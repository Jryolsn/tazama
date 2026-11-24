import 'package:flauncher/desktop/desktop_service.dart';
import 'package:flauncher/desktop/desktop_widgets.dart';
import 'package:flauncher/home_assistant/home_assistant_service.dart';
import 'package:flauncher/media_panel/media_panel_service.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flauncher/widgets/side_panel_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One row of a desktop menu.
class DesktopChoice<T> {
  final T value;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;

  const DesktopChoice(this.value, this.title, {this.subtitle, this.icon, this.selected = false});
}

/// A side panel with a list of choices; returns the chosen value, or null on Back.
Future<T?> showDesktopChoices<T>(BuildContext context, String title, List<DesktopChoice<T>> choices,
        {String? emptyText}) =>
    showDialog<T>(
      context: context,
      builder: (context) => SidePanelDialog(
        width: 320,
        isRightSide: true,
        child: Column(
          children: [
            SettingsPageHeader(title: title),
            Expanded(
              child: choices.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Focus(
                        autofocus: true,
                        child: Text(emptyText ?? 'Nothing to choose', style: Theme.of(context).textTheme.bodySmall),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        for (final (i, choice) in choices.indexed)
                          FocusableSettingsTile(
                            autofocus: choice.selected || (i == 0 && !choices.any((c) => c.selected)),
                            leading: choice.icon == null ? null : Icon(choice.icon),
                            title: Text(choice.title),
                            subtitle: choice.subtitle == null
                                ? null
                                : Text(choice.subtitle!, style: Theme.of(context).textTheme.bodySmall),
                            trailing: choice.selected
                                ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary, size: 20)
                                : null,
                            onPressed: () => Navigator.of(context).pop(choice.value),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );

enum DesktopMenuAction { move, size, remove }

/// Edit mode: what to do with one widget.
Future<DesktopMenuAction?> showDesktopItemMenu(BuildContext context, DesktopItem item, {required bool canResize}) =>
    showDesktopChoices(context, desktopTypeName(item.type), [
      const DesktopChoice(DesktopMenuAction.move, 'Move', subtitle: 'Arrows move it, past the edge to the next page',
          icon: Icons.open_with_rounded),
      if (canResize)
        DesktopChoice(DesktopMenuAction.size, 'Size', subtitle: desktopSizeLabel(item.size), icon: Icons.aspect_ratio_rounded),
      const DesktopChoice(DesktopMenuAction.remove, 'Remove widget', icon: Icons.delete_outline_rounded),
    ]);

String desktopBackgroundName(DesktopWidgetBackground background) => switch (background) {
      DesktopWidgetBackground.glass => 'Glass',
      DesktopWidgetBackground.blur => 'Blur',
      DesktopWidgetBackground.none => 'None',
    };

String _backgroundHint(DesktopWidgetBackground background) => switch (background) {
      DesktopWidgetBackground.glass => 'Tinted, see-through',
      DesktopWidgetBackground.blur => 'Frosted, blurs the wallpaper',
      DesktopWidgetBackground.none => 'Content right on the wallpaper',
    };

/// Widget border and background, shared by every page. Changes show right away behind the panel.
Future<void> showDesktopStyle(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => const SidePanelDialog(width: 320, isRightSide: true, child: DesktopStyleSettings()),
    );

class DesktopStyleSettings extends StatelessWidget {
  const DesktopStyleSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = context.watch<DesktopService>();
    final theme = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        const SettingsPageHeader(title: 'Widget style'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              FocusableSettingsTile(
                autofocus: true,
                leading: const Icon(Icons.crop_square_rounded),
                title: Text('Border', style: theme.bodyMedium),
                subtitle: Text('Thin outline around each widget', style: theme.bodySmall),
                trailing: Switch(value: desktop.widgetBorder, onChanged: desktop.setWidgetBorder),
                onPressed: () => desktop.setWidgetBorder(!desktop.widgetBorder),
              ),
              const SettingsGroupLabel('Background'),
              for (final background in DesktopWidgetBackground.values)
                FocusableSettingsTile(
                  leading: Icon(switch (background) {
                    DesktopWidgetBackground.glass => Icons.window_rounded,
                    DesktopWidgetBackground.blur => Icons.blur_on_rounded,
                    DesktopWidgetBackground.none => Icons.layers_clear_rounded,
                  }),
                  title: Text(desktopBackgroundName(background), style: theme.bodyMedium),
                  subtitle: Text(_backgroundHint(background), style: theme.bodySmall),
                  trailing: desktop.widgetBackground == background ? Icon(Icons.check_rounded, color: accent, size: 20) : null,
                  onPressed: () => desktop.setWidgetBackground(background),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Asks what to add. Returns (type, ref) or null.
Future<(DesktopWidgetType, String?)?> pickDesktopWidget(BuildContext context) async {
  final type = await showDesktopChoices(context, 'Add widget', [
    for (final type in DesktopWidgetType.values) DesktopChoice(type, desktopTypeName(type), icon: desktopTypeIcon(type)),
  ]);
  if (type == null || !context.mounted) return null;
  switch (type) {
    case DesktopWidgetType.clock:
    case DesktopWidgetType.watchNext:
      return (type, null);
    case DesktopWidgetType.camera:
      final cameras = context.read<MediaPanelService>().cards.where((c) => c.type == MediaCardType.camera);
      final id = await showDesktopChoices(
        context,
        'Camera',
        [for (final c in cameras) DesktopChoice(c.id, c.name, icon: Icons.videocam_rounded)],
        emptyText: 'No cameras yet. Add one in Settings > Media panel.',
      );
      return id == null ? null : (type, id);
    case DesktopWidgetType.homeAssistant:
      final ha = context.read<HomeAssistantService>();
      final states = {for (final e in await ha.fetchStates() ?? const <HaEntity>[]) e.entityId: e};
      if (!context.mounted) return null;
      final aliases = ha.aliases;
      final id = await showDesktopChoices(
        context,
        'Home Assistant',
        [
          for (final entityId in ha.panelEntities)
            DesktopChoice(entityId, aliases[entityId] ?? states[entityId]?.name ?? entityId, subtitle: entityId),
        ],
        emptyText: ha.isConfigured
            ? 'Choose entities in Settings > Home Assistant > Controls first.'
            : 'Set up Home Assistant in Settings first.',
      );
      return id == null ? null : (type, id);
    case DesktopWidgetType.app:
      final apps = context.read<AppsService>().applications.where((a) => !a.hidden);
      final package = await showDesktopChoices(context, 'App', [
        for (final app in apps) DesktopChoice(app.packageName, app.name),
      ]);
      return package == null ? null : (type, package);
  }
}

Future<bool> confirmDesktop(BuildContext context, String title, String yes) async =>
    await showDesktopChoices(context, title, [
      DesktopChoice(true, yes, icon: Icons.delete_outline_rounded),
      const DesktopChoice(false, 'Cancel', icon: Icons.close_rounded, selected: true),
    ]) ==
    true;
