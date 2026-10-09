import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/user_card.dart';
import '../providers/collection_provider.dart';
import '../widgets/card_widget.dart';
import '../widgets/card_detail_sheet.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';
import 'card_creation_screen_v2.dart';
import '../widgets/ui_icon.dart';

enum _CardScope { all, mine, seed }

enum _CardView { grid3, grid2, list }

/// カード閲覧画面（検索・属性/レア度の絞り込み・多軸ソート・3種の表示形式）
class CollectionScreen extends ConsumerStatefulWidget {
  // 下部ナビのタブに組み込む場合は戻るボタンを出さない
  final bool embedded;
  const CollectionScreen({super.key, this.embedded = false});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  String? _attrFilter; // null = 全て
  CardRarity? _rarityFilter;
  String _sort = 'rarity'; // rarity | attr | cost | attack | defense | speed | level
  _CardScope _scope = _CardScope.all;
  _CardView _view = _CardView.grid3;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilter => _attrFilter != null || _rarityFilter != null || _query.isNotEmpty;

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _attrFilter = null;
      _rarityFilter = null;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final allCards = ref.watch(myCollectionProvider);
    final t = AppLocalizations.of(context)!;

    final mineCount = allCards.where((c) => !c.isSeedCard).length;
    final scoped = switch (_scope) {
      _CardScope.all => allCards,
      _CardScope.mine => allCards.where((c) => !c.isSeedCard).toList(),
      _CardScope.seed => allCards.where((c) => c.isSeedCard).toList(),
    };
    final shown = _filtered(scoped);
    final sortLabels = <String, String>{
      'rarity': t.collection_sortByRarity,
      'attr': t.collection_sortByAttribute,
      'cost': t.collection_sortByCost,
      'attack': t.collection_sortByAttack,
      'defense': t.collection_sortByDefense,
      'speed': t.collection_sortBySpeed,
      'level': t.collection_sortByLevel,
    };
    List<PopupMenuEntry<String>> sortMenuItems(BuildContext _) => [
          for (final e in sortLabels.entries)
            PopupMenuItem<String>(
              value: e.key,
              child: Row(children: [
                Icon(Icons.check, size: 16, color: _sort == e.key ? Kingdom.gilt : Colors.transparent),
                const SizedBox(width: 8),
                IconText(e.value, style: const TextStyle(color: Kingdom.parchment)),
              ]),
            ),
        ];

    final viewToggle = IconButton(
      tooltip: t.collection_viewToggleTooltip,
      icon: Icon(
        switch (_view) {
          _CardView.grid3 => Icons.grid_view,
          _CardView.grid2 => Icons.view_agenda_outlined,
          _CardView.list => Icons.view_list,
        },
        color: Kingdom.gilt,
      ),
      onPressed: () => setState(() => _view = _CardView.values[(_view.index + 1) % _CardView.values.length]),
    );

