import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flauncher/desktop/desktop_menus.dart';
import 'package:flauncher/desktop/desktop_service.dart';
import 'package:flauncher/desktop/desktop_widgets.dart';
import 'package:flauncher/home_assistant/home_assistant_service.dart';
import 'package:flauncher/nebula_theme.dart';
import 'package:flauncher/widgets/focus_keyboard_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const double _kGap = 14;
const double _kBarHeight = 40;

// Focus ids that are not widgets start with an underscore.
const String _pencilId = '_pencil';
const String _newPageId = '_new_page';
String _cellId(int x, int y) => '_cell:$x:$y';
(int, int)? _cellOf(String id) {
  if (!id.startsWith('_cell:')) return null;
  final parts = id.split(':');
  return (int.parse(parts[1]), int.parse(parts[2]));
}

enum _Tool { add, home, style, deletePage, done }

String _toolId(_Tool tool) => '_tool:${tool.name}';

/// The area above the taskbar: pages of widgets ("dashboards").
///
/// Normal mode: only widgets that do something take focus; Left/Right past a page edge turns the page.
/// The pencil at the bottom right opens edit mode, where every widget and empty cell takes focus,
/// a toolbar adds widgets, sets the home page, changes the style or deletes the page, and going past
/// the first or last page offers a new page. Home always returns to the home page.
class Desktop extends StatefulWidget {
  const Desktop({super.key});

  @override
  State<Desktop> createState() => DesktopState();
}

class DesktopState extends State<Desktop> {
  static const _homeChannel = MethodChannel('com.jryolsn.tazama/home');

  /// In edit mode this can be -1 or pages.length: the "new page" spots past either end.
  late int _page;
  int _slide = 1;
  bool _editing = false;
  String? _movingId;
  bool _live = true;
  final Map<String, FocusNode> _nodes = {};
  final HaStates _haStates = ValueNotifier(const {});
  final ValueNotifier<bool> _busy = ValueNotifier(false);
  Timer? _haTimer;
  late final AppLifecycleListener _lifecycle;
  late final DesktopService _service;

