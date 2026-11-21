import 'package:flauncher/desktop/desktop_menus.dart';
import 'package:flauncher/desktop/desktop_service.dart';
import 'package:flauncher/desktop/taskbar.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flauncher/widgets/settings/watch_next_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Settings > Home screen: the taskbar at the bottom and the desktop above it.
class HomeScreenPage extends StatelessWidget {
  static const String routeName = "home_screen_panel";

  const HomeScreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final apps = context.watch<AppsService>();
    final desktop = context.watch<DesktopService>();
    final category = taskbarCategory(taskbarCategories(apps), settings.taskbarCategoryId);
    final theme = Theme.of(context).textTheme;
    final pageCount = desktop.pages.length;
    final widgetCount = desktop.pages.fold<int>(0, (n, page) => n + page.length);

    Widget value(String text) => Text(text, style: theme.bodySmall?.copyWith(color: Colors.white54));

    return Column(
      children: [
        const SettingsPageHeader(title: 'Home screen'),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SettingsGroupLabel('Taskbar'),
                FocusableSettingsTile(
                  autofocus: true,
                  leading: const Icon(Icons.view_week_rounded),
                  title: Text('Shown category', style: theme.bodyMedium),
                  trailing: value(category?.name ?? 'None'),
                  onPressed: () async {
                    final id = await showDesktopChoices(context, 'Category', [
                      for (final c in taskbarCategories(apps))
                        DesktopChoice(c.id, c.name, selected: c.id == category?.id),
                    ]);
                    if (id != null) await settings.setTaskbarCategoryId(id);
                  },
                ),
                FocusableSettingsTile(
                  showChevron: true,
                  leading: const Icon(Icons.view_agenda_rounded),
                  title: Text('Categories', style: theme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(LauncherSectionsPanelPage.routeName),
                ),
                const SettingsGroupLabel('Desktop'),
                FocusableSettingsTile(
                  leading: const Icon(Icons.dashboard_rounded),
                  title: Text('Pages', style: theme.bodyMedium),
                  trailing: value('$pageCount ${pageCount == 1 ? 'page' : 'pages'}, '
                      '$widgetCount ${widgetCount == 1 ? 'widget' : 'widgets'}'),
                  onPressed: () => desktop.addPage(pageCount - 1),
                  subtitle: Text('OK adds a page', style: theme.bodySmall),
                ),
                FocusableSettingsTile(
                  showChevron: true,
                  leading: const Icon(Icons.play_circle_rounded),
                  title: Text(AppLocalizations.of(context)!.watchNextSectionTitle, style: theme.bodyMedium),
                  onPressed: () => Navigator.of(context).pushNamed(WatchNextPanelPage.routeName),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Text(
                    'Taskbar: Up and Down switch category, Up from the first category goes to the desktop, '
                    'Left from the first app shows the category settings. '
                    'Desktop: hold OK on a widget to move, resize or remove it, or to add, move and remove pages. '
                    'Left and Right at the edge of a page turn the page.',
                    style: theme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
