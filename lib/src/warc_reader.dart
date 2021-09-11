import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'warc_parser.dart';
import 'warc_record.dart';

Future<void> readWarc(
  Stream<List<int>> input,
  Future<bool> Function(WarcRecord record) onRecord,
) async {
  WarcHeader? header;
  final buffer = BytesBuilder(copy: false);
  await for (final chunk in input) {
    buffer.add(chunk);

    bool emitted = true;
    while (emitted) {
      emitted = false;
      if (header == null) {
        final boundary = indexOfHeaderEnd(buffer.toBytes());
        if (boundary > 0) {
          final headerBuffer = buffer.takeBytes();
          final headerBytes = Uint8List.sublistView(headerBuffer, 0, boundary);
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
        final next = await onRecord(WarcRecord(
          header: header,
          payload: WarcPayload.bytes(contentBytes),
        ));
        if (!next) return;
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
