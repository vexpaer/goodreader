import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/border_asset.dart';
import '../../state/providers.dart';
import 'border_designer_page.dart';
import 'widgets/border_preview.dart';

/// 边框花纹图库。导入图片后逐张进入设计器调整切割方式。
class BorderGalleryPage extends ConsumerStatefulWidget {
  const BorderGalleryPage({super.key});

  @override
  ConsumerState<BorderGalleryPage> createState() => _BorderGalleryPageState();
}

class _BorderGalleryPageState extends ConsumerState<BorderGalleryPage> {
  late List<BorderAsset> _assets;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _assets = ref.read(borderRepositoryProvider).load();
  }

  Future<void> _import() async {
    final before = _assets.length;
    await ref.read(borderRepositoryProvider).pickAndImport();
    if (!mounted) return;
    setState(_reload);
    if (_assets.length == before) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有新图片，可能已经导入过')),
      );
    }
  }

  Future<void> _remove(BorderAsset asset) async {
    await ref.read(borderRepositoryProvider).remove(asset);
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('边框图库'),
        actions: [
          IconButton(
            tooltip: '导入图片',
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: _import,
          ),
        ],
      ),
      body: _assets.isEmpty
          ? _EmptyState(onImport: _import)
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170,
                childAspectRatio: 0.78,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _assets.length,
              itemBuilder: (context, i) => _Tile(
                asset: _assets[i],
                onTap: () => context.push('/borders/${_assets[i].id}'),
                onDelete: () => _remove(_assets[i]),
              ),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.crop_free, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('还没有边框图', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '导入一张边框花纹图，进入设计器后拖动绿线设定可以拉伸的区域，'
              '拖动橙框设定安全区。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('导入图片'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.asset, required this.onTap, required this.onDelete});

  final BorderAsset asset;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      onLongPress: () => _showActions(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LayoutBuilder(
                builder: (context, constraints) => BorderImage(
                  path: asset.path,
                  builder: (context, image) => BorderPreview(
                    cut: asset.cut,
                    image: image,
                    cardSize: Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    ),
                    editable: false,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            asset.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          Text(
            '${asset.width}×${asset.height}',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('进入设计器'),
              onTap: () {
                Navigator.pop(sheetContext);
                onTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () {
                Navigator.pop(sheetContext);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
