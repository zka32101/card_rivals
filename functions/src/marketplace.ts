import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';

const db = getFirestore();
const PLATFORM_FEE_PERCENT = 10;
const CARD_LISTING_MIN_PRICE = 10;
const CARD_LISTING_MAX_PRICE = 10000;
const CARD_LISTING_EXPIRY_DAYS = 7;
const TRADE_OFFER_EXPIRY_DAYS = 7;
const TRADE_OFFER_MAX_CARDS_PER_SIDE = 5;

interface CardListing {
  listingId: string;
  sellerId: string;
  sellerName: string;
  cardId: string;
  attribute: string;
  cost: number;
  cardName: Record<string, string>;
  imageUrl: string;
  price: number;
  status: 'active' | 'sold' | 'delisted';
  createdAt: Timestamp;
  soldAt?: Timestamp;
  buyerId?: string;
  buyerName?: string;
  expiresAt?: Timestamp;
  views: number;
}

interface MarketplaceTransaction {
  transactionId: string;
  type: 'card_sale' | 'trade_accepted' | 'currency_exchange';
  playerId: string;
  coinsDelta: number;
  gemsDelta: number;
  transactionFeeCoins: number;
  relatedListingId: string;
  counterpartyId?: string;
  counterpartyName?: string;
  createdAt: Timestamp;
  isSuccessful: boolean;
  errorMessage?: string;
  metadata: Record<string, any>;
}

// ===== CARD LISTINGS =====

/**
 * Create a card listing
 */
export const createCardListing = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'User not authenticated');

  const userId = request.auth.uid;
  const { cardId, price } = request.data;

  // Validate inputs
  if (!cardId || typeof cardId !== 'string') throw new Error('Invalid cardId');
  if (!price || typeof price !== 'number') throw new Error('Invalid price');
  if (price < CARD_LISTING_MIN_PRICE || price > CARD_LISTING_MAX_PRICE) {
    throw new Error(`Price must be between ${CARD_LISTING_MIN_PRICE} and ${CARD_LISTING_MAX_PRICE}`);
  }

  return await db.runTransaction(async (transaction) => {
    // Verify user owns the card
    const cardRef = db.collection('users').doc(userId).collection('cards').doc(cardId);
    const cardDoc = await transaction.get(cardRef);
    if (!cardDoc.exists) throw new HttpsError('not-found', 'Card not found');

    const cardData = cardDoc.data()!;

    // Check if card is already listed
    const existingListingQuery = await db
      .collection('users')
      .doc(userId)
      .collection('marketplace/card_listings')
      .where('cardId', '==', cardId)
      .where('status', '==', 'active')
      .get();

    if (!existingListingQuery.empty) {
      throw new HttpsError('already-exists', 'Card already listed');
    }

    // Create listing ID
    const listingId = db.collection('dummy').doc().id;
    const now = Timestamp.now();
    const expiresAt = new Timestamp(now.seconds + CARD_LISTING_EXPIRY_DAYS * 24 * 3600, now.nanoseconds);

    // Get seller name (pseudo handle)
    const userRef = db.collection('users').doc(userId);
    const userDoc = await transaction.get(userRef);
    const sellerName = userDoc.exists && userDoc.data()?.displayName
      ? userDoc.data()?.displayName
      : `Player-${userId.substring(0, 6)}`;

    const listing: CardListing = {
      listingId,
      sellerId: userId,
      sellerName,
      cardId,
      attribute: cardData.attribute || 'joy',
      cost: cardData.cost || 1,
      cardName: cardData.cardName || { jp: '', en: '' },
      imageUrl: cardData.imageUrl || '',
      price,
      status: 'active',
      createdAt: now,
      expiresAt,
      views: 0,
    };

    // Write to user collection
    const userListingRef = db.collection('users').doc(userId).collection('marketplace/card_listings').doc(listingId);
    transaction.set(userListingRef, listing);

    // Write to global active listings collection (for browsing)
    const globalListingRef = db.collection('marketplace/active_card_listings').doc(listingId);
    transaction.set(globalListingRef, listing);

    return { listingId };
  });
});

/**
 * Buy a card from marketplace
 */
