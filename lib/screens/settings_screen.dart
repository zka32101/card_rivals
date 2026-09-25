import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../theme/kingdom_theme.dart';

const String kPrivacyPolicyUrl = 'https://sites.google.com/view/yourwishapps/privacy-policy';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: Kingdom.night,
      appBar: AppBar(
        title: Text(t.settings_title, style: Kingdom.title(size: 17)),
        backgroundColor: Kingdom.nightDeep,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Kingdom.gilt),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: EmotionMoteField(count: 10)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(Kingdom.spaceLg),
              children: [
                _SectionLabel(t.settings_bonusSection),
                const SizedBox(height: Kingdom.spaceMd),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      title: t.settings_myBonus,
                      onTap: () => context.push('/bonus-detail'),
                    ),
                  ],
                ),
                const SizedBox(height: Kingdom.spaceXxl),

                _SectionLabel(t.settings_purchaseHistorySection),
                const SizedBox(height: Kingdom.spaceMd),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      title: t.settings_purchaseHistory,
                      onTap: () => context.push('/purchase-history'),
                    ),
                  ],
                ),
                const SizedBox(height: Kingdom.spaceXxl),

                _SectionLabel(t.settings_languageSection),
                const SizedBox(height: Kingdom.spaceMd),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      title: t.settings_japanese,
                      trailingIcon: locale.languageCode == 'ja' ? Icons.check : null,
                      selected: locale.languageCode == 'ja',
                      onTap: () => ref.read(localeProvider.notifier).setLocale(const Locale('ja')),
                    ),
                    _divider(),
                    _SettingsTile(
                      title: t.settings_english,
                      trailingIcon: locale.languageCode == 'en' ? Icons.check : null,
                      selected: locale.languageCode == 'en',
                      onTap: () => ref.read(localeProvider.notifier).setLocale(const Locale('en')),
                    ),
                  ],
                ),
                const SizedBox(height: Kingdom.spaceXxl),

                _SectionLabel(t.settings_infoSection),
                const SizedBox(height: Kingdom.spaceMd),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      title: t.settings_privacyPolicy,
                      trailingIcon: Icons.open_in_new,
                      onTap: () => _openPrivacyPolicy(context),
                    ),
                    _divider(),
                    _SettingsTile(
                      title: t.settings_termsOfService,
                      onTap: () => context.push('/terms'),
                    ),
                    _divider(),
                    _SettingsTile(
                      title: t.settings_contactUs,
                      onTap: () => context.push('/contact'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: Kingdom.parchment.withValues(alpha: 0.1));

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final launched = await launchUrl(Uri.parse(kPrivacyPolicyUrl), mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.settings_linkComingSoon)));
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: Kingdom.title(size: Kingdom.textSubheading));
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Kingdom.nightDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Kingdom.parchment.withValues(alpha: 0.12)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final IconData? trailingIcon;
  final bool selected;
  final VoidCallback? onTap;

  const _SettingsTile({required this.title, this.trailingIcon, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: TextStyle(color: Kingdom.parchment)),
      trailing: Icon(
        trailingIcon ?? Icons.chevron_right,
        color: selected ? Kingdom.gilt : Kingdom.parchment.withValues(alpha: 0.4),
      ),
      onTap: onTap,
    );
  }
}
