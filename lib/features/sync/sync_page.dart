import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/service_endpoint.dart';
import '../../services/sync/backend_factory.dart';
import '../../services/sync/library_sync.dart';
import '../../services/sync/sync_backend.dart';
import '../../services/sync/sync_service.dart';
import '../../services/sync/sync_state_store.dart';
import '../../state/providers.dart';
import '../services/service_providers_page.dart';

/// 云同步。同步的是书目、进度、笔记与设置，不包含书籍文件本身。
class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  final _service = const SyncService();
  final _state = SyncStateStore();

  bool _running = false;
  SyncReport? _report;
  String? _error;
  DateTime? _lastRunAt;
  String _lastMessage = '';

  @override
  void initState() {
    super.initState();
    _lastRunAt = _state.lastRunAt;
    _lastMessage = _state.lastMessage;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(serviceProviderRepositoryProvider);
    final endpoint = repo.activeOf(ServiceKind.sync);
    // 密钥不在端点记录里，要单独取。
    final secret = endpoint == null ? '' : repo.readSecret(endpoint.id);
    final library = LibrarySync(
      books: ref.read(bookRepositoryProvider),
      notes: ref.read(noteRepositoryProvider),
    );
    final documents = library.collect();

    return Scaffold(
      appBar: AppBar(title: const Text('云同步')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (endpoint == null)
            SizedBox(
              height: 380,
              child: NoServiceHint(
                kind: ServiceKind.sync,
                onConfigure: () => context.push('/services'),
              ),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(endpoint.label),
              subtitle: Text(
                '${endpoint.normalizedBaseUrl}\n'
                '${_backendLabel(endpoint)} · 密钥 ${secret.isEmpty ? '未填写' : '已填写'}',
              ),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: () => context.push('/services'),
                child: const Text('切换'),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: FilledButton.icon(
                onPressed: _running ? null : () => _run(endpoint, secret),
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(_running ? '正在同步' : '立即同步'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '本机 ${documents.length} 份文档待比较',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _Banner(
                  icon: Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  title: '同步失败',
                  body: _error!,
                ),
              ),
            if (_report != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _Banner(
                  icon: Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                  title: _report!.isEmpty ? '已经是最新的' : '同步完成',
                  body: _describeReport(_report!),
                ),
              )
            else if (_lastRunAt != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _Banner(
                  icon: Icons.history,
                  color: Theme.of(context).colorScheme.outline,
                  title: '上次同步 ${_formatTime(_lastRunAt!)}',
                  body: _lastMessage,
                ),
              ),
          ],
          const SizedBox(height: 24),
          const Divider(height: 1),
          const _Notes(),
        ],
      ),
    );
  }

  Future<void> _run(ServiceEndpoint endpoint, String secret) async {
    setState(() {
      _running = true;
      _error = null;
      _report = null;
    });

    final library = LibrarySync(
      books: ref.read(bookRepositoryProvider),
      notes: ref.read(noteRepositoryProvider),
    );

    try {
      final backend = buildSyncBackend(endpoint, secret: secret);
      final report = await _service.run(
        backend: backend,
        local: library.collect(),
        apply: library.apply,
      );
      final at = DateTime.now();
      await _state.record(at, _describeReport(report));
      if (!mounted) return;
      setState(() {
        _report = report;
        _lastRunAt = at;
        _lastMessage = _describeReport(report);
      });
    } on SyncException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '同步中断：$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  static String _describeReport(SyncReport report) {
    final parts = <String>[];
    if (report.uploaded > 0) parts.add('上传 ${report.uploaded} 项');
    if (report.downloaded > 0) parts.add('下载 ${report.downloaded} 项');
    if (report.diverged > 0) parts.add('${report.diverged} 项两端都有改动，按较新一侧合并');
    return parts.isEmpty ? '没有需要传输的改动' : parts.join('，');
  }

  static String _backendLabel(ServiceEndpoint endpoint) =>
      endpoint.model.trim().toLowerCase() == 's3' ? 'S3' : 'WebDAV';

  static String _formatTime(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${at.month}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(body, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('同步什么', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final line in const [
            '书目：书名、作者、标签、收藏、系列',
            '进度：读到第几章、章内位置、总进度',
            '笔记：划线、想法、书签',
            '设置：阅读排版与应用偏好',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('· $line', style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 14),
          Text('不同步什么', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final line in const [
            '书籍文件与封面：换设备后请自行导入同一本书',
            '服务密钥：只在本机，不参与任何上传',
            '阅读统计：各设备各记各的，避免重复累加',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('· $line', style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 14),
          Text(
            '冲突按较新的一侧胜出。删除不会同步到其它设备：本地删掉的条目，'
            '下一次同步会被云端版本拉回来。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
