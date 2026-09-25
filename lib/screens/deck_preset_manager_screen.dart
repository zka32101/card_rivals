import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/deck_preset.dart';
import '../providers/deck_presets_provider.dart';
import '../theme/kingdom_theme.dart';

class DeckPresetManagerScreen extends ConsumerStatefulWidget {
  /// 選択されたプリセットのコールバック
  final void Function(DeckPreset)? onPresetSelected;

  /// 保存モードの場合、現在のカードリストを渡す
  final List<String>? currentCardIds;

  const DeckPresetManagerScreen({
    super.key,
    this.onPresetSelected,
    this.currentCardIds,
  });

  @override
  ConsumerState<DeckPresetManagerScreen> createState() => _DeckPresetManagerScreenState();
}

class _DeckPresetManagerScreenState extends ConsumerState<DeckPresetManagerScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showSavePresetDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Kingdom.nightDeep,
        title: Text(
          l10n.deckPreset_saveDialogTitle,
          style: Kingdom.title(size: 18, color: Kingdom.gilt),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Kingdom.parchment),
                decoration: InputDecoration(
                  hintText: l10n.deckPreset_nameHint,
                  hintStyle: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Kingdom.gilt.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Kingdom.gilt),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                style: const TextStyle(color: Kingdom.parchment),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l10n.deckPreset_descriptionHint,
                  hintStyle: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Kingdom.gilt.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Kingdom.gilt),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.deckPreset_cancel, style: const TextStyle(color: Kingdom.parchment)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Kingdom.gilt),
            onPressed: () async {
              if (_nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.deckPreset_nameRequired)),
                );
                return;
              }

              try {
                await saveDeckPreset(
                  ref,
                  name: _nameController.text,
                  description: _descriptionController.text,
                  cardIds: widget.currentCardIds ?? [],
                );

                if (mounted) {
                  Navigator.pop(context);
                  _nameController.clear();
                  _descriptionController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.deckPreset_saved)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.deckPreset_error(e))),
                  );
                }
              }
            },
            child: Text(l10n.deckPreset_save),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(DeckPreset preset) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Kingdom.nightDeep,
        title: Text(
          l10n.deckPreset_deleteTitle,
          style: Kingdom.title(size: 18, color: Kingdom.angerCrimson),
        ),
        content: Text(
          l10n.deckPreset_deleteConfirm(preset.name),
          style: const TextStyle(color: Kingdom.parchment),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.deckPreset_cancel, style: const TextStyle(color: Kingdom.parchment)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Kingdom.angerCrimson),
            onPressed: () async {
              try {
                await deleteDeckPreset(ref, preset.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.deckPreset_deleted)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.deckPreset_error(e))),
                  );
                }
              }
            },
            child: Text(l10n.deckPreset_delete),
          ),
        ],
      ),
    );
  }

  void _showCopyPresetDialog(DeckPreset preset) {
    final l10n = AppLocalizations.of(context)!;
    final copyNameController = TextEditingController(text: l10n.deckPreset_copySuffix(preset.name));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Kingdom.nightDeep,
        title: Text(
          l10n.deckPreset_copyTitle,
          style: Kingdom.title(size: 18, color: Kingdom.gilt),
        ),
        content: TextField(
          controller: copyNameController,
          style: const TextStyle(color: Kingdom.parchment),
          decoration: InputDecoration(
            hintText: l10n.deckPreset_newNameHint,
            hintStyle: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Kingdom.gilt.withValues(alpha: 0.3)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Kingdom.gilt),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.deckPreset_cancel, style: const TextStyle(color: Kingdom.parchment)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Kingdom.gilt),
            onPressed: () async {
              if (copyNameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.deckPreset_nameRequired)),
                );
                return;
              }

              try {
                await copyDeckPreset(
                  ref,
                  sourcePresetId: preset.id,
                  newName: copyNameController.text,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.deckPreset_copied)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.deckPreset_error(e))),
                  );
                }
              }
            },
            child: Text(l10n.deckPreset_copy),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final presetsAsync = ref.watch(userDeckPresetsProvider);

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text(l10n.deckPreset_managerTitle),
        backgroundColor: Kingdom.nightDeep,
        elevation: 0,
      ),
      body: SafeArea(
        child: presetsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Kingdom.gilt),
          ),
          error: (error, stack) => Center(
            child: Text(
              l10n.deckPreset_loadError(error),
              style: const TextStyle(color: Kingdom.parchment),
            ),
          ),
          data: (presets) => Column(
            children: [
              // 保存ボタン（カード選択中の場合のみ）
              if (widget.currentCardIds != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ElevatedButton.icon(
                    onPressed: _showSavePresetDialog,
                    icon: const Icon(Icons.save),
                    label: Text(l10n.deckPreset_saveCurrentDeck),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Kingdom.gilt,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
              // プリセット一覧
              Expanded(
                child: presets.isEmpty
                    ? Center(
                        child: Text(
                          l10n.deckPreset_empty,
                          style: TextStyle(
                            color: Kingdom.parchment.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: presets.length,
                        itemBuilder: (context, index) {
                          final preset = presets[index];
                          return Card(
                            color: Kingdom.nightDeep,
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text(
                                preset.name,
                                style: Kingdom.title(size: 16, color: Kingdom.gilt),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (preset.description.isNotEmpty)
                                    Text(
                                      preset.description,
                                      style: TextStyle(
                                        color: Kingdom.parchment.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  Text(
                                    l10n.deckPreset_cardCount(preset.cardIds.length),
                                    style: TextStyle(
                                      color: Kingdom.parchment.withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                color: Kingdom.nightDeep,
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.copy, color: Kingdom.gilt),
                                        const SizedBox(width: 8),
                                        Text(l10n.deckPreset_copy, style: const TextStyle(color: Kingdom.parchment)),
                                      ],
                                    ),
                                    onTap: () {
                                      Future.delayed(Duration.zero, () {
                                        _showCopyPresetDialog(preset);
                                      });
                                    },
                                  ),
                                  PopupMenuItem(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete, color: Kingdom.angerCrimson),
                                        const SizedBox(width: 8),
                                        Text(l10n.deckPreset_delete, style: const TextStyle(color: Kingdom.parchment)),
                                      ],
                                    ),
                                    onTap: () {
                                      Future.delayed(Duration.zero, () {
                                        _showDeleteConfirmDialog(preset);
                                      });
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                if (widget.onPresetSelected != null) {
                                  widget.onPresetSelected!(preset);
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
