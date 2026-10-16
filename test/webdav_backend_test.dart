import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/services/http_transport.dart';
import 'package:goodreader/services/sync/sync_backend.dart';
import 'package:goodreader/services/sync/webdav_backend.dart';

class FakeTransport extends HttpTransport {
  FakeTransport({this.statusCode = 200, this.responseBody = ''});

  int statusCode;
  String responseBody;

  /// key 是 `METHOD path`，值是这次请求记下的内容。
  final Map<String, String> calls = {};
  String? lastBody;

  @override
  Future<TransportResponse> get(Uri url, {Map<String, String>? headers}) =>
      _record('GET', url, null);

  @override
  Future<TransportResponse> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _record('POST', url, body);

  @override
  Future<TransportResponse> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _record('PUT', url, body);

  @override
  Future<TransportResponse> delete(Uri url, {Map<String, String>? headers}) =>
      _record('DELETE', url, null);

  @override
  Future<TransportResponse> send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _record(method, url, body);

  Future<TransportResponse> _record(String method, Uri url, Object? body) async {
    final key = '$method ${url.path}';
    calls[key] = body is String ? body : jsonEncode(body ?? '');
    lastBody = body is String ? body : jsonEncode(body ?? '');
    return TransportResponse(
      statusCode: statusCode,
      body: responseBody,
      headers: const {},
    );
  }
}

/// 一段带命名空间前缀的 PROPFIND 响应，和真实服务端一致。
const propfindXml = '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/dav/goodreader/</d:href>
    <d:propstat><d:prop>
      <d:getcontentlength>0</d:getcontentlength>
      <d:getlastmodified>Sun, 06 Nov 1994 08:49:37 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/goodreader/settings.json</d:href>
    <d:propstat><d:prop>
      <d:getcontentlength>128</d:getcontentlength>
      <d:getlastmodified>Mon, 07 Nov 1994 08:49:37 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/goodreader/notes.json</d:href>
    <d:propstat><d:prop>
      <d:getcontentlength>256</d:getcontentlength>
    </d:prop></d:propstat>
  </d:response>
</d:multistatus>''';

void main() {
  group('WebDavBackend URL 拼接', () {
    test('末尾斜杠与开头斜杠都只留一个', () async {
      final transport = FakeTransport();
      final backend = WebDavBackend(
        baseUrl: 'https://dav.example.com/dav/',
        username: 'u',
        password: 'p',
        transport: transport,
      );

      await backend.get('settings.json');
      expect(transport.calls.keys.single, 'GET /dav/settings.json');
    });

    test('url 里的 http 双斜杠不被破坏', () async {
      final transport = FakeTransport();
      final backend = WebDavBackend(
        baseUrl: 'http://localhost:8080/dav',
        username: 'u',
        password: 'p',
        transport: transport,
      );
      await backend.get('a/b.json');
      expect(transport.calls.keys.single, 'GET /dav/a/b.json');
    });
  });

  group('WebDavBackend 基本操作', () {
    test('Basic 认证头拼得对', () async {
      final transport = FakeTransport();
      final backend = WebDavBackend(
        baseUrl: 'https://dav.example.com',
        username: 'alice',
        password: 's3cret',
        transport: transport,
      );
      await backend.get('x.json');
      final expected =
          'Basic ${base64Encode(utf8.encode('alice:s3cret'))}';
      expect(backend.authorizationHeader, expected);
    });

    test('MKCOL 遇到 405 视为目录已存在，不抛异常', () async {
      final transport = FakeTransport(statusCode: 405);
      final backend = WebDavBackend(
        baseUrl: 'https://dav.example.com',
        username: 'u',
        password: 'p',
        transport: transport,
      );
      await expectLater(backend.ensureDirectory('goodreader'), completes);
      expect(transport.calls.containsKey('MKCOL /goodreader'), isTrue);
    });

    test('MKCOL 其它 4xx 抛异常', () async {
      final transport = FakeTransport(statusCode: 409);
      final backend = WebDavBackend(
        baseUrl: 'https://dav.example.com',
        username: 'u',
        password: 'p',
        transport: transport,
      );
      await expectLater(
        backend.ensureDirectory('goodreader'),
        throwsA(isA<SyncException>()),
      );
    });

    test('PUT 把内容原样发出', () async {
      final transport = FakeTransport(statusCode: 201);
      final backend = WebDavBackend(
        baseUrl: 'https://dav.example.com',
        username: 'u',
        password: 'p',
        transport: transport,
      );
      await backend.put('settings.json', '{"a":1}');
      expect(transport.lastBody, '{"a":1}');
    });

    test('GET 到 404 返回 null 而不是抛异常', () async {
      final transport = FakeTransport(statusCode: 404);
      final backend = WebDavBackend(
        baseUrl: 'https://dav.example.com',
        username: 'u',
        password: 'p',
        transport: transport,
      );
      expect(await backend.get('missing.json'), isNull);
    });

    test('PROPFIND 到 404 返回空列表', () async {
      final transport = FakeTransport(statusCode: 404);
      final backend = WebDavBackend(
        baseUrl: 'https://dav.example.com',
        username: 'u',
        password: 'p',
        transport: transport,
      );
      expect(await backend.list('goodreader'), isEmpty);
    });
  });

  group('PROPFIND 解析', () {
    test('跳过目录自身，读出文件名、大小与时间', () {
      final entries = WebDavBackend.parsePropfind(propfindXml, 'goodreader');
      expect(entries.length, 2);
      expect(entries.map((e) => e.path), ['settings.json', 'notes.json']);
      expect(entries.first.size, 128);
      expect(entries.first.modified, DateTime.utc(1994, 11, 7, 8, 49, 37));
      // 没有 getlastmodified 时退回到当前时间，不会抛异常。
      expect(entries.last.modified.year, DateTime.now().year);
    });

    test('命名空间前缀不同也能解析', () {
      const xml = '''<multistatus xmlns="DAV:">
  <response><href>/dav/d/</href></response>
  <response><href>/dav/d/one.json</href>
    <propstat><prop><getcontentlength>10</getcontentlength>
    <getlastmodified>Tue, 08 Nov 1994 08:49:37 GMT</getlastmodified>
    </prop></propstat></response>
