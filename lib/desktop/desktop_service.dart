import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a desktop widget shows.
enum DesktopWidgetType { clock, camera, homeAssistant, app, watchNext }

/// Widgets that only show something cannot take focus outside edit mode.
bool desktopTypeFocusable(DesktopWidgetType type) => type != DesktopWidgetType.clock;

/// What sits behind a widget's content.
enum DesktopWidgetBackground { glass, blur, none }

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

  /// Top-left cell; null until placed.
  final int? x;
  final int? y;

  const DesktopItem({required this.id, required this.type, this.width = 1, this.height = 1, this.ref, this.x, this.y});

  (int, int) get size => (width, height);

  DesktopItem withSize((int, int) size) =>
      DesktopItem(id: id, type: type, width: size.$1, height: size.$2, ref: ref, x: x, y: y);

  DesktopItem at(int? x, int? y) => DesktopItem(id: id, type: type, width: width, height: height, ref: ref, x: x, y: y);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'w': width,
        'h': height,
        if (ref != null) 'ref': ref,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
      };

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
      x: (json['x'] as num?)?.toInt(),
      y: (json['y'] as num?)?.toInt(),
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

class _Grid {
  final taken = List.generate(kDesktopRows, (_) => List.filled(kDesktopColumns, false));

  bool free(int x, int y, int w, int h) {
    if (x < 0 || y < 0 || x + w > kDesktopColumns || y + h > kDesktopRows) return false;
    for (var dy = 0; dy < h; dy++) {
      for (var dx = 0; dx < w; dx++) {
        if (taken[y + dy][x + dx]) return false;
      }
    }
    return true;
  }

  void take(int x, int y, int w, int h) {
    for (var dy = 0; dy < h; dy++) {
      for (var dx = 0; dx < w; dx++) {
        taken[y + dy][x + dx] = true;
      }
    }
  }

  /// Free spot for a w x h widget, nearest to (nearX, nearY), else row by row.
  (int, int)? find(int w, int h, {int nearX = 0, int nearY = 0}) {
    (int, int)? best;
    var bestScore = 1 << 30;
    for (var y = 0; y + h <= kDesktopRows; y++) {
      for (var x = 0; x + w <= kDesktopColumns; x++) {
        if (!free(x, y, w, h)) continue;
        final score = (x - nearX).abs() + (y - nearY).abs() * 2;
        if (score < bestScore) {
          bestScore = score;
          best = (x, y);
        }
      }
    }
    return best;
  }
}

/// Where each widget sits. Widgets keep their own spot when it is free; the rest take the
/// nearest free spot. Widgets that do not fit at all are left out of the result.
Map<String, DesktopCell> layoutDesktopPage(List<DesktopItem> items) {
  final grid = _Grid();
  final result = <String, DesktopCell>{};
  for (final item in items) {
    final (x, y) = (item.x, item.y);
    if (x != null && y != null && grid.free(x, y, item.width, item.height)) {
      grid.take(x, y, item.width, item.height);
      result[item.id] = DesktopCell(x, y, item.width, item.height);
    }
  }
  for (final item in items) {
    if (result.containsKey(item.id)) continue;
    final spot = grid.find(item.width, item.height, nearX: item.x ?? 0, nearY: item.y ?? 0);
    if (spot == null) continue;
    grid.take(spot.$1, spot.$2, item.width, item.height);
    result[item.id] = DesktopCell(spot.$1, spot.$2, item.width, item.height);
  }
  return result;
}

bool desktopPageFits(List<DesktopItem> items) => layoutDesktopPage(items).length == items.length;

/// The items with their resolved spots written in.
List<DesktopItem> _placed(List<DesktopItem> items) {
  final cells = layoutDesktopPage(items);
  return [for (final i in items) cells[i.id] == null ? i : i.at(cells[i.id]!.x, cells[i.id]!.y)];
}

/// The desktop above the taskbar: pages of widgets, stored as JSON in preferences.
class DesktopService extends ChangeNotifier {
  static const _pagesKey = 'desktop_pages';
  static const _homePageKey = 'desktop_home_page';
  static const _borderKey = 'desktop_widget_border';
  static const _backgroundKey = 'desktop_widget_background';