export const buyCard = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'User not authenticated');

  const buyerId = request.auth.uid;
  const { listingId } = request.data;

  if (!listingId || typeof listingId !== 'string') {
    throw new Error('Invalid listingId');
  }

  return await db.runTransaction(async (transaction) => {
    // Get listing
    const globalListingRef = db.collection('marketplace/active_card_listings').doc(listingId);
    const globalListingDoc = await transaction.get(globalListingRef);

    if (!globalListingDoc.exists) throw new HttpsError('not-found', 'Listing not found');

    const listing = globalListingDoc.data() as CardListing;

    // Validate
    if (listing.status !== 'active') throw new HttpsError('failed-precondition', 'Listing is not active');
    if (listing.sellerId === buyerId) throw new Error('Cannot buy your own card');

    // Check buyer has enough coins
    const buyerWalletRef = db.collection('users').doc(buyerId).collection('wallet').doc('balance');
    const buyerWalletDoc = await transaction.get(buyerWalletRef);
    if (!buyerWalletDoc.exists) throw new HttpsError('not-found', 'Buyer wallet not found');

    const buyerWallet = buyerWalletDoc.data()!;
    if ((buyerWallet.coinBalance || 0) < listing.price) {
      throw new HttpsError('failed-precondition', 'Insufficient coins');
    }

    // Get card from seller
    const cardRef = db.collection('users').doc(listing.sellerId).collection('cards').doc(listing.cardId);
    const cardDoc = await transaction.get(cardRef);
    if (!cardDoc.exists) throw new HttpsError('not-found', 'Card no longer exists');

    // Calculate fee
    const platformFee = Math.floor(listing.price * PLATFORM_FEE_PERCENT / 100);
    const sellerReceives = listing.price - platformFee;

    // Transfer card to buyer (create new copy for provenance)
    const buyerCardRef = db.collection('users').doc(buyerId).collection('cards').doc();
    const cardData = cardDoc.data()!;
    transaction.set(buyerCardRef, { ...cardData, id: buyerCardRef.id });

    // Update wallets
    transaction.update(buyerWalletRef, {
      coinBalance: (buyerWallet.coinBalance || 0) - listing.price,
    });

    const sellerWalletRef = db.collection('users').doc(listing.sellerId).collection('wallet').doc('balance');
    const sellerWalletDoc = await transaction.get(sellerWalletRef);
    if (sellerWalletDoc.exists) {
      const sellerWallet = sellerWalletDoc.data()!;
      transaction.update(sellerWalletRef, {
        coinBalance: (sellerWallet.coinBalance || 0) + sellerReceives,
      });
    }

    // Update listing status
    const now = Timestamp.now();
    const updatedListing = { ...listing, status: 'sold', soldAt: now, buyerId, buyerName: `Player-${buyerId.substring(0, 6)}` };
    transaction.update(globalListingRef, updatedListing);

    // Update user's listing
    const userListingRef = db.collection('users').doc(listing.sellerId).collection('marketplace/card_listings').doc(listingId);
    transaction.update(userListingRef, updatedListing);

    // Create transaction record for buyer
    const buyerTransactionId = db.collection('dummy').doc().id;
    const buyerTransaction: MarketplaceTransaction = {
      transactionId: buyerTransactionId,
      type: 'card_sale',
      playerId: buyerId,
      coinsDelta: -listing.price,
      gemsDelta: 0,
      transactionFeeCoins: 0,
      relatedListingId: listingId,
      counterpartyId: listing.sellerId,
      counterpartyName: listing.sellerName,
      createdAt: now,
      isSuccessful: true,
      metadata: { cardId: listing.cardId, listingPrice: listing.price },
    };
    transaction.set(db.collection('users').doc(buyerId).collection('marketplace/transactions').doc(buyerTransactionId), buyerTransaction);

    // Create transaction record for seller
    const sellerTransactionId = db.collection('dummy').doc().id;
    const sellerTransaction: MarketplaceTransaction = {
      transactionId: sellerTransactionId,
      type: 'card_sale',
      playerId: listing.sellerId,
      coinsDelta: sellerReceives,
      gemsDelta: 0,
      transactionFeeCoins: platformFee,
      relatedListingId: listingId,
      counterpartyId: buyerId,
      counterpartyName: `Player-${buyerId.substring(0, 6)}`,
      createdAt: now,
      isSuccessful: true,
      metadata: { cardId: listing.cardId, listingPrice: listing.price, platformFee },
    };
    transaction.set(db.collection('users').doc(listing.sellerId).collection('marketplace/transactions').doc(sellerTransactionId), sellerTransaction);

    return { success: true, newCardId: buyerCardRef.id };
  });
});

