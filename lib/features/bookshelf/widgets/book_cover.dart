import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/book.dart';

/// Renders a book cover, falling back to a deterministic gradient card.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.width = 110,
    this.height = 160,
    this.radius = 10,
  });

  final Book book;
  final double width;
  final double height;
  final double radius;

  static const _palette = [
    [Color(0xFF1F6FEB), Color(0xFF4A9BFF)],
    [Color(0xFF7C4DFF), Color(0xFFB39DFF)],
    [Color(0xFF00897B), Color(0xFF4DB6AC)],
    [Color(0xFFE64A19), Color(0xFFFF8A65)],
    [Color(0xFF3949AB), Color(0xFF7986CB)],
    [Color(0xFFAD1457), Color(0xFFF06292)],
    [Color(0xFF455A64), Color(0xFF90A4AE)],
    [Color(0xFF827717), Color(0xFFD4E157)],
  ];

  List<Color> get _gradient {
    final seed = book.title.isEmpty ? 0 : book.title.codeUnitAt(0);
    return _palette[seed % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final path = book.coverPath;
    Widget child;
    if (path != null && File(path).existsSync()) {
      child = Image.file(
        File(path),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    } else {
      child = _placeholder(context);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: width, height: height, child: child),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = _gradient;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            book.title,
            maxLines: 4,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.format.label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