  final SharedPreferences _prefs;
  List<List<DesktopItem>> _pages = const [[]];
  final _random = Random();

  /// Bumped when something outside the desktop (settings) asks it to enter edit mode.
  final ValueNotifier<int> editRequests = ValueNotifier(0);

  DesktopService(this._prefs) {
    _load();
  }

  /// Always at least one page. Every widget that fits has its spot filled in.
  List<List<DesktopItem>> get pages => _pages;

  /// The page shown at start and when Home is pressed.
  int get homePage => (_prefs.getInt(_homePageKey) ?? 0).clamp(0, _pages.length - 1);

  bool get widgetBorder => _prefs.getBool(_borderKey) ?? true;

  DesktopWidgetBackground get widgetBackground =>
      DesktopWidgetBackground.values.where((b) => b.name == _prefs.getString(_backgroundKey)).firstOrNull ??
      DesktopWidgetBackground.glass;

  Future<void> setHomePage(int index) async {
    await _prefs.setInt(_homePageKey, index.clamp(0, _pages.length - 1));
    notifyListeners();
  }

  Future<void> setWidgetBorder(bool value) async {
    await _prefs.setBool(_borderKey, value);
    notifyListeners();
  }

  Future<void> setWidgetBackground(DesktopWidgetBackground value) async {
    await _prefs.setString(_backgroundKey, value.name);
    notifyListeners();
  }

  void requestEdit() => editRequests.value++;

  @override
  void dispose() {
    editRequests.dispose();
    super.dispose();
  }

  void _load() {
    final raw = _prefs.getString(_pagesKey);
    if (raw == null) {
      _pages = [
        [DesktopItem(id: _newId(), type: DesktopWidgetType.clock, width: 2, height: 2, x: 0, y: 0)],
      ];
      return;
    }
    try {
      _pages = (jsonDecode(raw) as List)
          .map((page) => _placed((page as List).map(DesktopItem.fromJson).whereType<DesktopItem>().toList()))
          .toList();
    } catch (_) {
      _pages = [];
    }
    if (_pages.isEmpty) _pages = [[]];
  }

  Future<void> _set(List<List<DesktopItem>> pages, {int? homePage}) async {
    _pages = [for (final p in pages) _placed(p)];
    if (_pages.isEmpty) _pages = [[]];
    if (homePage != null) await _prefs.setInt(_homePageKey, homePage.clamp(0, _pages.length - 1));
    notifyListeners();
    await _prefs.setString(_pagesKey, jsonEncode([for (final page in _pages) page.map((i) => i.toJson()).toList()]));
  }

