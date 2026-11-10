import 'dart:async';

import 'package:flauncher/home_assistant/home_assistant_service.dart';
import 'package:flauncher/home_assistant/camera_view.dart';
import 'package:flauncher/home_assistant/dashboard.dart';
import 'package:flauncher/home_assistant/media_card.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      'automation' => 'Automations',
      'button' || 'input_button' => 'Buttons',
      'vacuum' => 'Vacuums',
      'siren' => 'Sirens',
      'humidifier' => 'Humidifiers',
      'water_heater' => 'Water heaters',
      'weather' => 'Weather',
      'person' => 'People',
      'device_tracker' => 'Devices',
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
      'automation' => Icons.smart_toy_rounded,
      'button' || 'input_button' => Icons.radio_button_checked_rounded,
      'vacuum' => Icons.cleaning_services_rounded,
      'siren' => Icons.campaign_rounded,
      'humidifier' => Icons.water_drop_rounded,
      'water_heater' => Icons.hot_tub_rounded,
      'weather' => Icons.wb_cloudy_rounded,
      'person' || 'device_tracker' => entity.state == 'home' ? Icons.person_rounded : Icons.person_outline_rounded,
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
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    final ha = context.read<HomeAssistantService>();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
    if (ha.holdHomeOpensDashboard && ha.isConfigured && ha.dashboardPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openDashboard(ha);
      });
    }
  }

  void _openDashboard(HomeAssistantService ha) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HomeAssistantDashboard(ha: ha, path: ha.dashboardPath!),
      ));

  @override
  void dispose() {
    _poll?.cancel();
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

  Future<void> _dim(HaEntity entity, int step) async {
    final ok = await context
        .read<HomeAssistantService>()
        .callService('light', 'turn_on', entity.entityId, {'brightness_step_pct': step});
    if (ok) await _refresh();
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
    } else if (ha.panelEntities.isEmpty && ha.dashboardPath == null) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Text('No controls chosen yet. Pick them in Home Assistant settings > Controls.', style: body),
      ));
    } else if (!_loaded) {
      children.add(const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
    } else {
      if (ha.dashboardPath != null) {
        children.add(_EntityKey(
          child: FocusableSettingsTile(
            autofocus: true,
            leading: const Icon(Icons.space_dashboard_rounded),
            title: Text('Open dashboard', style: body),
            showChevron: true,
            onPressed: () => _openDashboard(ha),
          ),
        ));
      }
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
              name: ha.nameOf(entity),
              onPressed: () => _activate(entity),
            ),
          ));
          continue;
        }
        if (entity.domain == 'media_player') {
          children.add(_EntityKey(
            child: HaMediaCard(
              autofocus: autofocus,
              entity: entity,
              name: ha.nameOf(entity),
              onChanged: () => Future.delayed(const Duration(milliseconds: 300), _refresh),
            ),
          ));
          continue;
        }
        final actionable = HomeAssistantService.primaryAction(entity) != null;
        children.add(_EntityKey(
          child: _Dimmable(
            enabled: entity.dimmable && !entity.unavailable,
            onStep: (step) => _dim(entity, step),
            child: FocusableSettingsTile(
            autofocus: autofocus,
            leading: Icon(haEntityIcon(entity),
                color: entity.isOn ? Theme.of(context).colorScheme.primary : null),
            title: Text(ha.nameOf(entity), style: body, overflow: TextOverflow.ellipsis),
            trailing: Text(entity.unavailable ? 'unavailable' : entity.displayState, style: small),
            onPressed: actionable && !entity.unavailable ? () => _activate(entity) : _refresh,
          ),
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

/// Left/Right on a dimmable light changes its brightness.
class _Dimmable extends StatelessWidget {
  final bool enabled;
  final ValueChanged<int> onStep;
  final Widget child;

  const _Dimmable({required this.enabled, required this.onStep, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          onStep(10);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          onStep(-10);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
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

class _CameraTile extends StatefulWidget {
  final HaEntity entity;
  final String name;
  final bool autofocus;
  final VoidCallback onPressed;

  const _CameraTile({required this.entity, required this.name, required this.autofocus, required this.onPressed});

  @override
  State<_CameraTile> createState() => _CameraTileState();
}

class _CameraTileState extends State<_CameraTile> {
  bool _focused = false;
  bool _live = false;
  Timer? _liveDelay;

  void _onFocus(bool focused) {
    setState(() => _focused = focused);
    _liveDelay?.cancel();
    if (focused) {
      // Only one tile streams at a time, and only once the focus has rested on it.
      _liveDelay = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _live = true);
      });
    } else {
      setState(() => _live = false);
    }
  }

  @override
  void dispose() {
    _liveDelay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: _onFocus,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Actions(
            actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed())},
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _focused ? accent : Colors.white12, width: _focused ? 2 : 1),
                boxShadow: _focused ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 16)] : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(children: [
                AspectRatio(
                    aspectRatio: 16 / 9, child: HaCameraView(entityId: widget.entity.entityId, live: _live)),
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

/// Full-size live camera with sound. Back closes it.
class _CameraDialog extends StatelessWidget {
  final HaEntity entity;

  const _CameraDialog({required this.entity});

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(48),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Focus(
          autofocus: true,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: HaCameraView(entityId: entity.entityId, live: true, sound: true),
          ),
        ),
      );
}
