import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'warc_record.dart';

const lineFeed = 10;
const carriageReturn = 13;

int indexOfHeaderEnd(Uint8List buffer) {
  var start = 0;
  while (start < buffer.length &&
      (buffer[start] == lineFeed || buffer[start] == carriageReturn)) {
    start++;
  }
  for (var i = max(2, start); i < buffer.length; i++) {
    final current = buffer[i];
    switch (current) {
      case lineFeed:
        final prev = buffer[i - 1];
        if (prev == lineFeed) {
          return i + 1;
        }
        if (prev == carriageReturn && buffer[i - 2] == lineFeed) {
          return i + 1;
        }
        break;
      default:
      // no-op
    }
  }
  return -1;
}

WarcHeader parseHeaderBytes(Uint8List bytes) {
  final lines = utf8
      .decode(bytes)
      .split('\n')
      .map((e) => e.trimRight())
      .where((e) => e.isNotEmpty)
      .toList();
  if (lines.isEmpty) throw FormatException('Empty WARC header.');
  if (!lines.first.startsWith('WARC/')) {
    throw FormatException('Does not start with WARC/');
  }
  final warcVersion = lines.first.split('/').skip(1).join('/');
  final values = <String, String>{};
  for (final line in lines.skip(1)) {
    final index = line.indexOf(':');
    if (index < 0) throw FormatException('Line does not have valid key: $line');
    final key = line.substring(0, index).trim();
    final value = line.substring(index + 1).trim();
    values[key] = value;
  }
  return WarcHeader.fromValues(
    version: warcVersion,
    values: values,
  );
}
