import 'package:flauncher/providers/home_assistant_service.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Picks the Home Assistant dashboard that the panel can open.
class HomeAssistantDashboardPage extends StatefulWidget {
  static const String routeName = "home_assistant_dashboard_panel";

  const HomeAssistantDashboardPage({super.key});

  @override
  State<HomeAssistantDashboardPage> createState() => _HomeAssistantDashboardPageState();
}

class _HomeAssistantDashboardPageState extends State<HomeAssistantDashboardPage> {
  Map<String, String>? _dashboards;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    context.read<HomeAssistantService>().fetchDashboards().then((value) {
      if (mounted) setState(() {
        _dashboards = value;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    final body = Theme.of(context).textTheme.bodyMedium;
    final current = ha.dashboardPath;
    final dashboards = _dashboards ?? {if (current != null) current: current};

    Widget option(String? path, String title, {bool autofocus = false}) => FocusableSettingsTile(
          autofocus: autofocus,
          leading: Icon(path == current ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
          title: Text(title, style: body),
          onPressed: () => ha.setDashboardPath(path),
        );

    return Column(
      children: [
        const SettingsPageHeader(title: 'Dashboard'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              option(null, 'None (only panel controls)', autofocus: true),
              if (_loading)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else ...[
                if (_dashboards == null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Could not list dashboards.', style: const TextStyle(color: Colors.orangeAccent)),
                  ),
                for (final entry in dashboards.entries) option(entry.key, entry.value),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
