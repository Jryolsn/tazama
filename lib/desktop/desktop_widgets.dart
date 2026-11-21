import 'dart:typed_data';

import 'package:flauncher/desktop/desktop_service.dart';
import 'package:flauncher/home_assistant/home_assistant_service.dart';
import 'package:flauncher/home_assistant/panel.dart';
import 'package:flauncher/media_panel/media_panel_service.dart';
import 'package:flauncher/media_panel/stream_view.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/nebula_theme.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/widgets/date_time_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Live Home Assistant states for the widgets on the shown page, keyed by entity id.
typedef HaStates = ValueNotifier<Map<String, HaEntity>>;

String desktopTypeName(DesktopWidgetType type) => switch (type) {
      DesktopWidgetType.clock => 'Clock',
      DesktopWidgetType.camera => 'Camera',
      DesktopWidgetType.homeAssistant => 'Home Assistant',
      DesktopWidgetType.app => 'App',
      DesktopWidgetType.watchNext => 'Continue watching',
    };

IconData desktopTypeIcon(DesktopWidgetType type) => switch (type) {
      DesktopWidgetType.clock => Icons.schedule_rounded,
      DesktopWidgetType.camera => Icons.videocam_rounded,
      DesktopWidgetType.homeAssistant => Icons.home_rounded,
      DesktopWidgetType.app => Icons.apps_rounded,
      DesktopWidgetType.watchNext => Icons.play_circle_rounded,
    };

/// Size a new widget of this type starts with.
(int, int) desktopDefaultSize(DesktopWidgetType type) => switch (type) {
      DesktopWidgetType.clock => (2, 1),
      DesktopWidgetType.camera => (2, 2),
      DesktopWidgetType.homeAssistant => (1, 1),
      DesktopWidgetType.app => (1, 1),
      DesktopWidgetType.watchNext => (2, 1),
    };

App? _appOf(BuildContext context, String? packageName) =>
    context.read<AppsService>().applications.where((a) => a.packageName == packageName).firstOrNull;

/// Runs a widget's OK action. [busy] is set while a full-screen view is open,
/// so a small camera picture can stop meanwhile.
Future<void> activateDesktopItem(BuildContext context, DesktopItem item, HaStates haStates, ValueNotifier<bool> busy) async {
  switch (item.type) {
    case DesktopWidgetType.clock:
      return;
    case DesktopWidgetType.camera:
      final url = context.read<MediaPanelService>().streamUrlOf(item.ref ?? '');
      if (url == null || busy.value) return;
      busy.value = true;
      await openFullscreen(context, StreamView(url: url, sound: true, fit: BoxFit.contain));
      busy.value = false;
    case DesktopWidgetType.homeAssistant:
      final ha = context.read<HomeAssistantService>();
      final entity = haStates.value[item.ref];
      if (entity == null) return;
      if (await ha.runPrimaryAction(entity)) {
        final fresh = await ha.fetchStates();
        if (fresh != null) haStates.value = {for (final e in fresh) e.entityId: e};
      }
    case DesktopWidgetType.app:
      final app = _appOf(context, item.ref);
      if (app != null) await context.read<AppsService>().launchApp(app);
    case DesktopWidgetType.watchNext:
      final watch = context.read<WatchNextService>();
      final first = watch.items.firstOrNull;
      if (first != null) {
        await watch.launchItem(first);
      } else if (!watch.hasPermission) {
        await watch.requestPermission();
      }
  }
}

/// What a desktop widget draws inside its frame.
class DesktopItemContent extends StatelessWidget {
  final DesktopItem item;
  final HaStates haStates;
  final ValueNotifier<bool> busy;

  /// False while the launcher is hidden, so live pictures stop.
  final bool live;

  const DesktopItemContent({super.key, required this.item, required this.haStates, required this.busy, required this.live});

  @override
  Widget build(BuildContext context) => switch (item.type) {
        DesktopWidgetType.clock => _Clock(large: item.height > 1),
        DesktopWidgetType.camera => _Camera(item: item, busy: busy, live: live),
        DesktopWidgetType.homeAssistant => _HaEntity(item: item, haStates: haStates),
        DesktopWidgetType.app => _AppShortcut(item: item),
        DesktopWidgetType.watchNext => const _WatchNext(),
      };
}

class _Clock extends StatelessWidget {
  final bool large;

