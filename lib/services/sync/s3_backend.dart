import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:goodreader/services/http_transport.dart';
import 'package:goodreader/services/sync/sync_backend.dart';
import 'package:xml/xml.dart';

/// S3 后端，用 SigV4 签名。
///
/// 地址按**路径风格**解析：`https://s3.us-east-1.amazonaws.com/我的桶`。路径风格
/// 对 AWS 与 MinIO、Cloudflare R2、七牛这些兼容实现都一样有效；虚拟主机风格在
/// 自建服务上常常配不出域名。区域从主机名里认，认不出就用 us-east-1。
///
/// S3 没有目录，`ensureDirectory` 什么都不做；列目录靠 `list-type=2` 加
/// `delimiter=/`，拿到的就是直接子对象。
class S3Backend extends SyncBackend {
  S3Backend({
    required this.baseUrl,
    required this.accessKey,
    required this.secretKey,
    String? region,
    HttpTransport? transport,
    DateTime Function()? clock,
  })  : region = region ?? regionOf(baseUrl),
        _transport = transport ?? const IoHttpTransport(),
        _clock = clock ?? DateTime.now;

  final String baseUrl;
  final String accessKey;
  final String secretKey;
  final String region;
  final HttpTransport _transport;
  final DateTime Function() _clock;

  static final emptyPayloadHash = sha256.convert(const <int>[]).toString();

  /// 从主机名里认区域。`s3.us-west-2.amazonaws.com` 与
  /// `s3-us-west-2.amazonaws.com` 两种写法都认。
  static String regionOf(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    final match =
        RegExp(r'^s3[.-]([a-z0-9-]+)\.amazonaws\.com$').firstMatch(host);
    return match?.group(1) ?? 'us-east-1';
  }

  /// 拼目标地址。[rawQuery] 必须是已经按 SigV4 规则编码并排序好的字符串。
  ///
  /// 不把查询参数交给 `Uri.replace(queryParameters:)`：那用的是表单编码，
  /// 空格会变成 `+`，`~` 会被转义，而签名要求的是 RFC 3986。自己编码一次，
  /// 线上发的和签名用的就是同一串字节。
  Uri _url(String path, [String? rawQuery]) {
    final root = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final tail = path.startsWith('/') ? path.substring(1) : path;
    final url = Uri.parse('$root$tail');
    return rawQuery == null ? url : url.replace(query: rawQuery);
  }

  /// 签名用的主机头。带非默认端口时要一起签，否则服务端算出来的对不上。
  String get _host {
    final url = Uri.parse(baseUrl);
    return url.hasPort ? '${url.host}:${url.port}' : url.host;
  }

  @override
  Future<void> ensureDirectory(String path) async {
    // S3 是平坦的对象空间，没有目录可建。
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final prefix = path.endsWith('/') ? path : '$path/';
    final query = canonicalQueryOf({
      'list-type': '2',
      'prefix': prefix,
      'delimiter': '/',
    });
    return guard(() async {
      final response = await _transport.get(
        _url('', query),
        headers: _headers('GET', _url('', query), query),
      );
      if (response.statusCode == 404) return const [];
      if (response.statusCode >= 400) {
        throw SyncException(_describe('读取目录', response));
      }
      return parseList(response.body, prefix);
    });
  }

  @override
  Future<void> put(String path, String content) => guard(() async {
        final url = _url(path);
        final response = await _transport.put(
          url,
          headers: {
            ..._headers('PUT', url, '', payload: content),
            'content-type': 'application/json',
          },
          body: content,
        );
        if (response.statusCode >= 400) {
          throw SyncException(_describe('上传', response));
        }
      });

  @override
  Future<String?> get(String path) => guard(() async {
        final url = _url(path);
        final response = await _transport.get(
          url,
          headers: _headers('GET', url, ''),
        );
        if (response.statusCode == 404) return null;
        if (response.statusCode >= 400) {
          throw SyncException(_describe('下载', response));
        }
        return response.body;
      });

  @override
  Future<void> delete(String path) => guard(() async {
        final url = _url(path);
        final response = await _transport.delete(
          url,
          headers: _headers('DELETE', url, ''),
        );
        if (response.statusCode >= 400 && response.statusCode != 404) {
          throw SyncException(_describe('删除', response));
        }
      });

  Map<String, String> _headers(
    String method,
    Uri url,
    String canonicalQuery, {
    String? payload,
  }) {
    final payloadHash = payload == null
        ? emptyPayloadHash
        : sha256.convert(utf8.encode(payload)).toString();
    final now = _clock().toUtc();
    return {
      'authorization': authorizationHeader(
        method: method,
        canonicalUri: canonicalUriOf(url),
        canonicalQuery: canonicalQuery,
        host: _host,
        payloadHash: payloadHash,
        now: now,
        region: region,
        accessKey: accessKey,
        secretKey: secretKey,
      ),
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDateOf(now),
    };
  }

