import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../../../data/models/chapter.dart';
import 'document.dart';

/// Minimal, dependency-light EPUB 2/3 parser built directly on the ZIP + XML
/// containers, so no third-party ebook package can break the build.
class EpubDocument extends ReaderDocument {
  EpubDocument._(
    this._path,
    this._entries,
    this.chapters, {
    this.title,
    this.author,
    this.intro,
    this.coverBytes,
  });

  final String _path;
  final Map<String, ArchiveFile> _entries;

  @override
  final List<ChapterMeta> chapters;

  final String? title;
  final String? author;
  final String? intro;
  final Uint8List? coverBytes;

  static Future<EpubDocument> open(String path) async {
    final bytes = await File(path).readAsBytes();

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (e) {
      throw BookParseException('无法读取 EPUB 容器：$e');
    }

    final entries = <String, ArchiveFile>{};
    for (final f in archive.files) {
      if (f.name.endsWith('/')) continue;
      entries[_norm(f.name)] = f;
    }

    String? readText(String name) {
      final data = _bytes(entries[_norm(name)]);
      if (data == null) return null;
      return utf8.decode(data, allowMalformed: true);
    }

    // 1. Locate the OPF package document.
    final containerXml = readText('META-INF/container.xml');
    if (containerXml == null) {
      throw BookParseException('EPUB 缺少 META-INF/container.xml');
    }
    final container = XmlDocument.parse(containerXml);
    final rootfile = container.descendants
        .whereType<XmlElement>()
        .firstWhere(
          (e) => e.name.local == 'rootfile',
          orElse: () => throw BookParseException('EPUB 中找不到 OPF 根文件'),
        );
    final opfPath = rootfile.getAttribute('full-path');
    if (opfPath == null) {
      throw BookParseException('OPF 路径为空');
    }

    final opfXml = readText(opfPath);
    if (opfXml == null) {
      throw BookParseException('找不到 OPF 文件：$opfPath');
    }
    final opf = XmlDocument.parse(opfXml);
    final opfDir = _dirname(_norm(opfPath));

    // 2. Metadata.
    String? metaOf(String local) {
      for (final e in opf.descendants.whereType<XmlElement>()) {
        if (e.name.local == local && e.innerText.trim().isNotEmpty) {
          return e.innerText.trim();
        }
      }
      return null;
    }

    final title = metaOf('title');
    final author = metaOf('creator');
    final intro = metaOf('description');

    // 3. Manifest.
    final manifest = <String, _ManifestItem>{};
    for (final e in opf.descendants.whereType<XmlElement>()) {
      if (e.name.local != 'item') continue;
      final id = e.getAttribute('id');
      final href = e.getAttribute('href');
      if (id == null || href == null) continue;
      manifest[id] = _ManifestItem(
        id: id,
        href: href,
        mediaType: e.getAttribute('media-type') ?? '',
        properties: e.getAttribute('properties') ?? '',
      );
    }

    // 4. Spine order.
    final spineIds = <String>[];
    for (final e in opf.descendants.whereType<XmlElement>()) {
      if (e.name.local != 'itemref') continue;
      final idref = e.getAttribute('idref');
      if (idref != null) spineIds.add(idref);
    }

    // 5. Table of contents titles (NCX or EPUB3 nav), best effort.
    final tocTitles = <String, String>{};
    _collectToc(opf, manifest, opfDir, readText, tocTitles);

    // 6. Cover image.
    Uint8List? cover;
    String? coverId;
    for (final e in opf.descendants.whereType<XmlElement>()) {
      if (e.name.local == 'meta' && e.getAttribute('name') == 'cover') {
        coverId = e.getAttribute('content');
      }
    }
    for (final item in manifest.values) {
      final isCover = item.id == coverId ||
          item.properties.split(RegExp(r'\s+')).contains('cover-image');
      if (!isCover) continue;
      final data = _bytes(entries[_join(opfDir, item.href)]);
      if (data != null) {
        cover = data;
        break;
      }
    }

    // 7. Build chapters from the spine.
    final chapters = <ChapterMeta>[];
    for (final id in spineIds) {
      final item = manifest[id];
      if (item == null) continue;
      final zipName = _join(opfDir, item.href);
      final isHtml = item.mediaType.contains('html') ||
          item.href.toLowerCase().endsWith('.html') ||
          item.href.toLowerCase().endsWith('.xhtml') ||
          item.href.toLowerCase().endsWith('.htm');
      if (!isHtml || !entries.containsKey(zipName)) continue;

      final resolved = _join(opfDir, item.href);
      final tocTitle = tocTitles[_norm(item.href)] ??
          tocTitles[zipName] ??
          tocTitles[_basename(zipName)];
      chapters.add(ChapterMeta(
        index: chapters.length,
        title: tocTitle ?? '第 ${chapters.length + 1} 章',
        href: zipName,
      ));
    }

    if (chapters.isEmpty) {
      throw BookParseException('EPUB 中未找到可阅读的正文内容');
    }

    return EpubDocument._(
      path,
      entries,
      chapters,
      title: title,
      author: author,
      intro: intro,
      coverBytes: cover,
    );
  }

