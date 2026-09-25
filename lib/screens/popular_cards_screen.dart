import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/card_rental.dart';
import '../providers/card_rental_provider.dart';
import '../providers/game_state_provider.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

class PopularCardsScreen extends ConsumerWidget {
  const PopularCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final topCardsAsync = ref.watch(popularCardsProvider);
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text(t.popularCards_appBarTitle, style: Kingdom.title(size: 16)),
        elevation: 0,
        backgroundColor: Kingdom.nightDeep,
      ),
      body: SafeArea(
        child: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 10)),
          RefreshIndicator(
            onRefresh: () => ref.refresh(popularCardsProvider.future),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // 説明
            Padding(
              padding: const EdgeInsets.all(Kingdom.spaceMd),
              child: OrnateFrame(
                accent: Kingdom.sadnessIndigo,
                padding: const EdgeInsets.all(Kingdom.spaceMd),
                child: Text(
                  t.popularCards_description,
                  style: TextStyle(fontSize: 12, color: const Color(0xFF7C9CDB), height: 1.6),
                ),
              ),
            ),

            // ランキングリスト
            switch (topCardsAsync) {
              AsyncData(:final value) when value.isEmpty => Padding(
                  padding: const EdgeInsets.all(Kingdom.spaceXl),
                  child: Text(t.rankingV3_noData, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5))),
                ),
              AsyncData(:final value) => ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceMd),
                  itemCount: value.length,
                  itemBuilder: (_, index) {
                    final card = value[index];
                    return _PopularCardItem(
                      card: card,
                      onRent: () => _showRentalDialog(context, ref, card, wallet),
                    );
                  },
                ),
              AsyncError() => Padding(
                  padding: const EdgeInsets.all(Kingdom.spaceXl),
                  child: Text(t.popularCards_loadError, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5))),
                ),
              _ => const Padding(
                  padding: EdgeInsets.all(Kingdom.spaceXl),
                  child: Center(child: CircularProgressIndicator(color: Kingdom.gilt)),
                ),
            },

            const SizedBox(height: Kingdom.spaceXl),
          ],
        ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  // レンタル料金プラン（日数 → 総額）。rentCard() にはこの表示価格をそのまま渡す。
  static const Map<int, int> _rentalPlans = {1: 50, 7: 300, 30: 1000};

  void _showRentalDialog(
    BuildContext context,
    WidgetRef ref,
    CardPopularityScore card,
    WalletState wallet,
  ) {
    int selectedDays = 1;
    bool isSubmitting = false;
    final t = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedTotalCost = _rentalPlans[selectedDays]!;
          return AlertDialog(
            backgroundColor: Kingdom.nightDeep,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Kingdom.gilt.withValues(alpha: 0.4)),
            ),
            title: Text(card.cardName, style: Kingdom.label(size: 16, color: Kingdom.gilt)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // カード情報
                  // 使用回数・勝率はまだサーバー側でトラッキングしていないため、
                  // 常に0になってしまう項目は表示しない（実データが揃うまでの間の措置）
                  _InfoRow(label: t.popularCards_costLabel, value: '${card.cost}'),
                  _InfoRow(label: t.popularCards_rentalCountLabel, value: '${card.totalRentalCount}'),
                  Divider(color: Kingdom.parchment.withValues(alpha: 0.2)),

                  // レンタル期間選択
                  Text(t.popularCards_rentalPeriodLabel, style: Kingdom.label(size: 12, color: Kingdom.gilt)),
                  const SizedBox(height: Kingdom.spaceSm),
                  Column(
                    children: _rentalPlans.entries.map((e) {
                      return _RentalOption(
                        days: e.key,
                        totalCost: e.value,
                        userBalance: wallet.coinBalance,
                        isSelected: selectedDays == e.key,
                        onTap: () => setDialogState(() => selectedDays = e.key),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: Text(t.popularCards_cancelButton, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.7))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Kingdom.sadnessIndigo,
                  foregroundColor: Kingdom.parchment,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (!isSubmitting && wallet.coinBalance >= selectedTotalCost)
                    ? () async {
                        setDialogState(() => isSubmitting = true);
                        final levelBefore = card.evolutionLevel;
                        final errorMessage = await rentCard(ref, card, selectedDays);
                        if (!context.mounted) return;
                        Navigator.pop(context);

                        if (errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(errorMessage), backgroundColor: Kingdom.angerCrimson),
                          );
                          return;
                        }

                        // レンタル成功: ランキングを再取得して進化状態の変化を確認する
                        ref.invalidate(popularCardsProvider);
                        final refreshed = await ref.read(popularCardsProvider.future);
                        final updated = refreshed.firstWhere((c) => c.cardId == card.cardId, orElse: () => card);
                        final leveledUp = updated.evolutionLevel > levelBefore;
                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(leveledUp
                                ? t.popularCards_cardEvolvedMessage(card.cardName, updated.evolutionBadge)
                                : t.popularCards_rentalSuccessMessage(card.cardName, selectedDays)),
                            backgroundColor: leveledUp ? Kingdom.gilt : Kingdom.sadnessIndigo,
                          ),
                        );
                      }
                    : null,
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Kingdom.parchment),
                      )
                    : Text(t.popularCards_rentButton),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PopularCardItem extends StatelessWidget {
  final CardPopularityScore card;
  final VoidCallback onRent;

  const _PopularCardItem({
    required this.card,
    required this.onRent,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final medalColor = switch (card.rank) {
      1 => Kingdom.gilt,
      2 => const Color(0xFFB9C6D6),
      3 => const Color(0xFFB08D57),
      _ => const Color(0xFF7C9CDB),
    };

    const medalEmoji = {1: '🥇', 2: '🥈', 3: '🥉'};

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(Kingdom.spaceMd),
      decoration: BoxDecoration(
        color: Kingdom.nightDeep,
        border: Border.all(color: medalColor, width: 1.0),
        borderRadius: BorderRadius.circular(10),
        boxShadow: card.rank <= 3
            ? [BoxShadow(color: medalColor.withValues(alpha: 0.2), blurRadius: 6, spreadRadius: 1)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              // ランク
              if (card.rank <= 3)
                Text(medalEmoji[card.rank]!, style: const TextStyle(fontSize: 24))
              else
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: medalColor, width: 1.0), shape: BoxShape.circle),
                  child: Text('#${card.rank}',
                      style: TextStyle(fontSize: Kingdom.textCaption, fontWeight: FontWeight.bold, color: medalColor)),
                ),
              const SizedBox(width: Kingdom.spaceSm),

              // カード情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            card.cardName,
                            style: TextStyle(
                                fontFamily: Kingdom.displayFont,
                                fontSize: Kingdom.textBody,
                                fontWeight: FontWeight.bold,
                                color: Kingdom.parchment),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (card.evolutionLevel > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Kingdom.gilt.withValues(alpha: 0.2),
                              border: Border.all(color: Kingdom.gilt, width: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(card.evolutionBadge,
                                style: const TextStyle(fontSize: 9, color: Kingdom.gilt, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${card.attributeEmoji} ${t.popularCards_creatorCostLine(card.creatorName, card.cost)}',
                      style: TextStyle(fontSize: Kingdom.textCaption, color: Kingdom.parchment.withValues(alpha: 0.5)),
                    ),
                    if (card.rentalsUntilNextEvolution > 0)
                      Text(t.popularCards_rentalsUntilEvolution(card.rentalsUntilNextEvolution),
                          style: const TextStyle(fontSize: 9, color: Kingdom.joyGold)),
                  ],
                ),
              ),

              // スコア
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: medalColor, width: 1.0), borderRadius: BorderRadius.circular(4)),
                child: Text('${card.popularityScore.toStringAsFixed(0)} pt',
                    style: TextStyle(fontSize: Kingdom.textCaption, fontWeight: FontWeight.bold, color: medalColor)),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 統計（使用回数・勝率はまだサーバー側でトラッキングしていないため非表示）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(icon: '🔄', label: t.popularCards_rentalStatLabel, value: '${card.totalRentalCount}'),
              _StatItem(icon: '💰', label: t.popularCards_earningsStatLabel, value: '${card.totalEarnings}'),
            ],
          ),

          const SizedBox(height: 8),

          RoyalButton(label: t.popularCards_rentButtonAction, accent: Kingdom.sadnessIndigo, height: 40, onPressed: onRent),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _StatItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: Kingdom.textCaption, fontWeight: FontWeight.bold, color: Kingdom.parchment)),
        Text(label, style: TextStyle(fontSize: 9, color: Kingdom.parchment.withValues(alpha: 0.5))),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.7), fontSize: Kingdom.textCaption)),
          Text(value, style: TextStyle(color: Kingdom.gilt, fontWeight: FontWeight.bold, fontSize: Kingdom.textCaption)),
        ],
      ),
    );
  }
}

class _RentalOption extends StatelessWidget {
  final int days;
  final int totalCost;
  final int userBalance;
  final bool isSelected;
  final VoidCallback onTap;

  const _RentalOption({
    required this.days,
    required this.totalCost,
    required this.userBalance,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final canAfford = userBalance >= totalCost;
    final color = canAfford ? Kingdom.joyGold : Kingdom.angerCrimson;

    return GestureDetector(
      onTap: canAfford ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.25 : 0.1),
          border: Border.all(color: color, width: isSelected ? 1.6 : 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (isSelected) ...[
                  Icon(Icons.check_circle, size: 13, color: color),
                  const SizedBox(width: 4),
                ],
                Text(t.popularCards_daysUnit(days), style: TextStyle(fontSize: Kingdom.textCaption, color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            Text('$totalCost💰', style: TextStyle(fontSize: Kingdom.textCaption, color: color)),
          ],
        ),
      ),
    );
  }
}
