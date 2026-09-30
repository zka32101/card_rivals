import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/deck_preset.dart';
import '../providers/deck_presets_provider.dart';
import '../theme/kingdom_theme.dart';

class DeckPresetManagerScreen extends ConsumerStatefulWidget {
  /// 選択されたプリセットのコールバック
  final void Function(DeckPreset)? onPresetSelected;

  /// 保存モードの場合、現在のカードリストを渡す
  final List<String>? currentCardIds;

  /// 呼び出し元（デッキ選択画面）が直近で読み込んだプリセット。
  /// 指定されている場合、「新規保存」に加えて「このプリセットを上書き」も
  /// 提示する（プリセットを選択→編集→保存、を1つのプリセットに対して行えるように）。
  final String? editingPresetId;
  final String? editingPresetName;

  const DeckPresetManagerScreen({
    super.key,
    this.onPresetSelected,
    this.currentCardIds,
    this.editingPresetId,
    this.editingPresetName,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Kingdom.nightDeep,
        title: Text(
          'プリセットを保存',
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
                  hintText: 'プリセット名',
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
                  hintText: '説明（オプション）',
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
            child: const Text('キャンセル', style: TextStyle(color: Kingdom.parchment)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Kingdom.gilt),
            onPressed: () async {
              if (_nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('プリセット名を入力してください')),
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
                    const SnackBar(content: Text('プリセットを保存しました')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('エラー: $e')),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // 読み込み元プリセットに現在のデッキ内容をそのまま上書き保存する
  // （名前・説明は変更しない。プリセットの「編集」フロー用）
  Future<void> _overwriteEditingPreset() async {
    final presetId = widget.editingPresetId;
    if (presetId == null) return;
    try {
      await saveDeckPreset(
        ref,
        name: widget.editingPresetName ?? '',
        cardIds: widget.currentCardIds ?? [],
        existingPresetId: presetId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${widget.editingPresetName}」を更新しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmDialog(DeckPreset preset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Kingdom.nightDeep,
        title: Text(
          'プリセットを削除',
          style: Kingdom.title(size: 18, color: Kingdom.angerCrimson),
        ),
        content: Text(
          '「${preset.name}」を削除しますか？',
          style: const TextStyle(color: Kingdom.parchment),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: Kingdom.parchment)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Kingdom.angerCrimson),
            onPressed: () async {
              try {
                await deleteDeckPreset(ref, preset.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('プリセットを削除しました')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('エラー: $e')),
                  );
                }
              }
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  void _showCopyPresetDialog(DeckPreset preset) {
    final copyNameController = TextEditingController(text: '${preset.name} (コピー)');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Kingdom.nightDeep,
        title: Text(
          'プリセットをコピー',
          style: Kingdom.title(size: 18, color: Kingdom.gilt),
        ),
        content: TextField(
          controller: copyNameController,
          style: const TextStyle(color: Kingdom.parchment),
          decoration: InputDecoration(
            hintText: '新しい名前',
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
            child: const Text('キャンセル', style: TextStyle(color: Kingdom.parchment)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Kingdom.gilt),
            onPressed: () async {
              if (copyNameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('プリセット名を入力してください')),
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
                    const SnackBar(content: Text('プリセットをコピーしました')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('エラー: $e')),
                  );
                }
              }
            },
            child: const Text('コピー'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final presetsAsync = ref.watch(userDeckPresetsProvider);

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: const Text('デッキプリセット管理'),
        backgroundColor: Kingdom.nightDeep,
        elevation: 0,
      ),
      body: presetsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Kingdom.gilt),
        ),
        error: (error, stack) => Center(
          child: Text(
            'エラーが発生しました: $error',
            style: const TextStyle(color: Kingdom.parchment),
          ),
        ),
        data: (presets) => Column(
          children: [
            // 上書き保存ボタン（プリセットを読み込んで編集中の場合のみ）
            if (widget.currentCardIds != null && widget.editingPresetId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: ElevatedButton.icon(
                  onPressed: _overwriteEditingPreset,
                  icon: const Icon(Icons.edit),
                  label: Text('「${widget.editingPresetName}」を上書き保存'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Kingdom.sadnessIndigo,
                    foregroundColor: Kingdom.parchment,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            // 保存ボタン（カード選択中の場合のみ）
            if (widget.currentCardIds != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: _showSavePresetDialog,
                  icon: const Icon(Icons.save),
                  label: const Text('現在のデッキを保存'),
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
                        'プリセットがありません',
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
                                  'カード: ${preset.cardIds.length}枚',
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
                                    children: const [
                                      Icon(Icons.copy, color: Kingdom.gilt),
                                      SizedBox(width: 8),
                                      Text('コピー', style: TextStyle(color: Kingdom.parchment)),
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
                                    children: const [
                                      Icon(Icons.delete, color: Kingdom.angerCrimson),
                                      SizedBox(width: 8),
                                      Text('削除', style: TextStyle(color: Kingdom.parchment)),
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
    );
  }
}
