import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _localePrefsKey = 'app_locale';

// アプリの表示言語（設定画面から切り替え可能、端末に永続化される）
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('ja')) {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_localePrefsKey);
      if (saved != null && saved.isNotEmpty) {
        state = Locale(saved);
      }
    } catch (_) {
      // 読み込みに失敗してもデフォルト言語で継続
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localePrefsKey, locale.languageCode);
    } catch (_) {
      // 保存に失敗しても表示自体は切り替わったままにする
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);
