import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:warc/src/warc_record.dart';
import 'package:warc/warc.dart';

import 'cdxj_writer.dart';
import 'warc_writer.dart';

final _random = math.Random.secure();

typedef StoreCdxjFn = FutureOr<bool> Function(CdxjRecord record);

class WarcFileWriter {
  final String baseDirectoryPath;
  final String prefix;
  final int _serialNumberWidth;
  final int _serialTokenWidth;
  final StoreCdxjFn? _storeCdxjFn;
  String? _timestampId;
  String? _serialId;
  String? _serialToken;
  int _nextSerial = 0;
  int _currentLength = 0;
  final int _maxLength;
  bool _baseDirCreated = false;
  final bool _autoFlush;

  String? _currentFileName;
  IOSink? _warcSink;
  WarcWriter? _warcWriter;
  IOSink? _cdxjSink;
  CdxjWriter? _cdxjWriter;

  WarcFileWriter({
    required this.baseDirectoryPath,
    required this.prefix,
    int serialNumberWidth = 3,
    int serialTokenWidth = 4,
    int maxLength = 1024 * 1024 * 1024,
    StoreCdxjFn? storeCdxjFn,
    bool autoFlush = true,
  })  : _serialNumberWidth = serialNumberWidth,
        _serialTokenWidth = serialTokenWidth,
        _maxLength = maxLength,
        _storeCdxjFn = storeCdxjFn,
        _autoFlush = autoFlush;

  Future<void> _updateOutputFile() async {
    _timestampId ??= DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll('-', '')
        .replaceAll('T', '')
        .replaceAll(':', '')
        .split('.')
        .first;
    if (_currentLength >= _maxLength) {
      _serialId = null;
      _serialToken = null;
      _currentLength = 0;
    }
    _serialId ??= (_nextSerial++).toString().padLeft(_serialNumberWidth, '0');
    _serialToken ??= Iterable.generate(
        _serialTokenWidth, (i) => _random.nextInt(36).toRadixString(36)).join();
    final shortBase = [prefix, _timestampId, _serialId];
    final basename = [
      ...shortBase,
      if (_serialToken!.isNotEmpty) _serialToken,
    ].join('-');
    final warcFileName = '$basename.warc.gz';
    if (_currentFileName == warcFileName) return;

    await _closeWarcWriter();

    _currentFileName = warcFileName;
    _warcSink = File(p.join(baseDirectoryPath, warcFileName))
        .openWrite(mode: FileMode.writeOnlyAppend);
    _warcWriter = WarcWriter(
      output: _warcSink!,
      compressor: gzip.encoder,
    );

    if (_cdxjWriter == null) {
      _cdxjSink = File(p.join(baseDirectoryPath, '${shortBase.join('-')}.cdxj'))
          .openWrite(mode: FileMode.writeOnlyAppend);
      _cdxjWriter = CdxjWriter(
        output: _cdxjSink!,
        typed: false,
      );
    }
    await _cdxjSink?.flush();
  }

  Future<void> _createBaseDirIfNeeded() async {
    if (_baseDirCreated) return;
    await Directory(baseDirectoryPath).create(recursive: true);
    _baseDirCreated = true;
  }

  Future<void> add(WarcRecord record) async {
    await _createBaseDirIfNeeded();
    await _updateOutputFile();
    final position = await _warcWriter!.add(record);
    if (_autoFlush) {
      await _warcSink!.flush();
    }

    if (_cdxjWriter != null && record.header.targetUri != null) {
      String? mime;
      String? digest;
      WarcHttpBlock? httpBlock;
      final ct = (record.header['Content-Type'] ?? '').split(';').first.trim();
      if (ct == 'application/http') {
        httpBlock = WarcHttpBlock.fromBlock(record.block);
        if (record.header.type == WarcTypes.response) {
          mime = httpBlock.payloadContentType?.split(';').first.trim();
        }
        digest = hex.encode(sha1.convert(httpBlock.payloadBytes).bytes);
      }

      final cdxj = CdxjRecord(
        url: record.header.targetUri!,
        timestamp: record.header.date,
        mime: mime ?? 'warc/${record.header.type}',
        filename: _currentFileName!,
        offset: position.compressed.offset,
        length: position.compressed.length,
        status: httpBlock?.statusCode,
        digest: digest ?? hex.encode(sha1.convert(record.block.bytes).bytes),
      );
      final storeCdxj = _storeCdxjFn == null ? true : await _storeCdxjFn!(cdxj);
      if (storeCdxj) {
        _cdxjWriter!.add(cdxj);
        if (_autoFlush) {
          await _cdxjSink!.flush();
        }
      }
    }
  }

  Future<void> close() async {
    await _closeWarcWriter();
    await _closeCdxjWriter();
  }

  Future<void> _closeWarcWriter() async {
    await _warcSink?.flush();
    await _warcWriter?.close();
    _warcSink = null;
    _warcWriter = null;
  }

  Future<void> _closeCdxjWriter() async {
    await _cdxjSink?.flush();
    await _cdxjWriter?.close();
    _cdxjSink = null;
    _cdxjWriter = null;
  }
}
