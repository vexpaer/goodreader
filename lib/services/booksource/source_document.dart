import 'package:goodreader/data/models/chapter.dart';
import 'package:goodreader/features/reader/engines/document.dart';
import 'package:goodreader/services/booksource/book_source.dart';
import 'package:goodreader/services/booksource/book_source_engine.dart';
import 'package:goodreader/services/http_transport.dart';

/// 把网络书接到阅读器上。
///
/// 目录在打开时就拿到（导入时已经存进 ChapterList，通常不用再抓），正文按章
/// 懒加载并缓存。不做整本下载：一千章的书全下完要几百次请求，而读者往往只看
/// 到前几章。
///
/// 全文搜索因此受限：只能搜章节标题和已经取过的正文。没取过的章节要搜就得先
/// 全部抓一遍，那是整本下载的代价，不做。
class SourceDocument implements ReaderDocument {
  SourceDocument({
    required this.source,
    required List<ChapterMeta> chapters,
    BookSourceEngine? engine,
  })  : _chapters = chapters,
        _engine = engine ?? BookSourceEngine(source: source);

  final BookSource source;
  final BookSourceEngine _engine;
  final List<ChapterMeta> _chapters;
  final Map<int, String> _cache = {};

  @override
  List<ChapterMeta> get chapters => _chapters;

  /// 打开一本书。[chapters] 是导入时存下的目录，传空则现在去抓。
  static Future<SourceDocument> open({
    required BookSource source,
    required String bookUrl,
    List<ChapterMeta>? chapters,
    HttpTransport? transport,
  }) async {
    final engine = BookSourceEngine(source: source, transport: transport);
    var list = chapters ?? const <ChapterMeta>[];
    if (list.isEmpty) {
      final refs = await engine.chapters(bookUrl);
      list = [
        for (var i = 0; i < refs.length; i++)
          ChapterMeta(index: i, title: refs[i].title, href: refs[i].url),
      ];
    }
    return SourceDocument(source: source, chapters: list, engine: engine);
  }

  /// 抓目录，用于导入时落库。
  static Future<List<ChapterMeta>> fetchChapters({
    required BookSource source,
    required String bookUrl,
    HttpTransport? transport,
  }) async {
    final refs = await BookSourceEngine(source: source, transport: transport)
        .chapters(bookUrl);
    return [
      for (var i = 0; i < refs.length; i++)
        ChapterMeta(index: i, title: refs[i].title, href: refs[i].url),
    ];
  }

  @override
  Future<String> chapterText(int index) async {
    if (index < 0 || index >= _chapters.length) {
      throw const BookSourceException('章节不存在');
    }
    final cached = _cache[index];
    if (cached != null) return cached;

    final href = _chapters[index].href;
    if (href == null || href.isEmpty) {
      throw const BookSourceException('这一章没有链接，可能是目录规则漏了');
    }
    final text = await _engine.content(href);
    _cache[index] = text;
    return text;
  }

  /// 搜章节标题与已缓存的正文。
  @override
  Future<List<SearchHit>> search(String query, {int limit = 200}) async {
    final term = query.trim();
    if (term.isEmpty) return const [];
    final lower = term.toLowerCase();
    final hits = <SearchHit>[];

    for (final chapter in _chapters) {
      if (chapter.title.toLowerCase().contains(lower)) {
        hits.add(SearchHit(
          chapterIndex: chapter.index,
          chapterTitle: chapter.title,
          start: 0,
          end: 0,
          snippet: chapter.title,
        ));
        if (hits.length >= limit) return hits;
      }
    }

    for (final entry in _cache.entries) {
      final text = entry.value;
      final haystack = text.toLowerCase();
      var from = 0;
      while (hits.length < limit) {
        final at = haystack.indexOf(lower, from);
        if (at < 0) break;
        hits.add(SearchHit(
          chapterIndex: entry.key,
          chapterTitle: _chapters[entry.key].title,
          start: at,
          end: at + term.length,
          snippet: buildSnippet(text, at, term.length),
        ));
        from = at + term.length;
      }
      if (hits.length >= limit) break;
    }

    hits.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    return hits;
  }
}