    return Scaffold(
      backgroundColor: Kingdom.night,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Kingdom.gilt,
        foregroundColor: Kingdom.night,
        icon: const Icon(Icons.add),
        label: IconText(t.home_createCardButton, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CardCreationScreenV2())),
      ),
      // 下部ナビのカードタブ（CardHubScreen）に組み込む場合はAppBarを持たない。
      appBar: widget.embedded
          ? null
          : AppBar(
              title: IconText(t.collection_title, style: Kingdom.title(size: 17)),
              backgroundColor: Kingdom.nightDeep,
              elevation: 0,
              actions: [viewToggle, PopupMenuButton<String>(
                icon: const Icon(Icons.sort, color: Kingdom.gilt),
                tooltip: t.collection_sortTooltip,
                color: Kingdom.nightDeep,
                initialValue: _sort,
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: sortMenuItems,
              )],
            ),
      body: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 12)),
          Column(
            children: [
              _SearchAndScopeBar(
                controller: _searchController,
                scope: _scope,
                onScopeChanged: (s) => setState(() => _scope = s),
                onQueryChanged: (q) => setState(() => _query = q.trim()),
                allCount: allCards.length,
                mineCount: mineCount,
                seedCount: allCards.length - mineCount,
              ),
              _FilterBar(
                attrFilter: _attrFilter,
                rarityFilter: _rarityFilter,
                onAttrChanged: (v) => setState(() => _attrFilter = v),
                onRarityChanged: (v) => setState(() => _rarityFilter = v),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceMd, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: IconText(
                        t.collection_resultCount(shown.length, scoped.length),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.6)),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: t.collection_sortTooltip,
                      color: Kingdom.nightDeep,
                      initialValue: _sort,
                      onSelected: (v) => setState(() => _sort = v),
                      itemBuilder: sortMenuItems,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort, size: 14, color: Kingdom.gilt),
                            const SizedBox(width: 4),
                            Text(sortLabels[_sort] ?? '',
                                style: const TextStyle(fontSize: 12, color: Kingdom.gilt, fontWeight: FontWeight.bold)),
                            const Icon(Icons.arrow_drop_down, size: 16, color: Kingdom.gilt),
                          ],
                        ),
                      ),
                    ),
                    if (widget.embedded) viewToggle,
                    if (_hasActiveFilter) const SizedBox(width: 8),
                    if (_hasActiveFilter)
                      GestureDetector(
                        onTap: _resetFilters,
                        child: IconText(t.collection_resetFilters,
                            style: const TextStyle(fontSize: 12, color: Kingdom.gilt, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _CardResults(
                  cards: shown,
                  view: _view,
                  emptyMessage: (!_hasActiveFilter && _scope == _CardScope.mine)
                      ? t.collection_emptyMyCards
                      : t.collection_emptyNoCards,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PlayCard> _filtered(List<PlayCard> cards) {
    final q = _query.toLowerCase();
    final result = cards.where((c) {
      if (_attrFilter != null && c.attribute != _attrFilter) return false;
      if (_rarityFilter != null && c.rarity != _rarityFilter) return false;
      if (q.isNotEmpty && !c.nameJp.toLowerCase().contains(q) && !c.nameEn.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    result.sort((a, b) {
      final primary = switch (_sort) {
        'attr' => a.attribute.compareTo(b.attribute),
        'cost' => b.cost.compareTo(a.cost),
        'attack' => b.attackPower.compareTo(a.attackPower),
        'defense' => b.defensePower.compareTo(a.defensePower),
        'speed' => b.speed.compareTo(a.speed),
        'level' => b.level.compareTo(a.level),
        _ => b.rarity.index.compareTo(a.rarity.index), // UR→SR→R→N
      };
      return primary != 0 ? primary : b.cost.compareTo(a.cost);
    });
    return result;
  }
}

class _SearchAndScopeBar extends StatelessWidget {
  final TextEditingController controller;
  final _CardScope scope;
  final ValueChanged<_CardScope> onScopeChanged;
  final ValueChanged<String> onQueryChanged;
  final int allCount;
  final int mineCount;
  final int seedCount;

  const _SearchAndScopeBar({
    required this.controller,
    required this.scope,
    required this.onScopeChanged,
    required this.onQueryChanged,
    required this.allCount,
    required this.mineCount,
    required this.seedCount,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    Widget seg(_CardScope s, String label, int n) {
      final selected = scope == s;
      return Expanded(
        child: GestureDetector(
          onTap: () => onScopeChanged(s),
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Kingdom.gilt : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '$label $n',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? Kingdom.night : Kingdom.parchment.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: Kingdom.nightDeep,
      padding: const EdgeInsets.fromLTRB(Kingdom.spaceMd, Kingdom.spaceSm, Kingdom.spaceMd, 0),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            style: const TextStyle(color: Kingdom.parchment, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: t.collection_searchHint,
              hintStyle: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.4)),
              prefixIcon: const Icon(Icons.search, color: Kingdom.gilt, size: 20),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Kingdom.parchment),
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                    ),
              filled: true,
              fillColor: Kingdom.night,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: Kingdom.spaceSm),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Kingdom.night,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Kingdom.gilt.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              seg(_CardScope.all, t.collection_tabAll, allCount),
              seg(_CardScope.mine, t.collection_tabMyCards, mineCount),
              seg(_CardScope.seed, t.collection_tabSeedCards, seedCount),
            ]),
          ),
        ],
      ),
    );
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
      width: double.infinity,
      color: Kingdom.nightDeep,
      padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceSm, vertical: Kingdom.spaceXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: IconText(
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

class _CardResults extends StatelessWidget {
  final List<PlayCard> cards;
  final _CardView view;
  final String emptyMessage;

  const _CardResults({required this.cards, required this.view, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Kingdom.spaceXxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎴', style: TextStyle(fontSize: 48)),
              const SizedBox(height: Kingdom.spaceMd),
              IconText(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5), fontSize: 14, height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    if (view == _CardView.list) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(Kingdom.spaceMd, Kingdom.spaceMd, Kingdom.spaceMd, 96),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _CardRow(card: cards[i]),
      );
    }

    final cols = view == _CardView.grid2 ? 2 : 3;
    const pad = Kingdom.spaceMd;
    const gap = 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        // カードは「正方形のアート + ヘッダー/種別/ステータス3行」の縦積み。幅に応じて
        // 高さを決めないと、固定の縦横比ではステータス(攻撃/防御/速度)が見切れる。
        final itemWidth = (constraints.maxWidth - pad * 2 - gap * (cols - 1)) / cols;
        final itemHeight = cardGridItemHeight(itemWidth, compact: true);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(pad, pad, pad, 96),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            mainAxisExtent: itemHeight,
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) {
            final card = cards[i];
            return GestureDetector(
              onTap: () => showCardDetailSheet(context, card),
              // 上寄せで描画（余白は下に逃がし、カード本体は中身の高さに合わせる）
              child: Align(
                alignment: Alignment.topCenter,
                child: CardWidget(card: card, size: itemWidth, compact: true),
              ),
            );
          },
        );
      },
    );
  }
}

