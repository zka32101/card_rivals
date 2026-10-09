import 'package:flutter/material.dart';
import '../theme/kingdom_theme.dart';
import '../utils/safe_pop.dart';
import '../l10n/app_localizations.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final sections = [
      (t.terms_section1Title, t.terms_section1Body),
      (t.terms_section2Title, t.terms_section2Body),
      (t.terms_section3Title, t.terms_section3Body),
      (t.terms_section4Title, t.terms_section4Body),
      (t.terms_section5Title, t.terms_section5Body),
      (t.terms_section6Title, t.terms_section6Body),
    ];

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text(t.settings_termsOfService, style: Kingdom.title(size: 17)),
        backgroundColor: Kingdom.nightDeep,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Kingdom.gilt),
          onPressed: () => context.popOrHome(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Kingdom.spaceLg),
          children: [
            Text(t.terms_lastUpdated, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.5), fontSize: 11)),
            const SizedBox(height: Kingdom.spaceLg),
            for (final (title, body) in sections) ...[
              Text(title, style: Kingdom.title(size: 15)),
              const SizedBox(height: Kingdom.spaceSm),
              Text(body, style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.85), fontSize: 13, height: 1.6)),
              const SizedBox(height: Kingdom.spaceXl),
            ],
          ],
        ),
      ),
    );
  }
}
