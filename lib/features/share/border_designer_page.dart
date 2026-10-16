import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/border_asset.dart';
import '../../data/models/stretch_border.dart';
import '../../state/providers.dart';
import 'widgets/border_preview.dart';

Future<ui.Image?> loadBorderImage(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  final bytes = await file.readAsBytes();
  final completer = Completer<ui.Image?>();
  ui.decodeImageFromList(
    bytes,
    (image) {
      if (!completer.isCompleted) completer.complete(image);
    },
    onError: () {
      if (!completer.isCompleted) completer.complete(null);
    },
  );
  return completer.future;
}

/// 解码一次并缓存的边框图。
class BorderImage extends StatefulWidget {
  const BorderImage({super.key, required this.path, required this.builder});

  final String path;
  final Widget Function(BuildContext, ui.Image?) builder;

  @override
  State<BorderImage> createState() => _BorderImageState();
}

class _BorderImageState extends State<BorderImage> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BorderImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _load();
  }

  void _load() async {
    final image = await loadBorderImage(widget.path);
    if (!mounted) {
      image?.dispose();
      return;
    }
    setState(() => _image = image);
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _image);
}

/// 单张边框的设计器：拖动绿线定可拉伸区域，拖动橙框定安全区。
class BorderDesignerPage extends ConsumerStatefulWidget {
  const BorderDesignerPage({super.key, required this.assetId});

  final String assetId;

  @override
  ConsumerState<BorderDesignerPage> createState() => _BorderDesignerPageState();
}

class _BorderDesignerPageState extends ConsumerState<BorderDesignerPage> {
  late List<BorderAsset> _assets;

  @override
  void initState() {
    super.initState();
    _assets = ref.read(borderRepositoryProvider).load();
  }

  BorderAsset? get _asset {
    for (final a in _assets) {
      if (a.id == widget.assetId) return a;
    }
    return null;
  }

  void _mutate(BorderAsset asset, StretchBorder next) {
    setState(() => asset.cut = next);
    _persist();
  }

  void _persist() {
    ref.read(borderRepositoryProvider).save(_assets);
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    if (asset == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('边框不存在')),
        body: const Center(child: Text('这张边框已被删除')),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(asset.name),
        actions: [
          IconButton(
            tooltip: '重命名',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _rename(asset),
          ),
          IconButton(
            tooltip: '重置切割',
            icon: const Icon(Icons.restart_alt),
            onPressed: () => _mutate(
              asset,
              StretchBorder.guess(width: asset.width, height: asset.height),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Center(
            child: BorderImage(
              path: asset.path,
              builder: (context, image) {
                final width = MediaQuery.of(context).size.width - 32;
                final cardSize = Size(width, width * 4 / 3);
                return BorderPreview(
                  cut: asset.cut,
                  image: image,
                  cardSize: cardSize,
                  editable: true,
                  onChanged: (next) => _mutate(asset, next),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '拖动绿线选择允许拉伸的原图区域，拖动橙框选择文字与图标可占的范围。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          _modeSelector(asset),
          const SizedBox(height: 16),
          _slider(
            label: '原图显示比例',
            value: asset.cut.imageScale * 100,
            min: 5,
            max: 100,
            divisions: 95,
            format: (v) => '${v.round()}%',
            onChanged: (v) =>
                _mutate(asset, asset.cut.copyWith(imageScale: v / 100)),
          ),
          const Divider(height: 32),
          _groupTitle('可拉伸区域（源图像素）'),
          _pixelSlider(asset, '左', asset.cut.stretchLeft, asset.width, (v) =>
              asset.cut.copyWith(stretchLeft: v)),
          _pixelSlider(asset, '上', asset.cut.stretchTop, asset.height, (v) =>
              asset.cut.copyWith(stretchTop: v)),
          _pixelSlider(asset, '右', asset.cut.stretchRight, asset.width, (v) =>
              asset.cut.copyWith(stretchRight: v)),
          _pixelSlider(asset, '下', asset.cut.stretchBottom, asset.height, (v) =>
              asset.cut.copyWith(stretchBottom: v)),
          const Divider(height: 32),
          _groupTitle('安全框（占卡片宽高的比例）'),
          _ratioSlider(asset, '左', asset.cut.safe.left, (v) =>
              asset.cut.copyWith(safe: asset.cut.safe.copyWith(left: v))),
          _ratioSlider(asset, '上', asset.cut.safe.top, (v) =>
              asset.cut.copyWith(safe: asset.cut.safe.copyWith(top: v))),
          _ratioSlider(asset, '右', asset.cut.safe.right, (v) =>
              asset.cut.copyWith(safe: asset.cut.safe.copyWith(right: v))),
          _ratioSlider(asset, '下', asset.cut.safe.bottom, (v) =>
              asset.cut.copyWith(safe: asset.cut.safe.copyWith(bottom: v))),
          const SizedBox(height: 8),
          Text(
            '卡片小到装不下四个角时，整张图会等比缩小，不会把文字挤没。',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _modeSelector(BorderAsset asset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _groupTitle('伸缩方式'),
        const SizedBox(height: 8),
        SegmentedButton<StretchMode>(
          segments: const [
            ButtonSegment(
              value: StretchMode.both,
              label: Text('全部'),
              tooltip: '横竖都能拉，适合四角都有装饰的边框',
            ),
            ButtonSegment(
              value: StretchMode.horizontal,
              label: Text('水平'),
              tooltip: '只横向拉，高度固定，适合横条花边',
            ),
            ButtonSegment(
              value: StretchMode.vertical,
              label: Text('垂直'),
              tooltip: '只纵向拉，宽度固定，适合竖条花边',
            ),
          ],
          selected: {asset.cut.mode},
          showSelectedIcon: false,
          onSelectionChanged: (modes) =>
              _mutate(asset, asset.cut.copyWith(mode: modes.first)),
        ),
      ],
    );
  }

  Widget _groupTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      );

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required ValueChanged<double> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(format(value)),
      subtitle: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }

  Widget _pixelSlider(
    BorderAsset asset,
    String label,
    int value,
    int extent,
    StretchBorder Function(int) build,
  ) {
    return _slider(
      label: label,
      value: value.toDouble(),
      min: 0,
      max: extent.toDouble(),
      divisions: extent,
      format: (v) => v.round().toString(),
      onChanged: (v) => _mutate(asset, build(v.round())),
    );
  }

  Widget _ratioSlider(
    BorderAsset asset,
    String label,
    double value,
    StretchBorder Function(double) build,
  ) {
    return _slider(
      label: label,
      value: value,
      min: 0,
      max: 0.5,
      divisions: 50,
      format: (v) => '${(v * 100).round()}%',
      onChanged: (v) => _mutate(asset, build(v)),
    );
  }

  Future<void> _rename(BorderAsset asset) async {
    final controller = TextEditingController(text: asset.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名边框'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名称'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    setState(() {
      asset.name = name.trim().isEmpty ? asset.name : name.trim();
    });
    _persist();
  }
}
