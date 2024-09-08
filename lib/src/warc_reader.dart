import 'dart:async';
import 'dart:typed_data';

import 'common.dart';
import 'warc_http_block.dart';
import 'warc_parser.dart';
import 'warc_record.dart';

class WarcStreamReader extends StreamTransformerBase<List<int>, WarcRecord> {
  final bool _copyBytes;
  WarcStreamReader({bool copyBytes = false}) : _copyBytes = copyBytes;

  @override
  Stream<WarcRecord> bind(Stream<List<int>> input) async* {
    WarcHeader? header;
    final buffer = BytesBuilder(copy: _copyBytes);
    await for (final chunk in input) {
      buffer.add(chunk);

      bool emitted = true;
      while (emitted) {
        emitted = false;
        if (header == null) {
          final boundary = indexOfHeaderEnd(buffer.toBytes());
          if (boundary > 0) {
            final headerBuffer = buffer.takeBytes();
            final headerBytes =
                Uint8List.sublistView(headerBuffer, 0, boundary);
            header = parseHeaderBytes(headerBytes);
            final restOfBytes = Uint8List.sublistView(headerBuffer, boundary);
            buffer.add(restOfBytes);
          }
        }
        if (header != null && header.contentLength + 4 <= buffer.length) {
          final contentBuffer = buffer.takeBytes();
          final contentBytes =
              Uint8List.sublistView(contentBuffer, 0, header.contentLength);
          final restOfBytes =
              Uint8List.sublistView(contentBuffer, header.contentLength + 4);
          buffer.add(restOfBytes);
          final ct = (header['Content-Type'] ?? '').split(';').first.trim();
          WarcBlock? block;
          if (ct == 'application/http') {
            block = WarcHttpBlock.parseBytes(contentBytes);
          }
          yield WarcRecord(header, block ?? WarcBlock(contentBytes));
          header = null;
          emitted = true;
        }
      }
    }
    if (buffer.length > 0) {
      final bytes = buffer.toBytes();
      if (bytes.any((e) => e != lineFeed && e != carriageReturn)) {
        throw FormatException(
            'Unexpected bytes at the end of the input: ${buffer.length} bytes.');
      }
    }
  }
}

Stream<WarcRecord> readWarc(Stream<List<int>> input) =>
    WarcStreamReader().bind(input);
