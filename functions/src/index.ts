import * as admin from "firebase-admin";

admin.initializeApp();

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
export {getPeriodLeaderboard} from "./manageLeaderboard";
export {createCard, levelUpCard} from "./manageCards";
