import 'package:flauncher/home_assistant/settings/home_assistant_screen.dart';
import 'package:flauncher/media_panel/media_panel_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flauncher/widgets/tv_text_prompt.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const _streamHelp = 'e.g. rtsp://user:password@192.168.1.20:554/stream2. '
    'Many cameras need a camera account made in their own app first.';

IconData mediaCardIcon(MediaCardType type) => switch (type) {
      MediaCardType.camera => Icons.videocam_rounded,
      MediaCardType.homeAssistant => Icons.home_rounded,
    };

/// Settings > Media panel: add, order and remove the cards shown when holding Home.
class MediaPanelSettingsPage extends StatelessWidget {
  static const String routeName = 'media_panel_settings';

  const MediaPanelSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final panel = context.watch<MediaPanelService>();
    final body = Theme.of(context).textTheme.bodyMedium;
    final small = Theme.of(context).textTheme.bodySmall;

    return Column(
      children: [
        const SettingsPageHeader(title: 'Media panel'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                const SettingsGroupLabel('Cards (hold Home)'),
                for (final card in panel.cards)
                  FocusableSettingsTile(
                    leading: Icon(mediaCardIcon(card.type)),
                    title: Text(card.name, style: body, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      card.type == MediaCardType.camera ? 'Camera stream' : 'Controls, cameras and dashboard',
                      style: small,
                    ),
                    onPressed: () => _edit(context, panel, card),
                  ),
                FocusableSettingsTile(
                  autofocus: true,
                  leading: const Icon(Icons.add_rounded),
                  title: Text('Add card', style: body),
                  onPressed: () => _add(context, panel),
                ),
                const SettingsGroupLabel('Panel'),
                FocusableSettingsTile(
                  leading: Icon(
                      panel.panelOnRight ? Icons.align_horizontal_right_rounded : Icons.align_horizontal_left_rounded),
                  title: Text('Side: ${panel.panelOnRight ? 'Right' : 'Left'}', style: body),
                  onPressed: () => panel.setPanelOnRight(!panel.panelOnRight),
                ),
                RoundedSwitchListTile(
                  value: panel.panelWide,
                  onChanged: panel.setPanelWide,
                  title: Text('Wide panel', style: body),
                  subtitle: Text('More room for cameras', style: small),
                  secondary: const Icon(Icons.width_wide_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, MediaPanelService panel) async {
    final type = await showDialog<MediaCardType>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add card'),
        children: [
          _option(context, MediaCardType.camera, Icons.videocam_rounded, 'Camera',
              subtitle: 'Any camera with an RTSP stream', first: true),
          if (!panel.hasHomeAssistant)
            _option(context, MediaCardType.homeAssistant, Icons.home_rounded, 'Home Assistant',
                subtitle: 'Controls, cameras and dashboard'),
        ],
      ),
    );
    if (type == null || !context.mounted) return;
    switch (type) {
      case MediaCardType.homeAssistant:
        await panel.addHomeAssistant();
      case MediaCardType.camera:
        final url = await askTvText(context, title: 'Camera stream address', kind: TvTextKind.url, help: _streamHelp);
        if (url == null || url.trim().isEmpty || !context.mounted) return;
        final name = await askTvText(context, title: 'Camera name', initial: 'Camera');
        if (name == null) return;
        await panel.addCamera(name, url);
    }
  }

  Future<void> _edit(BuildContext context, MediaPanelService panel, MediaCard card) async {
    final index = panel.cards.indexWhere((c) => c.id == card.id);
    final last = panel.cards.length - 1;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(card.name),
        children: [
          if (index > 0) _option(context, 'up', Icons.arrow_upward_rounded, 'Move up', first: true),
          if (index < last) _option(context, 'down', Icons.arrow_downward_rounded, 'Move down', first: index == 0),
          if (card.type == MediaCardType.camera) ...[
            _option(context, 'rename', Icons.edit_rounded, 'Rename', first: last == 0),
            _option(context, 'stream', Icons.link_rounded, 'Stream address'),
          ] else
            _option(context, 'ha', Icons.settings_rounded, 'Home Assistant settings', first: last == 0),
          _option(context, 'remove', Icons.delete_outline_rounded, 'Remove from panel'),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'up':
        await panel.move(card.id, -1);
      case 'down':
        await panel.move(card.id, 1);
      case 'remove':
        await panel.remove(card.id);
      case 'ha':
        openHomeAssistantSettings(context, closeSettingsPanel: true);
      case 'rename':
        final value = await askTvText(context, title: 'Camera name', initial: card.name);
        if (value != null) await panel.rename(card.id, value);
      case 'stream':
        final value = await askTvText(context,
            title: 'Stream address for ${card.name}',
            initial: panel.streamUrlOf(card.id) ?? '',
            kind: TvTextKind.url,
            help: _streamHelp);
        if (value != null) await panel.setStreamUrl(card.id, value);
    }
  }

  static Widget _option<T>(BuildContext context, T value, IconData icon, String label,
          {String? subtitle, bool first = false}) =>
      FocusableSettingsTile(
        autofocus: first,
        leading: Icon(icon),
        title: Text(label),
        subtitle: subtitle == null ? null : Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        onPressed: () => Navigator.of(context).pop(value),
      );
}
