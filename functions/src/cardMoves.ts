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

// レア度(cost)ごとの付与確率と抽選プール。N(cost1)は付与なし。
// 強くなりすぎないよう、高レア度でも確率付与にしている。
const MILD_MOVES = ["iron_wall", "tailwind", "rally", "heal"];
const MID_MOVES = [...MILD_MOVES, "slash", "pierce", "flinch", "shadow_step"];
const ALL_MOVES = [...MID_MOVES, "heavy_blow", "weak_point"];

export function moveIdForCostTier(cost: number): string | null {
  let chance = 0;
  let pool: string[] = [];
  if (cost === 2 || cost === 3) {
    chance = 0.2; // R
    pool = MILD_MOVES;
  } else if (cost === 4) {
    chance = 0.4; // SR
    pool = MID_MOVES;
  } else if (cost === 5) {
    chance = 0.7; // UR
    pool = ALL_MOVES;
  }
  if (pool.length === 0 || Math.random() >= chance) return null;
  return pool[Math.floor(Math.random() * pool.length)];
}
