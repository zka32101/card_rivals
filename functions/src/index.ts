import * as admin from "firebase-admin";
import {setGlobalOptions} from "firebase-functions/v2";

admin.initializeApp();

// コスト暴走防止の上限。関数ごとの maxInstances 指定があればそちらが優先される。
// minInstances は課金増になるため設定しない。
setGlobalOptions({maxInstances: 10});

export {generateCardImage} from "./generateCardImage";
export {generateCardName} from "./generateCardName";
export {pvpMatch} from "./pvpMatch";
export {pvpBattle} from "./pvpBattle";
export {rentCard} from "./rentCard";
export {
  generateDailyEmotionCardName,
  generateDailyEmotionCardImage,
  onDailyEmotionCardCreated,
} from "./dailyEmotionCard";
export {
  sendFriendRequest,
  acceptFriendRequest,
  rejectFriendRequest,
  removeFriend,
  updateFriendMetadata,
  updateFriendCachedData,
} from "./manageFriends";
export {
  saveDeckPreset,
  deleteDeckPreset,
  copyDeckPreset,
} from "./manageDeckPresets";
export {
  progressChallenge,
  claimChallengeReward,
  getUserEventProgress,
} from "./manageEventChallenges";
export {
  createCardListing,
  buyCard,
  delistCard,
  updateCardListing,
  expireListings,
  createTradeOffer,
  respondToTradeOffer,
  cancelTradeOffer,
  fillCurrencyListing,
} from "./marketplace";
export {claimSeasonReward, getSeasonLeaderboard} from "./manageSeasons";
export {ensureSeasons} from "./ensureSeasons";
export {getPeriodLeaderboard} from "./manageLeaderboard";
export {createCard, levelUpCard} from "./manageCards";
