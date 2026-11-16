import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/l10n/locale_notifier.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/analysis_loading_chrome.dart';
import '../../../core/widgets/subject_picker_sheet.dart';
import '../../../models/consultation.dart';
import '../../../services/consultation_service.dart';
import '../../auth/auth_notifier.dart';
import '../../face_reading/result/widgets/reading_hero.dart';
import '../../face_reading/result/widgets/reading_section_card.dart';
import 'palm_result_notifier.dart';

class PalmResultPage extends ConsumerStatefulWidget {
  const PalmResultPage({super.key, required this.imagePath});

  final String imagePath;

  @override
  ConsumerState<PalmResultPage> createState() => _PalmResultPageState();
}

class _PalmResultPageState extends ConsumerState<PalmResultPage> {
  String _lastParsedText = '';
  List<_PalmBlock> _cachedSections = const [];
  bool _pendingSave = false;
  String? _savedReadingId;
  final _analyzedAt = DateTime.now();

  List<_PalmBlock> _sections(String text) {
    if (text == _lastParsedText) return _cachedSections;
    _lastParsedText = text;
    _cachedSections = _parseSections(text);
    return _cachedSections;
  }

  @override
  void initState() {
    super.initState();
    _loadLocaleAndAnalyze();
  }

  Future<void> _loadLocaleAndAnalyze() async {
    final locale = ref.read(localeNotifierProvider).languageCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(palmResultNotifierProvider.notifier).analyze(
        imagePath: widget.imagePath, locale: locale,
      );
    });
  }

  List<_PalmBlock> _parseSections(String text) {
    if (text.isEmpty) return const [];
    final heading = RegExp(r'^##\s+(.+?)\s*$', multiLine: true);
    final matches = heading.allMatches(text).toList();
    if (matches.isEmpty) return const [];

    final blocks = <_PalmBlock>[];
    final lead = text.substring(0, matches.first.start).trim();
    if (lead.isNotEmpty) blocks.add(_PalmBlock('', lead));
    for (var i = 0; i < matches.length; i++) {
      final title = matches[i].group(1)!.replaceAll(RegExp(r'^#+\s*'), '').trim();
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      final body = text.substring(start, end).trim();
      if (title.isEmpty || body.isEmpty) continue;
      blocks.add(_PalmBlock(title, body));
    }
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notifierState = ref.watch(palmResultNotifierProvider);
    final isStreaming = notifierState.isStreaming;
    final fullText = notifierState.fullText;
    final error = notifierState.error;
    final isModelError = notifierState.isModelError;

    ref.listen(authNotifierProvider, (prev, next) {
      if (_pendingSave && prev?.isLoggedIn == false && next.isLoggedIn) {
        _pendingSave = false;
        _onSave(context);
      }
    });

    final hand = (notifierState.reading?.isLeftHand ?? false)
        ? l10n.leftHand
        : l10n.rightHand;
    final aura = context.auraColors;
    final loading = error == null && isStreaming && fullText.isEmpty;

    return PopScope(
      canPop: !isStreaming,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave(context, l10n);
        if (leave && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: loading ? AnalysisLoadingBackdrop.top : null,
        appBar: AppBar(
          backgroundColor: loading ? AnalysisLoadingBackdrop.top : null,
          surfaceTintColor: loading ? Colors.transparent : null,
          elevation: loading ? 0 : null,
          title: Text(l10n.palmResultTitle(hand)),
        ),
        body: Column(
          children: [
            Expanded(
              child: error != null
                  ? _buildError(context, l10n, error, isModelError: isModelError)
                  : loading
                      ? _buildLoading(context, l10n, notifierState.progress)
                      : _buildContent(context, l10n, aura, fullText, isStreaming),
            ),
            if (!isStreaming && fullText.isNotEmpty && error == null)
              Container(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg,
                  AppSpacing.md + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(top: BorderSide(color: aura.cardBorder, width: 1)),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _onSave(context),
                    icon: const Icon(Icons.bookmark_outline),
                    label: Text(l10n.save),
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

  Widget _buildLoading(BuildContext context, AppLocalizations l10n, int progress) {
    final value = progress <= 0 ? null : (progress >= 100 ? 1.0 : progress / 100);
    final width = MediaQuery.sizeOf(context).width;
    // 첨부 화면의 원은 너비의 86%였다. 그 크기의 1/4.
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
              Image.asset(
                'assets/home/hand_part_ai.png',
                width: width,
                fit: BoxFit.fitWidth,
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
                            l10n.palmAnalyzing,
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

  Widget _buildError(BuildContext context, AppLocalizations l10n, String errorMsg, {bool isModelError = false}) {
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
            Text(_friendlyError(l10n, errorMsg), style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () {
                ref.invalidate(palmResultNotifierProvider);
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
    final sections = _sections(fullText);
    final hasSections = sections.isNotEmpty;
    final chips = [
      for (final block in sections)
        if (block.title.isNotEmpty) '#${block.title}',
    ];
    final lengthProgress = (fullText.length / 2400).clamp(0.0, 1.0);
    final progress = isStreaming
        ? (ref.watch(palmResultNotifierProvider).progress / 100).clamp(0.0, 1.0)
        : lengthProgress;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        ReadingHero(
          analyzedAt: _analyzedAt,
          highlightChips: chips,
          isStreaming: isStreaming,
          progress: progress,
        ),
        const SizedBox(height: AppSpacing.md),
        if (isStreaming && !hasSections)
          ReadingSectionCard(
            accent: aura.sectionAccents['overall']!,
            title: l10n.analyzing,
            body: fullText,
            icon: Icons.back_hand,
            isStreaming: true,
          )
        else if (!hasSections && fullText.isNotEmpty)
          ReadingSectionCard(
            accent: aura.sectionAccents['overall']!,
            title: l10n.palmAnalysisResult,
            body: fullText,
            icon: Icons.back_hand_outlined,
            isStreaming: isStreaming,
          )
        else
          for (var i = 0; i < sections.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ReadingSectionCard(
                accent: _palmAccent(aura, i),
                title: sections[i].title.isEmpty
                    ? l10n.palmAnalysisResult
                    : sections[i].title,
                body: sections[i].body,
                icon: _palmIcon(sections[i].title),
                isStreaming: isStreaming && i == sections.length - 1,
              ),
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
    final landmark = ref.read(palmResultNotifierProvider).reading;
    if (landmark == null) return;
    try {
      final reading = await ref.read(palmResultNotifierProvider.notifier).saveReading(
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
        SnackBar(content: Text(l10n.resultLoginToConsult)),
      );
      context.push('/auth');
      return;
    }
    if (_savedReadingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.resultSaveBeforeConsult)),
      );
      return;
    }

    final locale = ref.read(localeNotifierProvider).languageCode;
    final fullText = ref.read(palmResultNotifierProvider).fullText;

    final landmark = ref.read(palmResultNotifierProvider).reading;
    if (landmark == null) return;
    try {
      final consultation = await ref.read(consultationServiceProvider).createConsultation(
        userId: authState.user!.id,
        analysisType: AnalysisType.palm,
        analysisId: _savedReadingId!,
        contextSummary: fullText.length > 600 ? '${fullText.substring(0, 600)}…' : fullText,
        contextFeatures: {
          'palmWidth': landmark.features.palmWidth,
          'indexLength': landmark.features.indexLength,
          'middleLength': landmark.features.middleLength,
          'ringLength': landmark.features.ringLength,
          'pinkyLength': landmark.features.pinkyLength,
          'thumbLength': landmark.features.thumbLength,
          'fingerSpread': landmark.features.fingerSpread,
          'isLeftHand': landmark.isLeftHand,
        },
        locale: locale,
        modelUsed: 'E2B',
      );
      if (!context.mounted) return;
      context.push('/consultation/${consultation.id}');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.consultationCreateFailed}: $e')),
      );
    }
  }

  void _onShare() {
    final l10n = AppLocalizations.of(context)!;
    final fullText = ref.read(palmResultNotifierProvider).fullText;
    if (fullText.isEmpty) return;

    final hand = (ref.read(palmResultNotifierProvider).reading?.isLeftHand ?? false)
        ? l10n.leftHand
        : l10n.rightHand;
    final shareText = '${l10n.palmResultTitle(hand)}\n\n$fullText\n\n— LuckyStar';
    SharePlus.instance.share(ShareParams(text: shareText));
  }
}

class _PalmBottomCta extends StatelessWidget {
  const _PalmBottomCta({
    required this.l10n,
    required this.onSave,
    required this.onConsult,
  });

  final AppLocalizations l10n;
  final VoidCallback onSave;
  final VoidCallback onConsult;

  @override
  Widget build(BuildContext context) {
    final aura = context.auraColors;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: aura.cardBorder, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.bookmark_outline),
              label: Text(l10n.save),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: onConsult,
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(l10n.resultConsult),
            ),
          ),
        ],
      ),
    );
  }
}

