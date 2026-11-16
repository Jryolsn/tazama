
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flauncher/widgets/settings/accent_color_page.dart';
import 'package:flauncher/widgets/settings/wallpaper_panel_page.dart';
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
    final style = Theme.of(context).textTheme.bodyMedium;

    return Column(
      children: [
        const SettingsPageHeader(title: 'Look'),
        Expanded(
          child: ListView(
            children: [
              FocusableSettingsTile(
                autofocus: true,
                showChevron: true,
                leading: const Icon(Icons.wallpaper_rounded),
                title: Text(localizations.wallpaper, style: style),
                onPressed: () => Navigator.of(context).pushNamed(WallpaperPanelPage.routeName),
              ),
              FocusableSettingsTile(
                showChevron: true,
                leading: const Icon(Icons.palette_rounded),
                title: Text(localizations.accentColor, style: style),
                onPressed: () => Navigator.of(context).pushNamed(AccentColorPage.routeName),
              ),
              FocusableSettingsTile(
                showChevron: true,
                leading: const Icon(Icons.border_style_rounded),
                title: Text(localizations.focusBorderThickness, style: style),
                onPressed: () => Navigator.of(context).pushNamed(FocusBorderThicknessPage.routeName),
              ),
              const SettingsGroupLabel('Cards'),
              RoundedSwitchListTile(
                value: settingsService.showFocusBorders,
                onChanged: (value) => settingsService.setShowFocusBorders(value),
                title: Text(localizations.showFocusBorders, style: style),
                secondary: const Icon(Icons.border_outer_rounded),
              ),
              RoundedSwitchListTile(
                value: settingsService.appHighlightAnimationEnabled,
                onChanged: (value) => settingsService.setAppHighlightAnimationEnabled(value),
                title: Text(localizations.appCardHighlightAnimation, style: style),
                secondary: const Icon(Icons.filter_center_focus_rounded),
              ),
              RoundedSwitchListTile(
                value: settingsService.showAppNamesBelowIcons,
                onChanged: (value) => settingsService.setShowAppNamesBelowIcons(value),
                title: Text(localizations.showAppNamesBelowIcons, style: style),
                secondary: const Icon(Icons.subtitles_rounded),
              ),
              RoundedSwitchListTile(
                value: settingsService.showCategoryTitles,
                onChanged: (value) => settingsService.setShowCategoryTitles(value),
                title: Text(localizations.showCategoryTitles, style: style),
                secondary: const Icon(Icons.abc_rounded),
              ),
              const SettingsGroupLabel('Blur and dock'),
              RoundedSwitchListTile(
                value: !settingsService.backgroundBlurDisabled,
                onChanged: (value) => settingsService.setBackgroundBlurDisabled(!value),
                title: Text(localizations.backgroundBlur, style: style),
                secondary: const Icon(Icons.blur_on_rounded),
              ),
              RoundedSwitchListTile(
                value: !settingsService.dockBackdropFilterDisabled,
                onChanged: (value) => settingsService.setDockBackdropFilterDisabled(!value),
                title: Text(localizations.dockBlur, style: style),
                secondary: const Icon(Icons.blur_circular_rounded),
              ),
              RoundedSwitchListTile(
                value: settingsService.dockShadowEnabled,
                onChanged: settingsService.setDockShadowEnabled,
                title: Text(localizations.dockShadow, style: style),
                secondary: const Icon(Icons.layers_rounded),
              ),
              RoundedSwitchListTile(
                value: settingsService.dockDarkBackground,
                onChanged: settingsService.setDockDarkBackground,
                title: Text(localizations.dockDarkBackground, style: style),
                secondary: const Icon(Icons.dark_mode_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
