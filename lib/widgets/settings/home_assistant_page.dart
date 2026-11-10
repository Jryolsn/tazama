import 'package:flauncher/providers/home_assistant_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/home_assistant_arrange_page.dart';
import 'package:flauncher/widgets/settings/home_assistant_dashboard_page.dart';
import 'package:flauncher/widgets/settings/home_assistant_entities_page.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flauncher/widgets/tv_text_prompt.dart';
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
                      help: 'IP or host name, e.g. 192.168.1.10 or homeassistant.local. Port 8123 is tried first, then 80.');
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
              if (ha.state == HaConnectionState.connected)
                FocusableSettingsTile(
                  leading: const Icon(Icons.toggle_on_rounded),
                  title: Text('Panel controls', style: body),
                  subtitle: Text(
                      ha.panelEntities.isEmpty
                          ? 'Choose lights, scenes, sensors and cameras'
                          : '${ha.panelEntities.length} chosen · hold Home to open the panel',
                      style: small),
                  showChevron: true,
                  onPressed: () => Navigator.of(context).pushNamed(HomeAssistantEntitiesPage.routeName),
                ),
              if (ha.state == HaConnectionState.connected)
                FocusableSettingsTile(
                  leading: const Icon(Icons.space_dashboard_rounded),
                  title: Text('Dashboard', style: body),
                  subtitle: Text(ha.dashboardPath ?? 'None · show one of your own dashboards from the panel',
                      style: small),
                  showChevron: true,
                  onPressed: () => Navigator.of(context).pushNamed(HomeAssistantDashboardPage.routeName),
                ),
              if (ha.state == HaConnectionState.connected) ...[
                FocusableSettingsTile(
                  leading: const Icon(Icons.reorder_rounded),
                  title: Text('Arrange controls', style: body),
                  subtitle: Text('Order, names and removal', style: small),
                  showChevron: true,
                  onPressed: () => Navigator.of(context).pushNamed(HomeAssistantArrangePage.routeName),
                ),
                const SettingsGroupLabel('Panel'),
                FocusableSettingsTile(
                  leading: Icon(ha.panelOnRight ? Icons.align_horizontal_right_rounded : Icons.align_horizontal_left_rounded),
                  title: Text('Side: ${ha.panelOnRight ? 'Right' : 'Left'}', style: body),
                  onPressed: () => ha.setPanelOnRight(!ha.panelOnRight),
                ),
                RoundedSwitchListTile(
                  value: ha.panelWide,
                  onChanged: ha.setPanelWide,
                  title: Text('Wide panel', style: body),
                  subtitle: Text('More room for cameras', style: small),
                  secondary: const Icon(Icons.width_wide_rounded),
                ),
                if (ha.dashboardPath != null)
                  RoundedSwitchListTile(
                    value: ha.holdHomeOpensDashboard,
                    onChanged: ha.setHoldHomeOpensDashboard,
                    title: Text('Hold Home opens the dashboard', style: body),
                    subtitle: Text('Back returns to the controls', style: small),
                    secondary: const Icon(Icons.space_dashboard_rounded),
                  ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.videocam_rounded),
                  title: Text('Camera refresh: every ${ha.cameraRefreshSeconds} s', style: body),
                  onPressed: () {
                    const choices = HomeAssistantService.cameraRefreshChoices;
                    final i = choices.indexOf(ha.cameraRefreshSeconds);
                    ha.setCameraRefreshSeconds(choices[(i + 1) % choices.length]);
                  },
                ),
                const SettingsGroupLabel('Server'),
              ],
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
      askTvText(context,
          title: title, help: help, initial: initialValue, secret: obscure, kind: obscure ? TvTextKind.text : TvTextKind.url);
}
