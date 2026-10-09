import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/card_move.dart';
import 'card_detail_sheet.dart' show cardMoveName;
import 'ui_icon.dart';

// バトル中の「わざ」演出。
// 1) 全てのわざ: 技名のカットイン帯（左からスライドイン）
// 2) 攻撃系4種（slash / pierce / heavyBlow / weakPoint）: 専用の攻撃エフェクト
// 補助系の専用エフェクトは未実装（カットインのみ）。
//
// animation は 0→1 で1回再生する。0〜0.45 がカットイン、攻撃エフェクトは 0.4 以降
// （呼び出し側は 0.4〜0.5 付近でヒット演出を開始する想定）。
const double kMoveEffectHitPoint = 0.45;

// この演出の総再生時間。ヒット演出（フラッシュ・ダメージ表示）は
// kMoveEffectHitPoint 到達時に始めるため、呼び出し側は
// `kMoveEffectDuration * kMoveEffectHitPoint` だけ待ってからヒット処理に入る。
const Duration kMoveEffectDuration = Duration(milliseconds: 1400);

bool moveHasAttackEffect(CardMoveId id) => switch (id) {
      CardMoveId.slash ||
      CardMoveId.pierce ||
      CardMoveId.heavyBlow ||
      CardMoveId.weakPoint =>
        true,
      _ => false,
    };

class MoveEffectOverlay extends StatelessWidget {
  final Animation<double> animation;
  final CardMoveId moveId;
  final Color color;

  const MoveEffectOverlay({
    super.key,
    required this.animation,
    required this.moveId,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final name = cardMoveName(t, moveId);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final v = animation.value;
          if (v <= 0 || v >= 1) return const SizedBox.shrink();
          return Stack(
            fit: StackFit.expand,
            children: [
              if (moveHasAttackEffect(moveId))
                CustomPaint(
                  painter: MoveEffectPainter(t: v, moveId: moveId, color: color),
                ),
              _MoveCutIn(t: v, name: name, color: color),
            ],
          );
        },
      ),
    );
  }
}

