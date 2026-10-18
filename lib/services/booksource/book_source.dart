import 'dart:convert';

/// 网页的字符集。中文小说站到现在还有大量 GBK 页面，解码错了整页都是乱码。
enum SourceCharset { utf8, gbk }

extension SourceCharsetLabel on SourceCharset {
  String get label => switch (this) {
        SourceCharset.utf8 => 'UTF-8',
        SourceCharset.gbk => 'GBK',
      };

  static SourceCharset fromName(String raw) =>
      raw.trim().toLowerCase() == 'gbk' ? SourceCharset.gbk : SourceCharset.utf8;
}

/// 一条取值规则：`选择器[@属性][##正则##替换]`。
///
/// * 选择器是 CSS 选择器。空串表示「就用当前元素本身」——取列表项的标题时，
///   标题可能直接挂在条目上，不需要再往下选一层。
/// * 属性默认取文本。写 `@href`、`@src` 这类名字就取属性。
/// * `##正则##替换` 在取值之后做一次正则替换，替换串可以为空（等于删除）。
///   这一条是必要的：站点的章节名常写成「第12章 风起（求月票）」，得能砍掉尾巴。
class SourceRule {
  const SourceRule({
    this.selector = '',
    this.attribute,
    this.pattern,
    this.replacement,
  });

  static const empty = SourceRule();

  final String selector;

  /// null 表示取文本。
  final String? attribute;
  final String? pattern;
  final String? replacement;

  bool get isEmpty => selector.isEmpty && attribute == null && pattern == null;

  /// 解析规则串。格式不对时退化成「整串当选择器」，不抛异常——
  /// 用户手写规则，写错一个字不该让整个书源失效。
  static SourceRule parse(String raw) {
    var rest = raw.trim();
    if (rest.isEmpty) return empty;

    String? pattern;
    String? replacement;
    final marker = rest.indexOf('##');
    if (marker >= 0) {
      final tail = rest.substring(marker + 2);
      rest = rest.substring(0, marker);
      final second = tail.indexOf('##');
      if (second >= 0) {
        pattern = tail.substring(0, second);
        replacement = tail.substring(second + 2);
      } else {
        pattern = tail;
        replacement = '';
      }
    }

    String? attribute;
    final at = rest.lastIndexOf('@');
    if (at >= 0) {
      attribute = rest.substring(at + 1).trim();
      rest = rest.substring(0, at);
      if (attribute.isEmpty || attribute == 'text') attribute = null;
    }

    return SourceRule(
      selector: rest.trim(),
      attribute: attribute,
      pattern: pattern,
      replacement: replacement,
    );
  }

  Map<String, dynamic> toMap() => {
        'selector': selector,
        'attribute': attribute,
        'pattern': pattern,
        'replacement': replacement,
      };

