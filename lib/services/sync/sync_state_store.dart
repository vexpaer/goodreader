import 'package:hive/hive.dart';

import '../../data/db/hive_setup.dart';

/// 上一次同步的时间与结果。
///
/// 存在 settings 这个通用键值箱里，只用来在界面上回答「上次是什么时候同步的」。
/// 同步本身的状态在云端，这里丢了不影响正确性。
class SyncStateStore {
  SyncStateStore({Box<dynamic>? box})
      : _box = box ?? Hive.box<dynamic>(HiveBoxes.settings);

  final Box<dynamic> _box;

  static const _lastRunKey = 'sync.lastRunAt';
  static const _lastMessageKey = 'sync.lastMessage';

  DateTime? get lastRunAt {
    final raw = _box.get(_lastRunKey);
    return raw is int ? DateTime.fromMillisecondsSinceEpoch(raw) : null;
  }

  String get lastMessage {
    final raw = _box.get(_lastMessageKey);
    return raw is String ? raw : '';
  }

  Future<void> record(DateTime at, String message) async {
    await _box.put(_lastRunKey, at.millisecondsSinceEpoch);
    await _box.put(_lastMessageKey, message);
  }
}