  @override
  void initState() {
    super.initState();
    _service = context.read<DesktopService>();
    _page = _service.homePage;
    _service.editRequests.addListener(_onEditRequest);
    _homeChannel.setMethodCallHandler((call) async {
      if (call.method == 'home') goHome();
    });
    _lifecycle = AppLifecycleListener(onStateChange: (state) {
      final live = state == AppLifecycleState.resumed;
      if (live != _live && mounted) setState(() => _live = live);
      if (live) _pollHomeAssistant();
    });
    _haTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollHomeAssistant());
    WidgetsBinding.instance.addPostFrameCallback((_) => _pollHomeAssistant());
  }

  @override
  void dispose() {
    _homeChannel.setMethodCallHandler(null);
    _service.editRequests.removeListener(_onEditRequest);
    _lifecycle.dispose();
    _haTimer?.cancel();
    _haStates.dispose();
    _busy.dispose();
    super.dispose();
  }

  List<List<DesktopItem>> get _pages => _service.pages;

  bool get _onNewPage => _page < 0 || _page >= _pages.length;

  List<DesktopItem> get _items => _onNewPage ? const [] : _pages[_page];

  Future<void> _pollHomeAssistant() async {
    if (!mounted || !_live) return;
    final ha = context.read<HomeAssistantService>();
    if (!ha.isConfigured || !_items.any((i) => i.type == DesktopWidgetType.homeAssistant)) return;
    final states = await ha.fetchStates();
    if (states != null && mounted) _haStates.value = {for (final e in states) e.entityId: e};
  }

  bool get _hasFocus => _nodes.values.any((n) => n.hasFocus);

  void _focus(String? id) {
    final node = id == null ? null : _nodes[id];
    (node ?? _nodes[_editing ? _toolId(_Tool.done) : _pencilId])?.requestFocus();
  }

  void _focusLater(String? id) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus(id);
      });

  void _goToPage(int page, {String? focusId}) {
    final min = _editing ? -1 : 0;
    final max = _editing ? _pages.length : _pages.length - 1;
    if (page < min || page > max) return;
    setState(() {
      _slide = page >= _page ? 1 : -1;
      _page = page;
    });
    _focusLater(focusId);
    _pollHomeAssistant();
  }

  /// Home pressed: leave edit mode and show the home page.
  void goHome() {
    if (!mounted) return;
    final hadFocus = _hasFocus;
    final home = _service.homePage;
    setState(() {
      _editing = false;
      _movingId = null;
      _slide = home >= _page ? 1 : -1;
      _page = home;
    });
    if (hadFocus) _focusLater(_edgeTarget(home, left: true));
    _pollHomeAssistant();
  }

  void _onEditRequest() {
    if (!mounted) return;
    _enterEdit();
  }

  void _enterEdit() {
    setState(() {
      _editing = true;
      _movingId = null;
    });
    _focusLater(_firstTarget());
  }

  void _exitEdit() {
    setState(() {
      _editing = false;
      _movingId = null;
      _page = _page.clamp(0, _pages.length - 1);
    });
    _focusLater(_pencilId);
  }

  // ---- Spatial navigation on the grid ----

  /// What can take focus on [page], by cell: widgets (outside edit mode only those that do
  /// something) and, in edit mode, every empty cell.
  Map<String, DesktopCell> _targets([int? page]) {
    final p = page ?? _page;
    if (p < 0 || p >= _pages.length) return const {};
    final items = _pages[p];
    final cells = layoutDesktopPage(items);
    final result = <String, DesktopCell>{
      for (final item in items)
        if (cells[item.id] != null && (_editing || desktopTypeFocusable(item.type))) item.id: cells[item.id]!,
    };
    if (_editing) {
      for (final (x, y) in _freeCells(cells.values)) {
        result[_cellId(x, y)] = DesktopCell(x, y, 1, 1);
      }
    }
    return result;
  }

  List<(int, int)> _freeCells(Iterable<DesktopCell> taken) => [
        for (var y = 0; y < kDesktopRows; y++)
          for (var x = 0; x < kDesktopColumns; x++)
            if (!taken.any((c) => x >= c.x && x < c.right && y >= c.y && y < c.bottom)) (x, y),
      ];

  String? _firstTarget() {
    final targets = _targets();
    if (targets.isEmpty) return null;
    return (targets.entries.toList()..sort((a, b) => (a.value.y * 10 + a.value.x).compareTo(b.value.y * 10 + b.value.x)))
        .first
        .key;
  }

  /// Nearest target from [fromId] in [direction] on the shown page.
  String? _neighbour(String fromId, TraversalDirection direction) {
    final cells = _targets();
    final from = cells[fromId];
    if (from == null) return null;
    String? best;
    var bestScore = double.infinity;
    for (final MapEntry(key: id, value: c) in cells.entries) {
      if (id == fromId) continue;
      final double main, cross;
      switch (direction) {
        case TraversalDirection.right:
          if (c.x < from.right) continue;
          main = (c.x - from.right).toDouble();
          cross = _distance(c.y, c.bottom, from.y, from.bottom);
        case TraversalDirection.left:
          if (c.right > from.x) continue;
          main = (from.x - c.right).toDouble();
          cross = _distance(c.y, c.bottom, from.y, from.bottom);
        case TraversalDirection.down:
          if (c.y < from.bottom) continue;
          main = (c.y - from.bottom).toDouble();
          cross = _distance(c.x, c.right, from.x, from.right);
        case TraversalDirection.up:
          if (c.bottom > from.y) continue;
          main = (from.y - c.bottom).toDouble();
          cross = _distance(c.x, c.right, from.x, from.right);
      }
      final score = main * 10 + cross;
      if (score < bestScore) {
        bestScore = score;
        best = id;
      }
    }
    return best;
  }

  /// 0 when the spans overlap, else the gap between them.
  double _distance(int a0, int a1, int b0, int b1) => a1 <= b0
      ? (b0 - a1).toDouble() + 0.5
      : b1 <= a0
          ? (a0 - b1).toDouble() + 0.5
          : 0;

  /// The target at the left or right edge of [page], closest to [row].
  String? _edgeTarget(int page, {required bool left, int row = 0}) {
    String? best;
    var bestScore = double.infinity;
    for (final MapEntry(key: id, value: c) in _targets(page).entries) {
      final edge = left ? c.x : kDesktopColumns - c.right;
      final score = edge * 10 + _distance(c.y, c.bottom, row, row + 1);
      if (score < bestScore) {
        bestScore = score;
        best = id;
      }
    }
    return best;
  }

  /// The focusable node nearest above [from] (global coordinates) whose id passes [accept].
  FocusNode? _nearestAbove(Rect from, bool Function(String id) accept) {
    FocusNode? best;
    var bestScore = double.infinity;
    for (final MapEntry(key: id, value: node) in _nodes.entries) {
      if (!accept(id)) continue;
      final box = node.context?.findRenderObject();
      if (box is! RenderBox || !box.attached || !node.canRequestFocus) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.top >= from.top) continue;
      final dx = rect.right < from.left
          ? from.left - rect.right
          : rect.left > from.right
              ? rect.left - from.right
              : 0.0;
      final score = dx * 2 + (from.top - rect.bottom).abs();
      if (score < bestScore) {
        bestScore = score;
        best = node;
      }
    }
    return best;
  }

  Rect? _rectOf(String id) {
    final box = _nodes[id]?.context?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Up from the taskbar: the widget straight above [from] (global coordinates), else the pencil.
  bool focusFromBelow(Rect from) {
    final node = _nearestAbove(from, (id) => !id.startsWith('_')) ?? _nodes[_pencilId];
    node?.requestFocus();
    return node != null;
  }

  // ---- Keys ----

  static TraversalDirection? _direction(LogicalKeyboardKey key) => switch (key) {
        LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
        LogicalKeyboardKey.arrowRight => TraversalDirection.right,
        LogicalKeyboardKey.arrowUp => TraversalDirection.up,
        LogicalKeyboardKey.arrowDown => TraversalDirection.down,
        _ => null,
      };

  static bool _isBack(LogicalKeyboardKey key) => key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape;

  KeyEventResult _onKey(String id, LogicalKeyboardKey key) {
    final direction = _direction(key);
    if (_movingId != null) {
      if (direction != null) {
        final (dx, dy) = switch (direction) {
          TraversalDirection.left => (-1, 0),
          TraversalDirection.right => (1, 0),
          TraversalDirection.up => (0, -1),
          TraversalDirection.down => (0, 1),
        };
        _move(dx, dy);
      } else if (longPressableKeys.contains(key) || _isBack(key)) {
        setState(() => _movingId = null);
      }
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      if (!_editing) return KeyEventResult.ignored;
      _exitEdit();
      return KeyEventResult.handled;
    }
    if (id.startsWith('_tool:')) return _onToolKey(_Tool.values.byName(id.substring(6)), key, direction);
    if (longPressableKeys.contains(key)) {
      _activate(id);
      return KeyEventResult.handled;
    }
    if (direction == null) return KeyEventResult.ignored;

    if (id == _pencilId) return _onPencilKey(direction);
    if (id == _newPageId) {
      if (direction == TraversalDirection.right && _page < 0) {
        _goToPage(0, focusId: _edgeTarget(0, left: true));
      } else if (direction == TraversalDirection.left && _page >= _pages.length) {
        _goToPage(_pages.length - 1, focusId: _edgeTarget(_pages.length - 1, left: false));
      } else if (direction == TraversalDirection.down) {
        _focus(_toolId(_Tool.done));
      }
      return KeyEventResult.handled;
    }

    final next = _neighbour(id, direction);
    if (next != null) {
      _nodes[next]?.requestFocus();
      return KeyEventResult.handled;
    }
    final cell = _targets()[id];
    switch (direction) {
      case TraversalDirection.left:
      case TraversalDirection.right:
        _turnPage(direction == TraversalDirection.right ? 1 : -1, row: cell?.y ?? 0);
        return KeyEventResult.handled;
      case TraversalDirection.down:
        if (_editing) {
          final from = _rectOf(id);
          _focus(from == null ? null : _nearestTool(from));
          return KeyEventResult.handled;
        }
        // The pencil sits under the bottom-right corner; elsewhere Down goes on to the taskbar.
        if (cell != null && cell.right == kDesktopColumns && cell.bottom == kDesktopRows) {
          _focus(_pencilId);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case TraversalDirection.up:
        // Edit mode keeps focus on the desktop; otherwise Up goes on to the status bar.
        return _editing ? KeyEventResult.handled : KeyEventResult.ignored;
    }
  }

  void _turnPage(int delta, {int row = 0, String? keepFocus}) {
    final target = _page + delta;
    final inRange = target >= 0 && target < _pages.length;
    if (inRange) {
      _goToPage(target, focusId: keepFocus ?? _edgeTarget(target, left: delta > 0, row: row));
    } else if (_editing && !_onNewPage) {
      _goToPage(target, focusId: _newPageId);
    }
  }

  KeyEventResult _onPencilKey(TraversalDirection direction) {
    switch (direction) {
      case TraversalDirection.left:
      case TraversalDirection.right:
        // Turning pages from the pencil keeps focus there, so pages without anything to focus still work.
        _turnPage(direction == TraversalDirection.right ? 1 : -1, keepFocus: _pencilId);
        return KeyEventResult.handled;
      case TraversalDirection.up:
        final from = _rectOf(_pencilId);
        final node = from == null ? null : _nearestAbove(from, (id) => !id.startsWith('_'));
        if (node == null) return KeyEventResult.ignored;
        node.requestFocus();
        return KeyEventResult.handled;
      case TraversalDirection.down:
        return KeyEventResult.ignored;
    }
  }

  List<_Tool> get _tools => _onNewPage
      ? const [_Tool.done]
      : [_Tool.add, _Tool.home, _Tool.style, if (_pages.length > 1) _Tool.deletePage, _Tool.done];

  String? _nearestTool(Rect from) {
    String? best;
    var bestScore = double.infinity;
    for (final tool in _tools) {
      final rect = _rectOf(_toolId(tool));
      if (rect == null) continue;
      final score = (rect.center.dx - from.center.dx).abs();
      if (score < bestScore) {
        bestScore = score;
        best = _toolId(tool);
      }
    }
    return best;
  }

  KeyEventResult _onToolKey(_Tool tool, LogicalKeyboardKey key, TraversalDirection? direction) {
    if (longPressableKeys.contains(key)) {
      _runTool(tool);
      return KeyEventResult.handled;
    }
    final tools = _tools;
    final index = tools.indexOf(tool);
    switch (direction) {
      case TraversalDirection.left:
        if (index > 0) _focus(_toolId(tools[index - 1]));
      case TraversalDirection.right:
        if (index < tools.length - 1) _focus(_toolId(tools[index + 1]));
      case TraversalDirection.up:
        final from = _rectOf(_toolId(tool));
        if (from != null) _nearestAbove(from, (id) => !id.startsWith('_tool:') && id != _pencilId)?.requestFocus();
      case TraversalDirection.down:
      case null:
        break;
    }
    return KeyEventResult.handled;
  }

  // ---- Actions ----

  void _activate(String id) {
    if (id == _pencilId) return _enterEdit();
    if (id == _newPageId) {
      _createPage();
      return;
    }
    final cell = _cellOf(id);
    if (cell != null) {
      _add(at: cell);
      return;
    }
    final item = _items.where((i) => i.id == id).firstOrNull;
    if (item == null) return;
    if (_editing) {
      _openItemMenu(item);
    } else {
      activateDesktopItem(context, item, _haStates, _busy);
    }
  }

  Future<void> _runTool(_Tool tool) async {
    switch (tool) {
      case _Tool.add:
        await _add();
      case _Tool.home:
        await _service.setHomePage(_page);
      case _Tool.style:
        await showDesktopStyle(context);
        _focusLater(_toolId(_Tool.style));
      case _Tool.deletePage:
        final count = _items.length;
        if (count > 0 &&
            !await confirmDesktop(context, 'Delete page?', 'Delete page and its $count ${count == 1 ? 'widget' : 'widgets'}')) {
          _focusLater(_toolId(_Tool.deletePage));
          return;
        }
        await _service.removePage(_page);
        if (!mounted) return;
        setState(() => _page = _page.clamp(0, _pages.length - 1));
        _focusLater(_toolId(_pages.length > 1 ? _Tool.deletePage : _Tool.done));
      case _Tool.done:
        _exitEdit();
    }
  }

  Future<void> _createPage() async {
    final index = await _service.insertPage(_page < 0 ? 0 : _pages.length);
    if (!mounted) return;
    setState(() => _page = index);
    _focusLater(_cellId(0, 0));
  }

  Future<void> _move(int dx, int dy) async {
    final id = _movingId;
    if (id == null) return;
    final before = _service.locate(id)?.$1;
    if (!await _service.moveItemBy(id, dx, dy)) return;
    final after = _service.locate(id)?.$1;
    if (after != null && after != before) {
      _goToPage(after, focusId: id);
    } else {
      _focusLater(id);
    }
  }

  Future<void> _openItemMenu(DesktopItem item) async {
    final id = item.id;
    final sizes = _service.sizesThatFit(id);
    final action = await showDesktopItemMenu(context, item, canResize: sizes.length > 1);
    if (!mounted || action == null) {
      _focusLater(id);
      return;
    }
    switch (action) {
      case DesktopMenuAction.move:
        setState(() => _movingId = id);
        _focusLater(id);
      case DesktopMenuAction.size:
        final size = await showDesktopChoices(context, 'Size', [
          for (final s in sizes) DesktopChoice(s, desktopSizeLabel(s), subtitle: '${s.$1} x ${s.$2}', selected: s == item.size),
        ]);
        if (size != null) await _service.resizeItem(id, size);
        _focusLater(id);
      case DesktopMenuAction.remove:
        final cell = layoutDesktopPage(_items)[id];
        await _service.removeItem(id);
        // The freed spot shows as an empty cell where the widget was.
        _focusLater(cell == null ? null : _cellId(cell.x, cell.y));
    }
  }

  /// Adds a widget: to an empty cell, or with [at] null to the first free spot
  /// (on a new page right after this one when it is full).
  Future<void> _add({(int, int)? at}) async {
    final picked = await pickDesktopWidget(context);
    if (!mounted) return;
    if (picked == null) {
      _focusLater(at == null ? _toolId(_Tool.add) : _cellId(at.$1, at.$2));
      return;
    }
    final (type, ref) = picked;
    if (at != null && await _service.addItemAt(_page, type, size: desktopDefaultSize(type), ref: ref, x: at.$1, y: at.$2)) {
      _focusLater(_pages[_page].last.id);
      return;
    }
    final page = await _service.addItem(_page, type, size: desktopDefaultSize(type), ref: ref);
    final id = _pages[page].last.id;
    if (page != _page) {
      _goToPage(page, focusId: id);
    } else {
      _focusLater(id);
    }
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DesktopService>();
    final pages = service.pages;
    // Pages can be removed from outside (settings); keep the index valid for key handling too.
    _page = _editing ? _page.clamp(-1, pages.length) : _page.clamp(0, pages.length - 1);
    final page = _page;
    final style = _TileStyle(border: service.widgetBorder, background: service.widgetBackground);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 8, 48, 0),
            child: LayoutBuilder(
              builder: (context, constraints) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey(page);
                  final dx = (incoming ? 1 : -1) * _slide * 0.08;
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(page),
                  child: page < 0 || page >= pages.length
                      ? _buildNewPage(context, constraints.biggest)
                      : _buildPage(context, pages[page], constraints.biggest, style),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: _kBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: _buildBar(context, pages.length, page, service.homePage),
          ),
        ),
      ],
    );
  }

  Widget _buildBar(BuildContext context, int pageCount, int page, int homePage) {
    final showDots = pageCount > 1 || _editing;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (showDots)
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: _editing ? Alignment.centerLeft : Alignment.center,
            child: _PageDots(count: pageCount, current: page, home: homePage, editing: _editing),
          ),
        if (_movingId != null)
          const Align(
            alignment: Alignment.centerRight,
            child: Text('Arrows move the widget, past the edge to the next page. OK when done.',
                style: TextStyle(fontSize: 12, color: Nebula.text, shadows: Nebula.textShadow)),
          )
        else if (_editing)
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final tool in _tools)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _Target(
                      key: ValueKey(_toolId(tool)),
                      id: _toolId(tool),
                      nodes: _nodes,
                      onKey: _onKey,
                      builder: (context, focused) => _ToolButton(
                        focused: focused,
                        icon: switch (tool) {
                          _Tool.add => Icons.add_rounded,
                          _Tool.home => page == homePage ? Icons.home_rounded : Icons.home_outlined,
                          _Tool.style => Icons.tune_rounded,
                          _Tool.deletePage => Icons.delete_outline_rounded,
                          _Tool.done => Icons.check_rounded,
                        },
                        label: switch (tool) {
                          _Tool.add => 'Add widget',
                          _Tool.home => page == homePage ? 'Home page' : 'Set as home',
                          _Tool.style => 'Style',
                          _Tool.deletePage => 'Delete page',
                          _Tool.done => 'Done',
                        },
                        active: tool == _Tool.home && page == homePage,
                        primary: tool == _Tool.done,
                      ),
                    ),
                  ),
              ],
            ),
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: _Target(
              key: const ValueKey(_pencilId),
              id: _pencilId,
              nodes: _nodes,
              onKey: _onKey,
              builder: (context, focused) => _PencilButton(focused: focused),
            ),
          ),
      ],
    );
  }

  Widget _buildNewPage(BuildContext context, Size size) {
    final left = _page < 0;
    return Center(
      child: SizedBox(
        width: size.width / 2 - _kGap / 2,
        height: size.height / 2 - _kGap / 2,
        child: _Target(
          key: const ValueKey(_newPageId),
          id: _newPageId,
          nodes: _nodes,
          onKey: _onKey,
          builder: (context, focused) => _CellFrame(
            focused: focused,
            child: DesktopPlaceholder(
              icon: Icons.add_rounded,
              text: left ? 'New page before the first' : 'New page after the last',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, List<DesktopItem> items, Size size, _TileStyle style) {
    final cellW = (size.width - (kDesktopColumns - 1) * _kGap) / kDesktopColumns;
    final cellH = (size.height - (kDesktopRows - 1) * _kGap) / kDesktopRows;
    Rect rectOf(DesktopCell c) => Rect.fromLTWH(
          c.x * (cellW + _kGap),
          c.y * (cellH + _kGap),
          c.w * cellW + (c.w - 1) * _kGap,
          c.h * cellH + (c.h - 1) * _kGap,
        );
    final cells = layoutDesktopPage(items);
    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        if (_editing)
          for (final (x, y) in _freeCells(cells.values))
            Positioned.fromRect(
              key: ValueKey(_cellId(x, y)),
              rect: rectOf(DesktopCell(x, y, 1, 1)),
              child: _movingId != null
                  ? const _CellFrame(focused: false, child: SizedBox.shrink())
                  : _Target(
                      id: _cellId(x, y),
                      nodes: _nodes,
                      onKey: _onKey,
                      builder: (context, focused) => _CellFrame(
                        focused: focused,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          opacity: focused ? 1 : 0.35,
                          child: DesktopPlaceholder(icon: Icons.add_rounded, text: focused ? 'Add widget' : ''),
                        ),
                      ),
                    ),
            ),
        if (items.isEmpty && !_editing)
          const Center(
            child: Text('Empty page. Select the pencil at the bottom right to add widgets.',
                style: TextStyle(fontSize: 13, color: Nebula.textMuted, shadows: Nebula.textShadow)),
          ),
        for (final item in items)
          if (cells[item.id] != null)
            Positioned.fromRect(
              key: ValueKey(item.id),
              rect: rectOf(cells[item.id]!),
              child: _Target(
                id: item.id,
                nodes: _nodes,
                onKey: _onKey,
                focusable: _editing || desktopTypeFocusable(item.type),
                builder: (context, focused) => _WidgetFrame(
                  focused: focused,
                  editing: _editing,
                  moving: _movingId == item.id,
                  style: style,
                  child: DesktopItemContent(item: item, haStates: _haStates, busy: _busy, live: _live),
                ),
              ),
            ),
      ],
    );
    // One shared backdrop pass for all blurred widgets on the page. Always present so switching
    // the style does not rebuild the widgets (and restart camera pictures).
    return BackdropGroup(child: stack);
  }
}

class _TileStyle {
  final bool border;
  final DesktopWidgetBackground background;

  const _TileStyle({required this.border, required this.background});
}

/// Something on the desktop that can take focus: registers its node under [id] and
/// sends key presses (and taps) to [onKey].
class _Target extends StatefulWidget {
  final String id;
  final Map<String, FocusNode> nodes;
  final KeyEventResult Function(String id, LogicalKeyboardKey key) onKey;
  final bool focusable;
  final Widget Function(BuildContext context, bool focused) builder;

  const _Target({super.key, required this.id, required this.nodes, required this.onKey, required this.builder, this.focusable = true});

  @override
  State<_Target> createState() => _TargetState();
}

class _TargetState extends State<_Target> {
  late final FocusNode _node = FocusNode(debugLabel: 'desktop:${widget.id}');
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.nodes[widget.id] = _node;
  }

  @override
  void didUpdateWidget(_Target oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.nodes[widget.id] = _node;
  }

  @override
  void dispose() {
    if (widget.nodes[widget.id] == _node) widget.nodes.remove(widget.id);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusKeyboardListener(
        onPressed: (key) => widget.onKey(widget.id, key),
        // Holding OK does the same as a press; editing is reached through the pencil.
        onLongPress: (key) => widget.onKey(widget.id, key),
        child: Focus(
          focusNode: _node,
          canRequestFocus: widget.focusable,
          skipTraversal: !widget.focusable,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.focusable ? () => widget.onKey(widget.id, LogicalKeyboardKey.select) : null,
            child: widget.builder(context, _focused && widget.focusable),
          ),
        ),
      );
}

