import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:goodreader/services/ai/ai_client.dart';
import 'package:goodreader/services/http_transport.dart';

class FakeTransport extends HttpTransport {
  FakeTransport({
    this.statusCode = 200,
    this.responseBody = '{}',
    this.headers = const {},
  });

  int statusCode;
  String responseBody;
  Map<String, String> headers;

  /// 收到的最后一次请求，测试用它来断言请求体。
  Uri? lastUrl;
  Map<String, String>? lastHeaders;
  Object? lastBody;
  int callCount = 0;

  @override
  Future<TransportResponse> get(Uri url, {Map<String, String>? headers}) =>
      _record('GET', url, headers, null);

  @override
  Future<TransportResponse> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _record('POST', url, headers, body);

  @override
  Future<TransportResponse> send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _record(method, url, headers, body);

  @override
  Future<TransportResponse> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _record('PUT', url, headers, body);

  @override
  Future<TransportResponse> delete(Uri url, {Map<String, String>? headers}) =>
      _record('DELETE', url, headers, null);

  Future<TransportResponse> _record(
    String method,
    Uri url,
    Map<String, String>? headers,
    Object? body,
  ) async {
    callCount++;
    lastUrl = url;
    lastHeaders = headers;
    // 真实传输层在发送前把 Map 编码成 JSON，假实现必须照做，否则上层拿到
    // 的是 Dart 对象而不是线上的字节。
    lastBody = body is String ? body : jsonEncode(body);
    return TransportResponse(
      statusCode: statusCode,
      body: responseBody,
      headers: headers ?? const {},
    );
  }
}

/// 返回一个 OpenAI 兼容的成功响应。
String okBody(String content, {String model = 'gpt-4o-mini'}) => jsonEncode({
      'id': 'chatcmpl-1',
      'model': model,
      'choices': [
        {
          'index': 0,
          'message': {'role': 'assistant', 'content': content},
          'finish_reason': 'stop',
        }
      ],
      'usage': {'prompt_tokens': 10, 'completion_tokens': 20},
    });

String errorBody(String message, {String type = 'invalid_request_error'}) =>
    jsonEncode({
      'error': {'message': message, 'type': type, 'code': null}
    });

