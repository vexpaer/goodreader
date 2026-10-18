import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/services/booksource/book_source.dart';
import 'package:goodreader/services/booksource/book_source_engine.dart';
import 'package:goodreader/services/http_transport.dart';

/// 只认 URL 的假传输层，页面对不上就直接报网络错。
class FakeSite extends HttpTransport {
  FakeSite(this.pages);

  final Map<String, String> pages;

  @override
  Future<TransportResponse> get(Uri url, {Map<String, String>? headers}) async {
    final body = pages[url.toString()];
    if (body == null) {
      throw const TransportException('网络连接失败');
    }
    return TransportResponse(statusCode: 200, body: body);
  }

  @override
  Future<Uint8List> download(Uri url, {Map<String, String>? headers}) async {
    final response = await get(url);
    return Uint8List.fromList(utf8.encode(response.body));
  }

  @override
  Future<TransportResponse> post(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      throw UnimplementedError();

  @override
  Future<TransportResponse> put(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      throw UnimplementedError();

  @override
  Future<TransportResponse> delete(Uri url, {Map<String, String>? headers}) =>
      throw UnimplementedError();

  @override
  Future<TransportResponse> send(String method, Uri url,
          {Map<String, String>? headers, Object? body}) =>
      throw UnimplementedError();
}

const _searchHtml = '''
<html><body>
<div class="result">
  <h3><a href="/book/1">三体</a></h3>
  <span class="author">作者：刘慈欣</span>
  <p class="intro">地球往事三部曲第一部</p>
  <img src="/cover/1.jpg">
</div>
<div class="result">
  <h3><a href="/book/2">球状闪电</a></h3>
  <span class="author">作者：刘慈欣</span>
</div>
</body></html>
''';

const _tocHtml = '''
<html><body>
<div id="list">
  <dl>
    <dd><a href="/read/1-1">第1章 科学边界</a></dd>
    <dd><a href="/read/1-2">第2章 台球</a></dd>
  </dl>
</div>
</body></html>
''';

const _contentHtml = '''
<html><body>
<div id="content">
  <p>第一段。</p><p>第二段<br>换行后。</p>
</div>
</body></html>
''';

BookSource _source({SourceRule? contentRule}) => BookSource(
      id: 'src-1',
      name: '测试源',
      baseUrl: 'https://ex.com',
      searchUrl: 'https://ex.com/search?q={keyword}&page={page}',
      listRule: const SourceRule(selector: 'div.result'),
      titleRule: const SourceRule(selector: 'h3 a'),
      authorRule: const SourceRule(selector: 'span.author', pattern: '作者：'),
      introRule: const SourceRule(selector: 'p.intro'),
      coverRule: const SourceRule(selector: 'img', attribute: 'src'),
      detailUrlRule: const SourceRule(selector: 'h3 a', attribute: 'href'),
      chapterListRule: const SourceRule(selector: '#list dd'),
      chapterTitleRule: const SourceRule(selector: 'a'),
      chapterUrlRule: const SourceRule(selector: 'a', attribute: 'href'),
      contentRule: contentRule ?? const SourceRule(selector: '#content p'),
    );

void main() {
  group('规则串解析', () {
    test('空串是空规则', () {
      expect(SourceRule.parse('').isEmpty, isTrue);
      expect(SourceRule.parse('   ').isEmpty, isTrue);
    });

    test('只有选择器', () {
      final rule = SourceRule.parse('div.item');
      expect(rule.selector, 'div.item');
      expect(rule.attribute, isNull);
      expect(rule.pattern, isNull);
    });

    test('@ 后面是属性', () {
      expect(SourceRule.parse('a@href').attribute, 'href');
      expect(SourceRule.parse('a@href').selector, 'a');
      // @text 等于不写属性。
      expect(SourceRule.parse('a@text').attribute, isNull);
    });

    test('## 后面是正则与替换，替换可以为空', () {
      final rule = SourceRule.parse(r'span.author##作者：##');
      expect(rule.selector, 'span.author');
      expect(rule.pattern, '作者：');
      expect(rule.replacement, '');
    });

    test('属性与正则可以同时出现', () {
      final rule = SourceRule.parse(r'a@title##\s+## ');
      expect(rule.selector, 'a');
      expect(rule.attribute, 'title');
      expect(rule.pattern, r'\s+');
      expect(rule.replacement, ' ');
    });

    test('toString 能还原成同一串', () {
      for (final raw in [
        'div.item',
        'a@href',
        r'span.author##作者：##',
        r'a@title##\s+## ',
      ]) {
        expect(SourceRule.parse(raw).toString(), raw, reason: raw);
      }
    });

    test('序列化往返', () {
      final rule = SourceRule.parse(r'a@href##x##y');
      final back = SourceRule.fromMap(rule.toMap());
      expect(back.selector, rule.selector);
      expect(back.attribute, rule.attribute);
      expect(back.pattern, rule.pattern);
      expect(back.replacement, rule.replacement);
    });
  });

  group('地址处理', () {
    test('搜索地址里的占位符被替换', () {
      final uri = _source().searchUri('三体 2', 3);
      expect(uri.queryParameters['q'], '三体 2');
      expect(uri.queryParameters['page'], '3');
      expect(uri.host, 'ex.com');
    });

    test('相对链接按根地址解析，绝对链接原样返回', () {
      final source = _source();
      expect(source.resolve('/book/1').toString(), 'https://ex.com/book/1');
      expect(
        source.resolve('https://other.com/x').toString(),
        'https://other.com/x',
      );
      expect(source.resolve('   '), isNull);
    });
  });

  group('搜索', () {
    test('按规则取出书目', () async {
      final engine = BookSourceEngine(
        source: _source(),
        transport: FakeSite({
          'https://ex.com/search?q=%E4%B8%89%E4%BD%93&page=1': _searchHtml,
        }),
      );

      final results = await engine.search('三体');
      expect(results.length, 2);
      expect(results.first.title, '三体');
      expect(results.first.author, '刘慈欣');
      expect(results.first.intro, '地球往事三部曲第一部');
      expect(results.first.url, 'https://ex.com/book/1');
      expect(results.first.coverUrl, 'https://ex.com/cover/1.jpg');
      // 第二条没有简介与封面，字段是空串而不是 null。
      expect(results[1].intro, '');
      expect(results[1].coverUrl, '');
    });

    test('页面里有词但选择器没选中，报选择器的问题', () async {
      final engine = BookSourceEngine(
        source: _source().copyWith(listRule: const SourceRule(selector: 'div.nope')),
        transport: FakeSite({
          'https://ex.com/search?q=%E4%B8%89%E4%BD%93&page=1': _searchHtml,
        }),
      );
      await expectLater(
        engine.search('三体'),
        throwsA(isA<BookSourceException>().having(
          (e) => e.message,
          'message',
          contains('列表选择器'),
        )),
      );
    });

    test('页面里没有关键词就是真的没结果', () async {
      final engine = BookSourceEngine(
        source: _source(),
        transport: FakeSite({
          'https://ex.com/search?q=%E4%B8%8D%E5%AD%98%E5%9C%A8&page=1':
              '<html><body><p>没有找到</p></body></html>',
        }),
      );
      expect(await engine.search('不存在'), isEmpty);
    });

    test('网络失败翻成自己的异常', () async {
      final engine = BookSourceEngine(source: _source(), transport: FakeSite({}));
      await expectLater(
        engine.search('三体'),
        throwsA(isA<BookSourceException>()),
      );
    });
  });

  group('目录', () {
    test('取出章节标题与绝对地址', () async {
      final engine = BookSourceEngine(
        source: _source(),
        transport: FakeSite({'https://ex.com/book/1': _tocHtml}),
      );
      final chapters = await engine.chapters('https://ex.com/book/1');
      expect(chapters.map((c) => c.title), ['第1章 科学边界', '第2章 台球']);
      expect(chapters.first.url, 'https://ex.com/read/1-1');
    });

    test('目录选择器没命中就报错', () async {
      final engine = BookSourceEngine(
        source: _source(),
        transport: FakeSite({'https://ex.com/book/1': '<html></html>'}),
      );
      await expectLater(
        engine.chapters('https://ex.com/book/1'),
        throwsA(isA<BookSourceException>()),
      );
    });
  });

  group('正文', () {
    test('段落选择器：每段一行', () async {
      final engine = BookSourceEngine(
        source: _source(),
        transport: FakeSite({'https://ex.com/read/1-1': _contentHtml}),
      );
      final text = await engine.content('https://ex.com/read/1-1');
      expect(text, '第一段。\n第二段\n换行后。');
    });

    test('容器选择器：结果与段落选择器一致', () async {
      // 选整个容器时要靠把 </p> 换成换行来分段，否则所有段落会粘成一坨。
      final engine = BookSourceEngine(
        source: _source(contentRule: const SourceRule(selector: '#content')),
        transport: FakeSite({'https://ex.com/read/1-1': _contentHtml}),
      );
      final text = await engine.content('https://ex.com/read/1-1');
      expect(text, '第一段。\n第二段\n换行后。');
    });

    test('正文选择器没命中就报错，不退回整页', () async {
      final engine = BookSourceEngine(
        source: _source(contentRule: const SourceRule(selector: '.nope')),
        transport: FakeSite({'https://ex.com/read/1-1': _contentHtml}),
      );
      await expectLater(
        engine.content('https://ex.com/read/1-1'),
        throwsA(isA<BookSourceException>().having(
          (e) => e.message,
          'message',
          contains('正文选择器'),
        )),
      );
    });
  });

  group('字符集', () {
    test('GBK 页面按 GBK 解码', () {
      // 「中文」的 GBK 编码。
      final bytes = <int>[0xD6, 0xD0, 0xCE, 0xC4];
      expect(
        BookSourceEngine.decodeBytes(bytes, SourceCharset.gbk),
        '中文',
      );
      // 同一串字节按 UTF-8 解会得到替换字符。
      expect(
        BookSourceEngine.decodeBytes(bytes, SourceCharset.utf8),
        contains('\uFFFD'),
      );
    });
  });

  group('书架引用', () {
    test('编码后能解回原样', () {
      const ref = SourceBookRef(
        sourceId: 'src-1',
        bookUrl: 'https://ex.com/book/1?x=1',
      );
      final decoded = SourceBookRef.decode(ref.encode())!;
      expect(decoded.sourceId, 'src-1');
      expect(decoded.bookUrl, 'https://ex.com/book/1?x=1');
    });

    test('不是书源地址、缺字段、坏编码都返回 null', () {
      expect(SourceBookRef.decode('/tmp/a.txt'), isNull);
      expect(SourceBookRef.decode('web:'), isNull);
      expect(SourceBookRef.decode('web:src:'), isNull);
      expect(SourceBookRef.decode('web::abc'), isNull);
      expect(SourceBookRef.decode('web:src:%%%'), isNull);
    });
  });
}
