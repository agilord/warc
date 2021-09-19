import 'dart:typed_data';

import 'package:buffer/buffer.dart';

import 'common.dart';

class WarcRecord {
  final WarcHeader header;
  final WarcBlock block;

  WarcRecord._(this.header, this.block);

  factory WarcRecord(WarcHeader header, WarcBlock block) {
    if (!header.hasContentLength ||
        (!header.hasContentType && block.blockContentType != null)) {
      header = header.change(
        contentLength: header.hasContentLength ? null : block.bytes.length,
        contentType: header.hasContentType ? null : block.blockContentType,
      );
    }
    return WarcRecord._(header, block);
  }
}

String _uri(String url) {
  url = url.toString();
  if (url.startsWith('<')) return url;
  return '<$url>';
}

abstract class WarcTypes {
  static const warcinfo = 'warcinfo';
  static const response = 'response';
  static const resource = 'resource';
  static const request = 'request';
  static const metadata = 'metadata';
  static const revisit = 'revisit';
  static const conversion = 'conversion';
  static const continuation = 'continuation';
}

class WarcHeader {
  final String version;
  final CaseInsensitiveMap _values;

  String? _type;
  DateTime? _date;
  String? _recordId;
  int? _contentLength;
  Uri? _targetUri;

  WarcHeader.fromValues({
    this.version = '1.1',
    required Map<String, String> values,
  }) : _values = CaseInsensitiveMap<String>(values);

  WarcHeader({
    this.version = '1.1',
    required String type,
    required DateTime date,
    required String recordId,
    int? contentLength,
    String? contentType,
    String? warcinfoId,
    String? concurrentTo,
    String? ipAddress,
    Uri? targetUri,
    String? refersTo,
    String? refersToTargetUri,
    DateTime? refersToDate,
    String? payloadDigest,
    String? blockDigest,
    String? payloadType,
    String? filename,
    String? truncated,
    Map<String, String>? values,
  })  : _values = CaseInsensitiveMap<String>({
          'WARC-Type': type,
          'WARC-Date': date.toUtc().toIso8601String(),
          'WARC-Record-ID': _uri(recordId),
          if (contentLength != null) 'Content-Length': contentLength.toString(),
          if (contentType != null) 'Content-Type': contentType,
          if (warcinfoId != null) 'WARC-Warcinfo-ID': _uri(warcinfoId),
          if (concurrentTo != null) 'WARC-Concurrent-To': _uri(concurrentTo),
          if (ipAddress != null) 'WARC-IP-Address': ipAddress,
          if (targetUri != null) 'WARC-Target-URI': targetUri.toString(),
          if (refersTo != null) 'WARC-Refers-To': _uri(refersTo),
          if (refersToTargetUri != null)
            'WARC-Refers-To-Target-URI': refersToTargetUri,
          if (refersToDate != null)
            'WARC-Refers-To-Date': refersToDate.toUtc().toIso8601String(),
          if (payloadDigest != null) 'WARC-Payload-Digest': payloadDigest,
          if (blockDigest != null) 'WARC-Block-Digest': blockDigest,
          // identified payload type
          if (payloadType != null) 'WARC-Identified-Payload-Type': payloadType,
          if (filename != null) 'WARC-Filename': filename,
          if (truncated != null) 'WARC-Truncated': truncated,
          if (values != null) ...values,
        }),
        _type = type,
        _date = date,
        _contentLength = contentLength,
        _targetUri = targetUri;

  Iterable<String> get keys => _values.keys;
  String? operator [](String key) => _values[key];

  DateTime get date => _date ??= DateTime.parse(this['WARC-Date']!);
  String get type => _type ??= this['WARC-Type']!;
  String get recordId => _recordId ??= this['WARC-Record-ID']!;

  int get contentLength =>
      _contentLength ??= int.parse(this['Content-Length'] ?? '0');
  late final hasContentLength = this['Content-Length'] != null;
  late final hasContentType = this['Content-Type'] != null;

  Uri? get targetUri {
    if (_targetUri == null) {
      final v = this['WARC-Target-URI'];
      _targetUri = v == null ? null : Uri.parse(v);
    }
    return _targetUri;
  }

  WarcHeader change({
    int? contentLength,
    String? contentType,
  }) {
    return WarcHeader.fromValues(
      values: {
        ..._values,
        if (contentLength != null) 'Content-Length': contentLength.toString(),
        if (contentType != null) 'Content-Type': contentType,
      },
      version: version,
    );
  }
}

class WarcBlock {
  final Uint8List bytes;

  WarcBlock(List<int> bytes) : bytes = castBytes(bytes);

  String? get blockContentType => null;
}
