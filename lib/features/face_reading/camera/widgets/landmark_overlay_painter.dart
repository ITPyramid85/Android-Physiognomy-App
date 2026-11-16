import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../domain/entities/landmark_result.dart';
import '../../../../../domain/physiognomy/face_mesh_connections.dart';

class LandmarkOverlayPainter extends CustomPainter {
  const LandmarkOverlayPainter({required this.result, required this.labels});

  final FaceLandmarkResult result;
  /// index → localized label (from keyLandmarkLabels(locale))
  final Map<int, String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    _drawMeshLines(canvas, size);
    _drawKeyPoints(canvas, size);
  }

  // ── 선 연결 (face mesh wireframe) ──────────────────────────────────────────
  void _drawMeshLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.overlayMesh
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final lm = result.landmarks;
    for (final (a, b) in kFaceMeshConnections) {
      if (a >= lm.length || b >= lm.length) continue;
      canvas.drawLine(
        Offset(lm[a].x * size.width, lm[a].y * size.height),
        Offset(lm[b].x * size.width, lm[b].y * size.height),
        paint,
      );
    }
  }

  // ── 관상 핵심 17점. 중심 왼쪽은 왼쪽으로, 오른쪽은 오른쪽으로 설명선을 뺀다.
  void _drawKeyPoints(Canvas canvas, Size size) {
    final lm = result.landmarks;
    if (lm.isEmpty || labels.isEmpty) return;

    final centerX = (lm.length > 4 ? lm[4].x : 0.5) * size.width;
    final centerBand = size.width * 0.03;
    var faceLeft = double.infinity;
    var faceRight = 0.0;
    for (final point in lm) {
      final x = point.x * size.width;
      if (x < faceLeft) faceLeft = x;
      if (x > faceRight) faceRight = x;
    }

    final fontSize = (size.shortestSide * 0.038).clamp(20.0, 40.0);
    final labelStyle = TextStyle(
      color: AppColors.overlayKeyLabel,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    final leaders = <_Leader>[];
    for (final entry in labels.entries) {
      final idx = entry.key;
      if (idx < 0 || idx >= lm.length || entry.value.isEmpty) continue;
      final point = lm[idx];
      final anchor = Offset(point.x * size.width, point.y * size.height);
      final text = TextPainter(
        text: TextSpan(text: entry.value, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.34);
      leaders.add(_Leader(
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
    final pillBorder = Paint()
      ..color = AppColors.overlayKeyPoint
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.shortestSide * 0.002);
    final dotRadius = math.max(4.0, size.shortestSide * 0.007);
    final reach = math.max(48.0, size.width * 0.07);
    const padX = 8.0;
    const padY = 4.0;

    for (final item in leaders) {
      final text = item.text;
      final boxW = text.width + padX * 2;
      final boxH = text.height + padY * 2;
      final top = item.top;
      late final double boxLeft;
      late final double lineEndX;
      if (item.toLeft) {
        final outer = math.min(item.anchor.dx - reach, faceLeft - reach * 0.45);
        var rightEdge = outer;
        var leftEdge = rightEdge - boxW;
        if (leftEdge < 4) {
          leftEdge = 4;
          rightEdge = leftEdge + boxW;
        }
        boxLeft = leftEdge;
        lineEndX = rightEdge;
      } else {
        final outer = math.max(item.anchor.dx + reach, faceRight + reach * 0.45);
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
      canvas.drawRRect(rect, pillBorder);
      text.paint(canvas, Offset(boxLeft + padX, top + padY));
      canvas.drawCircle(item.anchor, dotRadius, dotPaint);
    }
  }

  void _spread(List<_Leader> side, double height) {
    if (side.isEmpty) return;
    const gap = 6.0;
    final tops = <double>[
      for (final item in side) item.anchor.dy - (item.text.height + 8) / 2,
    ];
    for (var i = 1; i < tops.length; i++) {
      final minTop = tops[i - 1] + side[i - 1].text.height + 8 + gap;
      if (tops[i] < minTop) tops[i] = minTop;
    }
    final overflow = tops.last + side.last.text.height + 8 + 4 - height;
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
  bool shouldRepaint(covariant LandmarkOverlayPainter old) =>
      !identical(old.result, result) || old.labels != labels;
}

class _Leader {
  _Leader({required this.anchor, required this.text, required this.toLeft});

  final Offset anchor;
  final TextPainter text;
  final bool toLeft;
  double top = 0;
}