class _PalmBlock {
  const _PalmBlock(this.title, this.body);

  final String title;
  final String body;
}

IconData _palmIcon(String title) {
  final text = title.toLowerCase();
  bool has(List<String> keys) => keys.any((key) => text.contains(key.toLowerCase()));
  if (has(['종합', 'overall', '総合', '综合'])) return Icons.star_outline;
  if (has(['생명', 'life line', '生命'])) return Icons.favorite_outline;
  if (has(['감정', 'heart', '感情'])) return Icons.volunteer_activism_outlined;
  if (has(['두뇌', 'head line', '頭脳', '头脑'])) return Icons.psychology_outlined;
  if (has(['운명', 'fate', '運命', '命运'])) return Icons.auto_awesome_outlined;
  if (has(['건강', 'health', '健康'])) return Icons.health_and_safety_outlined;
  if (has(['결혼', 'marriage', '結婚', '婚姻'])) return Icons.favorite_border;
  if (has(['재물', 'wealth', '財運', '财运'])) return Icons.savings_outlined;
  if (has(['손바닥', 'moon', '月丘', '手掌', '手のひら'])) return Icons.nightlight_outlined;
  if (has(['태양', 'sun', '太陽', '太阳'])) return Icons.wb_sunny_outlined;
  return Icons.back_hand_outlined;
}

Color _palmAccent(AuraColors aura, int index) {
  const keys = ['forehead', 'eyes', 'nose', 'mouth', 'chin', 'overall'];
  return aura.sectionAccents[keys[index % keys.length]]!;
}

