import '../l10n/app_localizations.dart';
import 'battle_models.dart';

/// バトルログ1行の説明文を現在の表示言語で組み立てる（カード名も言語に追従）。
String battleLogText(AppLocalizations t, BattleLog log) {
  final lang = t.localeName;
  final actor = log.attackingCard?.nameFor(lang) ?? '';
  final target = log.defendingCard?.nameFor(lang) ?? '';
  return switch (log.action) {
    BattleActionKind.attack => t.battleLog_attack(actor, target),
    BattleActionKind.counter => t.battleLog_counter(actor, target),
    BattleActionKind.firstStrike => t.battleLog_firstStrike(actor, target),
  };
}
