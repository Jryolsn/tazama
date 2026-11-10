import 'package:flauncher/home_assistant/home_assistant_service.dart';
import 'package:flauncher/home_assistant/panel.dart';
import 'package:flauncher/home_assistant/settings/home_assistant_screen.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flauncher/widgets/tv_text_prompt.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Picks the panel's entities among many: grouped by area, filtered by type, searchable.
class EntitiesSection extends StatefulWidget {
  final HaData data;

  const EntitiesSection({super.key, required this.data});

  @override
  State<EntitiesSection> createState() => _EntitiesSectionState();
}

class _EntitiesSectionState extends State<EntitiesSection> {
  static const _domainOrder = [
    'light', 'switch', 'scene', 'script', 'camera', 'media_player', 'cover', 'fan', 'lock', 'climate',
    'vacuum', 'sensor', 'binary_sensor', 'input_boolean', 'automation', 'button', 'input_button', 'siren',
    'humidifier', 'water_heater', 'weather', 'person', 'device_tracker',
  ];

  String _query = '';
  String? _domain; // null = all types
  bool _chosenOnly = false;
  bool _showHidden = false;

  List<String> get _domains {
    final present = widget.data.states.values.map((e) => e.domain).toSet();
    return _domainOrder.where(present.contains).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    final chosen = ha.panelEntities.toSet();
    final registry = widget.data.registry;
    final small = Theme.of(context).textTheme.bodySmall;
    final query = _query.toLowerCase();

    final entities = widget.data.states.values.where((e) {
      if (!HomeAssistantService.supportedDomains.contains(e.domain)) return false;
      if (_domain != null && e.domain != _domain) return false;
      if (_chosenOnly && !chosen.contains(e.entityId)) return false;
      if (!_showHidden && registry != null && registry.hidden.contains(e.entityId) && !chosen.contains(e.entityId)) {
        return false;
      }
      if (query.isNotEmpty &&
          !ha.nameOf(e).toLowerCase().contains(query) &&
          !e.entityId.contains(query) &&
          !(registry?.areaNameOf(e.entityId)?.toLowerCase().contains(query) ?? false)) {
        return false;
      }
      return true;
    }).toList();

    // Group by area (no area last), then type, then name.
    String areaOf(HaEntity e) => registry?.areaNameOf(e.entityId) ?? '';
    entities.sort((a, b) {
      final areaA = areaOf(a), areaB = areaOf(b);
      if (areaA != areaB) {
        if (areaA.isEmpty) return 1;
        if (areaB.isEmpty) return -1;
        return areaA.toLowerCase().compareTo(areaB.toLowerCase());
      }
      final byDomain = _domainOrder.indexOf(a.domain).compareTo(_domainOrder.indexOf(b.domain));
      return byDomain != 0 ? byDomain : ha.nameOf(a).toLowerCase().compareTo(ha.nameOf(b).toLowerCase());
    });

    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Text('Controls', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ),
      FocusableSettingsTile(
        leading: const Icon(Icons.search_rounded),
        title: Text(_query.isEmpty ? 'Search' : 'Search: $_query'),
        subtitle: Text('Name, entity id or area', style: small),
        onPressed: () async {
          final value = await askTvText(context, title: 'Search', initial: _query);
          if (value != null && mounted) setState(() => _query = value.trim());
        },
      ),
      FocusableSettingsTile(
        leading: const Icon(Icons.filter_list_rounded),
        title: Text('Type: ${_domain == null ? 'All' : haDomainLabel(_domain!)}'),
        subtitle: Text('OK to change', style: small),
        onPressed: () {
          final domains = _domains;
          final i = _domain == null ? -1 : domains.indexOf(_domain!);
          setState(() => _domain = i + 1 >= domains.length ? null : domains[i + 1]);
        },
      ),
      RoundedSwitchListTile(
        value: _chosenOnly,
        onChanged: (v) => setState(() => _chosenOnly = v),
        title: const Text('Only chosen'),
        secondary: const Icon(Icons.star_rounded),
      ),
      if (registry != null)
        RoundedSwitchListTile(
          value: _showHidden,
          onChanged: (v) => setState(() => _showHidden = v),
          title: const Text('Show diagnostic and hidden'),
          secondary: const Icon(Icons.visibility_rounded),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text('${entities.length} entities · ${chosen.length} in the panel', style: small),
      ),
    ];

    String? area;
    for (final entity in entities) {
      final entityArea = areaOf(entity);
      if (entityArea != area) {
        area = entityArea;
        rows.add(SettingsGroupLabel(entityArea.isEmpty ? 'No area' : entityArea));
      }
      rows.add(RoundedSwitchListTile(
        value: chosen.contains(entity.entityId),
        onChanged: (value) => ha.setPanelEntity(entity.entityId, value),
        title: Text(ha.nameOf(entity), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${haDomainLabel(entity.domain)} · ${entity.displayState}',
            style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
        secondary: Icon(haEntityIcon(entity)),
      ));
    }
    if (entities.isEmpty) {
      rows.add(const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Nothing matches.'))));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      itemCount: rows.length,
      itemBuilder: (_, i) => rows[i],
    );
  }
}
