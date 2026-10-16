import 'package:flutter/material.dart';

/// Pinch-to-zoom for the reader page.
///
/// Uses a raw [Listener] instead of a gesture recogniser so it never competes
/// with the pager, the edge brightness/volume drags or the text selection
/// gestures for a place in the gesture arena.
class ZoomableView extends StatefulWidget {
  const ZoomableView({
    super.key,
    required this.child,
    required this.enabled,
    required this.resetToken,
    this.onZoomChanged,
  });

  final Widget child;
  final bool enabled;

  /// When this value changes the zoom is reset, e.g. on a page turn.
  final Object resetToken;

  final ValueChanged<bool>? onZoomChanged;

  @override
  State<ZoomableView> createState() => _ZoomableViewState();
}

class _ZoomableViewState extends State<ZoomableView> {
  static const _minScale = 1.0;
  static const _maxScale = 4.0;

  final Map<int, Offset> _pointers = {};
  double _scale = 1;
  double _startScale = 1;
  double _startDistance = 0;
  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;
  Offset _panAnchor = Offset.zero;
  bool _zoomed = false;

  @override
  void didUpdateWidget(ZoomableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final needsReset = oldWidget.resetToken != widget.resetToken ||
        (!widget.enabled && _zoomed);
    if (!needsReset) return;
    // didUpdateWidget runs while the parent is rebuilding, so defer the reset
    // (and the zoom callback it fires) to avoid a setState-during-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reset();
    });
  }

  void _reset() {
    if (_scale == 1 && _offset == Offset.zero) return;
    setState(() {
      _scale = 1;
      _offset = Offset.zero;
      _zoomed = false;
    });
    widget.onZoomChanged?.call(false);
  }

  void _notifyZoom() {
    final zoomed = _scale > 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged?.call(zoomed);
  }

  double _pointerDistance() {
    final points = _pointers.values.toList();
    if (points.length < 2) return 0;
    return (points[0] - points[1]).distance;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length == 2) {
      _startDistance = _pointerDistance();
      _startScale = _scale;
      _startOffset = _offset;
    } else if (_pointers.length == 1) {
      _panAnchor = event.localPosition;
      _startOffset = _offset;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.enabled || !_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length >= 2) {
      final distance = _pointerDistance();
      if (_startDistance <= 0 || distance <= 0) return;
      final next =
          (_startScale * distance / _startDistance).clamp(_minScale, _maxScale);
      setState(() => _scale = next);
      _notifyZoom();
      return;
    }

    if (_scale > 1.01) {
      setState(() => _offset = _startOffset + (event.localPosition - _panAnchor));
    }
  }

  void _onPointerEnd(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length == 1) {
      _panAnchor = _pointers.values.first;
      _startOffset = _offset;
    }
    if (_pointers.isEmpty) {
      if (_scale <= 1.01) {
        _reset();
      } else {
        setState(() => _offset = _clamp(_offset, _viewport));
      }
    }
  }

  Size _viewport = Size.zero;

  Offset _clamp(Offset raw, Size size) {
    if (size.isEmpty) return raw;
    final maxX = size.width * (_scale - 1) / 2;
    final maxY = size.height * (_scale - 1) / 2;
    return Offset(
      raw.dx.clamp(-maxX, maxX),
      raw.dy.clamp(-maxY, maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          child: ClipRect(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translate(_offset.dx, _offset.dy)
                ..scale(_scale),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
