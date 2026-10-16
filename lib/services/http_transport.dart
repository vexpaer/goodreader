import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// 一次 HTTP 响应的最小表示。
///
/// 只带客户端需要的字段，避免把 `http` 包的类型泄漏到业务层。
class TransportResponse {
  const TransportResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  Map<String, dynamic>? get json => _json ??= _tryJson(body);

  static Map<String, dynamic>? _tryJson(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic>? _json;
}

/// 网络失败。与「服务端返回了错误」区分开，因为两者的处理不同。
class TransportException implements Exception {
  const TransportException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'TransportException: $message';
}

/// HTTP 传输层。业务代码只依赖这个抽象，测试注入假实现。
abstract class HttpTransport {
  const HttpTransport();

  Future<TransportResponse> get(Uri url, {Map<String, String>? headers});

  Future<TransportResponse> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  });

  Future<TransportResponse> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  });

  Future<TransportResponse> delete(Uri url, {Map<String, String>? headers});

  /// 流式下载，用于同步大文件。默认按一次性读取实现。
  Future<Uint8List> download(Uri url, {Map<String, String>? headers}) async {
    final response = await get(url, headers: headers);
    if (!response.isSuccess) {
      throw TransportException('下载失败，HTTP ${response.statusCode}');
    }
    return Uint8List.fromList(utf8.encode(response.body));
  }
}

/// 默认实现，包一层 `http`。
class IoHttpTransport extends HttpTransport {
  const IoHttpTransport();

  static const _userAgent = 'GoodReader-Android';

  @override
  Future<TransportResponse> get(Uri url, {Map<String, String>? headers}) =>
      _send(() => http.get(url, headers: _merge(headers)));

  @override
  Future<TransportResponse> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _send(() => http.post(url, headers: _merge(headers), body: _encode(body)));

  @override
  Future<TransportResponse> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _send(() => http.put(url, headers: _merge(headers), body: _encode(body)));

  @override
  Future<TransportResponse> delete(Uri url, {Map<String, String>? headers}) =>
      _send(() => http.delete(url, headers: _merge(headers)));

  @override
  Future<Uint8List> download(Uri url, {Map<String, String>? headers}) async {
    try {
      final request = http.Request('GET', url)..headers.addAll(_merge(headers));
      final response = await http.Client().send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TransportException('下载失败，HTTP ${response.statusCode}');
      }
      return await response.stream.toBytes();
    } on http.ClientException catch (e) {
      throw TransportException('网络连接失败', cause: e);
    }
  }

  Object? _encode(Object? body) {
    if (body == null) return null;
    if (body is String) return body;
    if (body is Uint8List) return body;
    return jsonEncode(body);
  }

  Map<String, String> _merge(Map<String, String>? headers) => {
        'accept': 'application/json',
        'user-agent': _userAgent,
        ...?headers,
      };

  Future<TransportResponse> _send(
      Future<http.Response> Function() request) async {
    try {
      final response = await request();
      return TransportResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } on http.ClientException catch (e) {
      throw TransportException('网络连接失败', cause: e);
    }
  }
}
