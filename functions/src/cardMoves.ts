// カードの「わざ」定義（サーバー権威）。lib/models/card_move.dart と同じ値・同じ文字列ID。
// わざはスキルとは別枠で、カード作成時にレア度に応じて確率で付与される。
// バトルでは「陣営ごとの使用間隔(interval)」で制限される（pvpBattle.ts の simulateBattle 参照）。

export interface MoveSpec {
  // 次に同じ陣営がわざを使えるまでの自陣営の攻撃回数（2 = 2回に1度）
  interval: number;
  damageMultiplier: number; // 攻撃ダメージ倍率（1.0 = 通常攻撃）
  defenseIgnore: number; // 相手防御の無視割合
  selfAttackUp: number; // 自陣営の攻撃力アップ
  selfDefenseUp: number; // 自陣営の防御力アップ
  selfSpeedUp: number; // 自陣営のスピードアップ
  foeAttackDown: number; // 相手陣営の攻撃力ダウン
  foeSpeedDown: number; // 相手陣営のスピードダウン
  healHp: number; // 自陣営のHP回復量
}

const NONE: MoveSpec = {
  interval: 2, damageMultiplier: 1.0, defenseIgnore: 0,
  selfAttackUp: 0, selfDefenseUp: 0, selfSpeedUp: 0,
  foeAttackDown: 0, foeSpeedDown: 0, healHp: 0,
};

// 補助効果が続くラウンド数（使用したラウンドを含む）
export const MOVE_BUFF_ROUNDS = 2;

export const MOVES: Record<string, MoveSpec> = {
  slash: {...NONE, interval: 2, damageMultiplier: 1.25},
  pierce: {...NONE, interval: 2, damageMultiplier: 1.2, defenseIgnore: 0.1},
  heavy_blow: {...NONE, interval: 3, damageMultiplier: 1.4},
  weak_point: {...NONE, interval: 3, damageMultiplier: 1.2, defenseIgnore: 0.15},
  iron_wall: {...NONE, interval: 2, selfDefenseUp: 0.08},
  tailwind: {...NONE, interval: 2, selfSpeedUp: 0.35},
  rally: {...NONE, interval: 3, selfAttackUp: 0.1},
  flinch: {...NONE, interval: 3, foeAttackDown: 0.05},
  shadow_step: {...NONE, interval: 2, foeSpeedDown: 0.3},
  heal: {...NONE, interval: 3, healHp: 1},
};

// わざの付与。ステータス予算が全レア度で同じなのと同様に、わざもレア度で強さに差をつけない:
// - 抽選プールは全レア度で共通（URだけが強いわざを持つ、ということは無い）
// - 付与確率の差は小さい（N 30% 〜 UR 45%）ので、Nでも「わざ持ち」を引ける
// レア度の差は主にスキルの有無と希少性で表現し、勝敗を決めるほどの差にはしない。
const MOVE_POOL = [
  "slash", "pierce", "heavy_blow", "weak_point",
  "iron_wall", "tailwind", "rally", "flinch", "shadow_step", "heal",
];

const MOVE_CHANCE_BY_COST: Record<number, number> = {
  1: 0.30, // N
  2: 0.35, // R
  3: 0.35, // R
  4: 0.40, // SR
  5: 0.45, // UR
};

export function moveIdForCostTier(cost: number): string | null {
  const chance = MOVE_CHANCE_BY_COST[cost] ?? 0;
  if (Math.random() >= chance) return null;
  return MOVE_POOL[Math.floor(Math.random() * MOVE_POOL.length)];
}
