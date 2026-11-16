import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_notifier.g.dart';

const _kSupported = ['ko', 'en', 'ja', 'zh'];
const _kDefaultLocale = 'zh';
const _kDefaultAppliedKey = 'locale_default_zh_v1';

@Riverpod(keepAlive: true)
class LocaleNotifier extends _$LocaleNotifier {
  @override
  Locale build() {
    _loadLocale();
    return const Locale(_kDefaultLocale);
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final applied = prefs.getBool(_kDefaultAppliedKey) ?? false;
    if (!applied) {
      await prefs.setString('locale', _kDefaultLocale);
      await prefs.setBool('locale_chosen', true);
      await prefs.setBool(_kDefaultAppliedKey, true);
      state = const Locale(_kDefaultLocale);
      return;
    }
    final saved = prefs.getString('locale');
    final code = saved != null && _kSupported.contains(saved)
        ? saved
        : _kDefaultLocale;
    state = Locale(code);
  }

  Future<void> setLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', code);
    await prefs.setBool('locale_chosen', true);
    state = Locale(code);
  }
}