  static SourceRule fromMap(Object? raw) {
    if (raw is! Map) return empty;
    return SourceRule(
      selector: raw['selector'] is String ? raw['selector'] as String : '',
      attribute: raw['attribute'] is String ? raw['attribute'] as String : null,
      pattern: raw['pattern'] is String ? raw['pattern'] as String : null,
      replacement:
          raw['replacement'] is String ? raw['replacement'] as String : null,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer(selector);
    if (attribute != null) buffer.write('@$attribute');
    if (pattern != null) buffer.write('##$pattern##${replacement ?? ''}');
    return buffer.toString();
  }
}

/// 一个书源。全部是声明式规则，没有脚本，也没有 eval。
///
/// 不做 JS 引擎是有意的：书源是用户从网上下载的第三方配置，能执行任意代码的
/// 书源等于把设备交出去。规则表达不了的能力就不支持，宁可少覆盖几个站点。
class BookSource {
  BookSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.searchUrl,
    required this.listRule,
    required this.titleRule,
    this.authorRule = SourceRule.empty,
    this.introRule = SourceRule.empty,
    this.coverRule = SourceRule.empty,
    this.detailUrlRule = const SourceRule(selector: 'a', attribute: 'href'),
    required this.chapterListRule,
    this.chapterTitleRule = const SourceRule(selector: 'a'),
    this.chapterUrlRule = const SourceRule(selector: 'a', attribute: 'href'),
    required this.contentRule,
    this.charset = SourceCharset.utf8,
    this.enabled = true,
    this.note = '',
  });

  final String id;
  String name;

  /// 站点的根地址，相对链接按它解析。
  String baseUrl;

  /// 搜索地址，支持 `{keyword}` 与 `{page}` 两个占位符。
  String searchUrl;

  SourceRule listRule;
  SourceRule titleRule;
  SourceRule authorRule;
  SourceRule introRule;
  SourceRule coverRule;
  SourceRule detailUrlRule;

  SourceRule chapterListRule;
  SourceRule chapterTitleRule;
  SourceRule chapterUrlRule;

  SourceRule contentRule;

  SourceCharset charset;
  bool enabled;
  String note;

  /// 把 `{keyword}` `{page}` 换成实际值。
  Uri searchUri(String keyword, int page) {
    final url = searchUrl
        .replaceAll('{keyword}', Uri.encodeQueryComponent(keyword))
        .replaceAll('{page}', '$page');
    return resolve(url) ?? Uri.parse(url);
  }

  /// 相对链接按 [baseUrl] 解析。解析不了返回 null。
  Uri? resolve(String href) {
    final trimmed = href.trim();
    if (trimmed.isEmpty) return null;
    final direct = Uri.tryParse(trimmed);
    if (direct != null && direct.hasScheme) return direct;
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null) return null;
    return base.resolve(trimmed);
  }

  BookSource copyWith({
    String? name,
    String? baseUrl,
    String? searchUrl,
    SourceRule? listRule,
    SourceRule? titleRule,
    SourceRule? authorRule,
    SourceRule? introRule,
    SourceRule? coverRule,
    SourceRule? detailUrlRule,
    SourceRule? chapterListRule,
    SourceRule? chapterTitleRule,
    SourceRule? chapterUrlRule,
    SourceRule? contentRule,
    SourceCharset? charset,
    bool? enabled,
    String? note,
  }) =>
      BookSource(
        id: id,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        searchUrl: searchUrl ?? this.searchUrl,
        listRule: listRule ?? this.listRule,
        titleRule: titleRule ?? this.titleRule,
        authorRule: authorRule ?? this.authorRule,
        introRule: introRule ?? this.introRule,
        coverRule: coverRule ?? this.coverRule,
        detailUrlRule: detailUrlRule ?? this.detailUrlRule,
        chapterListRule: chapterListRule ?? this.chapterListRule,
        chapterTitleRule: chapterTitleRule ?? this.chapterTitleRule,
        chapterUrlRule: chapterUrlRule ?? this.chapterUrlRule,
        contentRule: contentRule ?? this.contentRule,
        charset: charset ?? this.charset,
        enabled: enabled ?? this.enabled,
        note: note ?? this.note,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'searchUrl': searchUrl,
        'listRule': listRule.toMap(),
        'titleRule': titleRule.toMap(),
        'authorRule': authorRule.toMap(),
        'introRule': introRule.toMap(),
        'coverRule': coverRule.toMap(),
        'detailUrlRule': detailUrlRule.toMap(),
        'chapterListRule': chapterListRule.toMap(),
        'chapterTitleRule': chapterTitleRule.toMap(),
        'chapterUrlRule': chapterUrlRule.toMap(),
        'contentRule': contentRule.toMap(),
        'charset': charset.index,
        'enabled': enabled,
        'note': note,
      };

  /// 读回一个书源。缺字段用默认值，缺必需字段返回 null 由调用方跳过。
  static BookSource? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final baseUrl = raw['baseUrl'];
    final searchUrl = raw['searchUrl'];
    if (id is! String || name is! String || baseUrl is! String) return null;
    if (searchUrl is! String) return null;

    SourceRule rule(String key, [SourceRule fallback = SourceRule.empty]) =>
        raw[key] is Map ? SourceRule.fromMap(raw[key]) : fallback;

    final charsetIndex = raw['charset'];
    return BookSource(
      id: id,
      name: name,
      baseUrl: baseUrl,
      searchUrl: searchUrl,
      listRule: rule('listRule'),
      titleRule: rule('titleRule'),
      authorRule: rule('authorRule'),
      introRule: rule('introRule'),
      coverRule: rule('coverRule'),
      detailUrlRule: rule(
        'detailUrlRule',
        const SourceRule(selector: 'a', attribute: 'href'),
      ),
      chapterListRule: rule('chapterListRule'),
      chapterTitleRule: rule('chapterTitleRule', const SourceRule(selector: 'a')),
      chapterUrlRule: rule(
        'chapterUrlRule',
        const SourceRule(selector: 'a', attribute: 'href'),
      ),
      contentRule: rule('contentRule'),
      charset: charsetIndex is int &&
              charsetIndex >= 0 &&
              charsetIndex < SourceCharset.values.length
          ? SourceCharset.values[charsetIndex]
          : SourceCharset.utf8,
      enabled: raw['enabled'] is bool ? raw['enabled'] as bool : true,
      note: raw['note'] is String ? raw['note'] as String : '',
    );
  }
}

/// 书架上的一本「网络书」指向哪里。
///
/// 存在 `Book.filePath` 里，形如 `web:<sourceId>:<base64url(bookUrl)>`。不加字段
/// 是因为书源书的身份本来就只有这两样东西，多一个字段就要多改一次 Hive 适配器，
/// 而适配器改错会让老用户的书全读不出来。
class SourceBookRef {
  const SourceBookRef({required this.sourceId, required this.bookUrl});

  final String sourceId;
  final String bookUrl;

  static const scheme = 'web';

  String encode() =>
      '$scheme:$sourceId:${base64Url.encode(utf8.encode(bookUrl))}';

  static SourceBookRef? decode(String filePath) {
    if (!filePath.startsWith('$scheme:')) return null;
    final rest = filePath.substring(scheme.length + 1);
    final split = rest.indexOf(':');
    if (split <= 0) return null;
    final sourceId = rest.substring(0, split);
    final payload = rest.substring(split + 1);
    if (sourceId.isEmpty || payload.isEmpty) return null;
    try {
      final bookUrl = utf8.decode(base64Url.decode(payload));
      if (bookUrl.isEmpty) return null;
      return SourceBookRef(sourceId: sourceId, bookUrl: bookUrl);
    } on FormatException {
      return null;
    }
  }
}
