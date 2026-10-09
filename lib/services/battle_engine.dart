import 'dart:math';
import '../models/battle_models.dart';
import '../models/card_move.dart';
import '../models/card_skill.dart';
import '../models/user_card.dart';

// クライアント側フォールバック用のバトルシミュレーション。
// サーバー呼び出し失敗時のみ使われるため、この乱数（クリティカル判定）は
// functions/src/pvpBattle.ts側の同名ロジックとは独立している
// （サーバー経由の対戦は必ずサーバー側の乱数・権威計算に置き換わる）。
class BattleEngine {
  static const int initialHp = 30;
  // 「属性の国」移住ボーナス：移住先属性のカードで攻撃した際に加算される倍率
  static const double migrationBonus = 0.10;
  // クリティカルヒット：確率で追加ダメージ倍率が乗る（属性相性とは独立）
  static const double criticalChance = 0.15;
  static const double criticalMultiplier = 1.5;

  // カードタイプ（getCardType()：attack/defense/speed/balance）による特性。
  // これまでタイプは表示・フィルター専用のラベルでしかなかったが、
  // 攻撃・防御・速度のどのステータスに寄せてカードを作るかがバトルに実際に
  // 影響するようにする（balanceタイプは特性なしがそのまま個性）。
  // - attackタイプで攻撃: クリティカル率+10pt
  // - defenseタイプで防御: 20%の確率でシールド発動（被ダメージ半減）
  // - speedタイプで防御: 15%の確率で完全回避（被ダメージ0）
  static const double typeCriticalBonus = 0.10;
  static const double shieldChance = 0.20;
  static const double shieldDamageReduction = 0.5;
  static const double dodgeChance = 0.15;

  static final Random _random = Random();

  static BattleResult simulate(
    List<PlayCard> attackerDeck,
    List<PlayCard> defenderDeck, {
    // attackerDeck側のプレイヤーが移住済みの属性（null = 移住なし）
    String? migratedAttribute,
  }) {
    int attackerHp = initialHp;
    int defenderHp = initialHp;
    final List<BattleLog> logs = [];
    int turn = 1;
    final attSide = _SideState();
    final defSide = _SideState();

    // 1回の攻撃（わざ判定を含む）。actorIsAttacker=true なら attackerDeck 側の打ち手。
    // attackerDeck側のカードが打つ攻撃だけが移住ボーナス対象。
    void doAttack(int round, PlayCard actor, PlayCard target, bool actorIsAttacker, String verb) {
      final own = actorIsAttacker ? attSide : defSide;
      final foe = actorIsAttacker ? defSide : attSide;
      final boosted = actorIsAttacker && actor.attribute == migratedAttribute;
      final m = _effectiveMultiplier(actor.attribute, target.attribute, boosted: boosted);

      // わざ：カードが持ち、かつ自陣営の使用間隔を満たしている時のみ発動
      final spec = actor.moveId != null ? kCardMoves[actor.moveId] : null;
      final useMove = spec != null && own.attacks >= own.nextMoveAttack;
      final attackMod = 1 + own.attackUp.at(round) - own.attackDown.at(round);
      final defenseMod = 1 + foe.defenseUp.at(round);
      final r = _resolveAttack(actor, target, m,
          attackMod: attackMod, defenseMod: defenseMod, move: useMove ? spec : null);

      if (actorIsAttacker) {
        defenderHp -= r.damage;
      } else {
        attackerHp -= r.damage;
      }
      if (useMove) {
        own.nextMoveAttack = own.attacks + spec.interval;
        own.attackUp.set(spec.selfAttackUp, round);
        own.defenseUp.set(spec.selfDefenseUp, round);
        own.speedUp.set(spec.selfSpeedUp, round);
        foe.attackDown.set(spec.foeAttackDown, round);
        foe.speedDown.set(spec.foeSpeedDown, round);
        if (spec.healHp > 0) {
          if (actorIsAttacker) {
            attackerHp = min(initialHp, attackerHp + spec.healHp);
          } else {
            defenderHp = min(initialHp, defenderHp + spec.healHp);
          }
        }
      }
      own.attacks++;

      logs.add(BattleLog(
        turn: turn++,
        action: '${actor.nameJp} が ${target.nameJp} に$verb',
        damage: r.damage,
        attackerHp: attackerHp,
        defenderHp: defenderHp,
        attackingCard: actor,
        defendingCard: target,
        multiplier: m,
        isCritical: r.isCritical,
        isDodged: r.isDodged,
        isShielded: r.isShielded,
        moveId: useMove ? actor.moveId : null,
      ));
    }

    for (int i = 0; i < attackerDeck.length && i < defenderDeck.length; i++) {
      final attCard = attackerDeck[i];
      final defCard = defenderDeck[i];

      // 先攻判定：スピードが高い方が先攻（補助わざによるスピード増減を反映）
      final bool attackerGoesFirst =
          attCard.speed * attSide.speedFactor(i) >= defCard.speed * defSide.speedFactor(i);

      if (attackerGoesFirst) {
        doAttack(i, attCard, defCard, true, '攻撃');
        if (defenderHp <= 0) break;
        doAttack(i, defCard, attCard, false, '反撃');
        if (attackerHp <= 0) break;
      } else {
        doAttack(i, defCard, attCard, false, '先制攻撃');
        if (attackerHp <= 0) break;
        doAttack(i, attCard, defCard, true, '反撃');
        if (defenderHp <= 0) break;
      }
    }

    // 勝敗判定（HP多い方が勝利、同値は攻撃側勝利）
    final bool attackerWon = attackerHp >= defenderHp;
    return BattleResult(
      attackerWon: attackerWon,
      finalAttackerHp: attackerHp.clamp(0, initialHp),
      finalDefenderHp: defenderHp.clamp(0, initialHp),
      logs: logs,
    );
  }

