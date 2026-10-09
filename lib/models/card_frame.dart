import '../providers/game_state_provider.dart' show WalletState;

/// カードフレームの通貨種別
enum FrameCurrency { coin, gem }

/// 枠画像の開口部（カード本体を収める矩形）。画像全体に対する比率(0〜1)。
class FrameHole {
  final double left, top, right, bottom;
  const FrameHole(this.left, this.top, this.right, this.bottom);
  double get width => right - left;
  double get height => bottom - top;
}

enum FrameRarity { common, rare, epic }

/// コインまたはジェムで買えるカードフレーム。価格はどちらか一方のみ。
class CardFrame {
  final String id;
  final String nameJa;
  final String nameEn;
  final int? priceCoins;
  final int? priceGems;
  final FrameRarity rarity;
  final String assetPath;
  final FrameHole holeNorm;

  const CardFrame({
    required this.id,
    required this.nameJa,
    required this.nameEn,
    this.priceCoins,
    this.priceGems,
    required this.rarity,
    required this.assetPath,
    required this.holeNorm,
  });

  FrameCurrency get currency => priceCoins != null ? FrameCurrency.coin : FrameCurrency.gem;
  int get price => priceCoins ?? priceGems ?? 0;
  String nameOf(String languageCode) => languageCode == 'en' ? nameEn : nameJa;
}

// 価格はコイン(初期100・連勝/PvPボーナス1日上限15)とジェム(初期0・スターター5・
// 連勝シールド3/上限拡張5)の入手ペースに合わせた設定。
const List<CardFrame> kCardFrames = [
  CardFrame(id: 'coin_iron', nameJa: '鉄のフレーム', nameEn: 'Iron Frame', priceCoins: 300, rarity: FrameRarity.common,
      assetPath: 'assets/frames/frame_coin_iron.png', holeNorm: FrameHole(0.217, 0.171, 0.783, 0.829)),
  CardFrame(id: 'coin_silver', nameJa: '銀のフレーム', nameEn: 'Silver Frame', priceCoins: 400, rarity: FrameRarity.common,
      assetPath: 'assets/frames/frame_coin_silver.png', holeNorm: FrameHole(0.109, 0.079, 0.891, 0.921)),
  CardFrame(id: 'coin_bronze', nameJa: '銅のフレーム', nameEn: 'Bronze Frame', priceCoins: 500, rarity: FrameRarity.common,
      assetPath: 'assets/frames/frame_coin_bronze.png', holeNorm: FrameHole(0.12, 0.093, 0.88, 0.907)),
  CardFrame(id: 'coin_wood', nameJa: '木のフレーム', nameEn: 'Wooden Frame', priceCoins: 600, rarity: FrameRarity.common,
      assetPath: 'assets/frames/frame_coin_wood.png', holeNorm: FrameHole(0.141, 0.093, 0.859, 0.907)),
  CardFrame(id: 'coin_copper', nameJa: '赤銅のフレーム', nameEn: 'Copper Frame', priceCoins: 700, rarity: FrameRarity.rare,
      assetPath: 'assets/frames/frame_coin_copper.png', holeNorm: FrameHole(0.141, 0.15, 0.859, 0.85)),
  CardFrame(id: 'gem_gold', nameJa: '黄金のフレーム', nameEn: 'Golden Frame', priceGems: 30, rarity: FrameRarity.rare,
      assetPath: 'assets/frames/frame_gem_gold.png', holeNorm: FrameHole(0.196, 0.157, 0.804, 0.843)),
  CardFrame(id: 'gem_rainbow', nameJa: '虹のフレーム', nameEn: 'Rainbow Frame', priceGems: 40, rarity: FrameRarity.epic,
      assetPath: 'assets/frames/frame_gem_rainbow.png', holeNorm: FrameHole(0.163, 0.157, 0.837, 0.843)),
  CardFrame(id: 'gem_flame', nameJa: '炎のフレーム', nameEn: 'Flame Frame', priceGems: 50, rarity: FrameRarity.epic,
      assetPath: 'assets/frames/frame_gem_flame.png', holeNorm: FrameHole(0.228, 0.143, 0.772, 0.857)),
  CardFrame(id: 'gem_ice', nameJa: '氷のフレーム', nameEn: 'Ice Frame', priceGems: 50, rarity: FrameRarity.epic,
      assetPath: 'assets/frames/frame_gem_ice.png', holeNorm: FrameHole(0.239, 0.164, 0.761, 0.836)),
  CardFrame(id: 'gem_emerald', nameJa: 'エメラルドのフレーム', nameEn: 'Emerald Frame', priceGems: 60, rarity: FrameRarity.epic,
      assetPath: 'assets/frames/frame_gem_emerald.png', holeNorm: FrameHole(0.163, 0.2, 0.837, 0.8)),
];

