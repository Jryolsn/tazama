import 'package:flauncher/desktop/desktop_menus.dart';
import 'package:flauncher/desktop/desktop_service.dart';
import 'package:flauncher/desktop/desktop_widgets.dart';
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
                  leading: const Icon(Icons.edit_outlined),
                  title: Text('Edit desktop', style: theme.bodyMedium),
                  subtitle: Text('Add, remove and move widgets and pages', style: theme.bodySmall),
                  trailing: value('$pageCount ${pageCount == 1 ? 'page' : 'pages'}, '
                      '$widgetCount ${widgetCount == 1 ? 'widget' : 'widgets'}'),
                  onPressed: () {
                    // Close settings and open edit mode on the desktop itself.
                    Navigator.of(context, rootNavigator: true).pop();
                    desktop.requestEdit();
                  },
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.home_outlined),
                  title: Text('Home page', style: theme.bodyMedium),
                  subtitle: Text('Shown at start and when you press Home', style: theme.bodySmall),
                  trailing: value('Page ${desktop.homePage + 1}'),
                  onPressed: pageCount < 2
                      ? null
                      : () async {
                          final page = await showDesktopChoices(context, 'Home page', [
                            for (var i = 0; i < pageCount; i++)
                              DesktopChoice(i, 'Page ${i + 1}',
                                  subtitle: _pageSummary(desktop.pages[i]), selected: i == desktop.homePage),
                          ]);
                          if (page != null) await desktop.setHomePage(page);
                        },
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.crop_square_rounded),
                  title: Text('Widget border', style: theme.bodyMedium),
                  trailing: Switch(value: desktop.widgetBorder, onChanged: desktop.setWidgetBorder),
                  onPressed: () => desktop.setWidgetBorder(!desktop.widgetBorder),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.blur_on_rounded),
                  title: Text('Widget background', style: theme.bodyMedium),
                  trailing: value(desktopBackgroundName(desktop.widgetBackground)),
                  onPressed: () async {
                    final background = await showDesktopChoices(context, 'Widget background', [
                      for (final b in DesktopWidgetBackground.values)
                        DesktopChoice(b, desktopBackgroundName(b), selected: b == desktop.widgetBackground),
                    ]);
                    if (background != null) await desktop.setWidgetBackground(background);
                  },
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
                    'Desktop: Left and Right at the edge of a page turn the page, Home goes back to the home page. '
                    'The pencil at the bottom right opens edit mode: OK on a widget moves, resizes or removes it, '
                    'OK on an empty cell adds one there, and going past the first or last page adds a page.',
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

String _pageSummary(List<DesktopItem> items) => items.isEmpty
    ? 'Empty'
    : items.map((i) => desktopTypeName(i.type)).toSet().join(', ');

