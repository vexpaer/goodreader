import 'package:flutter_test/flutter_test.dart';
import 'package:goodreader/data/models/book.dart';
import 'package:goodreader/data/models/note.dart';
import 'package:goodreader/features/share/poster/poster_spec.dart';

Book book({
  String title = '三体',
  String author = '刘慈欣',
  String intro = '地球往事三部曲第一部。',
  BookFormat format = BookFormat.epub,
}) =>
    Book(
      id: 'b1',
      title: title,
      author: author,
      intro: intro,
      filePath: '/tmp/b1.epub',
      format: format,
    );

BookNote note({
  String text = '  划线原文  ',
  String comment = '',
  int chapterIndex = 2,
}) =>
    BookNote(
      id: 'n1',
      bookId: 'b1',
      type: NoteType.highlight,
      chapterIndex: chapterIndex,
      text: text,
      note: comment,
    );

void main() {
  group('配色', () {
    test('四套都能读：前景与背景亮度差足够大', () {
      for (final palette in PosterPalette.values) {
        final contrast = (palette.foreground.computeLuminance() -
                palette.background.computeLuminance())
            .abs();
        expect(contrast, greaterThan(0.5), reason: palette.label);
      }
    });

    test('深浅标记与背景亮度一致', () {
      expect(PosterPalette.night.isDark, isTrue);
      expect(PosterPalette.ink.isDark, isFalse);
      expect(PosterPalette.sand.isDark, isFalse);
      expect(PosterPalette.moss.isDark, isFalse);
    });

    test('点缀色与背景不是同一个颜色', () {
      for (final palette in PosterPalette.values) {
        expect(palette.accent, isNot(palette.background), reason: palette.label);
        expect(palette.accent, isNot(palette.foreground), reason: palette.label);
      }
    });

    test('夜读用的是模板 CSS 里那三个实测值', () {
      expect(PosterPalette.night.background.value, 0xFF121418);
      expect(PosterPalette.night.foreground.value, 0xFFEEE9DF);
      expect(PosterPalette.night.accent.value, 0xFF73C7B6);
    });
  });

  group('比例', () {
    test('宽高比与画布尺寸对得上', () {
      expect(PosterAspect.portrait.ratio, closeTo(0.75, 1e-9));
      expect(PosterAspect.square.ratio, closeTo(1.0, 1e-9));
      expect(PosterAspect.story.ratio, closeTo(0.5625, 1e-9));

      final portrait = PosterAspect.portrait.canvasSize(width: 360);
      expect(portrait.width, 360);
      expect(portrait.height, closeTo(480, 1e-9));

      final square = PosterAspect.square.canvasSize(width: 360);
      expect(square.height, closeTo(360, 1e-9));

      final story = PosterAspect.story.canvasSize(width: 360);
      expect(story.height, closeTo(640, 1e-9));
    });

    test('越高的比例给正文越多行', () {
      expect(PosterAspect.square.bodyMaxLines, 8);
      expect(PosterAspect.portrait.bodyMaxLines, 12);
      expect(PosterAspect.story.bodyMaxLines, 18);
    });
  });

  group('排版尺寸', () {
    test('全部按宽度取比例', () {
      final m = PosterMetrics.of(360);
      expect(m.padding, closeTo(30.6, 1e-9));
      expect(m.titleSize, closeTo(25.92, 1e-9));
      expect(m.bodySize, closeTo(16.92, 1e-9));
      expect(m.footerSize, closeTo(11.88, 1e-9));
      expect(m.gap, closeTo(16.2, 1e-9));
      expect(m.quoteMarkSize, closeTo(57.6, 1e-9));
      expect(m.ruleWidth, closeTo(32.4, 1e-9));
    });

    test('换一个宽度整体等比', () {
      final a = PosterMetrics.of(360);
      final b = PosterMetrics.of(720);
      expect(b.bodySize, closeTo(a.bodySize * 2, 1e-9));
      expect(b.padding, closeTo(a.padding * 2, 1e-9));
    });

    test('宽度非法时退回 360 的一套值', () {
      expect(PosterMetrics.of(0).bodySize, closeTo(16.92, 1e-9));
      expect(PosterMetrics.of(-5).bodySize, closeTo(16.92, 1e-9));
    });
  });

  group('正文规整', () {
    test('行内空白压成一个空格', () {
      expect(normalizePosterText('a  b\tc\u3000d'), 'a b c d');
    });

    test('连续空行压成一行，首尾空行去掉', () {
      expect(
        normalizePosterText('\n\n第一段\n\n\n第二段\n\n'),
        '第一段\n\n第二段',
      );
    });

    test('换行本身保留', () {
      expect(normalizePosterText('甲\n乙\n丙'), '甲\n乙\n丙');
    });

    test('CRLF 与单独的 CR 都当换行', () {
      expect(normalizePosterText('甲\r\n乙\r丙'), '甲\n乙\n丙');
    });

    test('空串与纯空白返回空串', () {
      expect(normalizePosterText(''), '');
      expect(normalizePosterText('   \n\n  '), '');
    });
  });

  group('截断', () {
    test('短文本原样返回（含规整）', () {
      expect(truncateForPoster('  短  文本  '), '短 文本');
    });

    test('超长且无标点时按字数截断并加省略号', () {
      final long = '甲' * 300;
      final out = truncateForPoster(long, maxChars: 220);
      expect(out.length, 221);
      expect(out.endsWith('…'), isTrue);
      expect(out.startsWith('甲' * 220), isTrue);
    });

    test('在靠后的标点处断开', () {
      final text = '${'甲' * 200}。${'乙' * 100}';
      final out = truncateForPoster(text, maxChars: 220);
      // 标点在下标 200，超过 220 的六成，所以停在标点之后。
      expect(out, '${'甲' * 200}。…');
    });

    test('标点太靠前就不理会，按字数切', () {
      final text = '${'甲' * 50}。${'乙' * 200}';
      final out = truncateForPoster(text, maxChars: 220);
      expect(out.length, 221);
      expect(out.endsWith('…'), isTrue);
    });
  });

  group('从笔记生成', () {
    test('优先用划线原文', () {
      final spec = specForNote(
        note: note(text: '  划线原文  ', comment: '我的想法'),
        book: book(),
      );
      expect(spec.kind, PosterKind.quote);
      expect(spec.title, '三体');
      expect(spec.body, '划线原文');
      expect(spec.footer, '刘慈欣 · 第 3 章');
    });

    test('没有原文时用想法', () {
      final spec = specForNote(
        note: note(text: '   ', comment: '一段想法'),
        book: book(),
      );
      expect(spec.body, '一段想法');
    });

    test('没有书时标题与作者退到默认值', () {
      final spec = specForNote(note: note(), book: null);
      expect(spec.title, '未命名');
      expect(spec.footer, '第 3 章');
    });

    test('作者为空时不出现空的分隔符', () {
      final spec = specForNote(note: note(), book: book(author: '  '));
      expect(spec.footer, '第 3 章');
    });
  });

  group('从书籍生成', () {
    test('书籍卡带简介与格式', () {
      final spec = specForBook(book());
      expect(spec.kind, PosterKind.book);
      expect(spec.title, '三体');
      expect(spec.body, '地球往事三部曲第一部。');
      expect(spec.footer, '刘慈欣 · EPUB');
    });
  });

  group('copyWith', () {
    test('边框可以被清掉，别的字段不受影响', () {
      final spec = const PosterSpec(borderAssetId: 'asset-1', body: '正文');
      expect(spec.copyWith(palette: PosterPalette.ink).borderAssetId, 'asset-1');
      expect(spec.copyWith(borderAssetId: null).borderAssetId, isNull);
      expect(spec.copyWith(borderAssetId: null).body, '正文');
    });

    test('isBlank 只看标题与正文', () {
      expect(const PosterSpec().isBlank, isTrue);
      expect(const PosterSpec(title: '书名').isBlank, isFalse);
      expect(const PosterSpec(body: '   ').isBlank, isTrue);
      expect(const PosterSpec(body: '一句').isBlank, isFalse);
    });
  });
}
