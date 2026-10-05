import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import '../models/marketplace_models.dart';
import '../models/user_card.dart';
import '../services/functions_service.dart';
import 'auth_provider.dart';
import 'collection_provider.dart';
import 'game_state_provider.dart';

// ===== Constants =====
const int kCardListingPlatformFeePercent = 10;
const int kCardListingMinPrice = 10;
const int kCardListingMaxPrice = 10000;
const int kCardListingDurationDays = 7;
const int kTradeOfferMaxCardsPerSide = 5;
const int kTradeOfferDurationDays = 7;
const int kMaxConcurrentListingsPerPlayer = 50;
const int kMarketplaceListingPageSize = 50;

// ===== ACTIVE CARD LISTINGS (Browse) =====

/// All active card listings, sorted by newest
final activeCardListingsProvider = FutureProvider<List<CardListing>>((ref) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('marketplace/active_card_listings')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(kMarketplaceListingPageSize)
        .get();

    return snapshot.docs.map((d) => CardListing.fromMap(d.data())).toList();
  } catch (e) {
    print('Error loading active listings: $e');
    return [];
  }
});

/// Filter card listings by various criteria
final filteredCardListingsProvider = FutureProvider.family<
    List<CardListing>,
    ({String? attribute, int? minCost, int? maxCost, int? minPrice, int? maxPrice})
>((ref, filters) async {
  try {
    var query = FirebaseFirestore.instance
        .collection('marketplace/active_card_listings')
        .where('status', isEqualTo: 'active') as Query<Map<String, dynamic>>;

    if (filters.attribute != null) {
      query = query.where('attribute', isEqualTo: filters.attribute);
    }
    if (filters.minCost != null) {
      query = query.where('cost', isGreaterThanOrEqualTo: filters.minCost);
    }
    if (filters.maxCost != null) {
      query = query.where('cost', isLessThanOrEqualTo: filters.maxCost);
    }

    var snapshot = await query.orderBy('createdAt', descending: true).limit(50).get();
    var listings = snapshot.docs.map((d) => CardListing.fromMap(d.data())).toList();

    // Client-side filtering for price range
    if (filters.minPrice != null) {
      listings = listings.where((l) => l.price >= filters.minPrice!).toList();
    }
    if (filters.maxPrice != null) {
      listings = listings.where((l) => l.price <= filters.maxPrice!).toList();
    }

    return listings;
  } catch (e) {
    print('Error filtering listings: $e');
    return [];
  }
});

/// Search card listings by name (client-side)
final searchCardListingsProvider = Provider.family<List<CardListing>, String>((ref, query) {
  final listings = ref.watch(activeCardListingsProvider).value ?? [];
  final lowerQuery = query.toLowerCase();
  return listings.where((l) {
    final jpName = (l.cardName['jp'] ?? '').toLowerCase();
    final enName = (l.cardName['en'] ?? '').toLowerCase();
    return jpName.contains(lowerQuery) || enName.contains(lowerQuery);
  }).toList();
});

// ===== MY LISTINGS (Seller Management) =====

/// Current user's active card listings
final myCardListingsProvider = FutureProvider<List<CardListing>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('marketplace/card_listings')
        .where('status', isNotEqualTo: 'delisted')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((d) => CardListing.fromMap(d.data())).toList();
  } catch (e) {
    print('Error loading my listings: $e');
    return [];
  }
});

/// Count of user's active listings (for UI badge)
final myActiveListingCountProvider = Provider<int>((ref) {
  final listings = ref.watch(myCardListingsProvider).value ?? [];
  return listings.where((l) => l.status == 'active').length;
});

// ===== MARKETPLACE HISTORY =====

/// Transaction history for current user
final marketplaceHistoryProvider = FutureProvider<List<MarketplaceTransaction>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('marketplace/transactions')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return snapshot.docs.map((d) => MarketplaceTransaction.fromMap(d.data())).toList();
  } catch (e) {
    print('Error loading transaction history: $e');
    return [];
  }
});

