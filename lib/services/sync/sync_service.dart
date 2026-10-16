import 'dart:convert';

import 'package:goodreader/services/sync/sync_backend.dart';

/// 一份可同步的数据文档。[path] 是云端文件名，[payload] 是 JSON 文本。
class SyncDocument {
  SyncDocument({required this.path, required this.payload});

  final String path;
  String payload;
}

/// 一次比较的结论。四种状态不能合并成一个可空字段，否则「两边一致」和
/// 「时间戳读不出来」会被混为一谈，而这两种情况的处理完全不同。
enum SyncVerdict {
  /// 两边完全一致，什么都不做。
  identical,

  /// 本地较新，上传。
  upload,

  /// 云端较新，下载并应用。
  download,

  /// 时间戳缺失，无法判断，保持原样。
  unknown,
}

/// 同步编排。只认识文档，不认识 WebDAV 还是 S3。
class SyncService {
  const SyncService();

  /// 本地文档由调用方从各仓储汇总，[apply] 在需要采纳云端版本时被调用。
  ///
  /// 冲突（两端都改过同一条）按较新的一侧胜出，只计数不打断同步。
  /// 静默丢数据比弹窗让用户一直点确定好。
  Future<SyncReport> run({
    required SyncBackend backend,
    required List<SyncDocument> local,
    required void Function(SyncDocument) apply,
    String directory = 'goodreader',
  }) async {
    var uploaded = 0;
    var downloaded = 0;
    var conflicts = 0;

    await backend.ensureDirectory(directory);
    final remoteNames = {
      for (final entry in await backend.list(directory)) entry.path,
    };
    final localNames = {for (final document in local) document.path};

    for (final document in local) {
      final remote = await backend.get('$directory/${document.path}');
      final verdict = compare(document.payload, remote);

      switch (verdict) {
        case SyncVerdict.identical:
          break;
        case SyncVerdict.upload:
          await backend.put('$directory/${document.path}', document.payload);
          uploaded++;
        case SyncVerdict.download:
          document.payload = remote!;
          apply(document);
          downloaded++;
        case SyncVerdict.unknown:
          break;
      }

      if (remote != null && verdict != SyncVerdict.identical) conflicts++;
    }

    for (final name in remoteNames.difference(localNames)) {
      final content = await backend.get('$directory/$name');
      if (content == null) continue;
      apply(SyncDocument(path: name, payload: content));
      downloaded++;
    }

    return SyncReport(
      uploaded: uploaded,
      downloaded: downloaded,
      conflicts: conflicts,
      message: '上传 $uploaded 项，下载 $downloaded 项',
    );
  }

  /// 比较本地与云端。[remote] 为 null 表示云端没有这份文档。
  SyncVerdict compare(String local, String? remote) {
    if (remote == null) return SyncVerdict.upload;
    if (remote == local) return SyncVerdict.identical;
    final localStamp = stampOf(local);
    final remoteStamp = stampOf(remote);
    if (localStamp == null || remoteStamp == null) return SyncVerdict.unknown;
    return localStamp.isAfter(remoteStamp) ? SyncVerdict.upload : SyncVerdict.download;
  }

  /// 文档里记的更新时间。解析不了返回 null，调用方据此放弃这一条。
  static DateTime? stampOf(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      final raw = decoded['updatedAt'];
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    } on FormatException {
      return null;
    }
  }

  /// 拼一份带更新时间的文档。
  static SyncDocument document(String path, Object body) {
    final map = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    map['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    return SyncDocument(path: path, payload: jsonEncode(map));
  }
}
