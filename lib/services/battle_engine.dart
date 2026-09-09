import 'dart:math';
import '../models/battle_models.dart';
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

    // カードをスピード降順にソートして先攻後攻を決める
    for (int i = 0; i < attackerDeck.length && i < defenderDeck.length; i++) {
      final attCard = attackerDeck[i];
      final defCard = defenderDeck[i];

      // 先攻判定：スピードが高い方が先攻
      final bool attackerGoesFirst = attCard.speed >= defCard.speed;

      if (attackerGoesFirst) {
        // attCard（attackerDeck側）が攻撃 → 移住ボーナス対象
        final m1 = _effectiveMultiplier(attCard.attribute, defCard.attribute,
            boosted: attCard.attribute == migratedAttribute);
        final r1 = _resolveAttack(attCard, defCard, m1);
        defenderHp -= r1.damage;
        logs.add(BattleLog(
          turn: turn++,
          action: '${attCard.nameJp} が ${defCard.nameJp} に攻撃',
          damage: r1.damage,
          attackerHp: attackerHp,
          defenderHp: defenderHp,
          attackingCard: attCard,
          defendingCard: defCard,
          multiplier: m1,
          isCritical: r1.isCritical,
          isDodged: r1.isDodged,
          isShielded: r1.isShielded,
        ));

        if (defenderHp <= 0) break;

        // defCard（defenderDeck側）が反撃 → 移住ボーナス対象外
        final m2 = _effectiveMultiplier(defCard.attribute, attCard.attribute, boosted: false);
        final r2 = _resolveAttack(defCard, attCard, m2);
        attackerHp -= r2.damage;
        logs.add(BattleLog(
          turn: turn++,
          action: '${defCard.nameJp} が ${attCard.nameJp} に反撃',
          damage: r2.damage,
          attackerHp: attackerHp,
          defenderHp: defenderHp,
          attackingCard: defCard,
          defendingCard: attCard,
          multiplier: m2,
          isCritical: r2.isCritical,
          isDodged: r2.isDodged,
          isShielded: r2.isShielded,
        ));

        if (attackerHp <= 0) break;
      } else {
        // defCard（defenderDeck側）が先制 → 移住ボーナス対象外
        final m1 = _effectiveMultiplier(defCard.attribute, attCard.attribute, boosted: false);
        final r1 = _resolveAttack(defCard, attCard, m1);
        attackerHp -= r1.damage;
        logs.add(BattleLog(
          turn: turn++,
          action: '${defCard.nameJp} が ${attCard.nameJp} に先制攻撃',
          damage: r1.damage,
          attackerHp: attackerHp,
          defenderHp: defenderHp,
          attackingCard: defCard,
          defendingCard: attCard,
          multiplier: m1,
          isCritical: r1.isCritical,
          isDodged: r1.isDodged,
          isShielded: r1.isShielded,
        ));

        if (attackerHp <= 0) break;

        // attCard（attackerDeck側）が反撃 → 移住ボーナス対象
        final m2 = _effectiveMultiplier(attCard.attribute, defCard.attribute,
            boosted: attCard.attribute == migratedAttribute);
        final r2 = _resolveAttack(attCard, defCard, m2);
        defenderHp -= r2.damage;
        logs.add(BattleLog(
          turn: turn++,
          action: '${attCard.nameJp} が ${defCard.nameJp} に反撃',
          damage: r2.damage,
          attackerHp: attackerHp,
          defenderHp: defenderHp,
          attackingCard: attCard,
          defendingCard: defCard,
          multiplier: m2,
          isCritical: r2.isCritical,
          isDodged: r2.isDodged,
          isShielded: r2.isShielded,
        ));

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
      PlayCard attacker, PlayCard defender, double multiplier) {
    if (defender.getCardType() == 'speed' && _random.nextDouble() < dodgeChance) {
      return (damage: 0, isCritical: false, isDodged: true, isShielded: false);
    }
    final isShielded =
        defender.getCardType() == 'defense' && _random.nextDouble() < shieldChance;
    final critChance =
        attacker.getCardType() == 'attack' ? criticalChance + typeCriticalBonus : criticalChance;
    final isCritical = _random.nextDouble() < critChance;

    final raw = (attacker.attackPower - defender.defensePower).toDouble();
    var effectiveMultiplier = multiplier;
    if (isCritical) effectiveMultiplier *= criticalMultiplier;
    if (isShielded) effectiveMultiplier *= shieldDamageReduction;
    final dmg = (raw * effectiveMultiplier).floor();
    return (
      damage: dmg < 1 ? 1 : dmg, // 最低1ダメージ保証（回避時を除く）
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
