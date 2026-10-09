import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/game_state_provider.dart';
import '../providers/vip_provider.dart';
import '../services/purchase_service.dart';
import '../theme/kingdom_theme.dart';
import '../utils/safe_pop.dart';
import '../l10n/app_localizations.dart';
import '../widgets/frame_shop_section.dart';
import '../widgets/ui_icon.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  // 購入処理中のパッケージID（多重タップ防止・ボタンにローディング表示するため）
  String? _processingPackageId;

  // ストアが返す実際の価格（取得できたものだけ）。画面の固定文字より優先して表示する。
  Map<String, String> _storePrices = {};

  @override
  void initState() {
    super.initState();
    PurchaseService.fetchStorePrices().then((prices) {
      if (mounted) setState(() => _storePrices = prices);
    });
  }

  Future<void> _buy(CurrencyPackageDef pkg) async {
    if (_processingPackageId != null) return;
    setState(() => _processingPackageId = pkg.packageId);

    final result = await PurchaseService.purchaseCurrencyPackage(pkg.packageId);
    if (!mounted) return;
    setState(() => _processingPackageId = null);

    final t = AppLocalizations.of(context)!;
    switch (result) {
      case PurchaseResult.success:
        final synced = await _grantCurrency(pkg);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: IconText(t.shop_receivedPackage(pkg.labelOf(t)))),
        );
        if (!synced) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: IconText(t.shop_purchaseSyncFailed), backgroundColor: Kingdom.angerCrimson),
          );
        }
      case PurchaseResult.cancelled:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: IconText(t.shop_purchaseCancelled)),
        );
      case PurchaseResult.noProduct:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: IconText(t.shop_productComingSoon)),
        );
      case PurchaseResult.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: IconText(_purchaseErrorText(t)), backgroundColor: Colors.red),
        );
    }
  }

  bool _isBuyingStarterPack = false;
  bool _isBuyingVip = false;

  Future<void> _buyStarterPack() async {
    if (_isBuyingStarterPack) return;
    setState(() => _isBuyingStarterPack = true);
    final result = await PurchaseService.purchaseStarterPack();
    if (!mounted) return;
    setState(() => _isBuyingStarterPack = false);

    final t = AppLocalizations.of(context)!;
    switch (result) {
      case PurchaseResult.success:
        final wallet = ref.read(walletProvider);
        final updated = wallet.copyWith(
          coinBalance: wallet.coinBalance + kStarterPackCoins,
          gemBalance: wallet.gemBalance + kStarterPackGems,
        );
        ref.read(walletProvider.notifier).state = updated;
        final userId = ref.read(currentUserIdProvider);
        final synced = userId != null ? await updateWallet(userId, updated) : false;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: IconText(t.shop_receivedPackage(t.shop_purchaseHistoryStarterPack))),
        );
        if (!synced) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: IconText(t.shop_purchaseSyncFailed), backgroundColor: Kingdom.angerCrimson),
          );
        }
      case PurchaseResult.cancelled:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: IconText(t.shop_purchaseCancelled)));
      case PurchaseResult.noProduct:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: IconText(t.shop_productComingSoon)));
      case PurchaseResult.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: IconText(_purchaseErrorText(t)), backgroundColor: Colors.red),
        );
    }
  }

  Future<void> _buyVipPass({bool yearly = false}) async {
    if (_isBuyingVip) return;
    setState(() => _isBuyingVip = true);
    final result = await PurchaseService.purchaseVipPass(yearly: yearly);
    if (!mounted) return;
    setState(() => _isBuyingVip = false);
    // サブスクリプションはEntitlement経由で有効判定するため、購入直後にプロバイダを再取得する
    ref.invalidate(vipStatusProvider);

    final t = AppLocalizations.of(context)!;
    switch (result) {
      case PurchaseResult.success:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: IconText(t.shop_vipWelcome)));
      case PurchaseResult.cancelled:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: IconText(t.shop_purchaseCancelled)));
      case PurchaseResult.noProduct:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: IconText(t.shop_productComingSoon)));
      case PurchaseResult.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: IconText(_purchaseErrorText(t)), backgroundColor: Colors.red),
        );
    }
  }

  // 戻り値: Firestoreへの永続化に成功したか（false ならUI側で警告を出す）
  Future<bool> _grantCurrency(CurrencyPackageDef pkg) async {
    final wallet = ref.read(walletProvider);
    final updated = pkg.isGem
        ? wallet.copyWith(gemBalance: wallet.gemBalance + pkg.amount)
        : wallet.copyWith(coinBalance: wallet.coinBalance + pkg.amount);
    ref.read(walletProvider.notifier).state = updated;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;
    return updateWallet(userId, updated);
  }

  void _buyStreakShield() {
    final t = AppLocalizations.of(context)!;
    final wallet = ref.read(walletProvider);
    if (wallet.gemBalance < kStreakShieldGemCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: IconText(t.shop_insufficientGems), backgroundColor: Kingdom.angerCrimson),
      );
      return;
    }
    final updated = wallet.buyStreakShield();
    ref.read(walletProvider.notifier).state = updated;
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) updateWallet(userId, updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: IconText(t.shop_exchangeSuccess)),
    );
  }

  void _extendDailyBonusCap() {
    final t = AppLocalizations.of(context)!;
    final wallet = ref.read(walletProvider);
    if (wallet.dailyBonusCapExtensionsUsedToday >= kDailyBonusCapExtensionMaxPerDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: IconText(t.shop_dailyBonusCapExtMaxReached), backgroundColor: Kingdom.angerCrimson),
      );
      return;
    }
    if (wallet.gemBalance < kDailyBonusCapExtensionGemCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: IconText(t.shop_insufficientGems), backgroundColor: Kingdom.angerCrimson),
      );
      return;
    }
    final updated = wallet.extendDailyBonusCap();
    ref.read(walletProvider.notifier).state = updated;
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) updateWallet(userId, updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: IconText(t.shop_exchangeSuccess)),
    );
  }

  // 購入失敗時は、原因の切り分けができるようエラーコードを併記する
  String _purchaseErrorText(AppLocalizations t) {
    final detail = PurchaseService.lastErrorDetail;
    return detail == null ? t.shop_purchaseError : t.shop_purchaseErrorWithDetail(detail);
  }

  Future<void> _restore() async {
    final ok = await PurchaseService.restorePurchases();
    if (!mounted) return;
    // 復元したEntitlementをVIP表示へ反映する
    ref.invalidate(vipStatusProvider);
    final t = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? t.shop_restoreSuccess : t.shop_restoreNotFound)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final t = AppLocalizations.of(context)!;
    final vipAsync = ref.watch(vipStatusProvider);
    final isVip = vipAsync.value ?? false;

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: IconText(t.shop_title, style: Kingdom.title(size: 17)),
        backgroundColor: Kingdom.nightDeep,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Kingdom.gilt),
          onPressed: () => context.popOrHome(),
        ),
        actions: [
          TextButton(
            onPressed: _restore,
            child: IconText(t.shop_restorePurchases, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.7))),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 10)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(Kingdom.spaceLg),
              children: [
                // 現在の残高表示
                OrnateFrame(
                  accent: Kingdom.gilt,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _BalanceDisplay(emoji: '🪙', label: t.shop_coinLabel, value: wallet.coinBalance),
                      Container(width: 1, height: 40, color: Kingdom.parchment.withValues(alpha: 0.15)),
                      _BalanceDisplay(emoji: '💎', label: t.shop_gemLabel, value: wallet.gemBalance),
                    ],
                  ),
                ),
                const SizedBox(height: Kingdom.spaceXxl),

                // VIPパス
                IconText(t.shop_vipHeader, style: Kingdom.label(size: 15, color: Kingdom.gilt)),
                const SizedBox(height: Kingdom.spaceMd),
                _VipPassTile(
                  isVip: isVip,
                  monthlyPrice: _storePrices['vip_monthly'],
                  yearlyPrice: _storePrices['vip_annual'],
                  isProcessing: _isBuyingVip,
                  onTapMonthly: () => _buyVipPass(),
                  onTapYearly: () => _buyVipPass(yearly: true),
                ),
                const SizedBox(height: Kingdom.spaceXl),

                // スターターパック
                IconText(t.shop_starterPackHeader, style: Kingdom.label(size: 15, color: Kingdom.gilt)),
                const SizedBox(height: Kingdom.spaceMd),
                _StarterPackTile(
                  price: _storePrices['starter'],
                  isProcessing: _isBuyingStarterPack,
                  onTap: _buyStarterPack,
                ),
                const SizedBox(height: Kingdom.spaceXl),

                IconText(t.shop_coinPackagesHeader, style: Kingdom.label(size: 15, color: Kingdom.gilt)),
                const SizedBox(height: Kingdom.spaceMd),
                for (final pkg in kCoinPackages) ...[
                  _PackageTile(
                    pkg: pkg,
                    price: _storePrices[pkg.packageId],
                    accent: Kingdom.gilt,
                    isProcessing: _processingPackageId == pkg.packageId,
                    onTap: () => _buy(pkg),
                  ),
                  const SizedBox(height: Kingdom.spaceMd),
                ],
                const SizedBox(height: Kingdom.spaceLg),

                IconText(t.shop_gemPackagesHeader, style: Kingdom.label(size: 15, color: Kingdom.sadnessIndigo)),
                const SizedBox(height: Kingdom.spaceMd),
                for (final pkg in kGemPackages) ...[
                  _PackageTile(
                    pkg: pkg,
                    price: _storePrices[pkg.packageId],
                    accent: Kingdom.sadnessIndigo,
                    isProcessing: _processingPackageId == pkg.packageId,
                    onTap: () => _buy(pkg),
                  ),
                  const SizedBox(height: Kingdom.spaceMd),
                ],
                const SizedBox(height: Kingdom.spaceLg),

                IconText(t.shop_gemExchangeHeader, style: Kingdom.label(size: 15, color: Kingdom.sadnessIndigo)),
                const SizedBox(height: Kingdom.spaceMd),
                _ExchangeTile(
                  emoji: '🛡️',
                  label: t.shop_streakShieldLabel(wallet.streakShieldCount),
                  description: t.shop_streakShieldDesc,
                  costLabel: '💎$kStreakShieldGemCost',
                  accent: Kingdom.sadnessIndigo,
                  onTap: _buyStreakShield,
                ),
                const SizedBox(height: Kingdom.spaceMd),
                _ExchangeTile(
                  emoji: '⏫',
                  label: t.shop_dailyBonusCapExtLabel(kDailyBonusCapExtensionAmount),
                  description: t.shop_dailyBonusCapExtDesc(
                      wallet.dailyBonusCapExtensionsUsedToday, kDailyBonusCapExtensionMaxPerDay),
                  costLabel: '💎$kDailyBonusCapExtensionGemCost',
                  accent: Kingdom.sadnessIndigo,
                  onTap: _extendDailyBonusCap,
                ),
                const SizedBox(height: Kingdom.spaceXl),

                const FrameShopSection(),
                const SizedBox(height: Kingdom.spaceXl),

                IconText(
                  t.shop_storeNote,
                  style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5), fontSize: 11),
                ),
                SizedBox(height: Kingdom.spaceXl + MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VipPassTile extends StatelessWidget {
  final bool isVip;
  final String? monthlyPrice;
  final String? yearlyPrice;
  final bool isProcessing;
  final VoidCallback onTapMonthly;
  final VoidCallback onTapYearly;

  const _VipPassTile({
    required this.isVip,
    this.monthlyPrice,
    this.yearlyPrice,
    required this.isProcessing,
    required this.onTapMonthly,
    required this.onTapYearly,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return OrnateFrame(
      accent: Kingdom.gilt,
      gradient: const LinearGradient(
        colors: [Color(0xFF3D2C0A), Color(0xFF5A4110)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('👑', style: TextStyle(fontSize: 28)),
              const SizedBox(width: Kingdom.spaceMd),
              Expanded(
                child: IconText(t.shop_vipPassLabel,
                    style: const TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              if (isVip)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Kingdom.gilt, borderRadius: BorderRadius.circular(6)),
                  child: IconText(t.shop_vipActiveLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Kingdom.night)),
                ),
            ],
          ),
          const SizedBox(height: Kingdom.spaceSm),
          IconText(t.shop_vipBenefit1, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.8), fontSize: 12)),
          IconText(t.shop_vipBenefit2, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.8), fontSize: 12)),
          IconText(t.shop_vipBenefit3, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.8), fontSize: 12)),
          const SizedBox(height: Kingdom.spaceMd),
          if (!isVip) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isProcessing ? null : onTapMonthly,
                style: ElevatedButton.styleFrom(backgroundColor: Kingdom.gilt, foregroundColor: Kingdom.night),
                child: isProcessing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Kingdom.night))
                    : IconText(PurchaseService.withStorePrice(t.shop_vipSubscribeButton, monthlyPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: Kingdom.spaceSm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isProcessing ? null : onTapYearly,
                style: OutlinedButton.styleFrom(foregroundColor: Kingdom.gilt, side: const BorderSide(color: Kingdom.gilt)),
                child: FittedBox(fit: BoxFit.scaleDown, child: IconText(PurchaseService.withStorePrice(t.shop_vipSubscribeYearlyButton, yearlyPrice), maxLines: 1, softWrap: false, style: const TextStyle(fontWeight: FontWeight.bold))),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StarterPackTile extends StatelessWidget {
  final String? price;
  final bool isProcessing;
  final VoidCallback onTap;

  const _StarterPackTile({this.price, required this.isProcessing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return OrnateFrame(
      accent: Kingdom.sadnessIndigo,
      showCorners: false,
      padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceLg, vertical: Kingdom.spaceMd),
      child: Row(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 28)),
          const SizedBox(width: Kingdom.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconText(t.shop_starterPackLabel, style: TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold, fontSize: 14)),
                IconText(t.shop_starterPackDesc.replaceFirst('（', '\n（').replaceFirst(' (', '\n('), style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6), fontSize: 11)),
              ],
            ),
          ),
          SizedBox(
            height: Kingdom.minTapTarget,
            child: ElevatedButton(
              onPressed: isProcessing ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Kingdom.sadnessIndigo,
                foregroundColor: Kingdom.parchment,
                minimumSize: const Size(84, Kingdom.minTapTarget),
              ),
              child: isProcessing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Kingdom.parchment))
                  : Text(price ?? '¥300', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceDisplay extends StatelessWidget {
  final String emoji;
  final String label;
  final int value;

  const _BalanceDisplay({required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconText('$emoji $value',
            style: TextStyle(
                fontFamily: Kingdom.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Kingdom.parchment)),
        const SizedBox(height: Kingdom.spaceXs),
        IconText(label, style: TextStyle(fontSize: 11, color: Kingdom.parchment.withValues(alpha: 0.6))),
      ],
    );
  }
}

