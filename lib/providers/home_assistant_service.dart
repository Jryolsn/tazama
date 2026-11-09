import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum HaConnectionState { notConfigured, checking, connected, unauthorized, unreachable }

/// Connection to a Home Assistant server: base URL in preferences, long-lived token in encrypted storage.
class HomeAssistantService extends ChangeNotifier {
  static const _urlKey = 'home_assistant_url';
  static const _tokenKey = 'home_assistant_token';

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

  /// Accepts "192.168.1.10:8123", "homeassistant.local" or a full URL.
  static String normalizeUrl(String input) {
    var value = input.trim();
    if (value.isEmpty) return value;
    if (!value.contains('://')) value = 'http://$value';
    final uri = Uri.parse(value);
    final withPort = uri.hasPort || uri.scheme == 'https' ? uri : uri.replace(port: 8123);
    return withPort.toString().replaceAll(RegExp(r'/+$'), '');
  }

  Future<void> setUrl(String input) async {
    final value = normalizeUrl(input);
    if (value.isEmpty) {
      await _prefs.remove(_urlKey);
    } else {
      await _prefs.setString(_urlKey, value);
    }
    await _afterChange();
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
}
