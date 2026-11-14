import 'package:flauncher/media_panel/media_panel_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions,
          WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async =>
      values[key];

  @override
  Future<void> write({required String key, required String? value, AppleOptions? iOptions, AndroidOptions? aOptions,
      LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

Future<MediaPanelService> _service(Map<String, Object> prefs, [_MemorySecureStorage? secure]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final service = MediaPanelService(await SharedPreferences.getInstance(), secureStorage: secure ?? _MemorySecureStorage());
  await service.reload();
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('new users start with no cards', () async {
    final service = await _service({});
    expect(service.cards, isEmpty);
  });

  test('Home Assistant users get a Home Assistant card once', () async {
    final service = await _service({'home_assistant_url': 'http://192.168.1.2'});
    expect(service.cards.map((c) => c.type), [MediaCardType.homeAssistant]);
    await service.remove(service.cards.single.id);
    await service.reload();
    expect(service.cards, isEmpty);
  });

  test('cameras keep their stream, order and names', () async {
    final secure = _MemorySecureStorage();
    final service = await _service({}, secure);
    final door = await service.addCamera('Door', '192.168.1.20:554/stream2');
    await service.addHomeAssistant();
    await service.addHomeAssistant();
    expect(service.cards.length, 2);
    expect(service.streamUrlOf(door.id), 'rtsp://192.168.1.20:554/stream2');

    await service.move(door.id, 1);
    await service.rename(door.id, 'Front door');
    expect(service.cards.last.name, 'Front door');

    await service.reload();
    expect(service.cards.map((c) => c.type), [MediaCardType.homeAssistant, MediaCardType.camera]);
    expect(service.streamUrlOf(door.id), 'rtsp://192.168.1.20:554/stream2');

    await service.remove(door.id);
    expect(service.streamUrlOf(door.id), isNull);
  });

  test('side and width carry over from the old panel', () async {
    final service = await _service({'home_assistant_panel_side': 'left', 'home_assistant_panel_wide': true});
    expect(service.panelOnRight, isFalse);
    expect(service.panelWide, isTrue);
  });
}
