import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_card.dart';
import '../services/sound_service.dart';
import 'card_widget.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

int _rarityTier(CardRarity r) => switch (r) {
      CardRarity.n => 0,
      CardRarity.r => 1,
      CardRarity.sr => 2,
      CardRarity.ur => 3,
    };

/// カード作成時のパック開封風リビール演出
/// タップで裏面 → 3Dフリップ → 表面（レアリティに応じて輝き・衝撃波が強化）
class CardRevealDialog extends StatefulWidget {
  final PlayCard card;

  const CardRevealDialog({super.key, required this.card});

  static Future<void> show(BuildContext context, PlayCard card) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CardRevealDialog(card: card),
    );
  }

  @override
  State<CardRevealDialog> createState() => _CardRevealDialogState();
}

class _CardRevealDialogState extends State<CardRevealDialog>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _shineController;
  late AnimationController _pulseController;
  late AnimationController _burstController;
  bool _revealed = false;
  bool _burstFired = false;

  int get _tier => _rarityTier(widget.card.rarity);

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
        vsync: this, duration: Duration(milliseconds: 700 + _tier * 120))
      ..addListener(_onFlipTick);
    _shineController = AnimationController(
        vsync: this, duration: Duration(milliseconds: 1800 - _tier * 300))
      ..repeat();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat();
    _burstController = AnimationController(
        vsync: this, duration: Duration(milliseconds: 550 + _tier * 150));
  }

  @override
  void dispose() {
    _flipController.dispose();
    _shineController.dispose();
    _pulseController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  void _onFlipTick() {
    // フリップが正面を向いた瞬間（半回転超え）に一度だけ衝撃波を発火
    if (!_burstFired && _flipController.value > 0.5) {
      _burstFired = true;
      _burstController.forward(from: 0);
      switch (_tier) {
        case 3:
          HapticFeedback.heavyImpact();
          playSound(SoundEffect.hit);
        case 2:
          HapticFeedback.mediumImpact();
          playSound(SoundEffect.hit);
        default:
          HapticFeedback.selectionClick();
      }
    }
  }

  void _flip() {
    if (_revealed) return;
    setState(() => _revealed = true);
    playSound(SoundEffect.cardFlip);
    _flipController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final rColor = rarityColor(widget.card.rarity);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            colors: [Kingdom.sadnessIndigoDeep, Kingdom.nightDeep],
            radius: 1.2,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Kingdom.gilt.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _revealed
                    ? (_tier >= 2 ? t.cardReveal_rareBornTitle : t.cardReveal_newCardBornTitle)
                    : (_tier >= 2 ? t.cardReveal_somethingShiningTitle : t.cardReveal_tapToOpen),
                key: ValueKey('$_revealed-$_tier'),
                style: Kingdom.title(size: 17),
              ),
            ),
            const SizedBox(height: 24),

            // フリップ + 衝撃波演出
            GestureDetector(
              onTap: _flip,
              // カード表面（幅170のCardWidget）の高さは約314ある。ここが280だと、フリップ後に
              // カード下段（攻撃力・防御力・速度）が34px はみ出して切れていた（実機で確認）。
              child: SizedBox(
                width: 220,
                height: 330,
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                      [_flipController, _shineController, _pulseController, _burstController]),
                  builder: (context, child) {
                    final angle = _flipController.value * math.pi;
                    final isFront = angle > math.pi / 2;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // レアリティ衝撃波（フリップ完了の瞬間に一度だけ発火）
                        if (_burstController.value > 0)
                          CustomPaint(
                            size: const Size(220, 330),
                            painter: _RevealBurstPainter(
                              t: _burstController.value,
                              color: rColor,
                              tier: _tier,
                            ),
                          ),
                        // フリップ完了後は3D Transformを外して素の状態で描画する。
                        // 回転Transform配下でImage.networkを合成し続けると、Impellerで
                        // 画像が白いまま固まって二度と再合成されないことがあるため
                        // （実機検証で確認）、静止後は通常のウィジェットツリーに戻す。
                        if (_flipController.isCompleted)
                          _buildFront()
                        else
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(angle),
                            child: isFront
                                ? Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()..rotateY(math.pi),
                                    child: _buildFront(),
                                  )
                                : _buildBack(rColor),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 28),

            if (_revealed)
              Column(
                children: [
                  // レアリティバッジ（バウンスして登場）
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.3, end: 1.0),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.elasticOut,
                    builder: (_, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: rColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: rColor, width: 1.4),
                        boxShadow: [
                          BoxShadow(
                              color: rColor.withValues(alpha: _tier >= 2 ? 0.6 : 0.25),
                              blurRadius: 10 + _tier * 4)
                        ],
                      ),
                      child: Text(
                        t.cardReveal_rarityRankLabel(widget.card.rarityLabel),
                        style: TextStyle(
                            color: rColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13),
                      ),
                    ),
                  ),
                  RoyalButton(
                    label: t.cardReveal_addToCollectionButton,
                    height: 48,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              )
            else
              Text(t.cardReveal_tapPackHint,
                  style: TextStyle(
                      color: Kingdom.parchment.withValues(alpha: 0.5),
                      fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // カード裏面（パック）— レアリティが高いほど脈動するオーラが強くなる
  Widget _buildBack(Color rColor) {
    final pulse = (math.sin(_pulseController.value * math.pi * 2) + 1) / 2;
    final glowStrength = 0.15 + _tier * 0.12 + pulse * (0.08 + _tier * 0.06);
    return Container(
      width: 170,
      height: 238,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Kingdom.gilt, width: 2),
        boxShadow: [
          BoxShadow(color: Kingdom.gilt.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2),
          if (_tier >= 1)
            BoxShadow(
                color: rColor.withValues(alpha: glowStrength.clamp(0.0, 0.85)),
                blurRadius: 22 + _tier * 8,
                spreadRadius: 2 + _tier * 2),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/theme/card_back.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Kingdom.sadnessIndigo, Kingdom.sadnessIndigoDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(_tier >= 2 ? '👑' : '🎴', style: const TextStyle(fontSize: 64)),
            ),
          ),
        ),
      ),
    );
  }

  // カード表面（キラキラ輝きオーバーレイ付き。レアリティが高いほど輝きが速く強い）
  Widget _buildFront() {
    return Stack(
      children: [
        SizedBox(width: 170, child: CardWidget(card: widget.card, size: 170)),
        // 斜めに走るシャイン
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: IgnorePointer(
              child: ShaderMask(
                // dstIn: 白い面をグラデーションのアルファで抜き、光の帯だけを残す。
                // （srcATopだと透明部分でも白がそのまま残り、カード全面が白く覆われていた）
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) {
                  final slide = _shineController.value * 2 - 0.5;
                  return LinearGradient(
                    begin: Alignment(slide - 0.3, -1),
                    end: Alignment(slide + 0.3, 1),
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.45 + _tier * 0.06),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.35, 0.5, 0.65],
                  ).createShader(rect);
                },
                child: Container(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// リビール衝撃波 CustomPainter
// tier(0=N〜3=UR)が高いほどリング数・輪の広がりが増える
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _RevealBurstPainter extends CustomPainter {
  final double t;
  final Color color;
  final int tier;
  _RevealBurstPainter({required this.t, required this.color, required this.tier});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final fade = (1 - t).clamp(0.0, 1.0);
    final ringCount = 1 + tier;
    final paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < ringCount; i++) {
      final delay = i * 0.12;
      final localT = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (localT <= 0) continue;
      final radius = 30 + localT * (size.width * 0.55 + tier * 14);
      paint
        ..color = color.withValues(alpha: (1 - localT) * fade * 0.6)
        ..strokeWidth = 3.0 - i * 0.4;
      canvas.drawCircle(center, radius, paint);
    }

    // UR/SRのみ: 中心からの放射光線で豪華さを強調
    if (tier >= 2) {
      final rayPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.2;
      const rays = 12;
      for (int i = 0; i < rays; i++) {
        final angle = (i / rays) * math.pi * 2;
        final dir = Offset(math.cos(angle), math.sin(angle));
        final len = 20 + t * (60 + tier * 10);
        rayPaint.color = color.withValues(alpha: fade * 0.5);
        canvas.drawLine(center + dir * 10, center + dir * len, rayPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_RevealBurstPainter old) =>
      old.t != t || old.color != color || old.tier != tier;
}