// 技名カットイン帯：0〜0.12でスライドイン、保持、0.4〜0.52でスライドアウト
class _MoveCutIn extends StatelessWidget {
  final double t;
  final String name;
  final Color color;
  const _MoveCutIn({required this.t, required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    double x;
    if (t < 0.12) {
      x = -1 + Curves.easeOutCubic.transform(t / 0.12);
    } else if (t < 0.4) {
      x = 0;
    } else if (t < 0.52) {
      x = Curves.easeInCubic.transform((t - 0.4) / 0.12);
    } else {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: const Alignment(0, -0.35),
      child: Transform.translate(
        offset: Offset(x * width, 0),
        child: Container(
          width: double.infinity,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              color.withValues(alpha: 0.0),
              color.withValues(alpha: 0.85),
              color.withValues(alpha: 0.85),
              color.withValues(alpha: 0.0),
            ], stops: const [0.0, 0.2, 0.8, 1.0]),
          ),
          child: Transform(
            transform: Matrix4.skewX(-0.18),
            alignment: Alignment.center,
            child: IconText(
              '✨ $name ✨',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 4,
                shadows: [
                  Shadow(color: Colors.black87, blurRadius: 10),
                  Shadow(color: Colors.black54, blurRadius: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 攻撃系4種の専用エフェクト。画面全体に描く（中心＝バトルステージ付近）。
class MoveEffectPainter extends CustomPainter {
  final double t; // 全体進捗 0..1
  final CardMoveId moveId;
  final Color color;
  MoveEffectPainter({required this.t, required this.moveId, required this.color});

  // カットイン後の攻撃エフェクト部分の進捗 0..1
  double get _p => ((t - 0.4) / 0.6).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (_p <= 0) return;
    final center = Offset(size.width / 2, size.height * 0.5);
    switch (moveId) {
      case CardMoveId.slash:
        _slash(canvas, size, center);
      case CardMoveId.pierce:
        _vacuumBlade(canvas, size, center);
      case CardMoveId.heavyBlow:
        _heavyBlow(canvas, size, center);
      case CardMoveId.weakPoint:
        _weakPoint(canvas, size, center);
      default:
        break;
    }
  }

  Paint _glow(Color c, double width, double blur, {double alpha = 1}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = width
    ..color = c.withValues(alpha: alpha.clamp(0.0, 1.0))
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

  // 一閃: 右上→左下へ走る斜めの斬撃線と、残光・火花
  void _slash(Canvas canvas, Size size, Offset c) {
    final p = _p;
    final len = size.width * 0.9;
    const angle = 2.5; // 右上→左下
    final dir = Offset(math.cos(angle), math.sin(angle));
    final start = c - dir * (len / 2);
    final sweep = Curves.easeOutExpo.transform((p / 0.45).clamp(0.0, 1.0));
    final head = start + dir * (len * sweep);
    final fade = p < 0.5 ? 1.0 : (1 - (p - 0.5) / 0.5);
    // 残光（太く淡い）→ 本体（細く白い）
    canvas.drawLine(start, head, _glow(color, 16, 12, alpha: 0.6 * fade));
    canvas.drawLine(start, head, _glow(Colors.white, 4.5, 2, alpha: fade));
    // 先端の火花
    final rng = math.Random(3);
    final spark = Paint()..color = Colors.white.withValues(alpha: 0.9 * fade);
    for (int i = 0; i < 10; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final d = (8 + rng.nextDouble() * 40) * sweep;
      canvas.drawCircle(head + Offset(math.cos(a), math.sin(a)) * d, 2.2 * (1 - p * 0.6), spark);
    }
  }

  // しんくうざん: 三日月型の真空刃が左→右へ飛び、衝突点で衝撃リング
  void _vacuumBlade(Canvas canvas, Size size, Offset c) {
    final p = _p;
    final fly = Curves.easeIn.transform((p / 0.55).clamp(0.0, 1.0));
    final x = -40 + (c.dx + 40) * fly;
    final fade = p < 0.6 ? 1.0 : (1 - (p - 0.6) / 0.4);
    if (p < 0.6) {
      // 三日月（弧）
      final r = 46.0;
      final rect = Rect.fromCircle(center: Offset(x, c.dy), radius: r);
      canvas.drawArc(rect, -math.pi * 0.42, math.pi * 0.84, false, _glow(color, 14, 8, alpha: 0.6));
      canvas.drawArc(rect, -math.pi * 0.42, math.pi * 0.84, false, _glow(Colors.white, 4, 1.5));
      // 風切りの線
      for (int i = 0; i < 4; i++) {
        final y = c.dy + (i - 1.5) * 16;
        canvas.drawLine(Offset(x - 30 - i * 14, y), Offset(x - 90 - i * 24, y), _glow(color, 2.4, 1, alpha: 0.7));
      }
    }
    if (p >= 0.55) {
      final k = ((p - 0.55) / 0.45).clamp(0.0, 1.0);
      canvas.drawCircle(c, 12 + 70 * k, _glow(color, 5 * (1 - k) + 1, 3, alpha: (1 - k) * fade + 0.0));
      canvas.drawCircle(c, 6 + 40 * k, _glow(Colors.white, 3, 2, alpha: (1 - k)));
    }
  }

  // ごうりき: 気を溜めて叩きつけ、2重の衝撃波・地割れ・土煙
  void _heavyBlow(Canvas canvas, Size size, Offset c) {
    final p = _p;
    if (p < 0.3) {
      // 溜め：中心に向かって収束する光
      final k = p / 0.3;
      final r = 90 * (1 - k) + 10;
      canvas.drawCircle(c, r, _glow(color, 4, 4, alpha: 0.4 + 0.6 * k));
      canvas.drawCircle(c, 6 + 16 * k, Paint()..color = Colors.white.withValues(alpha: 0.9 * k));
      return;
    }
    final k = ((p - 0.3) / 0.7).clamp(0.0, 1.0);
    final fade = 1 - k;
    // 衝撃波（2重）
    canvas.drawCircle(c, 20 + 150 * Curves.easeOutCubic.transform(k), _glow(Colors.white, 7 * fade + 1, 3, alpha: fade));
    canvas.drawCircle(c, 10 + 100 * Curves.easeOutCubic.transform(k), _glow(color, 12 * fade + 1, 6, alpha: fade * 0.8));
    // 地割れ（ギザギザの放射線）
    final rng = math.Random(11);
    final crack = _glow(Colors.white, 3, 0.8, alpha: fade);
    for (int i = 0; i < 9; i++) {
      final a = i / 9 * math.pi * 2 + rng.nextDouble() * 0.3;
      var pos = c;
      final path = Path()..moveTo(pos.dx, pos.dy);
      final segs = 4;
      final total = (30 + rng.nextDouble() * 70) * Curves.easeOutCubic.transform(k);
      for (int s = 1; s <= segs; s++) {
        final da = a + (rng.nextDouble() - 0.5) * 0.7;
        pos = c + Offset(math.cos(da), math.sin(da)) * (total * s / segs);
        path.lineTo(pos.dx, pos.dy);
      }
      canvas.drawPath(path, crack);
    }
    // 土煙・破片
    final dust = Paint()..color = color.withValues(alpha: 0.55 * fade);
    for (int i = 0; i < 14; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final d = (20 + rng.nextDouble() * 90) * k;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a) * 0.6) * d, 3 + rng.nextDouble() * 4, dust);
    }
  }

  // きゅうしょ突き: 照準リングが収束 → 一点を貫く鋭いスパイク
  void _weakPoint(Canvas canvas, Size size, Offset c) {
    final p = _p;
    if (p < 0.5) {
      final k = p / 0.5;
      final r = 80 * (1 - Curves.easeInOut.transform(k)) + 14;
      final a = 0.4 + 0.6 * k;
      canvas.drawCircle(c, r, _glow(Colors.white, 2.5, 1, alpha: a));
      canvas.drawLine(c + Offset(-r - 14, 0), c + Offset(r + 14, 0), _glow(color, 2, 1, alpha: a));
      canvas.drawLine(c + Offset(0, -r - 14), c + Offset(0, r + 14), _glow(color, 2, 1, alpha: a));
      return;
    }
    final k = ((p - 0.5) / 0.5).clamp(0.0, 1.0);
    final fade = 1 - k;
    // 一点から放たれる細く長いスパイク
    for (int i = 0; i < 8; i++) {
      final a = i / 8 * math.pi * 2 + math.pi / 8;
      final long = i.isEven;
      final l = (long ? 120.0 : 60.0) * Curves.easeOutExpo.transform(k);
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * 6, c + Offset(math.cos(a), math.sin(a)) * (6 + l),
          _glow(long ? Colors.white : color, long ? 3.2 : 2.4, 1.2, alpha: fade));
    }
    canvas.drawCircle(c, 14 * fade + 3, Paint()..color = Colors.white.withValues(alpha: fade));
    canvas.drawCircle(c, 26 * k + 6, _glow(color, 4 * fade + 1, 3, alpha: fade * 0.9));
  }

  @override
  bool shouldRepaint(MoveEffectPainter old) =>
      old.t != t || old.moveId != moveId || old.color != color;
}
