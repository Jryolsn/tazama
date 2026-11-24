import 'package:flauncher/desktop/desktop.dart';
import 'package:flauncher/desktop/desktop_service.dart';
import 'package:flauncher/home_assistant/home_assistant_service.dart';
import 'package:flauncher/media_panel/media_panel_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  late DesktopService desktop;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'desktop_pages': '[[{"id":"clock","type":"clock","w":2,"h":2,"x":0,"y":0},'
          '{"id":"ha","type":"homeAssistant","w":1,"h":1,"ref":"light.x","x":3,"y":1}],'
          '[{"id":"clock2","type":"clock","w":4,"h":1,"x":0,"y":0}]]',
    });
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    desktop = DesktopService(prefs);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: desktop),
        ChangeNotifierProvider(create: (_) => SettingsService(prefs)),
        ChangeNotifierProvider(create: (_) => HomeAssistantService(prefs)),
        ChangeNotifierProvider(create: (_) => MediaPanelService(prefs)),
      ],
      child: const MaterialApp(home: Scaffold(body: Desktop())),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  testWidgets('the clock takes no focus and the pencil turns pages', (tester) async {
    await pump(tester);
    expect(desktop.pages[0].first.type, DesktopWidgetType.clock);
    final state = tester.state<DesktopState>(find.byType(Desktop));
    expect(state.focusFromBelow(const Rect.fromLTWH(0, 500, 200, 40)), isTrue);
    await tester.pumpAndSettle();
    expect(_focused(), 'desktop:ha');
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused(), 'desktop:ha');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused(), 'desktop:_pencil');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused(), 'desktop:_pencil');
    expect(find.byKey(const ValueKey('clock2')), findsOneWidget);
  });

  testWidgets('edit mode offers new pages on both sides and Home returns to the home page', (tester) async {
    await pump(tester);
    tester.state<DesktopState>(find.byType(Desktop)).focusFromBelow(const Rect.fromLTWH(0, 500, 200, 40));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    expect(find.text('Done'), findsOneWidget);
    expect(_focused(), 'desktop:clock');

    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused(), 'desktop:_new_page');
    await press(tester, LogicalKeyboardKey.select);
    expect(desktop.pages.length, 3);
    expect(desktop.homePage, 1);
    expect(_focused(), 'desktop:_cell:0:0');

    await press(tester, LogicalKeyboardKey.escape);
    expect(find.text('Done'), findsNothing);
    expect(_focused(), 'desktop:_pencil');

    await tester.binding.defaultBinaryMessenger.handlePlatformMessage('com.jryolsn.tazama/home',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('home')), (_) {});
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ha')), findsOneWidget);
  });
}
