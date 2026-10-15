import 'package:hive/hive.dart';

import '../db/hive_setup.dart';
import '../models/note.dart';

class NoteRepository {
  NoteRepository({Box<BookNote>? box})
      : _box = box ?? Hive.box<BookNote>(HiveBoxes.notes);

  final Box<BookNote> _box;

  Box<BookNote> get allBox => _box;

  List<BookNote> forBook(String bookId) {
    final list = _box.values.where((n) => n.bookId == bookId).toList();
    list.sort((a, b) {
      final c = a.chapterIndex.compareTo(b.chapterIndex);
      return c != 0 ? c : a.start.compareTo(b.start);
    });
    return list;
  }

  List<BookNote> all() {
    final list = _box.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int countFor(String bookId) =>
      _box.values.where((n) => n.bookId == bookId).length;

  Future<void> save(BookNote note) => _box.put(note.id, note);

  Future<void> remove(String noteId) => _box.delete(noteId);

  Future<void> removeForBook(String bookId) async {
    final ids = _box.values
        .where((n) => n.bookId == bookId)
        .map((n) => n.id)
        .toList();
    await _box.deleteAll(ids);
  }
}