/**
 * Delist a card from marketplace
 */
export const delistCard = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'User not authenticated');

  const userId = request.auth.uid;
  const { listingId } = request.data;

  return await db.runTransaction(async (transaction) => {
    const userListingRef = db.collection('users').doc(userId).collection('marketplace/card_listings').doc(listingId);
    const userListingDoc = await transaction.get(userListingRef);

    if (!userListingDoc.exists) throw new HttpsError('not-found', 'Listing not found');

    const listing = userListingDoc.data() as CardListing;
    if (listing.status !== 'active') throw new HttpsError('failed-precondition', 'Only active listings can be delisted');

    // Update both collections
    const updatedListing = { ...listing, status: 'delisted' };
    transaction.update(userListingRef, updatedListing);

    const globalListingRef = db.collection('marketplace/active_card_listings').doc(listingId);
    transaction.update(globalListingRef, updatedListing);

    return { success: true };
  });
});

/**
 * Update price of a card listing
 */
export const updateCardListing = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'User not authenticated');

  const userId = request.auth.uid;
  const { listingId, newPrice } = request.data;

  if (!newPrice || typeof newPrice !== 'number') throw new Error('Invalid price');
  if (newPrice < CARD_LISTING_MIN_PRICE || newPrice > CARD_LISTING_MAX_PRICE) {
    throw new Error(`Price must be between ${CARD_LISTING_MIN_PRICE} and ${CARD_LISTING_MAX_PRICE}`);
  }

  return await db.runTransaction(async (transaction) => {
    const userListingRef = db.collection('users').doc(userId).collection('marketplace/card_listings').doc(listingId);
    const userListingDoc = await transaction.get(userListingRef);

    if (!userListingDoc.exists) throw new HttpsError('not-found', 'Listing not found');

    const listing = userListingDoc.data() as CardListing;
    if (listing.status !== 'active') throw new HttpsError('failed-precondition', 'Only active listings can be updated');

    transaction.update(userListingRef, { price: newPrice });

    const globalListingRef = db.collection('marketplace/active_card_listings').doc(listingId);
    transaction.update(globalListingRef, { price: newPrice });

    return { success: true };
  });
});

// ===== TRADE OFFERS (Phase 2) =====

interface TradeCard {
  cardId: string;
  attribute: string;
  cost: number;
  cardName: Record<string, string>;
  imageUrl: string;
}

interface TradeOffer {
  offerId: string;
  senderId: string;
  senderName: string;
  recipientId: string;
  recipientName: string;
  senderCardIds: string[];
  recipientCardIds: string[];
  status: 'pending' | 'accepted' | 'rejected' | 'expired' | 'cancelled';
  createdAt: Timestamp;
  respondedAt?: Timestamp;
  expiresAt: Timestamp;
  message?: string;
  senderCards: TradeCard[];
  recipientCards: TradeCard[];
}

/**
 * Create a trade offer between two players
 * No fees for P2P trades
 */
