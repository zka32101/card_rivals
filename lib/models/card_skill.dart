// カードスキル（パッシブ/アクティブ）。
// manageCards.ts のガチャ抽選で決まったレア度(cost)に応じて、作成時に固定で1つ
// 付与される（レア度が高いほど強い効果 — functions/src/manageCards.ts の
// skillIdForCostTier と同じ対応表）。シードカードにはスキルを付与しない。
enum CardSkillId {
  guardUp, // R: パッシブ - 防御時、防御力+8%
  powerStrike, // SR: パッシブ - 攻撃時、攻撃力+8%
  doubleStrike, // UR: アクティブ - 攻撃命中時10%の確率で追撃（追加30%ダメージ）
}

// Firestore/Cloud Functionsとの受け渡しに使う文字列表現。
// functions/src/manageCards.ts の skillIdForCostTier と同じ文字列。
CardSkillId? cardSkillIdFromString(String? raw) => switch (raw) {
      'guard_up' => CardSkillId.guardUp,
      'power_strike' => CardSkillId.powerStrike,
      'double_strike' => CardSkillId.doubleStrike,
      _ => null,
    };

String cardSkillIdToString(CardSkillId id) => switch (id) {
      CardSkillId.guardUp => 'guard_up',
      CardSkillId.powerStrike => 'power_strike',
      CardSkillId.doubleStrike => 'double_strike',
    };

bool cardSkillIsPassive(CardSkillId id) => id != CardSkillId.doubleStrike;

// 対戦バランス用の効果係数。functions/src/pvpBattle.ts と同じ値を使う
// （サーバー権威のバトル判定とクライアント側フォールバック(battle_engine.dart)の
// 両方で参照するため、ここに一箇所だけ定義する）。
const double kSkillStatBonusMultiplier = 1.08; // guard_up / power_strike
const double kDoubleStrikeChance = 0.1;
const double kDoubleStrikeBonus = 0.3;
