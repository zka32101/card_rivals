import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/marketplace_provider.dart';
import '../models/marketplace_models.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ui_icon.dart';

class MarketplaceMyListingsScreen extends ConsumerWidget {
  const MarketplaceMyListingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final listingsAsync = ref.watch(myCardListingsProvider);

    return listingsAsync.when(
      data: (listings) {
        final activeListings = listings.where((l) => l.status == 'active').toList();
        final soldListings = listings.where((l) => l.status == 'sold').toList();

        if (listings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                IconText(
                  t.marketplace_noMyListings,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                IconText(
                  t.marketplace_startSelling,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    // TODO: Navigate to create listing screen
                  },
                  icon: const Icon(Icons.add),
                  label: IconText(t.marketplace_createNewListing),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(Kingdom.spaceMd),
          children: [
            // Active Listings Section
            if (activeListings.isNotEmpty) ...[
              _SectionHeader('${t.marketplace_activeListings} (${activeListings.length})'),
              ...activeListings.map((listing) => MyListingTile(listing: listing)),
              const SizedBox(height: Kingdom.spaceXxl),
            ],

            // Sold Listings Section
            if (soldListings.isNotEmpty) ...[
              _SectionHeader('${t.marketplace_soldListings} (${soldListings.length})'),
              ...soldListings.map((listing) => SoldListingTile(listing: listing)),
            ],

            // Create New Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Kingdom.spaceMd),
              child: FilledButton.icon(
                onPressed: () {
                  // TODO: Navigate to create listing screen
                },
                icon: const Icon(Icons.add),
                label: IconText(t.marketplace_createNewListing),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

class MyListingTile extends ConsumerWidget {
  final CardListing listing;

  const MyListingTile({Key? key, required this.listing}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardNameDisplay = listing.cardName['en'] ?? listing.cardName['jp'] ?? 'Unknown';

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
                      IconText(
                        cardNameDisplay,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Kingdom.gilt.withValues(alpha: 0.2),
                              border: Border.all(color: Kingdom.gilt.withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${listing.views} ${AppLocalizations.of(context)!.marketplace_viewsLabel}',
                              style: TextStyle(fontSize: 11, color: Kingdom.gilt),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${AppLocalizations.of(context)!.marketplace_costLabel} ${listing.cost}',
                            style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconText(
                      '${listing.price}🪙',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Kingdom.gilt),
                    ),
                    IconText(
                      '${listing.sellerReceives}🪙 ${AppLocalizations.of(context)!.marketplace_afterFee}',
                      style: TextStyle(fontSize: 10, color: Kingdom.parchment.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Kingdom.spaceMd),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(AppLocalizations.of(context)!.marketplace_updatePrice),
                    onPressed: () {
                      // TODO: Show update price dialog
                    },
                  ),
                ),
                const SizedBox(width: Kingdom.spaceSm),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(AppLocalizations.of(context)!.marketplace_delist),
                    onPressed: () => _showDelistConfirm(context, ref, listing),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDelistConfirm(BuildContext context, WidgetRef ref, CardListing listing) {
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: IconText(t.marketplace_removeListingTitle),
        content: Text('${t.marketplace_removeListingDesc} (${listing.cardName['en'] ?? 'this card'})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: IconText(t.marketplace_cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await delistCardFlow(ref, listing.listingId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? t.marketplace_listingRemoved : t.marketplace_removeListingFailed),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: IconText(t.marketplace_remove),
          ),
        ],
      ),
    );
  }
}

class SoldListingTile extends StatelessWidget {
  final CardListing listing;

  const SoldListingTile({Key? key, required this.listing}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardNameDisplay = listing.cardName['en'] ?? listing.cardName['jp'] ?? 'Unknown';

    return Card(
      color: Kingdom.nightDeep.withValues(alpha: 0.6),
      margin: const EdgeInsets.only(bottom: Kingdom.spaceSm),
      child: Padding(
        padding: const EdgeInsets.all(Kingdom.spaceMd),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconText(
                    cardNameDisplay,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Kingdom.parchment.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppLocalizations.of(context)!.marketplace_soldTo} ${listing.buyerName ?? 'unknown'}',
                    style: TextStyle(fontSize: 11, color: Kingdom.parchment.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
            IconText(
              '+${listing.sellerReceives}🪙',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Kingdom.parchment.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Kingdom.spaceMd),
      child: IconText(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Kingdom.gilt,
        ),
      ),
    );
  }
}
