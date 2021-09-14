import 'dart:typed_data';

class WarcRecord {
  final WarcHeader header;
  final WarcBlock block;

  WarcRecord({
    required this.header,
    required this.block,
  });
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
  final Map<String, String> _values;

  String? _type;
  DateTime? _date;
  int? _contentLength;
  Uri? _targetUri;

  WarcHeader.fromValues({
    this.version = '1.1',
    required Map<String, String> values,
  }) : _values = <String, String>{...values};

  WarcHeader({
    this.version = '1.1',
    required String type,
    required DateTime date,
    required String recordId,
    required int contentLength,
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
  })  : _values = <String, String>{
          'WARC-Type': type,
          'WARC-Date': date.toUtc().toIso8601String(),
          'WARC-Record-ID': _uri(recordId),
          'Content-Length': contentLength.toString(),
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
        },
        _type = type,
        _date = date,
        _contentLength = contentLength,
        _targetUri = targetUri;

  Iterable<String> get keys => _values.keys;
  String? operator [](String key) {
    if (_values.containsKey(key)) {
      return _values[key];
    }
    final lc = key.toLowerCase();
    for (final k in keys) {
      if (k.toLowerCase() == lc) {
        return _values[k];
      }
    }
    return null;
  }

  DateTime get date => _date ??= DateTime.parse(this['WARC-Date']!);
  String get type => _type ??= this['WARC-Type']!;

  int get contentLength =>
      _contentLength ??= int.parse(this['Content-Length'] ?? '0');

  Uri? get targetUri {
    if (_targetUri == null) {
      final v = this['WARC-Target-URI'];
      _targetUri = v == null ? null : Uri.parse(v);
    }
    return _targetUri;
  }
}

abstract class WarcBlock {
  WarcBlock();

  factory WarcBlock.bytes(List<int> bytes) => _WarcBlockBytes(bytes);

  Stream<List<int>> read();

  Future<List<int>> readAsBytes() async {
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in read()) {
      buffer.add(chunk);
    }
    return buffer.takeBytes();
  }
}

class _WarcBlockBytes extends WarcBlock {
  final List<int> _bytes;
  _WarcBlockBytes(this._bytes);

  @override
  Stream<List<int>> read() {
    return Stream<List<int>>.value(_bytes);
  }

  @override
  Future<List<int>> readAsBytes() async {
    return _bytes;
  }
}
