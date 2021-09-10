import 'dart:io';

import 'package:base32/base32.dart';
import 'package:buffer/buffer.dart';
import 'package:crypto/crypto.dart';
import 'package:warc/src/reader.dart';
import 'package:test/test.dart';

void main() {
  group('Assets test', () {
    test('single-response.warc', () async {
      Future<void> testWithStream(Stream<List<int>> input) async {
        await readWarc(input, (r) async {
          expect(r.header.contentLength, 20931);
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