class _ExchangeTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String description;
  final String costLabel;
  final Color accent;
  final VoidCallback onTap;

  const _ExchangeTile({
    required this.emoji,
    required this.label,
    required this.description,
    required this.costLabel,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OrnateFrame(
      accent: accent,
      showCorners: false,
      padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceLg, vertical: Kingdom.spaceMd),
      child: Row(
        children: [
          IconText(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: Kingdom.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconText(label, style: TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold, fontSize: 14)),
                IconText(description, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6), fontSize: 11)),
              ],
            ),
          ),
          SizedBox(
            height: Kingdom.minTapTarget,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Kingdom.night,
                minimumSize: const Size(70, Kingdom.minTapTarget),
              ),
              child: IconText(costLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  final CurrencyPackageDef pkg;
  final String? price;
  final Color accent;
  final bool isProcessing;
  final VoidCallback onTap;

  const _PackageTile({
    required this.pkg,
    this.price,
    required this.accent,
    required this.isProcessing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OrnateFrame(
      accent: accent,
      showCorners: false,
      padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceLg, vertical: Kingdom.spaceMd),
      child: Row(
        children: [
          IconText(pkg.isGem ? '💎' : '🪙', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: Kingdom.spaceMd),
          Expanded(
            child: IconText(pkg.labelOf(AppLocalizations.of(context)!),
                style: TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          SizedBox(
            height: Kingdom.minTapTarget,
            child: ElevatedButton(
              onPressed: isProcessing ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Kingdom.night,
                minimumSize: const Size(84, Kingdom.minTapTarget),
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Kingdom.night))
                  : Text(price ?? pkg.fallbackPriceLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
