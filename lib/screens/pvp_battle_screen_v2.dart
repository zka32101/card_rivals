import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/user_card.dart';
import '../models/battle_models.dart';
import '../services/battle_engine.dart';
import '../services/functions_service.dart';
import '../providers/game_state_provider.dart';
import '../providers/season_provider.dart';
import '../services/sound_service.dart';
import '../widgets/card_widget.dart';
import 'deck_selection_screen_v2.dart';
import 'battle_result_screen_v2.dart';
import '../models/daily_emotion_card.dart';
import '../providers/daily_emotion_provider.dart';
import '../providers/migration_provider.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

// 今日のきもちカードの感情属性 → バトル属性文字列
String? _emotionToAttribute(EmotionType? emotion) => switch (emotion) {
      EmotionType.joy => 'joy',
      EmotionType.anger => 'anger',
      EmotionType.sadness => 'sadness',
      null => null,
    };

// ローカライズされたカード名を取得（現在のロケールに基づいてJP/EN を切り替え）
String _getCardDisplayName(BuildContext context, PlayCard card) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode == 'en' && card.nameEn.isNotEmpty) {
    return card.nameEn;
  }
  return card.nameJp;
}

// カード名をバトル表示用に短縮（6文字制限）
String _truncateCardName(String name) {
  return name.length > 6 ? name.substring(0, 6) : name;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 属性テーマ定義（王国パレット）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Color _attrColor(String? a) => Kingdom.attributeColor(a);

Color _attrGlow(String? a) => Kingdom.attributeColorDeep(a);

List<Color> _attrBgGradient(String? a) => Kingdom.attributeGradient(a);

String _attrEmoji(String? a) => switch (a) {
      'joy' => '☀️',
      'anger' => '🔥',
      'sadness' => '🌙',
      _ => '⭐',
    };

String _attrFx(String? a) => switch (a) {
      'joy' => '✨',
      'anger' => '💥',
      'sadness' => '❄️',
      _ => '⚔️',
    };

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// メイン画面
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class PvpBattleScreenV2 extends ConsumerStatefulWidget {
  const PvpBattleScreenV2({super.key});

  @override
  ConsumerState<PvpBattleScreenV2> createState() => _PvpBattleScreenV2State();
}

enum _PvpPhase { deckSelect, matching, battle, done }

class _PvpBattleScreenV2State extends ConsumerState<PvpBattleScreenV2>
    with TickerProviderStateMixin {
  _PvpPhase _phase = _PvpPhase.deckSelect;
  List<PlayCard>? _myDeck;
  List<PlayCard>? _opponentDeck;
  // pvpMatchがサーバーに保存した対戦相手デッキ記録のID。
  // サーバー呼び出しに失敗した際のローカルフォールバック対戦ではnullのままとなり、
  // その場合pvpBattleへのサーバー問い合わせ自体を行わない（後述）。
  String? _matchId;
  String _opponentName = '';
  String _opponentTier = '';
  BattleResult? _result;
  // pvpBattleがサーバー側で成功したか。falseの場合は_runBattleがローカルの
  // BattleEngineへフォールバックしており、結果は改ざん防止の対象外
  // （レーティング・シーズン進捗は変動しない）。コイン報酬/連勝ボーナスも
  // このフラグがtrueの時だけ付与する — でなければ、サーバー呼び出しが失敗する
  // たびに「レーティング/シーズンは動かないのにコイン・連勝だけは付く」という
  // 経済的な不整合が生まれてしまう（練習モードでこれを防いだ既存の修正と同じ理由）。
  bool _serverConfirmed = false;
  // pvpBattle Cloud Functionが返すシーズン進捗の反映結果（アクティブシーズンが
  // 無い場合や、サーバー呼び出し自体がフォールバックした場合はnullのまま）
  Map<String, dynamic>? _seasonResult;
  List<BattleLog> _displayedLogs = [];
  int _myHp = 30;
  int _aiHp = 30;
  int _prevMyHp = 30;
  int _prevAiHp = 30;
  BattleLog? _latestLog;
  bool _isFinalTurn = false;
  bool _showComeback = false;
  int _comboCount = 0;
  Offset? _tapEffectPos;
  // ヒット中のタップで参加感を出す「気合」カウント（表示のみ・ダメージには影響しない）
  int _spiritCount = 0;
  // 決着後、結果画面に遷移する前に一呼吸置いて勝敗をはっきり伝える
  bool _showConclusion = false;

  late AnimationController _dotController;
  late AnimationController _pulseController;
  late AnimationController _flashController;
  late AnimationController _damageController;
  late AnimationController _shakeController;
  late AnimationController _auraController;
  late AnimationController _particleController;
  late AnimationController _comebackController;
  late AnimationController _tapEffectController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat();
    _flashController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _damageController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _auraController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _particleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _comebackController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _tapEffectController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _dotController.dispose();
    _pulseController.dispose();
    _flashController.dispose();
    _damageController.dispose();
    _shakeController.dispose();
    _auraController.dispose();
    _particleController.dispose();
    _comebackController.dispose();
    _tapEffectController.dispose();
    super.dispose();
  }

  void _onBattleTap(TapDownDetails details) {
    // ヒット演出中のみ反応（見ているだけでなく参加している感覚を作る）
    if (!_flashController.isAnimating) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _tapEffectPos = details.localPosition;
      _spiritCount++;
    });
    _tapEffectController.forward(from: 0);
  }

  Future<void> _startMatching() async {
    setState(() => _phase = _PvpPhase.matching);

    final myRating = await ref.read(myRatingProvider.future);
    if (!mounted) return;

    try {
      final match = await FunctionsService.pvpMatch(myRating);
      _matchId = match['matchId'] as String?;
      final deckData = (match['opponentDeck'] as List).cast<Map>();
      _opponentDeck = deckData
          .map((c) => PlayCard(
                cardId: c['cardId'] as String,
                attribute: c['attribute'] as String,
                cost: c['cost'] as int,
                attackPower: c['attackPower'] as int,
                defensePower: c['defensePower'] as int,
                speed: c['speed'] as int,
                nameJp: c['nameJp'] as String,
              ))
          .toList();
      _opponentName = match['opponentName'] as String;
      _opponentTier = match['opponentTier'] as String;
    } catch (e) {
      // マッチングに失敗した場合は固定の対戦相手にフォールバックする
      // （サーバー記録が存在しないため_matchIdはnullのまま→_runBattleはサーバー
      //   問い合わせをスキップしてローカル計算のみで進行し、レーティングも変動しない）
      _matchId = null;
      final allCards = ref.read(allPlayCardsProvider);
      final anger = allCards.where((c) => c.attribute == 'anger').skip(2).take(2).toList();
      final sadness = allCards.where((c) => c.attribute == 'sadness').skip(1).take(2).toList();
      final joy = allCards.where((c) => c.attribute == 'joy').skip(1).take(1).toList();
      _opponentDeck = [...anger, ...sadness, ...joy];
      _opponentName = 'Shadow_Player_47';
      if (!mounted) return;
      _opponentTier = AppLocalizations.of(context)!.pvpBattle_fallbackOpponentTier;
    }
    if (!mounted) return;

    // マッチング演出の最低表示時間
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    setState(() => _phase = _PvpPhase.battle);
    await _runBattle();
  }

  Future<void> _runBattle() async {
    setState(() {
      _displayedLogs = [];
      _myHp = 30;
      _aiHp = 30;
      _prevMyHp = 30;
      _prevAiHp = 30;
      _latestLog = null;
      _isFinalTurn = false;
      _showComeback = false;
      _comboCount = 0;
      _spiritCount = 0;
      _showConclusion = false;
    });

    // サーバー権威でバトル判定（クライアント計算の改ざん防止・レーティング更新もサーバー側で行う）
    // 呼び出し失敗時、および正規のサーバーマッチが存在しない場合（_matchId未取得時）は
    // クライアント側BattleEngineにフォールバックする（この場合レーティングは変動しない）
    try {
      final matchId = _matchId;
      if (matchId == null) {
        throw StateError('No server-issued matchId; falling back to local battle');
      }
      final cardLookup = <String, PlayCard>{
        for (final c in [..._myDeck!, ..._opponentDeck!]) c.cardId: c,
      };
      final response = await FunctionsService.pvpBattle(
        matchId: matchId,
        attackerDeckCardIds: _myDeck!.map((c) => c.cardId).toList(),
      );
      _seasonResult = response['season'] as Map<String, dynamic>?;
      if (_seasonResult != null) {
        // シーズン進捗がサーバー側で更新されたので、画面に表示中の進捗を再取得させる
        ref.invalidate(userCurrentSeasonProgressProvider);
      }
      final rawLogs = (response['logs'] as List).cast<Map>();
      _result = BattleResult(
        attackerWon: response['attackerWon'] as bool,
        finalAttackerHp: response['finalAttackerHp'] as int,
        finalDefenderHp: response['finalDefenderHp'] as int,
        logs: rawLogs
            .map((l) => BattleLog(
                  turn: l['turn'] as int,
                  action: '',
                  damage: l['damage'] as int,
                  attackerHp: l['attackerHp'] as int,
                  defenderHp: l['defenderHp'] as int,
                  attackingCard: cardLookup[l['attackerCardId']],
                  defendingCard: cardLookup[l['defenderCardId']],
                  multiplier: (l['multiplier'] as num).toDouble(),
                  isCritical: l['isCritical'] as bool? ?? false,
                  isDodged: l['isDodged'] as bool? ?? false,
                  isShielded: l['isShielded'] as bool? ?? false,
                ))
            .toList(),
      );
      _serverConfirmed = true;
    } catch (e) {
      // サーバー呼び出しに失敗した場合はクライアント側で計算して続行する
      _result = BattleEngine.simulate(
        _myDeck!,
        _opponentDeck!,
        migratedAttribute: ref.read(activeMigrationAttributeProvider),
      );
    }
    if (!mounted) return;
    final logs = _result!.logs;

    for (int i = 0; i < logs.length; i++) {
      final log = logs[i];
      final isFinalTurn = i == logs.length - 1;
      final prevMyHp = _myHp;
      final prevAiHp = _aiHp;

      if (isFinalTurn) {
        // 決着前の「ため」— 一瞬静止して緊張感を作る
        await Future.delayed(const Duration(milliseconds: 650));
        if (!mounted) return;
      }

      await Future.delayed(
          Duration(milliseconds: isFinalTurn ? 1400 : 1100));
      if (!mounted) return;

      final newMyHp = log.attackerHp;
      final newAiHp = log.defenderHp;
      final isComeback = prevMyHp < prevAiHp && newMyHp > newAiHp;

      playSound(SoundEffect.hit);
      HapticFeedback.mediumImpact();
      if (log.isAdvantage || log.isCritical || isFinalTurn) {
        HapticFeedback.heavyImpact();
      }

      // 決着ターン・クリティカルヒットは演出をゆっくり・大きく
      final isBigHit = isFinalTurn || log.isCritical;
      _flashController.duration =
          Duration(milliseconds: isBigHit ? 700 : 380);
      _damageController.duration =
          Duration(milliseconds: isBigHit ? 1300 : 750);
      _shakeController.duration =
          Duration(milliseconds: isBigHit ? 600 : 350);
      _flashController.forward(from: 0);
      _damageController.forward(from: 0);
      _shakeController.forward(from: 0);

      _comboCount = log.isAdvantage ? _comboCount + 1 : 0;

      setState(() {
        _displayedLogs.add(log);
        _latestLog = log;
        _prevMyHp = prevMyHp;
        _prevAiHp = prevAiHp;
        _myHp = newMyHp;
        _aiHp = newAiHp;
        _isFinalTurn = isFinalTurn;
        _showComeback = isComeback;
      });

      if (isComeback) {
        playSound(SoundEffect.victory);
        HapticFeedback.heavyImpact();
        _comebackController.forward(from: 0);
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
      }
    }

    // 決着直後にすぐ画面遷移すると「何が起きたか分からない」まま終わるため、
    // 勝敗をはっきり見せる一呼吸を挟んでから結果画面へ遷移する
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _showConclusion = true);
    HapticFeedback.heavyImpact();
    playSound(_result!.attackerWon ? SoundEffect.victory : SoundEffect.defeat);
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BattleResultScreenV2(
          result: _result!,
          isPvP: true,
          myDeck: _myDeck!,
          opponentDeck: _opponentDeck!,
          opponentName: _opponentName,
          opponentTier: _opponentTier,
          seasonPointsGained: _seasonResult?['pointsGained'] as int?,
          seasonRankedUp: _seasonResult?['rankedUp'] as bool? ?? false,
          seasonNewRank: _seasonResult?['newRank'] as int?,
          serverConfirmed: _serverConfirmed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return switch (_phase) {
      _PvpPhase.deckSelect => DeckSelectionScreenV2(
          title: t.pvpBattle_selectAttackDeckTitle,
          onConfirm: (deck) {
            setState(() => _myDeck = deck);
            _startMatching();
          },
        ),
      _PvpPhase.matching => _buildMatchingView(),
      _PvpPhase.battle => _buildBattleView(),
      _PvpPhase.done => const SizedBox.shrink(),
    };
  }

  // ─── マッチング画面 ───────────────────────
  Widget _buildMatchingView() {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Kingdom.nightDeep,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Kingdom.nightDeep, Kingdom.night, Kingdom.nightDeep],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) => Transform.scale(
                    scale: 1 + (_pulseController.value * 0.22),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.amber.withValues(alpha: 0.8),
                            Colors.amber.withValues(alpha: 0.1),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber
                                .withValues(alpha: 0.5 * _pulseController.value),
                            blurRadius: 40,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                      child:
                          const Icon(Icons.shield, size: 60, color: Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                AnimatedBuilder(
                  animation: _dotController,
                  builder: (_, snapshot) {
                    final dots =
                        '.' * ((_dotController.value * 3).floor() + 1);
                    return Column(children: [
                      Text(t.pvpBattle_searchingOpponent(dots),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(t.pvpBattle_rankMatching,
                          style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ]);
                  },
                ),
                const SizedBox(height: 60),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MatchStep(label: t.pvpBattle_stepDeckSelect, done: true),
                    _MatchLine(),
                    _MatchStep(
                        label: t.pvpBattle_stepMatching, done: false, active: true),
                    _MatchLine(),
                    _MatchStep(label: t.pvpBattle_stepBattle, done: false),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── バトル画面 ───────────────────────────
  Widget _buildBattleView() {
    final t = AppLocalizations.of(context)!;
    final bottom = MediaQuery.of(context).padding.bottom;
    // 開幕直後（まだログがない）は「今日のきもちカード」の属性を初期テーマにする
    final todayEmotion = ref.watch(todayEmotionCardProvider).valueOrNull;
    final attackerAttr = _latestLog?.attackingCard?.attribute ??
        _emotionToAttribute(todayEmotion?.emotion);
    final anyDanger = _myHp <= 7 || _aiHp <= 7; // 30の25%未満で危険域

    return Scaffold(
      backgroundColor: Kingdom.nightDeep,
      body: GestureDetector(
        onTapDown: _onBattleTap,
        behavior: HitTestBehavior.translucent,
        child: AnimatedBuilder(
        animation: Listenable.merge(
            [_flashController, _shakeController, _pulseController]),
        builder: (context, child) {
          final shake =
              math.sin(_shakeController.value * math.pi * 8) *
                  7 *
                  (1 - _shakeController.value) *
                  (_isFinalTurn ? 1.6 : 1.0);
          final flashAlpha = (_flashController.value < 0.5
                  ? _flashController.value * 2
                  : (1 - _flashController.value) * 2) *
              (_isFinalTurn ? 0.6 : 0.38);
          final flashColor = _attrColor(attackerAttr);
          final dangerPulse = (math.sin(_pulseController.value * math.pi * 2) + 1) / 2;

          return Transform.translate(
            offset: Offset(shake, 0),
            child: Stack(
              children: [
                // 背景：属性別グラデーション
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ..._attrBgGradient(attackerAttr),
                        Kingdom.nightDeep,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // 属性パーティクル
                if (attackerAttr != null)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _particleController,
                      builder: (_, child) => CustomPaint(
                        painter: _BattleParticlePainter(
                          tick: _particleController.value,
                          attribute: attackerAttr,
                          flashAmount: _flashController.value,
                        ),
                      ),
                    ),
                  ),
                // ヒットフラッシュ（属性カラー）
                if (flashAlpha > 0)
                  Positioned.fill(
                    child: Container(
                        color: flashColor.withValues(alpha: flashAlpha)),
                  ),
                // HP危険域ビネット（赤く明滅する画面端）
                if (anyDanger)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.transparent,
                              Colors.red.withValues(
                                  alpha: 0.10 + dangerPulse * 0.22),
                            ],
                            stops: const [0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                // コンテンツ
                Column(
                  children: [
                    _ArenaZone(
                      name: _opponentName,
                      tier: _opponentTier,
                      hp: _aiHp,
                      previousHp: _prevAiHp,
                      maxHp: 30,
                      deck: _opponentDeck!,
                      isOpponent: true,
                      dangerPulse: dangerPulse,
                    ),
                    Expanded(child: _buildBattleStage(attackerAttr)),
                    _ArenaZone(
                      name: t.pvpBattle_youLabel,
                      tier: '',
                      hp: _myHp,
                      previousHp: _prevMyHp,
                      maxHp: 30,
                      deck: _myDeck!,
                      isOpponent: false,
                      bottomPad: bottom,
                      dangerPulse: dangerPulse,
                    ),
                  ],
                ),
                // 逆転演出
                if (_showComeback)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _comebackController,
                        builder: (_, child) {
                          final progress = _comebackController.value;
                          final scale = progress < 0.2
                              ? (0.5 + progress * 5 * 0.7)
                              : 1.2 - (progress - 0.2) * 0.25;
                          final alpha = progress < 0.75 ? 1.0 : (1 - progress) * 4;
                          return Center(
                            child: Transform.scale(
                              scale: scale.clamp(0.0, 1.3),
                              child: Opacity(
                                opacity: alpha.clamp(0.0, 1.0),
                                child: Text(
                                  t.pvpBattle_comebackBadge,
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFFFD700),
                                    shadows: [
                                      Shadow(
                                          color: Colors.orange
                                              .withValues(alpha: 0.9),
                                          blurRadius: 30),
                                      const Shadow(
                                          color: Colors.black,
                                          blurRadius: 10),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                // タップ加速エフェクト（ヒット中にタップすると弾ける）
                if (_tapEffectPos != null)
                  AnimatedBuilder(
                    animation: _tapEffectController,
                    builder: (_, child) {
                      final t = _tapEffectController.value;
                      if (t >= 1.0) return const SizedBox.shrink();
                      final scale = 0.6 + t * 1.2;
                      final alpha = (1 - t).clamp(0.0, 1.0);
                      return Positioned(
                        left: _tapEffectPos!.dx - 30,
                        top: _tapEffectPos!.dy - 30,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: alpha,
                            child: Transform.scale(
                              scale: scale,
                              child: const SizedBox(
                                width: 60,
                                height: 60,
                                child: Center(
                                  child: Text('✨',
                                      style: TextStyle(fontSize: 28)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                // ヒット中のタップ促しプロンプト＋気合カウント（自動進行だけでなく参加している感覚を出す）
                if (_flashController.isAnimating)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _flashController.value > 0 ? 1 : 0,
                          duration: const Duration(milliseconds: 100),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(t.pvpBattle_tapPrompt,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_spiritCount > 0)
                  Positioned(
                    top: 8,
                    right: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Kingdom.gilt.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Kingdom.gilt.withValues(alpha: 0.6)),
                        ),
                        child: Text(t.pvpBattle_spiritCount(_spiritCount),
                            style: const TextStyle(
                                color: Kingdom.gilt,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                // 決着クロージング（結果画面へ飛ぶ前に勝敗をはっきり見せる一呼吸）
                if (_showConclusion)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOut,
                        builder: (_, t, child) => Container(
                          color: Colors.black.withValues(alpha: 0.55 * t),
                          child: Opacity(opacity: t, child: child),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _result!.attackerWon ? '🏆' : '💔',
                                style: const TextStyle(fontSize: 64),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _result!.attackerWon
                                    ? t.pvpBattle_conclusionVictory
                                    : t.pvpBattle_conclusionDefeat,
                                style: TextStyle(
                                  fontFamily: Kingdom.displayFont,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: _result!.attackerWon
                                      ? Kingdom.gilt
                                      : Kingdom.angerCrimson,
                                  shadows: const [
                                    Shadow(color: Colors.black87, blurRadius: 12),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }

  // ─── バトルステージ（中央） ───────────────
  Widget _buildBattleStage(String? attackerAttr) {
    final t = AppLocalizations.of(context)!;
    final log = _latestLog;
    final accentColor = _attrColor(attackerAttr);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ..._attrBgGradient(attackerAttr),
            Kingdom.nightDeep,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: const Border(
          top: BorderSide(color: Kingdom.angerCrimson, width: 2),
          bottom: BorderSide(color: Kingdom.sadnessIndigo, width: 2),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // VS 背景文字
          Text(
            'VS',
            style: TextStyle(
              fontSize: 88,
              fontWeight: FontWeight.w900,
              color: accentColor.withValues(alpha: 0.06),
              letterSpacing: 12,
            ),
          ),
          if (log == null)
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('⚔️', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(t.pvpBattle_battleStart,
                  style: const TextStyle(color: Colors.white38, fontSize: 14)),
              if (attackerAttr != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${_attrEmoji(attackerAttr)} ${t.pvpBattle_todayEmotionBanner}',
                    style: TextStyle(
                        fontSize: 10, color: accentColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ])
          else
            // バトル演出が増えて縦幅を超える端末でも下部が見切れないようスクロール可能にする
            SingleChildScrollView(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ターン + 有利バッジ
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isFinalTurn
                              ? [
                                  const Color(0xFFFF3355),
                                  const Color(0xFFFF0033)
                                ]
                              : [
                                  accentColor.withValues(alpha: 0.8),
                                  accentColor
                                ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: (_isFinalTurn
                                      ? const Color(0xFFFF0033)
                                      : accentColor)
                                  .withValues(alpha: 0.6),
                              blurRadius: _isFinalTurn ? 18 : 10)
                        ],
                      ),
                      child: Text(
                          _isFinalTurn
                              ? t.pvpBattle_finalBlowBadge
                              : t.pvpBattle_turnLabel(log.turn),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isFinalTurn
                                  ? Colors.white
                                  : Colors.black)),
                    ),
                    if (log.isAdvantage) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFD700)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x66FFD700), blurRadius: 10)
                          ],
                        ),
                        child: Text(t.pvpBattle_attributeAdvantage,
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.bold)),
                      ),
                    ] else if (log.isDisadvantage) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blueAccent),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 8)
                          ],
                        ),
                        child: Text(t.pvpBattle_attributeDisadvantage,
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                    if (log.isCritical) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3300).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFF3300)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x66FF3300), blurRadius: 12)
                          ],
                        ),
                        child: Text(t.pvpBattle_criticalBadge,
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFFF3300),
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                    if (log.isShielded) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C9CDB).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF7C9CDB)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x667C9CDB), blurRadius: 10)
                          ],
                        ),
                        child: Text(t.pvpBattle_shieldBadge,
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF7C9CDB),
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                    if (log.isDodged) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Kingdom.parchment.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Kingdom.parchment.withValues(alpha: 0.6)),
                        ),
                        child: Text(t.pvpBattle_dodgeBadge,
                            style: TextStyle(
                                fontSize: 10,
                                color: Kingdom.parchment,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // カード対決
                if (log.attackingCard != null && log.defendingCard != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _BattleCardDisplay(
                        card: log.attackingCard!,
                        isAttacker: true,
                        auraController: _auraController,
                        flashController: _flashController,
                      ),
                      _AttackEffectWidget(
                        attribute: log.attackingCard!.attribute,
                        multiplier: log.multiplier,
                        flashController: _flashController,
                      ),
                      _BattleCardDisplay(
                        card: log.defendingCard!,
                        isAttacker: false,
                        auraController: _auraController,
                        flashController: _flashController,
                      ),
                    ],
                  ),

                const SizedBox(height: 14),

                // ダメージ数字
                AnimatedBuilder(
                  animation: _damageController,
                  builder: (_, child) {
                    final t = _damageController.value;
                    final yOffset = -40.0 * t;
                    final alpha =
                        t < 0.6 ? 1.0 : (1 - t) / 0.4;
                    final scale = 1.0 + (t < 0.15 ? t * 3.0 : 0.0);
                    return Transform.translate(
                      offset: Offset(0, yOffset),
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: alpha.clamp(0.0, 1.0),
                          child: Text(
                            log.isDodged
                                // このスコープのtは_damageController.value(double)で
                                // 既に予約されているため、AppLocalizationsを明示参照する
                                ? AppLocalizations.of(context)!.pvpBattle_missLabel
                                : '${_attrFx(log.attackingCard?.attribute)} -${log.damage}',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: log.isDodged
                                  ? Kingdom.parchment.withValues(alpha: 0.7)
                                  : _attrColor(log.attackingCard?.attribute),
                              shadows: [
                                Shadow(
                                    color: _attrGlow(
                                            log.attackingCard?.attribute)
                                        .withValues(alpha: 0.9),
                                    blurRadius: 24),
                                const Shadow(color: Colors.white, blurRadius: 6),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
              ),
            ),

          // コンボカウンター（左下・2連続以上の属性有利で表示）
          if (_comboCount >= 2)
            Positioned(
              bottom: 6,
              left: 8,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_comboCount),
                tween: Tween(begin: 0.6, end: 1.0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.elasticOut,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFD700)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x99FFD700), blurRadius: 10)
                    ],
                  ),
                  child: Text(
                    t.pvpBattle_comboCount(_comboCount),
                    style: TextStyle(
                        color: const Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 11 + (_comboCount.clamp(0, 5) * 0.8)),
                  ),
                ),
              ),
            ),

          // ターン進捗（右下）
          if (_displayedLogs.length > 1)
            Positioned(
              bottom: 6,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  t.pvpBattle_turnProgress(
                      _displayedLogs.length, _result?.logs.length ?? '?'),
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 中央攻撃エフェクト
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 属性専属インパクトエフェクト CustomPainter
// joy=放射光線 / anger=爆発衝撃波+火の粉 / sadness=氷片飛散+霜の輪
// t: flashController.value (0→1、ヒット時に0から1へ一度だけ進む)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _ImpactBurstPainter extends CustomPainter {
  final double t;
  final String attribute;
  _ImpactBurstPainter({required this.t, required this.attribute});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final color = _attrColor(attribute);

    switch (attribute) {
      case 'joy':
        _paintSunburst(canvas, center, color);
        break;
      case 'anger':
        _paintExplosion(canvas, center, color);
        break;
      case 'sadness':
        _paintFrostShatter(canvas, center, color);
        break;
      default:
        _paintSunburst(canvas, center, color);
    }
  }

  // 喜: 中心から放射状に伸びる光線が回転しながら広がる
  void _paintSunburst(Canvas canvas, Offset center, Color color) {
    const rayCount = 10;
    const maxLen = 46.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fade = (1 - t).clamp(0.0, 1.0);
    for (int i = 0; i < rayCount; i++) {
      final angle = (i / rayCount) * math.pi * 2 + t * math.pi * 0.6;
      final len = maxLen * t;
      final dir = Offset(math.cos(angle), math.sin(angle));
      paint
        ..color = color.withValues(alpha: fade * 0.85)
        ..strokeWidth = 3.5 * (1 - t * 0.4);
      canvas.drawLine(center + dir * 14, center + dir * (14 + len), paint);
    }
  }

  // 怒: ギザギザの衝撃波リング＋飛び散る火の粉
  void _paintExplosion(Canvas canvas, Offset center, Color color) {
    final ringRadius = 10 + 40 * t;
    final fade = (1 - t).clamp(0.0, 1.0);
    final path = Path();
    const spikes = 12;
    for (int i = 0; i <= spikes; i++) {
      final angle = (i / spikes) * math.pi * 2;
      final r = ringRadius * (i.isEven ? 1.0 : 0.72);
      final p = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = color.withValues(alpha: fade * 0.75);
    canvas.drawPath(path, ringPaint);

    final rng = math.Random(7);
    final emberPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = (10 + rng.nextDouble() * 30) * t;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      emberPaint.color = color.withValues(alpha: fade * 0.7);
      canvas.drawCircle(pos, 2.2 * (1 - t * 0.5), emberPaint);
    }
  }

  // 哀: 氷の破片が飛び散り、霜の輪がゆっくり広がる
  void _paintFrostShatter(Canvas canvas, Offset center, Color color) {
    final rng = math.Random(13);
    final fade = (1 - t).clamp(0.0, 1.0);
    final shardPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;
    for (int i = 0; i < 7; i++) {
      final angle = (i / 7) * math.pi * 2 + rng.nextDouble() * 0.3;
      final dist = 12 + 34 * t;
      final dir = Offset(math.cos(angle), math.sin(angle));
      shardPaint.color = color.withValues(alpha: fade * 0.8);
      canvas.drawLine(center + dir * (dist * 0.4), center + dir * dist, shardPaint);
    }
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color.withValues(alpha: fade * 0.4);
    canvas.drawCircle(center, 10 + 30 * t, ringPaint);
  }

  @override
  bool shouldRepaint(_ImpactBurstPainter old) =>
      old.t != t || old.attribute != attribute;
}

