import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/media_panel/media_panel_settings_page.dart';
import 'package:flauncher/providers/app_lock_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/back_button_action_page.dart';
import 'package:flauncher/widgets/settings/back_button_actions.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Everything the remote's buttons do in one place.
class RemoteButtonsPage extends StatelessWidget {
  static const String routeName = "remote_buttons_panel";

  const RemoteButtonsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    // Hold Home and hold Back are caught by the same accessibility service as the app lock.
    final serviceOn = context.watch<AppLockService>().isActive;
    final style = Theme.of(context).textTheme.bodyMedium;
    final valueStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54);

    Widget value(String text, {bool chevron = true}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: valueStyle),
          if (chevron) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white24),
          ],
        ]);

    final backAction = switch (settings.backButtonAction) {
      BACK_BUTTON_ACTION_CLOCK => localizations.dialogOptionBackButtonActionShowClock,
      BACK_BUTTON_ACTION_SCREENSAVER => localizations.dialogOptionBackButtonActionShowScreensaver,
      BACK_BUTTON_ACTION_DIM => 'Toggle dim screen',
      _ => localizations.dialogOptionBackButtonActionDoNothing,
    };

    return Column(
      children: [
        const SettingsPageHeader(title: 'Remote buttons'),
        Expanded(
          child: ListView(
            children: [
              if (!serviceOn)
                FocusableSettingsTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                  title: Text('Turn on "Tazama" in Accessibility', style: style),
                  onPressed: () => FLauncherChannel().openAccessibilitySettings(),
                ),
              FocusableSettingsTile(
                autofocus: true,
                leading: const Icon(Icons.home_rounded),
                title: Text('Hold Home', style: style),
                trailing: value('Media panel'),
                onPressed: () => Navigator.of(context).pushNamed(MediaPanelSettingsPage.routeName),
              ),
              FocusableSettingsTile(
                leading: const Icon(Icons.keyboard_return_rounded),
                title: Text('Hold Back or YouTube', style: style),
                trailing: value('Quick panel', chevron: false),
              ),
              FocusableSettingsTile(
                leading: const Icon(Icons.arrow_back_rounded),
                title: Text('Back on home', style: style),
                trailing: value(backAction),
                onPressed: () => Navigator.of(context).pushNamed(BackButtonActionPage.routeName),
              ),
              const SettingsSectionDivider(),
              RoundedSwitchListTile(
                value: settings.appKeyClickEnabled,
                onChanged: settings.setAppKeyClickEnabled,
                title: Text(localizations.appKeyClick, style: style),
                secondary: const Icon(Icons.volume_up_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