  /// 参与签名的绝对路径，逐段百分号编码，斜杠保留。
  ///
  /// 用 `pathSegments`（已解码）重新编码，而不是用 `path`（仍带编码）：
  /// 桶名和对象键都可能含中文，S3 要求签名用编码后的形式，拿原样字符串签
  /// 会在中文文件名上得到 403。
  static String canonicalUriOf(Uri url) =>
      '/${url.pathSegments.map(percentEncode).join('/')}';

  /// 按 key 排序并逐项编码的查询串。S3 要求顺序与编码都严格一致。
  static String canonicalQueryOf(Map<String, String> query) {
    final keys = query.keys.toList()..sort();
    return keys
        .map((k) => '${percentEncode(k)}=${percentEncode(query[k]!)}')
        .join('&');
  }

  static String amzDateOf(DateTime utc) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}${two(utc.day)}'
        'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  /// RFC 3986 的 unreserved 集合。`Uri.encodeComponent` 会放过 `!*'()`，
  /// 那四个字符在 SigV4 里必须编码，所以不能直接用它。
  static String percentEncode(String value) {
    const unreserved =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~';
    final buffer = StringBuffer();
    for (final byte in utf8.encode(value)) {
      final char = String.fromCharCode(byte);
      if (byte < 128 && unreserved.contains(char)) {
        buffer.write(char);
      } else {
        buffer.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return buffer.toString();
  }

  /// 算 Authorization 头。纯函数，测试直接打这里。
  static String authorizationHeader({
    required String method,
    required String canonicalUri,
    required String canonicalQuery,
    required String host,
    required String payloadHash,
    required DateTime now,
    required String region,
    required String accessKey,
    required String secretKey,
  }) {
    final amzDate = amzDateOf(now);
    final dateStamp = amzDate.substring(0, 8);

    const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';
    final canonicalHeaders =
        'host:$host\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate\n';

    final canonicalRequest = [
      method,
      canonicalUri,
      canonicalQuery,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final scope = '$dateStamp/$region/s3/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final signature = Hmac(sha256, _signingKey(secretKey, dateStamp, region))
        .convert(utf8.encode(stringToSign))
        .toString();

    return 'AWS4-HMAC-SHA256 '
        'Credential=$accessKey/$scope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';
  }

  static List<int> _signingKey(String secret, String dateStamp, String region) {
    List<int> step(List<int> key, String message) =>
        Hmac(sha256, key).convert(utf8.encode(message)).bytes;
    final date = step(utf8.encode('AWS4$secret'), dateStamp);
    final regional = step(date, region);
    final service = step(regional, 's3');
    return step(service, 'aws4_request');
  }

  /// 从 ListBucketResult 里取文件条目。目录条目在 CommonPrefixes 里，跳过。
  ///
  /// 按 local name 匹配而不是用 `findAllElements('Contents')`：S3 的响应带默认
  /// 命名空间，有些兼容实现还会加前缀（`<d:Contents>`），按限定名匹配会漏。
  static List<RemoteEntry> parseList(String body, String prefix) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(body);
    } on XmlException {
      return const [];
    }
    final entries = <RemoteEntry>[];
    for (final node in document.descendants.whereType<XmlElement>()) {
      if (node.name.local != 'Contents') continue;
      final key = _childText(node, 'Key');
      if (key == null || key.isEmpty || key.endsWith('/')) continue;
      final name = key.startsWith(prefix) ? key.substring(prefix.length) : key;
      if (name.isEmpty || name.contains('/')) continue;
      entries.add(RemoteEntry(
        path: name,
        size: int.tryParse(_childText(node, 'Size') ?? '') ?? 0,
        modified: DateTime.tryParse(_childText(node, 'LastModified') ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      ));
    }
    return entries;
  }

  static String? _childText(XmlElement parent, String name) {
    for (final child in parent.childElements) {
      if (child.name.local == name) return child.innerText;
    }
    return null;
  }

  /// 把 S3 的错误 XML 压成一句人话。403 基本只有一种原因。
  static String _describe(String action, TransportResponse response) {
    if (response.statusCode == 403) {
      return '$action失败：凭据被拒绝（403），检查 Access Key 与 Secret';
    }
    if (response.statusCode == 404) {
      return '$action失败：桶不存在或地址写错（404）';
    }
    final code = RegExp(r'<Code>([^<]+)</Code>').firstMatch(response.body);
    if (code != null) {
      return '$action失败：${code.group(1)}（HTTP ${response.statusCode}）';
    }
    return '$action失败，HTTP ${response.statusCode}';
  }
}