export const createTradeOffer = onCall(async (request) => {
  if (!request.auth) throw new Error('Not authenticated');

  const userId = request.auth.uid;
  const { recipientId, senderCardIds, recipientCardIds, message } = request.data;

  // Validation
  if (!recipientId || !Array.isArray(senderCardIds) || !Array.isArray(recipientCardIds)) {
    throw new Error('Invalid trade offer data');
  }

  if (senderCardIds.length === 0 || recipientCardIds.length === 0) {
    throw new Error('Trade must include at least one card per side');
  }

  if (senderCardIds.length > TRADE_OFFER_MAX_CARDS_PER_SIDE || recipientCardIds.length > TRADE_OFFER_MAX_CARDS_PER_SIDE) {
    throw new Error(`Maximum ${TRADE_OFFER_MAX_CARDS_PER_SIDE} cards per side`);
  }

  if (userId === recipientId) {
    throw new Error('Cannot trade with yourself');
  }

  return db.runTransaction(async (transaction) => {
    // Verify sender owns all sender cards
    const senderCardPromises = senderCardIds.map((cardId) =>
      db.collection('users').doc(userId).collection('cards').doc(cardId).get()
    );
    const senderCardDocs = await Promise.all(senderCardPromises);

    for (const doc of senderCardDocs) {
      if (!doc.exists) throw new Error('Sender card not found or not owned');
    }

    // Verify recipient owns all recipient cards
    const recipientCardPromises = recipientCardIds.map((cardId) =>
      db.collection('users').doc(recipientId).collection('cards').doc(cardId).get()
    );
    const recipientCardDocs = await Promise.all(recipientCardPromises);

    for (const doc of recipientCardDocs) {
      if (!doc.exists) throw new Error('Recipient card not found or not owned');
    }

    // Get user names
    const senderDoc = await transaction.get(db.collection('users').doc(userId));
    const recipientDoc = await transaction.get(db.collection('users').doc(recipientId));

    const senderName = senderDoc.data()?.displayName || 'Unknown';
    const recipientName = recipientDoc.data()?.displayName || 'Unknown';

    // Extract card details for caching
    const senderCards: TradeCard[] = senderCardDocs.map((doc) => {
      const data = doc.data() as any;
      return {
        cardId: doc.id,
        attribute: data.attribute || '',
        cost: data.cost || 0,
        cardName: data.cardName || {},
        imageUrl: data.imageUrl || '',
      };
    });

    const recipientCards: TradeCard[] = recipientCardDocs.map((doc) => {
      const data = doc.data() as any;
      return {
        cardId: doc.id,
        attribute: data.attribute || '',
        cost: data.cost || 0,
        cardName: data.cardName || {},
        imageUrl: data.imageUrl || '',
      };
    });

    // Create trade offer
    const offerId = db.collection('trade_offers').doc().id;
    const now = Timestamp.now();
    const expiresAt = new Timestamp(
      now.seconds + TRADE_OFFER_EXPIRY_DAYS * 24 * 3600,
      now.nanoseconds
    );

    const tradeOffer: TradeOffer = {
      offerId,
      senderId: userId,
      senderName,
      recipientId,
      recipientName,
      senderCardIds,
      recipientCardIds,
      status: 'pending',
      createdAt: now,
      expiresAt,
      message: message || undefined,
      senderCards,
      recipientCards,
    };

    // Save to sender's collection
    transaction.set(db.collection('users').doc(userId).collection('marketplace/trade_offers').doc(offerId), tradeOffer);

    // Save to recipient's collection (for visibility)
    transaction.set(db.collection('users').doc(recipientId).collection('marketplace/trade_offers').doc(offerId), tradeOffer);

    // Save to global collection
    transaction.set(db.collection('marketplace/trade_offers').doc(offerId), tradeOffer);

    return { offerId, success: true };
  });
});

/**
 * Respond to a trade offer (accept or reject)
 */
