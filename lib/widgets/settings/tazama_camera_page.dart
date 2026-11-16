import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The Tazama Camera phone app: the phone streams its camera to the TV over Wi-Fi.
class TazamaCameraPage extends StatelessWidget {
  static const String routeName = 'tazama_camera';

  const TazamaCameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final body = Theme.of(context).textTheme.bodyMedium;
    final small = Theme.of(context).textTheme.bodySmall;

    return Column(
      children: [
        const SettingsPageHeader(title: 'Tazama Camera'),
        Expanded(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                child: Text(
                    'Use your phone as a camera on the TV. Install the Tazama Camera app on the phone; '
                    'the camera view shows a QR code to download it and pair.',
                    style: small),
              ),
              FocusableSettingsTile(
                autofocus: true,
                showChevron: true,
                leading: const Icon(Icons.videocam_rounded),
                title: Text('Open camera view', style: body),
                subtitle: Text('Pair a phone or watch its camera', style: small),
                onPressed: () => FLauncherChannel().openPhoneCamera(),
              ),
              RoundedSwitchListTile(
                value: !settings.quickPanelHidden.contains('camera'),
                onChanged: (value) => settings.setQuickPanelItemShown('camera', value),
                title: Text('Show in quick panel', style: body),
                secondary: const Icon(Icons.bolt_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
