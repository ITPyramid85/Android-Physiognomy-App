import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/logging/app_log.dart';
import '../../data/server/aura_server_client.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final connected = _pingServer();
    try {
      await Future.delayed(const Duration(milliseconds: 2800));
      final ok = await connected;
      if (!mounted) return;
      context.go(ok ? '/home' : '/model_setup');
    } catch (e, st) {
      await AppLog.error('Splash', e, st);
      if (mounted) context.go('/model_setup');
    }
  }

  Future<bool> _pingServer() async {
    try {
      final health = await ref.read(auraServerClientProvider).health();
      await AppLog.write('Splash', 'server ok=${health.ok} backend=${health.backend}');
      return health.ok;
    } catch (e) {
      await AppLog.write('Splash', 'server unreachable: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0814),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.05),
            radius: 0.85,
            colors: [
              Color(0xFF2A1844),
              Color(0xFF140E22),
              Color(0xFF0C0814),
            ],
            stops: [0.0, 0.42, 1.0],
          ),
        ),
        child: const Center(
          child: Image(
            image: AssetImage('assets/icon/hand_seal.png'),
            width: 192,
            height: 192,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