export const respondToTradeOffer = onCall(async (request) => {
  if (!request.auth) throw new Error('Not authenticated');

  const userId = request.auth.uid;
  const { offerId, action } = request.data;

  if (!offerId || !['accept', 'reject'].includes(action)) {
    throw new Error('Invalid response data');
  }

  return db.runTransaction(async (transaction) => {
    const offerRef = db.collection('marketplace/trade_offers').doc(offerId);
    const offerDoc = await transaction.get(offerRef);

    if (!offerDoc.exists) throw new Error('Trade offer not found');

    const offer = offerDoc.data() as TradeOffer;

    if (offer.status !== 'pending') {
      throw new Error('Trade offer is no longer pending');
    }

    if (userId !== offer.recipientId) {
      throw new Error('Only the recipient can respond');
    }

    const now = Timestamp.now();
    if (now.seconds > offer.expiresAt.seconds) {
      throw new Error('Trade offer has expired');
    }

    if (action === 'reject') {
      // Simply update status to rejected
      const rejectedAt = Timestamp.now();
      transaction.update(offerRef, {
        status: 'rejected',
        respondedAt: rejectedAt,
      });

      // Update in both user collections
      transaction.update(
        db.collection('users').doc(offer.senderId).collection('marketplace/trade_offers').doc(offerId),
        { status: 'rejected', respondedAt: rejectedAt }
      );
      transaction.update(
        db.collection('users').doc(offer.recipientId).collection('marketplace/trade_offers').doc(offerId),
        { status: 'rejected', respondedAt: rejectedAt }
      );

      return { success: true, message: 'Trade rejected' };
    }

    // Accept: perform the card swap
    // Verify cards still exist (final check)
    for (const cardId of offer.senderCardIds) {
      const cardRef = db.collection('users').doc(offer.senderId).collection('cards').doc(cardId);
      const cardDoc = await transaction.get(cardRef);
      if (!cardDoc.exists) throw new Error('Sender card no longer exists');
    }

    for (const cardId of offer.recipientCardIds) {
      const cardRef = db.collection('users').doc(offer.recipientId).collection('cards').doc(cardId);
      const cardDoc = await transaction.get(cardRef);
      if (!cardDoc.exists) throw new Error('Recipient card no longer exists');
    }

    // Transfer sender cards to recipient
    for (const cardId of offer.senderCardIds) {
      const sourceRef = db.collection('users').doc(offer.senderId).collection('cards').doc(cardId);
      const destRef = db.collection('users').doc(offer.recipientId).collection('cards').doc(cardId);
      const cardData = await transaction.get(sourceRef);
      transaction.set(destRef, cardData.data());
      transaction.delete(sourceRef);
    }

    // Transfer recipient cards to sender
    for (const cardId of offer.recipientCardIds) {
      const sourceRef = db.collection('users').doc(offer.recipientId).collection('cards').doc(cardId);
      const destRef = db.collection('users').doc(offer.senderId).collection('cards').doc(cardId);
      const cardData = await transaction.get(sourceRef);
      transaction.set(destRef, cardData.data());
      transaction.delete(sourceRef);
    }

    // Update trade offer status
    transaction.update(offerRef, {
      status: 'accepted',
      respondedAt: now,
    });

    // Update in both user collections
    transaction.update(
      db.collection('users').doc(offer.senderId).collection('marketplace/trade_offers').doc(offerId),
      { status: 'accepted', respondedAt: now }
    );
    transaction.update(
      db.collection('users').doc(offer.recipientId).collection('marketplace/trade_offers').doc(offerId),
      { status: 'accepted', respondedAt: now }
    );

    // Create transaction records for both players (0% fee)
    const transactionId1 = db.collection('transactions').doc().id;
    const senderTransaction: MarketplaceTransaction = {
      transactionId: transactionId1,
      type: 'trade_accepted',
      playerId: offer.senderId,
      coinsDelta: 0,
      gemsDelta: 0,
      transactionFeeCoins: 0,
      relatedListingId: offerId,
      counterpartyId: offer.recipientId,
      counterpartyName: offer.recipientName,
      createdAt: now,
      isSuccessful: true,
      metadata: {
        cardsGiven: offer.senderCardIds.length,
        cardsReceived: offer.recipientCardIds.length,
      },
    };

    const transactionId2 = db.collection('transactions').doc().id;
    const recipientTransaction: MarketplaceTransaction = {
      transactionId: transactionId2,
      type: 'trade_accepted',
      playerId: offer.recipientId,
      coinsDelta: 0,
      gemsDelta: 0,
      transactionFeeCoins: 0,
      relatedListingId: offerId,
      counterpartyId: offer.senderId,
      counterpartyName: offer.senderName,
      createdAt: now,
      isSuccessful: true,
      metadata: {
        cardsGiven: offer.recipientCardIds.length,
        cardsReceived: offer.senderCardIds.length,
      },
    };

    transaction.set(
      db.collection('users').doc(offer.senderId).collection('marketplace/transactions').doc(transactionId1),
      senderTransaction
    );
    transaction.set(
      db.collection('users').doc(offer.recipientId).collection('marketplace/transactions').doc(transactionId2),
      recipientTransaction
    );

    return { success: true, message: 'Trade completed!' };
  });
});

/**
 * Cancel a trade offer (only sender can cancel pending offers)
 */
