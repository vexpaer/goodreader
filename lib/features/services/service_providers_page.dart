import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/book.dart';
import '../../data/models/service_endpoint.dart';
import '../../data/repositories/provider_catalog.dart';
import '../../state/providers.dart';

/// 管理用户自带的各类服务端点。
///
/// 一个列表覆盖五种能力。新增端点永远从预置目录起步，地址与密钥由用户填，
/// 所以不需要为每种能力各写一套设置界面。
class ServiceProvidersPage extends ConsumerStatefulWidget {
  const ServiceProvidersPage({super.key});

  @override
  ConsumerState<ServiceProvidersPage> createState() =>
      _ServiceProvidersPageState();
}

class _ServiceProvidersPageState extends ConsumerState<ServiceProvidersPage> {
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(serviceProviderRepositoryProvider);
    final endpoints = repo.load();
    final active = repo.loadActive();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('服务'),
            Text(
              '自己填地址与密钥，不经过任何第三方',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          for (final kind in ServiceKind.values) ...[
            _KindSection(
              kind: kind,
              endpoints: endpoints.where((e) => e.kind == kind).toList(),
              activeId: active[kind],
              onAdd: () => _openEditor(kind),
              onPick: (endpoint) async {
                await repo.setActive(kind, endpoint.id);
                setState(() {});
              },
              onEdit: (endpoint) => _openEditor(kind, existing: endpoint),
              onDelete: (endpoint) async {
                await repo.remove(endpoint.id);
                setState(() {});
              },
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Future<void> _openEditor(
    ServiceKind kind, {
    ServiceEndpoint? existing,
  }) async {
    final repo = ref.read(serviceProviderRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EndpointEditor(
        kind: kind,
        existing: existing,
        onSubmit: (draft) async {
          if (existing == null) {
            final endpoint = repo.create(
              kind: kind,
              label: draft.label,
              baseUrl: draft.baseUrl,
              secret: draft.secret,
              model: draft.model,
              note: draft.note,
            );
            await repo.add(endpoint);
            // 第一个端点自动设为启用，省一步操作。
            if (repo.activeOf(kind) == null) await repo.setActive(kind, endpoint.id);
          } else {
            await repo.update(existing.copyWith(
              label: draft.label,
              baseUrl: draft.baseUrl,
              secret: draft.secret,
              model: draft.model,
              note: draft.note,
            ));
          }
          if (context.mounted) Navigator.pop(context);
          setState(() {});
        },
      ),
    );
  }
}

class _KindSection extends StatelessWidget {
  const _KindSection({
    required this.kind,
    required this.endpoints,
    required this.activeId,
    required this.onAdd,
    required this.onPick,
    required this.onEdit,
    required this.onDelete,
  });

  final ServiceKind kind;
  final List<ServiceEndpoint> endpoints;
  final String? activeId;
  final VoidCallback onAdd;
  final ValueChanged<ServiceEndpoint> onPick;
  final ValueChanged<ServiceEndpoint> onEdit;
  final ValueChanged<ServiceEndpoint> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(kind.label, style: theme.textTheme.titleSmall),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
        ),
        if (endpoints.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              '还没配置。添加后可以随时停用或删除。',
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          for (final endpoint in endpoints)
            ListTile(
              leading: Radio<String>(
                value: endpoint.id,
                groupValue: activeId,
                onChanged: endpoint.enabled ? (_) => onPick(endpoint) : null,
              ),
              title: Text(endpoint.label),
              subtitle: Text(
                '${endpoint.normalizedBaseUrl.isEmpty ? '未填地址' : endpoint.normalizedBaseUrl}'
                '${endpoint.model.isEmpty ? '' : ' · ${endpoint.model}'}'
                '${endpoint.enabled ? '' : ' · 已停用'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit(endpoint);
                  if (value == 'delete') onDelete(endpoint);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ),
      ],
    );
  }
}

class _Draft {
  _Draft({
    required this.label,
    required this.baseUrl,
    required this.secret,
    required this.model,
    required this.note,
  });

