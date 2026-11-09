/*
 * FLauncher
 * Copyright (C) 2024 Oscar Rojas
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

import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flauncher/widgets/settings/date_time_format_page.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

import '../../providers/settings_service.dart';

class StatusBarPanelPage extends StatelessWidget {
  static const String routeName = "status_bar_panel";

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    SettingsService settingsService = Provider.of(context);

    return Column(
        children: [
          const SettingsPageHeader(title: 'Clock and status bar'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                RoundedSwitchListTile(
                  autofocus: true,
                  value: settingsService.autoHideAppBarEnabled,
                  onChanged: (value) => settingsService.setAutoHideAppBarEnabled(value),
                  title: Text(localizations.autoHideAppBar, style: Theme.of(context).textTheme.bodyMedium),
                  secondary: const Icon(Icons.visibility_off_rounded),
                ),
                RoundedSwitchListTile(
                  value: settingsService.hideStatusBarInGrid,
                  onChanged: (value) => settingsService.setHideStatusBarInGrid(value),
                  title: Text(localizations.hideStatusBarInGrid, style: Theme.of(context).textTheme.bodyMedium),
                  secondary: const Icon(Icons.grid_view_rounded),
                ),
                const SettingsSectionDivider(),
                RoundedSwitchListTile(
                  value: settingsService.showDateInStatusBar,
                  onChanged: (value) => settingsService.setShowDateInStatusBar(value),
                  title: Text(localizations.date),
                  secondary: Icon(Icons.calendar_today_rounded)
                ),
                RoundedSwitchListTile(
                  value: settingsService.showTimeInStatusBar,
                  onChanged: (value) => settingsService.setShowTimeInStatusBar(value),
                  title: Text(localizations.time),
                  secondary: Icon(Icons.watch_later_rounded)
                ),
                RoundedSwitchListTile(
                  value: settingsService.showWifiWidgetInStatusBar,
                  onChanged: (value) => settingsService.setShowWifiWidgetInStatusBar(value),
                  title: Text(localizations.wifiUsage),
                  secondary: Icon(Icons.wifi_rounded)
                ),
                RoundedSwitchListTile(
                  value: settingsService.showNetworkIndicatorInStatusBar,
                  onChanged: (value) => settingsService.setShowNetworkIndicatorInStatusBar(value),
                  title: Text(localizations.networkIndicator),
                  secondary: Icon(Icons.signal_wifi_4_bar_rounded)
                ),
                FocusableSettingsTile(
                  showChevron: true,
                  leading: const Icon(Icons.date_range_rounded),
                  title: Text(localizations.dateAndTimeFormat, style: Theme.of(context).textTheme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(DateTimeFormatPage.routeName),
                ),
              ],
            ),
          ),
        ],
      );
  }
}
