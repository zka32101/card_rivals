import 'package:flutter/material.dart';
import '../models/card_name.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/marketplace_provider.dart';
import '../models/marketplace_models.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ui_icon.dart';

class MarketplaceBrowseScreen extends ConsumerWidget {
  const MarketplaceBrowseScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final listingsAsync = ref.watch(activeCardListingsProvider);

    return listingsAsync.when(
      data: (listings) {
        if (listings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                IconText(
                  t.marketplace_noListings,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                IconText(
                  t.marketplace_checkBackLater,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(Kingdom.spaceMd),
          itemCount: listings.length,
          itemBuilder: (context, index) {
            final listing = listings[index];
            return CardListingTile(
              listing: listing,
              onBuy: () => _showBuyConfirmDialog(context, ref, listing),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  void _showBuyConfirmDialog(BuildContext context, WidgetRef ref, CardListing listing) {
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: IconText(t.marketplace_confirmPurchase),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t.marketplace_cardLabel}: ${localizedCardNameOrUnknown(AppLocalizations.of(context)!, listing.cardName)}'),
            const SizedBox(height: 8),
            IconText('${t.marketplace_priceLabel}: ${listing.price} 🪙'),
            const SizedBox(height: 8),
            IconText(
              '${t.marketplace_platformFeeLabel}: ${listing.platformFee} 🪙 (10%)',
              style: const TextStyle(fontSize: 12, color: Colors.amber),
            ),
            const SizedBox(height: 8),
            IconText(
              '${t.marketplace_totalLabel}: ${listing.price} 🪙',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: IconText(t.marketplace_cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              _performBuy(context, ref, listing);
            },
            child: IconText(t.marketplace_buy),
          ),
        ],
      ),
    );
  }

  void _performBuy(BuildContext context, WidgetRef ref, CardListing listing) async {
    final t = AppLocalizations.of(context)!;
    final success = await buyCardFlow(ref, listing.listingId);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: IconText(t.marketplace_purchaseSuccessTitle),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: IconText(t.marketplace_purchaseFailedTitle),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class CardListingTile extends StatelessWidget {
  final CardListing listing;
  final VoidCallback? onBuy;

  const CardListingTile({
    Key? key,
    required this.listing,
    this.onBuy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardNameDisplay = localizedCardNameOrUnknown(AppLocalizations.of(context)!, listing.cardName);

    return Card(
      color: Kingdom.nightDeep,
      margin: const EdgeInsets.only(bottom: Kingdom.spaceMd),
      child: Padding(
        padding: const EdgeInsets.all(Kingdom.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Card Name & Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconText(
                        cardNameDisplay,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppLocalizations.of(context)!.marketplace_byLabel} ${listing.sellerName}',
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
                    const IconText('🪙', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Kingdom.spaceSm),

            // Card Stats
            Row(
              children: [
                _StatChip('${AppLocalizations.of(context)!.marketplace_costLabel} ${listing.cost}', Kingdom.sadnessIndigo),
                const SizedBox(width: Kingdom.spaceXs),
                _StatChip(listing.attribute, Kingdom.joyGold),
                const SizedBox(width: Kingdom.spaceXs),
                Expanded(
                  child: Text(
                    '${listing.views} ${AppLocalizations.of(context)!.marketplace_viewsLabel}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Kingdom.parchment.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Kingdom.spaceMd),

            // Buy Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onBuy,
                child: Text(AppLocalizations.of(context)!.marketplace_buyNow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceSm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconText(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
