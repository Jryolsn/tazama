import 'dart:async';

import 'package:flauncher/providers/home_assistant_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

String haDomainLabel(String domain) => switch (domain) {
      'light' => 'Lights',
      'switch' => 'Switches',
      'scene' => 'Scenes',
      'script' => 'Scripts',
      'camera' => 'Cameras',
      'cover' => 'Covers',
      'fan' => 'Fans',
      'lock' => 'Locks',
      'media_player' => 'Media players',
      'climate' => 'Climate',
      'sensor' => 'Sensors',
      'binary_sensor' => 'Binary sensors',
      'input_boolean' => 'Helpers',
      _ => domain,
    };

IconData haEntityIcon(HaEntity entity) => switch (entity.domain) {
      'light' => entity.isOn ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
      'switch' || 'input_boolean' => entity.isOn ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
      'scene' => Icons.palette_rounded,
      'script' => Icons.play_arrow_rounded,
      'camera' => Icons.videocam_rounded,
      'cover' => Icons.blinds_rounded,
      'fan' => Icons.mode_fan_off_rounded,
      'lock' => entity.state == 'locked' ? Icons.lock_rounded : Icons.lock_open_rounded,
      'media_player' => entity.state == 'playing' ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
      'climate' => Icons.thermostat_rounded,
      'binary_sensor' => entity.isOn ? Icons.sensors_rounded : Icons.sensors_off_rounded,
      _ => Icons.sensors_rounded,
    };

/// Controls for the chosen Home Assistant entities, shown over the app that is open.
class HomeAssistantPanel extends StatefulWidget {
  final VoidCallback onOpenSettings;

  const HomeAssistantPanel({super.key, required this.onOpenSettings});

  @override
  State<HomeAssistantPanel> createState() => _HomeAssistantPanelState();
}

class _HomeAssistantPanelState extends State<HomeAssistantPanel> {
  Map<String, HaEntity> _states = {};
  bool _loaded = false;
  bool _failed = false;
  int _snapshot = 0;
  Timer? _poll;
  Timer? _cameras;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
    _cameras = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _snapshot++);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cameras?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final all = await context.read<HomeAssistantService>().fetchStates();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _failed = all == null;
      if (all != null) _states = {for (final e in all) e.entityId: e};
    });
  }

  Future<void> _activate(HaEntity entity) async {
    final ha = context.read<HomeAssistantService>();
    if (entity.domain == 'camera') {
      _showCamera(entity);
      return;
    }
    if (await ha.runPrimaryAction(entity)) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _refresh();
    }
  }

  void _showCamera(HaEntity entity) => showDialog(
        context: context,
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<HomeAssistantService>(),
          child: _CameraDialog(entity: entity),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    final body = Theme.of(context).textTheme.bodyMedium;
    final small = Theme.of(context).textTheme.bodySmall;

    final children = <Widget>[];
    if (!ha.isConfigured) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Text('Connect your Home Assistant server in the launcher settings.', style: body),
      ));
    } else if (ha.panelEntities.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Text('No controls chosen yet. Pick them under Home Assistant > Panel controls.', style: body),
      ));
    } else if (!_loaded) {
      children.add(const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
    } else {
      if (_failed) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('Home Assistant is not answering', style: const TextStyle(color: Colors.orangeAccent)),
        ));
      }
      for (final id in ha.panelEntities) {
        final entity = _states[id];
        if (entity == null) continue;
        final autofocus = children.whereType<_EntityKey>().isEmpty;
        if (entity.domain == 'camera') {
          children.add(_EntityKey(
            child: _CameraTile(
              autofocus: autofocus,
              entity: entity,
              image: ha.cameraSnapshotUri(entity.entityId, _snapshot),
              headers: ha.authHeaders,
              onPressed: () => _activate(entity),
            ),
          ));
          continue;
        }
        final actionable = HomeAssistantService.primaryAction(entity) != null;
        children.add(_EntityKey(
          child: FocusableSettingsTile(
            autofocus: autofocus,
            leading: Icon(haEntityIcon(entity),
                color: entity.isOn ? Theme.of(context).colorScheme.primary : null),
            title: Text(entity.name, style: body, overflow: TextOverflow.ellipsis),
            trailing: Text(entity.unavailable ? 'unavailable' : entity.displayState, style: small),
            onPressed: actionable && !entity.unavailable ? () => _activate(entity) : _refresh,
          ),
        ));
      }
    }
    children
      ..add(const SettingsSectionDivider())
      ..add(FocusableSettingsTile(
        autofocus: children.whereType<_EntityKey>().isEmpty,
        leading: const Icon(Icons.settings_outlined),
        title: Text('Home Assistant settings', style: body),
        showChevron: true,
        onPressed: widget.onOpenSettings,
      ));

    return Column(
      children: [
        SettingsPageHeader(title: ha.locationName ?? 'Home Assistant'),
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

/// Marks a row that is an entity, to know which one gets the first focus.
class _EntityKey extends StatelessWidget {
  final Widget child;

  const _EntityKey({required this.child});

  @override
  Widget build(BuildContext context) => child;
}

class _CameraTile extends StatelessWidget {
  final HaEntity entity;
  final Uri image;
  final Map<String, String> headers;
  final bool autofocus;
  final VoidCallback onPressed;

  const _CameraTile(
      {required this.entity, required this.image, required this.headers, required this.autofocus, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Focus(
        autofocus: autofocus,
        child: Builder(builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onPressed,
            child: Actions(
              actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onPressed())},
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: focused ? accent : Colors.white12, width: focused ? 2 : 1),
                  boxShadow: focused ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 16)] : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(children: [
                  AspectRatio(aspectRatio: 16 / 9, child: _Snapshot(image: image, headers: headers)),
                  Positioned(
                    left: 10,
                    bottom: 8,
                    child: Text(entity.name,
                        style: const TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 6)])),
                  ),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Keeps showing the previous frame while the next snapshot loads.
class _Snapshot extends StatelessWidget {
  final Uri image;
  final Map<String, String> headers;

  const _Snapshot({required this.image, required this.headers});

  @override
  Widget build(BuildContext context) => Image.network(
        image.toString(),
        headers: headers,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: Colors.black26, child: Center(child: Icon(Icons.videocam_off_rounded))),
      );
}

class _CameraDialog extends StatefulWidget {
  final HaEntity entity;

  const _CameraDialog({required this.entity});

  @override
  State<_CameraDialog> createState() => _CameraDialogState();
}

class _CameraDialogState extends State<_CameraDialog> {
  int _snapshot = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _snapshot++));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    return Dialog(
      insetPadding: const EdgeInsets.all(48),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Focus(
        autofocus: true,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _Snapshot(image: ha.cameraSnapshotUri(widget.entity.entityId, _snapshot), headers: ha.authHeaders),
        ),
      ),
    );
  }
}
