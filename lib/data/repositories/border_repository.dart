import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../db/hive_setup.dart';
import '../models/border_asset.dart';

/// 边框花纹图库。图片文件放在应用私有目录，索引存在 Hive。
class BorderRepository {
  BorderRepository({Box<dynamic>? box})
      : _box = box ?? Hive.box<dynamic>(HiveBoxes.borders);

  final Box<dynamic> _box;

  static const _key = 'items';
  static const _supportedExtensions = {'png', 'jpg', 'jpeg', 'webp'};

  List<BorderAsset> load() => BorderAsset.decodeAll(_box.get(_key));

  Future<void> save(List<BorderAsset> assets) =>
      _box.put(_key, BorderAsset.encodeAll(assets));

  /// 从系统选择器导入图片，返回新加入的条目。
  ///
  /// 已经导入过的文件不会重复入库，只会被跳过。
  Future<List<BorderAsset>> pickAndImport() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _supportedExtensions.toList(),
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return const [];

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/borders');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final assets = load();
    final known = {for (final a in assets) a.id};
    final added = <BorderAsset>[];

    for (final file in picked.files) {
      final source = file.path;
      if (source == null) continue;
      final ext = _extensionOf(file.name);
      if (!_supportedExtensions.contains(ext)) continue;

      final bytes = file.bytes != null
          ? Uint8List.fromList(file.bytes!)
          : await File(source).readAsBytes();
      if (bytes.isEmpty) continue;

      final id = md5.convert(bytes).toString();
      if (known.contains(id)) continue;

      final size = await decodeImageSize(bytes);
      if (size == null) continue;

      final target = File('${dir.path}/$id.$ext');
      if (!target.existsSync()) await target.writeAsBytes(bytes);

      final asset = BorderAsset(
        id: id,
        name: _displayName(file.name),
        path: target.path,
        width: size.width,
        height: size.height,
      );
      assets.add(asset);
      known.add(id);
      added.add(asset);
    }

    await save(assets);
    return added;
  }

  Future<void> remove(BorderAsset asset) async {
    final file = File(asset.path);
    if (file.existsSync()) await file.delete();
    await save(load().where((a) => a.id != asset.id).toList());
  }

  Future<void> rename(BorderAsset asset, String name) async {
    final assets = load();
    for (final a in assets) {
      if (a.id != asset.id) continue;
      a.name = name.trim().isEmpty ? a.name : name.trim();
      break;
    }
    await save(assets);
  }

  static String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  static String _displayName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot <= 0 ? fileName : fileName.substring(0, dot);
  }
}

/// 解出图片的像素尺寸。非图片字节返回 null。
Future<({int width, int height})?> decodeImageSize(Uint8List bytes) {
  final completer = Completer<({int width, int height})?>();
  ui.decodeImageFromList(
    bytes,
    (image) {
      final size = (width: image.width, height: image.height);
      image.dispose();
      if (!completer.isCompleted) completer.complete(size);
    },
    onError: () {
      if (!completer.isCompleted) completer.complete(null);
    },
  );
  return completer.future;
}
