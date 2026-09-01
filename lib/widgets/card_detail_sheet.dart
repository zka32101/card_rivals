import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/user_card.dart';
import '../providers/collection_provider.dart';
import '../providers/game_state_provider.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';
import 'card_widget.dart';

// ローカライズされたカード名を取得（現在のロケールに基づいてJP/EN を切り替え）
String _getCardDisplayName(BuildContext context, PlayCard card) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode == 'en' && card.nameEn.isNotEmpty) {
    return card.nameEn;
  }
  return card.nameJp;
}

/// カード詳細をボトムシートで表示する（コレクション/デッキ選択などから共通利用）
void showCardDetailSheet(BuildContext context, PlayCard card) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CardDetailSheet(card: card),
  );
}

class CardDetailSheet extends ConsumerWidget {
  final PlayCard card;
  const CardDetailSheet({super.key, required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;

    // マイカード（シードカードでない）の場合、特訓レベルは常にmyCardsProviderの
    // 最新値を見る。呼び出し元から渡されたcardは開いた瞬間のスナップショットなので、
    // シート内で特訓した直後もレベル・ステータス表示が追従するようにするため。
    UserCard? liveCard;
    if (!card.isSeedCard) {
      final myCards = ref.watch(myCardsProvider);
      for (final c in myCards) {
        if (c.cardId == card.cardId) {
          liveCard = c;
          break;
        }
      }
    }
    final displayCard = liveCard?.toPlayCard() ?? card;
    final attrColor = Kingdom.attributeColor(displayCard.attribute);
    final rc = rarityColor(displayCard.rarity);

    return Container(
      padding: const EdgeInsets.fromLTRB(Kingdom.spaceXl, Kingdom.spaceLg, Kingdom.spaceXl, Kingdom.spaceXxxl),
      decoration: BoxDecoration(
        color: Kingdom.nightDeep,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: rc, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ドラッグハンドル
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Kingdom.parchment.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: Kingdom.spaceXl),

          Row(
            children: [
              // カードプレビュー
              SizedBox(width: 120, child: CardWidget(card: displayCard, size: 120)),
              const SizedBox(width: Kingdom.spaceXl),
              // 詳細情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceSm, vertical: 3),
                          decoration: BoxDecoration(color: rc, borderRadius: BorderRadius.circular(6)),
                          child: Text(displayCard.rarityLabel, style: TextStyle(color: Kingdom.night, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: Kingdom.spaceSm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceSm, vertical: 3),
                          decoration: BoxDecoration(color: attrColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: attrColor)),
                          child: Text(_attrLabel(t, displayCard.attribute), style: TextStyle(color: attrColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: Kingdom.spaceSm),
                    Text(_getCardDisplayName(context, displayCard),
                        style: TextStyle(
                            fontFamily: Kingdom.displayFont, fontSize: 18, fontWeight: FontWeight.bold, color: Kingdom.parchment)),
                    const SizedBox(height: Kingdom.spaceXs),
                    Text(t.collection_costTypeLine(displayCard.cost, _typeLabel(t, displayCard.getCardType())),
                        style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5), fontSize: 12)),
                    const SizedBox(height: 14),
                    _statDetail(t.card_attack, displayCard.attackPower, Kingdom.angerCrimson),
                    const SizedBox(height: 6),
                    _statDetail(t.card_defense, displayCard.defensePower, Kingdom.sadnessIndigo),
                    const SizedBox(height: 6),
                    _statDetail(t.card_speed, displayCard.speed, Kingdom.joyGold),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: Kingdom.spaceLg),
          // 相性情報
          Container(
            padding: const EdgeInsets.all(Kingdom.spaceMd),
            decoration: BoxDecoration(color: attrColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _advantageChip(t.collection_advantageLabel, _advantage(t, displayCard.attribute), Kingdom.joyGold),
                _advantageChip(t.collection_disadvantageLabel, _disadvantage(t, displayCard.attribute), Kingdom.angerCrimson),
              ],
            ),
          ),

          if (liveCard != null) ...[
            const SizedBox(height: Kingdom.spaceLg),
            _TrainingSection(card: liveCard),
          ],
        ],
      ),
    );
  }

  Widget _statDetail(String label, int value, Color color) {
    return Row(
      children: [
        SizedBox(width: 40, child: Text(label, style: TextStyle(fontSize: Kingdom.textCaption, color: color, fontWeight: FontWeight.bold))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / 40).clamp(0.0, 1.0),
              backgroundColor: Kingdom.parchment.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('$value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Kingdom.parchment)),
      ],
    );
  }

  Widget _advantageChip(String label, String target, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(target, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Kingdom.parchment)),
      ],
    );
  }

  String _attrLabel(AppLocalizations t, String a) => switch (a) {
        'joy' => '☀️ ${t.attribute_joy}',
        'anger' => '🔥 ${t.attribute_anger}',
        _ => '🌙 ${t.attribute_sadness}',
      };
  String _typeLabel(AppLocalizations t, String type) => switch (type) {
        'attack' => t.collection_typeAttack,
        'defense' => t.collection_typeDefense,
        'speed' => t.collection_typeSpeed,
        _ => t.collection_typeBalance,
      };
  String _advantage(AppLocalizations t, String a) => switch (a) {
        'joy' => t.collection_strongAgainst('🔥 ${t.attribute_anger}'),
        'anger' => t.collection_strongAgainst('🌙 ${t.attribute_sadness}'),
        _ => t.collection_strongAgainst('☀️ ${t.attribute_joy}'),
      };
  String _disadvantage(AppLocalizations t, String a) => switch (a) {
        'joy' => t.collection_weakAgainst('🌙 ${t.attribute_sadness}'),
        'anger' => t.collection_weakAgainst('☀️ ${t.attribute_joy}'),
        _ => t.collection_weakAgainst('🔥 ${t.attribute_anger}'),
      };
}