class _WidgetFrame extends StatelessWidget {
  final bool focused;
  final bool editing;
  final bool moving;
  final _TileStyle style;
  final Widget child;

  const _WidgetFrame({required this.focused, required this.editing, required this.moving, required this.style, required this.child});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final highlighted = focused || moving;
    final Color borderColor;
    if (highlighted) {
      borderColor = accent;
    } else if (editing) {
      // Edit mode always outlines widgets so their extent is visible.
      borderColor = Colors.white.withValues(alpha: 0.32);
    } else if (style.border) {
      borderColor = Colors.white.withValues(alpha: 0.12);
    } else {
      borderColor = Colors.transparent;
    }
    final fill = switch (style.background) {
      DesktopWidgetBackground.glass => const Color(0x99121418),
      DesktopWidgetBackground.blur => const Color(0x59101216),
      DesktopWidgetBackground.none => Colors.transparent,
    };
    return AnimatedScale(
      scale: focused ? 1.03 : (editing && !moving ? 0.97 : 1),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: highlighted ? 2 : 1),
          boxShadow: focused ? [BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 18)] : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (style.background == DesktopWidgetBackground.blur)
                BackdropFilter.grouped(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: ColoredBox(color: fill),
                )
              else
                ColoredBox(color: fill),
              child,
              if (moving)
                const ColoredBox(
                  color: Color(0x66000000),
                  child: Center(child: Icon(Icons.open_with_rounded, size: 32, color: Colors.white)),
                )
              else if (editing && focused)
                const Positioned(
                  right: 8,
                  top: 8,
                  child: _Badge(icon: Icons.more_horiz_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;

  const _Badge({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: Nebula.deep),
      );
}

/// An empty cell or the new-page spot in edit mode.
class _CellFrame extends StatelessWidget {
  final bool focused;
  final Widget child;

  const _CellFrame({required this.focused, required this.child});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: focused ? 0.08 : 0.03),
        border: Border.all(color: focused ? accent : Colors.white.withValues(alpha: 0.14), width: focused ? 2 : 1),
      ),
      child: child,
    );
  }
}

