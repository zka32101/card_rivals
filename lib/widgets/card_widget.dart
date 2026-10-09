import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/card_frame.dart';
import '../providers/card_frame_provider.dart';
import '../models/card_skill.dart';
import '../models/user_card.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';
import 'ui_icon.dart';
import 'ui_icon.dart';

// ローカライズされたカード名を取得（現在のロケールに基づいてJP/EN を切り替え）
String _getCardDisplayName(BuildContext context, PlayCard card) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode == 'en' && card.nameEn.isNotEmpty) {
    return card.nameEn;
  }
  return card.nameJp;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 「感情の国」紋章カード テーマ
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Color rarityColor(CardRarity r) => switch (r) {
      CardRarity.n => const Color(0xFF9A9186), // 鉄
      CardRarity.r => const Color(0xFFB9C6D6), // 銀
      CardRarity.sr => const Color(0xFF6E8FD6), // サファイア
      CardRarity.ur => Kingdom.gilt, // 黄金
    };

// カードアート表示（ローカルバンドルアセット / リモートURL 両対応）
// imageUrlが 'assets/' で始まる場合はImage.asset、それ以外はImage.networkを使う
Widget _cardArt(
  String imageUrl, {
  required BoxFit fit,
  double? width,
  required Widget Function() placeholderBuilder,
}) {
  if (imageUrl.startsWith('assets/')) {
    return Image.asset(
      imageUrl,
      fit: fit,
      width: width,
      errorBuilder: (_, err, stack) => placeholderBuilder(),
    );
  }
  return Image.network(
    imageUrl,
    key: ValueKey(imageUrl),
    fit: fit,
    width: width,
    errorBuilder: (_, err, stack) => placeholderBuilder(),
    // 3D回転Transform(カード開封演出)配下だと、画像フレーム到着時の再描画が
    // 反映されずカードアートが白いまま固まることがあった（実機で確認）。
    // frameBuilderで明示的にAnimatedOpacityを挟むと毎回確実に再合成される。
    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded) return child;
      return AnimatedOpacity(
        opacity: frame == null ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: child,
      );
    },
  );
}

Color _attrPrimary(String? a) => Kingdom.attributeColor(a);

String _attrEmoji(String? a) => switch (a) {
      'joy' => '☀️',
      'anger' => '🔥',
      'sadness' => '🌙',
      _ => '⭐',
    };

// 属性オーブ画像（AI生成アセット）。カード画像未生成時のプレースホルダーで使う。
String _attrOrbAsset(String? a) => switch (a) {
      'joy' => 'assets/theme/orb_joy.png',
      'anger' => 'assets/theme/orb_anger.png',
      'sadness' => 'assets/theme/orb_sadness.png',
      _ => 'assets/theme/orb_joy.png',
    };