  static void _collectToc(
    XmlDocument opf,
    Map<String, _ManifestItem> manifest,
    String opfDir,
    String? Function(String) readText,
    Map<String, String> out,
  ) {
    String? tocHref;
    for (final item in manifest.values) {
      if (item.mediaType == 'application/x-dtbncx+xml') {
        tocHref = item.href;
      }
      if (item.properties.split(RegExp(r'\s+')).contains('nav')) {
        tocHref ??= item.href;
      }
    }
    if (tocHref == null) return;

    final tocName = _join(opfDir, tocHref);
    final xml = readText(tocName);
    if (xml == null) return;

    try {
      final doc = XmlDocument.parse(xml);
      for (final nav in doc.descendants.whereType<XmlElement>()) {
        if (nav.name.local != 'content' && nav.name.local != 'a') continue;
        final src = nav.getAttribute('src') ?? nav.getAttribute('href');
        if (src == null) continue;
        final label = nav.innerText.trim();
        if (label.isEmpty) continue;
        out.putIfAbsent(_norm(src.split('#').first), () => label);
      }
    } catch (_) {
      // A broken TOC must not prevent reading.
    }
  }

  static Uint8List? _bytes(ArchiveFile? file) {
    if (file == null) return null;
    final content = file.content;
    if (content is Uint8List) return content;
    if (content is List<int>) return Uint8List.fromList(content);
    return null;
  }

  static String _norm(String name) {
    var n = name.replaceAll('\\', '/');
    while (n.startsWith('./')) {
      n = n.substring(2);
    }
    return n;
  }

  static String _decode(String s) {
    try {
      return Uri.decodeFull(s);
    } catch (_) {
      return s;
    }
  }

  static String _dirname(String path) {
    final i = path.lastIndexOf('/');
    return i <= 0 ? '' : path.substring(0, i);
  }

  static String _basename(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }

  static String _join(String dir, String href) {
    final clean = _decode(href.split('#').first);
    final parts = <String>[];
    for (final seg in '$dir/$clean'.split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (parts.isNotEmpty) parts.removeLast();
        continue;
      }
      parts.add(seg);
    }
    return parts.join('/');
  }

  @override
  Future<String> chapterText(int index) async {
    if (index < 0 || index >= chapters.length) return '';
    final href = chapters[index].href;
    if (href == null) return '';
    final data = _bytes(_entries[href]);
    if (data == null) return '';
    return htmlToPlainText(utf8.decode(data, allowMalformed: true));
  }

  String get path => _path;

  @override
  Future<List<SearchHit>> search(String query, {int limit = 200}) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];

    final hits = <SearchHit>[];
    for (var i = 0; i < chapters.length && hits.length < limit; i++) {
      final text = await chapterText(i);
      if (text.isEmpty) continue;
      final haystack = text.toLowerCase();
      var from = 0;
      while (hits.length < limit) {
        final at = haystack.indexOf(needle, from);
        if (at < 0) break;
        hits.add(SearchHit(
          chapterIndex: i,
          chapterTitle: chapters[i].title,
          start: at,
          end: at + needle.length,
          snippet: buildSnippet(text, at, needle.length),
        ));
        from = at + needle.length;
      }
    }
    return hits;
  }
}

class _ManifestItem {
  _ManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    required this.properties,
  });

  final String id;
  final String href;
  final String mediaType;
  final String properties;
}

const _blockTags = {
  'p', 'div', 'br', 'hr', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
  'li', 'tr', 'table', 'blockquote', 'section', 'article', 'pre',
  'figure', 'figcaption', 'aside', 'header', 'footer', 'ul', 'ol',
};

/// Converts an XHTML document into readable plain text.
String htmlToPlainText(String source) {
  final document = html_parser.parse(source);
  final buffer = StringBuffer();

  void walk(dom.Node node) {
    for (final child in node.nodes) {
      if (child is dom.Text) {
        buffer.write(child.text);
      } else if (child is dom.Element) {
        final tag = child.localName?.toLowerCase() ?? '';
        if (tag == 'script' || tag == 'style' || tag == 'head') continue;
        final isBlock = _blockTags.contains(tag);
        if (isBlock) buffer.write('\n');
        walk(child);
        if (isBlock) buffer.write('\n');
      }
    }
  }

  walk(document.body ?? document);
  return buffer
      .toString()
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
