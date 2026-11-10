import 'package:flauncher/home_assistant/home_assistant_service.dart';
import 'package:flauncher/home_assistant/panel.dart';
import 'package:flauncher/home_assistant/settings/entities_section.dart';
import 'package:flauncher/nebula_theme.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flauncher/widgets/tv_text_prompt.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Opens the full-screen Home Assistant settings, closing the settings side panel first if asked.
void openHomeAssistantSettings(BuildContext context, {bool closeSettingsPanel = false}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (closeSettingsPanel) navigator.pop();
  navigator.push(MaterialPageRoute(builder: (_) => const HomeAssistantScreen()));
}

enum _Section { connection, controls, arrange, dashboard, panel }

/// Home Assistant settings as a full screen: a menu on the left, the chosen section on the right.
class HomeAssistantScreen extends StatefulWidget {
  const HomeAssistantScreen({super.key});

  @override
  State<HomeAssistantScreen> createState() => _HomeAssistantScreenState();
}

class _HomeAssistantScreenState extends State<HomeAssistantScreen> {
  _Section _section = _Section.connection;
  HaData? _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ha = context.read<HomeAssistantService>();
    if (ha.state != HaConnectionState.connected) return;
    setState(() => _loading = true);
    final results = await Future.wait([ha.fetchStates(), ha.fetchRegistry()]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      final states = results[0] as List<HaEntity>?;
      _data = states == null ? null : HaData(states, results[1] as HaRegistry?);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    final connected = ha.state == HaConnectionState.connected;
    if (connected && _data == null && !_loading) WidgetsBinding.instance.addPostFrameCallback((_) => _load());

    Widget item(_Section section, IconData icon, String title, String subtitle, {bool enabled = true}) => Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) {
            if (focused && _section != section) setState(() => _section = section);
          },
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: FocusableSettingsTile(
              autofocus: section == _Section.connection,
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              onPressed: () => FocusScope.of(context).focusInDirection(TraversalDirection.right),
            ),
          ),
        );

    return Scaffold(
      backgroundColor: Nebula.deep,
      body: Stack(
        children: [
          const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _NebulaPainter()))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 270,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          child: Text('Home Assistant',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: _StatusLine(ha: ha),
                        ),
                        Expanded(
                          child: ListView(
                            children: [
                              item(_Section.connection, Icons.link_rounded, 'Connection', ha.url ?? 'Not set up'),
                              item(_Section.controls, Icons.toggle_on_rounded, 'Controls',
                                  '${ha.panelEntities.length} in the panel',
                                  enabled: connected),
                              item(_Section.arrange, Icons.reorder_rounded, 'Arrange', 'Order and names',
                                  enabled: connected),
                              item(_Section.dashboard, Icons.space_dashboard_rounded, 'Dashboard',
                                  ha.dashboardPath ?? 'None',
                                  enabled: connected),
                              item(_Section.panel, Icons.view_sidebar_rounded, 'Panel', 'Side, width, cameras'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Nebula.surface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(SettingsStyle.cardRadius),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FocusTraversalGroup(child: _content(ha, connected)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(HomeAssistantService ha, bool connected) {
    if (_section != _Section.connection && _section != _Section.panel && !connected) {
      return const _Message('Connect to Home Assistant first.');
    }
    switch (_section) {
      case _Section.connection:
        return _ConnectionSection(onConnected: _load);
      case _Section.panel:
        return const _PanelSection();
      case _Section.dashboard:
        return const _DashboardSection();
      case _Section.controls:
      case _Section.arrange:
        final data = _data;
        if (data == null) {
          return _loading
              ? const Center(child: CircularProgressIndicator())
              : _Message('Could not load entities.', action: ('Try again', _load));
        }
        return _section == _Section.controls ? EntitiesSection(data: data) : _ArrangeSection(data: data);
    }
  }
}

/// States and registry loaded once for the screen.
class HaData {
  final Map<String, HaEntity> states;
  final HaRegistry? registry;

  HaData(List<HaEntity> list, this.registry) : states = {for (final e in list) e.entityId: e};
}

class _NebulaPainter extends CustomPainter {
  const _NebulaPainter();

  @override
  void paint(Canvas canvas, Size size) => Nebula.paintBackground(canvas, Offset.zero & size);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatusLine extends StatelessWidget {
  final HomeAssistantService ha;

  const _StatusLine({required this.ha});

  @override
  Widget build(BuildContext context) {
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
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

class _Message extends StatelessWidget {
  final String text;
  final (String, VoidCallback)? action;

  const _Message(this.text, {this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
          if (action != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: action!.$2, child: Text(action!.$1)),
          ],
        ]),
      );
}

class _SectionList extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionList({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ...children,
        ],
      );
}

class _ConnectionSection extends StatelessWidget {
  final VoidCallback onConnected;

  const _ConnectionSection({required this.onConnected});

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    final small = Theme.of(context).textTheme.bodySmall;
    Future<void> after() async {
      if (ha.state == HaConnectionState.connected) onConnected();
    }

    return _SectionList(title: 'Connection', children: [
      FocusableSettingsTile(
        leading: const Icon(Icons.dns_rounded),
        title: const Text('Server address'),
        subtitle: Text(ha.url ?? 'e.g. 192.168.1.10 or homeassistant.local', style: small),
        onPressed: () async {
          final value = await askTvText(context,
              title: 'Server address',
              initial: ha.url ?? '',
              kind: TvTextKind.url,
              help: 'IP or host name, e.g. 192.168.1.10 or homeassistant.local. Port 8123 is tried first, then 80.');
          if (value != null) {
            await ha.setUrl(value);
            await after();
          }
        },
      ),
      FocusableSettingsTile(
        leading: const Icon(Icons.key_rounded),
        title: const Text('Access token'),
        subtitle: Text(ha.hasToken ? 'Saved (encrypted on this TV)' : 'Not set', style: small),
        onPressed: () async {
          final value = await askTvText(context,
              title: 'Access token',
              secret: true,
              help: 'In Home Assistant: your profile > Security > Long-lived access tokens > Create token.');
          if (value != null && value.trim().isNotEmpty) {
            await ha.setToken(value);
            await after();
          }
        },
      ),
      if (ha.isConfigured)
        FocusableSettingsTile(
          leading: const Icon(Icons.network_check_rounded),
          title: const Text('Test connection'),
          onPressed: ha.state == HaConnectionState.checking
              ? null
              : () async {
                  await ha.testConnection();
                  await after();
                },
        ),
      if (ha.url != null || ha.hasToken)
        FocusableSettingsTile(
          leading: const Icon(Icons.link_off_rounded),
          title: const Text('Disconnect'),
          subtitle: Text('Removes the address and token', style: small),
          onPressed: ha.disconnect,
        ),
    ]);
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection();

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    final small = Theme.of(context).textTheme.bodySmall;
    return _SectionList(title: 'Panel (hold Home)', children: [
      FocusableSettingsTile(
        leading: Icon(ha.panelOnRight ? Icons.align_horizontal_right_rounded : Icons.align_horizontal_left_rounded),
        title: Text('Side: ${ha.panelOnRight ? 'Right' : 'Left'}'),
        onPressed: () => ha.setPanelOnRight(!ha.panelOnRight),
      ),
      RoundedSwitchListTile(
        value: ha.panelWide,
        onChanged: ha.setPanelWide,
        title: const Text('Wide panel'),
        subtitle: Text('More room for cameras', style: small),
        secondary: const Icon(Icons.width_wide_rounded),
      ),
      FocusableSettingsTile(
        leading: const Icon(Icons.videocam_rounded),
        title: Text('Camera refresh: every ${ha.cameraRefreshSeconds} s'),
        onPressed: () {
          const choices = HomeAssistantService.cameraRefreshChoices;
          final i = choices.indexOf(ha.cameraRefreshSeconds);
          ha.setCameraRefreshSeconds(choices[(i + 1) % choices.length]);
        },
      ),
    ]);
  }
}

class _DashboardSection extends StatefulWidget {
  const _DashboardSection();

  @override
  State<_DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<_DashboardSection> {
  Map<String, String>? _dashboards;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    context.read<HomeAssistantService>().fetchDashboards().then((value) {
      if (mounted) {
        setState(() {
          _dashboards = value;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    final current = ha.dashboardPath;
    final small = Theme.of(context).textTheme.bodySmall;
    final dashboards = _dashboards ?? {if (current != null) current: current};

    Widget option(String? path, String title) => FocusableSettingsTile(
          leading: Icon(path == current ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
          title: Text(title),
          onPressed: () => ha.setDashboardPath(path),
        );

    return _SectionList(title: 'Dashboard', children: [
      if (current != null)
        RoundedSwitchListTile(
          value: ha.holdHomeOpensDashboard,
          onChanged: ha.setHoldHomeOpensDashboard,
          title: const Text('Hold Home opens the dashboard'),
          subtitle: Text('Back returns to the controls', style: small),
          secondary: const Icon(Icons.home_rounded),
        ),
      const SettingsGroupLabel('Show in the panel'),
      option(null, 'None (only controls)'),
      if (_loading)
        const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
      else ...[
        if (_dashboards == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Could not list dashboards.', style: TextStyle(color: Colors.orangeAccent)),
          ),
        for (final entry in dashboards.entries) option(entry.key, entry.value),
      ],
    ]);
  }
}

class _ArrangeSection extends StatelessWidget {
  final HaData data;

  const _ArrangeSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    final small = Theme.of(context).textTheme.bodySmall;
    final ids = ha.panelEntities;
    if (ids.isEmpty) return const _Message('No controls chosen yet. Pick them under Controls.');

    String nameOf(String id) => data.states[id] == null ? (ha.aliases[id] ?? id) : ha.nameOf(data.states[id]!);

    return _SectionList(title: 'Arrange', children: [
      for (final (index, id) in ids.indexed)
        FocusableSettingsTile(
          leading: Icon(data.states[id] == null ? Icons.help_outline_rounded : haEntityIcon(data.states[id]!)),
          title: Text(nameOf(id)),
          subtitle: Text(
              ['${index + 1}', data.registry?.areaNameOf(id), id].whereType<String>().join(' · '),
              style: small),
          onPressed: () => _edit(context, ha, id, nameOf(id)),
        ),
    ]);
  }

  Future<void> _edit(BuildContext context, HomeAssistantService ha, String id, String name) async {
    final index = ha.panelEntities.indexOf(id);
    final last = ha.panelEntities.length - 1;
    Widget option(BuildContext context, String value, IconData icon, String label, {bool first = false}) =>
        FocusableSettingsTile(
          autofocus: first,
          leading: Icon(icon),
          title: Text(label),
          onPressed: () => Navigator.of(context).pop(value),
        );
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(name),
        children: [
          if (index > 0) option(context, 'top', Icons.vertical_align_top_rounded, 'Move to top'),
          if (index > 0) option(context, 'up', Icons.arrow_upward_rounded, 'Move up', first: true),
          if (index < last) option(context, 'down', Icons.arrow_downward_rounded, 'Move down', first: index == 0),
          option(context, 'rename', Icons.edit_rounded, 'Rename', first: index == 0 && last == 0),
          if (ha.aliases.containsKey(id)) option(context, 'reset', Icons.undo_rounded, 'Use Home Assistant name'),
          option(context, 'remove', Icons.delete_outline_rounded, 'Remove from panel'),
        ],
      ),
    );
    switch (choice) {
      case 'top':
        await ha.movePanelEntity(id, -index);
      case 'up':
        await ha.movePanelEntity(id, -1);
      case 'down':
        await ha.movePanelEntity(id, 1);
      case 'reset':
        await ha.setAlias(id, null);
      case 'remove':
        await ha.setPanelEntity(id, false);
      case 'rename':
        if (!context.mounted) return;
        final value = await askTvText(context, title: 'Name in the panel', initial: name);
        if (value != null) await ha.setAlias(id, value);
    }
  }
}
