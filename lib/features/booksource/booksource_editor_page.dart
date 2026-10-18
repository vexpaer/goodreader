import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/booksource/book_source.dart';
import '../../state/providers.dart';

/// 新建或编辑一个书源。
///
/// 规则串的写法：`选择器[@属性][##正则##替换]`。这一行说明直接放在界面上，
/// 因为书源是给用户自己改的，藏起来只会让人去猜。
class BookSourceEditorPage extends ConsumerStatefulWidget {
  const BookSourceEditorPage({super.key, this.sourceId});

  final String? sourceId;

  @override
  ConsumerState<BookSourceEditorPage> createState() =>
      _BookSourceEditorPageState();
}

class _BookSourceEditorPageState extends ConsumerState<BookSourceEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _searchUrl;
  late final TextEditingController _note;
  late final TextEditingController _listRule;
  late final TextEditingController _titleRule;
  late final TextEditingController _authorRule;
  late final TextEditingController _introRule;
  late final TextEditingController _coverRule;
  late final TextEditingController _detailUrlRule;
  late final TextEditingController _chapterListRule;
  late final TextEditingController _chapterTitleRule;
  late final TextEditingController _chapterUrlRule;
  late final TextEditingController _contentRule;

  SourceCharset _charset = SourceCharset.utf8;
  String? _id;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.sourceId == null
        ? null
        : ref.read(bookSourceRepositoryProvider).byId(widget.sourceId!);

    _name = TextEditingController(text: existing?.name ?? '');
    _baseUrl = TextEditingController(text: existing?.baseUrl ?? '');
    _searchUrl = TextEditingController(text: existing?.searchUrl ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
    _listRule = TextEditingController(text: existing?.listRule.toString() ?? '');
    _titleRule = TextEditingController(text: existing?.titleRule.toString() ?? '');
    _authorRule = TextEditingController(text: existing?.authorRule.toString() ?? '');
    _introRule = TextEditingController(text: existing?.introRule.toString() ?? '');
    _coverRule = TextEditingController(text: existing?.coverRule.toString() ?? '');
    _detailUrlRule =
        TextEditingController(text: existing?.detailUrlRule.toString() ?? 'a@href');
    _chapterListRule =
        TextEditingController(text: existing?.chapterListRule.toString() ?? '');
    _chapterTitleRule =
        TextEditingController(text: existing?.chapterTitleRule.toString() ?? 'a');
    _chapterUrlRule =
        TextEditingController(text: existing?.chapterUrlRule.toString() ?? 'a@href');
    _contentRule = TextEditingController(text: existing?.contentRule.toString() ?? '');
    _charset = existing?.charset ?? SourceCharset.utf8;
    _id = existing?.id;
    _loaded = true;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _baseUrl,
      _searchUrl,
      _note,
      _listRule,
      _titleRule,
      _authorRule,
      _introRule,
      _coverRule,
      _detailUrlRule,
      _chapterListRule,
      _chapterTitleRule,
      _chapterUrlRule,
      _contentRule,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_id == null ? '新建书源' : '编辑书源'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            '规则写法：选择器[@属性][##正则##替换]\n'
            '选择器留空表示当前元素本身；属性不写就取文本；##…## 用来删掉多余的字。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _section('基本信息'),
          _field(_name, '名称', hint: '例如「某某小说网」'),
          _field(_baseUrl, '根地址', hint: 'https://example.com'),
          _field(_searchUrl, '搜索地址', hint: 'https://example.com/search?q={keyword}&page={page}'),
          DropdownButtonFormField<SourceCharset>(
            value: _charset,
            decoration: const InputDecoration(labelText: '页面字符集'),
            items: [
              for (final charset in SourceCharset.values)
                DropdownMenuItem(value: charset, child: Text(charset.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _charset = value);
            },
          ),
          _field(_note, '备注'),
          const SizedBox(height: 20),
          _section('搜索结果'),
          _field(_listRule, '列表', hint: 'div.result-item'),
          _field(_titleRule, '标题', hint: 'h3 a'),
          _field(_authorRule, '作者', hint: 'span.author##作者：##'),
          _field(_introRule, '简介', hint: 'p.intro'),
          _field(_coverRule, '封面', hint: 'img@src'),
          _field(_detailUrlRule, '详情链接', hint: 'h3 a@href'),
          const SizedBox(height: 20),
          _section('目录'),
          _field(_chapterListRule, '目录列表', hint: '#list dd'),
          _field(_chapterTitleRule, '章节标题', hint: 'a'),
          _field(_chapterUrlRule, '章节链接', hint: 'a@href'),
          const SizedBox(height: 20),
          _section('正文'),
          _field(_contentRule, '正文', hint: '#content p'),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Future<void> _save() async {
    final name = _name.text.trim();
    final baseUrl = _baseUrl.text.trim();
    final searchUrl = _searchUrl.text.trim();
    if (name.isEmpty || baseUrl.isEmpty || searchUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名称、根地址、搜索地址都要填')),
      );
      return;
    }
    if (!searchUrl.contains('{keyword}')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('搜索地址里要有 {keyword} 占位符')),
      );
      return;
    }

    final source = BookSource(
      id: _id ?? 'src-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      baseUrl: baseUrl,
      searchUrl: searchUrl,
      listRule: SourceRule.parse(_listRule.text),
      titleRule: SourceRule.parse(_titleRule.text),
      authorRule: SourceRule.parse(_authorRule.text),
      introRule: SourceRule.parse(_introRule.text),
      coverRule: SourceRule.parse(_coverRule.text),
      detailUrlRule: SourceRule.parse(_detailUrlRule.text),
      chapterListRule: SourceRule.parse(_chapterListRule.text),
      chapterTitleRule: SourceRule.parse(_chapterTitleRule.text),
      chapterUrlRule: SourceRule.parse(_chapterUrlRule.text),
      contentRule: SourceRule.parse(_contentRule.text),
      charset: _charset,
      note: _note.text.trim(),
    );

    await ref.read(bookSourceRepositoryProvider).add(source);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/sources');
    }
  }
}
