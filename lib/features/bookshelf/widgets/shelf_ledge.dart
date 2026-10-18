import 'package:flutter/material.dart';

import '../../../data/models/shelf_appearance.dart';

/// 每行封面下方的那条书架横条。
///
/// 真实书架的横条是上表面受光、正面向下渐暗，底边在背板上投一道阴影。三样
/// 东西（亮顶边、渐变正面、下方投影）都做到，才读得出「书站在架子上」；
/// 只画一条实心矩形会像分隔线。
class ShelfLedge extends StatelessWidget {
  const ShelfLedge({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = dark ? const Color(0xFF3C4046) : const Color(0xFFF0EADE);
    final bottom = dark ? const Color(0xFF22252A) : const Color(0xFFD3C8B8);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 受光的上表面。
        Container(
          height: 2,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF4A4F56) : const Color(0xFFFBF7EF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ),
        // 正面，向下渐暗。
        Container(
          height: ShelfAppearance.ledgeHeight - 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, bottom],
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.45 : 0.10),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
