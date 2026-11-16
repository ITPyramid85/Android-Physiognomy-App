import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/camera/camera_guide_crop.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/mlkit/face_mesh_service.dart';
import '../../../domain/entities/landmark_result.dart';
import '../../../domain/physiognomy/landmark_index.dart';
import 'widgets/landmark_overlay_painter.dart';

/// 얼굴 촬영. 미리보기의 특징점은 기기에서 그리고, 관상 문장은 서버가 만든다.
class FaceCameraPage extends ConsumerStatefulWidget {
  const FaceCameraPage({super.key});

  @override
  ConsumerState<FaceCameraPage> createState() => _FaceCameraPageState();
}

class _FaceCameraPageState extends ConsumerState<FaceCameraPage> {
  CameraController? _camera;
  FaceMeshService? _mesh;
  FaceLandmarkResult? _face;
  bool _disposed = false;
  bool _busy = false;
  bool _detecting = false;
  int _misses = 0;
  bool _permissionDenied = false;
  final _previewKey = GlobalKey();
  final _guideKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _permissionDenied = true);
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _permissionDenied = true);
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await ctrl.initialize();
      if (_disposed) {
        await ctrl.dispose();
        return;
      }
      if (mounted) setState(() => _camera = ctrl);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) _beginLandmarks(ctrl);
      });
    } catch (e) {
      debugPrint('[FaceCamera] init error: $e');
      if (mounted) setState(() => _permissionDenied = true);
    }
  }

  Future<void> _beginLandmarks(CameraController ctrl) async {
    try {
      _mesh ??= await FaceMeshService.create();
      if (_disposed || !ctrl.value.isInitialized) return;
      if (!ctrl.value.isStreamingImages) {
        await ctrl.startImageStream(_onFrame);
      }
    } catch (e) {
      debugPrint('[FaceCamera] landmarks: $e');
    }
  }

  void _onFrame(CameraImage image) {
    if (_detecting || _busy || _disposed) return;
    final mesh = _mesh;
    final ctrl = _camera;
    if (mesh == null || ctrl == null) return;
    _detecting = true;
    mesh.process(image, ctrl.description).then((result) {
      _detecting = false;
      if (!mounted || _disposed) return;
      if (result == null) {
        _misses++;
        if (_misses >= 3 && _face != null) setState(() => _face = null);
        return;
      }
      _misses = 0;
      setState(() => _face = result);
    }).catchError((Object e) {
      _detecting = false;
      debugPrint('[FaceCamera] frame error: $e');
    });
  }

  Future<void> _pauseStream() async {
    final ctrl = _camera;
    if (ctrl != null && ctrl.value.isStreamingImages) {
      await ctrl.stopImageStream();
    }
  }

  Future<void> _openResult(String path) async {
    if (!mounted || path.isEmpty) return;
    await context.push('/face/result', extra: path);
  }

  bool _previewIsLandscape(CameraController ctrl) {
    final orientation = ctrl.value.previewPauseOrientation ??
        ctrl.value.lockedCaptureOrientation ??
        ctrl.value.deviceOrientation;
    return orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
  }

  /// 화면에 보이는 얼굴 가이드. 예전 240×320 보다 큰 정사각형이다.
  ({double left, double top, double width, double height, double viewW, double viewH})?
      _guideInPreview() {
    final guideBox = _guideKey.currentContext?.findRenderObject() as RenderBox?;
    final previewBox = _previewKey.currentContext?.findRenderObject() as RenderBox?;
    if (guideBox == null ||
        previewBox == null ||
        !guideBox.hasSize ||
        !previewBox.hasSize ||
        previewBox.size.width <= 0 ||
        previewBox.size.height <= 0 ||
        guideBox.size.width <= 0 ||
        guideBox.size.height <= 0) {
      return null;
    }
    final origin = previewBox.globalToLocal(guideBox.localToGlobal(Offset.zero));
    return (
      left: origin.dx,
      top: origin.dy,
      width: guideBox.size.width,
      height: guideBox.size.height,
      viewW: previewBox.size.width,
      viewH: previewBox.size.height,
    );
  }

  Future<void> _capture() async {
    final ctrl = _camera;
    if (ctrl == null || _busy || !ctrl.value.isInitialized) return;
    final guide = _guideInPreview();
    setState(() => _busy = true);
    try {
      await _pauseStream();
      final file = await ctrl.takePicture();
      final path = guide == null
          ? file.path
          : await compute(cropCameraGuideRegion, {
              'source': file.path,
              'left': guide.left,
              'top': guide.top,
              'width': guide.width,
              'height': guide.height,
              'viewW': guide.viewW,
              'viewH': guide.viewH,
              'suffix': '_face.jpg',
            });
      await _openResult(path);
    } catch (e) {
      debugPrint('[FaceCamera] capture error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      final current = _camera;
      if (!_disposed && current != null && current.value.isInitialized) {
        await _beginLandmarks(current);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      await _openResult(file.path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final ctrl = _camera;
    _mesh?.dispose();
    _mesh = null;
    if (ctrl != null) {
      if (ctrl.value.isStreamingImages) {
        ctrl.stopImageStream().whenComplete(ctrl.dispose);
      } else {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_permissionDenied) return _permissionDeniedView(context, l10n);

    final ctrl = _camera;
    final ready = ctrl != null && ctrl.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.faceReading,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: ready
          ? _preview(context, ctrl, l10n, keyLandmarkLabels(
              Localizations.localeOf(context).languageCode,
            ))
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  Widget _cameraView(CameraController ctrl, Map<int, String> labels) {
    final raw = ctrl.value.previewSize;
    final face = _face;
    if (raw == null) return CameraPreview(ctrl, key: _previewKey);
    final landscape = _previewIsLandscape(ctrl);
    final width = landscape ? raw.width : raw.height;
    final height = landscape ? raw.height : raw.width;
    return SizedBox.expand(
      key: _previewKey,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(ctrl),
              if (face != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: LandmarkOverlayPainter(result: face, labels: labels),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(
    BuildContext context,
    CameraController ctrl,
    AppLocalizations l10n,
    Map<int, String> labels,
  ) {
    final guideSide = MediaQuery.sizeOf(context).width * 0.8;
    return Stack(
      fit: StackFit.expand,
      children: [
        _cameraView(ctrl, labels),
        Center(
          child: SizedBox.square(
            key: _guideKey,
            dimension: guideSide,
            child: Image.asset(
              'assets/home/FaceRecognition.png',
              fit: BoxFit.contain,
              semanticLabel: l10n.cameraGuideAlign,
            ),
          ),
        ),
        Positioned(
          bottom: 88,
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          child: FilledButton.icon(
            onPressed: _busy ? null : _capture,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(l10n.viewResults),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 16),
            ),
          ),
        ),
        Positioned(
          bottom: 36,
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          child: TextButton.icon(
            onPressed: _busy ? null : _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined, color: Colors.white60, size: 18),
            label: Text(l10n.selectFromGallery,
                style: const TextStyle(color: Colors.white60, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  Widget _permissionDeniedView(BuildContext context, AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.faceReading,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography_outlined, color: Colors.white54, size: 64),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.cameraPermissionRequired,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.facePermissionDesc,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () async {
                  await openAppSettings();
                  if (mounted) {
                    setState(() => _permissionDenied = false);
                    _init();
                  }
                },
                icon: const Icon(Icons.settings_outlined),
                label: Text(l10n.openSettings),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(l10n.goBack, style: const TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