CardFrame? cardFrameById(String? id) {
  if (id == null) return null;
  for (final f in kCardFrames) {
    if (f.id == id) return f;
  }
  return null;
}

/// 所持フレームと装着中フレーム
class FrameInventory {
  final List<String> ownedIds;
  final String? equippedId;
  const FrameInventory({this.ownedIds = const [], this.equippedId});

  bool owns(String id) => ownedIds.contains(id);

  /// 所持していて存在するフレームのみ有効（不正な値は無視）
  String? get validEquippedId =>
      equippedId != null && owns(equippedId!) && cardFrameById(equippedId) != null ? equippedId : null;

  Map<String, dynamic> toMap() => {'ownedIds': ownedIds, 'equippedId': equippedId};

  factory FrameInventory.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const FrameInventory();
    final raw = map['ownedIds'];
    final owned = raw is List ? raw.whereType<String>().toSet().toList() : <String>[];
    final eq = map['equippedId'];
    return FrameInventory(ownedIds: owned, equippedId: eq is String ? eq : null);
  }
}

enum FramePurchaseStatus { success, unknownFrame, alreadyOwned, insufficientFunds }

class FramePurchaseResult {
  final FramePurchaseStatus status;
  final WalletState wallet;
  final FrameInventory inventory;
  const FramePurchaseResult(this.status, this.wallet, this.inventory);
  bool get ok => status == FramePurchaseStatus.success;
}

/// 購入の純関数。成功時は残高を差し引き、所持に追加する（自動では装着しない）。
FramePurchaseResult purchaseFrameLogic(WalletState wallet, FrameInventory inv, String frameId) {
  final frame = cardFrameById(frameId);
  if (frame == null) return FramePurchaseResult(FramePurchaseStatus.unknownFrame, wallet, inv);
  if (inv.owns(frameId)) return FramePurchaseResult(FramePurchaseStatus.alreadyOwned, wallet, inv);
  final balance = frame.currency == FrameCurrency.coin ? wallet.coinBalance : wallet.gemBalance;
  if (balance < frame.price) return FramePurchaseResult(FramePurchaseStatus.insufficientFunds, wallet, inv);
  final newWallet = frame.currency == FrameCurrency.coin
      ? wallet.copyWith(coinBalance: wallet.coinBalance - frame.price)
      : wallet.copyWith(gemBalance: wallet.gemBalance - frame.price);
  return FramePurchaseResult(
    FramePurchaseStatus.success,
    newWallet,
    FrameInventory(ownedIds: [...inv.ownedIds, frameId], equippedId: inv.equippedId),
  );
}

/// 装着。未所持/存在しないIDは変更しない。
FrameInventory equipFrameLogic(FrameInventory inv, String frameId) =>
    inv.owns(frameId) && cardFrameById(frameId) != null
        ? FrameInventory(ownedIds: inv.ownedIds, equippedId: frameId)
        : inv;

FrameInventory unequipFrameLogic(FrameInventory inv) => FrameInventory(ownedIds: inv.ownedIds);
