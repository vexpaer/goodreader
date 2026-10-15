import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/book.dart';
import '../../data/models/note.dart';
import '../../state/providers.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    ref.watch(notesControllerProvider);
    ref.watch(booksControllerProvider);

    final all = ref.read(notesControllerProvider).all();
    final notes = _query.isEmpty
        ? all
        : all
            .where((n) =>
                n.text.contains(_query) || n.note.contains(_query))
            .toList();

    final grouped = <String, List<BookNote>>{};
    for (final n in notes) {
      grouped.putIfAbsent(n.bookId, () => []).add(n);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记'),
        actions: [
          IconButton(
            tooltip: '导出全部笔记',
            icon: const Icon(Icons.ios_share),
            onPressed: notes.isEmpty ? null : () => _export(notes),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索划线或笔记内容',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: notes.isEmpty
                ? Center(
                    child: Text(
                      all.isEmpty ? '还没有笔记\n在阅读时长按选中文字即可高亮' : '没有匹配的笔记',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        height: 1.6,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      for (final entry in grouped.entries) ...[
                        _BookHeader(
                          book: ref.read(bookRepositoryProvider).byId(entry.key),
                          count: entry.value.length,
                        ),
                        for (final note in entry.value) _NoteTile(note: note),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(List<BookNote> notes) async {
    final buffer = StringBuffer()
      ..writeln('GoodReader 笔记导出')
      ..writeln('导出时间：${DateTime.now()}')
      ..writeln('共 ${notes.length} 条')
      ..writeln();

    for (final n in notes) {
      final book = ref.read(bookRepositoryProvider).byId(n.bookId);
      buffer
        ..writeln('【${book?.title ?? '未知书籍'}】第 ${n.chapterIndex + 1} 章');
      if (n.text.isNotEmpty) buffer.writeln('原文：${n.text}');
      if (n.note.isNotEmpty) buffer.writeln('笔记：${n.note}');
      buffer.writeln();
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制 ${notes.length} 条笔记到剪贴板')),
    );
  }
}

class _BookHeader extends StatelessWidget {
  const _BookHeader({required this.book, required this.count});

  final Book? book;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: [
          const Icon(Icons.menu_book, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              book?.title ?? '已删除的书籍',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends ConsumerWidget {
  const _NoteTile({required this.note});

  final BookNote note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.redAccent,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) =>
          ref.read(notesControllerProvider).remove(note.id),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          leading: Icon(switch (note.type) {
            NoteType.highlight => Icons.brush_outlined,
            NoteType.bookmark => Icons.bookmark_border,
            NoteType.thought => Icons.edit_note,
          }),
          title: Text(
            note.text.isEmpty ? note.note : note.text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '第 ${note.chapterIndex + 1} 章'
            '${note.note.isEmpty ? '' : '\n${note.note}'}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: note.note.isNotEmpty,
        ),
      ),
    );
  }
}
