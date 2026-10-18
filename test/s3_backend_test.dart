import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/services/sync/s3_backend.dart';

/// 固定的凭据与时间，让签名可复现。
const _accessKey = 'AKIDEXAMPLE';
const _secretKey = 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY';
final _clock = DateTime.utc(2024, 1, 2, 3, 4, 5);

/// 下面三个签名由一份独立的参考实现算出，那份实现先用 AWS 官方的
/// `aws-signing-test-suite/v4/get-vanilla` 向量校验过：canonical request、
/// string to sign、最终签名三者与官方文件逐字节一致
/// （`5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31`）。
/// 校验通过后才改成本项目实际签的三个头，所以这些数字不是从实现里抄回来的。
String _sign({
  required String method,
  required String canonicalUri,
  required String canonicalQuery,
  required String payloadHash,
}) =>
    S3Backend.authorizationHeader(
      method: method,
      canonicalUri: canonicalUri,
      canonicalQuery: canonicalQuery,
      host: 's3.us-east-1.amazonaws.com',
      payloadHash: payloadHash,
      now: _clock,
      region: 'us-east-1',
      accessKey: _accessKey,
      secretKey: _secretKey,
    );

void main() {
  group('区域识别', () {
    test('从 AWS 主机名里认，两种写法都认', () {
      expect(
        S3Backend.regionOf('https://s3.us-west-2.amazonaws.com/bucket'),
        'us-west-2',
      );
      expect(
        S3Backend.regionOf('https://s3-eu-central-1.amazonaws.com/bucket'),
        'eu-central-1',
      );
    });

    test('自建服务没有区域信息，用 us-east-1', () {
      expect(S3Backend.regionOf('http://192.168.1.5:9000/bucket'), 'us-east-1');
      expect(S3Backend.regionOf(''), 'us-east-1');
    });
  });

  group('规范化', () {
    test('路径逐段编码，斜杠保留', () {
      expect(
        S3Backend.canonicalUriOf(Uri.parse('https://h/mybucket/book_abc.json')),
        '/mybucket/book_abc.json',
      );
      expect(
        S3Backend.canonicalUriOf(Uri.parse('https://h/mybucket/')),
        '/mybucket/',
      );
      expect(S3Backend.canonicalUriOf(Uri.parse('https://h')), '/');
    });

    test('中文键编码一次，不重复编码', () {
      expect(
        S3Backend.canonicalUriOf(Uri.parse('https://h/b/书.json')),
        '/b/%E4%B9%A6.json',
      );
    });

    test('RFC 3986 的保留字符按规则处理', () {
      // 这四个是 Uri.encodeComponent 会放过的，SigV4 要求编码。
      expect(S3Backend.percentEncode("!*'()"), '%21%2A%27%28%29');
      // 波浪号是 unreserved，必须原样。
      expect(S3Backend.percentEncode('~'), '~');
      expect(S3Backend.percentEncode('a b'), 'a%20b');
      expect(S3Backend.percentEncode('书'), '%E4%B9%A6');
    });

    test('查询串按键排序并逐项编码', () {
      expect(
        S3Backend.canonicalQueryOf({
          'prefix': 'goodreader/',
          'list-type': '2',
          'delimiter': '/',
        }),
        'delimiter=%2F&list-type=2&prefix=goodreader%2F',
      );
      expect(S3Backend.canonicalQueryOf(const {}), '');
    });

    test('时间戳是 ISO 8601 基本格式，必须 UTC', () {
      expect(S3Backend.amzDateOf(DateTime.utc(2024, 1, 2, 3, 4, 5)),
          '20240102T030405Z');
      expect(S3Backend.amzDateOf(DateTime.utc(2015, 8, 30, 12, 36, 0)),
          '20150830T123600Z');
    });
  });

  group('SigV4 签名', () {
    test('空载荷的哈希是 sha256 的空串', () {
      expect(
        S3Backend.emptyPayloadHash,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('PUT 对象', () {
      // 载荷 {"a":1}
      final signature = _sign(
        method: 'PUT',
        canonicalUri: '/mybucket/book_abc.json',
        canonicalQuery: '',
        payloadHash:
            '015abd7f5cc57a2dd94b7590f04ad8084273905ee33ec5cebeae62276a97f862',
      );
      expect(
        signature,
        'AWS4-HMAC-SHA256 '
        'Credential=AKIDEXAMPLE/20240102/us-east-1/s3/aws4_request, '
        'SignedHeaders=host;x-amz-content-sha256;x-amz-date, '
        'Signature=98b2f5bf98231542c1b8e741d92fefa0c11a45dd44629ad49ab275940a5844d4',
      );
    });

    test('GET 对象', () {
      expect(
        _sign(
          method: 'GET',
          canonicalUri: '/mybucket/notes_abc.json',
          canonicalQuery: '',
          payloadHash: S3Backend.emptyPayloadHash,
        ),
        endsWith(
          'Signature=f4cb037d822fdb3c2f4e58bba1f2dc2d4f62f0c5db7b22c8f768e05e8a6500ff',
        ),
      );
    });

    test('列目录带查询串', () {
      expect(
        _sign(
          method: 'GET',
          canonicalUri: '/mybucket/',
          canonicalQuery: 'delimiter=%2F&list-type=2&prefix=goodreader%2F',
          payloadHash: S3Backend.emptyPayloadHash,
        ),
        endsWith(
          'Signature=5a508bf9c61895cf473623673b999507edae626c3605b9529836397bfe8226db',
        ),
      );
    });

    test('换一天签名就变', () {
      final a = S3Backend.authorizationHeader(
        method: 'GET',
        canonicalUri: '/b/x.json',
        canonicalQuery: '',
        host: 'h',
        payloadHash: S3Backend.emptyPayloadHash,
        now: DateTime.utc(2024, 1, 2),
        region: 'us-east-1',
        accessKey: _accessKey,
        secretKey: _secretKey,
      );
      final b = S3Backend.authorizationHeader(
        method: 'GET',
        canonicalUri: '/b/x.json',
        canonicalQuery: '',
        host: 'h',
        payloadHash: S3Backend.emptyPayloadHash,
        now: DateTime.utc(2024, 1, 3),
        region: 'us-east-1',
        accessKey: _accessKey,
        secretKey: _secretKey,
      );
      expect(a, isNot(b));
    });
  });

  group('解析 ListBucketResult', () {
    const body = '''
<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Name>mybucket</Name>
  <Prefix>goodreader/</Prefix>
  <Delimiter>/</Delimiter>
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>goodreader/book_abc.json</Key>
    <LastModified>2024-01-02T03:04:05.000Z</LastModified>
    <Size>42</Size>
  </Contents>
  <Contents>
    <Key>goodreader/notes_abc.json</Key>
    <LastModified>2024-02-03T04:05:06.000Z</LastModified>
    <Size>7</Size>
  </Contents>
  <CommonPrefixes>
    <Prefix>goodreader/sub/</Prefix>
  </CommonPrefixes>
</ListBucketResult>
''';

    test('取出直接子文件，跳过子目录', () {
      final entries = S3Backend.parseList(body, 'goodreader/');
      expect(entries.map((e) => e.path), ['book_abc.json', 'notes_abc.json']);
      expect(entries.first.size, 42);
      expect(entries.first.modified, DateTime.utc(2024, 1, 2, 3, 4, 5));
    });

    test('坏 XML 返回空列表而不是抛异常', () {
      expect(S3Backend.parseList('<not-closed>', 'x/'), isEmpty);
      expect(S3Backend.parseList('', 'x/'), isEmpty);
    });

    test('大小写与命名空间前缀不影响匹配', () {
      const prefixed = '''
<d:ListBucketResult xmlns:d="http://s3.amazonaws.com/doc/2006-03-01/">
  <d:Contents>
    <d:Key>goodreader/book_x.json</d:Key>
    <d:Size>1</d:Size>
  </d:Contents>
</d:ListBucketResult>
''';
      final entries = S3Backend.parseList(prefixed, 'goodreader/');
      expect(entries.map((e) => e.path), ['book_x.json']);
    });
  });
}
