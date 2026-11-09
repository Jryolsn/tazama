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
import 'package:flauncher/widgets/settings/home_assistant_page.dart';
import 'package:flauncher/widgets/settings/home_layout_page.dart';
import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flauncher/widgets/settings/lock_protection_page.dart';
import 'package:flauncher/widgets/settings/misc_panel_page.dart';
import 'package:flauncher/widgets/settings/screen_sleep_page.dart';
import 'package:flauncher/widgets/settings/status_bar_panel_page.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
import 'package:flauncher/widgets/settings/watch_next_panel_page.dart';
import 'package:flauncher/widgets/settings/update_dialogs.dart';
import 'package:flauncher/widgets/settings/general_settings_page.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import 'focusable_settings_tile.dart';

class SettingsPanelPage extends StatelessWidget {
  static const String routeName = "settings_panel";

  Widget _link(BuildContext context, IconData icon, String title, String route, {String? subtitle, bool autofocus = false}) =>
      FocusableSettingsTile(
        autofocus: autofocus,
        showChevron: true,
        leading: Icon(icon),
        title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
        subtitle: subtitle == null ? null : Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        onPressed: () => Navigator.of(context).pushNamed(route),
      );

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Column(
      children: [
        SettingsPageHeader(title: localizations.settings),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                const SettingsGroupLabel('Home screen'),
                _link(context, Icons.dashboard_rounded, 'Home layout', HomeLayoutPage.routeName,
                    subtitle: 'Rows, Orbit or Aurora', autofocus: true),
                _link(context, Icons.view_agenda_rounded, 'Categories', LauncherSectionsPanelPage.routeName,
                    subtitle: 'Order, size and layout'),
                _link(context, Icons.play_circle_rounded, localizations.watchNextSectionTitle, WatchNextPanelPage.routeName),
                _link(context, Icons.apps_rounded, localizations.applications, ApplicationsPanelPage.routeName,
                    subtitle: 'Favorites and hidden apps'),
                const SettingsGroupLabel('Appearance'),
                _link(context, Icons.wallpaper_rounded, localizations.wallpaper, WallpaperPanelPage.routeName),
                _link(context, Icons.palette_rounded, 'Color, cards and focus', MiscPanelPage.routeName),
                _link(context, Icons.schedule_rounded, 'Clock and status bar', StatusBarPanelPage.routeName),
                const SettingsGroupLabel('Smart home'),
                _link(context, Icons.home_rounded, 'Home Assistant', HomeAssistantPage.routeName,
                    subtitle: 'Connect your server'),
                const SettingsGroupLabel('TV and system'),
                _link(context, Icons.lock_rounded, 'Lock and protection', LockProtectionPage.routeName,
                    subtitle: 'App lock, VPN guard'),
                _link(context, Icons.brightness_medium_rounded, 'Screen and sleep', ScreenSleepPage.routeName),
                _link(context, Icons.tune_rounded, localizations.system, GeneralSettingsPage.routeName),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
