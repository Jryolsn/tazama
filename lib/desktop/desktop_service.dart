import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a desktop widget shows.
enum DesktopWidgetType { clock, camera, homeAssistant, app, watchNext }

/// Grid size of a desktop page, in cells.
const int kDesktopColumns = 4;
const int kDesktopRows = 2;

/// Sizes a widget can take (columns x rows).
const List<(int, int)> kDesktopSizes = [(1, 1), (2, 1), (2, 2), (4, 1), (4, 2)];

String desktopSizeLabel((int, int) size) => switch (size) {
      (1, 1) => 'Small',
      (2, 1) => 'Wide',
      (2, 2) => 'Large',
      (4, 1) => 'Banner',
      (4, 2) => 'Full page',
      _ => '${size.$1} x ${size.$2}',
    };

/// One widget on a desktop page. [ref] points at what it shows: a media panel
/// camera card id, a Home Assistant entity id or an app package name.
class DesktopItem {
  final String id;
  final DesktopWidgetType type;
  final int width;
  final int height;
  final String? ref;

  const DesktopItem({required this.id, required this.type, this.width = 1, this.height = 1, this.ref});

  (int, int) get size => (width, height);

  DesktopItem withSize((int, int) size) => DesktopItem(id: id, type: type, width: size.$1, height: size.$2, ref: ref);

  Map<String, dynamic> toJson() => {'id': id, 'type': type.name, 'w': width, 'h': height, if (ref != null) 'ref': ref};

  static DesktopItem? fromJson(Object? json) {
    if (json is! Map) return null;
    final type = DesktopWidgetType.values.where((t) => t.name == json['type']).firstOrNull;
    final id = json['id'];
    if (type == null || id is! String) return null;
    final w = (json['w'] as num?)?.toInt() ?? 1;
    final h = (json['h'] as num?)?.toInt() ?? 1;
    return DesktopItem(
      id: id,
      type: type,
      width: w.clamp(1, kDesktopColumns),
      height: h.clamp(1, kDesktopRows),
      ref: json['ref'] as String?,
    );
  }
}

/// Cell position of a placed widget.
class DesktopCell {
  final int x, y, w, h;
  const DesktopCell(this.x, this.y, this.w, this.h);

  int get right => x + w;
  int get bottom => y + h;
}

/// Places widgets in order, each at the first free spot (row by row).
/// Widgets that do not fit are left out of the result.
Map<String, DesktopCell> layoutDesktopPage(List<DesktopItem> items) {
  final taken = List.generate(kDesktopRows, (_) => List.filled(kDesktopColumns, false));
  final result = <String, DesktopCell>{};
  for (final item in items) {
    placement:
    for (var y = 0; y + item.height <= kDesktopRows; y++) {
      for (var x = 0; x + item.width <= kDesktopColumns; x++) {
        var free = true;
        for (var dy = 0; dy < item.height && free; dy++) {
          for (var dx = 0; dx < item.width && free; dx++) {
            if (taken[y + dy][x + dx]) free = false;
          }
        }
        if (!free) continue;
        for (var dy = 0; dy < item.height; dy++) {
          for (var dx = 0; dx < item.width; dx++) {
            taken[y + dy][x + dx] = true;
          }
        }
        result[item.id] = DesktopCell(x, y, item.width, item.height);
        break placement;
      }
    }
  }
  return result;
}

bool desktopPageFits(List<DesktopItem> items) => layoutDesktopPage(items).length == items.length;

/// The desktop above the taskbar: pages of widgets, stored as JSON in preferences.
class DesktopService extends ChangeNotifier {
  static const _pagesKey = 'desktop_pages';

  final SharedPreferences _prefs;
  List<List<DesktopItem>> _pages = const [[]];
  final _random = Random();

  DesktopService(this._prefs) {
    _load();
  }

  /// Always at least one page.
  List<List<DesktopItem>> get pages => _pages;

