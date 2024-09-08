import 'dart:async';
import 'dart:typed_data';

import 'warc_parser.dart';
import 'warc_record.dart';

class RawWarcHeaderOrChunk {
  final WarcHeader? header;
  final Uint8List? chunk;

  RawWarcHeaderOrChunk.header(this.header) : chunk = null;
  RawWarcHeaderOrChunk.chunk(this.chunk) : header = null;
}

Stream<RawWarcHeaderOrChunk> parseWarcRaw(Stream<List<int>> input) async* {
  WarcHeader? header;
  var remainingPayloadLength = 0;
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
          yield RawWarcHeaderOrChunk.header(header);
          remainingPayloadLength = header.contentLength;

          final restOfBytes = Uint8List.sublistView(headerBuffer, boundary);
          if (restOfBytes.length < remainingPayloadLength) {
            yield RawWarcHeaderOrChunk.chunk(restOfBytes);
            remainingPayloadLength -= restOfBytes.length;
          } else {
            buffer.add(restOfBytes);
          }
        }
      }
      if (header != null &&
          buffer.length > 0 &&
          buffer.length <= remainingPayloadLength) {
        final chunkBytes = buffer.takeBytes();
        remainingPayloadLength -= chunkBytes.length;
        yield RawWarcHeaderOrChunk.chunk(chunkBytes);
      }
      if (header != null &&
          remainingPayloadLength > 0 &&
          remainingPayloadLength < buffer.length) {
        final contentBuffer = buffer.takeBytes();
        final contentBytes =
            Uint8List.sublistView(contentBuffer, 0, remainingPayloadLength);
        final restOfBytes =
            Uint8List.sublistView(contentBuffer, remainingPayloadLength);
        buffer.add(restOfBytes);
        remainingPayloadLength -= contentBytes.length;
        yield RawWarcHeaderOrChunk.chunk(contentBytes);
        header = null;
        emitted = true;
      }
    }
  }
  if (buffer.length > 0) {
    throw FormatException(
        'Unexpected bytes at the end of the input: ${buffer.length} bytes.');
  }
}
