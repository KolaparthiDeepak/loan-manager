import 'package:flutter/material.dart';

import '../../loan_store.dart';
import '../../supabase_service.dart';
import '../../theme_controller.dart';
import '../../widgets/glass.dart';
import '../../widgets/premium.dart';
import '../auth_flow.dart';

class MoreTab extends StatelessWidget {
  final LoanStore store;
  const MoreTab({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final name = SupabaseService.displayName;
    final needsEmail = SupabaseService.needsRealEmail;
    final email = SupabaseService.currentUser?.email ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      children: [
        const Text('Settings',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
        const SizedBox(height: 14),
        GlassCard(
          blur: 14,
          radius: 28,
          padding: const EdgeInsets.all(16),
          onTap: () => showDisplayNameSheet(context),
          child: Row(
            children: [
              InitialsAvatar(name, radius: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w900)),
                    if (!needsEmail)
                      Text(email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: Palette.inkSoft)),
                    const SizedBox(height: 6),
                    needsEmail
                        ? const StatusChip('Email not verified', color: Palette.amber)
                        : const StatusChip('Email verified', color: Palette.green),
                  ],
                ),
              ),
              Icon(Icons.edit_rounded, color: Palette.inkSoft, size: 20),
            ],
          ),
        ),
        const SectionHeader('Account'),
        _group([
          if (needsEmail)
            _tile(Icons.mark_email_unread_rounded, Palette.amber, 'Verify your email',
                'Needed for password reset codes',
                () => showLinkEmailSheet(context)),
          _tile(Icons.badge_rounded, Palette.violet, 'Display name', name,
              () => showDisplayNameSheet(context)),
          _tile(Icons.key_rounded, Palette.indigo, 'Change password',
              'Update your sign-in password', () => showChangePasswordSheet(context)),
        ]),
        const SectionHeader('Appearance'),
        GlassCard(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Theme',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 10),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.mode,
                builder: (context, m, _) => SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      backgroundColor: Palette.glass(0.5),
                      foregroundColor: Palette.ink,
                      selectedBackgroundColor: Palette.indigo,
                      selectedForegroundColor: Colors.white,
                      side: BorderSide(color: Palette.glass(0.9)),
                    ),
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded, size: 18),
                          label: Text('Auto')),
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded, size: 18),
                          label: Text('Light')),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded, size: 18),
                          label: Text('Dark')),
                    ],
                    selected: {m},
                    onSelectionChanged: (s) => ThemeController.setMode(s.first),
                  ),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: ThemeController.hideAmounts,
                builder: (context, hide, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hide amounts',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  subtitle: Text('Mask balances on Home and Loans',
                      style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
                  value: hide,
                  activeThumbColor: Palette.indigo,
                  onChanged: ThemeController.setHideAmounts,
                ),
              ),
            ],
          ),
        ),
        const SectionHeader('Your data'),
        _group([
          _tile(Icons.account_balance_rounded, Palette.teal, 'Loans tracked',
              '${store.snaps.length} loan${store.snaps.length == 1 ? '' : 's'}', null),
          _tile(Icons.shield_rounded, Palette.green, 'Privacy',
              'Only you can see your loans', null),
        ]),
        const SectionHeader('About'),
        _group([
          _tile(Icons.info_rounded, Palette.sky, 'About Loan Manager',
              'Version 1.0.0', () {
            showAboutDialog(
              context: context,
              applicationName: 'Loan Manager',
              applicationVersion: '1.0.0',
              children: const [
                SizedBox(height: 8),
                Text('Daily-accurate interest, rate changes, charges and '
                    'penalties — with every calculation shown.'),
              ],
            );
          }),
        ]),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => _confirmSignOut(context),
          icon: const Icon(Icons.logout_rounded, color: Palette.rose),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Sign out', style: TextStyle(color: Palette.rose)),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in any time.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await SupabaseService.signOut();
  }

  Widget _group(List<Widget> tiles) {
    final items = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      items.add(tiles[i]);
      if (i != tiles.length - 1) items.add(const Divider(height: 1, indent: 62));
    }
    return GlassCard(
      radius: 26,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: items),
    );
  }

  Widget _tile(IconData icon, Color c, String title, String sub, VoidCallback? onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: c, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Palette.inkSoft)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: Palette.inkSoft),
          ],
        ),
      ),
    );
  }
}
