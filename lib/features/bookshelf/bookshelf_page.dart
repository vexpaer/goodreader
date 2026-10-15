import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/book.dart';
import '../../data/repositories/settings_repository.dart';
import '../../state/providers.dart';
import 'widgets/book_cover.dart';

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  final _searchController = TextEditingController();
  bool _searching = false;
  bool _importing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final result = await ref.read(importControllerProvider).pickAndImport();
      if (!mounted) return;
      final parts = <String>[];
      if (result.imported.isNotEmpty) {
        parts.add('成功导入 ${result.imported.length} 本');
      }
      if (result.skipped.isNotEmpty) {
        parts.add('跳过 ${result.skipped.length} 个文件');
      }
      if (result.failed.isNotEmpty) {
        parts.add('失败 ${result.failed.length} 个');
      }
      final message = parts.isEmpty ? '未选择文件' : parts.join('，');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failed.isEmpty
                ? message
                : '$message\n${result.failed.first}',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导入失败：$e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(booksControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final books = controller.visible;
    final view = settings.app.shelfView;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索书名或作者',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: controller.setQuery,
              )
            : const Text('书架'),
        actions: [
          IconButton(
            tooltip: _searching ? '关闭搜索' : '搜索',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) {
                _searchController.clear();
                controller.setQuery('');
              }
            },
          ),
          PopupMenuButton<SortMode>(
            tooltip: '排序',
            icon: const Icon(Icons.sort),
            initialValue: controller.sortMode,
            onSelected: controller.setSort,
            itemBuilder: (context) => SortMode.values
                .map((m) => PopupMenuItem(value: m, child: Text(m.label)))
                .toList(),
          ),
          PopupMenuButton<ShelfView>(
            tooltip: '视图',
            icon: Icon(view == ShelfView.grid
                ? Icons.grid_view
                : view == ShelfView.list
                    ? Icons.view_list
                    : Icons.view_agenda),
            initialValue: view,
            onSelected: (v) =>
                ref.read(settingsControllerProvider).updateApp((s) => s.shelfView = v),
            itemBuilder: (context) => ShelfView.values
                .map((v) => PopupMenuItem(value: v, child: Text(v.label)))
                .toList(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _FilterBar(controller: controller),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _import,
        icon: _importing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_importing ? '导入中' : '导入图书'),
      ),
      body: books.isEmpty
          ? const _EmptyShelf()
          : switch (view) {
              ShelfView.grid => _GridView(books: books),
              ShelfView.list => _ListView(books: books, compact: false),
              ShelfView.compact => _ListView(books: books, compact: true),
            },
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.controller});

  final BooksController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = controller.allTags;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          FilterChip(
            label: const Text('收藏'),
            selected: controller.favoritesOnly,
            onSelected: controller.setFavoritesOnly,
          ),
          const SizedBox(width: 8),
          if (controller.tagFilter != null) ...[
            InputChip(
              label: Text(controller.tagFilter!),
              onDeleted: () => controller.setTagFilter(null),
            ),
            const SizedBox(width: 8),
          ],
          for (final tag in tags)
            if (tag != controller.tagFilter) ...[
              ActionChip(
                label: Text(tag),
                onPressed: () => controller.setTagFilter(tag),
              ),
              const SizedBox(width: 8),
            ],
          const SizedBox(width: 60),
        ],
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_outlined,
              size: 72, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('书架还是空的', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '点击右下角导入 TXT / EPUB 开始阅读',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _GridView extends StatelessWidget {
  const _GridView({required this.books});

  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 0.56,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
      ),
      itemCount: books.length,
      itemBuilder: (context, i) => _GridTile(book: books[i]),
    );
  }
}

class _GridTile extends ConsumerWidget {
  const _GridTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.watch(settingsControllerProvider).app.coverFill.boxFit;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/reader/${book.id}'),
      onLongPress: () => showBookActions(context, book),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  BookCover(
                    book: book,
                    width: c.maxWidth,
                    height: c.maxHeight,
                    fit: fit,
                  ),
                  if (book.progress > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(10),
                        ),
                        child: LinearProgressIndicator(
                          value: book.progress,
                          minHeight: 3,
                          backgroundColor: Colors.black26,
                        ),
                      ),
                    ),
                  if (book.isFavorite)
                    const Positioned(
                      right: 6,
                      top: 6,
                      child: Icon(Icons.favorite,
                          size: 14, color: Colors.redAccent),
                    ),
                  if (book.progress > 0 && book.progress < 1)
                    Positioned(
                      right: 6,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${(book.progress * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            book.displayAuthor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.books, required this.compact});

  final List<Book> books;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final book = books[i];
        return ListTile(
          leading: compact
              ? null
              : BookCover(book: book, width: 44, height: 60, radius: 6),
          title: Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            compact
                ? book.displayAuthor
                : '${book.displayAuthor} · ${(book.progress * 100).toStringAsFixed(0)}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: book.isFavorite
              ? const Icon(Icons.favorite, size: 18, color: Colors.redAccent)
              : null,
          onTap: () => context.push('/reader/${book.id}'),
          onLongPress: () => showBookActions(context, book),
        );
      },
    );
  }
}

/// Shared long-press action sheet.
Future<void> showBookActions(BuildContext context, Book book) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => _BookActionSheet(book: book),
  );
}

class _BookActionSheet extends ConsumerWidget {
  const _BookActionSheet({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(booksControllerProvider);
    final importer = ref.read(importServiceProvider);
    final current = ref.read(bookRepositoryProvider).byId(book.id) ?? book;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: Text(current.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${current.format.label} · ${current.chapterCount} 章'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('书籍详情'),
            onTap: () {
              Navigator.pop(context);
              context.push('/book/${current.id}');
            },
          ),
          ListTile(
            leading: Icon(current.isFavorite
                ? Icons.favorite
                : Icons.favorite_border),
            title: Text(current.isFavorite ? '取消收藏' : '加入收藏'),
            onTap: () {
              controller.toggleFavorite(current);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('编辑标签'),
            onTap: () async {
              Navigator.pop(context);
              await _editTags(context, ref, current);
            },
          ),
          ListTile(
            leading: Icon(current.isPrivate
                ? Icons.lock_open_outlined
                : Icons.lock_outline),
            title: Text(current.isPrivate ? '取消私密' : '设为私密书籍'),
            onTap: () {
              controller.togglePrivate(current);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('删除', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('删除书籍'),
                  content: Text('确定要删除《${current.title}》吗？该操作不可撤销。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('删除'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await controller.delete(current, importer: importer);
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editTags(
    BuildContext context,
    WidgetRef ref,
    Book book,
  ) async {
    final textController = TextEditingController(text: book.tags.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('编辑标签'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(hintText: '用逗号分隔，例如：小说, 待读'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, textController.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final tags = result
        .split(RegExp(r'[,，]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    await ref.read(booksControllerProvider).setTags(book, tags);
  }
}