  const _Clock({required this.large});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DateTimeWidget(
              settings.timeFormat,
              updateInterval: const Duration(seconds: 10),
              textStyle: TextStyle(
                fontSize: large ? 84 : 56,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
                height: 1,
                color: Nebula.text,
                shadows: Nebula.textShadow,
              ),
            ),
            const SizedBox(height: 8),
            DateTimeWidget(
              settings.dateFormat,
              updateInterval: const Duration(minutes: 1),
              textStyle: TextStyle(
                fontSize: large ? 20 : 15,
                letterSpacing: 2,
                color: Nebula.textMuted,
                shadows: Nebula.textShadow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Camera extends StatelessWidget {
  final DesktopItem item;
  final ValueNotifier<bool> busy;
  final bool live;

  const _Camera({required this.item, required this.busy, required this.live});

  @override
  Widget build(BuildContext context) {
    final panel = context.watch<MediaPanelService>();
    final card = panel.cards.where((c) => c.id == item.ref).firstOrNull;
    final url = panel.streamUrlOf(item.ref ?? '');
    if (card == null || url == null) {
      return const DesktopPlaceholder(icon: Icons.videocam_off_rounded, text: 'Camera not found');
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: busy,
          builder: (_, fullscreen, __) => live && !fullscreen
              ? StreamView(key: ValueKey(url), url: url)
              : const ColoredBox(color: Colors.black26),
        ),
        Positioned(left: 12, bottom: 10, right: 12, child: _Label(card.name)),
      ],
    );
  }
}

class _HaEntity extends StatelessWidget {
  final DesktopItem item;
  final HaStates haStates;

  const _HaEntity({required this.item, required this.haStates});

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    if (!ha.isConfigured) {
      return const DesktopPlaceholder(icon: Icons.home_rounded, text: 'Home Assistant is not set up');
    }
    return ValueListenableBuilder<Map<String, HaEntity>>(
      valueListenable: haStates,
      builder: (context, states, _) {
        final entity = states[item.ref];
        final name = ha.aliases[item.ref] ?? entity?.name ?? item.ref ?? '';
        if (entity == null) {
          return DesktopPlaceholder(icon: Icons.home_rounded, text: name);
        }
        final unit = entity.attributes['unit_of_measurement'];
        final state = unit == null ? entity.state : '${entity.state} $unit';
        final accent = Theme.of(context).colorScheme.primary;
        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(haEntityIcon(entity), size: 28, color: entity.isOn ? accent : Nebula.textMuted),
              const Spacer(),
              Text(state,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Nebula.text)),
              const SizedBox(height: 2),
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Nebula.textMuted)),
            ],
          ),
        );
      },
    );
  }
}

class _AppShortcut extends StatefulWidget {
  final DesktopItem item;

  const _AppShortcut({required this.item});

  @override
  State<_AppShortcut> createState() => _AppShortcutState();
}

class _AppShortcutState extends State<_AppShortcut> {
  Future<Uint8List>? _banner;

  @override
  void initState() {
    super.initState();
    final package = widget.item.ref;
    if (package != null) _banner = context.read<AppsService>().getAppBanner(package);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.select<AppsService, App?>(
        (s) => s.applications.where((a) => a.packageName == widget.item.ref).firstOrNull);
    if (app == null) return const DesktopPlaceholder(icon: Icons.apps_rounded, text: 'App not installed');
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder<Uint8List>(
          future: _banner,
          builder: (_, snapshot) => snapshot.hasData && snapshot.data!.isNotEmpty
              ? Image.memory(snapshot.data!, fit: BoxFit.cover, gaplessPlayback: true)
              : Center(child: Text(app.name, style: const TextStyle(color: Nebula.text))),
        ),
        if (widget.item.height > 1) Positioned(left: 12, bottom: 10, right: 12, child: _Label(app.name)),
      ],
    );
  }
}

class _WatchNext extends StatelessWidget {
  const _WatchNext();

  @override
  Widget build(BuildContext context) {
    final watch = context.watch<WatchNextService>();
    if (!watch.hasPermission) {
      return const DesktopPlaceholder(icon: Icons.play_circle_rounded, text: 'Press OK to allow Continue watching');
    }
    final item = watch.items.firstOrNull;
    if (item == null) {
      return const DesktopPlaceholder(icon: Icons.play_circle_rounded, text: 'Nothing to continue');
    }
    final uri = watch.getPosterUriForItem(item);
    watch.ensurePosterLoaded(uri);
    final poster = watch.getCachedPoster(uri);
    final progress = item.progressPercent;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (poster != null) Image.memory(poster, fit: BoxFit.cover, gaplessPlayback: true),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xB3000000)],
              stops: [0.45, 1],
            ),
          ),
        ),
        Positioned(left: 12, right: 12, bottom: progress == null ? 10 : 16, child: _Label(item.title)),
        if (progress != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 3,
              backgroundColor: Colors.white24,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Nebula.text, shadows: Nebula.textShadow),
      );
}

class DesktopPlaceholder extends StatelessWidget {
  final IconData icon;
  final String text;

  const DesktopPlaceholder({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: Nebula.textMuted),
              const SizedBox(height: 8),
              Text(text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Nebula.textMuted)),
            ],
          ),
        ),
      );
}
