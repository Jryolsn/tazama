import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MediaCardType { camera, homeAssistant }

/// One card in the media panel (hold Home).
class MediaCard {
  final String id;
  final MediaCardType type;
  final String name;

  const MediaCard({required this.id, required this.type, required this.name});

  MediaCard copyWith({String? name}) => MediaCard(id: id, type: type, name: name ?? this.name);

  Map<String, dynamic> toJson() => {'id': id, 'type': type.name, 'name': name};

  static MediaCard? fromJson(Object? json) {
    if (json is! Map) return null;
    final type = MediaCardType.values.where((t) => t.name == json['type']).firstOrNull;
    final id = json['id'];
    if (type == null || id is! String) return null;
    return MediaCard(id: id, type: type, name: json['name'] as String? ?? '');
  }
}

/// The cards shown in the media panel, their order, and the panel's side and width.
/// Stream addresses can hold passwords, so they are kept in encrypted storage.
class MediaPanelService extends ChangeNotifier {
  static const _cardsKey = 'media_panel_cards';
  static const _streamsKey = 'media_panel_streams';
  // Shared with the old Home Assistant panel, so the chosen side and width carry over.
  static const _sideKey = 'home_assistant_panel_side';
  static const _wideKey = 'home_assistant_panel_wide';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;
  List<MediaCard> _cards = const [];
  Map<String, String> _streams = const {};

  MediaPanelService(this._prefs, {FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ??
            const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true)) {
    _load();
  }

  List<MediaCard> get cards => _cards;
  bool get hasHomeAssistant => _cards.any((c) => c.type == MediaCardType.homeAssistant);

  String? streamUrlOf(String cardId) => _streams[cardId];

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

  /// Picks up changes made by the other engine (launcher or panel).
  Future<void> reload() async {
    await _prefs.reload();
    await _load();
  }

  Future<void> _load() async {
    final raw = _prefs.getString(_cardsKey);
    if (raw == null) {
      _cards = _migrate();
      await _saveCards();
    } else {
      try {
        _cards = (jsonDecode(raw) as List).map(MediaCard.fromJson).whereType<MediaCard>().toList();
      } catch (_) {
        _cards = const [];
      }
    }
    try {
      final streams = await _secure.read(key: _streamsKey);
      _streams = streams == null ? const {} : Map<String, String>.from(jsonDecode(streams) as Map);
    } catch (_) {
      _streams = const {};
    }
    notifyListeners();
  }

  /// First start after the update: whoever used the Home Assistant panel gets it as a card.
  List<MediaCard> _migrate() {
    final usedHa = (_prefs.getString('home_assistant_url') ?? '').isNotEmpty ||
        (_prefs.getStringList('home_assistant_entities') ?? const []).isNotEmpty;
    return usedHa ? [MediaCard(id: _newId(), type: MediaCardType.homeAssistant, name: 'Home Assistant')] : const [];
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Future<void> _saveCards() => _prefs.setString(_cardsKey, jsonEncode(_cards.map((c) => c.toJson()).toList()));

  Future<void> _saveStreams() => _secure.write(key: _streamsKey, value: jsonEncode(_streams));

  static String normalizeStreamUrl(String value) {
    final trimmed = value.trim();
    return trimmed.contains('://') ? trimmed : 'rtsp://$trimmed';
  }

  Future<MediaCard> addCamera(String name, String url) async {
    final card = MediaCard(id: _newId(), type: MediaCardType.camera, name: name.trim().isEmpty ? 'Camera' : name.trim());
    _cards = [..._cards, card];
    _streams = {..._streams, card.id: normalizeStreamUrl(url)};
    await _saveStreams();
    await _saveCards();
    notifyListeners();
    return card;
  }

  Future<void> addHomeAssistant() async {
    if (hasHomeAssistant) return;
    _cards = [..._cards, MediaCard(id: _newId(), type: MediaCardType.homeAssistant, name: 'Home Assistant')];
    await _saveCards();
    notifyListeners();
  }

  Future<void> rename(String id, String name) async {
    if (name.trim().isEmpty) return;
    _cards = [for (final c in _cards) c.id == id ? c.copyWith(name: name.trim()) : c];
    await _saveCards();
    notifyListeners();
  }

  Future<void> setStreamUrl(String id, String url) async {
    if (url.trim().isEmpty) return;
    _streams = {..._streams, id: normalizeStreamUrl(url)};
    await _saveStreams();
    notifyListeners();
  }

  Future<void> move(String id, int delta) async {
    final list = [..._cards];
    final from = list.indexWhere((c) => c.id == id);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= list.length) return;
    list.insert(to, list.removeAt(from));
    _cards = list;
    await _saveCards();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _cards = _cards.where((c) => c.id != id).toList();
    if (_streams.containsKey(id)) {
      _streams = {..._streams}..remove(id);
      await _saveStreams();
    }
    await _saveCards();
    notifyListeners();
  }
}
