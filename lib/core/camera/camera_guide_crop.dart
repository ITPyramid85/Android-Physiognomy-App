import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 화면의 가이드 사각형과 같은 비율로 카메라 JPEG를 자른다.
/// 프리뷰는 BoxFit.cover 이므로, 화면에 보이는 카메라 영역만 기준으로 삼는다.
/// 가이드 PNG는 합성하지 않는다.
String cropCameraGuideRegion(Map<String, dynamic> args) {
  final source = args['source'] as String;
  try {
    final bytes = File(source).readAsBytesSync();
    var image = img.decodeImage(bytes);
    if (image == null) return source;

    final viewW = (args['viewW'] as num).toDouble();
    final viewH = (args['viewH'] as num).toDouble();
    if (viewW <= 0 || viewH <= 0) return source;

    final viewPortrait = viewH > viewW;
    final imagePortrait = image.height > image.width;
    if (viewPortrait != imagePortrait) {
      image = img.copyRotate(image, angle: 90);
    }

    final viewAspect = viewW / viewH;
    final imageAspect = image.width / image.height;
    late final double visibleX, visibleY, visibleW, visibleH;
    if (imageAspect > viewAspect) {
      visibleH = image.height.toDouble();
      visibleW = image.height * viewAspect;
      visibleX = (image.width - visibleW) / 2;
      visibleY = 0;
    } else {
      visibleW = image.width.toDouble();
      visibleH = image.width / viewAspect;
      visibleY = (image.height - visibleH) / 2;
      visibleX = 0;
    }

    final guideL = (args['left'] as num).toDouble();
    final guideT = (args['top'] as num).toDouble();
    final guideW = (args['width'] as num).toDouble();
    final guideH = (args['height'] as num).toDouble();

    var cropX = visibleX + (guideL / viewW) * visibleW;
    var cropY = visibleY + (guideT / viewH) * visibleH;
    var cropW = (guideW / viewW) * visibleW;
    var cropH = (guideH / viewH) * visibleH;

    if (cropX < 0) {
      cropW += cropX;
      cropX = 0;
    }
    if (cropY < 0) {
      cropH += cropY;
      cropY = 0;
    }
    if (cropX + cropW > image.width) cropW = image.width - cropX;
    if (cropY + cropH > image.height) cropH = image.height - cropY;

    final x = cropX.round().clamp(0, image.width - 1).toInt();
    final y = cropY.round().clamp(0, image.height - 1).toInt();
    final w = cropW.round();
    final h = cropH.round();
    final width = (x + w > image.width ? image.width - x : w);
    final height = (y + h > image.height ? image.height - y : h);
    if (width < 2 || height < 2) return source;

    final cropped = img.copyCrop(image, x: x, y: y, width: width, height: height);
    final suffix = args['suffix'] as String? ?? '_guide.jpg';
    final dot = source.lastIndexOf('.');
    final dest = '${dot > 0 ? source.substring(0, dot) : source}$suffix';
    File(dest).writeAsBytesSync(img.encodeJpg(cropped, quality: 92));
    return dest;
  } catch (e) {
    debugPrint('[CameraGuide] crop error: $e');
    return source;
  }
}