export const cancelTradeOffer = onCall(async (request) => {
  if (!request.auth) throw new Error('Not authenticated');

  const userId = request.auth.uid;
  const { offerId } = request.data;

  if (!offerId) throw new Error('Invalid offerId');

  return db.runTransaction(async (transaction) => {
    const offerRef = db.collection('marketplace/trade_offers').doc(offerId);
    const offerDoc = await transaction.get(offerRef);

    if (!offerDoc.exists) throw new Error('Trade offer not found');

    const offer = offerDoc.data() as TradeOffer;

    if (offer.senderId !== userId) {
      throw new Error('Only the sender can cancel');
    }

    if (offer.status !== 'pending') {
      throw new Error('Can only cancel pending offers');
    }

    // Update status to cancelled
    transaction.update(offerRef, {
      status: 'cancelled',
      respondedAt: Timestamp.now(),
    });

    // Update in both user collections
    transaction.update(
      db.collection('users').doc(offer.senderId).collection('marketplace/trade_offers').doc(offerId),
      { status: 'cancelled', respondedAt: Timestamp.now() }
    );
    transaction.update(
      db.collection('users').doc(offer.recipientId).collection('marketplace/trade_offers').doc(offerId),
      { status: 'cancelled', respondedAt: Timestamp.now() }
    );

    return { success: true, message: 'Trade offer cancelled' };
  });
});

// ===== CURRENCY EXCHANGE (Phase 3) =====

interface CurrencyListing {
  listingId: string;
  playerId: string;
  playerName: string;
  type: 'buy_gems' | 'sell_gems';
  amount: number;
  price: number;
  status: 'active' | 'partial' | 'closed';
  createdAt: Timestamp;
  expiresAt: Timestamp;
}

/**
 * Fill a currency exchange listing (buy/sell gems)
 * Supports partial fills
 */
