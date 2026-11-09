import 'package:flauncher/providers/home_assistant_service.dart';
import 'package:flauncher/widgets/home_assistant_panel.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Picks the entities shown in the Home Assistant panel.
class HomeAssistantEntitiesPage extends StatefulWidget {
  static const String routeName = "home_assistant_entities_panel";

  const HomeAssistantEntitiesPage({super.key});

  @override
  State<HomeAssistantEntitiesPage> createState() => _HomeAssistantEntitiesPageState();
}

class _HomeAssistantEntitiesPageState extends State<HomeAssistantEntitiesPage> {
  List<HaEntity>? _entities;
  bool _loading = true;

  static const _domainOrder = [
    'light', 'switch', 'scene', 'script', 'camera', 'cover', 'fan', 'lock',
    'media_player', 'climate', 'sensor', 'binary_sensor', 'input_boolean',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await context.read<HomeAssistantService>().fetchStates();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _entities = all
          ?.where((e) => HomeAssistantService.supportedDomains.contains(e.domain))
          .toList()
        ?..sort((a, b) {
          final byDomain = _domainOrder.indexOf(a.domain).compareTo(_domainOrder.indexOf(b.domain));
          return byDomain != 0 ? byDomain : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    final chosen = ha.panelEntities.toSet();
    final body = Theme.of(context).textTheme.bodyMedium;
    final small = Theme.of(context).textTheme.bodySmall;
    final entities = _entities;

    final children = <Widget>[];
    if (_loading) {
      children.add(const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
    } else if (entities == null) {
      children.add(Padding(
          padding: const EdgeInsets.all(16), child: Text('Could not reach Home Assistant.', style: body)));
    } else {
      String? domain;
      for (final entity in entities) {
        if (entity.domain != domain) {
          domain = entity.domain;
          children.add(SettingsGroupLabel(haDomainLabel(domain)));
        }
        children.add(RoundedSwitchListTile(
          autofocus: children.length == 1,
          value: chosen.contains(entity.entityId),
          onChanged: (value) => ha.setPanelEntity(entity.entityId, value),
          title: Text(entity.name, style: body),
          subtitle: Text(entity.displayState, style: small),
          secondary: Icon(haEntityIcon(entity)),
        ));
      }
    }

    return Column(
      children: [
        const SettingsPageHeader(title: 'Panel controls'),
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: children)),
      ],
    );
  }
}
