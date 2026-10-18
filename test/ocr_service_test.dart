import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/services/http_transport.dart';
import 'package:goodreader/services/ocr/ocr_service.dart';

class FakeTransport extends HttpTransport {
  FakeTransport({this.statusCode = 200, this.body = '{}'});

  int statusCode;
  String body;

  String? lastUrl;
  Map<String, String>? lastHeaders;
  String? lastBody;

  @override
  Future<TransportResponse> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    lastUrl = url.toString();
    lastHeaders = headers;
    lastBody = body is String ? body : jsonEncode(body);
    return TransportResponse(statusCode: statusCode, body: this.body);
  }

  @override
  Future<TransportResponse> get(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  Future<TransportResponse> put(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      throw UnimplementedError();

  @override
  Future<TransportResponse> delete(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  Future<TransportResponse> send(String method, Uri url,
          {Map<String, String>? headers, Object? body}) =>
      throw UnimplementedError();
}

void main() {
  group('响应解析', () {
    test('认 text 字段', () {
      expect(OcrService.parseText({'text': '第一行\n第二行'}), '第一行\n第二行');
    });

    test('认 result 字段', () {
      expect(OcrService.parseText({'result': '文字'}), '文字');
    });

    test('认 words_result 数组，按行拼接', () {
      expect(
        OcrService.parseText({
          'words_result': [
            {'words': '第一行'},
            {'words': '第二行'},
          ],
        }),
        '第一行\n第二行',
      );
    });

    test('认不出就返回 null', () {
      expect(OcrService.parseText(null), isNull);
      expect(OcrService.parseText(const {}), isNull);
      expect(OcrService.parseText(const {'foo': 'bar'}), isNull);
      expect(OcrService.parseText(const {'words_result': []}), isNull);
      expect(OcrService.parseText(const {'text': 42}), isNull);
    });
  });

  group('请求', () {
    test('图片以 base64 发出，带上语言与密钥', () async {
      final transport = FakeTransport(body: '{"text":"你好"}');
      final service = OcrService(
        baseUrl: 'https://ocr.example.com/recognize',
        apiKey: 'secret-token',
        language: 'chi_sim',
        transport: transport,
      );

      final text = await service.recognize(Uint8List.fromList([1, 2, 3]));
      expect(text, '你好');
      expect(transport.lastUrl, 'https://ocr.example.com/recognize');
      expect(transport.lastHeaders?['authorization'], 'Bearer secret-token');
      expect(transport.lastHeaders?['content-type'], 'application/json');

      final payload = jsonDecode(transport.lastBody!) as Map;
      expect(payload['image'], base64Encode([1, 2, 3]));
      expect(payload['language'], 'chi_sim');
    });

    test('没有密钥就不带 authorization', () async {
      final transport = FakeTransport(body: '{"text":"x"}');
      final service = OcrService(
        baseUrl: 'http://192.168.1.5:8080/ocr',
        transport: transport,
      );
      await service.recognize(Uint8List.fromList([9]));
      expect(transport.lastHeaders?.containsKey('authorization'), isFalse);
    });
  });

  group('错误映射', () {
    Future<String> run(int status, String body) => OcrService(
          baseUrl: 'https://ocr.example.com/r',
          transport: FakeTransport(statusCode: status, body: body),
        ).recognize(Uint8List.fromList([1]));

    test('401 与 403 都指向密钥', () async {
      await expectLater(
        run(401, '{}'),
        throwsA(isA<OcrException>().having((e) => e.message, 'm', contains('密钥'))),
      );
      await expectLater(
        run(403, '{}'),
        throwsA(isA<OcrException>().having((e) => e.message, 'm', contains('密钥'))),
      );
    });

    test('413 是图片太大', () async {
      await expectLater(
        run(413, '{}'),
        throwsA(isA<OcrException>().having((e) => e.message, 'm', contains('太大'))),
      );
    });

    test('429 是太频繁', () async {
      await expectLater(
        run(429, '{}'),
        throwsA(isA<OcrException>().having((e) => e.message, 'm', contains('频繁'))),
      );
    });

    test('其它 4xx / 5xx 带状态码', () async {
      await expectLater(
        run(500, '{}'),
        throwsA(isA<OcrException>().having((e) => e.message, 'm', contains('500'))),
      );
    });

    test('返回里没有文字算失败', () async {
      await expectLater(
        run(200, '{"foo":1}'),
        throwsA(isA<OcrException>().having((e) => e.message, 'm', contains('找不到文字'))),
      );
    });

    test('识别结果为空也算失败', () async {
      await expectLater(
        run(200, '{"text":"   "}'),
        throwsA(isA<OcrException>().having((e) => e.message, 'm', contains('没有识别出'))),
      );
    });

    test('没填地址直接报错，不发请求', () async {
      final transport = FakeTransport();
      await expectLater(
        OcrService(baseUrl: '  ', transport: transport)
            .recognize(Uint8List.fromList([1])),
        throwsA(isA<OcrException>()),
      );
      expect(transport.lastBody, isNull);
    });
  });

  group('预处理', () {
    test('长边超过上限才缩', () {
      expect(OcrService.needsDownscale(1600, 900), isFalse);
      expect(OcrService.needsDownscale(900, 1600), isFalse);
      expect(OcrService.needsDownscale(1601, 900), isTrue);
      expect(OcrService.needsDownscale(900, 2400), isTrue);
      expect(OcrService.needsDownscale(4000, 3000), isTrue);
    });

    test('按长边等比缩，短边跟着缩', () {
      expect(OcrService.scaledSize(3200, 1600), (width: 1600, height: 800));
      expect(OcrService.scaledSize(1600, 3200), (width: 800, height: 1600));
    });

    test('不需要缩时原样返回', () {
      expect(OcrService.scaledSize(1000, 800), (width: 1000, height: 800));
      expect(OcrService.scaledSize(1600, 1600), (width: 1600, height: 1600));
    });

    test('极窄的长条短边至少留 1 像素', () {
      // 1×5000 按比例算出来宽度会四舍五入成 0，0 宽的图编不出来。
      expect(OcrService.scaledSize(1, 5000), (width: 1, height: 1600));
      expect(OcrService.scaledSize(5000, 1), (width: 1600, height: 1));
    });

    test('上限可调', () {
      expect(OcrService.scaledSize(4000, 2000, edge: 1000),
          (width: 1000, height: 500));
    });
  });
}
