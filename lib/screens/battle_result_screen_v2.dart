import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../models/user_card.dart';
import '../providers/auth_provider.dart';
import '../providers/game_state_provider.dart';
import '../services/battle_engine.dart';
import '../services/sound_service.dart';
import '../widgets/confetti_painter.dart';
import '../widgets/daily_quests_widget.dart';
import '../widgets/card_widget.dart';
import '../providers/daily_mission_provider.dart';
import '../providers/vip_provider.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

class BattleResultScreenV2 extends ConsumerStatefulWidget {
  final BattleResult result;
  final bool isPvP;
  final List<PlayCard> myDeck;
  final List<PlayCard> opponentDeck;
  final String? opponentName;
  final String? opponentTier;
  // pvpBattle Cloud Functionがサーバー側で反映したシーズン進捗（アクティブシーズンが
  // 無い場合やサーバー呼び出しがローカルフォールバックした場合はnull/未設定のまま）
  final int? seasonPointsGained;
  final bool seasonRankedUp;
  final int? seasonNewRank;
  // PvP戦の判定がpvpBattle Cloud Function（サーバー権威）から実際に返ってきたか。
  // falseはローカルのBattleEngineフォールバックで進行したことを意味し、
  // レーティング/シーズン進捗は変動していない。連勝ボーナス・PvPデイリーボーナスの
  // コインもこのフラグがtrueの時だけ付与する（サーバー呼び出し失敗のたびに
  // 「本来の報酬は動かないのにコインだけ付く」という経済的不整合を防ぐため）。
  // PvP以外の呼び出し元（練習モード等）はisPvP=falseで既にボーナス自体が
  // 無効化されるため、trueのままで問題ない。
  final bool serverConfirmed;

  const BattleResultScreenV2({
    super.key,
    required this.result,
    required this.isPvP,
    required this.myDeck,
    required this.opponentDeck,
    this.opponentName,
    this.opponentTier,
    this.seasonPointsGained,
    this.seasonRankedUp = false,
    this.seasonNewRank,
    this.serverConfirmed = true,
  });

  @override
  ConsumerState<BattleResultScreenV2> createState() => _BattleResultScreenV2State();
}

