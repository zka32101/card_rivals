import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/user_card.dart';
import '../models/deck_preset.dart';
import '../providers/collection_provider.dart';
import '../widgets/card_widget.dart';
import '../widgets/card_detail_sheet.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/deck_presets_provider.dart';
import 'deck_preset_manager_screen.dart';
import 'deck_list_screen.dart';
import '../widgets/ui_icon.dart';

class DeckSelectionScreenV2 extends ConsumerStatefulWidget {
  final String? title;
  final int maxCards;
  final void Function(List<PlayCard>) onConfirm;
  final List<PlayCard>? initialDeck;

  const DeckSelectionScreenV2({
    super.key,
    this.title,
    this.maxCards = 5,
    required this.onConfirm,
    this.initialDeck,
  });

  @override
  ConsumerState<DeckSelectionScreenV2> createState() => _DeckSelectionScreenV2State();
}

class _DeckSelectionScreenV2State extends ConsumerState<DeckSelectionScreenV2> {
  late List<PlayCard> _selected;
  String? _attrFilter;
  // 直近で読み込んだプリセット（編集中の対象）。読み込み後にカードを
  // 入れ替えても保持し続け、保存時に「このプリセットを上書き」を選べるようにする
  // （プリセットの「選択して編集」を成立させるための状態）。
  String? _loadedPresetId;
  String? _loadedPresetName;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialDeck ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final allCards = ref.watch(battleEligibleCardsProvider);
    final filtered = _attrFilter == null
        ? allCards
        : allCards.where((c) => c.attribute == _attrFilter).toList();
    final progress = _selected.length / widget.maxCards;
    final title = widget.title ?? t.deckSelection_defaultTitle;

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: IconText(title, style: Kingdom.title(size: 16)),
        elevation: 0,
        backgroundColor: Kingdom.nightDeep,
        actions: [
          IconButton(
            icon: const Icon(Icons.star, color: Kingdom.gilt),
            tooltip: t.deckSelection_favoritePresetsTooltip,
            onPressed: _openPresetManager,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(Kingdom.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconText(t.deckSelection_progressLabel, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6), fontSize: 12)),
                    Text('${_selected.length}/${widget.maxCards}',
                        style: TextStyle(color: Kingdom.gilt, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: Kingdom.spaceSm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Kingdom.parchment.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(Kingdom.gilt),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 10)),
          Column(
        children: [
          // マイデッキ（保存済みデッキをワンタップで適用。適用後もカードの入れ替えは自由）
          _buildMyDecksStrip(t),

          // 属性フィルター
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconText(t.deckSelection_filterByAttribute, style: Kingdom.label(size: 13, color: Kingdom.gilt)),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildFilterChip(null, t.deckSelection_filterAll, '🃏', Kingdom.bronze)),
                      const SizedBox(width: 6),
                      Expanded(child: _buildFilterChip('joy', t.attribute_joy, '☀️', Kingdom.joyGold)),
                      const SizedBox(width: 6),
                      Expanded(child: _buildFilterChip('anger', t.attribute_anger, '🔥', Kingdom.angerCrimson)),
                      const SizedBox(width: 6),
                      Expanded(child: _buildFilterChip('sadness', t.attribute_sadness, '🌙', Kingdom.sadnessIndigo)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 選択済みプレビュー
          if (_selected.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Kingdom.spaceMd),
              color: Kingdom.nightDeep,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconText(t.deckSelection_selectedCardsLabel, style: Kingdom.label(size: Kingdom.textBody, color: Kingdom.gilt)),
                      const SizedBox(width: Kingdom.spaceSm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Kingdom.gilt, borderRadius: BorderRadius.circular(4)),
                        child: Text('${_selected.length}',
                            style: TextStyle(color: Kingdom.night, fontWeight: FontWeight.bold, fontSize: Kingdom.textCaption)),
                      ),
                    ],
                  ),
                  const SizedBox(height: Kingdom.spaceSm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _selected.map((card) {
                        return Padding(
                          padding: const EdgeInsets.only(right: Kingdom.spaceSm),
                          child: GestureDetector(
                            onTap: () => setState(() => _selected.remove(card)),
                            child: Stack(
                              children: [
                                CardThumbnail(card: card, size: 60),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(color: Kingdom.angerCrimson, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 12, color: Kingdom.parchment),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Kingdom.spaceMd),
          ],

          // 利用可能なカード一覧
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                      '${t.deckSelection_cardsAvailable(filtered.length)}　${t.deckSelection_longPressHint}',
                      style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.5))),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(Kingdom.spaceMd),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: cardGridItemHeight((MediaQuery.of(context).size.width - Kingdom.spaceMd * 2 - 20) / 3, compact: true),
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final card = filtered[i];
                      final isSelected = _selected.any((c) => c.cardId == card.cardId);
                      return GestureDetector(
                        onLongPress: () => showCardDetailSheet(context, card),
                        child: Stack(
                          children: [
                            CardWidget(
                              card: card,
                              compact: true,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selected.removeWhere((c) => c.cardId == card.cardId);
                                  } else if (_selected.length < widget.maxCards) {
                                    _selected.add(card);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: IconText(t.deckSelection_maxCardsReached(widget.maxCards)),
                                        backgroundColor: Kingdom.angerCrimson,
                                      ),
                                    );
                                  }
                                });
                              },
                            ),
                            if (card.isRented)
                              Positioned(
                                top: 4,
                                left: 4,
                                child: IgnorePointer(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Kingdom.sadnessIndigo,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Kingdom.parchment.withValues(alpha: 0.6), width: 0.5),
                                    ),
                                    child: IconText(t.deckSelection_rentedBadge,
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Kingdom.parchment)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 確定ボタン
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Kingdom.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selected.length < widget.maxCards)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Kingdom.spaceMd),
                      child: OrnateFrame(
                        accent: Kingdom.sadnessIndigo,
                        padding: const EdgeInsets.all(Kingdom.spaceMd),
                        child: IconText(
                          t.deckSelection_selectMoreCards(widget.maxCards - _selected.length),
                          style: const TextStyle(fontSize: Kingdom.textBody, color: Color(0xFF7C9CDB)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  RoyalButton(
                    label: _selected.length == widget.maxCards
                        ? t.deckSelection_confirmDeck
                        : t.deckSelection_selectCardsPrompt(widget.maxCards - _selected.length),
                    height: 56,
                    onPressed: _selected.length == widget.maxCards ? () => widget.onConfirm(_selected) : null,
                  ),
                ],
              ),
            ),
          ),
        ],
          ),
        ],
      ),
    );
  }

  // 保存済みデッキの一覧（ワンタップで適用）。デッキが無ければ何も表示しない。
  Widget _buildMyDecksStrip(AppLocalizations t) {
    final presets = ref.watch(userDeckPresetsProvider).value ?? const <DeckPreset>[];
    if (presets.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Kingdom.nightDeep,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          IconText(t.deckSelection_myDecksLabel, style: Kingdom.label(size: 12, color: Kingdom.gilt)),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in presets)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p.isFavorite ? '★ ${p.name}' : p.name, style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _loadedPresetId == p.id ? Kingdom.night : Kingdom.parchment,
                        )),
                        selected: _loadedPresetId == p.id,
                        selectedColor: Kingdom.gilt,
                        backgroundColor: Kingdom.night,
                        side: BorderSide(color: Kingdom.gilt.withValues(alpha: 0.4)),
                        onSelected: (_) => _applyPreset(p),
                      ),
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeckListScreen())),
            child: IconText(t.deckSelection_manageDecks, style: const TextStyle(color: Kingdom.gilt, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _openPresetManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeckPresetManagerScreen(
          currentCardIds: _selected.map((c) => c.cardId).toList(),
          onPresetSelected: _applyPreset,
          editingPresetId: _loadedPresetId,
          editingPresetName: _loadedPresetName,
        ),
      ),
    );
  }

  void _applyPreset(DeckPreset preset) {
    final t = AppLocalizations.of(context)!;
    final allCards = ref.read(battleEligibleCardsProvider);
    final byId = {for (final c in allCards) c.cardId: c};

    final resolved = <PlayCard>[];
    var missingCount = 0;
    for (final id in preset.cardIds) {
      final card = byId[id];
      if (card == null) {
        missingCount++;
        continue;
      }
      resolved.add(card);
      if (resolved.length >= widget.maxCards) break;
    }

    setState(() {
      _selected = resolved;
      _loadedPresetId = preset.id;
      _loadedPresetName = preset.name;
    });

    if (missingCount > 0 || preset.cardIds.length > widget.maxCards) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: IconText(t.deckSelection_presetAppliedPartial(preset.name)),
          backgroundColor: Kingdom.sadnessIndigo,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: IconText(t.deckSelection_presetApplied(preset.name)),
          backgroundColor: Kingdom.joyGold,
        ),
      );
    }
  }

  Widget _buildFilterChip(String? attr, String label, String icon, Color color) {
    final isActive = _attrFilter == attr;
    return GestureDetector(
      onTap: () => setState(() => _attrFilter = attr),
      // タップ領域を48px以上に拡張（見た目のチップサイズは変更しない）
      child: SizedBox(
        height: Kingdom.minTapTarget,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? color : Kingdom.nightDeep,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isActive ? color : Kingdom.parchment.withValues(alpha: 0.15)),
            ),
            child: Center(
              child: Text(
                '$icon $label',
                style: TextStyle(
                  color: isActive ? Kingdom.night : Kingdom.parchment.withValues(alpha: 0.7),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: Kingdom.textCaption,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
