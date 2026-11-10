import 'package:flauncher/providers/home_assistant_service.dart';
import 'package:flauncher/widgets/home_assistant_panel.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flauncher/widgets/tv_text_prompt.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Order, names and removal of the controls in the Home Assistant panel.
class HomeAssistantArrangePage extends StatefulWidget {
  static const String routeName = "home_assistant_arrange_panel";

  const HomeAssistantArrangePage({super.key});

  @override
  State<HomeAssistantArrangePage> createState() => _HomeAssistantArrangePageState();
}

class _HomeAssistantArrangePageState extends State<HomeAssistantArrangePage> {
  Map<String, HaEntity> _states = {};

  @override
  void initState() {
    super.initState();
    context.read<HomeAssistantService>().fetchStates().then((all) {
      if (mounted && all != null) setState(() => _states = {for (final e in all) e.entityId: e});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    final body = Theme.of(context).textTheme.bodyMedium;
    final small = Theme.of(context).textTheme.bodySmall;
    final ids = ha.panelEntities;

    return Column(
      children: [
        const SettingsPageHeader(title: 'Arrange controls'),
        Expanded(
          child: ids.isEmpty
              ? Padding(padding: const EdgeInsets.all(16), child: Text('No controls chosen yet.', style: body))
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final (index, id) in ids.indexed)
                      FocusableSettingsTile(
                        autofocus: index == 0,
                        leading: Icon(_states[id] == null ? Icons.help_outline_rounded : haEntityIcon(_states[id]!)),
                        title: Text(_states[id] == null ? (ha.aliases[id] ?? id) : ha.nameOf(_states[id]!),
                            style: body),
                        subtitle: Text('${index + 1}. $id', style: small),
                        onPressed: () => _edit(context, ha, id),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, HomeAssistantService ha, String id) async {
    final index = ha.panelEntities.indexOf(id);
    final last = ha.panelEntities.length - 1;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_states[id] == null ? id : ha.nameOf(_states[id]!)),
        children: [
          if (index > 0) _option(context, 'top', Icons.vertical_align_top_rounded, 'Move to top'),
          if (index > 0) _option(context, 'up', Icons.arrow_upward_rounded, 'Move up', first: true),
          if (index < last) _option(context, 'down', Icons.arrow_downward_rounded, 'Move down', first: index == 0),
          _option(context, 'rename', Icons.edit_rounded, 'Rename', first: index == 0 && last == 0),
          if (ha.aliases.containsKey(id)) _option(context, 'reset', Icons.undo_rounded, 'Use Home Assistant name'),
          _option(context, 'remove', Icons.delete_outline_rounded, 'Remove from panel'),
        ],
      ),
    );
    switch (choice) {
      case 'top':
        await ha.movePanelEntity(id, -index);
      case 'up':
        await ha.movePanelEntity(id, -1);
      case 'down':
        await ha.movePanelEntity(id, 1);
      case 'reset':
        await ha.setAlias(id, null);
      case 'remove':
        await ha.setPanelEntity(id, false);
      case 'rename':
        if (!context.mounted) return;
        final name = await askTvText(context,
            title: 'Name in the panel', initial: ha.aliases[id] ?? _states[id]?.name ?? '');
        if (name != null) await ha.setAlias(id, name);
    }
  }

  Widget _option(BuildContext context, String value, IconData icon, String label, {bool first = false}) =>
      FocusableSettingsTile(
        autofocus: first,
        leading: Icon(icon),
        title: Text(label),
        onPressed: () => Navigator.of(context).pop(value),
      );
}
