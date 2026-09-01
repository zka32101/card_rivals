import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../widgets/card_widget.dart';
import '../widgets/card_reveal_dialog.dart';
import '../models/user_card.dart';
import '../models/card_design_words.dart';
import '../providers/auth_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/game_state_provider.dart';
import '../providers/vip_provider.dart';
import '../services/functions_service.dart';
import '../widgets/daily_quests_widget.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

class CardCreationScreenV2 extends ConsumerStatefulWidget {
  const CardCreationScreenV2({super.key});

  @override
  ConsumerState<CardCreationScreenV2> createState() => _CardCreationScreenV2State();
}

class _CardCreationScreenV2State extends ConsumerState<CardCreationScreenV2> {
  int _step = 0;
  final List<String> _selectedDesignWords = []; // カードデザイン選択
  String? _attribute;
  int? _cost;
  int _attack = 0;
  int _defense = 0;
  int _speed = 0;
  String _tone = 'cool';
  List<String> _nameCandidates = [];
  String? _selectedName;
  bool _isGeneratingName = false;
  final _coCreatorController = TextEditingController();

  // ガチャ抽選パラメータ配分
  bool _hasRolled = false;
  bool _isRolling = false;
  bool _isBigHit = false;
  int _rerollsUsed = 0;
  final _random = Random();

  int get _budget => switch (_cost ?? 1) { 1 => 20, 2 => 25, 3 => 30, 4 => 35, _ => 40 };
  // build内(Widgetツリー構築中)でのみ使用。ref.watchはbuildフェーズ外(onPressed等)から
  // 呼ぶとエラーになるため、イベントハンドラー側では ref.read(vipStatusProvider) を直接使うこと。
  bool get _isVipWatched => ref.watch(vipStatusProvider).valueOrNull ?? false;
  int get _creationCostWatched => cardCreationCoinCost(isVip: _isVipWatched, cost: _cost ?? 1);
  bool get _isParamValid => _hasRolled;
  int get _remainingRerolls => kParamRerollMaxCount - _rerollsUsed;