  static double _effectiveMultiplier(String attackerAttribute, String defenderAttribute,
      {required bool boosted}) {
    final base = getAttributeMultiplier(attackerAttribute, defenderAttribute);
    return boosted ? base + migrationBonus : base;
  }

  // 1回の攻撃を解決する：防御側の回避→シールド判定 → 攻撃側のクリティカル判定 →
  // 最終ダメージ算出、の順で処理する。回避が成立したら以降の判定はすべて無意味なので
  // 打ち切る（ダメージは無条件で0。最低1ダメージ保証も適用しない）。
  static ({int damage, bool isCritical, bool isDodged, bool isShielded}) _resolveAttack(
      PlayCard attacker, PlayCard defender, double multiplier,
      {double attackMod = 1, double defenseMod = 1, CardMoveSpec? move}) {
    if (defender.getCardType() == 'speed' && _random.nextDouble() < dodgeChance) {
      return (damage: 0, isCritical: false, isDodged: true, isShielded: false);
    }
    final isShielded =
        defender.getCardType() == 'defense' && _random.nextDouble() < shieldChance;
    final critChance =
        attacker.getCardType() == 'attack' ? criticalChance + typeCriticalBonus : criticalChance;
    final isCritical = _random.nextDouble() < critChance;

    // パッシブスキル: power_strike(攻撃側)は攻撃力、guard_up(防御側)は防御力を+8%する
    // （functions/src/pvpBattle.ts の resolveAttack と同じ係数・同じロジック）。
    final effectiveAttack = attacker.skillId == CardSkillId.powerStrike
        ? attacker.attackPower * kSkillStatBonusMultiplier * attackMod
        : attacker.attackPower * attackMod;
    final effectiveDefense = defender.skillId == CardSkillId.guardUp
        ? defender.defensePower * kSkillStatBonusMultiplier * defenseMod * (1 - (move?.defenseIgnore ?? 0))
        : defender.defensePower * defenseMod * (1 - (move?.defenseIgnore ?? 0));

    final raw = effectiveAttack - effectiveDefense;
    var effectiveMultiplier = multiplier * (move?.damageMultiplier ?? 1);
    if (isCritical) effectiveMultiplier *= criticalMultiplier;
    if (isShielded) effectiveMultiplier *= shieldDamageReduction;
    var dmg = (raw * effectiveMultiplier).floor();
    dmg = dmg < 1 ? 1 : dmg; // 最低1ダメージ保証（回避時を除く）

    // アクティブスキル: double_strike(攻撃側)は命中時10%の確率で追加30%ダメージ
    if (attacker.skillId == CardSkillId.doubleStrike && _random.nextDouble() < kDoubleStrikeChance) {
      dmg += (dmg * kDoubleStrikeBonus).floor();
    }

    return (
      damage: dmg,
      isCritical: isCritical,
      isDodged: false,
      isShielded: isShielded,
    );
  }
}

class BattleResult {
  final bool attackerWon;
  final int finalAttackerHp;
  final int finalDefenderHp;
  final List<BattleLog> logs;

  BattleResult({
    required this.attackerWon,
    required this.finalAttackerHp,
    required this.finalDefenderHp,
    required this.logs,
  });
}

// 補助わざの効果（使用ラウンドを含む kMoveBuffRounds ラウンドの間有効）
class _Mod {
  double value = 0;
  int through = -1;
  double at(int round) => round <= through ? value : 0;
  void set(double v, int round) {
    if (v > 0) {
      value = v;
      through = round + kMoveBuffRounds - 1;
    }
  }
}

// 陣営（デッキ側）ごとの状態。各カードは1回しか攻撃しないため、
// わざの使用間隔はカードではなく陣営単位で管理する。
class _SideState {
  int attacks = 0; // これまでの自陣営の攻撃回数
  int nextMoveAttack = 0; // 次にわざを使える攻撃回数（使ったわざの interval 後）
  final attackUp = _Mod();
  final attackDown = _Mod();
  final defenseUp = _Mod();
  final speedUp = _Mod();
  final speedDown = _Mod();

  double speedFactor(int round) => 1 + speedUp.at(round) - speedDown.at(round);
}
