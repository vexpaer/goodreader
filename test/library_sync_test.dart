import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/data/models/book.dart';
import 'package:goodreader/data/models/chapter.dart';
import 'package:goodreader/data/models/note.dart';
import 'package:goodreader/data/repositories/book_repository.dart';
import 'package:goodreader/data/repositories/note_repository.dart';
import 'package:goodreader/services/sync/library_sync.dart';
import 'package:goodreader/services/sync/sync_service.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory temp;
  late Box<Book> booksBox;
  late Box<ChapterList> chaptersBox;
  late Box<BookNote> notesBox;
  late BookRepository books;
  late NoteRepository notes;
  late LibrarySync library;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('goodreader_sync_test');
    Hive.init(temp.path);
    Hive.registerAdapter(BookAdapter());
    Hive.registerAdapter(ChapterMetaAdapter());
    Hive.registerAdapter(ChapterListAdapter());
    Hive.registerAdapter(BookNoteAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  setUp(() async {
    booksBox = await Hive.openBox<Book>('books');
    chaptersBox = await Hive.openBox<ChapterList>('chapters');
    notesBox = await Hive.openBox<BookNote>('notes');
    await booksBox.clear();
    await notesBox.clear();
    books = BookRepository(box: booksBox, chapterBox: chaptersBox);
    notes = NoteRepository(box: notesBox);
    library = LibrarySync(books: books, notes: notes);
  });

  Book sample({
    String id = 'b1',
    int fileSize = 100,
    double progress = 0.1,
    int lastChapterIndex = 1,
    int lastOffset = 5,
    List<String> tags = const ['小说'],
    DateTime? updatedAt,
  }) =>
      Book(
        id: id,
        title: '测试书',
        author: '某人',
        filePath: '/tmp/$id.txt',
        format: BookFormat.txt,
        fileSize: fileSize,
        progress: progress,
        lastChapterIndex: lastChapterIndex,
        lastOffset: lastOffset,
        tags: List<String>.from(tags),
        updatedAt: updatedAt ?? DateTime.fromMillisecondsSinceEpoch(1000),
      );

  group('collect', () {
    test('一本书一份文档，时间戳用书自己的 updatedAt', () async {
      await books.save(sample(updatedAt: DateTime.fromMillisecondsSinceEpoch(5000)));

      final documents = library.collect();
      expect(documents.length, 1);
      expect(documents.single.path, 'book_b1.json');

      final payload = jsonDecode(documents.single.payload) as Map;
      expect(payload['id'], 'b1');
      expect(payload['updatedAt'], 5000);
      // 设备相关的字段不出现在文档里。
      expect(payload.containsKey('filePath'), isFalse);
      expect(payload.containsKey('coverPath'), isFalse);
    });

    test('笔记按书分组，时间戳取最新一条', () async {
      await books.save(sample());
      await notes.save(BookNote(
        id: 'n1',
        bookId: 'b1',
        type: NoteType.highlight,
        chapterIndex: 0,
        text: '甲',
        createdAt: DateTime.fromMillisecondsSinceEpoch(7000),
      ));
      await notes.save(BookNote(
        id: 'n2',
        bookId: 'b1',
        type: NoteType.thought,
        chapterIndex: 1,
        text: '乙',
        createdAt: DateTime.fromMillisecondsSinceEpoch(9000),
      ));

      final documents = library.collect();
      final noteDoc =
          documents.firstWhere((d) => d.path == 'notes_b1.json');
      final payload = jsonDecode(noteDoc.payload) as Map;
      expect(payload['updatedAt'], 9000);
      expect((payload['notes'] as List).length, 2);
    });
  });

  group('mergeBook', () {
    test('同一个文件采纳云端进度', () {
      final local = sample();
      final merged = LibrarySync.mergeBook(local, {
        'fileSize': 100,
        'progress': 0.9,
        'lastChapterIndex': 7,
        'lastOffset': 42,
        'updatedAt': 1700000000000,
      });
      expect(merged.progress, 0.9);
      expect(merged.lastChapterIndex, 7);
      expect(merged.lastOffset, 42);
      expect(merged.updatedAt.millisecondsSinceEpoch, 1700000000000);
    });

    test('文件大小不同就不采纳进度，但采纳标签与收藏', () {
      final local = sample();
      final merged = LibrarySync.mergeBook(local, {
        'fileSize': 200,
        'progress': 0.9,
        'lastChapterIndex': 7,
        'lastOffset': 42,
        'tags': ['科幻'],
        'isFavorite': true,
        'updatedAt': 1700000000000,
      });
      expect(merged.progress, 0.1);
      expect(merged.lastChapterIndex, 1);
      expect(merged.lastOffset, 5);
      expect(merged.tags, ['科幻']);
      expect(merged.isFavorite, isTrue);
    });

    test('云端缺时间戳时保留本地时间，不改成 1970', () {
      final local = sample(updatedAt: DateTime.fromMillisecondsSinceEpoch(5000));
      final merged = LibrarySync.mergeBook(local, {'title': '新名字'});
      expect(merged.title, '新名字');
      expect(merged.updatedAt.millisecondsSinceEpoch, 5000);
    });

    test('字段类型不对时保持本地值', () {
      final local = sample();
      final merged = LibrarySync.mergeBook(local, {
        'title': 123,
        'tags': 'not a list',
        'progress': 'half',
      });
      expect(merged.title, '测试书');
      expect(merged.tags, ['小说']);
      expect(merged.progress, 0.1);
    });
  });

  group('apply', () {
    test('本机没有这本书就不落地', () async {
      final applied = await library.apply(SyncDocument(
        path: 'book_ghost.json',
        payload: jsonEncode({'id': 'ghost', 'title': '不存在的书'}),
      ));
      expect(applied, isFalse);
      expect(books.all(), isEmpty);
    });

    test('本机有这本书就合并并保存', () async {
      await books.save(sample());
      final applied = await library.apply(SyncDocument(
        path: 'book_b1.json',
        payload: jsonEncode({
          'id': 'b1',
          'fileSize': 100,
          'title': '云端改过的名字',
          'progress': 0.75,
          'updatedAt': 8000,
        }),
      ));
      expect(applied, isTrue);
      final saved = books.byId('b1')!;
      expect(saved.title, '云端改过的名字');
      expect(saved.progress, 0.75);
    });

    test('笔记按云端那份替换，本地多出来的删掉', () async {
      await books.save(sample());
      await notes.save(BookNote(
        id: 'keep',
        bookId: 'b1',
        type: NoteType.highlight,
        chapterIndex: 0,
        text: '旧的',
      ));
      await notes.save(BookNote(
        id: 'stale',
        bookId: 'b1',
        type: NoteType.highlight,
        chapterIndex: 1,
        text: '别处已删',
      ));

      final applied = await library.apply(SyncDocument(
        path: 'notes_b1.json',
        payload: jsonEncode({
          'bookId': 'b1',
          'updatedAt': 9000,
          'notes': [
            {
              'id': 'keep',
              'bookId': 'b1',
              'type': NoteType.highlight.index,
              'chapterIndex': 0,
              'start': 0,
              'end': 2,
              'text': '新的',
              'note': '',
              'color': 0xFFFFD54F,
              'createdAt': 4000,
            },
            {
              'id': 'fresh',
              'bookId': 'b1',
              'type': NoteType.thought.index,
              'chapterIndex': 2,
              'start': 0,
              'end': 0,
              'text': '云端新增',
              'note': '',
              'color': 0xFFFFD54F,
              'createdAt': 9500,
            },
          ],
        }),
      ));

      expect(applied, isTrue);
      final remaining = notes.forBook('b1');
      expect(remaining.map((n) => n.id).toSet(), {'keep', 'fresh'});
      expect(remaining.firstWhere((n) => n.id == 'keep').text, '新的');
    });

    test('笔记所属的书不在本机就不落地', () async {
      final applied = await library.apply(SyncDocument(
        path: 'notes_ghost.json',
        payload: jsonEncode({'bookId': 'ghost', 'notes': []}),
      ));
      expect(applied, isFalse);
    });

    test('坏 JSON 与不认识的文档都不落地', () async {
      expect(
        await library.apply(SyncDocument(path: 'book_b1.json', payload: '{')),
        isFalse,
      );
      expect(
        await library.apply(SyncDocument(path: 'other.json', payload: '{}')),
        isFalse,
      );
    });

    test('坏条目跳过，好的照常写入', () async {
      await books.save(sample());
      await library.apply(SyncDocument(
        path: 'notes_b1.json',
        payload: jsonEncode({
          'bookId': 'b1',
          'notes': [
            {'id': 'ok', 'bookId': 'b1', 'type': 0, 'chapterIndex': 0},
            {'bookId': 'b1'},
            'garbage',
          ],
        }),
      ));
      expect(notes.forBook('b1').map((n) => n.id), ['ok']);
    });
  });

  group('往返', () {
    test('编码再合并，字段不丢也不变', () async {
      final local = sample();
      final merged = LibrarySync.mergeBook(local, {
        ...LibrarySync.encodeBook(local),
        'updatedAt': local.updatedAt.millisecondsSinceEpoch,
      });
      expect(merged.title, local.title);
      expect(merged.author, local.author);
      expect(merged.fileSize, local.fileSize);
      expect(merged.tags, local.tags);
      expect(merged.progress, local.progress);
      expect(merged.lastChapterIndex, local.lastChapterIndex);
      expect(merged.lastOffset, local.lastOffset);
    });
  });
}