class _BattleResultScreenV2State extends ConsumerState<BattleResultScreenV2> {
  int _streakBonus = 0;
  int _newStreak = 0;
  int _pvpBonusGranted = 0;
  bool _shieldUsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      playSound(widget.result.attackerWon ? SoundEffect.victory : SoundEffect.defeat);
      // 連勝数・連勝ボーナス・連勝シールドはPvPの実績。「ノーボーナス」と明記された
      // AI練習モードでこれを更新すると、練習勝利で無リスクにコインを稼げたり、
      // 練習の負けでPvP用の連勝/シールドを失ったりしてしまうバグがあった。
      // serverConfirmedがfalseの場合（pvpBattle呼び出し失敗によるローカルフォールバック）は
      // レーティング/シーズン進捗が動いていないので、コイン報酬だけ付与すると
      // 「本来の報酬は据え置きなのにコインだけ増える」という経済的不整合になる。
      if (widget.isPvP && widget.serverConfirmed) {
        _updateStreak();
        if (widget.result.attackerWon) _updatePvpBonus();
      }
      _updateQuests();
      _updateDailyMissions();
    });
  }

  // PvP勝利ボーナス（1日上限🪙20をstreakBonusと共有・実際に加算する）
  void _updatePvpBonus() {
    final w = ref.read(walletProvider);
    final isVip = ref.read(vipStatusProvider).valueOrNull ?? false;
    final (updatedWallet, granted) = w.grantDailyBonus(1, isVip: isVip);
    _pvpBonusGranted = granted;
    if (granted > 0) {
      ref.read(walletProvider.notifier).state = updatedWallet;
      _persistWallet(updatedWallet);
    }
    setState(() {});
  }

  void _persistWallet(WalletState wallet) {
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) updateWallet(userId, wallet);
  }

  void _updateStreak() {
    final w = ref.read(walletProvider);
    if (widget.result.attackerWon) {
      _newStreak = w.winStreak + 1;
      final oldTierBonus = w.streakBonus;
      final newTierBonus = w.copyWith(winStreak: _newStreak).streakBonus;
      // 新しい連勝ボーナス段階に達した分だけを付与する（前段階の額を含む値をそのまま
      // 付与すると、連勝が伸びるたびに過去の段階分まで多重に加算されてしまうバグがあった）
      final rawBonus = newTierBonus > oldTierBonus ? (newTierBonus - oldTierBonus) : 0;
      // 1日あたりのボーナス上限（🪙15、VIPは+10）を実際に強制する。
      // これが無かったため、連勝をわざと途切れさせて3連勝ボーナスを無限に稼げてしまっていた。
      final isVip = ref.read(vipStatusProvider).valueOrNull ?? false;
      final (updatedWallet, granted) =
          w.copyWith(winStreak: _newStreak).grantDailyBonus(rawBonus, isVip: isVip);
      _streakBonus = granted;
      ref.read(walletProvider.notifier).state = updatedWallet;
      _persistWallet(updatedWallet);
    } else if (w.streakShieldCount > 0) {
      // 連勝シールドを消費して連勝数を維持する
      _shieldUsed = true;
      _newStreak = w.winStreak;
      final updatedWallet = w.copyWith(streakShieldCount: w.streakShieldCount - 1);
      ref.read(walletProvider.notifier).state = updatedWallet;
      _persistWallet(updatedWallet);
    } else {
      _newStreak = 0;
      final updatedWallet = w.copyWith(winStreak: 0);
      ref.read(walletProvider.notifier).state = updatedWallet;
      _persistWallet(updatedWallet);
    }
    setState(() {});
  }

  void _shareReplay() {
    final t = AppLocalizations.of(context)!;
    final isWin = widget.result.attackerWon;
    final totalDamage = widget.result.logs.fold<int>(0, (prev, log) => prev + log.damage);
    final advantageHits = widget.result.logs.where((l) => l.isAdvantage).length;
    final opponent = widget.opponentName ?? 'AI';

    // Achievement badge (visual representation of victory/achievement)
    final achievementBadge = isWin
        ? '🏆 ${t.battleResult_winTitle}'
        : '⚔️ ${t.battleResult_lossTitle}';

    final buffer = StringBuffer()
      ..writeln(achievementBadge)
      ..writeln()
      ..writeln(t.battleResult_shareHeader)
      ..writeln(isWin ? t.battleResult_shareWin(opponent) : t.battleResult_shareLoss(opponent))
      ..writeln();

    // Summary stats without detailed turn-by-turn logs
    buffer.writeln(t.battleResult_shareStats(widget.result.logs.length, totalDamage, advantageHits));
    buffer.writeln();
    buffer.writeln(t.battleResult_shareHashtag);

    Share.share(buffer.toString());
  }

  void _updateDailyMissions() {
    final totalDamage = widget.result.logs.fold<int>(0, (prev, log) => prev + log.damage);
    final myAttributes = widget.myDeck.map((c) => c.attribute).toSet();
    updateMissionProgress(
      ref,
      isWin: widget.result.attackerWon,
      attributesUsed: myAttributes,
      damageDealt: totalDamage,
    );
  }

  // 今回のバトルで最も貢献したカード（自デッキ内で与ダメージ合計が最大のもの）
  PlayCard? get _mvpCard {
    final myCardIds = widget.myDeck.map((c) => c.cardId).toSet();
    final damageByCard = <String, int>{};
    for (final log in widget.result.logs) {
      final atk = log.attackingCard;
      if (atk != null && myCardIds.contains(atk.cardId)) {
        damageByCard[atk.cardId] = (damageByCard[atk.cardId] ?? 0) + log.damage;
      }
    }
    if (damageByCard.isEmpty) return null;
    final topId =
        damageByCard.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return widget.myDeck.firstWhere((c) => c.cardId == topId);
  }

  int get _mvpDamage {
    final mvp = _mvpCard;
    if (mvp == null) return 0;
    return widget.result.logs
        .where((l) => l.attackingCard?.cardId == mvp.cardId)
        .fold<int>(0, (prev, l) => prev + l.damage);
  }

  void _updateQuests() {
    final quests = ref.read(dailyQuestsProvider);
    final updated = quests.map((q) {
      if (q.type == QuestType.battle && q.progress < q.target) {
        return q.copyWith(progress: q.progress + 1);
      }
      if (q.type == QuestType.win && widget.result.attackerWon && q.progress < q.target) {
        return q.copyWith(progress: q.progress + 1);
      }
      return q;
    }).toList();
    ref.read(dailyQuestsProvider.notifier).state = updated;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isWin = widget.result.attackerWon;
    final accent = isWin ? Kingdom.gilt : Kingdom.angerCrimson;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.popUntil(context, ModalRoute.withName('/'));
        }
      },
      child: Scaffold(
        backgroundColor: Kingdom.nightDeep,
        body: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isWin
                      ? const [Color(0xFF3D2C0A), Kingdom.nightDeep]
                      : const [Color(0xFF3A1210), Kingdom.nightDeep],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const SizedBox.expand(),
            ),
            Positioned.fill(child: EmotionMoteField(count: 10)),
            // 勝利時の紙吹雪
            if (isWin) const Positioned.fill(child: ConfettiOverlay()),
            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                children: [
                  const SizedBox(height: 20),

                  // 勝敗表示
                  _buildResultHeader(isWin, accent),

                  if (!isWin && _shieldUsed) ...[
                    const SizedBox(height: 12),
                    _buildShieldUsedPanel(),
                  ],

                  const SizedBox(height: 30),

                  // 統計情報
                  _buildStatsPanel(accent),

                  const SizedBox(height: 24),

                  // MVPカード（勝利時のみ・達成感を演出）
                  if (isWin && _mvpCard != null) ...[
                    _buildMvpPanel(),
                    const SizedBox(height: 24),
                  ],

                  // デッキ比較
                  _buildDeckComparison(),

                  const SizedBox(height: 24),

                  // 連勝ストリーク（勝利時）
                  if (isWin && _newStreak > 1) ...[
                    _buildStreakPanel(),
                    const SizedBox(height: 24),
                  ],

                  // ボーナス情報（PvP勝利時のみ）
                  if (widget.isPvP && isWin) ...[
                    _buildBonusInfo(),
                    const SizedBox(height: 24),
                  ],

                  // シーズン進捗（PvP勝利時、アクティブシーズンがある場合のみ）
                  if (widget.isPvP && isWin && (widget.seasonPointsGained ?? 0) > 0) ...[
                    _buildSeasonPanel(),
                    const SizedBox(height: 24),
                  ],

                  // ボタン群
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // もう一度バトル
                        RoyalButton(
                          label: t.battleResult_playAgain,
                          icon: Icons.replay,
                          accent: accent,
                          height: 56,
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(height: 12),
                        // リプレイを共有
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _shareReplay,
                            icon: Icon(Icons.share, color: Kingdom.parchment.withValues(alpha: 0.8)),
                            label: Text(t.battleResult_shareReplay,
                                style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.8))),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Kingdom.parchment.withValues(alpha: 0.35)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // ホームに戻る
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.popUntil(context, ModalRoute.withName('/')),
                            icon: Icon(Icons.home, color: Kingdom.parchment.withValues(alpha: 0.8)),
                            label: Text(t.battleResult_backHome,
                                style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.8))),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Kingdom.parchment.withValues(alpha: 0.35)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20 + MediaQuery.of(context).padding.bottom),
                ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHeader(bool isWin, Color accent) {
    final t = AppLocalizations.of(context)!;
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Text(
                isWin ? '👑' : '💔',
                style: const TextStyle(fontSize: 76),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          isWin ? t.battleResult_winTitle : t.battleResult_lossTitle,
          style: TextStyle(
            fontFamily: Kingdom.displayFont,
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: accent,
            letterSpacing: 2,
            shadows: const [
              Shadow(offset: Offset(0, 3), blurRadius: 10, color: Colors.black54),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isWin ? t.battleResult_winSubtitle : t.battleResult_lossSubtitle,
          style: TextStyle(fontSize: 13, color: Kingdom.parchment.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _buildStatsPanel(Color accent) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OrnateFrame(
        accent: accent,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(t.battleResult_statsTitle, style: Kingdom.label(size: 15, color: accent)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatBox(label: t.battleResult_statTurns, value: '${widget.result.logs.length}', icon: '⏱️'),
                Container(width: 1, height: 60, color: Kingdom.parchment.withValues(alpha: 0.15)),
                _StatBox(
                  label: t.battleResult_statTotalDamage,
                  value: '${widget.result.logs.fold<int>(0, (prev, log) => prev + log.damage)}',
                  icon: '⚔️',
                ),
                Container(width: 1, height: 60, color: Kingdom.parchment.withValues(alpha: 0.15)),
                _StatBox(
                  label: t.battleResult_statRemainingHp,
                  value:
                      '${widget.result.attackerWon ? widget.result.finalAttackerHp : widget.result.finalDefenderHp}',
                  icon: '❤️',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // MVPカード表彰パネル（達成感の演出：どのカードが勝利に一番貢献したかを称える）
  Widget _buildMvpPanel() {
    final t = AppLocalizations.of(context)!;
    final mvp = _mvpCard!;
    final accentColor = Kingdom.attributeColor(mvp.attribute);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1.0),
        duration: const Duration(milliseconds: 550),
        curve: Curves.elasticOut,
        builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
        child: OrnateFrame(
          accent: Kingdom.gilt,
          gradient: const LinearGradient(
            colors: [Color(0xFF3D2C0A), Color(0xFF5A4110)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: accentColor.withValues(alpha: 0.5), blurRadius: 14, spreadRadius: 1),
                  ],
                ),
                child: CardThumbnail(card: mvp, size: 56),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.battleResult_mvpLabel, style: Kingdom.label(size: 13, color: Kingdom.gilt)),
                    const SizedBox(height: 4),
                    Text(mvp.nameJp,
                        style: TextStyle(
                            color: Kingdom.parchment,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(t.battleResult_mvpDamage(_mvpDamage),
                        style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.7), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeckComparison() {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.battle_yourDeck, style: Kingdom.label(size: 14, color: Kingdom.gilt)),
          const SizedBox(height: 12),
          OrnateFrame(
            accent: Kingdom.bronze,
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final card in widget.myDeck)
                  Column(
                    children: [
                      CardThumbnail(card: card, size: 50),
                      const SizedBox(height: 4),
                      Text(
                        '${card.attackPower}/${card.defensePower}',
                        style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.7), fontSize: 10),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakPanel() {
    final t = AppLocalizations.of(context)!;
    final streakEmoji = _newStreak >= 7 ? '🔥🔥🔥' : _newStreak >= 5 ? '🔥🔥' : '🔥';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OrnateFrame(
        accent: Kingdom.angerCrimson,
        gradient: const LinearGradient(
          colors: [Kingdom.angerCrimsonDeep, Color(0xFF7A3A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Row(
          children: [
            Text(streakEmoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.battleResult_streakActive(_newStreak), style: Kingdom.label(size: 15, color: Kingdom.parchment)),
                  if (_streakBonus > 0)
                    Text(t.battleResult_streakBonusEarned(_streakBonus),
                        style: const TextStyle(color: Kingdom.gilt, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Column(
              children: [
                Text('$_newStreak',
                    style: TextStyle(
                        fontFamily: Kingdom.displayFont,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Kingdom.parchment)),
                Text(t.battleResult_streakLabel, style: TextStyle(fontSize: 10, color: Kingdom.parchment.withValues(alpha: 0.7))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShieldUsedPanel() {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OrnateFrame(
        accent: Kingdom.sadnessIndigo,
        child: Row(
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(t.battleResult_shieldUsed(_newStreak),
                  style: Kingdom.label(size: 13, color: Kingdom.parchment)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBonusInfo() {
    final t = AppLocalizations.of(context)!;
    final isVip = ref.watch(vipStatusProvider).valueOrNull ?? false;
    final remaining = ref.watch(walletProvider).remainingDailyBonusCap(isVip: isVip);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OrnateFrame(
        accent: Kingdom.gilt,
        gradient: const LinearGradient(
          colors: [Color(0xFF3D2C0A), Color(0xFF5A4110)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Column(
          children: [
            Text(t.battleResult_pvpBonusTitle, style: Kingdom.label(size: 13, color: Kingdom.gilt)),
            const SizedBox(height: 8),
            Text(t.battleResult_pvpBonusSubtitle, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.7), fontSize: 12)),
            const SizedBox(height: 4),
            _pvpBonusGranted > 0
                ? Text(t.battleResult_pvpBonusAmount(_pvpBonusGranted),
                    style: TextStyle(
                        fontFamily: Kingdom.displayFont,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Kingdom.gilt))
                : Text(t.battleResult_pvpBonusCapReached,
                    style: TextStyle(
                        color: Kingdom.parchment.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(t.battleResult_pvpBonusCapInfo(kDailyBonusCoinCap, remaining),
                style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonPanel() {
    final t = AppLocalizations.of(context)!;
    final points = widget.seasonPointsGained ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OrnateFrame(
        accent: Kingdom.lightSkyBlue,
        child: Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.battleResult_seasonPointsEarned(points),
                      style: Kingdom.label(size: 14, color: Kingdom.lightSkyBlue)),
                  if (widget.seasonRankedUp && widget.seasonNewRank != null)
                    Text(t.battleResult_seasonRankUp(widget.seasonNewRank!),
                        style: const TextStyle(color: Kingdom.gilt, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
              fontFamily: Kingdom.displayFont,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Kingdom.parchment),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Kingdom.parchment.withValues(alpha: 0.5))),
      ],
    );
  }
}
