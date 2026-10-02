import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/deck_preset.dart';
import '../models/user_card.dart';
import '../providers/collection_provider.dart';
import '../providers/deck_presets_provider.dart';
import '../theme/kingdom_theme.dart';
import '../widgets/card_widget.dart';
import 'deck_selection_screen_v2.dart';

/// 「マイデッキ」: 対戦用デッキ(最大[maxPresetsPerUser]個)の作成・編集・コピー・削除。
/// カードコレクションから開く。対戦開始時は、ここで作ったデッキを選ぶだけで編成できる。
class DeckListScreen extends ConsumerWidget {
  const DeckListScreen({super.key});

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.deckList_saved(name))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.deckList_saveFailed), backgroundColor: Colors.red),
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
        title: Text(t.deckList_namePrompt, style: Kingdom.title(size: 16, color: Kingdom.gilt)),
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
            child: Text(t.deckList_cancel, style: const TextStyle(color: Kingdom.parchment)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Kingdom.gilt, foregroundColor: Kingdom.night),
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: Text(t.deckList_save),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, WidgetRef ref, DeckPreset preset) async {
    final t = AppLocalizations.of(context)!;
    if (ref.read(deckPresetsCountProvider) >= maxPresetsPerUser) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.deckList_limitReached(maxPresetsPerUser))));
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
          SnackBar(content: Text(t.deckList_saveFailed), backgroundColor: Colors.red),
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
        title: Text(t.deckList_deleteTitle, style: Kingdom.title(size: 16, color: Kingdom.angerCrimson)),
        content: Text(t.deckList_deleteConfirm(preset.name), style: const TextStyle(color: Kingdom.parchment)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.deckList_cancel, style: const TextStyle(color: Kingdom.parchment)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Kingdom.angerCrimson),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.deckList_delete),
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
          SnackBar(content: Text(t.deckList_saveFailed), backgroundColor: Colors.red),
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
      appBar: AppBar(
        title: Text(t.deckList_title, style: Kingdom.title(size: 17)),
        backgroundColor: Kingdom.nightDeep,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Kingdom.gilt,
        foregroundColor: Kingdom.night,
        icon: const Icon(Icons.add),
        label: Text(t.deckList_new, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          if (count >= maxPresetsPerUser) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.deckList_limitReached(maxPresetsPerUser))));
            return;
          }
          _edit(context, ref, null, allCards);
        },
      ),
      body: presetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(t.deckList_loadFailed, style: const TextStyle(color: Kingdom.parchment))),
        data: (presets) {
          if (presets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Kingdom.spaceXxxl),
                child: Text(t.deckList_empty,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6), height: 1.7)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(Kingdom.spaceMd, Kingdom.spaceMd, Kingdom.spaceMd, 96),
            itemCount: presets.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: Kingdom.spaceSm),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(t.deckList_countLabel(count, maxPresetsPerUser),
                      style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.6))),
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
                      border: Border.all(color: Kingdom.gilt.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(preset.name,
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
                                if (v == 'copy') _copy(context, ref, preset);
                                if (v == 'delete') _delete(context, ref, preset);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'edit', child: Text(t.deckList_edit, style: const TextStyle(color: Kingdom.parchment))),
                                PopupMenuItem(value: 'copy', child: Text(t.deckList_copy, style: const TextStyle(color: Kingdom.parchment))),
                                PopupMenuItem(value: 'delete', child: Text(t.deckList_delete, style: const TextStyle(color: Kingdom.angerCrimson))),
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
                            child: Text(t.deckList_missingCards(missing),
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
