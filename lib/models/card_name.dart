import '../l10n/app_localizations.dart';

/// 表示言語に合わせてカード名を選ぶ。
///
/// 英語表示で英語名があれば英語名、無ければ元の名前（日本語）にフォールバックする。
/// 日本語表示では日本語名（無ければ英語名）。
String pickCardName(String lang, {String? jp, String? en}) {
  final j = jp ?? '';
  final e = en ?? '';
  if (lang == 'en') return e.isNotEmpty ? e : j;
  return j.isNotEmpty ? j : e;
}

/// Firestoreの cardName マップ（{'jp':..., 'en':...}）から表示名を選ぶ。
String pickCardNameFromMap(String lang, Map<String, String> names) =>
    pickCardName(lang, jp: names['jp'], en: names['en']);

/// 表示名。どちらの言語の名前も無ければ「名前不明」を返す。
String localizedCardNameOrUnknown(AppLocalizations t, Map<String, String> names) {
  final n = pickCardNameFromMap(t.localeName, names);
  return n.isEmpty ? t.card_unknownName : n;
}
