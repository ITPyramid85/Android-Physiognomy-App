import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_notifier.dart';
import 'widgets/aura_wordmark.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authNotifierProvider);


    return Scaffold(
      backgroundColor: const Color(0xFF100C1D),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2A1B3D),
              Color(0xFF1B1430),
              Color(0xFF140F24),
              Color(0xFF100C1D),
            ],
            stops: [0.0, 0.32, 0.68, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ReadingArtCard(
                      asset: 'assets/home/hand_part.png',
                      onTap: () => context.push('/palm/camera'),
                    ),
                    const SizedBox(height: 64),
                    _ReadingArtCard(
                      asset: 'assets/home/face_part.png',
                      onTap: () => context.push('/face/camera'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 12, 12, 6),
                child: Row(
                  children: [
                    const AuraWordmark(size: 20),
                    const Spacer(),
                    _TopBarIconBtn(
                      icon: Icons.tune_outlined,
                      tooltip: l10n.settings,
                      onTap: () => context.push('/settings'),
                    ),
                    const SizedBox(width: 2),
                    PopupMenuButton<String>(
                      icon: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.hair, width: 1),
                        ),
                        child: Icon(
                          Icons.person_outline,
                          size: 16,
                          color: AppColors.ivoryMid,
                        ),
                      ),
                      color: AppColors.bg3,
                      onSelected: (val) {
                        switch (val) {
                          case 'logout': ref.read(authNotifierProvider.notifier).signOut();
                          case 'terms': context.push('/terms');
                          case 'privacy': context.push('/privacy');
                        }
                      },
                      itemBuilder: (_) => [
                        if (authState.isLoggedIn) ...[
                          PopupMenuItem(value: 'logout', child: Text(l10n.logout)),
                          const PopupMenuDivider(),
                        ],
                        PopupMenuItem(value: 'terms', child: Text(l10n.termsOfService)),
                        PopupMenuItem(value: 'privacy', child: Text(l10n.privacyPolicy)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingArtCard extends StatelessWidget {
  const _ReadingArtCard({required this.asset, required this.onTap});

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final button = MediaQuery.sizeOf(context).width * 0.60;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Image.asset(
          asset,
          width: button,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _TopBarIconBtn extends StatelessWidget {
  const _TopBarIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.hair, width: 1),
          ),
          child: Icon(icon, size: 16, color: AppColors.ivoryMid),
        ),
      ),
    );
  }
}
