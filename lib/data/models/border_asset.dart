import 'dart:convert';

import 'package:goodreader/data/models/stretch_border.dart';

/// 图库里的一张边框花纹图。
///
/// [cut] 是这张图的切割与铺放方式。整条记录可以原地序列化成 Map，
/// 所以仓储层不需要额外定义一套平行结构。
class BorderAsset {
  BorderAsset({
    required this.id,
    required this.name,
    required this.path,
    required this.width,
    required this.height,
    StretchBorder? cut,
  }) : cut = cut ??
            StretchBorder.guess(width: width, height: height);

  final String id;
  String name;
  final String path;
  final int width;
  final int height;
  StretchBorder cut;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'path': path,
        'width': width,
        'height': height,
        'stretchLeft': cut.stretchLeft,
        'stretchTop': cut.stretchTop,
        'stretchRight': cut.stretchRight,
        'stretchBottom': cut.stretchBottom,
        'mode': cut.mode.index,
        'imageScale': cut.imageScale,
        'safeLeft': cut.safe.left,
        'safeTop': cut.safe.top,
        'safeRight': cut.safe.right,
        'safeBottom': cut.safe.bottom,
      };

  /// 读回一条记录。坏数据返回 null，由调用方跳过而不是抛异常。
  static BorderAsset? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final path = raw['path'];
    if (id is! String || name is! String || path is! String) return null;
    final width = raw['width'];
    final height = raw['height'];
    if (width is! int || height is! int || width <= 0 || height <= 0) {
      return null;
    }
    final modeIndex = raw['mode'];
    return BorderAsset(
      id: id,
      name: name,
      path: path,
      width: width,
      height: height,
      cut: StretchBorder.create(
        width: width,
        height: height,
        stretchLeft: raw['stretchLeft'] is int ? raw['stretchLeft'] as int : 0,
        stretchTop: raw['stretchTop'] is int ? raw['stretchTop'] as int : 0,
        stretchRight: raw['stretchRight'] is int ? raw['stretchRight'] as int : 0,
        stretchBottom:
            raw['stretchBottom'] is int ? raw['stretchBottom'] as int : 0,
        safe: SafeArea(
          left: raw['safeLeft'] is num ? (raw['safeLeft'] as num).toDouble() : 0.08,
          top: raw['safeTop'] is num ? (raw['safeTop'] as num).toDouble() : 0.10,
          right:
              raw['safeRight'] is num ? (raw['safeRight'] as num).toDouble() : 0.08,
          bottom: raw['safeBottom'] is num
              ? (raw['safeBottom'] as num).toDouble()
              : 0.10,
        ),
        mode: modeIndex is int && modeIndex >= 0 && modeIndex < 3
            ? BorderStretchMode.values[modeIndex]
            : BorderStretchMode.both,
        imageScale: raw['imageScale'] is num
            ? (raw['imageScale'] as num).toDouble()
            : 1.0,
      ),
    );
  }

  /// 把整个图库编码成一行文本，便于迁移与排错。
  static String encodeAll(List<BorderAsset> assets) =>
      jsonEncode(assets.map((a) => a.toMap()).toList());

  static List<BorderAsset> decodeAll(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(BorderAsset.fromMap)
          .whereType<BorderAsset>()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }
}
