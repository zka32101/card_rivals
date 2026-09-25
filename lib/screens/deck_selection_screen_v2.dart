import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/deck_preset.dart';
import '../models/user_card.dart';
import '../providers/collection_provider.dart';
import '../providers/deck_presets_provider.dart';
import '../widgets/card_widget.dart';
import '../widgets/card_detail_sheet.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

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
        title: Text(title, style: Kingdom.title(size: 16)),
        elevation: 0,
        backgroundColor: Kingdom.nightDeep,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open, color: Kingdom.gilt),
            tooltip: t.deckSelection_loadPresetButton,
            onPressed: _showPresetPicker,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined, color: Kingdom.gilt),
            tooltip: t.deckSelection_savePresetButton,
            onPressed: _selected.length == widget.maxCards ? _showSavePresetDialog : null,
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
                    Text(t.deckSelection_progressLabel, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6), fontSize: 12)),
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
          // 属性フィルター
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.deckSelection_filterByAttribute, style: Kingdom.label(size: 13, color: Kingdom.gilt)),
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
                      Text(t.deckSelection_selectedCardsLabel, style: Kingdom.label(size: Kingdom.textBody, color: Kingdom.gilt)),
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.62,
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
                                        content: Text(t.deckSelection_maxCardsReached(widget.maxCards)),
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
                                    child: Text(t.deckSelection_rentedBadge,
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
                        child: Text(
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

  void _showPresetPicker() {
    final t = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Kingdom.nightDeep,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Consumer(
            builder: (context, ref, _) {
              final presetsAsync = ref.watch(userDeckPresetsProvider);
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                child: Padding(
                  padding: const EdgeInsets.all(Kingdom.spaceLg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.deckSelection_presetPickerTitle, style: Kingdom.title(size: 16, color: Kingdom.gilt)),
                      const SizedBox(height: Kingdom.spaceMd),
                      Flexible(
                        child: presetsAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator(color: Kingdom.gilt)),
                          ),
                          error: (_, _) => Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(t.deckSelection_presetEmpty,
                                style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6))),
                          ),
                          data: (presets) {
                            if (presets.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(t.deckSelection_presetEmpty,
                                    style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6))),
                              );
                            }
                            return ListView.builder(
                              shrinkWrap: true,
                              itemCount: presets.length,
                              itemBuilder: (context, i) {
                                final preset = presets[i];
                                return ListTile(
                                  title: Text(preset.name,
                                      style: const TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold)),
                                  subtitle: Text(t.deckPreset_cardCount(preset.cardIds.length),
                                      style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6), fontSize: 12)),
                                  trailing: const Icon(Icons.chevron_right, color: Kingdom.gilt),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _loadPreset(preset);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _loadPreset(DeckPreset preset) {
    final t = AppLocalizations.of(context)!;
    final allCards = ref.read(battleEligibleCardsProvider);
    final cardById = {for (final c in allCards) c.cardId: c};
    final resolved = <PlayCard>[];
    var missing = false;
    for (final id in preset.cardIds) {
      final card = cardById[id];
      if (card != null) {
        resolved.add(card);
      } else {
        missing = true;
      }
    }
    setState(() => _selected = resolved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(missing ? t.deckSelection_presetMissingCards : t.deckSelection_presetLoaded(preset.name)),
        backgroundColor: missing ? Kingdom.angerCrimson : null,
      ),
    );
  }

  void _showSavePresetDialog() {
    final t = AppLocalizations.of(context)!;
    if (_selected.length != widget.maxCards) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.deckSelection_saveNeedsFullDeck(widget.maxCards))),
      );
      return;
    }
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Kingdom.nightDeep,
        title: Text(t.deckPreset_saveDialogTitle, style: Kingdom.title(size: 18, color: Kingdom.gilt)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Kingdom.parchment),
          decoration: InputDecoration(
            hintText: t.deckPreset_nameHint,
            hintStyle: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Kingdom.gilt.withValues(alpha: 0.3))),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Kingdom.gilt)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.deckPreset_cancel, style: const TextStyle(color: Kingdom.parchment)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Kingdom.gilt),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.deckPreset_nameRequired)),
                );
                return;
              }
              try {
                await saveDeckPreset(
                  ref,
                  name: name,
                  cardIds: _selected.map((c) => c.cardId).toList(),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.deckPreset_saved)),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.deckPreset_error(e)), backgroundColor: Kingdom.angerCrimson),
                  );
                }
              }
            },
            child: Text(t.deckPreset_save),
          ),
        ],
      ),
    );
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
