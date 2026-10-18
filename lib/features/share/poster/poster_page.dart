import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/book.dart';
import '../../../data/models/border_asset.dart';
import '../../../data/models/stretch_border.dart' show StretchBorder;
import '../../../state/providers.dart';
import '../../bookshelf/widgets/book_cover.dart';
import '../widgets/border_image.dart';
import 'poster_canvas.dart';
import 'poster_spec.dart';

/// 海报编辑与导出。
///
/// 预览是按 360 宽排版的，导出时按 3 倍抓图得到 1080 宽。所以界面上看到的
/// 排版和导出的成品完全一致——不是两套布局。
class PosterPage extends ConsumerStatefulWidget {
  const PosterPage({super.key, required this.initial, this.book});

  final PosterSpec initial;

  /// 书籍卡要用到封面与作者。
  final Book? book;

  @override
  ConsumerState<PosterPage> createState() => _PosterPageState();
}

class _PosterPageState extends ConsumerState<PosterPage> {
  final _boundaryKey = GlobalKey();

  late PosterSpec _spec = widget.initial;
  bool _busy = false;

  /// 导出宽度。3:4 时得到 1080×1440，1:1 时 1080×1080。
  static const _exportWidth = 1080.0;

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(borderRepositoryProvider).load();

    return Scaffold(
      appBar: AppBar(
        title: const Text('分享海报'),
        actions: [
          IconButton(
            tooltip: '分享',
            onPressed: _busy ? null : () => _export(share: true),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _Preview(boundaryKey: _boundaryKey, spec: _spec, book: widget.book, assets: assets)),
          SizedBox(
            height: 250,
            child: _Controls(
              spec: _spec,
              assets: assets,
              onChanged: (next) => setState(() => _spec = next),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _export(share: false),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('保存图片'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _export(share: true),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.ios_share),
                      label: Text(_busy ? '正在导出' : '分享'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export({required bool share}) async {
    if (_spec.isBlank) {
      _toast('这张海报还没有内容');
      return;
    }

    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) {
        _toast('抓图失败，换一个比例再试');
        return;
      }

      final name = 'goodreader-${DateTime.now().millisecondsSinceEpoch}.png';
      final native = ref.read(nativeServiceProvider);

      if (share) {
        final ok = await native.shareImage(bytes, name);
        if (!ok) _toast('没有找到可以分享的应用');
      } else {
        final path = await native.saveImage(bytes, name);
        _toast(path == null ? '保存失败' : '已保存到 $path');
      }
    } catch (e) {
      _toast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List?> _capture() async {
    final boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final canvas = _spec.aspect.canvasSize();
    final image = await boundary.toImage(pixelRatio: _exportWidth / canvas.width);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.boundaryKey,
    required this.spec,
    required this.book,
    required this.assets,
  });

  final GlobalKey boundaryKey;
  final PosterSpec spec;
  final Book? book;
  final List<BorderAsset> assets;

  @override
  Widget build(BuildContext context) {
    final canvas = spec.aspect.canvasSize();
    final asset = _selectedAsset();

    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: RepaintBoundary(
            key: boundaryKey,
            child: asset == null
                ? _canvas(canvas, null, null)
                : BorderImage(
                    path: asset.path,
                    builder: (_, image) =>
                        _canvas(canvas, image, asset.cut),
                  ),
          ),
        ),
      ),
    );
  }

  BorderAsset? _selectedAsset() {
    final id = spec.borderAssetId;
    if (id == null) return null;
    for (final asset in assets) {
      if (asset.id == id) return asset;
    }
    return null;
  }

  Widget _canvas(Size canvas, ui.Image? image, StretchBorder? cut) =>
      PosterCanvas(
        spec: spec,
        size: canvas,
        borderImage: image,
        borderCut: cut,
        cover: spec.kind == PosterKind.book && book != null
            ? BookCover(
                book: book!,
                width: canvas.width * 0.34,
                height: canvas.width * 0.34 * 1.5,
                radius: 6,
                spineLight: true,
              )
            : null,
      );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.spec,
    required this.assets,
    required this.onChanged,
  });

  final PosterSpec spec;
  final List<BorderAsset> assets;
  final ValueChanged<PosterSpec> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<PosterKind>(
                segments: [
                  for (final kind in PosterKind.values)
                    ButtonSegment(value: kind, label: Text(kind.label)),
                ],
                selected: {spec.kind},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    onChanged(spec.copyWith(kind: value.first)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('配色', style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          children: [
            for (final palette in PosterPalette.values)
              _PaletteChip(
                palette: palette,
                selected: spec.palette == palette,
                onTap: () => onChanged(spec.copyWith(palette: palette)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<PosterAspect>(
                segments: [
                  for (final aspect in PosterAspect.values)
                    ButtonSegment(value: aspect, label: Text(aspect.label)),
                ],
                selected: {spec.aspect},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    onChanged(spec.copyWith(aspect: value.first)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('边框', style: theme.textTheme.labelMedium),
            const Spacer(),
            if (spec.borderAssetId != null)
              Text(
                '大小 ${(spec.borderScale * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ChoiceChip(
                label: const Text('无'),
                selected: spec.borderAssetId == null,
                onSelected: (_) => onChanged(spec.copyWith(borderAssetId: null)),
              ),
              const SizedBox(width: 8),
              for (final asset in assets) ...[
                ChoiceChip(
                  label: Text(asset.name, overflow: TextOverflow.ellipsis),
                  selected: spec.borderAssetId == asset.id,
                  onSelected: (_) =>
                      onChanged(spec.copyWith(borderAssetId: asset.id)),
                ),
                const SizedBox(width: 8),
              ],
              if (assets.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '还没有边框图，去「边框图库」导入一张',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        if (spec.borderAssetId != null)
          Slider(
            value: spec.borderScale,
            min: 0.3,
            max: 1,
            onChanged: (value) =>
                onChanged(spec.copyWith(borderScale: value)),
          ),
        if (spec.kind == PosterKind.quote)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('左上角大引号', style: theme.textTheme.labelMedium),
            value: spec.showQuoteMark,
            onChanged: (value) =>
                onChanged(spec.copyWith(showQuoteMark: value)),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '导出宽度 1080 像素，${spec.aspect.label} 比例。',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final PosterPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            palette.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// 打开海报编辑页。
///
/// 用 Navigator 而不是路由：海报是一次性的编辑流程，不需要深链接，而且它带着
/// 一份临时样式状态——回到这个地址应该是重新开始，不是恢复上次调了一半的配色。
Future<void> openPoster(
  BuildContext context,
  PosterSpec spec, {
  Book? book,
}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PosterPage(initial: spec, book: book),
      ),
    );
