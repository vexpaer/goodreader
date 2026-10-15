import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/repositories/settings_repository.dart';

/// Current fractional page position, safe to call before layout is ready.
double pagePositionOf(PageController controller) {
  if (controller.hasClients && controller.position.haveDimensions) {
    return controller.page ?? controller.initialPage.toDouble();
  }
  return controller.initialPage.toDouble();
}

/// Applies the configured page turn animation to one page of the reader.
class PageTurn extends StatelessWidget {
  const PageTurn({
    super.key,
    required this.controller,
    required this.index,
    required this.style,
    required this.child,
  });

  final PageController controller;
  final int index;
  final PageTurnStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      PageTurnStyle.none || PageTurnStyle.slide => child,
      PageTurnStyle.fade => _FadeTurn(
          controller: controller,
          index: index,
          child: child,
        ),
      PageTurnStyle.cover => _CoverTurn(
          controller: controller,
          index: index,
          child: child,
        ),
      PageTurnStyle.simulation => _SimulationTurn(
          controller: controller,
          index: index,
          child: child,
        ),
    };
  }
}

/// Cross fades between pages.
class _FadeTurn extends StatelessWidget {
  const _FadeTurn({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final delta = (pagePositionOf(controller) - index).abs();
        return Opacity(
          opacity: (1 - delta).clamp(0.0, 1.0),
          child: child,
        );
      },
    );
  }
}

/// The incoming page slides over the page that is already on screen, with a
/// soft shadow along its leading edge.
class _CoverTurn extends StatelessWidget {
  const _CoverTurn({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final width = MediaQuery.of(context).size.width;
        final delta = pagePositionOf(controller) - index;

        // A page that has already been passed stays where it is so the incoming
        // page can slide across it.
        final shift = delta > 0 ? delta.clamp(0.0, 1.0) * width : 0.0;
        final incoming = delta < 0 && delta > -1;

        return Transform.translate(
          offset: Offset(shift, 0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child!,
              if (incoming)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 28,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withOpacity(0.30 * -delta),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Folds the outgoing page around the spine with a slight perspective, which
/// reads as a paper page being turned.
class _SimulationTurn extends StatelessWidget {
  const _SimulationTurn({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final width = MediaQuery.of(context).size.width;
        final delta = pagePositionOf(controller) - index;

        // Incoming pages simply wait underneath the folding page.
        if (delta <= 0) return child!;

        final t = delta.clamp(0.0, 1.0);
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(-t * math.pi / 2);

        return Transform.translate(
          // Cancel the pager's own translation so the page folds in place.
          offset: Offset(t * width, 0),
          child: Transform(
            alignment: Alignment.centerLeft,
            transform: matrix,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child!,
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.black.withOpacity(0.35 * t),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
