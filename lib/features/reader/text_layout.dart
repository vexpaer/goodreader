/// Pure text layout helpers shared by the reader.
///
/// Chinese typography needs a two-character first-line indent and a configurable
/// gap between paragraphs. Flutter can only express those by inserting real
/// characters into the text, which shifts every character offset. Highlights,
/// bookmarks and search jumps therefore live in *raw* source offsets and are
/// mapped through [DisplayTransform] here.
///
/// The transform is strictly monotonic, so [DisplayTransform.toRaw] can invert
/// it exactly with a binary search even when the settings change.
library;

/// Describes how a chapter's raw text is expanded for display.
class DisplayTransform {
  const DisplayTransform({this.indent = 0, this.paragraphGap = 0});

  /// Ideographic spaces prepended to every non-blank line.
  final int indent;

  /// Blank lines inserted before every paragraph after the first.
  final int paragraphGap;

  bool get isIdentity => indent <= 0 && paragraphGap <= 0;

  /// Expands [text] for rendering.
  String apply(String text) {
    if (text.isEmpty || isIdentity) return text;
    final pad = '\u3000' * indent;
    final gap = '\n' * paragraphGap;

    final buffer = StringBuffer();
    var start = 0;
    var seenParagraph = false;
    while (start <= text.length) {
      var end = text.indexOf('\n', start);
      if (end < 0) end = text.length;
      final line = text.substring(start, end);

      if (line.trim().isEmpty) {
        buffer.write(line);
      } else {
        if (seenParagraph && paragraphGap > 0) buffer.write(gap);
        if (indent > 0) buffer.write(pad);
        buffer.write(line);
        seenParagraph = true;
      }

      if (end >= text.length) break;
      buffer.write('\n');
      start = end + 1;
    }
    return buffer.toString();
  }

  /// Characters inserted before [rawOffset] in display space.
  int shiftAt(String text, int rawOffset) {
    if (text.isEmpty || isIdentity) return 0;
    final limit = rawOffset.clamp(0, text.length);
    var extra = 0;
    var lineStart = 0;
    var seenParagraph = false;

    while (lineStart < text.length && lineStart <= limit) {
      var lineEnd = text.indexOf('\n', lineStart);
      if (lineEnd < 0) lineEnd = text.length;

      if (text.substring(lineStart, lineEnd).trim().isNotEmpty) {
        if (seenParagraph && paragraphGap > 0) extra += paragraphGap;
        if (indent > 0) extra += indent;
        seenParagraph = true;
      }

      if (lineEnd >= limit) break;
      lineStart = lineEnd + 1;
    }
    return extra;
  }

  /// Maps a raw source offset into display space.
  int toDisplay(String text, int rawOffset) {
    final clamped = rawOffset.clamp(0, text.length);
    if (isIdentity) return clamped;
    return (clamped + shiftAt(text, clamped)).clamp(0, apply(text).length);
  }

  /// Maps a display offset back into raw source space.
  int toRaw(String text, int displayOffset) {
    if (isIdentity) return displayOffset.clamp(0, text.length);
    var low = 0;
    var high = text.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (toDisplay(text, mid) < displayOffset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low.clamp(0, text.length);
  }
}

/// Index of the first character that is not whitespace or an ideographic space.
int firstVisibleIndex(String text) {
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c != ' ' && c != '\u3000' && c != '\n' && c != '\t' && c != '\r') {
      return i;
    }
  }
  return -1;
}

/// A contiguous run of text with an optional highlight colour.
class TextRun {
  TextRun(this.text, {this.highlight, this.dropCap = false});

  final String text;
  final int? highlight;

  /// Rendered with an enlarged first character.
  final bool dropCap;
}

/// One highlight expressed in raw source offsets.
typedef HighlightMark = ({int start, int end, int color});

/// Splits [rawText] into runs, applying [highlights] and, optionally, an
/// enlarged first character.
List<TextRun> buildTextRuns({
  required String rawText,
  required DisplayTransform transform,
  required List<HighlightMark> highlights,
  bool dropCap = false,
}) {
  final display = transform.apply(rawText);

  final marks = highlights
      .where((h) => h.end > h.start && h.start >= 0 && h.end <= rawText.length)
      .map((h) => (
            start: transform.toDisplay(rawText, h.start),
            end: transform.toDisplay(rawText, h.end),
            color: h.color,
          ))
      .where((h) => h.end > h.start && h.end <= display.length)
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  final runs = <TextRun>[];
  var cursor = 0;
  for (final mark in marks) {
    if (mark.start < cursor) continue;
    if (mark.start > cursor) {
      runs.add(TextRun(display.substring(cursor, mark.start)));
    }
    runs.add(TextRun(
      display.substring(mark.start, mark.end),
      highlight: mark.color,
    ));
    cursor = mark.end;
  }
  if (cursor < display.length) {
    runs.add(TextRun(display.substring(cursor)));
  }
  if (runs.isEmpty) runs.add(TextRun(display));

  if (!dropCap) return runs;
  return _applyDropCap(runs);
}

/// Enlarges the first visible character by splitting the run that holds it.
List<TextRun> _applyDropCap(List<TextRun> runs) {
  for (var i = 0; i < runs.length; i++) {
    final index = firstVisibleIndex(runs[i].text);
    if (index < 0) continue;

    final run = runs[i];
    final before = run.text.substring(0, index);
    final head = run.text.substring(index, index + 1);
    final after = run.text.substring(index + 1);

    return [
      ...runs.take(i),
      if (before.isNotEmpty) TextRun(before, highlight: run.highlight),
      TextRun(head, highlight: run.highlight, dropCap: true),
      if (after.isNotEmpty) TextRun(after, highlight: run.highlight),
      ...runs.skip(i + 1),
    ];
  }
  return runs;
}
