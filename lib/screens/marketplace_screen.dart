import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/marketplace_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';
import 'marketplace_browse_screen.dart';
import 'marketplace_my_listings_screen.dart';
import 'marketplace_trade_offers_screen.dart';
import 'marketplace_currency_screen.dart';
import 'marketplace_history_screen.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 5 tabs: Browse, My Listings, Trade Offers, Currency, History
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final listingCount = ref.watch(myActiveListingCountProvider);
    final tradeOfferCount = ref.watch(pendingTradeOfferCountProvider);

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text(t.marketplace_title),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Kingdom.nightDeep,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Kingdom.gilt,
          unselectedLabelColor: Kingdom.parchment.withValues(alpha: 0.6),
          indicatorColor: Kingdom.gilt,
          tabs: [
            Tab(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_bag, size: 18),
                  const SizedBox(height: 2),
                  Text(t.marketplace_browse, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      const Icon(Icons.local_offer, size: 18),
                      if (listingCount > 0)
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Kingdom.angerCrimson,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '$listingCount',
                              style: const TextStyle(color: Colors.white, fontSize: 8),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(t.marketplace_listings, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      const Icon(Icons.compare_arrows, size: 18),
                      if (tradeOfferCount > 0)
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Kingdom.angerCrimson,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '$tradeOfferCount',
                              style: const TextStyle(color: Colors.white, fontSize: 8),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(t.marketplace_trades, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.currency_exchange, size: 18),
                  const SizedBox(height: 2),
                  Text(t.marketplace_currency, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            Tab(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, size: 18),
                  const SizedBox(height: 2),
                  Text(t.marketplace_history, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            const MarketplaceBrowseScreen(),
            const MarketplaceMyListingsScreen(),
            const MarketplaceTradeOffersScreen(),
            const MarketplaceCurrencyScreen(),
            const MarketplaceHistoryScreen(),
          ],
        ),
      ),
    );
  }
}
