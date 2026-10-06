import 'package:flutter/material.dart';

/// 画面で使うアイコン画像（絵文字の置き換え用）。assets/ui_icons/ の11枚。
///
/// 例: `UiIcon.coin(size: 18)` や、文章中に並べる場合は `UiIconText` を使う。
enum UiIconKind {
  coin('coin', '🪙'),
  gem('gem', '💎'),
  attrJoy('attr_joy', '☀️'),
  attrAnger('attr_anger', '🔥'),
  attrSadness('attr_sadness', '🌙'),
  statAttack('stat_attack', '⚔️'),
  statDefense('stat_defense', '🛡️'),
  statSpeed('stat_speed', '⚡'),
  medalGold('medal_gold', '🥇'),
  medalSilver('medal_silver', '🥈'),
  medalBronze('medal_bronze', '🥉');

  const UiIconKind(this.fileName, this.emoji);

  final String fileName;

  /// 置き換え前の絵文字（画像が読めない場合の代わりに出す）。
  final String emoji;

  String get assetPath => 'assets/ui_icons/$fileName.png';
}

class UiIcon extends StatelessWidget {
  const UiIcon(this.kind, {super.key, this.size = 20});

  const UiIcon.coin({Key? key, double size = 20}) : this(UiIconKind.coin, key: key, size: size);
  const UiIcon.gem({Key? key, double size = 20}) : this(UiIconKind.gem, key: key, size: size);

  final UiIconKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kind.assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      // 画像が無い/壊れている場合は、元の絵文字を出す（画面を壊さない）。
      errorBuilder: (_, _, _) => Text(kind.emoji, style: TextStyle(fontSize: size * 0.85)),
    );
  }
}

/// 「アイコン + 数字」の横並び（コイン残高・ステータスなど）。
class UiIconText extends StatelessWidget {
  const UiIconText(this.kind, this.text, {super.key, this.size = 18, this.style});

  final UiIconKind kind;
  final String text;
  final double size;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UiIcon(kind, size: size),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: style, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
