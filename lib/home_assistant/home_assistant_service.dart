import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum HaConnectionState { notConfigured, checking, connected, unauthorized, unreachable }

/// Connection to a Home Assistant server: base URL in preferences, long-lived token in encrypted storage.
class HomeAssistantService extends ChangeNotifier {
  static const _urlKey = 'home_assistant_url';
  static const _tokenKey = 'home_assistant_token';
  static const _entitiesKey = 'home_assistant_entities';
  static const _dashboardKey = 'home_assistant_dashboard';
  static const _aliasesKey = 'home_assistant_aliases';
  static const _sideKey = 'home_assistant_panel_side';
  static const _wideKey = 'home_assistant_panel_wide';
  static const _holdHomeKey = 'home_assistant_hold_home';
  static const _cameraRefreshKey = 'home_assistant_camera_refresh';
  static const cameraRefreshChoices = [1, 2, 3, 5, 10, 30];

  /// Domains the panel can show or control.
  static const supportedDomains = {
    'light', 'switch', 'fan', 'input_boolean', 'scene', 'script', 'cover', 'lock',
    'media_player', 'climate', 'sensor', 'binary_sensor', 'camera', 'automation',
    'button', 'input_button', 'vacuum', 'siren', 'humidifier', 'water_heater', 'weather',
    'person', 'device_tracker',
  };

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  String? _token;
  HaConnectionState _state = HaConnectionState.notConfigured;
  String? _locationName;
  String? _version;
  String? _error;

  HomeAssistantService(this._prefs, {FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ??
            const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true)) {
    _load();
  }

  String? get url => _prefs.getString(_urlKey);
  bool get hasToken => (_token ?? '').isNotEmpty;
  bool get isConfigured => (url ?? '').isNotEmpty && hasToken;
  HaConnectionState get state => _state;
  String? get locationName => _locationName;
  String? get version => _version;
  String? get error => _error;

  /// Entity ids shown in the Home Assistant panel, in order.
  List<String> get panelEntities => _prefs.getStringList(_entitiesKey) ?? const [];

  Future<void> setPanelEntity(String entityId, bool shown) async {
    final list = [...panelEntities]..remove(entityId);
    if (shown) list.add(entityId);
    await _prefs.setStringList(_entitiesKey, list);
    notifyListeners();
  }

  /// Url path of the dashboard opened from the panel ('lovelace' is the default one), or null for none.
  String? get dashboardPath => _prefs.getString(_dashboardKey);

  Future<void> setDashboardPath(String? path) async {
    if (path == null) {
      await _prefs.remove(_dashboardKey);
    } else {
      await _prefs.setString(_dashboardKey, path);
    }
    notifyListeners();
  }

  String? get token => _token;

  Map<String, String> get aliases {
    try {
      return (jsonDecode(_prefs.getString(_aliasesKey) ?? '{}') as Map).cast<String, String>();
    } catch (_) {
      return {};
    }
  }

  /// The user's own name for an entity, or null to use Home Assistant's.
  Future<void> setAlias(String entityId, String? alias) async {
    final map = aliases;
    if (alias == null || alias.trim().isEmpty) {
      map.remove(entityId);
    } else {
      map[entityId] = alias.trim();
    }
    await _prefs.setString(_aliasesKey, jsonEncode(map));
    notifyListeners();
  }

  String nameOf(HaEntity entity) => aliases[entity.entityId] ?? entity.name;

