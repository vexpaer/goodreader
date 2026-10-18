import 'dart:convert';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:goodreader/services/booksource/book_source.dart';
import 'package:goodreader/services/http_transport.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// 书源引擎自己的错误类型。界面直接显示 [message]。
class BookSourceException implements Exception {
  const BookSourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 搜索结果里的一条。
class SourceSearchResult {
  const SourceSearchResult({
    required this.title,
    required this.url,
    this.author = '',
    this.intro = '',
    this.coverUrl = '',
  });

  final String title;
  final String url;
  final String author;
  final String intro;
  final String coverUrl;
}

/// 目录里的一章。
class SourceChapterRef {
  const SourceChapterRef({required this.title, required this.url});

  final String title;
  final String url;
}

/// 按声明式规则把网页变成书目、目录与正文。
///
/// 只做四件事：抓页面、选节点、取值、拼正文。所有站点差异都在 [BookSource] 的
/// 规则里，引擎本身不认识任何具体网站。
class BookSourceEngine {
  BookSourceEngine({required this.source, HttpTransport? transport})
      : _transport = transport ?? const IoHttpTransport();

  final BookSource source;
  final HttpTransport _transport;

  static const _htmlAccept = {'accept': 'text/html,application/xhtml+xml'};

  /// 搜索。[page] 从 1 开始。
  Future<List<SourceSearchResult>> search(String keyword, {int page = 1}) async {
    final document = await _load(source.searchUri(keyword, page));
    final items = _select(document, source.listRule.selector);

    if (items.isEmpty) {
      // 页面里出现了关键词却一条都没选中，几乎一定是选择器写错了；页面里连
      // 关键词都没有，那是真的没有结果。两者混在一起会让用户不知道该改什么。
      // 用 body 的文本而不是 document.text：后者在 package:html 里对
      // Document 不保证包含后代文本，取不到时会静默判成「没有结果」。
      final pageText = document.body?.text ?? '';
      final hasKeyword = pageText.contains(keyword);
      if (hasKeyword) {
        throw BookSourceException('列表选择器没有匹配到任何条目，检查列表规则');
      }
      return const [];
    }

    final results = <SourceSearchResult>[];
    for (final item in items) {
      final title = _text(item, source.titleRule);
      if (title.isEmpty) continue;
      final href = _text(item, source.detailUrlRule);
      final url = source.resolve(href)?.toString() ?? '';
      if (url.isEmpty) continue;
      final cover = source.resolve(_text(item, source.coverRule))?.toString() ?? '';
      results.add(SourceSearchResult(
        title: title,
        url: url,
        author: _text(item, source.authorRule),
        intro: _text(item, source.introRule),
        coverUrl: cover,
      ));
    }
    return results;
  }

  /// 读取目录。[bookUrl] 是书籍详情页。
  Future<List<SourceChapterRef>> chapters(String bookUrl) async {
    final url = source.resolve(bookUrl);
    if (url == null) throw const BookSourceException('书籍地址不合法');

    final document = await _load(url);
    final items = _select(document, source.chapterListRule.selector);
    if (items.isEmpty) {
      throw const BookSourceException('目录选择器没有匹配到章节，检查目录规则');
    }

    final chapters = <SourceChapterRef>[];
    for (final item in items) {
      final title = _text(item, source.chapterTitleRule);
      final href = _text(item, source.chapterUrlRule);
      final chapterUrl = source.resolve(href)?.toString() ?? '';
      if (title.isEmpty || chapterUrl.isEmpty) continue;
      chapters.add(SourceChapterRef(title: title, url: chapterUrl));
    }
    if (chapters.isEmpty) {
      throw const BookSourceException('目录里没有可用的章节链接');
    }
    return chapters;
  }

  /// 读取一章正文。选择器没命中就报错，不退回整个页面——整页正文里混着导航、
  /// 广告和评论区，静默退回等于给用户一堆垃圾。
  Future<String> content(String chapterUrl) async {
    final url = source.resolve(chapterUrl);
    if (url == null) throw const BookSourceException('章节地址不合法');

    final document = await _load(url);
    final nodes = _select(document, source.contentRule.selector);
    if (nodes.isEmpty) {
      throw const BookSourceException('正文选择器没有匹配到内容，检查正文规则');
    }

    final buffer = StringBuffer();
    for (final node in nodes) {
      final text = _nodeText(node);
      if (text.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(text);
    }

    final body = buffer.toString().trim();
    if (body.isEmpty) {
      throw const BookSourceException('这一章取到的正文是空的');
    }
    return body;
  }

  Future<dom.Document> _load(Uri url) async {
    try {
      final bytes = await _transport.download(url, headers: _htmlAccept);
      return html_parser.parse(decodeBytes(bytes, source.charset));
    } on TransportException catch (e) {
      throw BookSourceException('抓取失败：${e.message}');
    }
  }

  static List<dom.Element> _select(dom.Document document, String selector) {
    if (selector.trim().isEmpty) return const [];
    try {
      return document.querySelectorAll(selector);
    } catch (_) {
      // 选择器语法错误由 package:html 抛，具体类型不稳定，一律翻成人话。
      throw BookSourceException('选择器写法不对：$selector');
    }
  }

  /// 按规则从一个元素里取值。
  String _text(dom.Element root, SourceRule rule) {
    final element = rule.selector.isEmpty ? root : root.querySelector(rule.selector);
    if (element == null) return '';

    final raw = rule.attribute == null
        ? element.text
        : (element.attributes[rule.attribute!] ?? '');
    return _clean(raw, rule);
  }

  /// 取正文文本。先把 `<br>` 和 `</p>` 换成换行再取文本，这样无论选择器选中的是
  /// 每个段落还是整个容器，段落之间都有分隔。
  static String _nodeText(dom.Element node) {
    final html = node.innerHtml
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n');
    final text = html_parser.parseFragment(html).text ?? '';
    final lines = text
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t\u3000]+'), ' ').trim())
        .where((line) => line.isNotEmpty);
    return lines.join('\n');
  }

  static String _clean(String raw, SourceRule rule) {
    var value = raw;
    final pattern = rule.pattern;
    if (pattern != null && pattern.isNotEmpty) {
      try {
        value = value.replaceAll(RegExp(pattern), rule.replacement ?? '');
      } on FormatException {
        // 用户写的正则不合法。保留原值比整条规则失效好。
      }
    }
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 按书源声明的字符集解码。GBK 解不动时退回 UTF-8，至少不会抛出去。
  static String decodeBytes(List<int> bytes, SourceCharset charset) {
    if (charset == SourceCharset.gbk) {
      try {
        return GbkCodec(allowMalformed: true).decode(bytes);
      } catch (_) {
        // 落到下面的 UTF-8。标错字符集的页面至少还能读出点东西。
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
