import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/card_frame.dart';
import '../providers/card_frame_provider.dart';
import '../theme/kingdom_theme.dart';
import 'ui_icon.dart';

String frameCostLabel(CardFrame f) => f.currency == FrameCurrency.coin ? '🪙${f.price}' : '💎${f.price}';

/// ショップの「カードフレーム」区分（コイン/ジェムで購入・装着/解除）。
class FrameShopSection extends ConsumerWidget {
  const FrameShopSection({super.key});

  void _snack(BuildContext context, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: IconText(msg), backgroundColor: error ? Kingdom.angerCrimson : null),
    );
  }

  Future<void> _buy(BuildContext context, WidgetRef ref, CardFrame frame) async {
    final t = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Kingdom.nightDeep,
        title: IconText(t.shop_frameConfirmTitle, style: Kingdom.label(size: 16, color: Kingdom.gilt)),
        content: IconText(
          t.shop_frameConfirmBody(frame.nameOf(lang), frameCostLabel(frame)),
          style: TextStyle(color: Kingdom.parchment),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: IconText(t.shop_frameCancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: IconText(t.shop_frameBuy)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final status = await ref.read(frameInventoryProvider.notifier).purchase(frame.id);
    if (!context.mounted) return;
    switch (status) {
      case FramePurchaseStatus.success:
        _snack(context, t.shop_frameBought);
      case FramePurchaseStatus.insufficientFunds:
        _snack(context, frame.currency == FrameCurrency.coin ? t.shop_frameInsufficientCoins : t.shop_insufficientGems,
            error: true);
      case FramePurchaseStatus.alreadyOwned:
      case FramePurchaseStatus.unknownFrame:
      case null:
        _snack(context, t.shop_frameFailed, error: true);
    }
  }

  Future<void> _toggleEquip(BuildContext context, WidgetRef ref, CardFrame frame, bool equipped) async {
    final n = ref.read(frameInventoryProvider.notifier);
    final ok = equipped ? await n.unequip() : await n.equip(frame.id);
    if (!ok && context.mounted) _snack(context, AppLocalizations.of(context)!.shop_frameFailed, error: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final inv = ref.watch(frameInventoryProvider);
    final equippedId = inv.validEquippedId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconText(t.shop_framesHeader, style: Kingdom.label(size: 15, color: Kingdom.gilt)),
        const SizedBox(height: Kingdom.spaceSm),
        IconText(t.shop_framesDesc, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6), fontSize: 11)),
        const SizedBox(height: Kingdom.spaceMd),
        for (final f in kCardFrames) ...[
          _FrameTile(
            frame: f,
            name: f.nameOf(lang),
            owned: inv.owns(f.id),
            equipped: equippedId == f.id,
            onBuy: () => _buy(context, ref, f),
            onToggleEquip: () => _toggleEquip(context, ref, f, equippedId == f.id),
          ),
          const SizedBox(height: Kingdom.spaceMd),
        ],
      ],
    );
  }
}

class _FrameTile extends StatelessWidget {
  final CardFrame frame;
  final String name;
  final bool owned;
  final bool equipped;
  final VoidCallback onBuy;
  final VoidCallback onToggleEquip;

  const _FrameTile({
    required this.frame,
    required this.name,
    required this.owned,
    required this.equipped,
    required this.onBuy,
    required this.onToggleEquip,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final accent = frame.currency == FrameCurrency.coin ? Kingdom.gilt : Kingdom.sadnessIndigo;
    return OrnateFrame(
      accent: accent,
      showCorners: false,
      padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceLg, vertical: Kingdom.spaceMd),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 72,
            child: Image.asset(
              frame.assetPath,
              fit: BoxFit.contain,
              errorBuilder: (_, e, s) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: Kingdom.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconText(name, style: TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold, fontSize: 14)),
                IconText(
                  equipped ? t.shop_frameEquipped : (owned ? t.shop_frameOwned : frameCostLabel(frame)),
                  style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6), fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(
            height: Kingdom.minTapTarget,
            child: ElevatedButton(
              onPressed: owned ? onToggleEquip : onBuy,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Kingdom.night,
                minimumSize: const Size(70, Kingdom.minTapTarget),
              ),
              child: IconText(
                owned ? (equipped ? t.shop_frameUnequip : t.shop_frameEquip) : frameCostLabel(frame),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
