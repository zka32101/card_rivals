// カードの「わざ」。スキルとは別枠で、カード作成時に確率で付与される（レア度による差は小さく、Nでも付く）
// （manageCards.ts / functions/src/cardMoves.ts の moveIdForCostTier）。
// バトルでは「陣営ごとの使用間隔(interval)」で制限される: 各カードは1回しか攻撃しないため、
// カード単位ではなく陣営単位で「intervalの攻撃回数に1度」しか使えない。
// 値は functions/src/cardMoves.ts の MOVES と同じ（サーバー権威の判定と揃える）。
enum CardMoveId {
  slash, // 一閃: 攻撃力×1.25
  pierce, // しんくうざん: ×1.2、相手防御を10%無視
  heavyBlow, // ごうりき: ×1.4（3回に1度）
  weakPoint, // きゅうしょ突き: ×1.2、相手防御を15%無視（3回に1度）
  ironWall, // てつぺき: 自陣営の防御+8%（2ラウンド）
  tailwind, // ついふう: 自陣営のスピード+35%（2ラウンド）
  rally, // ちからのよびごえ: 自陣営の攻撃+10%（2ラウンド、3回に1度）
  flinch, // ひるませ: 相手陣営の攻撃-5%（2ラウンド、3回に1度）
  shadowStep, // かげうち: 相手陣営のスピード-30%（2ラウンド）
  heal, // いやしのいぶき: HP1回復（3回に1度）
}

class CardMoveSpec {
  final String key;
  // 次に使えるまでの自陣営の攻撃回数（2 = 2回に1度）
  final int interval;
  final double damageMultiplier;
  final double defenseIgnore;
  final double selfAttackUp;
  final double selfDefenseUp;
  final double selfSpeedUp;
  final double foeAttackDown;
  final double foeSpeedDown;
  final int healHp;

  const CardMoveSpec(
    this.key, {
    required this.interval,
    this.damageMultiplier = 1.0,
    this.defenseIgnore = 0,
    this.selfAttackUp = 0,
    this.selfDefenseUp = 0,
    this.selfSpeedUp = 0,
    this.foeAttackDown = 0,
    this.foeSpeedDown = 0,
    this.healHp = 0,
  });

  bool get isAttackMove => damageMultiplier > 1.0 || defenseIgnore > 0;
}

// 補助効果が続くラウンド数（使用したラウンドを含む）
const int kMoveBuffRounds = 2;

const Map<CardMoveId, CardMoveSpec> kCardMoves = {
  CardMoveId.slash: CardMoveSpec('slash', interval: 2, damageMultiplier: 1.25),
  CardMoveId.pierce: CardMoveSpec('pierce', interval: 2, damageMultiplier: 1.2, defenseIgnore: 0.1),
  CardMoveId.heavyBlow: CardMoveSpec('heavy_blow', interval: 3, damageMultiplier: 1.4),
  CardMoveId.weakPoint: CardMoveSpec('weak_point', interval: 3, damageMultiplier: 1.2, defenseIgnore: 0.15),
  CardMoveId.ironWall: CardMoveSpec('iron_wall', interval: 2, selfDefenseUp: 0.08),
  CardMoveId.tailwind: CardMoveSpec('tailwind', interval: 2, selfSpeedUp: 0.35),
  CardMoveId.rally: CardMoveSpec('rally', interval: 3, selfAttackUp: 0.1),
  CardMoveId.flinch: CardMoveSpec('flinch', interval: 3, foeAttackDown: 0.05),
  CardMoveId.shadowStep: CardMoveSpec('shadow_step', interval: 2, foeSpeedDown: 0.3),
  CardMoveId.heal: CardMoveSpec('heal', interval: 3, healHp: 1),
};

CardMoveId? cardMoveIdFromString(String? raw) {
  if (raw == null) return null;
  for (final entry in kCardMoves.entries) {
    if (entry.value.key == raw) return entry.key;
  }
  return null;
}

String cardMoveIdToString(CardMoveId id) => kCardMoves[id]!.key;
