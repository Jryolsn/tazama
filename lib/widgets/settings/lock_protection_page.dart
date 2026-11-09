/*
 * Tazama settings: app lock and VPN guard.
 * Licensed under GPL-3.0, see LICENSE.
 */

import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flauncher/widgets/settings/vpn_guard_page.dart';
import 'package:flutter/material.dart';

class LockProtectionPage extends StatelessWidget {
  static const String routeName = "lock_protection_panel";

  /// Index of the "Locked apps" tab in [ApplicationsPanelPage].
  static const int lockedAppsTab = 3;

  const LockProtectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;

    return Column(
      children: [
        const SettingsPageHeader(title: 'Lock and protection'),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                FocusableSettingsTile(
                  showChevron: true,
                  autofocus: true,
                  leading: const Icon(Icons.lock_rounded),
                  title: Text('App lock', style: style),
                  subtitle: Text('PIN or remote pattern for chosen apps', style: Theme.of(context).textTheme.bodySmall),
                  onPressed: () => Navigator.of(context).pushNamed(ApplicationsPanelPage.routeName, arguments: lockedAppsTab),
                ),
                FocusableSettingsTile(
                  showChevron: true,
                  leading: const Icon(Icons.vpn_lock_rounded),
                  title: Text('VPN guard', style: style),
                  onPressed: () => Navigator.of(context).pushNamed(VpnGuardPage.routeName),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
