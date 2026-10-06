import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/deck_preset.dart';
import '../models/user_card.dart';
import '../providers/collection_provider.dart';
import '../providers/deck_presets_provider.dart';
import '../theme/kingdom_theme.dart';
import '../widgets/card_widget.dart';
import '../widgets/defense_deck_card.dart';
import 'deck_selection_screen_v2.dart';
import '../widgets/ui_icon.dart';

/// 「マイデッキ」: 対戦用デッキ(最大[maxPresetsPerUser]個)の作成・編集・コピー・削除。
/// カードタブの「デッキ」に組み込まれる（[embedded]）ほか、単独画面としても開ける。
/// 対戦開始時は、ここで作った（お気に入りを先頭にした）デッキを選ぶだけで編成できる。
class DeckListScreen extends ConsumerWidget {
  /// カードタブ内に置く場合は AppBar を出さず、先頭に防衛デッキを表示する。
  final bool embedded;
  const DeckListScreen({super.key, this.embedded = false});

  static const int deckSize = 5;

  Future<void> _edit(BuildContext context, WidgetRef ref, DeckPreset? preset, List<PlayCard> allCards) async {
    final t = AppLocalizations.of(context)!;
    final initial = preset == null
        ? <PlayCard>[]
        : [
            for (final id in preset.cardIds)
              ...allCards.where((c) => c.cardId == id),
          ];
    final deck = await Navigator.push<List<PlayCard>>(
      context,
      MaterialPageRoute(
        builder: (ctx) => DeckSelectionScreenV2(
          title: preset == null ? t.deckList_newTitle : t.deckList_editTitle(preset.name),
          maxCards: deckSize,
          initialDeck: initial,
          onConfirm: (d) => Navigator.pop(ctx, d),
        ),
      ),
    );
    if (deck == null || !context.mounted) return;

    String name = preset?.name ?? '';
    if (preset == null) {
      final count = ref.read(deckPresetsCountProvider);
      final entered = await _askName(context, t.deckList_defaultName(count + 1));
      if (entered == null || !context.mounted) return;
      name = entered;
    }
    try {
      await saveDeckPreset(
        ref,
        name: name,
        description: preset?.description ?? '',
        cardIds: deck.map((c) => c.cardId).toList(),
        existingPresetId: preset?.id,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: IconText(t.deckList_saved(name))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: IconText(t.deckList_saveFailed), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _askName(BuildContext context, String initial) {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Kingdom.nightDeep,
        title: IconText(t.deckList_namePrompt, style: Kingdom.title(size: 16, color: Kingdom.gilt)),
        content: TextField(
          controller: controller,
          maxLength: 20,
          autofocus: true,
          style: const TextStyle(color: Kingdom.parchment),
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Kingdom.gilt.withValues(alpha: 0.3))),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Kingdom.gilt)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: IconText(t.deckList_cancel, style: const TextStyle(color: Kingdom.parchment)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Kingdom.gilt, foregroundColor: Kingdom.night),
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: IconText(t.deckList_save),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, DeckPreset preset) async {
    final t = AppLocalizations.of(context)!;
    final name = await _askName(context, preset.name);
    if (name == null || name == preset.name || !context.mounted) return;
    try {
      await renameDeckPreset(ref, preset.id, name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: IconText(t.deckList_saveFailed), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref, DeckPreset preset) async {
    final t = AppLocalizations.of(context)!;
    try {
      await setDeckPresetFavorite(ref, preset.id, !preset.isFavorite);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: IconText(t.deckList_saveFailed), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _copy(BuildContext context, WidgetRef ref, DeckPreset preset) async {
    final t = AppLocalizations.of(context)!;
    if (ref.read(deckPresetsCountProvider) >= maxPresetsPerUser) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: IconText(t.deckList_limitReached(maxPresetsPerUser))));
      return;
    }
    final name = await _askName(context, t.deckList_copyName(preset.name));
    if (name == null || !context.mounted) return;
    try {
      await copyDeckPreset(ref, sourcePresetId: preset.id, newName: name);
      ref.invalidate(userDeckPresetsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: IconText(t.deckList_saveFailed), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, DeckPreset preset) async {
    final t = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Kingdom.nightDeep,
        title: IconText(t.deckList_deleteTitle, style: Kingdom.title(size: 16, color: Kingdom.angerCrimson)),
        content: IconText(t.deckList_deleteConfirm(preset.name), style: const TextStyle(color: Kingdom.parchment)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: IconText(t.deckList_cancel, style: const TextStyle(color: Kingdom.parchment)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Kingdom.angerCrimson),
            onPressed: () => Navigator.pop(ctx, true),
            child: IconText(t.deckList_delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await deleteDeckPreset(ref, preset.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: IconText(t.deckList_saveFailed), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final presetsAsync = ref.watch(userDeckPresetsProvider);
    final allCards = ref.watch(battleEligibleCardsProvider);
    final count = ref.watch(deckPresetsCountProvider);

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: embedded
          ? null
          : AppBar(
              title: IconText(t.deckList_title, style: Kingdom.title(size: 17)),
              backgroundColor: Kingdom.nightDeep,
              elevation: 0,
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Kingdom.gilt,
        foregroundColor: Kingdom.night,
        icon: const Icon(Icons.add),
        label: IconText(t.deckList_new, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          if (count >= maxPresetsPerUser) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: IconText(t.deckList_limitReached(maxPresetsPerUser))));
            return;
          }
          _edit(context, ref, null, allCards);
        },
      ),
      body: presetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: IconText(t.deckList_loadFailed, style: const TextStyle(color: Kingdom.parchment))),
        data: (presets) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(Kingdom.spaceMd, Kingdom.spaceMd, Kingdom.spaceMd, 96),
            itemCount: presets.length + (embedded ? 2 : 1),
            separatorBuilder: (_, __) => const SizedBox(height: Kingdom.spaceSm),
            itemBuilder: (context, i) {
              // カードタブ内: 先頭は防衛デッキ、続いて対戦用デッキの見出し
              if (embedded) {
                if (i == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: Kingdom.spaceSm),
                        child: IconText(t.home_defenseDeckHeader, style: Kingdom.label(size: 13, color: Kingdom.gilt)),
                      ),
                      const DefenseDeckCard(),
                      const SizedBox(height: Kingdom.spaceMd),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: IconText(t.deckList_battleDecksHeader, style: Kingdom.label(size: 13, color: Kingdom.gilt)),
                      ),
                    ],
                  );
                }
                i -= 1;
              }
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    presets.isEmpty ? t.deckList_empty : t.deckList_countLabel(count, maxPresetsPerUser),
                    textAlign: presets.isEmpty ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      fontSize: 12,
                      height: presets.isEmpty ? 1.7 : null,
                      color: Kingdom.parchment.withValues(alpha: 0.6),
                    ),
                  ),
                );
              }
              final preset = presets[i - 1];
              final cards = [
                for (final id in preset.cardIds) ...allCards.where((c) => c.cardId == id),
              ];
              final missing = preset.cardIds.length - cards.length;
              return Material(
                color: Kingdom.nightDeep,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _edit(context, ref, preset, allCards),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Kingdom.gilt.withValues(alpha: preset.isFavorite ? 0.8 : 0.3),
                        width: preset.isFavorite ? 1.6 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              tooltip: preset.isFavorite ? t.deckList_unfavorite : t.deckList_favorite,
                              icon: Icon(
                                preset.isFavorite ? Icons.star : Icons.star_border,
                                color: preset.isFavorite ? Kingdom.gilt : Kingdom.parchment.withValues(alpha: 0.6),
                              ),
                              onPressed: () => _toggleFavorite(context, ref, preset),
                            ),
                            Expanded(
                              child: IconText(preset.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Kingdom.title(size: 15, color: Kingdom.gilt)),
                            ),
                            Text('${cards.length}/$deckSize',
                                style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.7))),
                            PopupMenuButton<String>(
                              color: Kingdom.nightDeep,
                              icon: const Icon(Icons.more_vert, color: Kingdom.parchment),
                              onSelected: (v) {
                                if (v == 'edit') _edit(context, ref, preset, allCards);
                                if (v == 'rename') _rename(context, ref, preset);
                                if (v == 'copy') _copy(context, ref, preset);
                                if (v == 'delete') _delete(context, ref, preset);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'edit', child: IconText(t.deckList_edit, style: const TextStyle(color: Kingdom.parchment))),
                                PopupMenuItem(value: 'rename', child: IconText(t.deckList_rename, style: const TextStyle(color: Kingdom.parchment))),
                                PopupMenuItem(value: 'copy', child: IconText(t.deckList_copy, style: const TextStyle(color: Kingdom.parchment))),
                                PopupMenuItem(value: 'delete', child: IconText(t.deckList_delete, style: const TextStyle(color: Kingdom.angerCrimson))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final c in cards)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: CardThumbnail(card: c, size: 56),
                                ),
                            ],
                          ),
                        ),
                        if (missing > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: IconText(t.deckList_missingCards(missing),
                                style: const TextStyle(fontSize: 11, color: Kingdom.angerCrimson)),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
