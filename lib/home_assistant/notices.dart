import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flauncher/home_assistant/home_assistant_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('me.efesser.flauncher/method');

/// Settings for notices shown in a corner of the TV when a Home Assistant sensor fires.
class HaNoticeSettings extends ChangeNotifier {
  static const _enabledKey = 'ha_notices_enabled';
  static const _sensorsKey = 'ha_notice_sensors';
  static const _cornerKey = 'ha_notice_corner';
  static const _secondsKey = 'ha_notice_seconds';
  static const _cooldownKey = 'ha_notice_cooldown';
  static const _eventsKey = 'ha_notice_events';

  static const corners = ['top_right', 'top_left', 'bottom_right', 'bottom_left'];
  static const secondsChoices = [4, 8, 15, 30];
  static const cooldownChoices = [10, 30, 60, 300];

  final SharedPreferences _prefs;

  HaNoticeSettings(this._prefs);

  bool get enabled => _prefs.getBool(_enabledKey) ?? false;
  List<String> get sensors => _prefs.getStringList(_sensorsKey) ?? const [];
  String get corner => _prefs.getString(_cornerKey) ?? 'top_right';
  int get seconds => _prefs.getInt(_secondsKey) ?? 8;
  int get cooldown => _prefs.getInt(_cooldownKey) ?? 30;
  bool get listenForEvents => _prefs.getBool(_eventsKey) ?? true;

  /// Changes whenever a setting that needs a new subscription changes.
  String get signature => '$enabled|${sensors.join(',')}|$listenForEvents';

  Future<void> setEnabled(bool v) => _set(() => _prefs.setBool(_enabledKey, v));
  Future<void> setCorner(String v) => _set(() => _prefs.setString(_cornerKey, v));
  Future<void> setSeconds(int v) => _set(() => _prefs.setInt(_secondsKey, v));
  Future<void> setCooldown(int v) => _set(() => _prefs.setInt(_cooldownKey, v));
  Future<void> setListenForEvents(bool v) => _set(() => _prefs.setBool(_eventsKey, v));

  Future<void> setSensor(String entityId, bool on) {
    final list = [...sensors]..remove(entityId);
    if (on) list.add(entityId);
    return _set(() => _prefs.setStringList(_sensorsKey, list));
  }

  Future<void> _set(Future<bool> Function() write) async {
    await write();
    notifyListeners();
  }

  Future<void> reload() => _prefs.reload();

  /// Icon for a sensor notice, picked from the sensor's device class.
  static IconData iconFor(HaEntity entity) => iconNamed(entity.attributes['device_class']?.toString());

  /// Icon for a device class or a short name (also accepts `mdi:` names) sent by an automation.
  static IconData iconNamed(String? name) {
    final n = (name ?? '').toLowerCase().replaceFirst('mdi:', '');
    bool has(List<String> keys) => keys.any(n.contains);
    if (has(['motion', 'moving', 'walk', 'run'])) return Icons.directions_walk_rounded;
    if (has(['occupancy', 'presence', 'person', 'account', 'home'])) return Icons.person_rounded;
    if (has(['doorbell', 'bell-ring'])) return Icons.doorbell_rounded;
    if (has(['garage'])) return Icons.garage_rounded;
    if (has(['door', 'opening'])) return Icons.door_front_door_rounded;
    if (has(['window'])) return Icons.window_rounded;
    if (has(['smoke', 'heat', 'fire'])) return Icons.local_fire_department_rounded;
    if (has(['gas', 'carbon', 'alert', 'warning', 'problem', 'safety'])) return Icons.warning_rounded;
    if (has(['moisture', 'water', 'leak'])) return Icons.water_drop_rounded;
    if (has(['sound', 'volume', 'speaker'])) return Icons.volume_up_rounded;
    if (has(['vibration', 'tamper'])) return Icons.vibration_rounded;
    if (has(['lock'])) return Icons.lock_rounded;
    if (has(['package', 'mail', 'delivery'])) return Icons.inventory_2_rounded;
    if (has(['camera', 'cctv'])) return Icons.videocam_rounded;
    if (has(['washing', 'laundry', 'dishwasher'])) return Icons.local_laundry_service_rounded;
    if (has(['battery'])) return Icons.battery_alert_rounded;
    if (has(['temperature', 'thermometer'])) return Icons.thermostat_rounded;
    return Icons.notifications_rounded;
  }

  /// Sensor kinds worth showing first in the picker.
  static const alertClasses = {
    'motion', 'moving', 'occupancy', 'presence', 'door', 'garage_door', 'opening', 'window', 'smoke', 'heat',
    'gas', 'carbon_monoxide', 'moisture', 'sound', 'vibration', 'tamper',
  };
}

/// Shows a notice on the TV through the native overlay. Returns false when it could not be shown.
Future<bool> showTvNotice(String title,
    {String? message, IconData icon = Icons.notifications_rounded, required int seconds, required String corner}) async {
  try {
    return await _channel.invokeMethod<bool>('showNotice', {
          'title': title,
          'message': message,
          'icon': await _iconPng(icon),
          'seconds': seconds,
          'corner': corner,
        }) ??
        false;
  } catch (_) {
    return false;
  }
}

