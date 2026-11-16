/*
 * FLauncher
 * Copyright (C) 2024 LeanBitLab
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

import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:flauncher/build_flags.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/settings/settings_panel_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'focusable_settings_tile.dart';
import 'replace_launcher_page.dart';


class GeneralSettingsPage extends StatelessWidget {
  static const String routeName = "general_settings_panel";

  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Column(
      children: [
        SettingsPageHeader(title: localizations.system),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                FocusableSettingsTile(
                  showChevron: true,
                  autofocus: true,
                  leading: const Icon(Icons.home_rounded),
                  title: Text('Replace launcher', style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(ReplaceLauncherPage.routeName),
                ),
                const SettingsSectionDivider(),
                FocusableSettingsTile(
                  showChevron: false,
                  leading: const Icon(Icons.settings_rounded),
                  title: Text(localizations.systemSettings, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => context.read<AppsService>().openSettings(),
                ),
                if (kEnableSelfUpdater)
                  FocusableSettingsTile(
                    showChevron: false,
                    leading: const Icon(Icons.system_update_alt_rounded),
                    title: Text(localizations.updateCheck, style: Theme.of(context).textTheme.bodyMedium),
                    onPressed: () => checkForUpdates(context),
                  ),
                FocusableSettingsTile(
                  showChevron: false,
                  leading: const Icon(Icons.info_rounded),
                  title: Text(localizations.aboutFlauncher, style: Theme.of(context).textTheme.bodyMedium),
                  trailing: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) => Text(snapshot.data?.version ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54)),
                  ),
                  onPressed: () => showAboutTazama(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}
