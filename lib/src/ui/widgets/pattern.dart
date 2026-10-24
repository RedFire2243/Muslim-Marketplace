import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A faint repeating eight-point star lattice, drawn in code so no image
/// assets or network requests are needed.
class StarLattice extends StatelessWidget {
  const StarLattice({
    super.key,
    required this.color,
    this.cell = 56,
    this.opacity = 0.12,
  });

  final Color color;
  final double cell;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _StarPainter(color.withValues(alpha: opacity), cell),
        size: Size.infinite,
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.color, this.cell);
  final Color color;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final r = cell * 0.32;
    for (var y = -cell / 2; y < size.height + cell; y += cell) {
      for (var x = -cell / 2; x < size.width + cell; x += cell) {
        final center = Offset(x, y);
        _square(canvas, center, r, 0, paint);
        _square(canvas, center, r, math.pi / 4, paint);
        canvas.drawCircle(center, r * 0.28, paint);
      }
    }
  }

  void _square(Canvas canvas, Offset c, double r, double angle, Paint p) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final a = angle + i * math.pi / 2 + math.pi / 4;
      final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.color != color || old.cell != cell;
}

/// The app mark: an eight-point star in a rounded emerald tile.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.primary,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: CustomPaint(
          painter: _MarkPainter(c.onPrimary, c.secondaryContainer),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color, this.accent);
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.3;
    final fill = Paint()..color = color;
    for (final angle in [0.0, math.pi / 4]) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = angle + i * math.pi / 2 + math.pi / 4;
        final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, fill);
    }
    canvas.drawCircle(c, r * 0.42, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.color != color || old.accent != accent;
}
