import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/booksource/book_source.dart';
import '../../state/providers.dart';

/// 书源列表。全部是声明式规则，没有脚本。
class BookSourcePage extends ConsumerStatefulWidget {
  const BookSourcePage({super.key});

  @override
  ConsumerState<BookSourcePage> createState() => _BookSourcePageState();
}

class _BookSourcePageState extends ConsumerState<BookSourcePage> {
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(bookSourceRepositoryProvider);
    final sources = repo.load();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('书源'),
        actions: [
          IconButton(
            tooltip: '导入',
            onPressed: () => _import(context),
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: '新建',
            onPressed: () => context.push('/sources/edit'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: sources.isEmpty
          ? _Empty(onCreate: () => context.push('/sources/edit'), onImport: () => _import(context))
          : ListView.separated(
              itemCount: sources.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final source = sources[index];
                return ListTile(
                  title: Text(source.name),
                  subtitle: Text(
                    '${source.baseUrl}\n${source.note.isEmpty ? source.charset.label : source.note}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  onTap: () => context.push('/sources/search/${source.id}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await context.push('/sources/edit/${source.id}');
                      } else if (value == 'delete') {
                        await _confirmDelete(source);
                      }
                      if (mounted) setState(() {});
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: sources.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  '共 ${sources.length} 个书源。点进去搜索，搜到的书可以直接加入书架。',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
    );
  }

  Future<void> _confirmDelete(BookSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除「${source.name}」？'),
        content: const Text('已经加入书架的书会打不开。书籍与笔记不会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(bookSourceRepositoryProvider).remove(source.id);
    if (mounted) setState(() {});
  }

  Future<void> _import(BuildContext context) async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入书源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('把书源 JSON 粘进来。支持单个对象或数组。'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '{"id": "...", "name": "...", ...}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final added = await ref.read(bookSourceRepositoryProvider).importJson(raw);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(added == 0 ? '这些书源都已经在了' : '新增 $added 个书源')),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：${e.message}')),
      );
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate, required this.onImport});

  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rss_feed, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('还没有书源', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '书源是一组取值规则，告诉应用从网页的哪个位置取书名、目录和正文。'
              '不执行脚本，所以不会有任意代码运行的风险。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('导入书源'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('手动新建'),
            ),
          ],
        ),
      ),
    );
  }
}
