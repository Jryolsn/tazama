import 'package:flauncher/home_assistant/panel.dart';
import 'package:flauncher/media_panel/media_panel_service.dart';
import 'package:flauncher/media_panel/stream_view.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The media panel (hold Home): the cards the user added, in their order.
class MediaPanel extends StatefulWidget {
  final VoidCallback onOpenSettings;

  const MediaPanel({super.key, required this.onOpenSettings});

  @override
  State<MediaPanel> createState() => _MediaPanelState();
}

class _MediaPanelState extends State<MediaPanel> {
  final _cardsScope = FocusScopeNode(debugLabel: 'media panel cards');
  bool _userMoved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusFirstCard());
  }

  /// Home Assistant rows appear after a fetch: move focus up to them unless the user already moved.
  void _cardLoaded() {
    if (!_userMoved) _focusFirstCard();
  }

  void _focusFirstCard() {
    if (!mounted) return;
    final first = _cardsScope.traversalDescendants.where((n) => n.canRequestFocus).firstOrNull;
    if (first != null && !first.hasPrimaryFocus) first.requestFocus();
  }

  @override
  void dispose() {
    _cardsScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onOpenSettings = widget.onOpenSettings;
    final panel = context.watch<MediaPanelService>();
    final body = Theme.of(context).textTheme.bodyMedium;
    final cards = panel.cards;

    final children = <Widget>[];
    final cardWidgets = <Widget>[];
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
      for (final card in cards) {
        switch (card.type) {
          case MediaCardType.camera:
            final url = panel.streamUrlOf(card.id);
            cardWidgets.add(_StreamCard(key: ValueKey(card.id), name: card.name, url: url));
          case MediaCardType.homeAssistant:
            cardWidgets.add(HomeAssistantSection(key: ValueKey(card.id), title: card.name, onLoaded: _cardLoaded));
        }
      }
      children
        ..add(FocusScope(
          node: _cardsScope,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: cardWidgets),
        ))
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
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) _userMoved = true;
              return KeyEventResult.ignored;
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
            ),
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

  const _StreamCard({super.key, required this.name, required this.url});

  @override
  State<_StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<_StreamCard> {
  bool _focused = false;
  bool _fullscreen = false;

  Future<void> _open() async {
    final url = widget.url;
    if (url == null || _fullscreen) return;
    // One stream at a time: the small picture stops while the full one plays.
    setState(() => _fullscreen = true);
    await openFullscreen(context, StreamView(url: url, sound: true, fit: BoxFit.contain));
    if (mounted) setState(() => _fullscreen = false);
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
                      : _fullscreen
                          ? const ColoredBox(color: Colors.black26)
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

