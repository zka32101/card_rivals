import 'package:flutter/material.dart';
import '../models/card_name.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/marketplace_provider.dart';
import '../providers/auth_provider.dart';
import '../models/marketplace_models.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

class MarketplaceTradeOffersScreen extends ConsumerWidget {
  const MarketplaceTradeOffersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final offersAsync = ref.watch(myTradeOffersProvider);

    return offersAsync.when(
      data: (offers) {
        if (offers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.compare_arrows,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  t.marketplace_noTradeOffers,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  t.marketplace_noTradeOffersDesc,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    // TODO: Navigate to create trade offer screen
                  },
                  icon: const Icon(Icons.add),
                  label: Text(t.marketplace_sendTradeOffer),
                ),
              ],
            ),
          );
        }

        final sentOffers = offers.where((o) => o.status == 'pending').toList();
        final receivedOffers = offers.where((o) => o.status == 'pending').toList();
        final completedOffers = offers.where((o) => ['accepted', 'rejected', 'expired', 'cancelled'].contains(o.status)).toList();

        return ListView(
          padding: const EdgeInsets.all(Kingdom.spaceMd),
          children: [
            // Pending Offers Section
            if (sentOffers.isNotEmpty || receivedOffers.isNotEmpty) ...[
              _SectionHeader('${t.marketplace_askingFor}'),
              ...offers
                  .where((o) => o.status == 'pending')
                  .map((offer) => TradeOfferTile(offer: offer)),
              const SizedBox(height: Kingdom.spaceXxl),
            ],

            // Completed Trades Section
            if (completedOffers.isNotEmpty) ...[
              _SectionHeader('${t.marketplace_completed} (${completedOffers.length})'),
              ...completedOffers.map((offer) => CompletedTradeOfferTile(offer: offer)),
            ],

            // Create New Button
            if (offers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Kingdom.spaceMd),
                child: FilledButton.icon(
                  onPressed: () {
                    // TODO: Navigate to create trade offer screen
                  },
                  icon: const Icon(Icons.add),
                  label: Text(t.marketplace_sendTradeOffer),
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

class TradeOfferTile extends ConsumerWidget {
  final TradeOffer offer;

  const TradeOfferTile({Key? key, required this.offer}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncoming = offer.recipientId == ref.watch(currentUserIdProvider);

    return Card(
      color: Kingdom.nightDeep,
      margin: const EdgeInsets.only(bottom: Kingdom.spaceMd),
      child: Padding(
        padding: const EdgeInsets.all(Kingdom.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Trade Direction & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIncoming ? '${AppLocalizations.of(context)!.marketplace_tradeFrom} ${offer.senderName}' : '${AppLocalizations.of(context)!.marketplace_tradeTo} ${offer.recipientName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Kingdom.joyGold.withValues(alpha: 0.2),
                          border: Border.all(color: Kingdom.joyGold.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.marketplace_daysRemaining(offer.daysRemaining),
                          style: TextStyle(fontSize: 11, color: Kingdom.joyGold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Kingdom.spaceMd),

            // Trade Cards Display
            Row(
              children: [
                // Sender Cards
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIncoming ? AppLocalizations.of(context)!.marketplace_offering : AppLocalizations.of(context)!.marketplace_sending,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Kingdom.parchment.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...offer.senderCards.map((card) => _TradeCardChip(card: card)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceMd),
                  child: Icon(
                    Icons.compare_arrows,
                    color: Kingdom.joyGold,
                    size: 24,
                  ),
                ),
                // Recipient Cards
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isIncoming ? AppLocalizations.of(context)!.marketplace_askingFor : AppLocalizations.of(context)!.marketplace_receiving,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Kingdom.parchment.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      ...offer.recipientCards.map((card) => _TradeCardChip(card: card, align: TextAlign.right)),
                    ],
                  ),
                ),
              ],
            ),

            // Message (if present)
            if (offer.message != null && offer.message!.isNotEmpty) ...[
              const SizedBox(height: Kingdom.spaceMd),
              Container(
                padding: const EdgeInsets.all(Kingdom.spaceSm),
                decoration: BoxDecoration(
                  color: Kingdom.sadnessIndigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Kingdom.sadnessIndigo.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '"${offer.message}"',
                  style: TextStyle(
                    fontSize: 12,
                    color: Kingdom.parchment.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            // Action Buttons (for incoming offers)
            if (isIncoming && offer.status == 'pending') ...[
              const SizedBox(height: Kingdom.spaceMd),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showRejectConfirm(context, ref, offer),
                      child: Text(AppLocalizations.of(context)!.marketplace_reject),
                    ),
                  ),
                  const SizedBox(width: Kingdom.spaceSm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _showAcceptConfirm(context, ref, offer),
                      child: Text(AppLocalizations.of(context)!.marketplace_accept),
                    ),
                  ),
                ],
              ),
            ],

            // Action Buttons (for sent offers)
            if (!isIncoming && offer.status == 'pending') ...[
              const SizedBox(height: Kingdom.spaceMd),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(AppLocalizations.of(context)!.marketplace_cancelTradeTitle),
                  onPressed: () => _showCancelConfirm(context, ref, offer),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAcceptConfirm(BuildContext context, WidgetRef ref, TradeOffer offer) {
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.marketplace_acceptTradeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.marketplace_willGive(offer.recipientCards.length)),
            const SizedBox(height: 8),
            Text(t.marketplace_willReceive(offer.senderCards.length, offer.senderName)),
            const SizedBox(height: 16),
            Text(
              t.marketplace_cannotUndo,
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.marketplace_cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await respondToTradeOfferFlow(ref, offer.offerId, 'accept');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? t.marketplace_tradeAccepted : t.marketplace_acceptFailed),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: Text(t.marketplace_accept),
          ),
        ],
      ),
    );
  }

  void _showRejectConfirm(BuildContext context, WidgetRef ref, TradeOffer offer) {
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.marketplace_rejectTradeTitle),
        content: Text(t.marketplace_rejectDesc(offer.senderName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.marketplace_cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await respondToTradeOfferFlow(ref, offer.offerId, 'reject');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? t.marketplace_tradeRejected : t.marketplace_rejectFailed),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: Text(t.marketplace_reject),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirm(BuildContext context, WidgetRef ref, TradeOffer offer) {
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.marketplace_cancelTradeTitle),
        content: Text(t.marketplace_cancelDesc(offer.recipientName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.marketplace_keep),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await cancelTradeOfferFlow(ref, offer.offerId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? t.marketplace_tradeCancelled : t.marketplace_cancelFailed),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: Text(t.marketplace_cancel),
          ),
        ],
      ),
    );
  }
}

class CompletedTradeOfferTile extends StatelessWidget {
  final TradeOffer offer;

  const CompletedTradeOfferTile({Key? key, required this.offer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final statusColor = offer.status == 'accepted' ? Colors.green : Colors.orange;
    final statusLabel = offer.status == 'accepted' ? t.marketplace_completed : offer.status.capitalize();

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
                  Text(
                    'Trade with ${offer.senderName == offer.senderId ? offer.recipientName : offer.senderName}',
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
                    '${offer.senderCards.length} ↔ ${offer.recipientCards.length} cards',
                    style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeCardChip extends StatelessWidget {
  final TradeCard card;
  final TextAlign align;

  const _TradeCardChip({required this.card, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Kingdom.spaceSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceSm, vertical: 4),
        decoration: BoxDecoration(
          color: Kingdom.sadnessIndigo.withValues(alpha: 0.2),
          border: Border.all(color: Kingdom.sadnessIndigo.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${localizedCardNameOrUnknown(AppLocalizations.of(context)!, card.cardName)} (${card.cost})',
          style: TextStyle(
            fontSize: 11,
            color: Kingdom.parchment.withValues(alpha: 0.8),
          ),
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
      child: Text(
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

extension on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}