  void _load() {
    final raw = _prefs.getString(_pagesKey);
    if (raw == null) {
      _pages = [
        [DesktopItem(id: _newId(), type: DesktopWidgetType.clock, width: 2, height: 2)],
      ];
      return;
    }
    try {
      _pages = (jsonDecode(raw) as List)
          .map((page) => (page as List).map(DesktopItem.fromJson).whereType<DesktopItem>().toList())
          .toList();
    } catch (_) {
      _pages = [];
    }
    if (_pages.isEmpty) _pages = [[]];
  }

  Future<void> _save() async {
    notifyListeners();
    await _prefs.setString(_pagesKey, jsonEncode([for (final page in _pages) page.map((i) => i.toJson()).toList()]));
  }

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}${_random.nextInt(1000)}';

  /// Adds a widget to [pageIndex], or to a new page right after it when there is no room.
  /// Returns the page it landed on.
  Future<int> addItem(int pageIndex, DesktopWidgetType type, {required (int, int) size, String? ref}) async {
    final item = DesktopItem(id: _newId(), type: type, width: size.$1, height: size.$2, ref: ref);
    final pages = [for (final p in _pages) List.of(p)];
    var target = pageIndex.clamp(0, pages.length - 1);
    if (!desktopPageFits([...pages[target], item])) {
      target++;
      pages.insert(target, []);
    }
    pages[target].add(item);
    _pages = pages;
    await _save();
    return target;
  }

  Future<void> removeItem(String id) async {
    _pages = [for (final p in _pages) p.where((i) => i.id != id).toList()];
    await _save();
  }

  /// Sizes the widget can take without pushing another widget off its page.
  List<(int, int)> sizesThatFit(String id) {
    final (page, index) = locate(id) ?? (-1, -1);
    if (page < 0) return const [];
    final items = _pages[page];
    return kDesktopSizes.where((size) {
      final changed = List.of(items)..[index] = items[index].withSize(size);
      return desktopPageFits(changed);
    }).toList();
  }

  Future<void> resizeItem(String id, (int, int) size) async {
    final (page, index) = locate(id) ?? (-1, -1);
    if (page < 0) return;
    final pages = [for (final p in _pages) List.of(p)];
    pages[page][index] = pages[page][index].withSize(size);
    _pages = pages;
    await _save();
  }

  /// Moves the widget one step earlier (-1) or later (+1). At the start or end of a page it
  /// moves to the neighbouring page when there is room there. Returns false when it cannot move.
  Future<bool> moveItem(String id, int delta) async {
    final (page, index) = locate(id) ?? (-1, -1);
    if (page < 0) return false;
    final pages = [for (final p in _pages) List.of(p)];
    final items = pages[page];
    final newIndex = index + delta;
    if (newIndex >= 0 && newIndex < items.length) {
      final item = items.removeAt(index);
      items.insert(newIndex, item);
      if (!desktopPageFits(items)) return false;
    } else {
      final otherPage = page + delta;
      if (otherPage < 0 || otherPage >= pages.length) return false;
      final item = items.removeAt(index);
      final other = pages[otherPage];
      delta < 0 ? other.add(item) : other.insert(0, item);
      if (!desktopPageFits(other)) return false;
    }
    _pages = pages;
    await _save();
    return true;
  }

  Future<int> addPage(int afterIndex) async {
    final pages = List.of(_pages);
    final index = (afterIndex + 1).clamp(0, pages.length);
    pages.insert(index, []);
    _pages = pages;
    await _save();
    return index;
  }

  Future<void> removePage(int index) async {
    if (index < 0 || index >= _pages.length) return;
    final pages = List.of(_pages)..removeAt(index);
    _pages = pages.isEmpty ? [[]] : pages;
    await _save();
  }

  /// (page, index) of a widget.
  (int, int)? locate(String id) {
    for (var p = 0; p < _pages.length; p++) {
      final i = _pages[p].indexWhere((item) => item.id == id);
      if (i >= 0) return (p, i);
    }
    return null;
  }
}