// 属性移住ボーナス(+0.15)が乗った倍率(1.15/1.65/0.82等)も含めて正しく表示する。
// 旧実装は基礎倍率(1.5/0.67)への完全一致でしか判定しておらず、移住ボーナス適用中は
// 常に「×1.0」と誤表示していた。
String _formatMultiplier(double multiplier) {
  var s = multiplier.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return s;
}

class _AttackEffectWidget extends StatelessWidget {
  final String attribute;
  final double multiplier;
  final AnimationController flashController;
  const _AttackEffectWidget(
      {required this.attribute,
      required this.multiplier,
      required this.flashController});

  @override
  Widget build(BuildContext context) {
    final color = _attrColor(attribute);
    final fx = _attrFx(attribute);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: flashController,
            builder: (_, child) {
              final scale = 1.0 + flashController.value * 0.6;
              return SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 属性専属インパクトエフェクト
                    // （joy=放射光線 / anger=爆発衝撃波+火の粉 / sadness=氷片飛散+霜の輪）
                    CustomPaint(
                      size: const Size(96, 96),
                      painter: _ImpactBurstPainter(
                        t: flashController.value,
                        attribute: attribute,
                      ),
                    ),
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(
                              alpha: 0.08 + flashController.value * 0.22),
                          boxShadow: [
                            BoxShadow(
                              color: color
                                  .withValues(alpha: flashController.value * 0.9),
                              blurRadius: 16 + flashController.value * 24,
                              spreadRadius: flashController.value * 10,
                            ),
                          ],
                        ),
                        child: Center(
                            child: Text(fx,
                                style: const TextStyle(fontSize: 28))),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.6)),
            ),
            child: Text(
              '×${_formatMultiplier(multiplier)}',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// バトル中カード表示（大型・属性オーラ）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _BattleCardDisplay extends StatelessWidget {
  final PlayCard card;
  final bool isAttacker;
  final AnimationController auraController;
  final AnimationController flashController;
  const _BattleCardDisplay({
    required this.card,
    required this.isAttacker,
    required this.auraController,
    required this.flashController,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final attr = card.attribute;
    final color = _attrColor(attr);
    final glow = _attrGlow(attr);
    final emoji = _attrEmoji(attr);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 攻撃/防御ラベル
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isAttacker ? Colors.redAccent : Colors.blueGrey[700],
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                  color: (isAttacker ? Colors.red : Colors.blueGrey)
                      .withValues(alpha: 0.5),
                  blurRadius: 8)
            ],
          ),
          child: Text(
            isAttacker ? t.pvpBattle_attackLabel : t.pvpBattle_defenseLabel,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation:
              Listenable.merge([auraController, flashController]),
          builder: (_, child) {
            final auraPulse =
                (math.sin(auraController.value * math.pi * 2) + 1) / 2;
            final flashBoost =
                isAttacker ? flashController.value : 0.0;
            final glowAmount = auraPulse * 0.4 + flashBoost * 0.6;
            // 攻撃カードは前傾み、防御カードは後傾
            final angle =
                isAttacker ? -0.10 + flashBoost * 0.08 : 0.07;
            // 衝突ラウンジ：攻撃カードは中央へ突進、防御カードはノックバック
            final lunge = math.sin(
                    flashController.value.clamp(0.0, 1.0) * math.pi) *
                (isAttacker ? 16.0 : -7.0);

            return Transform.translate(
              offset: Offset(lunge, 0),
              child: Transform.rotate(
              angle: angle,
              child: Container(
                width: 92,
                height: 126,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.38 + glowAmount * 0.2),
                      const Color(0xFF100C28),
                      color.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        color.withValues(alpha: 0.55 + glowAmount * 0.45),
                    width: isAttacker ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(
                          alpha: isAttacker
                              ? 0.35 + glowAmount * 0.55
                              : 0.12 + glowAmount * 0.18),
                      blurRadius: isAttacker
                          ? 16 + glowAmount * 18
                          : 6 + glowAmount * 8,
                      spreadRadius: isAttacker ? glowAmount * 5 : 0,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 攻撃カードのみ波動オーラ
                    if (isAttacker)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CustomPaint(
                            painter: _CardAuraPainter(
                              color: color,
                              tick: auraController.value +
                                  flashController.value * 0.4,
                            ),
                          ),
                        ),
                      ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 38)),
                        const SizedBox(height: 4),
                        Text(
                          _truncateCardName(_getCardDisplayName(context, card)),
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('ATK',
                                style: TextStyle(
                                    color: Colors.redAccent
                                        .withValues(alpha: 0.85),
                                    fontSize: 7)),
                            const SizedBox(width: 2),
                            Text('${card.attackPower}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('DEF',
                                style: TextStyle(
                                    color: Colors.blueAccent
                                        .withValues(alpha: 0.85),
                                    fontSize: 7)),
                            const SizedBox(width: 2),
                            Text('${card.defensePower}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// カード波動オーラ CustomPainter
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _CardAuraPainter extends CustomPainter {
  final Color color;
  final double tick;
  _CardAuraPainter({required this.color, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.75;
    for (int i = 0; i < 3; i++) {
      final phase = (tick + i * 0.333) % 1.0;
      final r = maxR * phase;
      final a = (1 - phase) * 0.18;
      paint.color = color.withValues(alpha: a);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_CardAuraPainter old) => old.tick != tick;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// バトルパーティクル CustomPainter
// 属性別: joy=星形放射、anger=上昇炎、sadness=落下雫
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _BattleParticlePainter extends CustomPainter {
  final double tick;
  final String attribute;
  final double flashAmount;
  _BattleParticlePainter(
      {required this.tick,
      required this.attribute,
      required this.flashAmount});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final color = _attrColor(attribute);
    final count = attribute == 'anger' ? 14 : 9;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = size.height * (0.2 + rng.nextDouble() * 0.6);
      final phase = (tick + i / count) % 1.0;
      double x, y, radius;

      if (attribute == 'anger') {
        // 炎: 上昇しながら左右にゆれる
        x = baseX + math.sin(phase * math.pi * 3 + i * 1.3) * 18;
        y = baseY - phase * size.height * 0.55;
        radius = 3.5 * (1 - phase * 0.8);
      } else if (attribute == 'joy') {
        // 喜: 中心から星形に放射
        final angle = (i / count) * math.pi * 2 + tick * math.pi * 1.2;
        final r = 50.0 + phase * size.width * 0.32;
        x = size.width / 2 + math.cos(angle) * r;
        y = size.height / 2 + math.sin(angle) * r * 0.6;
        radius = 2.8 * (1 - phase * 0.5);
      } else {
        // 哀: ゆっくり落下する雫
        x = baseX + math.sin(phase * math.pi + i) * 8;
        y = baseY + phase * size.height * 0.28;
        radius = 2.2;
      }

      final alpha =
          ((1 - phase) * 0.28 + flashAmount * 0.18).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_BattleParticlePainter old) =>
      old.tick != tick ||
      old.attribute != attribute ||
      old.flashAmount != flashAmount;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// アリーナ プレイヤーゾーン
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _ArenaZone extends StatelessWidget {
  final String name;
  final String tier;
  final int hp;
  final int previousHp;
  final int maxHp;
  final List<PlayCard> deck;
  final bool isOpponent;
  final double bottomPad;
  final double dangerPulse;

  const _ArenaZone({
    required this.name,
    required this.tier,
    required this.hp,
    int? previousHp,
    required this.maxHp,
    required this.deck,
    required this.isOpponent,
    this.bottomPad = 0,
    this.dangerPulse = 0,
  }) : previousHp = previousHp ?? hp;

  @override
  Widget build(BuildContext context) {
    final ratio = (hp / maxHp).clamp(0.0, 1.0);
    final prevRatio = (previousHp / maxHp).clamp(0.0, 1.0);
    final isDanger = ratio <= 0.25;
    final hpColor = ratio > 0.5
        ? const Color(0xFF00FF88)
        : ratio > 0.25
            ? Colors.orange
            : Colors.red;
    final bgColor = isOpponent ? const Color(0xFF2A0A0A) : Kingdom.nightDeep;
    final accentColor = isDanger
        ? Colors.red.withValues(alpha: 0.6 + dangerPulse * 0.4)
        : (isOpponent ? Kingdom.angerCrimson : Kingdom.sadnessIndigo);

    return Container(
      padding: EdgeInsets.fromLTRB(
          12,
          isOpponent ? (MediaQuery.of(context).padding.top + 4) : 10,
          12,
          bottomPad + 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: isOpponent
              ? BorderSide(color: accentColor, width: isDanger ? 2.5 : 1.5)
              : BorderSide.none,
          top: !isOpponent
              ? BorderSide(color: accentColor, width: isDanger ? 2.5 : 1.5)
              : BorderSide.none,
        ),
        boxShadow: isDanger
            ? [
                BoxShadow(
                    color: Colors.red.withValues(alpha: dangerPulse * 0.35),
                    blurRadius: 14)
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white)),
                    if (tier.isNotEmpty)
                      Text(tier,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white54)),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: hpColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hpColor, width: 1.5),
                ),
                child: Text(
                  'HP $hp / $maxHp',
                  style: TextStyle(
                      color: hpColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 12, color: Colors.white10),
                // 被弾トレイル（直前HPから現在HPへゆっくり追いつく白い残像）
                // → 一撃でどれだけ削れたかが体感的にわかる「駆け引き」演出
                if (prevRatio > ratio)
                  TweenAnimationBuilder<double>(
                    key: ValueKey('hp-trail-$hp-$previousHp'),
                    tween: Tween(begin: prevRatio, end: ratio),
                    duration: const Duration(milliseconds: 850),
                    curve: Curves.easeOut,
                    builder: (_, val, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 12,
                        width: (MediaQuery.of(context).size.width - 24) * val,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  height: 12,
                  width:
                      (MediaQuery.of(context).size.width - 24) * ratio,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      hpColor.withValues(alpha: 0.7),
                      hpColor
                    ]),
                    boxShadow: [
                      BoxShadow(
                          color: hpColor.withValues(alpha: 0.6),
                          blurRadius: 6)
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                deck.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                            color: accentColor.withValues(alpha: 0.4),
                            blurRadius: 6)
                      ],
                    ),
                    child: CardThumbnail(card: deck[i], size: 46),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// マッチングステップ
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _MatchStep extends StatelessWidget {
  final String label;
  final bool done;
  final bool active;
  const _MatchStep(
      {required this.label, this.done = false, this.active = false});

  @override
  Widget build(BuildContext context) {
    final color =
        done ? Colors.green : active ? Colors.amber : Colors.white24;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: Text(
            done ? '✓' : active ? '●' : '○',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: color, fontSize: 9)),
    ]);
  }
}

class _MatchLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 28,
      height: 2,
      color: Colors.white12,
      margin: const EdgeInsets.only(bottom: 14));
}