/// Discreet edit button at the bottom right of the desktop.
class _PencilButton extends StatelessWidget {
  final bool focused;

  const _PencilButton({required this.focused});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 30,
      padding: EdgeInsets.symmetric(horizontal: focused ? 12 : 7),
      decoration: BoxDecoration(
        color: focused ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_outlined, size: 16, color: focused ? Nebula.deep : Colors.white38),
          if (focused) ...[
            const SizedBox(width: 6),
            const Text('Edit desktop', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Nebula.deep)),
          ],
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final bool focused;
  final IconData icon;
  final String label;
  final bool active;
  final bool primary;

  const _ToolButton({required this.focused, required this.icon, required this.label, this.active = false, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final fg = focused ? Nebula.deep : (active ? accent : Nebula.text);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: focused ? accent : Colors.black.withValues(alpha: primary ? 0.5 : 0.35),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: focused ? accent : Colors.white.withValues(alpha: primary ? 0.3 : 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

/// Page dots; the home page is a small house, and edit mode shows the new-page spots at both ends.
class _PageDots extends StatelessWidget {
  final int count;
  final int current;
  final int home;
  final bool editing;

  const _PageDots({required this.count, required this.current, required this.home, required this.editing});

  @override
  Widget build(BuildContext context) {
    Widget dot(int i) {
      final selected = i == current;
      final color = selected ? Nebula.text : Colors.white38;
      if (i < 0 || i >= count) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Icon(Icons.add_rounded, size: 12, color: color),
        );
      }
      if (i == home) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Icon(Icons.home_rounded, size: 12, color: color),
        );
      }
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: selected ? 16 : 6,
        height: 6,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = editing ? -1 : 0; i < (editing ? count + 1 : count); i++) dot(i),
      ],
    );
  }
}
