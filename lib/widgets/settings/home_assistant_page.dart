import 'package:flauncher/providers/home_assistant_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Connects Tazama to a Home Assistant server.
class HomeAssistantPage extends StatelessWidget {
  static const String routeName = "home_assistant_panel";

  const HomeAssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    final body = Theme.of(context).textTheme.bodyMedium;
    final small = Theme.of(context).textTheme.bodySmall;

    final (IconData icon, Color color, String text) = switch (ha.state) {
      HaConnectionState.notConfigured => (Icons.link_off_rounded, Colors.white54, 'Not connected'),
      HaConnectionState.checking => (Icons.sync_rounded, Colors.white70, 'Connecting...'),
      HaConnectionState.connected => (
          Icons.check_circle_rounded,
          Colors.lightGreenAccent,
          ['Connected', ha.locationName, if (ha.version != null) 'HA ${ha.version}'].whereType<String>().join(' · ')
        ),
      HaConnectionState.unauthorized => (Icons.key_off_rounded, Colors.orangeAccent, ha.error ?? 'Token rejected'),
      HaConnectionState.unreachable => (Icons.cloud_off_rounded, Colors.orangeAccent, ha.error ?? 'Unreachable'),
    };

    return Column(
      children: [
        const SettingsPageHeader(title: 'Home Assistant'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(text, style: body)),
                ]),
              ),
              FocusableSettingsTile(
                autofocus: true,
                leading: const Icon(Icons.dns_rounded),
                title: Text('Server address', style: body),
                subtitle: Text(ha.url ?? 'e.g. 192.168.1.10:8123', style: small),
                onPressed: () async {
                  final value = await _askText(context, 'Server address', ha.url ?? '',
                      help: 'IP or host name of Home Assistant. Port 8123 is added if none is given.');
                  if (value != null) await ha.setUrl(value);
                },
              ),
              FocusableSettingsTile(
                leading: const Icon(Icons.key_rounded),
                title: Text('Access token', style: body),
                subtitle: Text(ha.hasToken ? 'Saved (encrypted on this TV)' : 'Not set', style: small),
                onPressed: () async {
                  final value = await _askText(context, 'Access token', '',
                      help: 'In Home Assistant: your profile > Security > Long-lived access tokens > Create token.',
                      obscure: true);
                  if (value != null && value.trim().isNotEmpty) await ha.setToken(value);
                },
              ),
              if (ha.isConfigured)
                FocusableSettingsTile(
                  leading: const Icon(Icons.network_check_rounded),
                  title: Text('Test connection', style: body),
                  onPressed: ha.state == HaConnectionState.checking ? null : ha.testConnection,
                ),
              if (ha.url != null || ha.hasToken)
                FocusableSettingsTile(
                  leading: const Icon(Icons.link_off_rounded),
                  title: Text('Disconnect', style: body),
                  subtitle: Text('Removes the address and token', style: small),
                  onPressed: ha.disconnect,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<String?> _askText(BuildContext context, String title, String initialValue,
          {String? help, bool obscure = false}) =>
      showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          insetPadding: const EdgeInsets.only(bottom: 120),
          contentPadding: const EdgeInsets.all(24),
          title: Text(title),
          children: [
            if (help != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(help)),
            TextFormField(
              autofocus: true,
              initialValue: initialValue,
              obscureText: obscure,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: obscure ? TextInputType.visiblePassword : TextInputType.url,
              onFieldSubmitted: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
      );
}
