import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/game_state_provider.dart';
import '../screens/defense_deck_screen.dart';
import '../theme/kingdom_theme.dart';
import 'card_widget.dart';

/// 現在の防衛デッキと、その変更への導線。カードタブの「デッキ」に置く。
class DefenseDeckCard extends ConsumerWidget {
  const DefenseDeckCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final defenseDeck = ref.watch(defenseDeckProvider);
    return OrnateFrame(
      accent: Kingdom.bronze,
      padding: const EdgeInsets.all(Kingdom.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                defenseDeck.isEmpty ? t.home_notSetLabel : t.home_deckCountSet(defenseDeck.length),
                style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.6)),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DefenseDeckScreen()),
                ),
                icon: const Icon(Icons.edit, size: 16, color: Kingdom.gilt),
                label: Text(t.home_changeButton, style: const TextStyle(fontSize: 12, color: Kingdom.gilt)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          defenseDeck.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Kingdom.spaceXl),
                    child: Text(
                      t.home_tapToSetDeckHint,
                      style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: defenseDeck.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: CardThumbnail(card: defenseDeck[i], size: 70),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