  @override
  void dispose() {
    _coCreatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text(t.cardCreation_appBarTitle(_step + 1), style: Kingdom.title(size: 16)),
        elevation: 0,
        backgroundColor: Kingdom.nightDeep,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Kingdom.spaceLg, vertical: Kingdom.spaceXs),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_step + 1) / 6,
                backgroundColor: Kingdom.night,
                valueColor: const AlwaysStoppedAnimation<Color>(Kingdom.gilt),
                minHeight: 4,
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 8)),
          SafeArea(
        child: Column(
          children: [
            // ステップ表示
            Padding(
              padding: const EdgeInsets.all(Kingdom.spaceLg),
              child: Row(
                children: List.generate(6, (i) {
                  final isActive = i == _step;
                  final isDone = i < _step;
                  final stepColor = isDone ? Kingdom.joyGold : isActive ? Kingdom.gilt : Kingdom.bronze.withValues(alpha: 0.4);
                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Kingdom.nightDeep,
                            shape: BoxShape.circle,
                            border: Border.all(color: stepColor, width: 1.6),
                          ),
                          child: Center(
                            child: Text(
                              isDone ? '✓' : '${i + 1}',
                              style: TextStyle(
                                fontFamily: Kingdom.displayFont,
                                color: isDone || isActive ? stepColor : Kingdom.parchment.withValues(alpha: 0.4),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: Kingdom.spaceXs),
                        Text(
                          [
                            t.cardCreation_stepDesign,
                            t.cardCreation_stepAttribute,
                            t.cardCreation_stepCost,
                            t.cardCreation_stepParameters,
                            t.cardCreation_stepTone,
                            t.cardCreation_stepNaming,
                          ][i],
                          style: TextStyle(fontSize: 10, color: isActive ? Kingdom.gilt : Kingdom.parchment.withValues(alpha: 0.4)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),

            // コンテンツ
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Kingdom.spaceLg),
                child: switch (_step) {
                  0 => _buildDesignStep(t),
                  1 => _buildAttributeStep(t),
                  2 => _buildCostStep(t),
                  3 => _buildParameterStep(t),
                  4 => _buildToneStep(t),
                  5 => _buildNamingStep(t),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),

            // ボタン
            Padding(
              padding: const EdgeInsets.all(Kingdom.spaceLg),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Kingdom.parchment.withValues(alpha: 0.4)),
                          foregroundColor: Kingdom.parchment,
                        ),
                        child: Text(t.cardCreation_back),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: Kingdom.spaceMd),
                  Expanded(child: _buildNextButton(t)),
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

  Widget _buildStepTitle(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Kingdom.title(size: 17)),
        const SizedBox(height: Kingdom.spaceXs),
        Text(sub, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6), fontSize: 12)),
        const SizedBox(height: Kingdom.spaceXl),
      ],
    );
  }

  Widget _buildDesignStep(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(t.cardCreation_designStepTitle, t.cardCreation_designStepSub),
        if (_selectedDesignWords.isNotEmpty) ...[
          OrnateFrame(
            accent: Kingdom.gilt,
            padding: const EdgeInsets.all(Kingdom.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.cardCreation_designSelectedCount(_selectedDesignWords.length),
                    style: Kingdom.label(size: 12, color: Kingdom.gilt)),
                const SizedBox(height: Kingdom.spaceSm),
                Wrap(
                  spacing: Kingdom.spaceSm,
                  runSpacing: 6,
                  children: _selectedDesignWords.map((word) {
                    return Chip(
                      label: Text(word),
                      onDeleted: () => setState(() => _selectedDesignWords.remove(word)),
                      backgroundColor: Kingdom.gilt,
                      labelStyle: TextStyle(color: Kingdom.night, fontWeight: FontWeight.bold),
                      deleteIconColor: Kingdom.night,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: Kingdom.spaceLg),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1.6,
          ),
          itemCount: kCardDesignWords.length,
          itemBuilder: (context, index) {
            final word = kCardDesignWords[index];
            final isSelected = _selectedDesignWords.contains(word);
            final canSelect = !isSelected && _selectedDesignWords.length < 3;

            return GestureDetector(
              onTap: () {
                if (isSelected) {
                  setState(() => _selectedDesignWords.remove(word));
                } else if (canSelect) {
                  setState(() => _selectedDesignWords.add(word));
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Kingdom.gilt : Kingdom.nightDeep,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Kingdom.gilt : Kingdom.parchment.withValues(alpha: 0.15),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    word,
                    style: TextStyle(
                      fontSize: Kingdom.textCaption,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Kingdom.night
                          : (!canSelect ? Kingdom.parchment.withValues(alpha: 0.25) : Kingdom.parchment.withValues(alpha: 0.85)),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAttributeStep(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(t.cardCreation_attributeStepTitle, t.cardCreation_attributeStepSub),
        ...[
          ('joy', '☀️ ${t.cardCreation_attrJoyLabel}', t.cardCreation_attrJoyAdvantage, Kingdom.joyGold, t.cardCreation_attrJoyRealm),
          ('anger', '🔥 ${t.cardCreation_attrAngerLabel}', t.cardCreation_attrAngerAdvantage, Kingdom.angerCrimson, t.cardCreation_attrAngerRealm),
          ('sadness', '🌙 ${t.cardCreation_attrSadnessLabel}', t.cardCreation_attrSadnessAdvantage, Kingdom.sadnessIndigo, t.cardCreation_attrSadnessRealm),
        ].map((item) {
          final isSelected = _attribute == item.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: Kingdom.spaceMd),
            child: GestureDetector(
              onTap: () => setState(() => _attribute = item.$1),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? item.$4.withValues(alpha: 0.15) : Kingdom.nightDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? item.$4 : Kingdom.parchment.withValues(alpha: 0.15), width: isSelected ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Text(item.$2.split(' ')[0], style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: Kingdom.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$2.split(' ')[1], style: Kingdom.label(size: 14, color: item.$4)),
                          Text(item.$3, style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.6))),
                          Text(item.$5, style: TextStyle(fontSize: Kingdom.textCaption, color: Kingdom.parchment.withValues(alpha: 0.4))),
                        ],
                      ),
                    ),
                    if (isSelected) Icon(Icons.check_circle, color: item.$4),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCostStep(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(t.cardCreation_costStepTitle, t.cardCreation_costStepSub),
        ...List.generate(5, (i) {
          final c = i + 1;
          final budget = switch (c) { 1 => 20, 2 => 25, 3 => 30, 4 => 35, _ => 40 };
          final isSelected = _cost == c;
          return Padding(
            padding: const EdgeInsets.only(bottom: Kingdom.spaceMd),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _cost = c;
                  _attack = 0;
                  _defense = 0;
                  _speed = 0;
                  _hasRolled = false;
                  _isBigHit = false;
                  _rerollsUsed = 0;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? Kingdom.gilt.withValues(alpha: 0.12) : Kingdom.nightDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? Kingdom.gilt : Kingdom.parchment.withValues(alpha: 0.15), width: isSelected ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Text(List.generate(c, (_) => '★').join(), style: const TextStyle(fontSize: 18, color: Kingdom.gilt)),
                    const SizedBox(width: Kingdom.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.cardCreation_costLabel(c), style: Kingdom.label(size: Kingdom.textBody, color: Kingdom.parchment)),
                          Text(t.cardCreation_costBudget(budget), style: TextStyle(fontSize: 12, color: Kingdom.parchment.withValues(alpha: 0.5))),
                          Text(t.cardCreation_costPrice(cardCreationCoinCost(isVip: _isVipWatched, cost: c)),
                              style: TextStyle(fontSize: 12, color: Kingdom.gilt.withValues(alpha: 0.8))),
                        ],
                      ),
                    ),
                    if (isSelected) const Icon(Icons.check_circle, color: Kingdom.gilt),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // total を parts 個の1以上の整数にランダム分割する（各値がランダムに偏る）
  List<int> _splitRandom(int total, int parts) {
    final cuts = <int>{};
    while (cuts.length < parts - 1) {
      cuts.add(1 + _random.nextInt(total - 1));
    }
    final sorted = cuts.toList()..sort();
    final shares = <int>[];
    int prev = 0;
    for (final c in sorted) {
      shares.add(c - prev);
      prev = c;
    }
    shares.add(total - prev);
    shares.shuffle(_random);
    return shares;
  }

  Future<void> _rollParameters({required bool isReroll}) async {
    if (isReroll) {
      final wallet = ref.read(walletProvider);
      if (wallet.coinBalance < kParamRerollCoinCost || _remainingRerolls <= 0) return;
      final updated = wallet.copyWith(coinBalance: wallet.coinBalance - kParamRerollCoinCost);
      ref.read(walletProvider.notifier).state = updated;
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) updateWallet(userId, updated);
      setState(() => _rerollsUsed++);
    }

    setState(() => _isRolling = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final isBigHit = _random.nextDouble() < kParamBigHitChance;
    // ゲームバランス確保：総パラメータ数を各コストティアごとに厳密に固定
    final total = isBigHit ? (_budget * (1 + kParamBigHitBonusPercent)).round() : _budget;
    final shares = _splitRandom(total, 3);

    setState(() {
      _attack = shares[0];
      _defense = shares[1];
      _speed = shares[2];
      _isBigHit = isBigHit;
      _hasRolled = true;
      _isRolling = false;
    });
  }

  Widget _buildParameterStep(AppLocalizations t) {
    final wallet = ref.watch(walletProvider);
    final canReroll = _remainingRerolls > 0 && wallet.coinBalance >= kParamRerollCoinCost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.card_selectParameters, style: Kingdom.title(size: 17)),
        const SizedBox(height: Kingdom.spaceXs),
        Text(t.cardCreation_gachaSub, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6), fontSize: 12)),
        const SizedBox(height: Kingdom.spaceXl),

        if (!_hasRolled && !_isRolling)
          Center(
            child: RoyalButton(
              label: t.cardCreation_rollButton,
              accent: Kingdom.gilt,
              onPressed: () => _rollParameters(isReroll: false),
            ),
          )
        else if (_isRolling)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: Kingdom.spaceXxl),
              child: CircularProgressIndicator(color: Kingdom.gilt),
            ),
          )
        else ...[
          if (_isBigHit)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Kingdom.spaceMd),
                child: Text(t.cardCreation_bigHitLabel,
                    style: TextStyle(
                        color: Kingdom.gilt, fontWeight: FontWeight.w900, fontSize: 20, fontFamily: Kingdom.displayFont)),
              ),
            ),
          _buildParamResultRow(t.card_attack, _attack, Kingdom.angerCrimson),
          const SizedBox(height: Kingdom.spaceMd),
          _buildParamResultRow(t.card_defense, _defense, Kingdom.sadnessIndigo),
          const SizedBox(height: Kingdom.spaceMd),
          _buildParamResultRow(t.card_speed, _speed, Kingdom.joyGold),
          const SizedBox(height: Kingdom.spaceLg),
          if (_remainingRerolls > 0)
            Center(
              child: Column(
                children: [
                  OutlinedButton(
                    onPressed: canReroll ? () => _rollParameters(isReroll: true) : null,
                    child: Text(t.cardCreation_rerollButton(kParamRerollCoinCost, _remainingRerolls)),
                  ),
                  if (!canReroll)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(t.cardCreation_insufficientCoins,
                          style: TextStyle(color: Kingdom.angerCrimson.withValues(alpha: 0.8), fontSize: 11)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: Kingdom.spaceXxl),
          Text(t.cardCreation_preview, style: Kingdom.label(size: Kingdom.textBody, color: Kingdom.gilt)),
          const SizedBox(height: Kingdom.spaceMd),
          Center(
            child: SizedBox(
              width: 160,
              child: CardWidget(
                card: PlayCard(
                  cardId: 'preview',
                  attribute: _attribute ?? 'joy',
                  cost: _cost ?? 1,
                  attackPower: _attack,
                  defensePower: _defense,
                  speed: _speed,
                  nameJp: t.cardCreation_previewCardName,
                  nameEn: t.cardCreation_previewCardName,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildParamResultRow(String label, int value, Color color) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: Kingdom.label(size: Kingdom.textBody, color: color))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / 20).clamp(0.0, 1.0),
              backgroundColor: Kingdom.parchment.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: Kingdom.spaceSm),
        SizedBox(
          width: 28,
          child: Text('$value', textAlign: TextAlign.end, style: const TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildToneStep(AppLocalizations t) {
    final tones = [
      ('cute', t.card_cute, t.cardCreation_toneCuteDesc),
      ('cool', t.card_cool, t.cardCreation_toneCoolDesc),
      ('dark', t.card_dark, t.cardCreation_toneDarkDesc),
      ('elegant', t.card_elegant, t.cardCreation_toneElegantDesc),
      ('normal', t.cardCreation_toneNormalLabel, t.cardCreation_toneNormalDesc),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(t.cardCreation_toneStepTitle, t.cardCreation_toneStepSub),
        ...tones.map((tone) {
          final isSelected = _tone == tone.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _tone = tone.$1),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? Kingdom.gilt.withValues(alpha: 0.12) : Kingdom.nightDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? Kingdom.gilt : Kingdom.parchment.withValues(alpha: 0.15), width: isSelected ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tone.$2, style: Kingdom.label(size: Kingdom.textBody, color: Kingdom.parchment)),
                          Text(tone.$3, style: TextStyle(fontSize: Kingdom.textCaption, color: Kingdom.parchment.withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                    if (isSelected) const Icon(Icons.check_circle, color: Kingdom.gilt),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNamingStep(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepTitle(t.cardCreation_namingStepTitle, t.cardCreation_namingStepSub),
        if (_isGeneratingName) ...[
          const Center(child: CircularProgressIndicator(color: Kingdom.gilt)),
          const SizedBox(height: Kingdom.spaceLg),
          Center(child: Text(t.cardCreation_generatingName, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.6)))),
        ] else ...[
          ..._nameCandidates.map((name) {
            final isSelected = _selectedName == name;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selectedName = name),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? Kingdom.gilt.withValues(alpha: 0.12) : Kingdom.nightDeep,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? Kingdom.gilt : Kingdom.parchment.withValues(alpha: 0.15), width: isSelected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: TextStyle(
                                fontFamily: Kingdom.displayFont,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Kingdom.parchment)),
                      ),
                      if (isSelected) const Icon(Icons.check_circle, color: Kingdom.gilt),
                    ],
                  ),
                ),
              ),
            );
          }),
          TextButton.icon(
            onPressed: () {
              setState(() => _isGeneratingName = true);
              _generateNames();
            },
            icon: Icon(Icons.refresh, color: Kingdom.gilt),
            label: Text(t.cardCreation_regenerateNames, style: TextStyle(color: Kingdom.gilt)),
          ),
        ],
        const SizedBox(height: Kingdom.spaceLg),
        Text('🤝 ${t.cardCreation_coCreatorTitle}', style: Kingdom.label(size: Kingdom.textBody, color: const Color(0xFF7C9CDB))),
        const SizedBox(height: Kingdom.spaceXs),
        Text(t.cardCreation_coCreatorDesc,
            style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5), fontSize: Kingdom.textCaption)),
        const SizedBox(height: Kingdom.spaceSm),
        TextField(
          controller: _coCreatorController,
          maxLength: 12,
          style: TextStyle(color: Kingdom.parchment),
          decoration: InputDecoration(
            hintText: t.cardCreation_coCreatorHint,
            hintStyle: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.35)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Kingdom.parchment.withValues(alpha: 0.25)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Kingdom.parchment.withValues(alpha: 0.25)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Kingdom.gilt),
            ),
            isDense: true,
          ),
        ),
        const SizedBox(height: Kingdom.spaceMd),
        OrnateFrame(
          accent: Kingdom.sadnessIndigo,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF7C9CDB), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.cardCreation_confirmCoinNotice(_creationCostWatched),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7C9CDB))),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNextButton(AppLocalizations t) {
    switch (_step) {
      case 0:
        return RoyalButton(
          label: t.cardCreation_next,
          onPressed: _selectedDesignWords.length == 3 ? () => setState(() => _step = 1) : null,
        );
      case 1:
        return RoyalButton(
          label: t.cardCreation_next,
          onPressed: _attribute != null ? () => setState(() => _step = 2) : null,
        );
      case 2:
        return RoyalButton(
          label: t.cardCreation_next,
          onPressed: _cost != null ? () => setState(() => _step = 3) : null,
        );
      case 3:
        return RoyalButton(
          label: t.cardCreation_next,
          onPressed: _isParamValid ? () => setState(() => _step = 4) : null,
        );
      case 4:
        return RoyalButton(
          label: t.cardCreation_generateNameButton,
          onPressed: () {
            setState(() => _step = 5);
            _generateNames();
          },
        );
      case 5:
        return RoyalButton(
          label: t.cardCreation_createForCoins(_creationCostWatched),
          accent: Kingdom.angerCrimson,
          onPressed: _selectedName != null ? _confirmAndPay : null,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _costToRarity(int cost) => switch (cost) {
        1 => 'n',
        2 => 'r',
        3 => 'r',
        4 => 'sr',
        _ => 'ur',
      };

  Future<void> _generateNames() async {
    try {
      final names = await FunctionsService.generateCardName(
        attribute: _attribute ?? 'joy',
        cost: _cost ?? 1,
        attack: _attack,
        defense: _defense,
        speed: _speed,
        tone: _tone,
      );
      if (!mounted) return;
      setState(() {
        _nameCandidates = names;
        _isGeneratingName = false;
      });
    } catch (e) {
      if (!mounted) return;
      final t = AppLocalizations.of(context)!;
      final fallback = [
        _tone == 'cute' ? t.cardCreation_fallbackLightFairy : t.cardCreation_fallbackLightIcon,
        _attribute == 'joy'
            ? t.cardCreation_fallbackSunChild
            : _attribute == 'anger'
                ? t.cardCreation_fallbackFlameChild
                : t.cardCreation_fallbackMoonChild,
        t.cardCreation_fallbackPowerCard,
      ];
      setState(() {
        _nameCandidates = fallback;
        _isGeneratingName = false;
      });
    }
  }

  void _confirmAndPay() {
    final t = AppLocalizations.of(context)!;
    final wallet = ref.read(walletProvider);
    final isVip = ref.read(vipStatusProvider).valueOrNull ?? false;
    final cost = cardCreationCoinCost(isVip: isVip, cost: _cost ?? 1);
    if (wallet.coinBalance < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.cardCreation_insufficientCoins),
          backgroundColor: Kingdom.angerCrimson,
          action: SnackBarAction(
            label: t.cardCreation_goToShop,
            textColor: Kingdom.parchment,
            onPressed: () => context.push('/shop'),
          ),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Kingdom.nightDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Kingdom.gilt.withValues(alpha: 0.4)),
        ),
        title: Text(t.cardCreation_confirmTitle, style: Kingdom.title(size: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.cardCreation_quotedName(_selectedName ?? ''),
                style: TextStyle(fontFamily: Kingdom.displayFont, fontSize: 18, fontWeight: FontWeight.bold, color: Kingdom.parchment)),
            const SizedBox(height: Kingdom.spaceSm),
            Text(t.cardCreation_confirmBody(cost), style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.8))),
            const SizedBox(height: Kingdom.spaceXs),
            Text(t.cardCreation_confirmNote, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5), fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cardCreation_cancel, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.7))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _processPurchase();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Kingdom.angerCrimson, foregroundColor: Kingdom.parchment),
            child: Text(t.cardCreation_createForCoins(cost)),
          ),
        ],
      ),
    );
  }

  Future<void> _processPurchase() async {
    final wallet = ref.read(walletProvider);
    final isVip = ref.read(vipStatusProvider).valueOrNull ?? false;
    final cost = cardCreationCoinCost(isVip: isVip, cost: _cost ?? 1);
    if (wallet.coinBalance < cost) {
      // _confirmAndPay側で確認済みだが、確認ダイアログ表示中の消費と競合した場合の保険
      return;
    }
    // コイン消費とカード実数値の決定は createCard Cloud Function 側のトランザクションで
    // アトミックに行う（サーバー権威）。以前はここでローカルにコインを引き、
    // ステータス値も含めてクライアントが直接Firestoreへ書き込んでおり、改造クライアント/
    // 直接呼び出しでattackPower等を任意の値に詐称できてしまっていた
    // （pvpBattle.tsが検証なしで信用してPvP戦闘の実ダメージを計算するため実害が大きい）。
    await _onCardCreated(cost, isVip);
  }

  Future<void> _onCardCreated(int cost, bool isVip) async {
    final t = AppLocalizations.of(context)!;
    // 画像生成ローディング表示
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ImageGenLoadingDialog(
          attribute: _attribute ?? 'joy',
          rarity: _costToRarity(_cost ?? 1),
        ),
      );
    }

    String imageUrl = '';
    try {
      final previewCard = PlayCard(
        cardId: 'tmp',
        attribute: _attribute ?? 'joy',
        cost: _cost ?? 1,
        attackPower: _attack,
        defensePower: _defense,
        speed: _speed,
        nameJp: _selectedName ?? t.cardCreation_defaultCardName,
        nameEn: '',
      );
      imageUrl = await FunctionsService.generateCardImage(
        attribute: _attribute ?? 'joy',
        cardName: _selectedName ?? '',
        cardType: previewCard.getCardType(),
        rarity: _costToRarity(_cost ?? 1),
        designWords: List<String>.from(_selectedDesignWords),
        tone: _tone,
      );
    } catch (e) {
      // 画像生成失敗時はプレースホルダーで続行
      imageUrl = '';
    }

    final coCreatorName = _coCreatorController.text.trim();
    final cardNameJp = _selectedName ?? t.cardCreation_defaultCardName;
    final userId = ref.read(currentUserIdProvider);

    Map<String, dynamic> result;
    try {
      result = await FunctionsService.createCard(
        attribute: _attribute ?? 'joy',
        cost: _cost ?? 1,
        attackPower: _attack,
        defensePower: _defense,
        speed: _speed,
        cardNameJp: cardNameJp,
        imageUrl: imageUrl,
        coCreatorName: coCreatorName.isEmpty ? null : coCreatorName,
        isVip: isVip,
      );
    } on FirebaseFunctionsException catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? t.cardCreation_insufficientCoins), backgroundColor: Kingdom.angerCrimson),
        );
      }
      return;
    } catch (_) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.cardCreation_insufficientCoins), backgroundColor: Kingdom.angerCrimson),
        );
      }
      return;
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    final newCardId = result['cardId'] as String;
    final newCoinBalance = result['newCoinBalance'] as int;
    final wallet = ref.read(walletProvider);
    ref.read(walletProvider.notifier).state = wallet.copyWith(coinBalance: newCoinBalance);

    final newCard = PlayCard(
      cardId: newCardId,
      attribute: _attribute ?? 'joy',
      cost: _cost ?? 1,
      attackPower: _attack,
      defensePower: _defense,
      speed: _speed,
      nameJp: _selectedName ?? t.cardCreation_defaultCardName,
      nameEn: '',
      imageUrl: imageUrl,
      coCreatorName: coCreatorName.isEmpty ? null : coCreatorName,
    );

    // サーバー側で既に永続化済みなので、ローカル状態にも楽観的に反映するだけでよい。
    final userCard = UserCard(
      cardId: newCardId,
      userId: userId ?? '',
      attribute: newCard.attribute,
      cost: newCard.cost,
      attackPower: newCard.attackPower,
      defensePower: newCard.defensePower,
      speed: newCard.speed,
      cardName: {'jp': newCard.nameJp, 'en': newCard.nameJp},
      cardDescription: const {'jp': '', 'en': ''},
      imageUrl: newCard.imageUrl,
      createdAt: Timestamp.now(),
      coCreatorId: null,
      coCreatorName: newCard.coCreatorName,
    );
    ref.read(myCardsProvider.notifier).state = [...ref.read(myCardsProvider), userCard];

    if (!mounted) return;
    await CardRevealDialog.show(context, newCard);
    if (!mounted) return;

    // カード作成クエスト進捗更新
    final quests = ref.read(dailyQuestsProvider);
    final updated = quests.map((q) {
      if (q.type == QuestType.create && q.progress < q.target) {
        return q.copyWith(progress: q.progress + 1);
      }
      return q;
    }).toList();
    ref.read(dailyQuestsProvider.notifier).state = updated;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.cardCreation_cardAddedSnackbar(_selectedName ?? '', cost)),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.pop(context);
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 画像生成中ローディングダイアログ
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _ImageGenLoadingDialog extends StatelessWidget {
  final String attribute;
  final String rarity;
  const _ImageGenLoadingDialog(
      {required this.attribute, required this.rarity});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final emoji = switch (attribute) {
      'joy' => '☀️',
      'anger' => '🔥',
      _ => '🌙',
    };
    final color = Kingdom.attributeColor(attribute);
    final rarityLabel = switch (rarity) {
      'ur' => t.cardCreation_rarityUr,
      'sr' => t.cardCreation_raritySr,
      'r' => t.cardCreation_rarityR,
      _ => t.cardCreation_rarityN,
    };
    return Dialog(
      backgroundColor: Kingdom.nightDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: Kingdom.spaceLg),
            Text(t.cardCreation_generatingImage, style: Kingdom.label(size: Kingdom.textSubheading, color: color)),
            const SizedBox(height: 6),
            Text(rarityLabel, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5), fontSize: 12)),
            const SizedBox(height: Kingdom.spaceXl),
            LinearProgressIndicator(
              backgroundColor: Kingdom.night,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: Kingdom.spaceMd),
            Text(
              t.cardCreation_generatingImageSub,
              textAlign: TextAlign.center,
              style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.35), fontSize: Kingdom.textCaption),
            ),
          ],
        ),
      ),
    );
  }
}