void main() {
  group('AiClient 正常路径', () {
    test('发出请求并读回助手回复', () async {
      final transport = FakeTransport(responseBody: okBody('林澜是沈砚的母亲。'));
      final client = AiClient(transport: transport);

      final reply = await client.chat(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'sk-test',
        model: 'deepseek-chat',
        history: [ChatMessage(role: 'user', content: '林澜是谁？')],
      );

      expect(reply, '林澜是沈砚的母亲。');
      expect(transport.lastUrl.toString(), 'https://api.example.com/v1/chat/completions');
      expect(transport.lastHeaders?['authorization'], 'Bearer sk-test');
      expect(transport.lastHeaders?['content-type'], 'application/json');
    });

    test('请求体带模型、系统提示与历史', () async {
      final transport = FakeTransport(responseBody: okBody('ok'));
      final client = AiClient(transport: transport);

      await client.chat(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'k',
        model: 'glm-4-air',
        history: [
          ChatMessage(role: 'user', content: '问题一'),
          ChatMessage(role: 'assistant', content: '回答一'),
          ChatMessage(role: 'user', content: '问题二'),
        ],
        system: '你是考据助手',
        maxHistory: 2,
      );

      final sent = jsonDecode(transport.lastBody! as String) as Map<String, dynamic>;
      expect(sent['model'], 'glm-4-air');
      expect(sent['stream'], false);
      expect(sent['temperature'], 0.3);

      final messages = sent['messages'] as List;
      expect(messages.length, 3);
      expect((messages.first as Map)['role'], 'system');
      expect((messages.first as Map)['content'], '你是考据助手');
      // maxHistory 只带最后两条，最早的问题一被丢掉。
      expect((messages[1] as Map)['content'], '回答一');
      expect((messages[2] as Map)['content'], '问题二');
    });

    test('默认系统提示要求用原文语言', () async {
      final transport = FakeTransport(responseBody: okBody('ok'));
      final client = AiClient(transport: transport);
      await client.chat(
        baseUrl: 'https://api.example.com/v1',
        apiKey: '',
        model: 'm',
        history: [ChatMessage(role: 'user', content: 'hi')],
      );
      final sent = jsonDecode(transport.lastBody! as String) as Map<String, dynamic>;
      final messages = sent['messages'] as List;
      expect((messages.first as Map)['content'], AiClient.systemPrompt);
      // 空密钥不带 authorization 头，本地 Ollama 就是这样。
      expect(transport.lastHeaders?.containsKey('authorization'), isFalse);
    });

    test('回复首尾空白被去掉', () async {
      final transport = FakeTransport(responseBody: okBody('  有空白  \n'));
      final client = AiClient(transport: transport);
      final reply = await client.chat(
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'k',
        model: 'm',
        history: [ChatMessage(role: 'user', content: 'hi')],
      );
      expect(reply, '有空白');
    });
  });

  group('AiClient 错误映射', () {
    Future<String> callWith(FakeTransport transport) => AiClient(transport: transport)
        .chat(
          baseUrl: 'https://api.example.com/v1',
          apiKey: 'k',
          model: 'm',
          history: [ChatMessage(role: 'user', content: 'hi')],
        );

    test('401 映射为 unauthorized', () async {
      final t = FakeTransport(statusCode: 401, responseBody: errorBody('Invalid API key'));
      await expectLater(
        callWith(t),
        throwsA(isA<AiException>()
            .having((e) => e.failure, 'failure', AiFailure.unauthorized)
            .having((e) => e.userMessage, 'userMessage', contains('密钥'))),
      );
    });

    test('403 同样映射为 unauthorized', () async {
      final t = FakeTransport(statusCode: 403, responseBody: errorBody('forbidden'));
      await expectLater(
        callWith(t),
        throwsA(isA<AiException>()
            .having((e) => e.failure, 'failure', AiFailure.unauthorized)),
      );
    });

    test('402 与 429 映射为 rateLimited', () async {
      for (final code in [402, 429]) {
        final t = FakeTransport(statusCode: code, responseBody: errorBody('quota'));
        await expectLater(
          callWith(t),
          throwsA(isA<AiException>()
              .having((e) => e.failure, 'failure', AiFailure.rateLimited)),
        );
      }
    });

    test('500 带上服务端给的一句话', () async {
      final t = FakeTransport(statusCode: 500, responseBody: errorBody('upstream overloaded'));
      await expectLater(
        callWith(t),
        throwsA(isA<AiException>()
            .having((e) => e.failure, 'failure', AiFailure.serverError)
            .having((e) => e.message, 'message', 'upstream overloaded')),
      );
    });

    test('200 但格式不对映射为 badResponse', () async {
      for (final body in [
        'not json at all',
        jsonEncode({'choices': []}),
        jsonEncode({'choices': [{'message': {}}]}),
        jsonEncode({'choices': [{'message': {'content': '  '}}]}),
        jsonEncode({'error': 'x'}),
      ]) {
        final t = FakeTransport(responseBody: body);
        await expectLater(
          callWith(t),
          throwsA(isA<AiException>()
              .having((e) => e.failure, 'failure', AiFailure.badResponse)),
          reason: body,
        );
      }
    });

    test('没配端点或模型时本地就失败，不发请求', () async {
      final t = FakeTransport(responseBody: okBody('x'));
      final client = AiClient(transport: t);
      await expectLater(
        client.chat(
          baseUrl: '',
          apiKey: 'k',
          model: 'm',
          history: const [],
        ),
        throwsA(isA<AiException>()
            .having((e) => e.failure, 'failure', AiFailure.notConfigured)),
      );
      await expectLater(
        client.chat(
          baseUrl: 'https://api.example.com/v1',
          apiKey: 'k',
          model: '',
          history: const [],
        ),
        throwsA(isA<AiException>()
            .having((e) => e.failure, 'failure', AiFailure.notConfigured)),
      );
      expect(t.callCount, 0);
    });

    test('网络异常映射为 network', () async {
      final transport = _ThrowingTransport();
      await expectLater(
        AiClient(transport: transport).chat(
          baseUrl: 'https://api.example.com/v1',
          apiKey: 'k',
          model: 'm',
          history: const [],
        ),
        throwsA(isA<AiException>()
            .having((e) => e.failure, 'failure', AiFailure.network)),
      );
    });
  });

  group('ChatMessage 序列化', () {
    test('往返保留字段', () {
      final m = ChatMessage(
        role: 'assistant',
        content: '回复',
        model: 'deepseek-chat',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final restored = ChatMessage.fromMap(jsonDecode(jsonEncode(m.toMap())))!;
      expect(restored.role, 'assistant');
      expect(restored.content, '回复');
      expect(restored.model, 'deepseek-chat');
      expect(restored.createdAt.millisecondsSinceEpoch, 1700000000000);
      expect(restored.isUser, isFalse);
    });

    test('坏数据返回 null', () {
      expect(ChatMessage.fromMap(null), isNull);
      expect(ChatMessage.fromMap('x'), isNull);
      expect(ChatMessage.fromMap({'role': 'user'}), isNull);
      expect(ChatMessage.fromMap({'content': 'c'}), isNull);
    });
  });
}

class _ThrowingTransport extends HttpTransport {
  @override
  Future<TransportResponse> get(Uri url, {Map<String, String>? headers}) =>
      Future.error(const TransportException('no route'));

  @override
  Future<TransportResponse> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      Future.error(const TransportException('no route'));

  @override
  Future<TransportResponse> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      Future.error(const TransportException('no route'));

  @override
  Future<TransportResponse> delete(Uri url, {Map<String, String>? headers}) =>
      Future.error(const TransportException('no route'));

  @override
  Future<TransportResponse> send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      Future.error(const TransportException('no route'));
}
