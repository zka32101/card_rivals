import 'package:flutter/material.dart';
import '../theme/kingdom_theme.dart';
import '../l10n/app_localizations.dart';

class ExplanationScreen extends StatefulWidget {
  const ExplanationScreen({super.key});

  @override
  State<ExplanationScreen> createState() => _ExplanationScreenState();
}

class _ExplanationScreenState extends State<ExplanationScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  List<_ExplanationPage> _buildPages(AppLocalizations t) => [
    _ExplanationPage(
      title: '⚔️ ${t.explanation_page1Title}',
      description: t.explanation_page1Description,
      icon: '⚔️',
      imageId: 'page1_mechanics',
      color: Kingdom.gilt,
      details: [
        t.explanation_page1Detail1,
        t.explanation_page1Detail2,
        t.explanation_page1Detail3,
      ],
    ),
    _ExplanationPage(
      title: '💪 ${t.explanation_page2Title}',
      description: t.explanation_page2Description,
      icon: '💪',
      imageId: 'page2_stats',
      color: Kingdom.joyGold,
      details: [
        t.explanation_page2Detail1,
        t.explanation_page2Detail2,
        t.explanation_page2Detail3,
      ],
    ),
    _ExplanationPage(
      title: '💥 ${t.explanation_page3Title}',
      description: t.explanation_page3Description,
      icon: '💥',
      imageId: 'page3_damage',
      color: Kingdom.angerCrimson,
      details: [
        t.explanation_page3Detail1,
        t.explanation_page3Detail2,
        t.explanation_page3Detail3,
        t.explanation_page3Detail4,
      ],
    ),
    _ExplanationPage(
      title: '🛡️ ${t.explanation_page4Title}',
      description: t.explanation_page4Description,
      icon: '🛡️',
      imageId: 'page4_defense',
      color: Kingdom.sadnessIndigo,
      details: [
        t.explanation_page4Detail1,
        t.explanation_page4Detail2,
        t.explanation_page4Detail3,
      ],
    ),
    _ExplanationPage(
      title: '🌍 ${t.explanation_page5Title}',
      description: t.explanation_page5Description,
      icon: '🌍',
      imageId: 'page5_migration',
      color: Kingdom.joyGold,
      details: [
        t.explanation_page5Detail1,
        t.explanation_page5Detail2,
        t.explanation_page5Detail3,
      ],
    ),
    _ExplanationPage(
      title: '🎴 ${t.explanation_page6Title}',
      description: t.explanation_page6Description,
      icon: '🎴',
      imageId: 'page6_cardtypes',
      color: Kingdom.angerCrimson,
      details: [
        t.explanation_page6Detail1,
        t.explanation_page6Detail2,
        t.explanation_page6Detail3,
      ],
    ),
    _ExplanationPage(
      title: '💰 ${t.explanation_page7Title}',
      description: t.explanation_page7Description,
      icon: '💰',
      imageId: 'page7_rental',
      color: Kingdom.sadnessIndigo,
      details: [
        t.explanation_page7Detail1,
        t.explanation_page7Detail2,
        t.explanation_page7Detail3,
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
        title: Text('📖 ${t.explanation_appBarTitle}', style: Kingdom.title(size: 17)),
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
                    return _ExplanationPageWidget(page: pages[index]);
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
                            label: Text(t.explanation_back),
                          ),
                        ),
                      if (_currentPage > 0) const SizedBox(width: Kingdom.spaceMd),
                      Expanded(
                        child: RoyalButton(
                          label: _currentPage < pages.length - 1 ? t.explanation_next : t.explanation_complete,
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

class _ExplanationPage {
  final String title;
  final String description;
  final String icon;
  final String imageId;
  final Color color;
  final List<String> details;

  _ExplanationPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.imageId,
    required this.color,
    this.details = const [],
  });

  String get imageAsset => 'assets/tutorial/$imageId.png';
}

class _ExplanationPageWidget extends StatelessWidget {
  final _ExplanationPage page;

  const _ExplanationPageWidget({required this.page});

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
              errorBuilder: (_, _, _) => Text(page.icon, style: const TextStyle(fontSize: 80)),
            ),
          ),
          const SizedBox(height: Kingdom.spaceXxl),

          // タイトル
          Text(page.title, style: Kingdom.title(size: 22, color: page.color), textAlign: TextAlign.center),
          const SizedBox(height: Kingdom.spaceLg),

          // 説明
          OrnateFrame(
            accent: page.color,
            padding: const EdgeInsets.all(Kingdom.spaceLg),
            child: Text(
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
                        child: Text(detail,
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
