/*
 * Tazama settings: app lock and VPN guard.
 * Licensed under GPL-3.0, see LICENSE.
 */

import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flauncher/widgets/settings/vpn_guard_page.dart';
import 'package:flauncher/providers/app_lock_service.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LockProtectionPage extends StatelessWidget {
  static const String routeName = "lock_protection_panel";

  /// Index of the "Locked apps" tab in [ApplicationsPanelPage].
  static const int lockedAppsTab = 3;

  const LockProtectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final lock = context.watch<AppLockService>();
    final lockedCount =
        context.watch<AppsService>().applications.where((app) => lock.isLocked(app.packageName)).length;

    return Column(
      children: [
        const SettingsPageHeader(title: 'Lock and protection'),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SettingsGroupLabel('App lock'),
                ...appLockSettingsTiles(context, lock),
                FocusableSettingsTile(
                  showChevron: true,
                  leading: const Icon(Icons.lock_rounded),
                  title: Text('Locked apps', style: style),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('$lockedCount', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white24),
                  ]),
                  onPressed: () => Navigator.of(context).pushNamed(ApplicationsPanelPage.routeName, arguments: lockedAppsTab),
                ),
                const SettingsGroupLabel('Network'),
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
