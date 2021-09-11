import 'dart:io';
import 'dart:typed_data';

import 'package:base32/base32.dart';
import 'package:buffer/buffer.dart';
import 'package:crypto/crypto.dart';
import 'package:warc/warc.dart';
import 'package:test/test.dart';

void main() {
  group('Assets test', () {
    test('single-response.warc', () async {
      Future<void> testWithStream(Stream<List<int>> input) async {
        await readWarc(input, (r) async {
          expect(r.header.contentLength, 20931);
          expect(r.header.targetUri.toString(), 'http://commoncrawl.org/');
          expect(r.header.date, DateTime.utc(2019, 12, 10, 10, 00, 01, 0));
          expect(r.header.type, 'response');
          final payload = await r.payload.readAsBytes();
          expect(payload, hasLength(20931));
          final hash = base32.encode(castBytes(sha1.convert(payload).bytes));
          expect(hash, 'IJCC6OVIIPVV5KV6WESWIGH7UV2NO34X');
          expect(r.header['WARC-Block-Digest'], 'sha1:$hash');
          return true;
        });
      }

      final file = File('test_assets/single-response.warc');
      await testWithStream(file.openRead());
      for (final size in [1, 2, 3, 5, 8, 13, 21, 34, 55]) {
        await testWithStream(_chunk(file.openRead(), size));
      }

      final plainSink = BytesBuilderSink();
      final plainWriter = WarcWriter(output: plainSink);
      await readWarc(file.openRead(), (r) async {
        final pos = await plainWriter.add(r);
        expect(pos.raw.offset, 0);
        expect(pos.raw.length, 21507);
        expect(pos.encoded.offset, 0);
        expect(pos.encoded.length, 21507);
        return true;
      });
      expect(plainWriter.rawOffset, 21507);
      expect(plainWriter.encodedOffset, 21507);
      await plainWriter.close();
      expect(plainSink.result, hasLength(21507));
      expect(plainSink.result, await file.readAsBytes());

      final compressedSink = BytesBuilderSink();
      final compressedWriter =
          WarcWriter(output: compressedSink, encoder: gzip.encoder);
      await readWarc(file.openRead(), (r) async {
        final pos = await compressedWriter.add(r);
        expect(pos.raw.offset, 0);
        expect(pos.raw.length, 21507);
        expect(pos.encoded.offset, 0);
        expect(pos.encoded.length, 5392);
        return true;
      });
      expect(compressedWriter.rawOffset, 21507);
      expect(compressedWriter.encodedOffset, 5392);
      await compressedWriter.close();
      expect(compressedSink.result, hasLength(5392));
      expect(gzip.decode(compressedSink.result), await file.readAsBytes());
    });
  });
}

Stream<List<int>> _chunk(Stream<List<int>> input, int size) async* {
  final reader = ByteDataReader();
  await for (final data in input) {
    reader.add(data);
    while (reader.remainingLength >= size) {
      yield reader.read(size);
    }
  }
  if (reader.remainingLength > 0) {
    yield reader.read(reader.remainingLength);
  }
}

class BytesBuilderSink implements Sink<List<int>> {
  final _buffer = BytesBuilder(copy: false);
  Uint8List? _result;

  Uint8List get result => _result!;

  @override
  void add(List<int> data) {
    if (_result != null) throw StateError('Close already called.');
    _buffer.add(data);
  }

  @override
  void close() {
    _result ??= _buffer.takeBytes();
  }
}
