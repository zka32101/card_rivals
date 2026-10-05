import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/game_state_provider.dart';
import '../providers/vip_provider.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

class BonusDetailScreen extends ConsumerWidget {
  const BonusDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final wallet = ref.watch(walletProvider);
    final isVip = ref.watch(vipStatusProvider).value ?? false;
    final remainingCap = wallet.remainingDailyBonusCap(isVip: isVip);
    final totalCapToday = kDailyBonusCoinCap +
        (wallet.dailyBonusCapExtensionsUsedToday * kDailyBonusCapExtensionAmount) +
        (isVip ? kVipDailyBonusCapBoost : 0);
    final earnedToday = totalCapToday - remainingCap;
    final capRatio = totalCapToday == 0 ? 0.0 : (earnedToday / totalCapToday).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text(t.settings_myBonus, style: Kingdom.title(size: 17)),
        backgroundColor: Kingdom.nightDeep,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Kingdom.gilt),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 10)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(Kingdom.spaceLg),
              children: [
                // 本日の獲得状況
                OrnateFrame(
                  accent: Kingdom.joyGold,
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
                          Text(t.bonusDetail_todayHeader, style: Kingdom.label(size: 13, color: Kingdom.parchment.withValues(alpha: 0.8))),
                          if (isVip) ...[
                            const SizedBox(width: Kingdom.spaceSm),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Kingdom.gilt, borderRadius: BorderRadius.circular(4)),
                              child: Text('👑 VIP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Kingdom.night)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: Kingdom.spaceSm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('🪙$earnedToday / $totalCapToday',
                              style: TextStyle(
                                  fontFamily: Kingdom.displayFont, color: Kingdom.gilt, fontWeight: FontWeight.w900, fontSize: 26)),
                          Text(t.home_todayWinsProgress(wallet.todayWins),
                              style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.75), fontSize: Kingdom.textBody)),
                        ],
                      ),
                      const SizedBox(height: Kingdom.spaceSm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: capRatio,
                          backgroundColor: Kingdom.night,
                          valueColor: const AlwaysStoppedAnimation<Color>(Kingdom.gilt),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: Kingdom.spaceXs),
                      Text(t.bonusDetail_capNote(kDailyBonusCoinCap),
                          style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5), fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: Kingdom.spaceXl),

                // 連勝ボーナス
                Text(t.achievements_streakBonusTitle, style: Kingdom.title(size: Kingdom.textSubheading)),
                const SizedBox(height: Kingdom.spaceMd),
                OrnateFrame(
                  accent: Kingdom.angerCrimson,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statRow(t.achievements_streakLabel, '${wallet.winStreak}'),
                      _statRow(t.achievements_bonusMultiplierLabel, '+🪙${wallet.streakBonus}'),
                      if (wallet.streakShieldCount > 0) ...[
                        const SizedBox(height: Kingdom.spaceSm),
                        Row(
                          children: [
                            const Text('🛡️', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Text(t.shop_streakShieldLabel(wallet.streakShieldCount),
                                style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.85), fontSize: 13)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Kingdom.spaceXl),

                // ジェムでできること
                Text(t.bonusDetail_boostHeader, style: Kingdom.title(size: Kingdom.textSubheading)),
                const SizedBox(height: Kingdom.spaceMd),
                OrnateFrame(
                  accent: Kingdom.sadnessIndigo,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.bonusDetail_boostDesc,
                          style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.75), fontSize: 12)),
                      const SizedBox(height: Kingdom.spaceMd),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.push('/shop'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Kingdom.sadnessIndigo,
                            foregroundColor: Kingdom.parchment,
                          ),
                          child: Text(t.shop_title),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.75), fontSize: 13)),
            Text(value, style: const TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      );
}
