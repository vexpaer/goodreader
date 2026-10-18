import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/book.dart';
import '../../data/models/chapter.dart';
import '../../services/booksource/book_source.dart';
import '../../services/booksource/book_source_engine.dart';
import '../../services/booksource/source_document.dart';
import '../../state/providers.dart';

/// 在某个书源里搜索，并把结果加入书架。
class BookSourceSearchPage extends ConsumerStatefulWidget {
  const BookSourceSearchPage({super.key, required this.sourceId});

  final String sourceId;

  @override
  ConsumerState<BookSourceSearchPage> createState() =>
      _BookSourceSearchPageState();
}

class _BookSourceSearchPageState extends ConsumerState<BookSourceSearchPage> {
  final _controller = TextEditingController();

  BookSource? _source;
  List<SourceSearchResult> _results = const [];
  String? _error;
  bool _searching = false;
  bool _added = false;
  String? _addingUrl;

  @override
  void initState() {
    super.initState();
    _source = ref.read(bookSourceRepositoryProvider).byId(widget.sourceId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    if (source == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('搜索')),
        body: const Center(child: Text('书源不存在，可能已被删除')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(source.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '书名或作者',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  onPressed: _searching ? null : _search,
                  icon: _searching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_added)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 6),
                  const Expanded(child: Text('已加入书架')),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('去书架'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _searching ? '正在搜索…' : '输入关键词开始搜索',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      final busy = _addingUrl == result.url;
                      return ListTile(
                        title: Text(result.title, maxLines: 2),
                        subtitle: Text(
                          [
                            if (result.author.isNotEmpty) result.author,
                            if (result.intro.isNotEmpty) result.intro,
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_circle_outline),
                        onTap: busy ? null : () => _add(result),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _search() async {
    final source = _source;
    final keyword = _controller.text.trim();
    if (source == null || keyword.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
      _results = const [];
    });

    try {
      final results =
          await BookSourceEngine(source: source).search(keyword);
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) _error = '没有搜到结果';
      });
    } on BookSourceException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '搜索失败：$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(SourceSearchResult result) async {
    final source = _source;
    if (source == null) return;

    setState(() {
      _addingUrl = result.url;
      _error = null;
    });

    try {
      final chapters = await SourceDocument.fetchChapters(
        source: source,
        bookUrl: result.url,
      );
      if (!mounted) return;

      // 同一个书源里的同一个地址永远得到同一个 id，重复加入是更新而不是新增。
      final id = md5
          .convert('${source.id}|${result.url}'.codeUnits)
          .toString();
      final book = Book(
        id: id,
        title: result.title,
        author: result.author,
        intro: result.intro,
        filePath: SourceBookRef(sourceId: source.id, bookUrl: result.url).encode(),
        format: BookFormat.web,
        chapterCount: chapters.length,
      );

      await ref.read(booksControllerProvider).save(book);
      await ref.read(bookRepositoryProvider).saveChapters(
            ChapterList(bookId: id, chapters: chapters),
          );

      if (!mounted) return;
      setState(() {
        _added = true;
        _addingUrl = null;
      });
    } on BookSourceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _addingUrl = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加入失败：$e';
        _addingUrl = null;
      });
    }
  }
}