// 属性ラベル文字（喜/怒/哀）。既存キー card_attack/defense/speed と同様、
// attribute_joy/anger/sadness（app_ja.arb / app_en.arb 既存）を再利用する。
String _attrLabel(AppLocalizations t, String? a) => switch (a) {
      'joy' => t.attribute_joy,
      'anger' => t.attribute_anger,
      'sadness' => t.attribute_sadness,
      _ => '',
    };

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// フルカードウィジェット
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class CardWidget extends StatelessWidget {
  final PlayCard card;
  final double size;
  final bool isSelected;
  final VoidCallback? onTap;

  /// 一覧用の簡易表示。ステータスをバーではなく数字だけで1行にまとめ、
  /// 属性ラベルも省いて小さいマスでも見切れないようにする。
  final bool compact;

  /// 購入済みカードフレームのID。nullなら従来表示と完全に同一。
  /// 指定時はカード本体をフレームの開口部に収め、外側にフレーム画像を描く
  /// （全体の幅は[size]に揃え、縦が収まらない場合は縮小）。
  final String? frameId;

  const CardWidget({
    super.key,
    required this.card,
    this.size = 150,
    this.isSelected = false,
    this.onTap,
    this.compact = false,
    this.frameId,
  });

  @override
  Widget build(BuildContext context) {
    // カードは size で固定寸法のアート扱い。端末の文字拡大で中身が溢れないよう拡大しない。
    return MediaQuery.withNoTextScaling(child: _buildFramed(context));
  }

  Widget _buildFramed(BuildContext context) {
    final frame = cardFrameById(frameId);
    if (frame == null) return _buildCard(context, size);
    final hole = frame.holeNorm;
    // カード本体は開口部の幅で描くが、幅が狭すぎると文字が収まらないため、基準幅
    // (150) 以上で組んでから全体を[size]幅へ縮小/拡大する（比率は保つ）。
    final inner = (size * hole.width) < 150.0 ? 150.0 : size * hole.width;
    return SizedBox(
      width: size,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: inner / hole.width,
          child: Stack(
            children: [
              _FrameHoleLayout(hole: hole, child: _buildCard(context, inner)),
              Positioned.fill(
                child: IgnorePointer(
                  child: Image.asset(
                    frame.assetPath,
                    fit: BoxFit.fill,
                    errorBuilder: (_, e, s) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, double size) {
    final attr = card.attribute;
    final accent = _attrPrimary(attr);
    final rColor = rarityColor(card.rarity);
    final isUR = card.rarity == CardRarity.ur;
    final isSR = card.rarity == CardRarity.sr;

    final frameColor = isSelected ? Kingdom.gilt : rColor;
    final glowAlpha = isUR ? 0.55 : isSR ? 0.4 : isSelected ? 0.5 : 0.28;
    final glowRadius = isUR ? 16.0 : isSR ? 12.0 : isSelected ? 12.0 : 7.0;
    // レアリティが高いほど枠を太くし、一覧上でも見分けやすくする
    final rarityFrameWidth = switch (card.rarity) {
      CardRarity.n => 1.8,
      CardRarity.r => 2.4,
      CardRarity.sr => 3.0,
      CardRarity.ur => 3.6,
    };
    final frameWidth = isSelected ? rarityFrameWidth + 0.6 : rarityFrameWidth;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: frameColor, width: frameWidth),
          gradient: LinearGradient(
            colors: [Kingdom.nightDeep, Kingdom.night],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: frameColor.withValues(alpha: glowAlpha),
              blurRadius: glowRadius,
              spreadRadius: 1,
            ),
            const BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Header(card: card, accent: accent, compact: compact),
                  _ArtArea(card: card, accent: accent),
                  _TypeBar(card: card, accent: accent),
                  compact ? _CompactStats(card: card) : _StatsSection(card: card),
                ],
              ),
              // UR カードのみ、金箔の光沢が斜めに走る
              if (isUR)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Kingdom.gilt.withValues(alpha: 0.0),
                            Kingdom.gilt.withValues(alpha: 0.10),
                            Kingdom.gilt.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              // 内側ベベル枠 + 装飾角（レアリティで精緻さが増す）
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CardFramePainter(
                      color: frameColor,
                      rarity: card.rarity,
                    ),
                  ),
                ),
              ),
              // レアリティ宝石（上辺中央・SR/UR のみ）
              if (isUR || isSR)
                Positioned(
                  top: 3,
                  left: 0,
                  right: 0,
                  child: Center(child: _RarityGem(color: frameColor)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// カード本体（child）を、フレーム画像の開口部[hole]に収まるように配置し、
/// 全体サイズをフレーム全体の大きさ（本体サイズ ÷ 開口部比率）にするレイアウト。
class _FrameHoleLayout extends SingleChildRenderObjectWidget {
  final FrameHole hole;
  const _FrameHoleLayout({required this.hole, required Widget child}) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFrameHole(hole);

  @override
  void updateRenderObject(BuildContext context, _RenderFrameHole renderObject) {
    renderObject.hole = hole;
  }
}

class _RenderFrameHole extends RenderShiftedBox {
  _RenderFrameHole(this._hole) : super(null);
  FrameHole _hole;
  set hole(FrameHole v) {
    if (v == _hole) return;
    _hole = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(const BoxConstraints(), parentUsesSize: true);
    final w = c.size.width / _hole.width;
    final h = c.size.height / _hole.height;
    size = constraints.constrain(Size(w, h));
    (c.parentData! as BoxParentData).offset = Offset(w * _hole.left, h * _hole.top);
  }
}

/// 自分のカード表示用。装着中のカードフレームを自動で適用する。
class MyCardWidget extends ConsumerWidget {
  final PlayCard card;
  final double size;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool compact;
  const MyCardWidget({
    super.key,
    required this.card,
    this.size = 150,
    this.isSelected = false,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => CardWidget(
        card: card,
        size: size,
        isSelected: isSelected,
        onTap: onTap,
        compact: compact,
        frameId: ref.watch(equippedFrameIdProvider),
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// カード専用の精緻な枠 — 内側ベベル線 + 角の飾りフラリッシュ
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _CardFramePainter extends CustomPainter {
  final Color color;
  final CardRarity rarity;
  _CardFramePainter({required this.color, required this.rarity});

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // ── 内側ベベル（二重線）: レアリティが高いほど内枠を強調 ──
    final inset = 4.0;
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2),
      const Radius.circular(7),
    );
    line
      ..color = color.withValues(alpha: rarity == CardRarity.n ? 0.22 : 0.4)
      ..strokeWidth = 0.8;
    canvas.drawRRect(innerRect, line);

    // ── 角の飾り（L字 + 対角フラリッシュ + 宝石ドット） ──
    final ornate = rarity == CardRarity.sr || rarity == CardRarity.ur;
    final len = ornate ? 15.0 : 11.0;
    final flourish = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ornate ? 1.5 : 1.1
      ..strokeCap = StrokeCap.round;
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    void corner(Offset o, double sx, double sy) {
      // L字
      canvas.drawLine(o, o + Offset(len * sx, 0), flourish);
      canvas.drawLine(o, o + Offset(0, len * sy), flourish);
      // 対角の短い飾り線（SR/UR のみ）
      if (ornate) {
        canvas.drawLine(o + Offset(3 * sx, 3 * sy), o + Offset(9 * sx, 9 * sy), flourish);
      }
      // 宝石ドット
      canvas.drawCircle(o, ornate ? 2.4 : 1.8, dot);
    }

    const m = 2.5;
    corner(Offset(m, m), 1, 1);
    corner(Offset(size.width - m, m), -1, 1);
    corner(Offset(m, size.height - m), 1, -1);
    corner(Offset(size.width - m, size.height - m), -1, -1);
  }

  @override
  bool shouldRepaint(_CardFramePainter old) => old.color != color || old.rarity != rarity;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// レアリティ宝石 — 上辺中央の菱形カット宝石
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _RarityGem extends StatelessWidget {
  final Color color;
  const _RarityGem({required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398, // 45°
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.white, 0.5)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Kingdom.parchment.withValues(alpha: 0.7), width: 0.6),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 4)],
        ),
      ),
    );
  }
}

