import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/kingdom_theme.dart';
import '../utils/safe_pop.dart';
import '../l10n/app_localizations.dart';

const String kSupportEmail = 'petitworksdev@gmail.com';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _openMailApp(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    final uri = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      query: 'subject=${Uri.encodeComponent(t.contact_emailSubject)}',
    );
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      _copyEmail(context);
    }
  }

  void _copyEmail(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    Clipboard.setData(const ClipboardData(text: kSupportEmail));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.contact_emailCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text(t.settings_contactUs, style: Kingdom.title(size: 17)),
        backgroundColor: Kingdom.nightDeep,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Kingdom.gilt),
          onPressed: () => context.popOrHome(),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 10)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Kingdom.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.contact_intro,
                      style: TextStyle(color: Kingdom.parchment.withValues(alpha: 0.85), fontSize: 14, height: 1.6)),
                  const SizedBox(height: Kingdom.spaceXl),
                  OrnateFrame(
                    accent: Kingdom.gilt,
                    child: Row(
                      children: [
                        const Icon(Icons.email_outlined, color: Kingdom.gilt),
                        const SizedBox(width: Kingdom.spaceMd),
                        Expanded(
                          child: Text(kSupportEmail,
                              style: const TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, color: Kingdom.parchment.withValues(alpha: 0.6), size: 18),
                          onPressed: () => _copyEmail(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Kingdom.spaceLg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openMailApp(context),
                      icon: const Icon(Icons.send),
                      label: Text(t.contact_sendEmailButton),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Kingdom.gilt,
                        foregroundColor: Kingdom.night,
                        padding: const EdgeInsets.symmetric(vertical: Kingdom.spaceMd),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
