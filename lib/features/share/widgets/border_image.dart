import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../data/services/image_header.dart';

/// 解码一张边框花纹图。
///
/// 先读文件头确认尺寸再解码：文件不是图片时能提前返回，不必等解码器报错。
/// 这一版 Flutter 的 `decodeImageFromList` 没有失败回调，所以尺寸校验是唯一的
/// 兜底——没有它，坏文件会让 Future 永远不完成。
Future<ui.Image?> loadBorderImage(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  final bytes = await file.readAsBytes();
  final header = readImageHeaderSize(bytes);
  if (header == null) return null;

  final completer = Completer<ui.Image?>();
  try {
    ui.decodeImageFromList(
      bytes,
      (image) {
        if (!completer.isCompleted) completer.complete(image);
      },
    );
  } on Object {
    if (!completer.isCompleted) completer.complete(null);
  }
  return completer.future;
}

/// 解码一次并缓存解码结果的边框图。
///
/// 设计器与海报都要用同一张图，重复解码一张 2000 像素的 PNG 要几十毫秒，
/// 拖动滑条时会一卡一卡的。
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
