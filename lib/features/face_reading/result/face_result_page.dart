import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/l10n/locale_notifier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/analysis_loading_chrome.dart';
import '../../../core/widgets/subject_picker_sheet.dart';
import '../../../models/consultation.dart';
import '../../../services/consultation_service.dart';
import '../../auth/auth_notifier.dart';
import 'face_result_notifier.dart';
import 'widgets/reading_hero.dart';
import 'widgets/reading_section_card.dart';

class FaceResultPage extends ConsumerStatefulWidget {
  const FaceResultPage({super.key, required this.imagePath});

  final String imagePath;

  @override
  ConsumerState<FaceResultPage> createState() => _FaceResultPageState();
}

class _FaceResultPageState extends ConsumerState<FaceResultPage> {
  bool _pendingSave = false;
  String? _savedReadingId;
  final _analyzedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadLocaleAndAnalyze();
  }

  Future<void> _loadLocaleAndAnalyze() async {
    final locale = ref.read(localeNotifierProvider).languageCode;
    debugPrint('[FaceResultPage] _loadLocaleAndAnalyze 시작, locale=$locale');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(faceResultNotifierProvider.notifier).analyze(
        imagePath: widget.imagePath, locale: locale,
      );
    });
  }

  String _friendlyError(AppLocalizations l10n, String errorMsg) {
    switch (errorMsg) {
      case 'no_face':
        return l10n.noFaceDetected;
      case 'no_palm':
        return l10n.noPalmDetected;
      default:
        return errorMsg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final aura = context.auraColors;
    final notifierState = ref.watch(faceResultNotifierProvider);
    final isStreaming = notifierState.isStreaming;
    final fullText = notifierState.fullText;
    final error = notifierState.error;
    final isModelError = notifierState.isModelError;
    final reading = notifierState.reading;

    ref.listen(authNotifierProvider, (prev, next) {
      if (_pendingSave && prev?.isLoggedIn == false && next.isLoggedIn) {
        _pendingSave = false;
        _onSave(context);
      }
    });

    Widget body;
    if (error != null) {
      body = _buildError(context, l10n, error, isModelError: isModelError);
    } else if (isStreaming && fullText.isEmpty) {
      body = _buildLoading(context, l10n, notifierState.progress);
    } else {
      body = _buildContent(context, l10n, aura, fullText, isStreaming);
    }


    return PopScope(
      canPop: !isStreaming,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave(context, l10n);
        if (leave && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg0,
        appBar: AppBar(
          backgroundColor: AppColors.bg0.withValues(alpha: 0.9),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            onPressed: isStreaming
                ? () async {
                    final leave = await _confirmLeave(context, l10n);
                    if (leave && context.mounted) context.pop();
                  }
                : () => context.pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.faceAnalysisResult,
                style: GoogleFonts.notoSerifKr(
                  fontSize: 15, color: AppColors.ivory, letterSpacing: 1,
                ),
              ),
              Text(
                '甲辰年 · ${DateTime.now().month}.${DateTime.now().day}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9, color: AppColors.ivoryFaint, letterSpacing: 2,
                ),
              ),
            ],
          ),
          actions: [
            // Confidence badge — 스트리밍 완료 후에만 표시
            if (!isStreaming && fullText.isNotEmpty && error == null)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.5), width: 1,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.2),
                      AppColors.bg1.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.confidence,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8, letterSpacing: 1.5,
                        color: AppColors.goldLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(((reading?.score) ?? 0) * 100).round()}',
                      style: GoogleFonts.notoSerifKr(
                        fontSize: 16, color: AppColors.ivory,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: body),
            if (!isStreaming && fullText.isNotEmpty && error == null)
              Container(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm + MediaQuery.of(context).padding.bottom,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.hair2, width: 1)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xFF0D0B14)],
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _GhostBtn(
                    icon: Icons.bookmark_outline,
                    label: l10n.save,
                    onTap: () => _onSave(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmLeave(BuildContext context, AppLocalizations l10n) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.streamingBackTitle),
        content: Text(l10n.streamingBackBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.streamingBackLeave),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _buildLoading(BuildContext context, AppLocalizations l10n, int progress) {
    final value = progress <= 0 ? null : (progress >= 100 ? 1.0 : progress / 100);
    final width = MediaQuery.sizeOf(context).width;
    // 손금 그림(398×451)과 같은 높이 칸이라 금색 원이 같은 자리에 온다.
    final artHeight = width * 451 / 398;
    final ring = width * 0.86 / 4;
    return Stack(
      fit: StackFit.expand,
      children: [
        const AnalysisLoadingBackdrop(),
        Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width,
                height: artHeight,
                child: Image.asset(
                  'assets/home/face_part_ai.png',
                  width: width,
                  height: artHeight,
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  semanticLabel: l10n.faceAnalyzing,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox.square(
                dimension: ring,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ModernGoldRing(progress: value),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: ring * 0.12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.faceAnalyzing,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                              color: AppColors.goldLight,
                              fontSize: ring * 0.11,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: ring * 0.04),
                          Text(
                            '$progress%',
                            style: TextStyle(
                              color: AppColors.goldLight,
                              fontSize: ring * 0.2,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, AppLocalizations l10n,
      String errorMsg, {bool isModelError = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isModelError ? Icons.memory_outlined : Icons.error_outline,
              color: Colors.redAccent, size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isModelError ? l10n.aiModelError : l10n.analysisError,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(_friendlyError(l10n, errorMsg),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () {
                ref.invalidate(faceResultNotifierProvider);
                _loadLocaleAndAnalyze();
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: () => context.pop(), child: Text(l10n.goBack)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    AuraColors aura,
    String fullText,
    bool isStreaming,
  ) {
    final lengthProgress = (fullText.length / 1200).clamp(0.0, 1.0);
    final progress = isStreaming
        ? (ref.watch(faceResultNotifierProvider).progress / 100).clamp(0.0, 1.0)
        : lengthProgress;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ReadingHero(
          analyzedAt: _analyzedAt,
          highlightChips: const [],
          isStreaming: isStreaming,
          progress: progress,
        ),
        const SizedBox(height: AppSpacing.md),
        if (fullText.isNotEmpty)
          ReadingSectionCard(
            accent: aura.sectionAccents['overall']!,
            title: isStreaming ? l10n.analyzing : l10n.faceAnalysisResult,
            body: fullText,
            icon: isStreaming ? Icons.auto_awesome : Icons.auto_awesome_outlined,
            isStreaming: isStreaming,
          ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }


  Future<void> _onSave(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.read(authNotifierProvider);
    if (!authState.isLoggedIn) {
      final goLogin = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.loginRequired),
          content: Text(l10n.loginRequiredContent),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.login)),
          ],
        ),
      );
      if (goLogin != true || !context.mounted) return;
      _pendingSave = true;
      context.push('/auth');
      return;
    }
    final subject = await showSubjectPickerSheet(context);
    if (subject == null || !context.mounted) return;
    await _doSave(subjectName: subject);
  }

  Future<void> _doSave({String subjectName = '나'}) async {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.read(authNotifierProvider);
    if (!authState.isLoggedIn) return;
    final locale = ref.read(localeNotifierProvider).languageCode;
    final landmark = ref.read(faceResultNotifierProvider).reading;
    if (landmark == null) return;
    try {
      final reading = await ref.read(faceResultNotifierProvider.notifier).saveReading(
        userId: authState.user!.id,
        landmarkResult: landmark,
        modelUsed: 'E2B',
        locale: locale,
        subjectName: subjectName,
      );
      if (!mounted) return;
      final email = authState.user?.email ?? '';
      final displayName = email.contains('@') ? email.split('@').first : email;
      if (reading != null) setState(() => _savedReadingId = reading.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveSuccess(displayName))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.saveFailed}: $e')),
      );
    }
  }

  Future<void> _onStartConsultation(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.read(authNotifierProvider);
    if (!authState.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.resultLoginToConsult)));
      context.push('/auth');
      return;
    }
    if (_savedReadingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.resultSaveBeforeConsult)));
      return;
    }
    final locale = ref.read(localeNotifierProvider).languageCode;
    final fullText = ref.read(faceResultNotifierProvider).fullText;
    final landmark = ref.read(faceResultNotifierProvider).reading;
    if (landmark == null) return;
    try {
      final consultation = await ref.read(consultationServiceProvider).createConsultation(
        userId: authState.user!.id,
        analysisType: AnalysisType.face,
        analysisId: _savedReadingId!,
        contextSummary: fullText.length > 600 ? '${fullText.substring(0, 600)}…' : fullText,
        contextFeatures: {
          'eyeSpan': landmark.features.eyeSpan,
          'faceHeight': landmark.features.faceHeight,
          'noseRatio': landmark.features.noseRatio,
          'mouthWidth': landmark.features.mouthWidth,
          'symmetry': landmark.features.symmetry,
          'foreheadHeight': landmark.features.foreheadHeight,
          'eyebrowDistance': landmark.features.eyebrowDistance,
        },
        locale: locale,
        modelUsed: 'E2B',
      );
      if (!context.mounted) return;
      context.push('/consultation/${consultation.id}');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.consultationCreateFailed}: $e')));
    }
  }

  void _onShare() {
    final l10n = AppLocalizations.of(context)!;
    final fullText = ref.read(faceResultNotifierProvider).fullText;
    if (fullText.isEmpty) return;

    final shareText = '${l10n.faceResultTitle}\n\n$fullText\n\n— LuckyStar';
    SharePlus.instance.share(ShareParams(text: shareText));
  }
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({
    required this.l10n,
    required this.onSave,
    required this.onConsult,
    required this.onShare,
  });

  final AppLocalizations l10n;
  final VoidCallback onSave;
  final VoidCallback onConsult;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hair2, width: 1)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xFF0D0B14)],
        ),
      ),
      child: Row(
        children: [
          _GhostBtn(
            icon: Icons.bookmark_outline,
            label: l10n.save,
            onTap: onSave,
          ),
          const SizedBox(width: 8),
          _GhostBtn(
            icon: Icons.share_outlined,
            label: l10n.share,
            onTap: onShare,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onConsult,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE6C877), Color(0xFFC9A449)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.resultConsult,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 13, letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1a1407),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('→',
                        style: TextStyle(color: Color(0xFF1a1407), fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostBtn extends StatelessWidget {
  const _GhostBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(color: AppColors.hair, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.goldLight),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.notoSansKr(
                fontSize: 11, letterSpacing: 0.8,
                color: AppColors.ivoryMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
