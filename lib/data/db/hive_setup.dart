import 'package:hive_flutter/hive_flutter.dart';

import '../models/book.dart';
import '../models/chapter.dart';
import '../models/note.dart';
import '../models/reading_session.dart';

/// Names of every Hive box used by the app.
class HiveBoxes {
  static const books = 'books';
  static const chapters = 'chapters';
  static const notes = 'notes';
  static const sessions = 'sessions';
  static const settings = 'settings';
  static const borders = 'borders';
  static const serviceEndpoints = 'serviceEndpoints';
  static const serviceSecrets = 'serviceSecrets';
  static const aiConversations = 'aiConversations';
}

class HiveSetup {
  static bool _ready = false;

  static Future<void> init({String? subDir}) async {
    if (_ready) return;
    await Hive.initFlutter(subDir ?? 'goodreader');

    Hive.registerAdapter(BookAdapter());
    Hive.registerAdapter(ChapterMetaAdapter());
    Hive.registerAdapter(ChapterListAdapter());
    Hive.registerAdapter(BookNoteAdapter());
    Hive.registerAdapter(ReadingSessionAdapter());

    await Future.wait([
      Hive.openBox<Book>(HiveBoxes.books),
      Hive.openBox<ChapterList>(HiveBoxes.chapters),
      Hive.openBox<BookNote>(HiveBoxes.notes),
      Hive.openBox<ReadingSession>(HiveBoxes.sessions),
      Hive.openBox<dynamic>(HiveBoxes.settings),
      Hive.openBox<dynamic>(HiveBoxes.borders),
      Hive.openBox<dynamic>(HiveBoxes.serviceEndpoints),
      Hive.openBox<dynamic>(HiveBoxes.serviceSecrets),
      Hive.openBox<dynamic>(HiveBoxes.aiConversations),
    ]);

    _ready = true;
  }
}
