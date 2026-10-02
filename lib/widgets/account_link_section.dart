import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/account_link_service.dart';
import '../theme/kingdom_theme.dart';

/// 設定画面の「アカウントの引き継ぎ」欄。Googleアカウントで端末変更・再インストール後も
/// コイン/カード/デッキ/ランクを引き継げるようにする。
class AccountLinkSection extends StatefulWidget {
  const AccountLinkSection({super.key});

  @override
  State<AccountLinkSection> createState() => _AccountLinkSectionState();
}

class _AccountLinkSectionState extends State<AccountLinkSection> {
  bool _busy = false;

  Future<void> _link() async {
    final t = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final result = await AccountLinkService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    final message = switch (result) {
      AccountLinkResult.linked => t.settings_accountLinkSuccess,
      AccountLinkResult.switchedToExisting => t.settings_accountSwitchedSuccess,
      AccountLinkResult.cancelled => t.settings_accountLinkCancelled,
      AccountLinkResult.failed => t.settings_accountLinkFailed,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: result == AccountLinkResult.failed ? Colors.red : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final linked = AccountLinkService.isLinked;
    return Container(
      padding: const EdgeInsets.all(Kingdom.spaceMd),
      decoration: BoxDecoration(
        color: Kingdom.nightDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Kingdom.gilt.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(linked ? Icons.verified_user_outlined : Icons.shield_outlined, color: Kingdom.gilt),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  linked ? t.settings_accountLinked(AccountLinkService.linkedEmail ?? '') : t.settings_accountLinkTitle,
                  style: const TextStyle(color: Kingdom.parchment, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            linked ? t.settings_accountLinkedNote : t.settings_accountLinkDesc,
            style: TextStyle(fontSize: 12, height: 1.6, color: Kingdom.parchment.withValues(alpha: 0.7)),
          ),
          if (!linked) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _link,
                style: ElevatedButton.styleFrom(backgroundColor: Kingdom.gilt, foregroundColor: Kingdom.night),
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Kingdom.night))
                    : const Icon(Icons.login),
                label: Text(t.settings_accountLinkButton, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
