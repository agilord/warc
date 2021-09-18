import 'package:test/test.dart';
import 'package:warc/warc.dart';

void main() {
  group('CDXJ', () {
    test('serialize', () {
      final r = CdxjRecord(
        url: Uri.parse('http://example.com:80/x'),
        timestamp: DateTime.utc(2021, 9, 10, 11, 12, 13),
        mime: 'text/html',
        filename: 'x.warc.gz',
        offset: 12,
        length: 34,
      );
      expect(
        r.toString(),
        'com,example)/x 20210910111213 {"url":"http://example.com/x","mime":"text/html","filename":"x.warc.gz","offset":"12","length":"34"}',
      );
      expect(
        r.toString(typed: true),
        'com,example)/x 20210910111213 {"url":"http://example.com/x","mime":"text/html","filename":"x.warc.gz","offset":12,"length":34}',
      );

      expect(
        CdxjRecord(
          url: Uri.parse('https://example.com:443/?id=1'),
          timestamp: DateTime.utc(2021, 9, 10, 11, 12, 13),
          mime: 'text/html',
          filename: 'x.warc.gz',
          offset: 0,
          length: 1000,
          status: 200,
          digest: 'abc-123',
        ).toString(),
        'com,example)/?id=1 20210910111213 {"url":"https://example.com/?id=1","mime":"text/html","filename":"x.warc.gz","offset":"0","length":"1000","status":"200","digest":"abc-123"}',
      );
    });
  });
}
