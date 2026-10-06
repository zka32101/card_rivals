import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/marketplace_provider.dart';
import '../models/marketplace_models.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ui_icon.dart';

class MarketplaceCurrencyScreen extends ConsumerWidget {
  const MarketplaceCurrencyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Kingdom.gilt,
            unselectedLabelColor: Kingdom.parchment.withValues(alpha: 0.6),
            indicatorColor: Kingdom.gilt,
            tabs: [
              Tab(text: t.marketplace_buyGems),
              Tab(text: t.marketplace_sellGems),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _BuyGemsTab(),
                _SellGemsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyGemsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final listings = ref.watch(currencyListingsByTypeProvider('sell_gems'));

    if (listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            IconText(
              t.marketplace_noSellers,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            IconText(
              t.marketplace_noSellersDesc,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Sort by best price (lowest coins per gem)
    final sorted = [...listings];
    sorted.sort((a, b) => a.price.compareTo(b.price));

    return ListView.builder(
      padding: const EdgeInsets.all(Kingdom.spaceMd),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final listing = sorted[index];
        return CurrencyListingTile(
          listing: listing,
          onFill: () => _showFillDialog(context, ref, listing, 'buy'),
        );
      },
    );
  }

  void _showFillDialog(BuildContext context, WidgetRef ref, CurrencyListing listing, String action) {
    final t = AppLocalizations.of(context)!;
    final maxAmount = listing.amount;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: IconText(t.marketplace_buyGems),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconText(t.marketplace_available(maxAmount, 'gems')),
            const SizedBox(height: 8),
            IconText(t.marketplace_price(listing.price, 'gem')),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: t.marketplace_amount(maxAmount),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 16),
            Builder(builder: (ctx) {
              int amount = int.tryParse(amountController.text) ?? 0;
              int total = amount * listing.price;
              return IconText(t.marketplace_total(total));
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: IconText(t.marketplace_cancel),
          ),
          FilledButton(
            onPressed: () async {
              final amount = int.tryParse(amountController.text);
              if (amount == null || amount <= 0 || amount > maxAmount) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: IconText(t.marketplace_invalidAmount)),
                  );
                }
                return;
              }

              Navigator.pop(context);
              final success = await fillCurrencyListingFlow(ref, listing.listingId, amount: amount);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? t.marketplace_purchaseSuccess : t.marketplace_purchaseFailed),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: IconText(t.marketplace_buy),
          ),
        ],
      ),
    );
  }
}

class _SellGemsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final listings = ref.watch(currencyListingsByTypeProvider('buy_gems'));

    if (listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_down,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            IconText(
              t.marketplace_noBuyers,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            IconText(
              t.marketplace_noBuyersDesc,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                // TODO: Navigate to create sell gems listing
              },
              icon: const Icon(Icons.add),
              label: IconText(t.marketplace_createSellListing),
            ),
          ],
        ),
      );
    }

    // Sort by best price (highest coins per gem)
    final sorted = [...listings];
    sorted.sort((a, b) => b.price.compareTo(a.price));

    return ListView(
      padding: const EdgeInsets.all(Kingdom.spaceMd),
      children: [
        ...sorted.map((listing) => CurrencyListingTile(
              listing: listing,
              onFill: () => _showFillDialog(context, ref, listing, 'sell'),
            )),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Kingdom.spaceMd),
          child: FilledButton.icon(
            onPressed: () {
              // TODO: Navigate to create sell gems listing
            },
            icon: const Icon(Icons.add),
            label: IconText(t.marketplace_createSellListing),
          ),
        ),
      ],
    );
  }

  void _showFillDialog(BuildContext context, WidgetRef ref, CurrencyListing listing, String action) {
    final t = AppLocalizations.of(context)!;
    final maxAmount = listing.amount;
    final amountController = TextEditingController();
    final isSell = action == 'sell';
    final currencyType = isSell ? 'coins' : 'gems';
    final currencyEmoji = isSell ? '🪙' : '💎';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: IconText(isSell ? t.marketplace_sellGems : t.marketplace_buyGems),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconText(t.marketplace_available(maxAmount, currencyType)),
            const SizedBox(height: 8),
            IconText(t.marketplace_price(listing.price, isSell ? 'gem' : 'coin')),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: t.marketplace_amount(maxAmount),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 16),
            Builder(builder: (ctx) {
              int amount = int.tryParse(amountController.text) ?? 0;
              int total = amount * listing.price;
              return IconText(t.marketplace_youReceive(total, currencyEmoji));
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: IconText(t.marketplace_cancel),
          ),
          FilledButton(
            onPressed: () async {
              final amount = int.tryParse(amountController.text);
              if (amount == null || amount <= 0 || amount > maxAmount) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: IconText(t.marketplace_invalidAmount)),
                  );
                }
                return;
              }

              Navigator.pop(context);
              final success = await fillCurrencyListingFlow(ref, listing.listingId, amount: amount);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? t.marketplace_exchangeSuccess : t.marketplace_exchangeFailed),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: Text(isSell ? t.marketplace_sell : t.marketplace_buy),
          ),
        ],
      ),
    );
  }
}

class CurrencyListingTile extends StatelessWidget {
  final CurrencyListing listing;
  final VoidCallback onFill;

  const CurrencyListingTile({
    Key? key,
    required this.listing,
    required this.onFill,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isSellGems = listing.type == 'sell_gems';
    final currencyLabel = isSellGems ? '💎' : '💎';
    final coinsLabel = '🪙';

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSellGems ? 'Buy Gems' : 'Buy Coins',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${listing.amount} ${isSellGems ? currencyLabel : coinsLabel} available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Kingdom.parchment.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${listing.price}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Kingdom.gilt,
                      ),
                    ),
                    Text(
                      isSellGems ? coinsLabel : currencyLabel,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Kingdom.spaceMd),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onFill,
                child: Text(isSellGems ? 'Buy Gems' : 'Sell Gems'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
