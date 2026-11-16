import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../domain/entities/palm_result.dart';

class HandOverlayPainter extends CustomPainter {
  const HandOverlayPainter({required this.result, required this.labels});

  final PalmLandmarkResult result;
  /// index → localized label (from keyHandLandmarkLabels(locale))
  final Map<int, String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawBones(canvas, size);
    _drawKeyPoints(canvas, size);
  }

  // 손바닥 격자 (가로선·대각선) — 얇은 반투명
  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.overlayMesh.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final lm = result.landmarks;
    // 가로선 (관절 행 연결) — 손가락 뼈 제외, 끝마디·대각선 생략
    const gridOnly = [
      // MCP 행
      (5, 9), (9, 13), (13, 17),
      // PIP 행
      (6, 10), (10, 14), (14, 18),
      // 손바닥 외곽
      (1, 17), (1, 5), (2, 5), (5, 17),
    ];

    for (final (a, b) in gridOnly) {
      if (a >= lm.length || b >= lm.length) continue;
      canvas.drawLine(
        Offset(lm[a].x * size.width, lm[a].y * size.height),
        Offset(lm[b].x * size.width, lm[b].y * size.height),
        paint,
      );
    }
  }

  // 손가락 뼈대 — 굵고 선명하게
  void _drawBones(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.overlayMesh
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final lm = result.landmarks;
    const bones = [
      (0, 1), (1, 2), (2, 3), (3, 4),
      (0, 5), (5, 6), (6, 7), (7, 8),
      (0, 9), (9, 10), (10, 11), (11, 12),
      (0, 13), (13, 14), (14, 15), (15, 16),
      (0, 17), (17, 18), (18, 19), (19, 20),
    ];

    for (final (a, b) in bones) {
      if (a >= lm.length || b >= lm.length) continue;
      canvas.drawLine(
        Offset(lm[a].x * size.width, lm[a].y * size.height),
        Offset(lm[b].x * size.width, lm[b].y * size.height),
        paint,
      );
    }
  }

  void _drawKeyPoints(Canvas canvas, Size size) {
    final lm = result.landmarks;
    if (lm.isEmpty || labels.isEmpty) return;

    final centerX = (lm.length > 9 ? lm[9].x : 0.5) * size.width;
    final centerBand = size.width * 0.03;
    var handLeft = double.infinity;
    var handRight = 0.0;
    for (final point in lm) {
      final x = point.x * size.width;
      if (x < handLeft) handLeft = x;
      if (x > handRight) handRight = x;
    }

    final fontSize = (size.shortestSide * 0.038).clamp(20.0, 40.0);
    final labelStyle = TextStyle(
      color: AppColors.overlayKeyLabel,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    final leaders = <_HandLeader>[];
    for (final entry in labels.entries) {
      final idx = entry.key;
      if (idx < 0 || idx >= lm.length || entry.value.isEmpty) continue;
      final point = lm[idx];
      final text = TextPainter(
        text: TextSpan(text: entry.value, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.34);
      final anchor = Offset(point.x * size.width, point.y * size.height);
      leaders.add(_HandLeader(
        anchor: anchor,
        text: text,
        toLeft: anchor.dx < centerX - centerBand,
      ));
    }

    final left = leaders.where((item) => item.toLeft).toList()
      ..sort((a, b) => a.anchor.dy.compareTo(b.anchor.dy));
    final right = leaders.where((item) => !item.toLeft).toList()
      ..sort((a, b) => a.anchor.dy.compareTo(b.anchor.dy));
    _spread(left, size.height);
    _spread(right, size.height);

    final linePaint = Paint()
      ..color = AppColors.overlayKeyPoint
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, size.shortestSide * 0.0035)
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()
      ..color = AppColors.overlayKeyPoint
      ..style = PaintingStyle.fill;
    final boxBorder = Paint()
      ..color = AppColors.overlayKeyPoint
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.shortestSide * 0.002);
    final dotRadius = math.max(4.0, size.shortestSide * 0.007);
    final reach = math.max(40.0, size.width * 0.06);
    final padX = fontSize * 0.38;
    final padY = fontSize * 0.18;

    for (final item in leaders) {
      final text = item.text;
      final boxW = text.width + padX * 2;
      final boxH = text.height + padY * 2;
      final top = item.top;
      late final double boxLeft;
      late final double lineEndX;
      if (item.toLeft) {
        final outer = math.min(item.anchor.dx - reach, handLeft - reach * 0.35);
        var rightEdge = outer;
        var leftEdge = rightEdge - boxW;
        if (leftEdge < 4) {
          leftEdge = 4;
          rightEdge = leftEdge + boxW;
        }
        boxLeft = leftEdge;
        lineEndX = rightEdge;
      } else {
        final outer = math.max(item.anchor.dx + reach, handRight + reach * 0.35);
        var leftEdge = outer;
        if (leftEdge + boxW > size.width - 4) {
          leftEdge = size.width - 4 - boxW;
        }
        boxLeft = leftEdge;
        lineEndX = leftEdge;
      }
      final midY = top + boxH / 2;
      canvas.drawLine(item.anchor, Offset(lineEndX, midY), linePaint);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxLeft, top, boxW, boxH),
        Radius.circular(boxH / 2),
      );
      canvas.drawRRect(rect, boxBorder);
      text.paint(canvas, Offset(boxLeft + padX, top + padY));
      canvas.drawCircle(item.anchor, dotRadius, dotPaint);
    }
  }

  void _spread(List<_HandLeader> side, double height) {
    if (side.isEmpty) return;
    const gap = 6.0;
    double boxH(TextPainter text) {
      final font = text.text?.style?.fontSize ?? 20;
      return text.height + font * 0.36;
    }
    final tops = <double>[
      for (final item in side) item.anchor.dy - boxH(item.text) / 2,
    ];
    for (var i = 1; i < tops.length; i++) {
      final minTop = tops[i - 1] + boxH(side[i - 1].text) + gap;
      if (tops[i] < minTop) tops[i] = minTop;
    }
    final overflow = tops.last + boxH(side.last.text) + 4 - height;
    if (overflow > 0) {
      for (var i = 0; i < tops.length; i++) {
        tops[i] -= overflow;
      }
    }
    if (tops.first < 4) {
      final shift = 4 - tops.first;
      for (var i = 0; i < tops.length; i++) {
        tops[i] += shift;
      }
    }
    for (var i = 0; i < side.length; i++) {
      side[i].top = tops[i];
    }
  }

  @override
  bool shouldRepaint(covariant HandOverlayPainter old) =>
      !identical(old.result, result) || old.labels != labels;
}

class _HandLeader {
  _HandLeader({required this.anchor, required this.text, required this.toLeft});

  final Offset anchor;
  final TextPainter text;
  final bool toLeft;
  double top = 0;
}
