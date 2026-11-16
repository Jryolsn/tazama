import 'package:flauncher/home_assistant/panel.dart';
import 'package:flauncher/media_panel/media_panel_service.dart';
import 'package:flauncher/media_panel/stream_view.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The media panel (hold Home): the cards the user added, in their order.
class MediaPanel extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const MediaPanel({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final panel = context.watch<MediaPanelService>();
    final body = Theme.of(context).textTheme.bodyMedium;
    final cards = panel.cards;

    final children = <Widget>[];
    if (cards.isEmpty) {
      children
        ..add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text('Add cameras, Home Assistant and more to this panel.', style: body),
        ))
        ..add(FocusableSettingsTile(
          autofocus: true,
          leading: const Icon(Icons.add_rounded),
          title: Text('Add card', style: body),
          showChevron: true,
          onPressed: onOpenSettings,
        ));
    } else {
      for (final (index, card) in cards.indexed) {
        switch (card.type) {
          case MediaCardType.camera:
            final url = panel.streamUrlOf(card.id);
            children.add(_StreamCard(
              key: ValueKey(card.id),
              name: card.name,
              url: url,
              autofocus: index == 0,
            ));
          case MediaCardType.homeAssistant:
            children.add(HomeAssistantSection(key: ValueKey(card.id), title: card.name, autofocus: index == 0));
        }
      }
      children
        ..add(const SettingsSectionDivider())
        ..add(FocusableSettingsTile(
          autofocus: true,
          leading: const Icon(Icons.settings_outlined),
          title: Text('Media panel settings', style: body),
          showChevron: true,
          onPressed: onOpenSettings,
        ));
    }

    return Column(
      children: [
        const SettingsPageHeader(title: 'Media panel'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ),
      ],
    );
  }
}

/// A live camera stream; OK opens it large with sound.
class _StreamCard extends StatefulWidget {
  final String name;
  final String? url;
  final bool autofocus;

  const _StreamCard({super.key, required this.name, required this.url, required this.autofocus});

  @override
  State<_StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<_StreamCard> {
  bool _focused = false;

  void _open() {
    final url = widget.url;
    if (url == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(48),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Focus(
          autofocus: true,
          child: AspectRatio(aspectRatio: 16 / 9, child: StreamView(url: url, sound: true)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final url = widget.url;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Actions(
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _open())},
        child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: GestureDetector(
          onTap: _open,
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _focused ? accent : Colors.white12, width: _focused ? 2 : 1),
                boxShadow: _focused ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 16)] : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: url == null
                      ? const ColoredBox(color: Colors.black26, child: Center(child: Icon(Icons.link_off_rounded)))
                      : StreamView(url: url),
                ),
                Positioned(
                  left: 10,
                  bottom: 8,
                  child: Text(widget.name, style: const TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 6)])),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
