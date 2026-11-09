/*
 * Tazama settings: brightness, screensaver and screensaver clock.
 * Licensed under GPL-3.0, see LICENSE.
 */

import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/widgets/settings/brightness_settings_page.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/screensaver_clock_style_page.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScreenSleepPage extends StatelessWidget {
  static const String routeName = "screen_sleep_panel";

  const ScreenSleepPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final style = Theme.of(context).textTheme.bodyMedium;

    return Column(
      children: [
        const SettingsPageHeader(title: 'Screen and sleep'),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                FocusableSettingsTile(
                  showChevron: true,
                  autofocus: true,
                  leading: const Icon(Icons.brightness_6_rounded),
                  title: Text('Brightness', style: style),
                  onPressed: () => Navigator.of(context).pushNamed(BrightnessSettingsPage.routeName),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.screenshot_monitor_rounded),
                  title: Text(localizations.screensaverSettings, style: style),
                  onPressed: () => const MethodChannel('me.efesser.flauncher/method').invokeMethod('openScreensaverSettings'),
                ),
                FocusableSettingsTile(
                  showChevron: true,
                  leading: const Icon(Icons.watch_later_rounded),
                  title: Text(localizations.screensaverClockStyle, style: style),
                  onPressed: () => Navigator.of(context).pushNamed(ScreensaverClockStylePage.routeName),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
