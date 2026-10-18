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

/// 一次同步的结果统计。
///
/// [diverged] 是两端内容不同、由时间戳定胜负的条目数。没有基线版本时无法
/// 区分「只有一侧改过」和「两侧都改过」，所以不叫冲突，只叫分歧。
class SyncReport {
  const SyncReport({
    this.uploaded = 0,
    this.downloaded = 0,
    this.diverged = 0,
    this.message = '',
  });

  final int uploaded;
  final int downloaded;
  final int diverged;
  final String message;

  bool get isEmpty => uploaded == 0 && downloaded == 0 && diverged == 0;
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

  /// 所有后端共用的异常包装。少包一条路径，那种失败就会从调用方的 catch 漏过。
  Future<T> guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on TransportException catch (e) {
      throw SyncException(e.message);
    }
  }
}