  final String label;
  final String baseUrl;
  final String secret;
  final String model;
  final String note;
}

class _EndpointEditor extends StatefulWidget {
  const _EndpointEditor({
    required this.kind,
    required this.existing,
    required this.onSubmit,
  });

  final ServiceKind kind;
  final ServiceEndpoint? existing;
  final ValueChanged<_Draft> onSubmit;

  @override
  State<_EndpointEditor> createState() => _EndpointEditorState();
}

class _EndpointEditorState extends State<_EndpointEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _baseUrl;
  late final TextEditingController _secret;
  late final TextEditingController _model;
  late final TextEditingController _note;
  String? _presetId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _label = TextEditingController(text: existing?.label ?? '');
    _baseUrl = TextEditingController(text: existing?.baseUrl ?? '');
    _secret = TextEditingController(text: existing?.secret ?? '');
    _model = TextEditingController(text: existing?.model ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    _baseUrl.dispose();
    _secret.dispose();
    _model.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presets = ProviderCatalog.ofKind(widget.kind);
    final isNew = widget.existing == null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('添加${widget.kind.label}', style: Theme.of(context).textTheme.titleMedium),
            if (isNew) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _presetId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '从预置选择',
                  helperText: '选好后只需补地址与密钥',
                ),
                items: [
                  for (final preset in presets)
                    DropdownMenuItem(
                      value: preset.id,
                      child: Text(preset.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  final preset = ProviderCatalog.byId(value);
                  if (preset == null) return;
                  setState(() {
                    _presetId = value;
                    if (_label.text.trim().isEmpty) _label.text = preset.name;
                    if (preset.defaultBaseUrl.isNotEmpty) {
                      _baseUrl.text = preset.defaultBaseUrl;
                    }
                    if (preset.models.isNotEmpty) {
                      _model.text = preset.models.first;
                    }
                    if (preset.hint.isNotEmpty && _note.text.trim().isEmpty) {
                      _note.text = preset.hint;
                    }
                  });
                },
              ),
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: _label,
              decoration: const InputDecoration(labelText: '名称'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '给这个连接起个名字' : null,
            ),
            TextFormField(
              controller: _baseUrl,
              decoration: const InputDecoration(
                labelText: '地址',
                hintText: 'https://',
                helperText: '不填协议会补 https，本机服务填 http://localhost:端口',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '地址不能为空' : null,
            ),
            TextFormField(
              controller: _model,
              decoration: const InputDecoration(
                labelText: '模型或配置档',
                helperText: '可留空，由服务端决定',
              ),
            ),
            TextFormField(
              controller: _secret,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: _secretLabel(presets),
                helperText: '单独存放，不参与备份与同步',
              ),
            ),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: '备注'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(isNew ? '添加' : '保存'),
            ),
            const SizedBox(height: 8),
            Text(
              '密钥只保存在本机。导出备份与云同步都不会带上它。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _secretLabel(List<ProviderPreset> presets) {
    if (_presetId == null) return '密钥';
    final preset = ProviderCatalog.byId(_presetId!);
    return preset?.secretLabel ?? '密钥';
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmit(_Draft(
      label: _label.text.trim(),
      baseUrl: _baseUrl.text.trim(),
      secret: _secret.text,
      model: _model.text.trim(),
      note: _note.text.trim(),
    ));
  }
}

/// 供其它页面复用：没有可用端点时给出引导。
class NoServiceHint extends StatelessWidget {
  const NoServiceHint({super.key, required this.kind, required this.onConfigure});

  final ServiceKind kind;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('还没配置${kind.label}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '填一个自己的服务地址与密钥就能用。不设置为空，也不经过任何中转。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onConfigure,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('去配置'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 把当前书作为上下文拼进提问里。
String bookContextPrompt(Book book) =>
    '我正在读《${book.title}》（作者：${book.displayAuthor}）。'
    '请只依据这本书的内容回答，引用时保留原文句子。';
