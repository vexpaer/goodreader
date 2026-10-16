import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../data/db/hive_setup.dart';
import '../data/models/book.dart';
import '../data/models/note.dart';
import '../data/models/reading_session.dart';
import '../data/repositories/book_repository.dart';
import '../data/repositories/border_repository.dart';
import '../data/repositories/service_provider_repository.dart';
import '../data/repositories/note_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/stats_repository.dart';
import '../services/import_service.dart';
import '../services/native_service.dart';
import '../services/tts_service.dart';
import '../services/update_service.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Repositories & services
// ---------------------------------------------------------------------------

final bookRepositoryProvider = Provider<BookRepository>((_) => BookRepository());
final noteRepositoryProvider = Provider<NoteRepository>((_) => NoteRepository());
final statsRepositoryProvider =
    Provider<StatsRepository>((_) => StatsRepository());
final settingsRepositoryProvider =
    Provider<SettingsRepository>((_) => SettingsRepository());

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(ref.read(bookRepositoryProvider)),
);

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});

final nativeServiceProvider =
    Provider<NativeService>((_) => const NativeService());

final updateServiceProvider =
    Provider<UpdateService>((_) => const UpdateService());

final borderRepositoryProvider =
    Provider<BorderRepository>((_) => BorderRepository());

final serviceProviderRepositoryProvider =
    Provider<ServiceProviderRepository>((_) => ServiceProviderRepository());

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class SettingsController extends ChangeNotifier {
  SettingsController(this._repo)
      : app = _repo.loadApp(),
        reader = _repo.loadReader();

  final SettingsRepository _repo;
  AppSettings app;
  ReaderSettings reader;

  Future<void> updateApp(void Function(AppSettings s) mutate) async {
    mutate(app);
    notifyListeners();
    await _repo.saveApp(app);
  }

  Future<void> updateReader(void Function(ReaderSettings s) mutate) async {
    mutate(reader);
    notifyListeners();
    await _repo.saveReader(reader);
  }
}

final settingsControllerProvider =
    ChangeNotifierProvider<SettingsController>((ref) {
  return SettingsController(ref.read(settingsRepositoryProvider));
});

// ---------------------------------------------------------------------------
// Bookshelf
// ---------------------------------------------------------------------------

enum SortMode { recentlyRead, recentlyAdded, title, author, progress }

extension SortModeX on SortMode {
  String get label => switch (this) {
        SortMode.recentlyRead => '最近阅读',
        SortMode.recentlyAdded => '最近添加',
        SortMode.title => '书名',
        SortMode.author => '作者',
        SortMode.progress => '阅读进度',
      };
}

class BooksController extends ChangeNotifier {
  BooksController(this._repo) {
    _sub = _repo.box.watch().listen((_) => _reload());
    _reload();
  }

  final BookRepository _repo;
  StreamSubscription<BoxEvent>? _sub;

  List<Book> _all = const [];
  SortMode sortMode = SortMode.recentlyAdded;
  bool favoritesOnly = false;
  String? tagFilter;
  String query = '';

  List<Book> get all => _all;

