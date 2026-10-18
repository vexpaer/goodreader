import 'dart:convert';

import 'package:hive/hive.dart';

import '../db/hive_setup.dart';
import '../../services/booksource/book_source.dart';

/// 书源的增删改查与导入导出。
///
/// 整份列表存成一条 JSON，跟边框图库一个套路：书源数量是几十的量级，逐条建箱
/// 只会多一层索引，换不来任何好处。
class BookSourceRepository {
  BookSourceRepository({Box<dynamic>? box})
      : _box = box ?? Hive.box<dynamic>(HiveBoxes.bookSources);

  final Box<dynamic> _box;

  static const _key = 'items';

  List<BookSource> load() {
    final raw = _box.get(_key);
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(BookSource.fromMap)
          .whereType<BookSource>()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<void> save(List<BookSource> sources) => _box.put(
        _key,
        jsonEncode(sources.map((s) => s.toMap()).toList()),
      );

  Future<void> add(BookSource source) async {
    final list = load().toList();
    list.removeWhere((s) => s.id == source.id);
    list.add(source);
    await save(list);
  }

  Future<void> remove(String id) async {
    await save(load().where((s) => s.id != id).toList());
  }

  BookSource? byId(String id) {
    for (final source in load()) {
      if (source.id == id) return source;
    }
    return null;
  }

  /// 从分享来的 JSON 导入。支持单个对象与数组两种形态。
  ///
  /// 返回真正新增的条数。同名同地址的视为同一个源，重复导入不会产生副本——
  /// 用户往往会把同一个源导入好几次，每次多一份列表就没法用了。
  Future<int> importJson(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('不是合法的 JSON');
    }

    final candidates = switch (decoded) {
      final List list => list,
      final Map map => [map],
      _ => const [],
    };

    final incoming = <BookSource>[];
    for (final item in candidates) {
      final source = BookSource.fromMap(item);
      if (source != null) incoming.add(source);
    }
    if (incoming.isEmpty) {
      throw const FormatException('里面没有可用的书源');
    }

    final existing = load().toList();
    var added = 0;
    for (final source in incoming) {
      final duplicate = existing.any((s) =>
          s.id == source.id || (s.name == source.name && s.baseUrl == source.baseUrl));
      if (duplicate) continue;
      existing.add(source);
      added++;
    }
    if (added > 0) await save(existing);
    return added;
  }

  String exportJson() =>
      const JsonEncoder.withIndent('  ')
          .convert(load().map((s) => s.toMap()).toList());
}
