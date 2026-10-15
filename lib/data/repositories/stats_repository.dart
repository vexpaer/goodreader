import 'package:hive/hive.dart';

import '../db/hive_setup.dart';
import '../models/reading_session.dart';

/// Aggregated reading numbers for a period.
class StatsSummary {
  const StatsSummary({
    required this.totalSeconds,
    required this.totalChars,
    required this.days,
    required this.byDay,
    required this.byBook,
  });

  final int totalSeconds;
  final int totalChars;
  final Set<String> days;

  /// dayKey -> seconds
  final Map<String, int> byDay;

  /// bookId -> seconds
  final Map<String, int> byBook;

  int get streakDays {
    if (days.isEmpty) return 0;
    var streak = 0;
    var cursor = DateTime.now();
    // Allow the streak to start yesterday if nothing has been read today yet.
    final todayKey = _key(cursor);
    if (!days.contains(todayKey)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (days.contains(_key(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static String _key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class StatsRepository {
  StatsRepository({Box<ReadingSession>? box})
      : _box = box ?? Hive.box<ReadingSession>(HiveBoxes.sessions);

  final Box<ReadingSession> _box;

  Box<ReadingSession> get box => _box;

  Future<void> add(ReadingSession session) => _box.put(session.id, session);

  Future<void> removeForBook(String bookId) async {
    final ids = _box.values
        .where((s) => s.bookId == bookId)
        .map((s) => s.id)
        .toList();
    await _box.deleteAll(ids);
  }

  /// [from] inclusive, [to] exclusive.
  StatsSummary summary({DateTime? from, DateTime? to}) {
    final byDay = <String, int>{};
    final byBook = <String, int>{};
    final days = <String>{};
    var totalSeconds = 0;
    var totalChars = 0;

    for (final s in _box.values) {
      if (from != null && s.startedAt.isBefore(from)) continue;
      if (to != null && !s.startedAt.isBefore(to)) continue;
      totalSeconds += s.seconds;
      totalChars += s.chars;
      days.add(s.dayKey);
      byDay.update(s.dayKey, (v) => v + s.seconds, ifAbsent: () => s.seconds);
      byBook.update(s.bookId, (v) => v + s.seconds, ifAbsent: () => s.seconds);
    }

    return StatsSummary(
      totalSeconds: totalSeconds,
      totalChars: totalChars,
      days: days,
      byDay: byDay,
      byBook: byBook,
    );
  }
}
