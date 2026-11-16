import 'package:flauncher/home_assistant/home_assistant_service.dart';
import 'package:flauncher/media_panel/media_panel.dart';
import 'package:flauncher/media_panel/media_panel_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('focus starts on the first card, not on settings', (tester) async {
    SharedPreferences.setMockInitialValues({
      // Home Assistant first but not set up, so it has nothing to focus.
      'media_panel_cards': '[{"id":"b","type":"homeAssistant","name":"Home Assistant"},'
          '{"id":"a","type":"camera","name":"Front door"}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final media = MediaPanelService(prefs);
    await tester.runAsync(media.reload);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: HomeAssistantService(prefs)),
        ChangeNotifierProvider.value(value: media),
      ],
      child: MaterialApp(home: Scaffold(body: MediaPanel(onOpenSettings: () {}))),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(find.descendant(of: find.byWidget(focused.widget), matching: find.text('Front door')), findsOneWidget);
  });
}
