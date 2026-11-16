import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Name, icon and short description of each quick panel shortcut.
const Map<String, (String, IconData, String)> quickPanelItemInfo = {
  'dim': ('Dim screen', Icons.nightlight_rounded, 'Switch and brightness slider'),
  'vpn': ('VPN for the open app', Icons.vpn_lock_rounded, 'Status and require VPN'),
  'lock': ('App lock', Icons.lock_rounded, 'Lock now, stay unlocked (needs a PIN)'),
  'camera': ('Tazama Camera', Icons.videocam_rounded, 'Your phone as a camera'),
  'mediaPanel': ('Media panel', Icons.view_sidebar_rounded, 'Cameras and Home Assistant'),
};

class QuickPanelSettingsPage extends StatelessWidget {
  static const String routeName = 'quick_panel_settings';

  const QuickPanelSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final hidden = settings.quickPanelHidden;
    final order = settings.quickPanelOrder;
    final body = Theme.of(context).textTheme.bodyMedium;
    final small = Theme.of(context).textTheme.bodySmall;

    return Column(
      children: [
        const SettingsPageHeader(title: 'Quick panel'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                const SettingsGroupLabel('Shortcuts (hold Back)'),
                for (final (i, id) in order.indexed)
                  FocusableSettingsTile(
                    autofocus: i == 0,
                    leading: Icon(quickPanelItemInfo[id]!.$2),
                    title: Text(quickPanelItemInfo[id]!.$1,
                        style: hidden.contains(id) ? body?.copyWith(color: Colors.white38) : body),
                    trailing: Text(hidden.contains(id) ? 'Hidden' : 'Shown',
                        style: small?.copyWith(color: hidden.contains(id) ? Colors.white38 : Colors.white54)),
                    onPressed: () => _edit(context, settings, id, i, order.length - 1, hidden.contains(id)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                  child: Text('"All settings" is always at the bottom of the panel.', style: small),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, SettingsService settings, String id, int index, int last, bool isHidden) async {
    final info = quickPanelItemInfo[id]!;
    Widget option(String value, IconData icon, String label, {bool first = false}) => FocusableSettingsTile(
          autofocus: first,
          leading: Icon(icon),
          title: Text(label),
          onPressed: () => Navigator.of(context).pop(value),
        );
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(info.$1),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(info.$3, style: Theme.of(context).textTheme.bodySmall),
          ),
          option('toggle', isHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              isHidden ? 'Show in panel' : 'Hide from panel', first: true),
          if (index > 0) option('up', Icons.arrow_upward_rounded, 'Move up'),
          if (index < last) option('down', Icons.arrow_downward_rounded, 'Move down'),
        ],
      ),
    );
    switch (choice) {
      case 'toggle':
        await settings.setQuickPanelItemShown(id, isHidden);
      case 'up':
        await settings.moveQuickPanelItem(id, -1);
      case 'down':
        await settings.moveQuickPanelItem(id, 1);
    }
  }
}
