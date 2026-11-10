import 'package:flauncher/home_assistant/home_assistant_service.dart';
import 'package:flauncher/home_assistant/panel.dart';
import 'package:flauncher/home_assistant/settings/home_assistant_screen.dart';
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
  final _open = <String>{};

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

    // Area -> device -> entities. Areas and devices with no name go last.
    String areaOf(HaEntity e) => registry?.areaNameOf(e.entityId) ?? '';
    String deviceOf(HaEntity e) => registry?.deviceNameOf(e.entityId) ?? '';
    int byName(String a, String b) {
      if (a.isEmpty != b.isEmpty) return a.isEmpty ? 1 : -1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    }

    entities.sort((a, b) {
      final area = byName(areaOf(a), areaOf(b));
      if (area != 0) return area;
      final device = byName(deviceOf(a), deviceOf(b));
      if (device != 0) return device;
      final byDomain = _domainOrder.indexOf(a.domain).compareTo(_domainOrder.indexOf(b.domain));
      return byDomain != 0 ? byDomain : ha.nameOf(a).toLowerCase().compareTo(ha.nameOf(b).toLowerCase());
    });

    final searching = _query.isNotEmpty || _domain != null || _chosenOnly;

    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Text('Controls', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ),
      _CompactRow(
        icon: Icons.search_rounded,
        title: _query.isEmpty ? 'Search' : 'Search: $_query',
        onPressed: () async {
          final value = await askTvText(context, title: 'Search', initial: _query);
          if (value != null && mounted) setState(() => _query = value.trim());
        },
      ),
      _CompactRow(
        icon: Icons.filter_list_rounded,
        title: 'Type: ${_domain == null ? 'All' : haDomainLabel(_domain!)}',
        onPressed: () {
          final domains = _domains;
          final i = _domain == null ? -1 : domains.indexOf(_domain!);
          setState(() => _domain = i + 1 >= domains.length ? null : domains[i + 1]);
        },
      ),
      _CompactRow(
        icon: Icons.star_rounded,
        title: 'Only chosen',
        checked: _chosenOnly,
        onPressed: () => setState(() => _chosenOnly = !_chosenOnly),
      ),
      if (registry != null)
        _CompactRow(
          icon: Icons.visibility_rounded,
          title: 'Show diagnostic and hidden',
          checked: _showHidden,
          onPressed: () => setState(() => _showHidden = !_showHidden),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Text('${entities.length} entities · ${chosen.length} in the panel', style: small),
      ),
    ];

    // Walk the sorted entities, one area at a time.
    var index = 0;
    while (index < entities.length) {
      final area = areaOf(entities[index]);
      var end = index;
      while (end < entities.length && areaOf(entities[end]) == area) {
        end++;
      }
      final group = entities.sublist(index, end);
      index = end;

      final areaKey = area.isEmpty ? '(no area)' : area;
      final open = searching || _open.contains(areaKey);
      final chosenHere = group.where((e) => chosen.contains(e.entityId)).length;
      rows.add(_CompactRow(
        icon: open ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
        title: '${area.isEmpty ? 'No area' : area}  (${group.length})',
        trailing: chosenHere == 0 ? null : '$chosenHere chosen',
        bold: true,
        onPressed: searching
            ? null
            : () => setState(() {
                  if (!_open.remove(areaKey)) _open.add(areaKey);
                }),
      ));
      if (!open) continue;

      String? device;
      for (final entity in group) {
        final entityDevice = deviceOf(entity);
        if (entityDevice != device && entityDevice.isNotEmpty) {
          device = entityDevice;
          rows.add(Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 12, 2),
            child: Text(entityDevice, style: small?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700)),
          ));
        } else if (entityDevice.isEmpty) {
          device = null;
        }
        rows.add(_CompactRow(
          indent: 20,
          leading: Icon(haEntityIcon(entity), size: 18),
          title: ha.nameOf(entity),
          trailing: entity.displayState,
          checked: chosen.contains(entity.entityId),
          onPressed: () => ha.setPanelEntity(entity.entityId, !chosen.contains(entity.entityId)),
        ));
      }
    }
    if (entities.isEmpty) {
      rows.add(const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Nothing matches.'))));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: rows.length,
      itemBuilder: (_, i) => rows[i],
    );
  }
}

/// A dense, focusable row (about 40 dp) used for long lists. [checked] shows a check box.
class _CompactRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? trailing;
  final bool? checked;
  final bool bold;
  final double indent;
  final VoidCallback? onPressed;

  const _CompactRow({
    this.icon,
    this.leading,
    required this.title,
    this.trailing,
    this.checked,
    this.bold = false,
    this.indent = 0,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(4 + indent, 1, 4, 1),
      child: Focus(
        canRequestFocus: onPressed != null,
        child: Builder(builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return Actions(
            actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onPressed?.call())},
            child: GestureDetector(
              onTap: onPressed,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: focused ? accent.withValues(alpha: 0.22) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: focused ? accent : Colors.transparent, width: 2),
                ),
                child: Row(children: [
                  leading ?? (icon == null ? const SizedBox.shrink() : Icon(icon, size: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.w700 : null)),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    Text(trailing!, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                  ],
                  if (checked != null) ...[
                    const SizedBox(width: 8),
                    Icon(checked! ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        size: 22, color: checked! ? accent : Colors.white54),
                  ],
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}