  Future<void> movePanelEntity(String entityId, int delta) async {
    final list = [...panelEntities];
    final from = list.indexOf(entityId);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= list.length) return;
    list
      ..removeAt(from)
      ..insert(to, entityId);
    await _prefs.setStringList(_entitiesKey, list);
    notifyListeners();
  }

  bool get panelOnRight => _prefs.getString(_sideKey) != 'left';
  Future<void> setPanelOnRight(bool right) async {
    await _prefs.setString(_sideKey, right ? 'right' : 'left');
    notifyListeners();
  }

  bool get panelWide => _prefs.getBool(_wideKey) ?? false;
  Future<void> setPanelWide(bool wide) async {
    await _prefs.setBool(_wideKey, wide);
    notifyListeners();
  }

  /// Holding Home goes straight to the dashboard instead of the controls.
  bool get holdHomeOpensDashboard => (_prefs.getString(_holdHomeKey) ?? 'panel') == 'dashboard';
  Future<void> setHoldHomeOpensDashboard(bool value) async {
    await _prefs.setString(_holdHomeKey, value ? 'dashboard' : 'panel');
    notifyListeners();
  }

  int get cameraRefreshSeconds => _prefs.getInt(_cameraRefreshKey) ?? 3;
  Future<void> setCameraRefreshSeconds(int seconds) async {
    await _prefs.setInt(_cameraRefreshKey, seconds);
    notifyListeners();
  }

  /// Re-reads address and token without testing the connection (cheap enough to poll).
  Future<void> refreshConfig() async {
    await _prefs.reload();
    try {
      _token = await _secure.read(key: _tokenKey);
    } catch (_) {
      _token = null;
    }
  }

  /// Picks up changes made by the other engine (launcher or panel).
  Future<void> reload() async {
    await _prefs.reload();
    await _load();
  }

  Future<void> _load() async {
    try {
      _token = await _secure.read(key: _tokenKey);
    } catch (_) {
      _token = null;
    }
    if (isConfigured) {
      await testConnection();
    } else {
      notifyListeners();
    }
  }

  /// Accepts "192.168.1.10:8123", "homeassistant.local" or a full URL. A bare host without
  /// scheme or port gets HA's default port 8123; "http://host" keeps port 80.
  static String normalizeUrl(String input) {
    var value = input.trim();
    if (value.isEmpty) return value;
    final bare = !value.contains('://');
    if (bare) value = 'http://$value';
    final explicitPort = RegExp(r'^[a-zA-Z]+://[^/]*:\d+').hasMatch(value);
    final uri = Uri.parse(value);
    final result = bare && !explicitPort ? uri.replace(port: 8123) : uri;
    return result.toString().replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> setUrl(String input) async {
    final value = normalizeUrl(input);
    if (value.isEmpty) {
      await _prefs.remove(_urlKey);
    } else {
      await _prefs.setString(_urlKey, value);
    }
    await _afterChange();
    // A bare host that doesn't answer on 8123 may run on port 80 (e.g. behind a proxy).
    final trimmed = input.trim();
    if (_state == HaConnectionState.unreachable && !trimmed.contains('://') && !trimmed.contains(':')) {
      await _prefs.setString(_urlKey, 'http://$trimmed'.replaceAll(RegExp(r'/+$'), ''));
      await _afterChange();
      if (_state == HaConnectionState.unreachable) {
        await _prefs.setString(_urlKey, value);
        await _afterChange();
      }
    }
  }

  Future<void> setToken(String input) async {
    final value = input.trim();
    _token = value.isEmpty ? null : value;
    if (_token == null) {
      await _secure.delete(key: _tokenKey);
    } else {
      await _secure.write(key: _tokenKey, value: _token);
    }
    await _afterChange();
  }

  Future<void> disconnect() async {
    _token = null;
    await _secure.delete(key: _tokenKey);
    await _prefs.remove(_urlKey);
    await _afterChange();
  }

  Future<void> _afterChange() async {
    _locationName = null;
    _version = null;
    _error = null;
    if (isConfigured) {
      await testConnection();
    } else {
      _state = HaConnectionState.notConfigured;
      notifyListeners();
    }
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };

  Future<void> testConnection() async {
    if (!isConfigured) {
      _state = HaConnectionState.notConfigured;
      notifyListeners();
      return;
    }
    _state = HaConnectionState.checking;
    _error = null;
    notifyListeners();
    try {
      final response =
          await http.get(Uri.parse('$url/api/config'), headers: _headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final config = jsonDecode(response.body) as Map<String, dynamic>;
        _locationName = config['location_name'] as String?;
        _version = config['version'] as String?;
        _state = HaConnectionState.connected;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _state = HaConnectionState.unauthorized;
        _error = 'The token was rejected';
      } else {
        _state = HaConnectionState.unreachable;
        _error = 'Server answered ${response.statusCode}';
      }
    } on TimeoutException {
      _state = HaConnectionState.unreachable;
      _error = 'No answer from the server';
    } catch (e) {
      _state = HaConnectionState.unreachable;
      _error = e.toString();
    }
    notifyListeners();
  }

  /// All entity states, or null when the server can't be reached.
  Future<List<HaEntity>?> fetchStates() async {
    if (!isConfigured) return null;
    try {
      final response =
          await http.get(Uri.parse('$url/api/states'), headers: _headers).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return (jsonDecode(response.body) as List)
          .map((e) => HaEntity.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> callService(String domain, String service, String entityId, [Map<String, dynamic>? data]) async {
    if (!isConfigured) return false;
    try {
      final response = await http
          .post(Uri.parse('$url/api/services/$domain/$service'),
              headers: _headers, body: jsonEncode({'entity_id': entityId, ...?data}))
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// The main action for OK on an entity, or null when it can only be shown.
  static (String domain, String service)? primaryAction(HaEntity entity) => switch (entity.domain) {
        'light' || 'switch' || 'fan' || 'input_boolean' || 'automation' || 'siren' || 'humidifier' =>
          (entity.domain, 'toggle'),
        'button' || 'input_button' => (entity.domain, 'press'),
        'vacuum' => ('vacuum', entity.state == 'cleaning' ? 'return_to_base' : 'start'),
        'scene' => ('scene', 'turn_on'),
        'script' => ('script', 'turn_on'),
        'cover' => ('cover', 'toggle'),
        'media_player' => ('media_player', 'media_play_pause'),
        'lock' => ('lock', entity.state == 'locked' ? 'unlock' : 'lock'),
        _ => null,
      };

  Future<bool> runPrimaryAction(HaEntity entity) async {
    final action = primaryAction(entity);
    if (action == null) return false;
    return callService(action.$1, action.$2, entity.entityId);
  }

  /// Runs websocket commands in order and returns their results (null on any failure).
  Future<List<dynamic>?> _websocket(List<Map<String, dynamic>> commands) async {
    if (!isConfigured) return null;
    WebSocket? socket;
    try {
      final wsUrl = url!.replaceFirst(RegExp('^http'), 'ws');
      socket = await WebSocket.connect('$wsUrl/api/websocket').timeout(const Duration(seconds: 8));
      final messages = socket.map((m) => jsonDecode(m as String) as Map<String, dynamic>).asBroadcastStream();
      await messages.firstWhere((m) => m['type'] == 'auth_required').timeout(const Duration(seconds: 8));
      socket.add(jsonEncode({'type': 'auth', 'access_token': _token}));
      final auth = await messages.firstWhere((m) => m['type'] != 'auth_required').timeout(const Duration(seconds: 8));
      if (auth['type'] != 'auth_ok') return null;
      final results = <dynamic>[];
      for (final (i, command) in commands.indexed) {
        socket.add(jsonEncode({'id': i + 1, ...command}));
        final reply = await messages.firstWhere((m) => m['id'] == i + 1).timeout(const Duration(seconds: 10));
        if (reply['success'] != true) return null;
        results.add(reply['result']);
      }
      return results;
    } catch (_) {
      return null;
    } finally {
      await socket?.close();
    }
  }

  /// Dashboards from the websocket API (the REST API has no list), as url path -> title.
  Future<Map<String, String>?> fetchDashboards() async {
    final results = await _websocket([
      {'type': 'lovelace/dashboards/list'}
    ]);
    if (results == null) return null;
    final dashboards = <String, String>{'lovelace': 'Overview'};
    for (final d in (results[0] as List? ?? const [])) {
      final map = d as Map<String, dynamic>;
      final path = map['url_path'] as String?;
      if (path != null) dashboards[path] = map['title'] as String? ?? path;
    }
    return dashboards;
  }

  /// Areas and entity metadata, used to group and filter entities.
  Future<HaRegistry?> fetchRegistry() async {
    final results = await _websocket([
      {'type': 'config/area_registry/list'},
      {'type': 'config/device_registry/list'},
      {'type': 'config/entity_registry/list'},
    ]);
    if (results == null) return null;
    final areas = <String, String>{
      for (final a in results[0] as List) (a as Map)['area_id'] as String: a['name'] as String? ?? a['area_id'] as String,
    };
    final deviceArea = <String, String?>{
      for (final d in results[1] as List) (d as Map)['id'] as String: d['area_id'] as String?,
    };
    final entityArea = <String, String>{};
    final hidden = <String>{};
    for (final e in results[2] as List) {
      final map = e as Map;
      final id = map['entity_id'] as String;
      final area = map['area_id'] as String? ?? deviceArea[map['device_id']];
      if (area != null) entityArea[id] = area;
      if (map['entity_category'] != null || map['hidden_by'] != null || map['disabled_by'] != null) hidden.add(id);
    }
    return HaRegistry(areas, entityArea, hidden);
  }

  /// URL of the camera's HLS stream (needs HA's `stream` integration), or null if it has none.
  Future<Uri?> fetchHlsUrl(String entityId) async {
    final results = await _websocket([
      {'type': 'camera/stream', 'entity_id': entityId, 'format': 'hls'}
    ]);
    final path = results != null && results[0] is Map ? (results[0] as Map)['url'] as String? : null;
    return path == null ? null : Uri.parse(path.startsWith('http') ? path : '$url$path');
  }

  Future<bool> setVolume(String entityId, double level) =>
      callService('media_player', 'volume_set', entityId, {'volume_level': level.clamp(0.0, 1.0)});

  /// Absolute URL for a relative path such as a media player's `entity_picture`.
  Uri? absoluteUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return Uri.parse(path.startsWith('http') ? path : '$url$path');
  }

  /// A fresh snapshot of a camera; [bust] makes the URL unique so the image is not cached.
  Uri cameraSnapshotUri(String entityId, int bust) => Uri.parse('$url/api/camera_proxy/$entityId?t=$bust');

  Map<String, String> get authHeaders => {'Authorization': 'Bearer $_token'};
}

class HaEntity {
  final String entityId;
  final String state;
  final Map<String, dynamic> attributes;

  HaEntity(this.entityId, this.state, this.attributes);

  factory HaEntity.fromJson(Map<String, dynamic> json) => HaEntity(
        json['entity_id'] as String,
        json['state']?.toString() ?? '',
        (json['attributes'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  String get domain => entityId.split('.').first;
  String get name => attributes['friendly_name'] as String? ?? entityId;
  bool get isOn => const {'on', 'open', 'playing', 'unlocked', 'home'}.contains(state);
  String? get mediaTitle => attributes['media_title'] as String?;
  String? get mediaArtist => (attributes['media_artist'] ?? attributes['media_series_title']) as String?;
  String? get picture => attributes['entity_picture'] as String?;
  double? get volume => (attributes['volume_level'] as num?)?.toDouble();
  double? get mediaDuration => (attributes['media_duration'] as num?)?.toDouble();

  /// Playback position now, extrapolated from the last update while playing.
  double? get mediaPosition {
    final position = (attributes['media_position'] as num?)?.toDouble();
    if (position == null) return null;
    final updated = DateTime.tryParse(attributes['media_position_updated_at']?.toString() ?? '');
    if (state != 'playing' || updated == null) return position;
    final elapsed = DateTime.now().difference(updated).inMilliseconds / 1000;
    final total = mediaDuration;
    final now = position + elapsed;
    return total == null ? now : now.clamp(0, total).toDouble();
  }

  /// Light brightness in percent, or null when off or not dimmable.
  int? get brightnessPercent {
    final b = attributes['brightness'];
    return b is num ? (b * 100 / 255).round() : null;
  }

  bool get dimmable {
    final modes = attributes['supported_color_modes'];
    return domain == 'light' && modes is List && modes.any((m) => m != 'onoff');
  }

  bool get unavailable => state == 'unavailable' || state == 'unknown';

  String get displayState {
    final unit = attributes['unit_of_measurement'];
    if (domain == 'climate' || domain == 'water_heater') {
      final current = attributes['current_temperature'];
      return current == null ? state : '$current° · $state';
    }
    if (domain == 'weather') {
      final t = attributes['temperature'];
      return t == null ? state : '$t° · $state';
    }
    if (domain == 'button' || domain == 'input_button') return 'press';
    if (domain == 'light' && isOn && brightnessPercent != null) return '$brightnessPercent%';
    return unit == null ? state : '$state $unit';
  }
}

class HaRegistry {
  /// area id -> name
  final Map<String, String> areas;

  /// entity id -> area id (own area, or its device's)
  final Map<String, String> entityArea;

  /// Diagnostic, config, hidden and disabled entities.
  final Set<String> hidden;

  HaRegistry(this.areas, this.entityArea, this.hidden);

  String? areaNameOf(String entityId) => areas[entityArea[entityId]];
}
