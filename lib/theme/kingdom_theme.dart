import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 「感情の国」ファンタジー王国 デザインシステム
// 喜=黄金の大陸 / 怒=火山の大陸 / 哀=深夜の森と湖
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class Kingdom {
  Kingdom._();

  // ─── ベースパレット ───────────────────────
  static const Color parchment = Color(0xFFEFE3C8); // 羊皮紙
  static const Color parchmentDark = Color(0xFFD8C69E);
  static const Color ink = Color(0xFF2B2013); // 深い焦茶（本文色）
  static const Color night = Color(0xFF120E1E); // 夜空・背景
  static const Color nightDeep = Color(0xFF0A0714);
  static const Color bronze = Color(0xFF8C6A3F); // 縁取り・金具
  static const Color gilt = Color(0xFFC9A24B); // 金箔ハイライト

  // ─── 属性カラー（王国別） ───────────────────
  static const Color joyGold = Color(0xFFE8B93A); // 希望の君主・黄金の大陸
  static const Color joyGoldDeep = Color(0xFFB8860B);
  static const Color angerCrimson = Color(0xFFB33A2E); // 怒りの王・火山の大陸
  static const Color angerCrimsonDeep = Color(0xFF7A1F17);
  static const Color sadnessIndigo = Color(0xFF35538C); // 悲しみの王・深夜の森
  static const Color sadnessIndigoDeep = Color(0xFF1E2E52);
  static const Color lightSkyBlue = Color(0xFF6BA3D4); // シーズン・ボーナス色

  static Color attributeColor(String? attribute) => switch (attribute) {
        'joy' => joyGold,
        'anger' => angerCrimson,
        'sadness' => sadnessIndigo,
        _ => bronze,
      };

  static Color attributeColorDeep(String? attribute) => switch (attribute) {
        'joy' => joyGoldDeep,
        'anger' => angerCrimsonDeep,
        'sadness' => sadnessIndigoDeep,
        _ => bronze,
      };

  static String attributeRealm(String? attribute, AppLocalizations t) => switch (attribute) {
        'joy' => t.cardCreation_attrJoyRealm,
        'anger' => t.cardCreation_attrAngerRealm,
        'sadness' => t.cardCreation_attrSadnessRealm,
        _ => t.kingdom_defaultRealm,
      };

  static List<Color> attributeGradient(String? attribute) => switch (attribute) {
        'joy' => [const Color(0xFF2A1F08), const Color(0xFF3D2C0A)],
        'anger' => [const Color(0xFF250A06), const Color(0xFF3A120A)],
        'sadness' => [const Color(0xFF060A18), const Color(0xFF0C1428)],
        _ => [nightDeep, night],
      };

  // ─── 余白スケール ───────────────────────────
  // 全画面で使う統一スペーシング（4の倍数ベース）。ad-hocな数値の代わりにこれを使う。
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double spaceXxl = 24;
  static const double spaceXxxl = 32;

  // ─── タップ領域 ─────────────────────────────
  // WCAG/Material推奨に沿った最小タップターゲット（アイコンボタン等はこれ以上を確保する）
  static const double minTapTarget = 48;

  // ─── タイポグラフィ ─────────────────────────
  // 装飾用の見出し書体（プラットフォーム標準セリフで代替、追加アセット不要）
  static const String displayFont = 'serif';

  // 統一タイプスケール（画面ごとにバラついていたfontSizeの基準値）
  static const double textDisplay = 28; // 画面タイトル・勝敗表示など
  static const double textHeading = 20; // セクション見出し
  static const double textSubheading = 15; // カード見出し・強調ラベル
  static const double textBody = 13; // 本文・説明文
  static const double textCaption = 11; // 補足・メタ情報

  static TextStyle title({double size = 20, Color color = gilt}) => TextStyle(
        fontFamily: displayFont,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: color,
        shadows: const [
          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
        ],
      );

  static TextStyle label({double size = 12, Color color = parchment}) => TextStyle(
        fontFamily: displayFont,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: color,
      );

  // 本文用の標準スタイル（説明文・補足テキストなど）。sansの方が長文の可読性が高いため
  // 装飾フォント(displayFont)ではなくプラットフォーム標準のsansを使う。
  static TextStyle body({double size = textBody, Color? color, FontWeight weight = FontWeight.normal}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color ?? parchment.withValues(alpha: 0.75),
        height: 1.4,
      );

  // ─── ThemeData ─────────────────────────────
  static ThemeData materialTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: night,
      colorScheme: ColorScheme.fromSeed(
        seedColor: gilt,
        brightness: Brightness.dark,
        primary: gilt,
        secondary: bronze,
        surface: nightDeep,
      ),
      fontFamily: displayFont,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        titleTextStyle: title(size: 18),
        iconTheme: const IconThemeData(color: gilt),
      ),
      textTheme: const TextTheme().apply(
        bodyColor: parchment,
        displayColor: gilt,
        fontFamily: displayFont,
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 紋章枠 CustomPainter — 角に小さな装飾フラリッシュを描く
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class CrestCornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  CrestCornerPainter({required this.color, this.strokeWidth = 1.4});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    const len = 14.0;

    void corner(Offset origin, Offset dx, Offset dy) {
      canvas.drawLine(origin, origin + dx, paint);
      canvas.drawLine(origin, origin + dy, paint);
      canvas.drawCircle(origin, 2.0, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
    }

    corner(const Offset(2, 2), const Offset(len, 0), const Offset(0, len));
    corner(Offset(size.width - 2, 2), Offset(-len, 0), const Offset(0, len));
    corner(Offset(2, size.height - 2), const Offset(len, 0), Offset(0, -len));
    corner(Offset(size.width - 2, size.height - 2), Offset(-len, 0), Offset(0, -len));
  }

  @override
  bool shouldRepaint(CrestCornerPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 紋章枠付きコンテナ — 王国調カード/パネルの共通外枠
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class OrnateFrame extends StatelessWidget {
  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final double borderRadius;
  final bool showCorners;

  const OrnateFrame({
    super.key,
    required this.child,
    this.accent = Kingdom.gilt,
    this.padding = const EdgeInsets.all(14),
    this.gradient,
    this.borderRadius = 14,
    this.showCorners = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ??
            LinearGradient(
              colors: [Kingdom.nightDeep, Kingdom.night],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: accent.withValues(alpha: 0.65), width: 1.4),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: Stack(
        children: [
          Padding(padding: padding, child: child),
          if (showCorners)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: CrestCornerPainter(color: accent.withValues(alpha: 0.8)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 蝋印バッジ — レアリティ・実績などの丸章表示
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class WaxSealBadge extends StatelessWidget {
  final String text;
  final Color color;
  final double size;

  const WaxSealBadge({super.key, required this.text, this.color = Kingdom.angerCrimson, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.85), color],
        ),
        border: Border.all(color: Kingdom.gilt.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
          const BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w900,
          fontFamily: Kingdom.displayFont,
          color: Kingdom.parchment,
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 王家風ボタン — 金箔グラデーション + 紋章枠
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class RoyalButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final IconData? icon;
  final double height;

  const RoyalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.accent = Kingdom.gilt,
    this.icon,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: disabled
                ? [Colors.grey[700]!, Colors.grey[800]!]
                : [accent, Color.lerp(accent, Colors.black, 0.4)!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Kingdom.gilt.withValues(alpha: disabled ? 0.2 : 0.7), width: 1.4),
          boxShadow: disabled
              ? null
              : [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: Kingdom.night),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: Kingdom.displayFont,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.6,
                    color: disabled ? Colors.grey[400] : Kingdom.night,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 感情の光粒フィールド — 三大陸の色をした光がゆっくり漂う環境背景
// 自己完結型（呼び出し側にコントローラー不要）。画面全体の背面に敷く。
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class EmotionMoteField extends StatefulWidget {
  final int count;
  const EmotionMoteField({super.key, this.count = 20});

  @override
  State<EmotionMoteField> createState() => _EmotionMoteFieldState();
}

class _EmotionMoteFieldState extends State<EmotionMoteField> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Mote> _motes;

  @override
  void initState() {
    super.initState();
    // 決定論的シード（乱数の再現性・Date.now非依存）
    final rng = math.Random(7);
    const realmColors = [Kingdom.joyGold, Kingdom.angerCrimson, Kingdom.sadnessIndigo];
    _motes = List.generate(widget.count, (i) {
      return _Mote(
        x: rng.nextDouble(),
        baseY: rng.nextDouble(),
        radius: 1.2 + rng.nextDouble() * 2.4,
        speed: 0.02 + rng.nextDouble() * 0.05,
        drift: (rng.nextDouble() - 0.5) * 0.04,
        phase: rng.nextDouble(),
        color: realmColors[i % 3],
      );
    });
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => CustomPaint(
            painter: _MoteFieldPainter(motes: _motes, t: _c.value),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _Mote {
  final double x, baseY, radius, speed, drift, phase;
  final Color color;
  _Mote({
    required this.x,
    required this.baseY,
    required this.radius,
    required this.speed,
    required this.drift,
    required this.phase,
    required this.color,
  });
}

class _MoteFieldPainter extends CustomPainter {
  final List<_Mote> motes;
  final double t;
  _MoteFieldPainter({required this.motes, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final m in motes) {
      // ゆっくり上昇＋横ドリフト、上端で下に回り込む
      final prog = (m.baseY - (t * m.speed * 20) + m.phase) % 1.0;
      final y = prog * size.height;
      final x = ((m.x + math.sin((t + m.phase) * math.pi * 2) * m.drift) % 1.0) * size.width;
      // 明滅
      final twinkle = 0.35 + 0.35 * (0.5 + 0.5 * math.sin((t + m.phase) * math.pi * 4));
      paint.color = m.color.withValues(alpha: twinkle * 0.5);
      // 淡いハロー
      canvas.drawCircle(Offset(x, y), m.radius * 2.6, paint..color = m.color.withValues(alpha: twinkle * 0.08));
      canvas.drawCircle(Offset(x, y), m.radius, paint..color = m.color.withValues(alpha: twinkle * 0.5));
    }
  }

  @override
  bool shouldRepaint(_MoteFieldPainter old) => old.t != t;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 王家の紋章タイトル — アプリバー用（三大陸の三日月＋タイトル＋副題）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class CrestTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const CrestTitle({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 三大陸の紋章（喜・怒・哀の三色の菱形）
        SizedBox(
          width: 22,
          height: 22,
          child: CustomPaint(painter: _TriRealmCrestPainter()),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Kingdom.title(size: 17)),
            Text(subtitle,
                style: TextStyle(
                  fontFamily: Kingdom.displayFont,
                  fontSize: 8,
                  letterSpacing: 1.5,
                  color: Kingdom.gilt.withValues(alpha: 0.6),
                )),
          ],
        ),
      ],
    );
  }
}

class _TriRealmCrestPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.5;
    const colors = [Kingdom.joyGold, Kingdom.angerCrimson, Kingdom.sadnessIndigo];
    final paint = Paint()..style = PaintingStyle.fill;
    // 三色の小菱形を三角配置
    for (int i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + i * (math.pi * 2 / 3);
      final px = cx + math.cos(angle) * r * 0.5;
      final py = cy + math.sin(angle) * r * 0.5;
      paint.color = colors[i];
      final path = Path()
        ..moveTo(px, py - 3)
        ..lineTo(px + 3, py)
        ..lineTo(px, py + 3)
        ..lineTo(px - 3, py)
        ..close();
      canvas.drawPath(path, paint);
    }
    // 中央の金環
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.28,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Kingdom.gilt,
    );
  }

  @override
  bool shouldRepaint(_TriRealmCrestPainter old) => false;
}
