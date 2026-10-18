import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/book.dart';
import '../../data/models/note.dart';
import '../../state/providers.dart';
import '../bookshelf/widgets/book_cover.dart';
import '../share/poster/poster_page.dart';
import '../share/poster/poster_spec.dart';

class BookDetailPage extends ConsumerWidget {
  const BookDetailPage({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(booksControllerProvider);
    ref.watch(notesControllerProvider);

    final book = ref.watch(bookByIdProvider(bookId));
    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('书籍不存在或已被删除')),
      );
    }

    final notes = ref.read(notesControllerProvider).forBook(bookId);
    final stats = ref.read(statsControllerProvider).allTime();
    final seconds = stats.byBook[bookId] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '分享卡片',
            icon: const Icon(Icons.ios_share),
            onPressed: () =>
                openPoster(context, specForBook(book), book: book),
          ),
          IconButton(
            tooltip: book.isFavorite ? '取消收藏' : '收藏',
            icon: Icon(book.isFavorite ? Icons.favorite : Icons.favorite_border),
            onPressed: () =>
                ref.read(booksControllerProvider).toggleFavorite(book),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(book: book, width: 110, height: 158),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.displayAuthor,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(context, book.format.label),
                        _pill(context, '${book.chapterCount} 章'),
                        _pill(context, _humanSize(book.fileSize)),
                        _pill(context, '${(book.progress * 100).toStringAsFixed(0)}%'),
                        _pill(context, _humanDuration(seconds)),
                        if (book.isPrivate) _pill(context, '私密'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => context.push('/reader/${book.id}'),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(book.progress > 0 ? '继续阅读' : '开始阅读'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (book.intro.trim().isNotEmpty) ...[
            const _Heading('简介'),
            Text(book.intro, style: const TextStyle(height: 1.7)),
            const SizedBox(height: 20),
          ],
          if (book.tags.isNotEmpty) ...[
            const _Heading('标签'),
            Wrap(
              spacing: 8,
              children: book.tags.map((t) => Chip(label: Text(t))).toList(),
            ),
            const SizedBox(height: 20),
          ],
          _Heading('阅读数据'),
          _KeyValue('阅读时长', _humanDuration(seconds)),
          _KeyValue('阅读进度', '${(book.progress * 100).toStringAsFixed(1)}%'),
          _KeyValue(
            '最近阅读',
            book.lastReadAt == null
                ? '尚未阅读'
                : '${book.lastReadAt!.year}-${book.lastReadAt!.month.toString().padLeft(2, '0')}-${book.lastReadAt!.day.toString().padLeft(2, '0')}',
          ),
          _KeyValue('添加时间',
              '${book.addedAt.year}-${book.addedAt.month.toString().padLeft(2, '0')}-${book.addedAt.day.toString().padLeft(2, '0')}'),
          _KeyValue('文件编码', book.encoding.toUpperCase()),
          const SizedBox(height: 20),
          _Heading('笔记与书签（${notes.length}）'),
          if (notes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('暂无笔记', style: TextStyle(color: Colors.grey)),
            )
          else
            ...notes.take(20).map(
                  (n) => Card(
                    child: ListTile(
                      leading: Icon(_noteIcon(n.type)),
                      title: Text(
                        n.text.isEmpty ? n.note : n.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '第 ${n.chapterIndex + 1} 章'
                        '${n.note.isEmpty ? '' : ' · ${n.note}'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  static IconData _noteIcon(NoteType type) => switch (type) {
        NoteType.highlight => Icons.brush_outlined,
        NoteType.bookmark => Icons.bookmark_border,
        NoteType.thought => Icons.edit_note,
      };

  static Widget _pill(BuildContext context, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11)),
      );

  static String _humanSize(int bytes) {
    if (bytes <= 0) return '未知大小';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static String _humanDuration(int seconds) {
    if (seconds <= 0) return '0 分钟';
    if (seconds < 60) return '$seconds 秒';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    return '$hours 小时 ${minutes % 60} 分';
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      );
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
