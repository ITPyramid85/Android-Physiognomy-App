import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Indigo gradient, a warm glow, and small stars behind an analysis illustration.
class AnalysisLoadingBackdrop extends StatelessWidget {
  const AnalysisLoadingBackdrop({super.key});

  static const Color top = Color(0xFF1A1230);

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                top,
                Color(0xFF2C1A4E),
                Color(0xFF140E26),
                AppColors.bg0,
              ],
              stops: [0.0, 0.28, 0.62, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.42),
              radius: 0.85,
              colors: [
                Color(0x73E6C877),
                Color(0x44301858),
                Color(0x001A1230),
              ],
              stops: [0.0, 0.42, 0.78],
            ),
          ),
        ),
        CustomPaint(painter: _AnalysisLoadingStars()),
      ],
    );
  }
}

class _AnalysisLoadingStars extends CustomPainter {
  const _AnalysisLoadingStars();

  static const List<(double, double, double)> _stars = [
    (0.12, 0.08, 1.4),
    (0.84, 0.12, 1.8),
    (0.22, 0.28, 1.1),
    (0.91, 0.34, 1.3),
    (0.08, 0.46, 1.6),
    (0.78, 0.52, 1.0),
    (0.16, 0.70, 1.2),
    (0.88, 0.74, 1.5),
    (0.34, 0.18, 0.9),
    (0.62, 0.08, 1.1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x99E6C877);
    for (final (x, y, r) in _stars) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnalysisLoadingStars oldDelegate) => false;
}

/// Metallic gold arc: lit from the upper left, with a soft bloom and rounded ends.
class ModernGoldRing extends StatefulWidget {
  const ModernGoldRing({super.key, required this.progress});

  /// Null draws a moving arc until a real percent arrives.
  final double? progress;

  @override
  State<ModernGoldRing> createState() => _ModernGoldRingState();
}

class _ModernGoldRingState extends State<ModernGoldRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.progress == null) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant ModernGoldRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress == null) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.progress != null) {
      return CustomPaint(
        painter: _ModernGoldRingPainter(progress: widget.progress!),
      );
    }
    return AnimatedBuilder(
      animation: _spin,
      builder: (context, _) => CustomPaint(
        painter: _ModernGoldRingPainter(progress: null, phase: _spin.value),
      ),
    );
  }
}

class _ModernGoldRingPainter extends CustomPainter {
  const _ModernGoldRingPainter({required this.progress, this.phase = 0});

  final double? progress;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.12;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;
    final sweep = progress == null
        ? math.pi * 1.35
        : progress!.clamp(0.0, 1.0).toDouble() * math.pi * 2;
    final arcStart = progress == null ? start + phase * math.pi * 2 : start;
    if (sweep <= 0.001) return;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.45
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x73E6C877)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.35);
    canvas.drawArc(rect, arcStart, sweep, false, glow);

    canvas.save();
    canvas.translate(stroke * 0.08, stroke * 0.14);
    canvas.drawArc(
      rect,
      arcStart,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF5A4216),
    );
    canvas.restore();

    final bounds = rect.inflate(stroke);
    canvas.drawArc(
      rect,
      arcStart,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF6D0),
            Color(0xFFE6C877),
            Color(0xFFC9A449),
            Color(0xFF8E6F2C),
          ],
          stops: [0.0, 0.32, 0.62, 1.0],
        ).createShader(bounds),
    );

    canvas.drawArc(
      rect.shift(Offset(-stroke * 0.1, -stroke * 0.12)),
      arcStart,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.34
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFBE8),
            Color(0xAAE6C877),
            Color(0x00C9A449),
          ],
          stops: [0.0, 0.38, 1.0],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant _ModernGoldRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.phase != phase;
  }
}