  List<List<DesktopItem>> _copy() => [for (final p in _pages) List.of(p)];

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}${_random.nextInt(1000)}';

  /// Adds a widget at the first free spot of [pageIndex], or on a new page right after it
  /// when there is no room. Returns the page it landed on.
  Future<int> addItem(int pageIndex, DesktopWidgetType type, {required (int, int) size, String? ref}) async {
    final pages = _copy();
    var target = pageIndex.clamp(0, pages.length - 1);
    var item = DesktopItem(id: _newId(), type: type, width: size.$1, height: size.$2, ref: ref);
    if (!desktopPageFits([...pages[target], item])) {
      target++;
      pages.insert(target, []);
    }
    pages[target].add(item);
    await _set(pages);
    return target;
  }

  /// Adds a widget to an empty cell of [pageIndex]. Takes [size] when it fits near the cell,
  /// else the largest size that does. Returns false when the page is full.
  Future<bool> addItemAt(int pageIndex, DesktopWidgetType type,
      {required (int, int) size, String? ref, required int x, required int y}) async {
    if (pageIndex < 0 || pageIndex >= _pages.length) return false;
    final pages = _copy();
    final sizes = [size, ...kDesktopSizes.reversed.where((s) => s != size && s.$1 <= size.$1 && s.$2 <= size.$2), (1, 1)];
    for (final s in sizes) {
      // Spots that cover the chosen cell, so the widget lands where the user pointed.
      for (var dy = 0; dy < s.$2; dy++) {
        for (var dx = 0; dx < s.$1; dx++) {
          final item = DesktopItem(id: _newId(), type: type, width: s.$1, height: s.$2, ref: ref, x: x - dx, y: y - dy);
          if (item.x! < 0 || item.y! < 0) continue;
          final cells = layoutDesktopPage([...pages[pageIndex], item]);
          final cell = cells[item.id];
          if (cells.length == pages[pageIndex].length + 1 && cell!.x == item.x && cell.y == item.y) {
            pages[pageIndex].add(item);
            await _set(pages);
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<void> removeItem(String id) => _set([for (final p in _pages) p.where((i) => i.id != id).toList()]);

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

  /// Keeps the widget's top-left corner when the new size fits there.
  Future<void> resizeItem(String id, (int, int) size) async {
    final (page, index) = locate(id) ?? (-1, -1);
    if (page < 0) return;
    final pages = _copy();
    final items = pages[page];
    final resized = items[index].withSize(size);
    // Place the resized widget first so it keeps its corner; the others make room.
    items
      ..removeAt(index)
      ..insert(0, resized);
    final cells = layoutDesktopPage(items);
    if (cells.length != items.length) return;
    final original = _pages[page].map((i) => i.id).toList();
    pages[page] = [
      for (final oid in original)
        items.firstWhere((i) => i.id == oid).at(cells[oid]!.x, cells[oid]!.y),
    ];
    await _set(pages);
  }

  /// Moves the widget one cell. Widgets in the way move to the nearest free spot.
  /// Past the left or right edge it goes to the neighbouring page.
  /// Returns false when there is no room.
  Future<bool> moveItemBy(String id, int dx, int dy) async {
    final (page, index) = locate(id) ?? (-1, -1);
    if (page < 0) return false;
    final pages = _copy();
    final item = pages[page][index];
    final x = (item.x ?? 0) + dx;
    final y = (item.y ?? 0) + dy;
    if (y < 0 || y + item.height > kDesktopRows) return false;

    if (x < 0 || x + item.width > kDesktopColumns) {
      final other = page + (dx < 0 ? -1 : 1);
      if (other < 0 || other >= pages.length) return false;
      final edgeX = dx < 0 ? kDesktopColumns - item.width : 0;
      final grid = _Grid();
      for (final c in layoutDesktopPage(pages[other]).values) {
        grid.take(c.x, c.y, c.w, c.h);
      }
      final spot = grid.find(item.width, item.height, nearX: edgeX, nearY: item.y ?? 0);
      if (spot == null) return false;
      pages[page].removeAt(index);
      pages[other].add(item.at(spot.$1, spot.$2));
      await _set(pages);
      return true;
    }

    // The moved widget claims its new spot first; the others keep theirs when they can.
    final items = pages[page]..removeAt(index);
    final moved = item.at(x, y);
    final order = [moved, ...items];
    final cells = layoutDesktopPage(order);
    if (cells.length != order.length) return false;
    pages[page] = [
      for (final i in _pages[page]) (i.id == id ? moved : i).at(cells[i.id]!.x, cells[i.id]!.y),
    ];
    await _set(pages);
    return true;
  }

  /// Inserts an empty page at [index] (0 = before the first page). Returns its index.
  Future<int> insertPage(int index) async {
    final pages = _copy();
    final at = index.clamp(0, pages.length);
    pages.insert(at, []);
    final home = homePage;
    await _set(pages, homePage: at <= home ? home + 1 : home);
    return at;
  }

  /// The last page cannot be removed. The home page moves along with its page,
  /// or to the page before it when it is the one removed.
  Future<void> removePage(int index) async {
    if (_pages.length < 2 || index < 0 || index >= _pages.length) return;
    final home = homePage;
    await _set(_copy()..removeAt(index), homePage: index < home || (index == home && home > 0) ? home - 1 : home);
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