// 一覧表示用の1行（ステータスを一目で比べられる）
class _CardRow extends StatelessWidget {
  final PlayCard card;
  const _CardRow({required this.card});

  @override
  Widget build(BuildContext context) {
    final rColor = rarityColor(card.rarity);
    final attrEmoji = switch (card.attribute) {
      'joy' => '☀️',
      'anger' => '🔥',
      _ => '🌙',
    };
    final name = Localizations.localeOf(context).languageCode == 'en' && card.nameEn.isNotEmpty
        ? card.nameEn
        : card.nameJp;
    Widget stat(String label, int v) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text('$label $v', style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.75))),
        );
    return Material(
      color: Kingdom.nightDeep,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showCardDetailSheet(context, card),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: rColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              // CardWidgetは小サイズ前提で作られていないため、一覧では簡易サムネイルにする
              Container(
                width: 56,
                height: 72,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Kingdom.night,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: rColor, width: 1.5),
                ),
                child: card.imageUrl.isEmpty
                    ? Center(child: IconText(attrEmoji, style: const TextStyle(fontSize: 24)))
                    : (card.imageUrl.startsWith('assets/')
                        ? Image.asset(card.imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(child: IconText(attrEmoji, style: const TextStyle(fontSize: 24))))
                        : Image.network(card.imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(child: IconText(attrEmoji, style: const TextStyle(fontSize: 24))))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: rColor, borderRadius: BorderRadius.circular(6)),
                        child: IconText(card.rarityLabel,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Kingdom.night)),
                      ),
                      const SizedBox(width: 6),
                      IconText(attrEmoji),
                      const SizedBox(width: 6),
                      Expanded(
                        child: IconText(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      stat('ATK', card.attackPower),
                      stat('DEF', card.defensePower),
                      stat('SPD', card.speed),
                    ]),
                    const SizedBox(height: 2),
                    Text('COST ${card.cost}${card.level > 0 ? '  Lv.${card.level}' : ''}',
                        style: TextStyle(fontSize: 11, color: Kingdom.parchment.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Kingdom.gilt.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