</multistatus>''';
      final entries = WebDavBackend.parsePropfind(xml, 'd');
      expect(entries.length, 1);
      expect(entries.single.path, 'one.json');
      expect(entries.single.size, 10);
      expect(entries.single.modified, DateTime.utc(1994, 11, 8, 8, 49, 37));
    });

    test('空响应与垃圾响应返回空列表', () {
      expect(WebDavBackend.parsePropfind('', 'd'), isEmpty);
      expect(WebDavBackend.parsePropfind('<html>nope</html>', 'd'), isEmpty);
    });

    test('URL 编码的文件名被解码', () {
      const xml = '''<d:multistatus xmlns:d="DAV:">
  <d:response><d:href>/dav/d/%E4%B8%AD%E6%96%87.json</d:href>
  <d:propstat><d:prop></d:prop></d:propstat></d:response>
</d:multistatus>''';
      final entries = WebDavBackend.parsePropfind(xml, 'd');
      expect(entries.single.path, '中文.json');
    });
  });

  group('parseHttpDate', () {
    test('解析 RFC 1123 与带时区变体的写法', () {
      expect(
        parseHttpDate('Sun, 06 Nov 1994 08:49:37 GMT'),
        DateTime.utc(1994, 11, 6, 8, 49, 37),
      );
      // 时区偏移被忽略，只认得到日期与时刻。WebDAV 服务端一律发 GMT，
      // 同步只需要相对先后，所以这个取舍可以接受。
      expect(parseHttpDate('06 Nov 1994 08:49:37 +0000'),
          DateTime.utc(1994, 11, 6, 8, 49, 37));
      expect(parseHttpDate('garbage'), isNull);
      expect(parseHttpDate(null), isNull);
    });
  });

  group('网络失败映射', () {
    test('传输层异常转成 SyncException', () async {
      final backend = WebDavBackend(
        baseUrl: 'https://dav.example.com',
        username: 'u',
        password: 'p',
        transport: _ThrowingTransport(),
      );
      await expectLater(
        backend.ensureDirectory('goodreader'),
        throwsA(isA<SyncException>()),
      );
      await expectLater(
        backend.get('x.json'),
        throwsA(isA<SyncException>()),
      );
    });
  });
}

class _ThrowingTransport extends HttpTransport {
  @override
  Future<TransportResponse> get(Uri url, {Map<String, String>? headers}) =>
      Future.error(const TransportException('offline'));

  @override
  Future<TransportResponse> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      Future.error(const TransportException('offline'));

  @override
  Future<TransportResponse> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      Future.error(const TransportException('offline'));

  @override
  Future<TransportResponse> delete(Uri url, {Map<String, String>? headers}) =>
      Future.error(const TransportException('offline'));

  @override
  Future<TransportResponse> send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      Future.error(const TransportException('offline'));
}
