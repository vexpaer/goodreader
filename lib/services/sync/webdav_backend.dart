import 'dart:convert';

import 'package:goodreader/services/http_transport.dart';

/// 云端的一个文件条目。[path] 只是文件名，不含目录。
class RemoteEntry {
  const RemoteEntry({
    required this.path,
    required this.size,
    required this.modified,
  });

  final String path;
  final int size;
  final DateTime modified;
}

class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => 'SyncException: $message';
}

/// 同步后端。WebDAV 与 S3 只是同一组操作的两种实现。
///
/// 上层只跟这四个方法打交道，不关心用的是 HTTP 还是对象存储。
abstract class SyncBackend {
  const SyncBackend();

  /// 确保远端目录存在。已存在时不做任何事。
  Future<void> ensureDirectory(String path);

  /// 列出目录下的文件。目录不存在返回空列表。
  Future<List<RemoteEntry>> list(String path);

  /// 上传一份 JSON 文本。
  Future<void> put(String path, String content);

  /// 下载。文件不存在返回 null。
  Future<String?> get(String path);

  Future<void> delete(String path);
}

/// WebDAV 后端。
///
/// WebDAV 的目录也是 URL，建目录用 MKCOL，已存在时服务端回 405，那是正常情况。
class WebDavBackend extends SyncBackend {
  WebDavBackend({
    required this.baseUrl,
    required this.username,
    required this.password,
    HttpTransport? transport,
  }) : _transport = transport ?? const IoHttpTransport();

  final String baseUrl;
  final String username;
  final String password;
  final HttpTransport _transport;

  /// 暴露出来只为了测试。不要在别处读它。
  String get authorizationHeader =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  /// 拼 URL。两端都可能有斜杠，不能直接用 replaceAll，那会把 https:// 也切坏。
  Uri _url(String path) {
    final root = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final tail = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$root$tail');
  }

  @override
  Future<void> ensureDirectory(String path) async {
    final response = await _request('MKCOL', _url(path));
    if (response.statusCode == 405) return;
    if (response.statusCode >= 400) {
      throw SyncException('创建目录失败，HTTP ${response.statusCode}');
    }
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final response = await _request('PROPFIND', _url(path));
    if (response.statusCode == 404) return const [];
    if (response.statusCode >= 400) {
      throw SyncException('读取目录失败，HTTP ${response.statusCode}');
    }
    return _parsePropfind(response.body, path);
  }

  @override
  Future<void> put(String path, String content) => _guard(() async {
        final response = await _transport.put(
          _url(path),
          headers: {
            'authorization': authorizationHeader,
            'content-type': 'application/json',
          },
          body: content,
        );
        if (response.statusCode >= 400) {
          throw SyncException('上传失败，HTTP ${response.statusCode}');
        }
      });

  @override
  Future<String?> get(String path) => _guard(() async {
        final response = await _transport.get(
          _url(path),
          headers: {'authorization': authorizationHeader},
        );
        if (response.statusCode == 404) return null;
        if (response.statusCode >= 400) {
          throw SyncException('下载失败，HTTP ${response.statusCode}');
        }
        return response.body;
      });

  @override
  Future<void> delete(String path) async {
    final response = await _request('DELETE', _url(path));
    if (response.statusCode >= 400 && response.statusCode != 404) {
      throw SyncException('删除失败，HTTP ${response.statusCode}');
    }
  }

  /// 所有动作都走这里，网络层异常一律转成 SyncException。
  ///
  /// 调用方只 catch 一种异常。少包一条路径就意味着那一种失败会漏过去。
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on TransportException catch (e) {
      throw SyncException(e.message);
    }
  }

  Future<TransportResponse> _request(String method, Uri url) =>
      _guard(() => _transport.send(
            method,
            url,
            headers: {'authorization': authorizationHeader, 'depth': '1'},
          ));

  /// 从 PROPFIND 的 XML 里取出文件名、大小与修改时间。
  ///
  /// 命名空间前缀随服务端而变，所以按**本地名**匹配而不是写死 `d:`。
  /// 暴露出来只为了测试。
  static List<RemoteEntry> parsePropfind(String body, String directory) {
    return _parsePropfind(body, directory);
  }

  static List<RemoteEntry> _parsePropfind(String body, String directory) {
    final entries = <RemoteEntry>[];
    final responses = RegExp(r'<(?:[\w.-]+:)?response\b[^>]*>(.*?)'
            r'</(?:[\w.-]+:)?response>',
            dotAll: true)
        .allMatches(body);

    for (final match in responses) {
      final chunk = match.group(1) ?? '';
      final href = _firstTag(chunk, 'href');
      if (href == null || href.isEmpty) continue;

      // 目录自身也出现在结果里，靠结尾斜杠认出来。
      if (href.endsWith('/')) continue;

      final name = _lastSegment(href);
      if (name.isEmpty || name == directory) continue;

      final size = int.tryParse(_firstTag(chunk, 'getcontentlength') ?? '') ?? 0;
      entries.add(RemoteEntry(
        path: name,
        size: size,
        modified: parseHttpDate(_firstTag(chunk, 'getlastmodified')) ?? DateTime.now(),
      ));
    }
    return entries;
  }

  static String _lastSegment(String href) {
    var value = href.split('?').first.split('#').first;
    value = Uri.decodeComponent(value);
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    final slash = value.lastIndexOf('/');
    return slash < 0 ? value : value.substring(slash + 1);
  }

  /// 按本地名取第一个子元素的文本。没有该元素返回 null。
  static String? _firstTag(String xml, String localName) {
    final pattern = RegExp('<(?:[\\w.-]+:)?$localName\\b[^>]*>'
        '(.*?)</(?:[\\w.-]+:)?$localName>', dotAll: true);
    final match = pattern.firstMatch(xml);
    if (match != null) return _decode(match.group(1)!);
    if (RegExp('<(?:[\\w.-]+:)?$localName\\b[^>]*/>').hasMatch(xml)) return '';
    return null;
  }

  static String _decode(String raw) => raw
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}

const _monthNames = {
  'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
  'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
};

/// RFC 1123，形如 `Sun, 06 Nov 1994 08:49:37 GMT`。解析不了返回 null。
DateTime? parseHttpDate(String? value) {
  if (value == null) return null;
  final match = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
          r'(\d{2}):(\d{2}):(\d{2})')
      .firstMatch(value.trim());
  if (match == null) return null;
  final month = _monthNames[match.group(2)!];
  if (month == null) return null;
  return DateTime.utc(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
}
