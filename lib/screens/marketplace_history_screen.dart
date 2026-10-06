import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/marketplace_provider.dart';
import '../models/marketplace_models.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ui_icon.dart';

class MarketplaceHistoryScreen extends ConsumerWidget {
  const MarketplaceHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final historyAsync = ref.watch(marketplaceHistoryProvider);

    return historyAsync.when(
      data: (history) {
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                IconText(
                  t.marketplace_noHistory,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                IconText(
                  t.marketplace_historyDesc,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(Kingdom.spaceMd),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final transaction = history[index];
            return TransactionHistoryTile(transaction: transaction);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class TransactionHistoryTile extends StatelessWidget {
  final MarketplaceTransaction transaction;

  const TransactionHistoryTile({Key? key, required this.transaction}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final typeLabel = _getTypeLabel(transaction.type, t);
    final typeIcon = _getTypeIcon(transaction.type);
    final isIncome = transaction.coinsDelta > 0 || transaction.gemsDelta > 0;
    final deltaDisplay = _formatDelta(transaction);

    return Card(
      color: Kingdom.nightDeep,
      margin: const EdgeInsets.only(bottom: Kingdom.spaceMd),
      child: Padding(
        padding: const EdgeInsets.all(Kingdom.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (isIncome ? Kingdom.joyGold : Kingdom.angerCrimson).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            typeIcon,
                            color: isIncome ? Kingdom.joyGold : Kingdom.angerCrimson,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: Kingdom.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconText(
                              typeLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (transaction.counterpartyName != null) ...[
                              const SizedBox(height: 4),
                              IconText(
                                t.marketplace_with(transaction.counterpartyName!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Kingdom.parchment.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconText(
                      deltaDisplay,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isIncome ? Kingdom.joyGold : Kingdom.angerCrimson,
                      ),
                    ),
                    if (transaction.transactionFeeCoins > 0) ...[
                      const SizedBox(height: 4),
                      IconText(
                        t.marketplace_fee(transaction.transactionFeeCoins),
                        style: TextStyle(
                          fontSize: 10,
                          color: Kingdom.parchment.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: Kingdom.spaceSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconText(
                  _formatDate(transaction.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Kingdom.parchment.withValues(alpha: 0.5),
                  ),
                ),
                if (!transaction.isSuccessful)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Kingdom.angerCrimson.withValues(alpha: 0.2),
                      border: Border.all(color: Kingdom.angerCrimson.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconText(
                      t.marketplace_failed,
                      style: TextStyle(fontSize: 10, color: Kingdom.angerCrimson),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(String type, AppLocalizations t) {
    switch (type) {
      case 'card_sale':
        return t.marketplace_cardSale;
      case 'trade_accepted':
        return t.marketplace_tradeCompleted;
      case 'currency_exchange':
        return t.marketplace_currencyExchange;
      default:
        return t.marketplace_transaction;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'card_sale':
        return Icons.shopping_bag;
      case 'trade_accepted':
        return Icons.compare_arrows;
      case 'currency_exchange':
        return Icons.currency_exchange;
      default:
        return Icons.receipt;
    }
  }

  String _formatDelta(MarketplaceTransaction transaction) {
    final parts = <String>[];

    if (transaction.coinsDelta != 0) {
      final sign = transaction.coinsDelta > 0 ? '+' : '';
      parts.add('$sign${transaction.coinsDelta}🪙');
    }

    if (transaction.gemsDelta != 0) {
      final sign = transaction.gemsDelta > 0 ? '+' : '';
      parts.add('$sign${transaction.gemsDelta}💎');
    }

    return parts.join(' ');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
