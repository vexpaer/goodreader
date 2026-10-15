import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/models/book.dart';
import '../data/models/chapter.dart';
import '../data/repositories/book_repository.dart';
import '../features/reader/engines/document.dart';
import '../features/reader/engines/epub_engine.dart';
import '../features/reader/engines/txt_engine.dart';

const _uuid = Uuid();

/// Outcome of a batch import.
class ImportResult {
  const ImportResult({
    required this.imported,
    required this.skipped,
    required this.failed,
  });

  final List<Book> imported;
  final List<String> skipped;
  final List<String> failed;

  bool get isEmpty => imported.isEmpty && skipped.isEmpty && failed.isEmpty;
}

/// Copies picked files into app-private storage and indexes their metadata.
class ImportService {
  ImportService(this._books);

  final BookRepository _books;

  static const supportedExtensions = {
    'txt', 'epub', 'pdf', 'mobi', 'azw', 'azw3', 'cbz', 'cbr',
  };

  Future<Directory> _booksDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/books');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Directory> _coversDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/covers');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Opens the system picker and imports every selected file.
  Future<ImportResult> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return const ImportResult(imported: [], skipped: [], failed: []);
    }
    return importPaths(result.files.map((f) => f.path).whereType<String>());
  }

  Future<ImportResult> importPaths(Iterable<String> paths) async {
    final imported = <Book>[];
    final skipped = <String>[];
    final failed = <String>[];

    for (final path in paths) {
      try {
        final ext = _extension(path);
        if (!supportedExtensions.contains(ext)) {
          skipped.add('${_basename(path)}（不支持的格式 .$ext）');
          continue;
        }
        final book = await importFile(path);
        imported.add(book);
      } catch (e) {
        failed.add('${_basename(path)}：$e');
      }
    }

    return ImportResult(imported: imported, skipped: skipped, failed: failed);
  }

  /// Imports a single file located at [sourcePath].
  Future<Book> importFile(String sourcePath, {String? titleOverride}) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw BookParseException('文件不存在：$sourcePath');
    }

    final size = await source.length();
    final ext = _extension(sourcePath);
    final id = md5.convert('$sourcePath|$size'.codeUnits).toString();

    final existing = _books.byId(id);
    if (existing != null) return existing;

    final booksDir = await _booksDir();
    final stored = File('${booksDir.path}/$id.$ext');
    if (!stored.existsSync()) {
      await source.copy(stored.path);
    }

    final format = BookFormatX.fromExtension(ext);
    final opened = await _parse(stored.path, format);

    String? coverPath;
    if (opened.coverBytes != null) {
      coverPath = await _writeCover(id, opened.coverBytes!);
    }

    final nameFromFile = _basename(sourcePath).replaceAll(RegExp(r'\.[^.]+$'), '');
    final book = Book(
      id: id,
      title: titleOverride ?? opened.title ?? nameFromFile,
      author: opened.author ?? '',
      intro: opened.intro ?? '',
      coverPath: coverPath,
      filePath: stored.path,
      format: format,
      fileSize: size,
      chapterCount: opened.chapters.length,
      encoding: opened.encoding ?? 'utf-8',
    );

    await _books.save(book);
    await _books.saveChapters(
      ChapterList(bookId: id, chapters: opened.chapters),
    );
    return book;
  }

  Future<OpenedBook> _parse(String path, BookFormat format) async {
    switch (format) {
      case BookFormat.txt:
        final doc = await TxtDocument.open(path);
        return OpenedBook(
          chapters: doc.chapters,
          title: null,
          encoding: 'utf-8',
        );
      case BookFormat.epub:
        final doc = await EpubDocument.open(path);
        return OpenedBook(
          chapters: doc.chapters,
          title: doc.title,
          author: doc.author,
          intro: doc.intro,
          coverBytes: doc.coverBytes,
        );
      default:
        // PDF / MOBI / AZW3 / CBZ arrive in later milestones. Index them as a
        // single placeholder chapter so they still appear on the shelf.
        return OpenedBook(
          chapters: [ChapterMeta(index: 0, title: '正文', start: 0, end: 0)],
        );
    }
  }

  Future<String> _writeCover(String id, Uint8List bytes) async {
    final dir = await _coversDir();
    final path = '${dir.path}/$id.img';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  static String _extension(String path) {
    final name = _basename(path);
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  static String _basename(String path) =>
      path.split(RegExp(r'[\\/]')).last;

  /// Removes a book, its chapters, cover and stored file.
  Future<void> deleteBook(Book book) async {
    await _books.remove(book.id);
    for (final p in [book.filePath, book.coverPath]) {
      if (p == null) continue;
      final f = File(p);
      if (f.existsSync()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }

  static String newId() => _uuid.v4();
}
