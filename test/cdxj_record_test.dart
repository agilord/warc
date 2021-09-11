import 'package:test/test.dart';
import 'package:warc/src/warc_record.dart';
import 'package:warc/warc.dart';

void main() {
  group('CDXJ', () {
    test('serialize', () {
      expect(
        CdxjRecord(
          uri: Uri.parse('http://hvg.hu:80/x'),
          timestamp: DateTime.utc(2021, 9, 10, 11, 12, 13),
          type: WarcTypes.response,
          reference: warcfileUri('x.warc.gz', 12),
        ).toString(),
        'hu,hvg)/x 20210910111213 response {"uri":"http://hvg.hu/x","ref":"warcfile:x.warc.gz#12"}',
      );

      expect(
        CdxjRecord(
          uri: Uri.parse('https://hvg.hu:443/?id=1'),
          timestamp: DateTime.utc(2021, 9, 10, 11, 12, 13),
          type: WarcTypes.response,
          reference: warcfileUri('x.warc.gz', 12),
          httpStatusCode: 200,
          mediaContentType: 'text/html',
          recordId: 'rid-1',
        ).toString(),
        'hu,hvg)/?id=1 20210910111213 response {"uri":"https://hvg.hu/?id=1","hsc":200,"mct":"text/html","ref":"warcfile:x.warc.gz#12","rid":"rid-1"}',
      );
    });
  });
}
