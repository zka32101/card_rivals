import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:card_rivals/providers/locale_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('初回はOSの言語から決める（日本語以外は英語）', () async {
    expect(await loadSavedLocale(device: const Locale('ja', 'JP')), const Locale('ja'));
    expect(await loadSavedLocale(device: const Locale('en', 'US')), const Locale('en'));
    expect(await loadSavedLocale(device: const Locale('fr')), const Locale('en'));
  });

  test('保存した言語が次回起動時に復元される', () async {
    await saveLocale(const Locale('en'));
    expect(await loadSavedLocale(device: const Locale('ja')), const Locale('en'));
    await saveLocale(const Locale('ja'));
    expect(await loadSavedLocale(device: const Locale('en')), const Locale('ja'));
  });

  test('不正な保存値は無視して既定値になる', () async {
    SharedPreferences.setMockInitialValues({kLocalePrefKey: 'xx'});
    expect(await loadSavedLocale(device: const Locale('ja')), const Locale('ja'));
  });
}
