import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/user_card.dart';
import '../providers/collection_provider.dart';
import '../widgets/card_widget.dart';
import '../widgets/card_detail_sheet.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> with SingleTickerProviderStateMixin {
  String? _attrFilter;      // null = 全て
  CardRarity? _rarityFilter;
  String _sort = 'rarity';  // 'rarity' | 'attr' | 'cost'
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCards = ref.watch(myCollectionProvider);
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text(t.collection_title, style: Kingdom.title(size: 17)),
        backgroundColor: Kingdom.nightDeep,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Kingdom.gilt),
            tooltip: t.collection_sortTooltip,
            color: Kingdom.nightDeep,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rarity', child: Text(t.collection_sortByRarity, style: TextStyle(color: Kingdom.parchment))),
              PopupMenuItem(value: 'attr', child: Text(t.collection_sortByAttribute, style: TextStyle(color: Kingdom.parchment))),
              PopupMenuItem(value: 'cost', child: Text(t.collection_sortByCost, style: TextStyle(color: Kingdom.parchment))),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Kingdom.gilt,
          labelColor: Kingdom.gilt,
          unselectedLabelColor: Kingdom.parchment.withValues(alpha: 0.5),
          tabs: [
            Tab(text: t.collection_tabSeedCards),
            Tab(text: t.collection_tabMyCards),
          ],
        ),
      ),
      body: SafeArea(
        child: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 12)),
          Column(
            children: [
              // フィルターバー
              _FilterBar(
                attrFilter: _attrFilter,
                rarityFilter: _rarityFilter,
                onAttrChanged: (v) => setState(() => _attrFilter = v),
                onRarityChanged: (v) => setState(() => _rarityFilter = v),
              ),

              // カードグリッド
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // シードカード
                    _CardGrid(
                      cards: _filtered(allCards.where((c) => c.isSeedCard).toList()),
                    ),
                    // マイカード（現状はシードから未所持分を除外 ― Firebase 接続後は Firestore から取得）
                    _CardGrid(
                      cards: _filtered(allCards.where((c) => !c.isSeedCard).toList()),
                      emptyMessage: t.collection_emptyMyCards,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  List<PlayCard> _filtered(List<PlayCard> cards) {
    var result = cards.where((c) {
      if (_attrFilter != null && c.attribute != _attrFilter) return false;
      if (_rarityFilter != null && c.rarity != _rarityFilter) return false;
      return true;
    }).toList();

    result.sort((a, b) => switch (_sort) {
      'attr' => a.attribute.compareTo(b.attribute),
      'cost' => b.cost.compareTo(a.cost),
      _ => b.rarity.index.compareTo(a.rarity.index), // rarity: UR→SR→R→N
    });

    return result;
  }
}

class _FilterBar extends StatelessWidget {
  final String? attrFilter;
  final CardRarity? rarityFilter;
  final void Function(String?) onAttrChanged;
  final void Function(CardRarity?) onRarityChanged;

  const _FilterBar({
    required this.attrFilter,
    required this.rarityFilter,
    required this.onAttrChanged,
    required this.onRarityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      color: Kingdom.nightDeep,
      padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceSm, vertical: Kingdom.spaceSm),
      child: Column(
        children: [
          // 属性フィルタ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(t.collection_filterAllAttributes, attrFilter == null, () => onAttrChanged(null), Kingdom.bronze),
                const SizedBox(width: 6),
                _chip('☀️ ${t.attribute_joy}', attrFilter == 'joy', () => onAttrChanged('joy'), Kingdom.joyGold),
                const SizedBox(width: 6),
                _chip('🔥 ${t.attribute_anger}', attrFilter == 'anger', () => onAttrChanged('anger'), Kingdom.angerCrimson),
                const SizedBox(width: 6),
                _chip('🌙 ${t.attribute_sadness}', attrFilter == 'sadness', () => onAttrChanged('sadness'), Kingdom.sadnessIndigo),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // レアリティフィルタ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(t.collection_filterAllRarities, rarityFilter == null, () => onRarityChanged(null), Kingdom.bronze),
                const SizedBox(width: 6),
                _chip('UR', rarityFilter == CardRarity.ur, () => onRarityChanged(CardRarity.ur), rarityColor(CardRarity.ur)),
                const SizedBox(width: 6),
                _chip('SR', rarityFilter == CardRarity.sr, () => onRarityChanged(CardRarity.sr), rarityColor(CardRarity.sr)),
                const SizedBox(width: 6),
                _chip('R', rarityFilter == CardRarity.r, () => onRarityChanged(CardRarity.r), rarityColor(CardRarity.r)),
                const SizedBox(width: 6),
                _chip('N', rarityFilter == CardRarity.n, () => onRarityChanged(CardRarity.n), rarityColor(CardRarity.n)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: Kingdom.minTapTarget,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceMd, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? color : Kingdom.night,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? color : Kingdom.parchment.withValues(alpha: 0.2)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Kingdom.night : Kingdom.parchment.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardGrid extends StatelessWidget {
  final List<PlayCard> cards;
  final String? emptyMessage;

  const _CardGrid({required this.cards, this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      final t = AppLocalizations.of(context)!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Kingdom.spaceXxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎴', style: TextStyle(fontSize: 48)),
              const SizedBox(height: Kingdom.spaceMd),
              Text(
                emptyMessage ?? t.collection_emptyNoCards,
                textAlign: TextAlign.center,
                style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5), fontSize: 14, height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(Kingdom.spaceMd),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemCount: cards.length,
      itemBuilder: (context, i) {
        final card = cards[i];
        return GestureDetector(
          onTap: () => showCardDetailSheet(context, card),
          child: CardWidget(card: card, size: double.infinity),
        );
      },
    );
  }
}
