import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/service_endpoint.dart';
import '../../services/ocr/ocr_service.dart';
import '../../state/providers.dart';
import '../services/service_providers_page.dart';

/// 图片转文字。识别完可以存成一本书，交给阅读器处理。
class OcrPage extends ConsumerStatefulWidget {
  const OcrPage({super.key});

  @override
  ConsumerState<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends ConsumerState<OcrPage> {
  final _text = TextEditingController();
  final _title = TextEditingController();

  Uint8List? _image;
  String _fileName = '';
  String? _error;
  bool _recognizing = false;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(serviceProviderRepositoryProvider);
    final endpoint = repo.activeOf(ServiceKind.ocr);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('图片转文字')),
      body: endpoint == null
          ? NoServiceHint(
              kind: ServiceKind.ocr,
              onConfigure: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ServiceProvidersPage(),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (_image == null)
                  _Picker(onPick: _pick)
                else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _image!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton(onPressed: _pick, child: const Text('换一张')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _recognizing ? null : () => _recognize(endpoint),
                    icon: _recognizing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.text_fields),
                    label: Text(_recognizing ? '正在识别' : '识别文字'),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 20),
                Text('识别结果', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _text,
                  maxLines: null,
                  minLines: 8,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '识别出来的文字会出现在这里，可以直接改。',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: '书名',
                    helperText: '留空就用第一行',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _saveAsBook,
                  icon: const Icon(Icons.library_add_outlined),
                  label: const Text('保存为书籍'),
                ),
                const SizedBox(height: 16),
                Text(
                  '图片会先压到长边 1600 像素再发给你配置的识别服务，原图不会上传到'
                  '别处。识别质量取决于那个服务，应用本身不做识别。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;

    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      if (mounted) setState(() => _error = '读不到这张图');
      return;
    }
    if (!mounted) return;
    setState(() {
      _image = bytes;
      _fileName = file.name;
      _error = null;
      _text.clear();
    });
  }

  Future<void> _recognize(ServiceEndpoint endpoint) async {
    final image = _image;
    if (image == null) return;

    setState(() {
      _recognizing = true;
      _error = null;
    });

    try {
      final prepared = await OcrService.downscale(image);
      final service = OcrService(
        baseUrl: endpoint.normalizedBaseUrl,
        apiKey: ref.read(serviceProviderRepositoryProvider).readSecret(endpoint.id),
        language: endpoint.model.isEmpty ? 'chi_sim' : endpoint.model,
      );
      final text = await service.recognize(prepared);
      if (!mounted) return;
      setState(() {
        _text.text = text;
        if (_title.text.trim().isEmpty) _title.text = _suggestTitle(text);
      });
    } on OcrException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '识别失败：$e');
    } finally {
      if (mounted) setState(() => _recognizing = false);
    }
  }

  Future<void> _saveAsBook() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '还没有文字可以保存');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/ocr');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}/ocr-${DateTime.now().microsecondsSinceEpoch}.txt');
      await file.writeAsString(text, flush: true);

      final book = await ref.read(importServiceProvider).importFile(
            file.path,
            titleOverride: _title.text.trim().isEmpty
                ? _suggestTitle(text)
                : _title.text.trim(),
          );

      // 导入会把文件复制进书库，这份临时稿留着只是占空间。
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {
          // 删不掉不影响结果。
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已加入书架：${book.title}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 用第一行当书名，太长就截断。第一行往往是标题，不一定是好书名，所以界面上
  /// 可以改。
  static String _suggestTitle(String text) {
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      return trimmed.length > 30 ? trimmed.substring(0, 30) : trimmed;
    }
    return '识别文本';
  }
}

class _Picker extends StatelessWidget {
  const _Picker({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.image_outlined, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('选一张图', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '书页照片、截图、扫描件都行。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('选择图片'),
          ),
        ],
      ),
    );
  }
}
