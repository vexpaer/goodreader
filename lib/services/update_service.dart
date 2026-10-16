import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/app_info.dart';

/// A downloadable artifact attached to a release.
class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.url,
    required this.size,
  });

  final String name;
  final String url;
  final int size;

  String get sizeLabel {
    if (size <= 0) return '未知大小';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// A published GitHub release.
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.notes,
    required this.pageUrl,
    required this.publishedAt,
    required this.assets,
  });

  final String tag;
  final String name;
  final String notes;
  final String pageUrl;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  /// Prefers the universal build, then arm64, then any APK.
  ReleaseAsset? get preferredApk {
    final apks = assets.where((a) => a.name.endsWith('.apk')).toList();
    if (apks.isEmpty) return null;
    for (final needle in ['universal', 'arm64-v8a', 'armeabi-v7a']) {
      final hit = apks.where((a) => a.name.contains(needle));
      if (hit.isNotEmpty) return hit.first;
    }
    return apks.first;
  }
}

/// Outcome of an update check.
enum UpdateStatus { upToDate, updateAvailable, failed }

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    this.release,
    this.message,
  });

  final UpdateStatus status;
  final ReleaseInfo? release;
  final String? message;
}

/// A dotted version such as `1.2.3`, comparable numerically.
class VersionNumber implements Comparable<VersionNumber> {
  VersionNumber(this.parts);

  final List<int> parts;

  static VersionNumber parse(String raw) {
    final cleaned = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final core = cleaned.split('+').first.split('-').first;
    final parts = core
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return VersionNumber(parts);
  }

  @override
  int compareTo(VersionNumber other) {
    final length = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < length; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  bool operator >(VersionNumber other) => compareTo(other) > 0;

  @override
  String toString() => parts.join('.');
}

/// Queries the GitHub releases API and downloads APK artifacts.
class UpdateService {
  const UpdateService();

  static const _userAgent = 'GoodReader-Android';

  Future<UpdateCheckResult> check() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(AppInfo.apiUrl));
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, _userAgent);

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 404) {
        return const UpdateCheckResult(
          status: UpdateStatus.failed,
          message: '仓库还没有发布任何版本',
        );
      }
      if (response.statusCode != 200) {
        return UpdateCheckResult(
          status: UpdateStatus.failed,
          message: '检查更新失败（HTTP ${response.statusCode}）',
        );
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final release = _parseRelease(json);
      final current = VersionNumber.parse(AppInfo.version);
      final latest = VersionNumber.parse(release.tag);

      return UpdateCheckResult(
        status: latest > current
            ? UpdateStatus.updateAvailable
            : UpdateStatus.upToDate,
        release: release,
      );
    } on SocketException {
      return const UpdateCheckResult(
        status: UpdateStatus.failed,
        message: '网络不可用，请检查连接后重试',
      );
    } catch (e) {
      return UpdateCheckResult(
        status: UpdateStatus.failed,
        message: '检查更新失败：$e',
      );
    } finally {
      client.close(force: true);
    }
  }

  ReleaseInfo _parseRelease(Map<String, dynamic> json) {
    final assets = <ReleaseAsset>[];
    final rawAssets = json['assets'];
    if (rawAssets is List) {
      for (final entry in rawAssets) {
        if (entry is! Map) continue;
        final name = entry['name'];
        final url = entry['browser_download_url'];
        if (name is! String || url is! String) continue;
        assets.add(ReleaseAsset(
          name: name,
          url: url,
          size: (entry['size'] as num?)?.toInt() ?? 0,
        ));
      }
    }

    DateTime? published;
    final publishedRaw = json['published_at'];
    if (publishedRaw is String) {
      published = DateTime.tryParse(publishedRaw);
    }

    return ReleaseInfo(
      tag: (json['tag_name'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      notes: (json['body'] as String?) ?? '',
      pageUrl: (json['html_url'] as String?) ?? AppInfo.releasesUrl,
      publishedAt: published,
      assets: assets,
    );
  }

  /// Downloads [asset] into app storage and returns the written file.
  Future<File> downloadApk(
    ReleaseAsset asset, {
    void Function(int received, int total)? onProgress,
    HttpClient? client,
  }) async {
    final owned = client ?? HttpClient();
    try {
      // Stored under the app's internal files directory so the FileProvider
      // declared in AndroidManifest can hand it to the package installer.
      final directory = Directory(
        '${(await getApplicationSupportDirectory()).path}/updates',
      );
      if (!directory.existsSync()) directory.createSync(recursive: true);

      final file = File('${directory.path}/${asset.name}');
      if (file.existsSync()) file.deleteSync();

      final request = await owned.getUrl(Uri.parse(asset.url));
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException('下载失败（HTTP ${response.statusCode}）');
      }

      final total = response.contentLength > 0
          ? response.contentLength
          : asset.size;
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
      } finally {
        await sink.close();
      }
      return file;
    } finally {
      if (client == null) owned.close(force: true);
    }
  }
}

/// Strips the most common Markdown markers so release notes read cleanly.
String plainReleaseNotes(String markdown) {
  var text = markdown.replaceAll('\r\n', '\n');
  text = text.replaceAllMapped(
      RegExp(r'^#{1,6}[ \t]*', multiLine: true), (_) => '');
  text = text.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1) ?? '');
  text = text.replaceAllMapped(
      RegExp(r'\*(.+?)\*'), (m) => m.group(1) ?? '');
  text = text.replaceAllMapped(
      RegExp(r'`(.+?)`'), (m) => m.group(1) ?? '');
  text = text.replaceAllMapped(
    RegExp(r'^[ \t]*[-*+][ \t]+', multiLine: true),
    (_) => '· ',
  );
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}
