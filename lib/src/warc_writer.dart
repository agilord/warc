import 'dart:async';
import 'dart:convert';

import 'warc_parser.dart';
import 'warc_record.dart';

class OffsetLength {
  final int offset;
  final int length;

  OffsetLength(this.offset, this.length);
}

class WarcRecordPosition {
  final OffsetLength raw;
  final OffsetLength encoded;

  WarcRecordPosition({
    required this.raw,
    required this.encoded,
  });
}

class WarcWriter {
  final Sink<List<int>> _outputSink;
  final Converter<List<int>, List<int>>? _encoder;
  bool _isClosed = false;
  int _rawOffset = 0;
  int _encodedOffset = 0;

  WarcWriter._(this._outputSink, this._encoder);

  factory WarcWriter({
    required Sink<List<int>> output,
    Converter<List<int>, List<int>>? encoder,
  }) {
    return WarcWriter._(output, encoder);
  }

  int get rawOffset => _rawOffset;
  int get encodedOffset => _encodedOffset;

  Future<WarcRecordPosition> add(WarcRecord record) async {
    if (_isClosed) throw StateError('Writer was already closed.');

    final counterSink = _encoder == null ? null : _CounterSink(_outputSink);
    final chunkedSink = _encoder?.startChunkedConversion(counterSink!);
    final sink = chunkedSink ?? _outputSink;

    var rawLength = 0;
    void writeChunk(List<int> data) {
      rawLength += data.length;
      sink.add(data);
    }

    writeChunk(utf8.encode('WARC/${record.header.version}\r\n'));
    for (final key in record.header.keys) {
      writeChunk(utf8.encode('$key: ${record.header[key]}\r\n'));
    }
    writeChunk([carriageReturn, lineFeed]);
    writeChunk(record.block.bytes);
    writeChunk([carriageReturn, lineFeed, carriageReturn, lineFeed]);

    chunkedSink?.close();

    final position = WarcRecordPosition(
      raw: OffsetLength(_rawOffset, rawLength),
      encoded: OffsetLength(_rawOffset, counterSink?._offset ?? rawLength),
    );

    _rawOffset += position.raw.length;
    _encodedOffset += position.encoded.length;
    return position;
  }

  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    _outputSink.close();
  }
}

class _CounterSink implements Sink<List<int>> {
  int _offset = 0;
  final Sink<List<int>> _sink;

  _CounterSink(this._sink);

  @override
  void add(List<int> data) {
    _offset += data.length;
    _sink.add(data);
  }

  @override
  void close() {}
}