/// Filter transactions by type (card_sale, trade_accepted, currency_exchange)
final filteredTransactionsProvider = Provider.family<List<MarketplaceTransaction>, String>((ref, type) {
  final history = ref.watch(marketplaceHistoryProvider).value ?? [];
  if (type.isEmpty) return history;
  return history.where((t) => t.type == type).toList();
});

// ===== TRADE OFFERS (Phase 2) =====

/// All trade offers involving current user
final myTradeOffersProvider = FutureProvider<List<TradeOffer>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  try {
    // Get offers sent by user
    final sent = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('marketplace/trade_offers')
        .where('status', isNotEqualTo: 'expired')
        .get();

    // Get offers received by user (via collectionGroup)
    final received = await FirebaseFirestore.instance
        .collectionGroup('trade_offers')
        .where('recipientId', isEqualTo: userId)
        .where('status', isNotEqualTo: 'expired')
        .get();

    final offers = [
      ...sent.docs.map((d) => TradeOffer.fromMap(d.data())),
      ...received.docs.map((d) => TradeOffer.fromMap(d.data())),
    ];

    // Deduplicate if any
    final seen = <String>{};
    return offers.where((o) => seen.add(o.offerId)).toList();
  } catch (e) {
    print('Error loading trade offers: $e');
    return [];
  }
});

/// Pending (incoming) trade offers only
final pendingTradeOffersProvider = Provider<List<TradeOffer>>((ref) {
  final offers = ref.watch(myTradeOffersProvider).value ?? [];
  return offers.where((o) => o.status == 'pending' && o.recipientId == ref.watch(currentUserIdProvider)).toList();
});

/// Count of pending trade offers (for UI badge)
final pendingTradeOfferCountProvider = Provider<int>((ref) {
  return ref.watch(pendingTradeOffersProvider).length;
});

// ===== CURRENCY LISTINGS (Phase 3) =====

/// Active currency exchange listings
final activeCurrencyListingsProvider = FutureProvider<List<CurrencyListing>>((ref) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('marketplace/active_currency_listings')
        .where('status', isEqualTo: 'active')
        .orderBy('price')
        .limit(50)
        .get();

    return snapshot.docs.map((d) => CurrencyListing.fromMap(d.data())).toList();
  } catch (e) {
    print('Error loading currency listings: $e');
    return [];
  }
});

/// Filter currency listings by type (sell_gems or buy_gems)
final currencyListingsByTypeProvider = Provider.family<List<CurrencyListing>, String>((ref, type) {
  final listings = ref.watch(activeCurrencyListingsProvider).value ?? [];
  return listings.where((l) => l.type == type).toList();
});

// ===== LOCAL STATE PROVIDERS =====

/// Draft for creating a new card listing
final draftCardListingProvider = StateProvider<({String? cardId, int? price})?>((ref) => null);

/// Selected cards for creating trade offer
final selectedSenderCardsProvider = StateProvider<List<String>>((ref) => []);
final selectedRecipientCardsProvider = StateProvider<List<String>>((ref) => []);

/// Marketplace filter preferences
final marketplaceFiltersProvider = StateProvider<({
  String? attribute,
  int? minCost,
  int? maxCost,
  int? minPrice,
  int? maxPrice,
})>((ref) => (attribute: null, minCost: null, maxCost: null, minPrice: null, maxPrice: null));

// ===== HELPER FUNCTIONS =====

/// Create a card listing
Future<void> createCardListingFlow(WidgetRef ref, String cardId, int price) async {
  try {
    final result = await FunctionsService.createCardListing(
      cardId: cardId,
      price: price,
    );

    if (result.isNotEmpty && result['listingId'] != null) {
      // Refresh listings
      ref.refresh(myCardListingsProvider);
      ref.refresh(activeCardListingsProvider);
      // Clear draft
      ref.read(draftCardListingProvider.notifier).state = null;
    }
  } catch (e) {
    print('Error creating listing: $e');
    rethrow;
  }
}