// マイカード限定の特訓（レベルアップ）UI。コインを払って恒久的にステータスを底上げする。
class _TrainingSection extends ConsumerWidget {
  final UserCard card;
  const _TrainingSection({required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final wallet = ref.watch(walletProvider);
    final isMaxed = card.level >= kMaxCardLevel;
    final cost = isMaxed ? 0 : cardLevelUpCost(card.level);
    final canAfford = !isMaxed && wallet.coinBalance >= cost;

    return OrnateFrame(
      accent: Kingdom.gilt,
      padding: const EdgeInsets.all(Kingdom.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('💪 ${t.collection_trainingLabel}', style: Kingdom.label(size: 13, color: Kingdom.gilt)),
              const Spacer(),
              Text(t.collection_trainingLevelFormat(card.level, kMaxCardLevel),
                  style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.8), fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(kMaxCardLevel, (i) {
              final filled = i < card.level;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == kMaxCardLevel - 1 ? 0 : 4),
                  height: 6,
                  decoration: BoxDecoration(
                    color: filled ? Kingdom.gilt : Kingdom.parchment.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: Kingdom.spaceMd),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isMaxed
                  ? null
                  : () async {
                      if (!canAfford) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.collection_trainInsufficientCoins), backgroundColor: Kingdom.angerCrimson),
                        );
                        return;
                      }
                      final newLevel = card.level + 1;
                      final error = await levelUpCard(ref, card.cardId);
                      if (!context.mounted) return;
                      if (error == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.collection_trainSuccess(newLevel)), backgroundColor: Colors.green),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.collection_trainInsufficientCoins), backgroundColor: Kingdom.angerCrimson),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Kingdom.gilt,
                foregroundColor: Kingdom.night,
                disabledBackgroundColor: Kingdom.parchment.withValues(alpha: 0.12),
              ),
              child: Text(isMaxed ? t.collection_trainMaxReached : t.collection_trainButton(cost)),
            ),
          ),
        ],
      ),
    );
  }
}
