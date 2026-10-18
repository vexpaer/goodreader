import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

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

/// 用 dart:ui 现画一张 1×1 的 PNG，避免把一段来路不明的 base64 写进测试。
Future<Uint8List> tinyPng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 1, 1),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );
  final image = await recorder.endRecording().toImage(1, 1);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    testWidgets('小图原样返回，不重新编码', (tester) async {
      final bytes = await tinyPng();
      final result = await OcrService.downscale(bytes);
      expect(result, orderedEquals(bytes));
    });

    testWidgets('打不开的数据报可读的错误', (tester) async {
      await expectLater(
        OcrService.downscale(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<OcrException>().having((e) => e.message, 'm', contains('打不开'))),
      );
    });
  });
}