/// Buy a card from marketplace
Future<bool> buyCardFlow(WidgetRef ref, String listingId) async {
  try {
    final result = await FunctionsService.buyCard(
      listingId: listingId,
    );

    if (result.isNotEmpty && result['success'] == true) {
      // Refresh all relevant providers
      ref.refresh(activeCardListingsProvider);
      ref.refresh(myCardsProvider);
      ref.refresh(walletProvider);
      ref.refresh(marketplaceHistoryProvider);
      return true;
    }
  } catch (e) {
    print('Error buying card: $e');
  }
  return false;
}

/// Delist a card from marketplace
Future<bool> delistCardFlow(WidgetRef ref, String listingId) async {
  try {
    final result = await FunctionsService.delistCard(
      listingId: listingId,
    );

    if (result.isNotEmpty && result['success'] == true) {
      ref.refresh(myCardListingsProvider);
      ref.refresh(activeCardListingsProvider);
      return true;
    }
  } catch (e) {
    print('Error delisting card: $e');
  }
  return false;
}

/// Update price of a card listing
Future<bool> updateCardListingPriceFlow(WidgetRef ref, String listingId, int newPrice) async {
  try {
    final result = await FunctionsService.updateCardListing(
      listingId: listingId,
      newPrice: newPrice,
    );

    if (result.isNotEmpty && result['success'] == true) {
      ref.refresh(myCardListingsProvider);
      ref.refresh(activeCardListingsProvider);
      return true;
    }
  } catch (e) {
    print('Error updating listing: $e');
  }
  return false;
}

/// Create a trade offer (Phase 2)
Future<void> createTradeOfferFlow(
  WidgetRef ref,
  String recipientId,
  List<String> senderCards,
  List<String> recipientCards,
  String? message,
) async {
  try {
    final result = await FunctionsService.createTradeOffer(
      recipientId: recipientId,
      senderCardIds: senderCards,
      recipientCardIds: recipientCards,
      message: message,
    );

    if (result.isNotEmpty && result['offerId'] != null) {
      ref.refresh(myTradeOffersProvider);
      // Clear selections
      ref.read(selectedSenderCardsProvider.notifier).state = [];
      ref.read(selectedRecipientCardsProvider.notifier).state = [];
    }
  } catch (e) {
    print('Error creating trade offer: $e');
    rethrow;
  }
}

/// Respond to a trade offer (Phase 2)
Future<bool> respondToTradeOfferFlow(WidgetRef ref, String offerId, String action) async {
  try {
    final result = await FunctionsService.respondToTradeOffer(
      offerId: offerId,
      action: action,
    );

    if (result.isNotEmpty && result['success'] == true) {
      ref.refresh(myTradeOffersProvider);
      ref.refresh(myCardsProvider);
      if (action == 'accept') {
        ref.refresh(marketplaceHistoryProvider);
      }
      return true;
    }
  } catch (e) {
    print('Error responding to trade: $e');
  }
  return false;
}

/// Cancel a trade offer
Future<bool> cancelTradeOfferFlow(WidgetRef ref, String offerId) async {
  try {
    final result = await FunctionsService.cancelTradeOffer(
      offerId: offerId,
    );

    if (result.isNotEmpty && result['success'] == true) {
      ref.refresh(myTradeOffersProvider);
      return true;
    }
  } catch (e) {
    print('Error cancelling trade: $e');
  }
  return false;
}

/// Fill a currency listing (Phase 3)
Future<bool> fillCurrencyListingFlow(WidgetRef ref, String listingId, {int? amount}) async {
  try {
    final result = await FunctionsService.fillCurrencyListing(
      listingId: listingId,
      amount: amount,
    );

    if (result.isNotEmpty && result['success'] == true) {
      ref.refresh(activeCurrencyListingsProvider);
      ref.refresh(walletProvider);
      ref.refresh(marketplaceHistoryProvider);
      return true;
    }
  } catch (e) {
    print('Error filling currency listing: $e');
  }
  return false;
}
