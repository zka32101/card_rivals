import 'package:flutter/material.dart';
import 'package:hooks_riverpod/legacy.dart';

// アプリの表示言語（設定画面から切り替え可能）
final localeProvider = StateProvider<Locale>((ref) => const Locale('ja'));