export const fillCurrencyListing = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'User not authenticated');

  const buyerId = request.auth.uid;
  const { listingId, amount } = request.data;

  if (!listingId || typeof listingId !== 'string') {
    throw new Error('Invalid listingId');
  }

  if (!amount || typeof amount !== 'number' || amount <= 0) {
    throw new Error('Invalid amount');
  }

  return await db.runTransaction(async (transaction) => {
    // Get the listing from global collection
    const globalListingRef = db.collection('marketplace/currency_listings').doc(listingId);
    const globalListingDoc = await transaction.get(globalListingRef);

    if (!globalListingDoc.exists) {
      throw new HttpsError('not-found', 'Listing not found');
    }

    const listing = globalListingDoc.data() as CurrencyListing;

    // Validate listing status
    if (listing.status !== 'active' && listing.status !== 'partial') {
      throw new HttpsError('failed-precondition', 'Listing is not available');
    }

    // Check expiry
    const now = Timestamp.now();
    if (now.seconds > listing.expiresAt.seconds) {
      throw new HttpsError('failed-precondition', 'Listing has expired');
    }

    // Validate amount requested doesn't exceed available
    if (amount > listing.amount) {
      throw new Error(`Only ${listing.amount} available`);
    }

    // Cannot buy from yourself
    if (listing.playerId === buyerId) {
      throw new Error('Cannot buy from yourself');
    }

    // Get buyer wallet
    const buyerRef = db.collection('users').doc(buyerId);
    const buyerDoc = await transaction.get(buyerRef);

    if (!buyerDoc.exists) {
      throw new HttpsError('not-found', 'Buyer profile not found');
    }

    const buyerData = buyerDoc.data();
    const buyerCoins = buyerData?.coins || 0;
    const buyerGems = buyerData?.gems || 0;

    // Get seller wallet
    const sellerRef = db.collection('users').doc(listing.playerId);
    const sellerDoc = await transaction.get(sellerRef);

    if (!sellerDoc.exists) {
      throw new HttpsError('not-found', 'Seller profile not found');
    }

    const sellerData = sellerDoc.data();
    const sellerCoins = sellerData?.coins || 0;
    const sellerGems = sellerData?.gems || 0;

    // Calculate total cost/receive
    const totalCost = amount * listing.price;

    // Validate funds based on listing type
    if (listing.type === 'sell_gems') {
      // Buyer is paying coins to get gems
      if (buyerCoins < totalCost) {
        throw new HttpsError('failed-precondition', 'Insufficient coins');
      }
      if (sellerGems < amount) {
        throw new HttpsError('failed-precondition', 'Seller no longer has enough gems');
      }

      // Transfer coins and gems
      transaction.update(buyerRef, {
        coins: buyerCoins - totalCost,
        gems: buyerGems + amount,
      });

      transaction.update(sellerRef, {
        coins: sellerCoins + totalCost,
        gems: sellerGems - amount,
      });
    } else {
      // Buyer is paying gems to get coins (buy_gems listing means seller is buying gems from you)
      if (buyerGems < amount) {
        throw new HttpsError('failed-precondition', 'Insufficient gems');
      }
      if (sellerCoins < totalCost) {
        throw new HttpsError('failed-precondition', 'Seller no longer has enough coins');
      }

      // Transfer gems and coins
      transaction.update(buyerRef, {
        gems: buyerGems - amount,
        coins: buyerCoins + totalCost,
      });

      transaction.update(sellerRef, {
        coins: sellerCoins - totalCost,
        gems: sellerGems + amount,
      });
    }

    // Update listing
    const remainingAmount = listing.amount - amount;
    const newStatus = remainingAmount === 0 ? 'closed' : 'partial';

    transaction.update(globalListingRef, {
      amount: remainingAmount,
      status: newStatus,
    });

    // Also update in seller's user collection
    transaction.update(
      db.collection('users').doc(listing.playerId).collection('marketplace/currency_listings').doc(listingId),
      {
        amount: remainingAmount,
        status: newStatus,
      }
    );

    // Create transaction records (0% fee for currency exchange)
    const transactionId1 = db.collection('transactions').doc().id;
    const buyerTransaction: MarketplaceTransaction = {
      transactionId: transactionId1,
      type: 'currency_exchange',
      playerId: buyerId,
      coinsDelta: listing.type === 'sell_gems' ? -totalCost : totalCost,
      gemsDelta: listing.type === 'sell_gems' ? amount : -amount,
      transactionFeeCoins: 0,
      relatedListingId: listingId,
      counterpartyId: listing.playerId,
      counterpartyName: listing.playerName,
      createdAt: now,
      isSuccessful: true,
      metadata: {
        listingType: listing.type,
        amount: amount,
        pricePerUnit: listing.price,
      },
    };

    const transactionId2 = db.collection('transactions').doc().id;
    const sellerTransaction: MarketplaceTransaction = {
      transactionId: transactionId2,
      type: 'currency_exchange',
      playerId: listing.playerId,
      coinsDelta: listing.type === 'sell_gems' ? totalCost : -totalCost,
      gemsDelta: listing.type === 'sell_gems' ? -amount : amount,
      transactionFeeCoins: 0,
      relatedListingId: listingId,
      counterpartyId: buyerId,
      counterpartyName: buyerData?.displayName || 'Unknown',
      createdAt: now,
      isSuccessful: true,
      metadata: {
        listingType: listing.type,
        amount: amount,
        pricePerUnit: listing.price,
      },
    };

    transaction.set(
      db.collection('users').doc(buyerId).collection('marketplace/transactions').doc(transactionId1),
      buyerTransaction
    );
    transaction.set(
      db.collection('users').doc(listing.playerId).collection('marketplace/transactions').doc(transactionId2),
      sellerTransaction
    );

    return { success: true, message: 'Exchange completed!' };
  });
});

// ===== CLEANUP JOBS =====

/**
 * Scheduled job to expire old listings (runs daily)
 */
export const expireListings = onSchedule('every day 02:00', async () => {
  const now = Timestamp.now();
  const expiryThreshold = new Timestamp(now.seconds - 24 * 3600, now.nanoseconds);

  // Expire active card listings
  const expiredCardListings = await db
    .collectionGroup('card_listings')
    .where('status', '==', 'active')
    .where('createdAt', '<', expiryThreshold)
    .get();

  for (const doc of expiredCardListings.docs) {
    await db.runTransaction(async (transaction) => {
      transaction.update(doc.ref, { status: 'delisted' });

      const listingData = doc.data() as CardListing;
      const globalRef = db.collection('marketplace/active_card_listings').doc(listingData.listingId);
      transaction.update(globalRef, { status: 'delisted' });
    });
  }

  // Note: Trade offers and currency listings will auto-expire via client-side checks
  // Could add similar cleanup here if desired

  console.log(`Expired ${expiredCardListings.docs.length} card listings`);
});
