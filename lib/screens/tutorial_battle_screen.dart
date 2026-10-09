import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/user_card.dart';
import '../models/battle_models.dart';
import '../models/battle_log_text.dart';
import '../services/battle_engine.dart';
import '../providers/game_state_provider.dart';
import '../widgets/card_widget.dart';
import 'deck_selection_screen_v2.dart';
import 'battle_result_screen_v2.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

class TutorialBattleScreen extends ConsumerStatefulWidget {
  const TutorialBattleScreen({super.key});

  @override
  ConsumerState<TutorialBattleScreen> createState() => _TutorialBattleScreenState();
}

class _TutorialBattleScreenState extends ConsumerState<TutorialBattleScreen>
    with TickerProviderStateMixin {
  List<PlayCard>? _myDeck;
  List<PlayCard>? _aiDeck;
  BattleResult? _result;
  List<BattleLog> _displayedLogs = [];
  bool _isAnimating = false;
  int _myHp = 30;
  int _aiHp = 30;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _buildAiDeck(List<PlayCard> allCards) {
    // AIは全属性から均等に5枚選ぶ（決定論的）
    final joy = allCards.where((c) => c.attribute == 'joy').take(2).toList();
    final anger = allCards.where((c) => c.attribute == 'anger').take(2).toList();
    final sadness = allCards.where((c) => c.attribute == 'sadness').take(1).toList();
    _aiDeck = [...joy, ...anger, ...sadness];
  }

  Future<void> _runBattle() async {
    if (_myDeck == null || _aiDeck == null) return;

    setState(() {
      _isAnimating = true;
      _displayedLogs = [];
      _myHp = 30;
      _aiHp = 30;
    });

    _result = BattleEngine.simulate(_myDeck!, _aiDeck!);

    // ログをアニメーション表示
    for (final log in _result!.logs) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() {
        _displayedLogs.add(log);
        _myHp = log.attackerHp;
        _aiHp = log.defenderHp;
      });
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // 結果画面へ
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BattleResultScreenV2(
          result: _result!,
          isPvP: false,
          myDeck: _myDeck!,
          opponentDeck: _aiDeck!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allCards = ref.watch(allPlayCardsProvider);
    final t = AppLocalizations.of(context)!;

    if (_myDeck == null) {
      return DeckSelectionScreenV2(
        title: t.tutorialBattle_selectPracticeDeck,
        onConfirm: (deck) {
          setState(() {
            _myDeck = deck;
            _buildAiDeck(allCards);
          });
        },
      );
    }

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text(t.tutorialBattle_title, style: Kingdom.title(size: 16)),
        centerTitle: true,
        backgroundColor: Kingdom.nightDeep,
      ),
      body: _isAnimating ? _buildBattleView(t) : _buildReadyView(t),
    );
  }

  Widget _buildReadyView(AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.all(Kingdom.spaceXxl),
      child: Column(
        children: [
          Icon(Icons.smart_toy, size: 80, color: Kingdom.sadnessIndigo),
          const SizedBox(height: Kingdom.spaceLg),
          Text(t.tutorialBattle_aiOpponent, style: Kingdom.title(size: 18)),
          const SizedBox(height: Kingdom.spaceSm),
          Text(t.tutorialBattle_aiDescription, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5))),
          const SizedBox(height: Kingdom.spaceXxxl),
          Text(t.tutorialBattle_yourDeckCount(_myDeck!.length), style: Kingdom.label(size: 13, color: Kingdom.gilt)),
          const SizedBox(height: Kingdom.spaceMd),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _myDeck!.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(right: Kingdom.spaceSm),
                child: CardThumbnail(card: _myDeck![i], size: 80),
              ),
            ),
          ),
          const Spacer(),
          RoyalButton(
            label: t.tutorialBattle_startBattle,
            accent: Kingdom.angerCrimson,
            height: 56,
            onPressed: _runBattle,
          ),
        ],
      ),
    );
  }

  Widget _buildBattleView(AppLocalizations t) {
    return Column(
      children: [
        // AI サイド
        _buildSidePanel(
          label: t.tutorialBattle_aiLabel,
          hp: _aiHp,
          deck: _aiDeck!,
          isAi: true,
        ),

        // バトルログ
        Expanded(
          child: Container(
            color: Kingdom.nightDeep,
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(Kingdom.spaceMd),
              itemCount: _displayedLogs.length,
              itemBuilder: (_, i) {
                final log = _displayedLogs[_displayedLogs.length - 1 - i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Kingdom.gilt, borderRadius: BorderRadius.circular(4)),
                        child: Text('T${log.turn}', style: TextStyle(color: Kingdom.night, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: Kingdom.spaceSm),
                      Expanded(
                        child: Text(
                          '${battleLogText(AppLocalizations.of(context)!, log)}　-${log.damage}',
                          style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.8), fontSize: Kingdom.textBody),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // 自分サイド
        _buildSidePanel(
          label: t.tutorialBattle_youLabel,
          hp: _myHp,
          deck: _myDeck!,
          isAi: false,
        ),
      ],
    );
  }

  Widget _buildSidePanel({
    required String label,
    required int hp,
    required List<PlayCard> deck,
    required bool isAi,
  }) {
    final ratio = hp / 30.0;
    return Container(
      padding: const EdgeInsets.all(Kingdom.spaceMd),
      color: (isAi ? Kingdom.angerCrimson : Kingdom.sadnessIndigo).withValues(alpha: 0.15),
      child: Column(
        children: [
          Row(
            children: [
              Text(label, style: Kingdom.label(size: 13, color: Kingdom.parchment)),
              const Spacer(),
              Text('HP $hp/30', style: TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: Kingdom.parchment.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                  ratio > 0.5 ? Kingdom.joyGold : ratio > 0.25 ? Colors.orange : Kingdom.angerCrimson),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: Kingdom.spaceSm),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: deck.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: CardThumbnail(card: deck[i], size: 55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
