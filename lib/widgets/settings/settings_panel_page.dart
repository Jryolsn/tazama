/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flauncher/providers/update_service.dart';
import 'package:flauncher/build_flags.dart';
import 'package:flauncher/widgets/settings/applications_panel_page.dart';
import 'package:flauncher/widgets/settings/flauncher_about_dialog.dart';
import 'package:flauncher/home_assistant/settings/home_assistant_screen.dart';
import 'package:flauncher/widgets/settings/home_layout_page.dart';
import 'package:flauncher/media_panel/media_panel_settings_page.dart';
import 'package:flauncher/widgets/settings/remote_buttons_page.dart';
import 'package:flauncher/widgets/settings/quick_panel_settings_page.dart';
import 'package:flauncher/widgets/settings/tazama_camera_page.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/app_lock_service.dart';
import 'package:flauncher/home_assistant/home_assistant_service.dart';
import 'package:flauncher/media_panel/media_panel_service.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/widgets/settings/lock_protection_page.dart';
import 'package:flauncher/widgets/settings/misc_panel_page.dart';
import 'package:flauncher/widgets/settings/screen_sleep_page.dart';
import 'package:flauncher/widgets/settings/status_bar_panel_page.dart';
import 'package:flauncher/widgets/settings/update_dialogs.dart';
import 'package:flauncher/widgets/settings/general_settings_page.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import 'focusable_settings_tile.dart';

class SettingsPanelPage extends StatelessWidget {
  static const String routeName = "settings_panel";

  /// One-line row. [value] shows the current choice on the right so the
  /// menu tells what is set without opening each page.
  static Widget _link(BuildContext context, IconData icon, String title,
      {String? route, VoidCallback? onPressed, String? value, bool autofocus = false}) {
    final theme = Theme.of(context).textTheme;
    return FocusableSettingsTile(
      autofocus: autofocus,
      showChevron: true,
      leading: Icon(icon),
      title: Text(title, style: theme.bodyMedium),
      trailing: value == null
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Text(value, style: theme.bodySmall?.copyWith(color: Colors.white54)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white24),
            ]),
      onPressed: onPressed ?? () => Navigator.of(context).pushNamed(route!),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    final mediaPanel = context.watch<MediaPanelService>();
    final ha = context.watch<HomeAssistantService>();
    final lock = context.watch<AppLockService>();
    final cardCount = mediaPanel.cards.length;

    return Column(
      children: [
        SettingsPageHeader(title: localizations.settings),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                const SettingsGroupLabel('Home'),
                _link(context, Icons.apps_rounded, 'Apps', route: ApplicationsPanelPage.routeName, autofocus: true),
                _link(context, Icons.dashboard_rounded, 'Home screen', route: HomeLayoutPage.routeName,
                    value: _layoutName(settings.homeLayout)),
                _link(context, Icons.palette_rounded, 'Look', route: MiscPanelPage.routeName),
                _link(context, Icons.schedule_rounded, 'Clock and status bar', route: StatusBarPanelPage.routeName),
                const SettingsGroupLabel('Panels'),
                _link(context, Icons.bolt_rounded, 'Quick panel', route: QuickPanelSettingsPage.routeName,
                    value: 'Hold Back'),
                _link(context, Icons.view_sidebar_rounded, 'Media panel', route: MediaPanelSettingsPage.routeName,
                    value: cardCount == 0 ? 'Empty' : '$cardCount ${cardCount == 1 ? 'card' : 'cards'}'),
                const SettingsGroupLabel('Integrations'),
                _link(context, Icons.home_rounded, 'Home Assistant',
                    value: ha.isConfigured ? 'Connected' : 'Not set up',
                    onPressed: () => openHomeAssistantSettings(context, closeSettingsPanel: true)),
                _link(context, Icons.phone_android_rounded, 'Tazama Link', route: TazamaCameraPage.routeName,
                    value: 'Phone app'),
                const SettingsGroupLabel('TV'),
                _link(context, Icons.settings_remote_rounded, 'Remote buttons', route: RemoteButtonsPage.routeName),
                _link(context, Icons.lock_rounded, 'Lock and protection', route: LockProtectionPage.routeName,
                    value: lock.hasPin ? 'On' : 'Off'),
                _link(context, Icons.brightness_medium_rounded, 'Screen and sleep', route: ScreenSleepPage.routeName),
                _link(context, Icons.tune_rounded, localizations.system, route: GeneralSettingsPage.routeName),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _layoutName(String layout) => switch (layout) {
        HOME_LAYOUT_ORBIT => 'Orbit',
        HOME_LAYOUT_AURORA => 'Aurora',
        _ => 'Rows',
      };
}

void showAboutTazama(BuildContext context) => showDialog(
      context: context,
      builder: (_) => FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done && snapshot.hasData
            ? LTvLauncherAboutDialog(packageInfo: snapshot.data!)
            : Container(),
      ),
    );

Future<void> checkForUpdates(BuildContext context) async {
  if (!kEnableSelfUpdater) {
    return;
  }

  final localizations = AppLocalizations.of(context)!;
  final updateService = UpdateService();
  final navigator = Navigator.of(context, rootNavigator: true);

  showUpdateProgressDialog(
    context,
    label: localizations.updateCheck,
  );

  try {
    final update = await updateService.checkForUpdate();
    if (navigator.canPop()) {
      navigator.pop();
    }
    if (!context.mounted) {
      return;
    }

    if (!update.updateAvailable) {
      await showNoUpdateDialog(
        context,
        localizations,
        currentVersion: update.currentVersion,
        changelog: update.releaseNotes,
      );
      return;
    }

    final download = await showUpdateAvailableDialog(
      context,
      localizations,
      latestVersion: update.latestVersion,
      currentVersion: update.currentVersion,
      changelog: update.releaseNotes,
    );

    if (!download) {
      return;
    }

    showUpdateProgressDialog(
      context,
      label: localizations.updateDownloadButton,
    );

    final downloadedApk = await updateService.downloadApk(update);
    if (navigator.canPop()) {
      navigator.pop();
    }
    if (!context.mounted) {
      return;
    }

    final install = await showReadyToInstallDialog(
      context,
      localizations,
      latestVersion: downloadedApk.version,
    );

    if (!install) {
      return;
    }

    final installerOpened = await updateService.installApk(downloadedApk.path);
    if (!context.mounted || installerOpened) {
      return;
    }

    await showInstallPermissionDialog(
      context,
      localizations,
      onOpenPermissionSettings: () =>
          updateService.requestInstallUnknownAppsPermission(),
    );
  } catch (_) {
    if (navigator.canPop()) {
      navigator.pop();
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.updateErrorGeneric)),
    );
  }
}
