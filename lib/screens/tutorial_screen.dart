import 'package:flutter/material.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ui_icon.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  List<_TutorialPage> _buildPages(AppLocalizations t) => [
    _TutorialPage(
      title: '🎮 ${t.tutorial_page1Title}',
      description: t.tutorial_page1Description,
      icon: '🎴',
      imageId: 'page1_welcome',
      color: Kingdom.gilt,
    ),
    _TutorialPage(
      title: '☀️ ${t.tutorial_page2Title}',
      description: t.tutorial_page2Description,
      icon: '☀️',
      imageId: 'page2_joy',
      color: Kingdom.joyGold,
      details: [
        t.tutorial_page2Detail1,
        t.tutorial_page2Detail2,
        t.tutorial_page2Detail3,
      ],
    ),
    _TutorialPage(
      title: '🔥 ${t.tutorial_page3Title}',
      description: t.tutorial_page3Description,
      icon: '🔥',
      imageId: 'page3_anger',
      color: Kingdom.angerCrimson,
      details: [
        t.tutorial_page3Detail1,
        t.tutorial_page3Detail2,
        t.tutorial_page3Detail3,
      ],
    ),
    _TutorialPage(
      title: '🌙 ${t.tutorial_page4Title}',
      description: t.tutorial_page4Description,
      icon: '🌙',
      imageId: 'page4_sadness',
      color: Kingdom.sadnessIndigo,
      details: [
        t.tutorial_page4Detail1,
        t.tutorial_page4Detail2,
        t.tutorial_page4Detail3,
      ],
    ),
    _TutorialPage(
      title: '⚔️ ${t.tutorial_page5Title}',
      description: t.tutorial_page5Description,
      icon: '⚔️',
      imageId: 'page5_battle',
      color: Kingdom.angerCrimson,
      details: [
        t.tutorial_page5Detail1,
        t.tutorial_page5Detail2,
        t.tutorial_page5Detail3,
        t.tutorial_page5Detail4,
      ],
    ),
    _TutorialPage(
      title: '🎯 ${t.tutorial_page6Title}',
      description: t.tutorial_page6Description,
      icon: '🎴',
      imageId: 'page6_deck',
      color: Kingdom.sadnessIndigo,
      details: [
        t.tutorial_page6Detail1,
        t.tutorial_page6Detail2,
        t.tutorial_page6Detail3,
        t.tutorial_page6Detail4,
      ],
    ),
    _TutorialPage(
      title: '💰 ${t.tutorial_page7Title}',
      description: t.tutorial_page7Description,
      icon: '💰',
      imageId: 'page7_economy',
      color: Kingdom.joyGold,
      details: [
        t.tutorial_page7Detail1,
        t.tutorial_page7Detail2,
        t.tutorial_page7Detail3,
        t.tutorial_page7Detail4,
      ],
    ),
    _TutorialPage(
      title: '📊 ${t.tutorial_page8Title}',
      description: t.tutorial_page8Description,
      icon: '🏆',
      imageId: 'page8_rating',
      color: Kingdom.sadnessIndigo,
      details: [
        t.tutorial_page8Detail1,
        t.tutorial_page8Detail2,
        t.tutorial_page8Detail3,
        t.tutorial_page8Detail4,
      ],
    ),
    _TutorialPage(
      title: '🚀 ${t.tutorial_page9Title}',
      description: t.tutorial_page9Description,
      icon: '🎮',
      imageId: 'page9_start',
      color: Kingdom.gilt,
      details: [
        t.tutorial_page9Detail1,
        t.tutorial_page9Detail2,
        t.tutorial_page9Detail3,
        t.tutorial_page9Detail4,
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final pages = _buildPages(t);
    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text('📖 ${t.tutorial_appBarTitle}', style: Kingdom.title(size: 17)),
        elevation: 0,
        backgroundColor: Kingdom.nightDeep,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 12)),
          Column(
        children: [
          // プログレスバー
          Padding(
            padding: const EdgeInsets.all(Kingdom.spaceLg),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / pages.length,
                backgroundColor: Kingdom.nightDeep,
                valueColor: const AlwaysStoppedAnimation<Color>(Kingdom.gilt),
                minHeight: 6,
              ),
            ),
          ),

          // ページコンテンツ
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: pages.length,
              itemBuilder: (context, index) {
                return _TutorialPageWidget(page: pages[index]);
              },
            ),
          ),

          // ナビゲーション
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Kingdom.spaceLg),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Kingdom.parchment.withValues(alpha: 0.4)),
                          foregroundColor: Kingdom.parchment,
                        ),
                        icon: const Icon(Icons.arrow_back),
                        label: IconText(t.tutorial_back),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: Kingdom.spaceMd),
                  Expanded(
                    child: RoyalButton(
                      label: _currentPage < pages.length - 1 ? t.tutorial_next : t.tutorial_complete,
                      icon: _currentPage < pages.length - 1 ? Icons.arrow_forward : Icons.check,
                      onPressed: () {
                        if (_currentPage < pages.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
          ),
        ],
      ),
    );
  }
}

class _TutorialPage {
  final String title;
  final String description;
  final String icon;
  final String imageId;
  final Color color;
  final List<String> details;

  _TutorialPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.imageId,
    required this.color,
    this.details = const [],
  });

  String get imageAsset => 'assets/tutorial/$imageId.png';
}

class _TutorialPageWidget extends StatelessWidget {
  final _TutorialPage page;

  const _TutorialPageWidget({required this.page});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Kingdom.spaceXxl),
      child: Column(
        children: [
          const SizedBox(height: Kingdom.spaceXxl),
          // アイコン
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              page.imageAsset,
              width: 180,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => IconText(page.icon, style: const TextStyle(fontSize: 80)),
            ),
          ),
          const SizedBox(height: Kingdom.spaceXxl),

          // タイトル
          IconText(page.title, style: Kingdom.title(size: 22, color: page.color), textAlign: TextAlign.center),
          const SizedBox(height: Kingdom.spaceLg),

          // 説明
          OrnateFrame(
            accent: page.color,
            padding: const EdgeInsets.all(Kingdom.spaceLg),
            child: IconText(
              page.description,
              style: TextStyle(fontSize: Kingdom.textSubheading, height: 1.6, color: Kingdom.parchment.withValues(alpha: 0.9)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Kingdom.spaceXxl),

          // 詳細情報
          if (page.details.isNotEmpty) ...[
            Column(
              children: page.details.map((detail) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: Kingdom.spaceMd),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(color: page.color, shape: BoxShape.circle),
                        child: Center(
                          child: Text('✓', style: TextStyle(color: Kingdom.night, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: Kingdom.spaceMd),
                      Expanded(
                        child: IconText(detail,
                            style: TextStyle(fontSize: Kingdom.textBody, height: 1.5, color: Kingdom.parchment.withValues(alpha: 0.8))),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
