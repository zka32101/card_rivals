import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kLocalePrefKey = 'app_locale';

/// 端末の言語から既定のアプリ言語を決める（日本語以外は英語）。
Locale defaultLocaleFor(Locale device) =>
    device.languageCode == 'ja' ? const Locale('ja') : const Locale('en');

/// 保存済みの言語を読む。無ければ（初回）OSの言語から決める。
Future<Locale> loadSavedLocale({Locale? device}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kLocalePrefKey);
    if (saved == 'ja' || saved == 'en') return Locale(saved!);
  } catch (_) {
    // 読めなくても既定値で続行する
  }
  return defaultLocaleFor(device ?? ui.PlatformDispatcher.instance.locale);
}

Future<void> saveLocale(Locale locale) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLocalePrefKey, locale.languageCode);
  } catch (_) {
    // 保存失敗は致命的でない（次回は既定値になるだけ）
  }
}

// アプリの表示言語（設定画面から切り替え可能）。
// 起動時に main() で loadSavedLocale() の結果を overrideWith して復元し、
// 変更は CardRivalsApp が ref.listen して saveLocale() で永続化する。
final localeProvider = StateProvider<Locale>((ref) => const Locale('ja'));
