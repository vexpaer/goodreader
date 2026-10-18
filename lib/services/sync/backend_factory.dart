import 'package:goodreader/data/models/service_endpoint.dart';
import 'package:goodreader/services/http_transport.dart';
import 'package:goodreader/services/sync/s3_backend.dart';
import 'package:goodreader/services/sync/sync_backend.dart';
import 'package:goodreader/services/sync/webdav_backend.dart';

/// 同步端点的两种配置约定，都塞在已有的字段里，不加新字段。
///
/// * `model` 选后端：`s3` 走 S3，其它值（含空）走 WebDAV。默认 WebDAV 是因为
///   自建网盘支持它的更多。
/// * `secret` 是 `账号:密钥`。WebDAV 填 `用户名:密码`，S3 填
///   `AccessKey:SecretKey`。只有一个冒号时前半段是账号；整串没有冒号就当作
///   只有密码，账号留空——有些 WebDAV 服务允许匿名或只认令牌。
class SyncCredentials {
  const SyncCredentials({required this.user, required this.secret});

  final String user;
  final String secret;

  static SyncCredentials parse(String raw) {
    final index = raw.indexOf(':');
    if (index < 0) return SyncCredentials(user: '', secret: raw);
    return SyncCredentials(
      user: raw.substring(0, index),
      secret: raw.substring(index + 1),
    );
  }
}

/// 按端点配置造一个后端。配置不全时抛 [SyncException]，界面直接把消息显示出来。
///
/// [secret] 单独传，不从端点上读：端点记录里本来就不存密钥（它存在另一个箱子里），
/// 由调用方显式去取。这样「密钥从哪来」在调用点看得见，不会有人以为端点自带。
SyncBackend buildSyncBackend(
  ServiceEndpoint endpoint, {
  required String secret,
  HttpTransport? transport,
}) {
  final baseUrl = endpoint.normalizedBaseUrl;
  if (baseUrl.isEmpty) {
    throw const SyncException('这个同步服务还没填地址');
  }
  final credentials = SyncCredentials.parse(secret);
  if (credentials.secret.isEmpty) {
    throw const SyncException('这个同步服务还没填密钥');
  }

  if (endpoint.model.trim().toLowerCase() == 's3') {
    return S3Backend(
      baseUrl: baseUrl,
      accessKey: credentials.user,
      secretKey: credentials.secret,
      transport: transport,
    );
  }

  return WebDavBackend(
    baseUrl: baseUrl,
    username: credentials.user,
    password: credentials.secret,
    transport: transport,
  );
}
