import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../../data/db/hive_setup.dart';
import '../../data/models/book.dart';
import '../../data/models/service_endpoint.dart';
import '../../services/ai/ai_client.dart';
import '../../state/providers.dart';
import '../services/service_providers_page.dart';

/// 与 AI 的对话界面。[bookId] 为空时是全局问答，非空时带上书籍上下文。
class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key, this.bookId});

  final String? bookId;

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  static const _box = HiveBoxes.aiConversations;

  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  bool _sending = false;
  String? _error;
  String? _model;

  String get _key => widget.bookId ?? 'global';

  Book? get _book => widget.bookId == null
      ? null
      : ref.read(booksControllerProvider).byId(widget.bookId!);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final raw = Hive.box<dynamic>(_box).get(_key);
    if (raw is! String || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      setState(() {
        _messages = decoded
            .map(ChatMessage.fromMap)
            .whereType<ChatMessage>()
            .toList(growable: false);
      });
    } on FormatException {
      // 历史损坏不影响继续用，从头开始即可。
    }
  }

  Future<void> _persist() async {
    final payload = jsonEncode(_messages.map((m) => m.toMap()).toList());
    await Hive.box<dynamic>(_box).put(_key, payload);
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;

    final endpoint = ref.read(serviceProviderRepositoryProvider).activeOf(ServiceKind.ai);
    if (endpoint == null) {
      setState(() => _error = '还没配置 AI 服务');
      return;
    }

    final client = AiClient();
    _input.clear();
    setState(() {
      _error = null;
      _sending = true;
      _messages = [..._messages, ChatMessage(role: 'user', content: text)];
    });
    _scrollToEnd();

    try {
      final reply = await client.chat(
        baseUrl: endpoint.normalizedBaseUrl,
        apiKey: ref.read(serviceProviderRepositoryProvider).readSecret(endpoint.id),
        model: endpoint.model,
        history: _messages,
        system: _book == null ? null : bookContextPrompt(_book!),
      );
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          ChatMessage(
            role: 'assistant',
            content: reply,
            model: endpoint.model.isEmpty ? null : endpoint.model,
          ),
        ];
        _model = endpoint.model;
      });
      await _persist();
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.userMessage);
      await _persist();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _clear() async {
    setState(() => _messages = const []);
    await Hive.box<dynamic>(_box).delete(_key);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final endpoint = ref.watch(serviceProviderRepositoryProvider).activeOf(ServiceKind.ai);

    return Scaffold(
      appBar: AppBar(
        title: Text(_book?.title ?? '阅读助手'),
        subtitle: endpoint == null
            ? const Text('未配置服务')
            : Text(endpoint.label + (endpoint.model.isEmpty ? '' : ' · ${endpoint.model}')),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: '清空对话',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clear,
            ),
        ],
      ),
      body: endpoint == null
          ? NoServiceHint(
              kind: ServiceKind.ai,
              onConfigure: () => context.push('/services'),
            )
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? _Welcome(
                          book: _book,
                          onPick: (p) => _send(p),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          itemCount: _messages.length + (_sending ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == _messages.length) {
                              return const _Thinking();
                            }
                            return _Bubble(message: _messages[i]);
                          },
                        ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 16, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                _Composer(
                  controller: _input,
                  sending: _sending,
                  onSend: _send,
                ),
              ],
            ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.book, required this.onPick});

  final Book? book;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prompts = <({String label, String prompt})>[
      (
        label: '总结本章',
        prompt: book == null ? AiPrompts.summarizeChapter : '${bookContextPrompt(book!)}\n\n${AiPrompts.summarizeChapter}',
      ),
      (
        label: '挑出值得划线的句子',
        prompt: book == null ? AiPrompts.pickHighlights : '${bookContextPrompt(book!)}\n\n${AiPrompts.pickHighlights}',
      ),
      (
        label: '分析一个人物',
        prompt: book == null ? AiPrompts.analyzeCharacter : '${bookContextPrompt(book!)}\n\n${AiPrompts.analyzeCharacter}',
      ),
      (
        label: '相关背景知识',
        prompt: AiPrompts.explainBackground,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('问点什么', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '回答只依据你配置的服务，GoodReader 不做中转，也不存你的密钥。',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        for (final p in prompts)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              title: Text(p.label),
              trailing: const Icon(Icons.arrow_forward, size: 16),
              onTap: () => onPick(p.prompt),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.content,
              style: theme.textTheme.bodyMedium,
            ),
            if (!isUser && (message.model?.isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  message.model!,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '输入问题',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : () => onSend(controller.text),
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
