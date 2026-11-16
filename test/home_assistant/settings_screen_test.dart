import 'package:flauncher/home_assistant/home_assistant_service.dart';
import 'package:flauncher/home_assistant/notices.dart';
import 'package:flauncher/home_assistant/settings/home_assistant_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Mem extends FlutterSecureStorage {
  final Map<String, String> v = {};
  @override
  Future<String?> read({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions,
          WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async => v[key];
  @override
  Future<void> write({required String key, required String? value, AppleOptions? iOptions, AndroidOptions? aOptions,
      LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async {
    if (value == null) {
      v.remove(key);
    } else {
      v[key] = value;
    }
  }
}

class _Fake extends HomeAssistantService {
  _Fake(super.prefs, {super.secureStorage});
  @override
  HaConnectionState get state => HaConnectionState.connected;
  @override
  Future<List<HaEntity>?> fetchStates() async => [
        HaEntity.fromJson({'entity_id': 'light.a', 'state': 'on', 'attributes': {'friendly_name': 'Lamp'}}),
        HaEntity.fromJson({'entity_id': 'camera.c', 'state': 'idle', 'attributes': {'friendly_name': 'Cam'}}),
      ];
  @override
  Future<HaRegistry?> fetchRegistry() async => null;
}

void main() {
  testWidgets('Controls rows react to OK and arrows stay in their column', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ha = _Fake(prefs, secureStorage: _Mem());
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<HomeAssistantService>.value(value: ha),
      ChangeNotifierProvider(create: (_) => HaNoticeSettings(prefs)),
    ], child: MaterialApp(theme: ThemeData.dark(), home: const HomeAssistantScreen())));
    await tester.pumpAndSettle();
    const d = LogicalKeyboardKey.arrowDown, r = LogicalKeyboardKey.arrowRight, l = LogicalKeyboardKey.arrowLeft;
    const ok = LogicalKeyboardKey.select;
    // Menu -> Controls, into the list, open the group, pick both entities, back to the menu.
    for (final k in [d, r, d, d, d, ok, d, ok, d, ok, d, d, l]) {
      await tester.sendKeyEvent(k);
      await tester.pumpAndSettle();
    }
    expect(ha.panelEntities, ['light.a', 'camera.c']);
    expect(find.text('2 in the panel'), findsOneWidget);
  });
}
