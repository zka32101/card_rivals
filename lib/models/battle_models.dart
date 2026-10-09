// Battle system models
import 'card_move.dart';
import 'user_card.dart';

enum Attribute { joy, anger, sadness }

enum CardType { attack, defense, speed, balance }

class BattleState {
  final List<String> attackerDeckIds;
  final List<String> defenderDeckIds;
  final int attackerHp;
  final int defenderHp;
  final List<BattleLog> logs;
  final bool isFinished;
  final bool? attackerWon;

  BattleState({
    required this.attackerDeckIds,
    required this.defenderDeckIds,
    required this.attackerHp,
    required this.defenderHp,
    required this.logs,
    required this.isFinished,
    this.attackerWon,
  });

  BattleState copyWith({
    List<String>? attackerDeckIds,
    List<String>? defenderDeckIds,
    int? attackerHp,
    int? defenderHp,
    List<BattleLog>? logs,
    bool? isFinished,
    bool? attackerWon,
  }) {
    return BattleState(
      attackerDeckIds: attackerDeckIds ?? this.attackerDeckIds,
      defenderDeckIds: defenderDeckIds ?? this.defenderDeckIds,
      attackerHp: attackerHp ?? this.attackerHp,
      defenderHp: defenderHp ?? this.defenderHp,
      logs: logs ?? this.logs,
      isFinished: isFinished ?? this.isFinished,
      attackerWon: attackerWon ?? this.attackerWon,
    );
  }
}

class BattleLog {
  final int turn;
  final String action;
  final int damage;
  final int attackerHp;
  final int defenderHp;
  final PlayCard? attackingCard;
  final PlayCard? defendingCard;
  final double multiplier;
  // クリティカルヒット（属性相性とは別に、確率で追加ダメージが乗る）
  final bool isCritical;
  // 防御側がspeedタイプの特性で完全回避した（damageは常に0）
  final bool isDodged;
  // 防御側がdefenseタイプの特性でシールドを発動し、被ダメージを軽減した
  final bool isShielded;
  // このターンに発動したわざ（null = 不発動）
  final CardMoveId? moveId;

  BattleLog({
    required this.turn,
    required this.action,
    required this.damage,
    required this.attackerHp,
    required this.defenderHp,
    this.attackingCard,
    this.defendingCard,
    this.multiplier = 1.0,
    this.isCritical = false,
    this.isDodged = false,
    this.isShielded = false,
    this.moveId,
  });

  bool get isAdvantage => multiplier > 1.0;
  bool get isDisadvantage => multiplier < 1.0;
}

// Attribute advantage calculation
double getAttributeMultiplier(String attackerAttribute, String defenderAttribute) {
  // 喜 → 怒 (joy beats anger)
  // 怒 → 哀 (anger beats sadness)
  // 哀 → 喜 (sadness beats joy)

  if (attackerAttribute == defenderAttribute) return 1.0;

  if (attackerAttribute == 'joy' && defenderAttribute == 'anger') return 1.5;
  if (attackerAttribute == 'anger' && defenderAttribute == 'sadness') return 1.5;
  if (attackerAttribute == 'sadness' && defenderAttribute == 'joy') return 1.5;

  return 0.67; // Disadvantage
}
