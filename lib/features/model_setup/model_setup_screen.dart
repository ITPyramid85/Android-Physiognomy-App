import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/server/aura_server_client.dart';
import '../home/widgets/aura_wordmark.dart';

/// 기기 Gemma 다운로드 대신 분석 서버 `/health`에 연결한다.
class ModelSetupScreen extends ConsumerStatefulWidget {
  const ModelSetupScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  ConsumerState<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

enum _Phase { connecting, ready, error }

class _ModelSetupScreenState extends ConsumerState<ModelSetupScreen> {
  _Phase _phase = _Phase.connecting;
  String _detail = resolveAuraServerUrl();
  String? _error;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _phase = _Phase.connecting;
      _detail = resolveAuraServerUrl();
      _error = null;
    });
    try {
      final health = await ref.read(auraServerClientProvider).health();
      if (!mounted) return;
      if (!health.ok) {
        setState(() {
          _phase = _Phase.error;
          _error = health.error ?? 'server not ready';
        });
        return;
      }
      ref.invalidate(serverHealthProvider);
      setState(() {
        _phase = _Phase.ready;
        _detail = '${health.model} · ${health.backend.toUpperCase()}';
      });
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final aura = context.auraColors;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.6),
                    radius: 1.0,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AuraWordmark(size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'AI 관상·손금',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: aura.onSurfaceMuted),
                  ),
                  const SizedBox(height: 48),
                  _body(context, l10n),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    switch (_phase) {
      case _Phase.connecting:
        return _StatusTile(
          icon: Icons.cloud_outlined,
          title: l10n.aiEngineInitializing,
          subtitle: _detail,
          showSpinner: true,
        );
      case _Phase.ready:
        return _StatusTile(
          icon: Icons.check_circle_outline,
          title: l10n.modelReady,
          subtitle: _detail,
          showSpinner: false,
        );
      case _Phase.error:
        return Column(
          children: [
            _StatusTile(
              icon: Icons.cloud_off_outlined,
              title: l10n.aiEngineInitError,
              subtitle: _error ?? _detail,
              showSpinner: false,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _connect,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.aiEngineRetry),
            ),
          ],
        );
    }
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.showSpinner,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aura = context.auraColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: aura.surfaceContainer,
        border: Border.all(color: aura.cardBorder, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: aura.onSurfaceMuted),
                ),
              ],
            ),
          ),
          if (showSpinner)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