/// CardWidgetをグリッドに並べるときの1マスの高さ。
/// カードは「正方形のアート + ヘッダー/種別/ステータス3行」の縦積みなので、幅に応じて
/// 高さを決めないと固定の縦横比ではステータスが見切れる。
/// [compact]（数字だけの簡易表示）は縦が短く済む。グリッド側は上寄せ(Align)で描画して
/// 余白は下に逃がすので、見切れない側に少し余裕を持たせてある。
double cardGridItemHeight(double itemWidth, {bool compact = false}) =>
    itemWidth + (compact ? 104 : 166);

// ─── ヘッダー（属性紋章 + 名前 + コスト） ───
class _Header extends StatelessWidget {
  final PlayCard card;
  final Color accent;
  final bool compact;
  const _Header({required this.card, required this.accent, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Kingdom.nightDeep,
        border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.7), width: 1.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            Row(
              children: [
                IconText(_attrEmoji(card.attribute), style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Flexible(
                  child: IconText(Kingdom.attributeRealm(card.attribute, AppLocalizations.of(context)!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Kingdom.label(size: 8, color: accent.withValues(alpha: 0.85))),
                ),
              ],
            ),
            const SizedBox(height: 3),
          ],
          Row(
            children: [
              if (compact) ...[
                IconText(_attrEmoji(card.attribute), style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: IconText(
                  _getCardDisplayName(context, card),
                  style: TextStyle(
                    fontFamily: Kingdom.displayFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Kingdom.parchment,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              if (card.skillId != null) ...[
                IconText(cardSkillIsPassive(card.skillId!) ? '🛡️' : '⚡', style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 2),
              ],
              if (card.moveId != null) ...[
                const IconText('✨', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 2),
              ],
              WaxSealBadge(text: '${card.cost}', color: accent, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── アートエリア ───
class _ArtArea extends StatelessWidget {
  final PlayCard card;
  final Color accent;
  const _ArtArea({required this.card, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(5, 5, 5, 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.85), width: 1.4),
        boxShadow: [
          // 額縁が浮き上がって見えるよう内側に軽い陰
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              card.imageUrl.isNotEmpty
                  ? _cardArt(
                      card.imageUrl,
                      fit: BoxFit.cover,
                      placeholderBuilder: () => _ArtPlaceholder(card: card),
                    )
                  : _ArtPlaceholder(card: card),
              // 上部からの微光沢（額のガラス感）
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // 内側の細い金線
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Kingdom.parchment.withValues(alpha: 0.12), width: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtPlaceholder extends StatelessWidget {
  final PlayCard card;
  const _ArtPlaceholder({required this.card});

  @override
  Widget build(BuildContext context) {
    final attrColor = _attrPrimary(card.attribute);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Kingdom.attributeGradient(card.attribute),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      // 小さいカード枠でも中身が溢れないよう、収まらないときは縮小する
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              _attrOrbAsset(card.attribute),
              width: 56,
              height: 56,
              errorBuilder: (_, __, ___) => IconText(_attrEmoji(card.attribute),
                  style: TextStyle(
                    fontSize: 48,
                    shadows: [Shadow(color: attrColor.withValues(alpha: 0.7), blurRadius: 14)],
                  )),
            ),
            const SizedBox(height: 8),
            IconText(Kingdom.attributeRealm(card.attribute, AppLocalizations.of(context)!),
                textAlign: TextAlign.center,
                style: Kingdom.label(size: 9, color: attrColor)),
          ],
        ),
        ),
      ),
    );
  }
}

// ─── タイプバー（属性ラベル + レアリティ紋章） ───
class _TypeBar extends StatelessWidget {
  final PlayCard card;
  final Color accent;
  const _TypeBar({required this.card, required this.accent});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final rColor = rarityColor(card.rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Kingdom.nightDeep,
        border: Border(
          top: BorderSide(color: accent.withValues(alpha: 0.5), width: 0.8),
          bottom: BorderSide(color: accent.withValues(alpha: 0.5), width: 0.8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconText(_attrLabel(t, card.attribute), style: Kingdom.label(size: 10, color: accent)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: rColor, width: 1.0),
              borderRadius: BorderRadius.circular(3),
              color: rColor.withValues(alpha: 0.12),
            ),
            child: IconText(card.rarityLabel,
                style: TextStyle(
                  fontFamily: Kingdom.displayFont,
                  fontSize: 9,
                  color: rColor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                )),
          ),
        ],
      ),
    );
  }
}

// ─── ステータス ───
class _StatsSection extends StatelessWidget {
  final PlayCard card;
  const _StatsSection({required this.card});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final maxStat = (card.cost * 8 + 12).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        children: [
          _StatRow(icon: '⚔', label: t.card_attack, value: card.attackPower, maxVal: maxStat, color: Kingdom.angerCrimson),
          const SizedBox(height: 3),
          _StatRow(icon: '🛡', label: t.card_defense, value: card.defensePower, maxVal: maxStat, color: Kingdom.sadnessIndigo),
          const SizedBox(height: 3),
          _StatRow(icon: '⚡', label: t.card_speed, value: card.speed, maxVal: maxStat, color: Kingdom.joyGold),
        ],
      ),
    );
  }
}

// ─── 一覧用ステータス（数字だけを1行で） ───
class _CompactStats extends StatelessWidget {
  final PlayCard card;
  const _CompactStats({required this.card});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    Widget stat(String icon, String label, int v, Color color) => Semantics(
          label: '$label $v',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconText(icon, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 2),
              Text('$v',
                  style: TextStyle(
                    fontFamily: Kingdom.displayFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: color,
                  )),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 7),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            stat('⚔', t.card_attack, card.attackPower, Kingdom.angerCrimson),
            const SizedBox(width: 8),
            stat('🛡', t.card_defense, card.defensePower, Kingdom.sadnessIndigo),
            const SizedBox(width: 8),
            stat('⚡', t.card_speed, card.speed, Kingdom.joyGold),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String icon;
  final String label;
  final int value;
  final double maxVal;
  final Color color;
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.maxVal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (value / maxVal).clamp(0.0, 1.0);
    return Semantics(
      label: '$label $value',
      child: Row(
      children: [
        SizedBox(width: 14, child: IconText(icon, style: const TextStyle(fontSize: 9))),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: Kingdom.parchment.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(colors: [color.withValues(alpha: 0.7), color]),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        SizedBox(
          width: 22,
          child: Text(
            '$value',
            style: TextStyle(
              fontFamily: Kingdom.displayFont,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Kingdom.parchment.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// サムネイル（デッキ選択・バトルゾーン用）
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class CardThumbnail extends StatelessWidget {
  final PlayCard card;
  final double size;
  final bool isSelected;
  final VoidCallback? onTap;

  const CardThumbnail({
    super.key,
    required this.card,
    this.size = 80,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _attrPrimary(card.attribute);
    final rColor = rarityColor(card.rarity);
    // レアリティが高いほど枠を太くし、一覧上でも見分けやすくする
    final rarityFrameWidth = switch (card.rarity) {
      CardRarity.n => 1.4,
      CardRarity.r => 1.9,
      CardRarity.sr => 2.4,
      CardRarity.ur => 2.9,
    };

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size * 1.28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Kingdom.gilt : accent,
                width: isSelected ? rarityFrameWidth + 0.6 : rarityFrameWidth,
              ),
              gradient: LinearGradient(
                colors: [Kingdom.nightDeep, Kingdom.night],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: Kingdom.gilt.withValues(alpha: 0.45), blurRadius: 8)]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Column(
                children: [
                  Expanded(
                    child: card.imageUrl.isNotEmpty
                        ? _cardArt(
                            card.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholderBuilder: () => _thumbPlaceholder(context, card, accent),
                          )
                        : _thumbPlaceholder(context, card, accent),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    decoration: BoxDecoration(
                      color: Kingdom.nightDeep,
                      border: Border(top: BorderSide(color: accent.withValues(alpha: 0.6), width: 0.8)),
                    ),
                    child: IconText(
                      _getCardDisplayName(context, card),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: Kingdom.displayFont,
                        fontSize: 8,
                        color: Kingdom.parchment,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Kingdom.gilt,
                  shape: BoxShape.circle,
                  border: Border.all(color: Kingdom.night, width: 1),
                ),
                child: const Icon(Icons.check, size: 10, color: Kingdom.night),
              ),
            ),
          if (card.isCoCreated)
            Positioned(
              bottom: 20,
              right: 3,
              child: WaxSealBadge(text: '🤝', color: Kingdom.sadnessIndigo, size: 16),
            ),
          if (card.rarity != CardRarity.n)
            Positioned(
              bottom: 20,
              left: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: rColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: IconText(
                  card.rarityLabel,
                  style: const TextStyle(fontSize: 6, color: Kingdom.night, fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder(BuildContext context, PlayCard card, Color accent) {
    final t = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: Kingdom.attributeGradient(card.attribute),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconText(_attrEmoji(card.attribute), style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              IconText(_attrLabel(t, card.attribute),
                  style: Kingdom.label(size: 8, color: accent)),
            ],
          ),
        ),
      ),
    );
  }
}
