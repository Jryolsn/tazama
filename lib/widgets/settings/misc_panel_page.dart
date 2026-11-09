
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flauncher/widgets/settings/accent_color_page.dart';
import 'package:flauncher/widgets/settings/appearance_panel_page.dart';
import 'package:flauncher/widgets/settings/focus_border_thickness_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

class MiscPanelPage extends StatelessWidget {
  static const String routeName = "misc_panel";

  const MiscPanelPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    SettingsService settingsService = Provider.of(context);

    return Column(
      children: [
        const SettingsPageHeader(title: 'Color, cards and focus'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              FocusableSettingsTile(
                autofocus: true,
                showChevron: true,
                leading: const Icon(Icons.palette_rounded),
                title: Text(localizations.accentColor, style: Theme.of(context).textTheme.bodyMedium),
                onPressed: () => Navigator.of(context).pushNamed(AccentColorPage.routeName),
              ),
              FocusableSettingsTile(
                showChevron: true,
                leading: const Icon(Icons.border_style_rounded),
                title: Text(localizations.focusBorderThickness, style: Theme.of(context).textTheme.bodyMedium),
                onPressed: () => Navigator.of(context).pushNamed(FocusBorderThicknessPage.routeName),
              ),
              FocusableSettingsTile(
                showChevron: true,
                leading: const Icon(Icons.blur_on_rounded),
                title: Text('Blur and dock', style: Theme.of(context).textTheme.bodyMedium),
                onPressed: () => Navigator.of(context).pushNamed(AppearancePanelPage.routeName),
              ),
              const SettingsSectionDivider(),
              RoundedSwitchListTile(
                value: settingsService.appHighlightAnimationEnabled,
                onChanged: (value) => settingsService.setAppHighlightAnimationEnabled(value),
                title: Text(localizations.appCardHighlightAnimation, style: Theme.of(context).textTheme.bodyMedium),
                secondary: Icon(Icons.filter_center_focus_rounded),
              ),
              RoundedSwitchListTile(
                value: settingsService.appKeyClickEnabled,
                onChanged: (value) => settingsService.setAppKeyClickEnabled(value),
                title: Text(localizations.appKeyClick, style: Theme.of(context).textTheme.bodyMedium),
                secondary: Icon(Icons.notifications_active_rounded),
              ),
              RoundedSwitchListTile(
                value: settingsService.showCategoryTitles,
                onChanged: (value) => settingsService.setShowCategoryTitles(value),
                title: Text(localizations.showCategoryTitles, style: Theme.of(context).textTheme.bodyMedium),
                secondary: Icon(Icons.abc_rounded),
              ),
              RoundedSwitchListTile(
                value: settingsService.showAppNamesBelowIcons,
                onChanged: (value) => settingsService.setShowAppNamesBelowIcons(value),
                title: Text(localizations.showAppNamesBelowIcons, style: Theme.of(context).textTheme.bodyMedium),
                secondary: Icon(Icons.subtitles_rounded),
              ),
              RoundedSwitchListTile(
                value: settingsService.showFocusBorders,
                onChanged: (value) => settingsService.setShowFocusBorders(value),
                title: Text(localizations.showFocusBorders, style: Theme.of(context).textTheme.bodyMedium),
                secondary: Icon(Icons.border_outer_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