  List<Book> get visible {
    Iterable<Book> items = _all.where((b) => !b.isPrivate);
    if (favoritesOnly) items = items.where((b) => b.isFavorite);
    if (tagFilter != null) {
      items = items.where((b) => b.tags.contains(tagFilter));
    }
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      items = items.where((b) =>
          b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q));
    }
    final list = items.toList();
    switch (sortMode) {
      case SortMode.recentlyAdded:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case SortMode.recentlyRead:
        list.sort((a, b) => (b.lastReadAt ?? b.addedAt)
            .compareTo(a.lastReadAt ?? a.addedAt));
      case SortMode.title:
        list.sort((a, b) => a.title.compareTo(b.title));
      case SortMode.author:
        list.sort((a, b) => a.displayAuthor.compareTo(b.displayAuthor));
      case SortMode.progress:
        list.sort((a, b) => b.progress.compareTo(a.progress));
    }
    return list;
  }

  List<String> get allTags {
    final set = <String>{};
    for (final b in _all) {
      set.addAll(b.tags);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Book> get privateBooks =>
      _all.where((b) => b.isPrivate).toList(growable: false);

  Book? byId(String id) => _repo.byId(id);

  void _reload() {
    _all = _repo.all();
    notifyListeners();
  }

  void setSort(SortMode mode) {
    sortMode = mode;
    notifyListeners();
  }

  void setFavoritesOnly(bool value) {
    favoritesOnly = value;
    notifyListeners();
  }

  void setTagFilter(String? tag) {
    tagFilter = tag;
    notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  Future<void> save(Book book) async {
    await _repo.save(book.copyWith(updatedAt: DateTime.now()));
    _reload();
  }

  Future<void> toggleFavorite(Book book) =>
      save(book.copyWith(isFavorite: !book.isFavorite));

  Future<void> togglePrivate(Book book) =>
      save(book.copyWith(isPrivate: !book.isPrivate));

  Future<void> setTags(Book book, List<String> tags) =>
      save(book.copyWith(tags: tags));

  Future<void> delete(Book book, {required ImportService importer}) async {
    await importer.deleteBook(book);
    _reload();
  }

  Future<void> recordProgress(
    Book book, {
    required int chapterIndex,
    required int offset,
    required double progress,
  }) async {
    await _repo.save(book.copyWith(
      lastChapterIndex: chapterIndex,
      lastOffset: offset,
      progress: progress.clamp(0.0, 1.0),
      lastReadAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    _reload();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final booksControllerProvider =
    ChangeNotifierProvider<BooksController>((ref) {
  return BooksController(ref.read(bookRepositoryProvider));
});

final bookByIdProvider = Provider.family<Book?, String>((ref, id) {
  ref.watch(booksControllerProvider);
  return ref.read(bookRepositoryProvider).byId(id);
});

// ---------------------------------------------------------------------------
// Notes
// ---------------------------------------------------------------------------

class NotesController extends ChangeNotifier {
  NotesController(this._repo) {
    _sub = _repo.allBox.watch().listen((_) => notifyListeners());
  }

  final NoteRepository _repo;
  StreamSubscription<BoxEvent>? _sub;

  List<BookNote> all() => _repo.all();

  List<BookNote> forBook(String bookId) => _repo.forBook(bookId);

  Future<void> save(BookNote note) async {
    await _repo.save(note);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await _repo.remove(id);
    notifyListeners();
  }

  Future<void> addHighlight({
    required String bookId,
    required int chapterIndex,
    required int start,
    required int end,
    required String text,
    int color = 0xFFFFD54F,
  }) =>
      save(BookNote(
        id: _uuid.v4(),
        bookId: bookId,
        type: NoteType.highlight,
        chapterIndex: chapterIndex,
        start: start,
        end: end,
        text: text,
        color: color,
      ));

  Future<void> addBookmark({
    required String bookId,
    required int chapterIndex,
    required int offset,
    String text = '',
  }) =>
      save(BookNote(
        id: _uuid.v4(),
        bookId: bookId,
        type: NoteType.bookmark,
        chapterIndex: chapterIndex,
        start: offset,
        end: offset,
        text: text,
      ));

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final notesControllerProvider =
    ChangeNotifierProvider<NotesController>((ref) {
  return NotesController(ref.read(noteRepositoryProvider));
});

// ---------------------------------------------------------------------------
// Statistics
// ---------------------------------------------------------------------------

class StatsController extends ChangeNotifier {
  StatsController(this._repo) {
    _sub = _repo.box.watch().listen((_) => notifyListeners());
  }

  final StatsRepository _repo;
  StreamSubscription<BoxEvent>? _sub;

  StatsSummary today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return _repo.summary(from: start, to: start.add(const Duration(days: 1)));
  }

  StatsSummary lastDays(int days) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    return _repo.summary(from: start);
  }

  StatsSummary allTime() => _repo.summary();

  Future<void> log({
    required String bookId,
    required int seconds,
    int chars = 0,
    DateTime? startedAt,
  }) async {
    if (seconds <= 0 && chars <= 0) return;
    await _repo.add(ReadingSession(
      id: _uuid.v4(),
      bookId: bookId,
      startedAt: startedAt ?? DateTime.now(),
      seconds: seconds,
      chars: chars,
    ));
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final statsControllerProvider =
    ChangeNotifierProvider<StatsController>((ref) {
  return StatsController(ref.read(statsRepositoryProvider));
});

// ---------------------------------------------------------------------------
// Import
// ---------------------------------------------------------------------------

class ImportResultView {
  ImportResultView(this.imported, this.skipped, this.failed);

  final List<Book> imported;
  final List<String> skipped;
  final List<String> failed;
}

/// Convenience wrapper used by the UI.
class ImportController {
  ImportController(this._service, this._books);

  final ImportService _service;
  final BooksController _books;

  Future<ImportResultView> pickAndImport() async {
    final result = await _service.pickAndImport();
    return ImportResultView(result.imported, result.skipped, result.failed);
  }
}

final importControllerProvider = Provider<ImportController>((ref) {
  return ImportController(
    ref.read(importServiceProvider),
    ref.read(booksControllerProvider),
  );
});

/// Kept for symmetry with the box names declared in [HiveBoxes].
const settingsBoxName = HiveBoxes.settings;
