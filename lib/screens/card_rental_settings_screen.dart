import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/card_rental_provider.dart';
import '../providers/collection_provider.dart';
import '../models/user_card.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

// ローカライズされたカード名を取得（現在のロケールに基づいてJP/EN を切り替え）
String _getCardDisplayName(BuildContext context, UserCard card) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode == 'en' && card.nameEn.isNotEmpty) {
    return card.nameEn;
  }
  return card.nameJp;
}

class CardRentalSettingsScreen extends ConsumerWidget {
  const CardRentalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final myCards = ref.watch(myCardsProvider);
    final earnings = ref.watch(userRentalEarningsProvider);

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text(t.cardRental_appBarTitle, style: Kingdom.title(size: 16)),
        elevation: 0,
        backgroundColor: Kingdom.nightDeep,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 10)),
          myCards.isEmpty
          ? Center(
              child: Text(t.cardRental_noCards, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5))),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // 収益表示
                  Padding(
                    padding: const EdgeInsets.all(Kingdom.spaceMd),
                    child: OrnateFrame(
                      accent: Kingdom.joyGold,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.cardRental_monthlyEarningsLabel, style: Kingdom.label(size: 12, color: Kingdom.joyGold)),
                          const SizedBox(height: Kingdom.spaceSm),
                          Text(t.cardRental_coinsAmount(earnings),
                              style: TextStyle(
                                  fontFamily: Kingdom.displayFont,
                                  fontSize: Kingdom.textDisplay,
                                  fontWeight: FontWeight.bold,
                                  color: Kingdom.joyGold)),
                          const SizedBox(height: 6),
                          Text(t.cardRental_publicCount(myCards.where((c) => c.isPublic).length),
                              style: TextStyle(fontSize: Kingdom.textCaption, color: Kingdom.joyGold.withValues(alpha: 0.8))),
                        ],
                      ),
                    ),
                  ),

                  // 説明
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceMd),
                    child: OrnateFrame(
                      accent: Kingdom.sadnessIndigo,
                      padding: const EdgeInsets.all(Kingdom.spaceMd),
                      child: Text(
                        t.cardRental_explanation,
                        style: TextStyle(fontSize: Kingdom.textCaption, color: const Color(0xFF7C9CDB), height: 1.6),
                      ),
                    ),
                  ),

                  const SizedBox(height: Kingdom.spaceMd),

                  // カードリスト
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceMd),
                    child: Column(
                      children: myCards.map((card) {
                        return _CardRentalToggleItem(
                          card: card,
                          onToggle: (value) => toggleCardPublic(ref, card.cardId, value),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: Kingdom.spaceXl),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CardRentalToggleItem extends StatelessWidget {
  final UserCard card;
  final Function(bool) onToggle;

  const _CardRentalToggleItem({
    required this.card,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final cardTypeStr = card.getCardType();
    final typeLabel = switch (cardTypeStr) {
      'attack' => '⚔️',
      'defense' => '🛡️',
      'speed' => '⚡',
      _ => '⚖️',
    };
    final isPublic = card.isPublic;
    final accent = isPublic ? Kingdom.joyGold : const Color(0xFF7C9CDB);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(Kingdom.spaceMd),
      decoration: BoxDecoration(
        color: Kingdom.nightDeep,
        border: Border.all(color: accent, width: 1.0),
        borderRadius: BorderRadius.circular(10),
        boxShadow: isPublic ? [BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 4)] : null,
      ),
      child: Row(
        children: [
          // カード情報
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getCardDisplayName(context, card),
                    style: TextStyle(
                        fontFamily: Kingdom.displayFont, fontSize: Kingdom.textBody, fontWeight: FontWeight.bold, color: Kingdom.parchment),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(t.cardRental_costLabel(card.cost), style: TextStyle(fontSize: Kingdom.textCaption, color: Kingdom.parchment.withValues(alpha: 0.5))),
                    const SizedBox(width: Kingdom.spaceSm),
                    Text(typeLabel, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: Kingdom.spaceSm),

          // トグル（タップ領域を48x48以上に拡張、見た目のスイッチサイズは変更しない）
          GestureDetector(
            onTap: () => onToggle(!isPublic),
            child: Container(
              width: 50,
              height: Kingdom.minTapTarget,
              alignment: Alignment.center,
              child: Container(
                width: 50,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  border: Border.all(color: accent, width: 1.0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      left: isPublic ? 24 : 2,
                      top: 2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
