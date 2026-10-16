import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../services/update_service.dart';
import '../../state/providers.dart';

/// Settings page that checks GitHub Releases for a newer build, downloads the
/// APK and hands it to the system installer.
class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key});

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
  UpdateCheckResult? _result;
  bool _checking = false;

  bool _downloading = false;
  int _received = 0;
  int _total = 0;
  File? _downloaded;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _downloaded = null;
      _downloadError = null;
    });
    final result = await ref.read(updateServiceProvider).check();
    if (!mounted) return;
    setState(() {
      _result = result;
      _checking = false;
    });
  }

  Future<void> _download(ReleaseInfo release) async {
    final asset = release.preferredApk;
    if (asset == null) {
      setState(() => _downloadError = '该版本没有附带 APK 文件');
      return;
    }
    setState(() {
      _downloading = true;
      _received = 0;
      _total = asset.size;
      _downloadError = null;
    });

    try {
      final file = await ref.read(updateServiceProvider).downloadApk(
            asset,
            onProgress: (received, total) {
              if (!mounted) return;
              setState(() {
                _received = received;
                _total = total;
              });
            },
          );
      if (!mounted) return;
      setState(() {
        _downloaded = file;
        _downloading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _downloadError = '$e';
      });
    }
  }

  Future<void> _install() async {
    final file = _downloaded;
    if (file == null) return;
    final started = await ref.read(nativeServiceProvider).installApk(file.path);
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法唤起安装程序，请检查是否允许「安装未知应用」'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('检查更新'),
        actions: [
          IconButton(
            tooltip: '重新检查',
            icon: const Icon(Icons.refresh),
            onPressed: _checking ? null : _check,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.menu_book, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('GoodReader',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          '当前版本 ${AppInfo.displayVersion}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_checking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (result == null)
            const SizedBox.shrink()
          else
            _buildResult(context, result),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, UpdateCheckResult result) {
    switch (result.status) {
      case UpdateStatus.failed:
        return _Banner(
          icon: Icons.cloud_off,
          color: Theme.of(context).colorScheme.error,
          title: '检查失败',
          body: result.message ?? '未知错误',
          action: TextButton(
            onPressed: _check,
            child: const Text('重试'),
          ),
        );

      case UpdateStatus.upToDate:
        return _Banner(
          icon: Icons.check_circle_outline,
          color: Colors.green,
          title: '已是最新版本',
          body: result.release == null
              ? '当前已是最新发布版本。'
              : '最新发布版本为 ${result.release!.tag}。',
          action: TextButton(
            onPressed: () => ref
                .read(nativeServiceProvider)
                .openUrl(AppInfo.releasesUrl),
            child: const Text('查看全部版本'),
          ),
        );

      case UpdateStatus.updateAvailable:
        final release = result.release!;
        final asset = release.preferredApk;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(
              icon: Icons.system_update_alt,
              color: Theme.of(context).colorScheme.primary,
              title: '发现新版本 ${release.tag}',
              body: release.publishedAt == null
                  ? '可以下载更新。'
                  : '发布于 ${_formatDate(release.publishedAt!)}',
            ),
            const SizedBox(height: 16),
            if (asset != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.android),
                  title: Text(asset.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(asset.size > 0 ? asset.sizeLabel : '点击下方按钮开始下载'),
                ),
              ),
            const SizedBox(height: 16),
            if (_downloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _total > 0 ? _received / _total : null,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _total > 0
                    ? '已下载 ${_humanSize(_received)} / ${_humanSize(_total)}'
                    : '已下载 ${_humanSize(_received)}',
                style: const TextStyle(fontSize: 12),
              ),
            ] else if (_downloaded != null) ...[
              _Banner(
                icon: Icons.download_done,
                color: Colors.green,
                title: '下载完成',
                body: _downloaded!.path.split(Platform.pathSeparator).last,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _install,
                icon: const Icon(Icons.install_mobile),
                label: const Text('立即安装'),
              ),
              const SizedBox(height: 8),
              Text(
                '若系统提示不允许安装，请在设置中允许 GoodReader 安装未知应用。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ] else if (asset != null) ...[
              FilledButton.icon(
                onPressed: () => _download(release),
                icon: const Icon(Icons.download),
                label: Text(asset.size > 0
                    ? '下载 APK（${asset.sizeLabel}）'
                    : '下载 APK'),
              ),
            ],
            if (_downloadError != null) ...[
              const SizedBox(height: 12),
              _Banner(
                icon: Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                title: '下载失败',
                body: _downloadError!,
              ),
            ],
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () =>
                  ref.read(nativeServiceProvider).openUrl(release.pageUrl),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('在浏览器中打开该版本'),
            ),
            const Divider(height: 32),
            const Text('更新内容',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            SelectableText(
              plainReleaseNotes(release.notes).isEmpty
                  ? '该版本没有提供更新说明。'
                  : plainReleaseNotes(release.notes),
              style: const TextStyle(fontSize: 13, height: 1.65),
            ),
          ],
        );
    }
  }

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 6),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