/// Renders an icon glyph to PNG so the native overlay can show it without its own icon set.
Future<Uint8List?> _iconPng(IconData icon) async {
  try {
    const size = 64.0;
    final recorder = ui.PictureRecorder();
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: size, color: const Color(0xFFF2F3F5)),
      ),
    )..layout();
    painter.paint(Canvas(recorder), Offset((size - painter.width) / 2, (size - painter.height) / 2));
    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// Listens to Home Assistant in the background and shows notices.
///
/// Runs in the always-loaded quick panel engine. Two sources:
/// * the chosen binary sensors turning on, and
/// * a `tazama_notify` event fired by a Home Assistant automation, with `message`, optional `title`,
///   `icon` (for example `door` or `mdi:door`) and `seconds`.
class HaNoticeListener {
  final HomeAssistantService ha;
  final HaNoticeSettings settings;
  final SharedPreferences prefs;

  HaNoticeListener(this.ha, this.settings, this.prefs);

  final _lastShown = <String, DateTime>{};
  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    _loop();
  }

  Future<void> _loop() async {
    var backoff = 10;
    while (_running) {
      await settings.reload();
      await ha.refreshConfig();
      if (!settings.enabled || !ha.isConfigured || (settings.sensors.isEmpty && !settings.listenForEvents)) {
        await Future.delayed(const Duration(seconds: 20));
        continue;
      }
      final started = DateTime.now();
      try {
        await _session();
      } catch (_) {
        // reconnect below
      }
      // A session that lasted a while was healthy: start the backoff over.
      backoff = DateTime.now().difference(started).inMinutes >= 2 ? 10 : (backoff * 2).clamp(10, 120);
      await Future.delayed(Duration(seconds: backoff));
    }
  }

  Future<void> _session() async {
    final signature = settings.signature;
    final wsUrl = ha.url!.replaceFirst(RegExp('^http'), 'ws');
    final socket = await WebSocket.connect('$wsUrl/api/websocket').timeout(const Duration(seconds: 10));
    socket.pingInterval = const Duration(seconds: 30);
    final done = Completer<void>();
    final names = <String, String>{}; // entity id -> text, filled lazily
    var nextId = 1;

    void send(Map<String, dynamic> message) => socket.add(jsonEncode(message));

    // Settings changed (or HA connection edited): leave, and the loop reconnects.
    final watcher = Timer.periodic(const Duration(seconds: 20), (_) async {
      await settings.reload();
      await ha.refreshConfig();
      if (settings.signature != signature && !done.isCompleted) done.complete();
    });

    socket.listen(
      (raw) {
        final message = jsonDecode(raw as String) as Map<String, dynamic>;
        switch (message['type']) {
          case 'auth_required':
            send({'type': 'auth', 'access_token': ha.token});
          case 'auth_ok':
            if (settings.sensors.isNotEmpty) {
              send({
                'id': nextId++,
                'type': 'subscribe_trigger',
                'trigger': {'platform': 'state', 'entity_id': settings.sensors, 'to': 'on'},
              });
            }
            if (settings.listenForEvents) {
              send({'id': nextId++, 'type': 'subscribe_events', 'event_type': 'tazama_notify'});
            }
          case 'auth_invalid':
            if (!done.isCompleted) done.complete();
          case 'event':
            _onEvent(message['event'] as Map<String, dynamic>? ?? const {}, names);
        }
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      onError: (_) {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );

    await done.future;
    watcher.cancel();
    await socket.close();
  }

  void _onEvent(Map<String, dynamic> event, Map<String, String> names) {
    // Event fired by an automation.
    if (event['event_type'] == 'tazama_notify') {
      final data = (event['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      final message = data['message']?.toString() ?? '';
      if (message.isEmpty) return;
      final title = data['title']?.toString();
      final hasTitle = title != null && title.isNotEmpty;
      showTvNotice(hasTitle ? title : message,
          message: hasTitle ? message : null,
          icon: HaNoticeSettings.iconNamed(data['icon']?.toString() ?? title),
          seconds: (data['seconds'] as num?)?.toInt() ?? settings.seconds,
          corner: settings.corner);
      return;
    }
    // Sensor trigger.
    final trigger = ((event['variables'] as Map?)?['trigger'] as Map?)?.cast<String, dynamic>();
    final to = (trigger?['to_state'] as Map?)?.cast<String, dynamic>();
    if (trigger == null || to == null) return;
    final entityId = trigger['entity_id']?.toString() ?? to['entity_id']?.toString() ?? '';
    final now = DateTime.now();
    final last = _lastShown[entityId];
    if (last != null && now.difference(last).inSeconds < settings.cooldown) return;
    _lastShown[entityId] = now;
    final entity = HaEntity.fromJson(to);
    showTvNotice(ha.nameOf(entity),
        message: _stateText(entity), icon: HaNoticeSettings.iconFor(entity), seconds: settings.seconds, corner: settings.corner);
  }
}

/// Short state line for a sensor that just turned on.
String? _stateText(HaEntity entity) => switch (entity.attributes['device_class']) {
      'motion' || 'moving' => 'Motion detected',
      'occupancy' || 'presence' => 'Someone is here',
      'door' || 'garage_door' || 'opening' || 'window' => 'Opened',
      'smoke' => 'Smoke detected',
      'heat' => 'Heat detected',
      'gas' || 'carbon_monoxide' => 'Gas detected',
      'moisture' => 'Water detected',
      'sound' => 'Sound detected',
      'vibration' => 'Vibration detected',
      'tamper' => 'Tampering detected',
      'lock' => 'Unlocked',
      _ => null,
    };
