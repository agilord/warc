import 'dart:async';
import 'dart:convert';

import 'package:synchronized/synchronized.dart';

import 'common.dart';
import 'warc_record.dart';

class OffsetLength {
  final int offset;
  final int length;

  OffsetLength(this.offset, this.length);
}

class WarcRecordPosition {
  final OffsetLength raw;
  final OffsetLength compressed;

  WarcRecordPosition({
    required this.raw,
    required this.compressed,
  });
}

class WarcWriter {
  final Sink<List<int>> _outputSink;
  final Converter<List<int>, List<int>>? _compressor;
  bool _isClosed = false;
  int _rawOffset = 0;
  int _encodedOffset = 0;
  final _lock = Lock();

  WarcWriter._(this._outputSink, this._compressor);

  factory WarcWriter({
    required Sink<List<int>> output,
    Converter<List<int>, List<int>>? compressor,
  }) {
    return WarcWriter._(output, compressor);
  }

  int get rawOffset => _rawOffset;
  int get encodedOffset => _encodedOffset;

  Future<WarcRecordPosition> add(WarcRecord record) async {
    return await _lock.synchronized(() async {
      if (_isClosed) throw StateError('Writer was already closed.');

      final counterSink =
          _compressor == null ? null : _CounterSink(_outputSink);
      final chunkedSink = _compressor?.startChunkedConversion(counterSink!);
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
        compressed:
            OffsetLength(_encodedOffset, counterSink?._offset ?? rawLength),
      );

      _rawOffset += position.raw.length;
      _encodedOffset += position.compressed.length;
      return position;
    });
  }

  Future<void> close() async {
    if (_isClosed) return;
    await _lock.synchronized(() async {
      _isClosed = true;
      _outputSink.close();
    });
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
