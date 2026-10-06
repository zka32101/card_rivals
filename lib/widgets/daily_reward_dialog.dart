import 'package:flutter/material.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';
import 'ui_icon.dart';
import 'ui_icon.dart';

/// デイリーログインボーナス（7日間カレンダー＋連続ストリーク）
class DailyRewardDialog extends StatefulWidget {
  final int currentDay; // 1-7（本日が何日目か）
  final void Function(int coins) onClaim;

  const DailyRewardDialog({
    super.key,
    required this.currentDay,
    required this.onClaim,
  });

  /// 7日間の報酬テーブル
  static const rewards = [3, 5, 6, 9, 12, 17, 25];

  static Future<void> show(BuildContext context, {required int currentDay, required void Function(int) onClaim}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DailyRewardDialog(currentDay: currentDay, onClaim: onClaim),
    );
  }

  @override
  State<DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends State<DailyRewardDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _claimed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final todayIndex = (widget.currentDay - 1).clamp(0, 6);
    final todayReward = DailyRewardDialog.rewards[todayIndex];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceXxl),
      child: Container(
        padding: const EdgeInsets.all(Kingdom.spaceXl),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Kingdom.nightDeep, Kingdom.sadnessIndigoDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Kingdom.gilt.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconText(t.dailyReward_title, style: Kingdom.title(size: 20)),
            const SizedBox(height: Kingdom.spaceXs),
            IconText(t.dailyReward_streakLabel(widget.currentDay), style: Kingdom.label(size: 13, color: Kingdom.gilt)),
            const SizedBox(height: Kingdom.spaceXl),

            // 7日間カレンダー
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
              children: List.generate(7, (i) {
                final day = i + 1;
                final isToday = day == widget.currentDay;
                final isPast = day < widget.currentDay;
                final reward = DailyRewardDialog.rewards[i];
                final isBig = day == 7;

                return Container(
                  decoration: BoxDecoration(
                    color: isToday
                        ? Kingdom.gilt
                        : isPast
                            ? Kingdom.parchment.withValues(alpha: 0.08)
                            : Kingdom.parchment.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isToday ? Kingdom.parchment : (isBig ? Kingdom.gilt : Colors.transparent),
                      width: isToday ? 2 : (isBig ? 1.5 : 0),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconText(t.dailyReward_dayLabel(day),
                          style: TextStyle(fontSize: 9, color: isToday ? Kingdom.night : Kingdom.parchment.withValues(alpha: 0.7))),
                      const SizedBox(height: 2),
                      IconText(isBig ? '🎉' : '🪙', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('$reward',
                          style: TextStyle(
                              fontSize: Kingdom.textCaption,
                              fontWeight: FontWeight.bold,
                              color: isToday ? Kingdom.night : Kingdom.parchment.withValues(alpha: 0.7))),
                      if (isPast) Icon(Icons.check_circle, size: 12, color: Kingdom.joyGold),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: Kingdom.spaceXl),

            // 受取ボタン / 受取済み演出
            if (!_claimed)
              RoyalButton(
                label: t.dailyReward_claimButton(todayReward),
                height: 52,
                onPressed: () {
                  setState(() => _claimed = true);
                  _controller.forward();
                  widget.onClaim(todayReward);
                },
              )
            else
              ScaleTransition(
                scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                  CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
                ),
                child: Column(
                  children: [
                    IconText(t.dailyReward_claimedAmount(todayReward),
                        style: TextStyle(
                            fontFamily: Kingdom.displayFont, fontSize: 32, fontWeight: FontWeight.bold, color: Kingdom.gilt)),
                    const SizedBox(height: Kingdom.spaceMd),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Kingdom.parchment,
                          foregroundColor: Kingdom.nightDeep,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: IconText(t.dailyReward_okButton, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
