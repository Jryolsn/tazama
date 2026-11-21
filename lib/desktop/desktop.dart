import 'dart:async';

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

/// The area above the taskbar: pages of widgets the user places.
/// Left/Right past the edge of a page turns the page; hold OK on a widget to edit.
class Desktop extends StatefulWidget {
  const Desktop({super.key});

  @override
  State<Desktop> createState() => DesktopState();
}

class DesktopState extends State<Desktop> {
  int _page = 0;
  int _slide = 1;
  String? _movingId;
  bool _live = true;
  final Map<String, FocusNode> _nodes = {};
  final HaStates _haStates = ValueNotifier(const {});
  final ValueNotifier<bool> _busy = ValueNotifier(false);
  Timer? _haTimer;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
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
    _lifecycle.dispose();
    _haTimer?.cancel();
    _haStates.dispose();
    _busy.dispose();
    super.dispose();
  }

  List<DesktopItem> get _items {
    final pages = context.read<DesktopService>().pages;
    return pages[_page.clamp(0, pages.length - 1)];
  }

  Future<void> _pollHomeAssistant() async {
    if (!mounted || !_live) return;
    final ha = context.read<HomeAssistantService>();
    if (!ha.isConfigured || !_items.any((i) => i.type == DesktopWidgetType.homeAssistant)) return;
    final states = await ha.fetchStates();
    if (states != null && mounted) _haStates.value = {for (final e in states) e.entityId: e};
  }

  void _focusLater(String? id) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final node = id == null ? null : _nodes[id];
        (node ?? _nodes[_addTileId])?.requestFocus();
      });

  void _goToPage(int page, {String? focusId}) {
    final count = context.read<DesktopService>().pages.length;
    if (page < 0 || page >= count) return;
    setState(() {
      _slide = page >= _page ? 1 : -1;
      _page = page;
    });
    _focusLater(focusId);
    _pollHomeAssistant();
  }

  /// Nearest widget from [from] in [direction] on the shown page.
  String? _neighbour(String fromId, TraversalDirection direction) {
    final cells = layoutDesktopPage(_items);
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

  /// The widget at the left or right edge of a page, closest to [row].
  String? _edgeItem(List<DesktopItem> items, {required bool left, int row = 0}) {
    final cells = layoutDesktopPage(items);
    String? best;
    var bestScore = double.infinity;
    for (final MapEntry(key: id, value: c) in cells.entries) {
      final edge = left ? c.x : kDesktopColumns - c.right;
      final score = edge * 10 + _distance(c.y, c.bottom, row, row + 1);
      if (score < bestScore) {
        bestScore = score;
        best = id;
      }
    }
    return best;
  }

  /// Up from the taskbar: the widget straight above [from] (global coordinates).
  bool focusFromBelow(Rect from) {
    FocusNode? best;
    var bestScore = double.infinity;
    for (final node in _nodes.values) {
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
    best?.requestFocus();
    return best != null;
  }

  KeyEventResult _onKey(String id, LogicalKeyboardKey key) {
    final direction = switch (key) {
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      _ => null,
    };
    if (_movingId != null) {
      if (direction != null) {
        final (dx, dy) = switch (direction) {
          TraversalDirection.left => (-1, 0),
          TraversalDirection.right => (1, 0),
          TraversalDirection.up => (0, -1),
          TraversalDirection.down => (0, 1),
        };
        _move(dx, dy);
      } else if (longPressableKeys.contains(key) || key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape) {
        setState(() => _movingId = null);
      }
      return KeyEventResult.handled;
    }
    if (longPressableKeys.contains(key)) {
      final item = _items.where((i) => i.id == id).firstOrNull;
      if (item == null) {
        _add();
      } else {
        activateDesktopItem(context, item, _haStates, _busy);
      }
      return KeyEventResult.handled;
    }
    if (direction == null) return KeyEventResult.ignored;

    final next = id == _addTileId ? null : _neighbour(id, direction);
    if (next != null) {
      _nodes[next]?.requestFocus();
      return KeyEventResult.handled;
    }
    if (direction == TraversalDirection.left || direction == TraversalDirection.right) {
      final pages = context.read<DesktopService>().pages;
      final target = _page + (direction == TraversalDirection.right ? 1 : -1);
      if (target >= 0 && target < pages.length) {
        final row = layoutDesktopPage(_items)[id]?.y ?? 0;
        _goToPage(target, focusId: _edgeItem(pages[target], left: direction == TraversalDirection.right, row: row));
      }
      return KeyEventResult.handled;
    }
    // Up goes on to the status bar, Down to the taskbar.
    return KeyEventResult.ignored;
  }

  Future<void> _move(int dx, int dy) async {
    final id = _movingId;
    if (id == null) return;
    final service = context.read<DesktopService>();
    final before = service.locate(id)?.$1;
    if (!await service.moveItemBy(id, dx, dy)) return;
    final after = service.locate(id)?.$1;
    if (after != null && after != before) {
      _goToPage(after, focusId: id);
    } else {
      _focusLater(id);
    }
  }

  Future<void> _openMenu(String id) async {
    if (_movingId != null) return;
    final service = context.read<DesktopService>();
    final item = _items.where((i) => i.id == id).firstOrNull;
    final action = await showDesktopItemMenu(context, item: item, page: _page, pageCount: service.pages.length);
    if (!mounted || action == null) return;
    switch (action) {
      case DesktopMenuAction.move:
        setState(() => _movingId = id);
        _focusLater(id);
      case DesktopMenuAction.size:
        final sizes = service.sizesThatFit(id);
        final size = await showDesktopChoices(context, 'Size', [
          for (final s in sizes) DesktopChoice(s, desktopSizeLabel(s), selected: s == item!.size),
        ]);
        if (size != null) await service.resizeItem(id, size);
        _focusLater(id);
      case DesktopMenuAction.add:
        await _add();
      case DesktopMenuAction.addPage:
        final page = await service.addPage(_page);
        _goToPage(page);
      case DesktopMenuAction.remove:
        final neighbour = _neighbour(id, TraversalDirection.left) ?? _neighbour(id, TraversalDirection.right);
        await service.removeItem(id);
        _focusLater(neighbour);
      case DesktopMenuAction.pageEarlier:
      case DesktopMenuAction.pageLater:
        final page = await service.movePage(_page, action == DesktopMenuAction.pageEarlier ? -1 : 1);
        _goToPage(page, focusId: id);
      case DesktopMenuAction.removePage:
        final count = _items.length;
        if (count > 0 &&
            !await confirmDesktop(context, 'Remove page?', 'Remove page and its $count ${count == 1 ? 'widget' : 'widgets'}')) {
          _focusLater(id);
          return;
        }
        await service.removePage(_page);
        if (!mounted) return;
        setState(() => _page = _page.clamp(0, service.pages.length - 1));
        _focusLater(_edgeItem(_items, left: true));
    }
  }

  Future<void> _add() async {
    final picked = await pickDesktopWidget(context);
    if (picked == null || !mounted) return;
    final (type, ref) = picked;
    final service = context.read<DesktopService>();
    final page = await service.addItem(_page, type, size: desktopDefaultSize(type), ref: ref);
    final id = service.pages[page].last.id;
    if (page != _page) {
      _goToPage(page, focusId: id);
    } else {
      _focusLater(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = context.watch<DesktopService>().pages;
    final page = _page.clamp(0, pages.length - 1);
    final items = pages[page];
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 8, 48, 4),
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
                  child: _buildPage(context, items, constraints.biggest),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 18,
          child: _movingId != null
              ? const Center(
                  child: Text('Arrows move the widget, past the edge to the next page. OK when done.',
                      style: TextStyle(fontSize: 12, color: Nebula.text, shadows: Nebula.textShadow)),
                )
              : pages.length < 2
              ? null
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < pages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == page ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == page ? Nebula.text : Colors.white30,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPage(BuildContext context, List<DesktopItem> items, Size size) {
    final cellW = (size.width - (kDesktopColumns - 1) * _kGap) / kDesktopColumns;
    final cellH = (size.height - (kDesktopRows - 1) * _kGap) / kDesktopRows;
    Rect rectOf(DesktopCell c) => Rect.fromLTWH(
          c.x * (cellW + _kGap),
          c.y * (cellH + _kGap),
          c.w * cellW + (c.w - 1) * _kGap,
          c.h * cellH + (c.h - 1) * _kGap,
        );
    final cells = layoutDesktopPage(items);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (_movingId != null)
          for (var y = 0; y < kDesktopRows; y++)
            for (var x = 0; x < kDesktopColumns; x++)
              if (!cells.values.any((c) => x >= c.x && x < c.right && y >= c.y && y < c.bottom))
              Positioned.fromRect(
                rect: rectOf(DesktopCell(x, y, 1, 1)),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                ),
              ),
        if (items.isEmpty)
          Positioned.fromRect(
            rect: rectOf(const DesktopCell(1, 0, 2, 1)).shift(Offset(0, (cellH + _kGap) / 2)),
            child: _DesktopTile(
              key: const ValueKey(_addTileId),
              id: _addTileId,
              nodes: _nodes,
              onKey: _onKey,
              onLongPress: _openMenu,
              child: const DesktopPlaceholder(icon: Icons.add_rounded, text: 'Add widget'),
            ),
          ),
        for (final item in items)
          if (cells[item.id] != null)
            Positioned.fromRect(
              key: ValueKey(item.id),
              rect: rectOf(cells[item.id]!),
              child: _DesktopTile(
                id: item.id,
                nodes: _nodes,
                moving: _movingId == item.id,
                onKey: _onKey,
                onLongPress: _openMenu,
                child: DesktopItemContent(item: item, haStates: _haStates, busy: _busy, live: _live),
              ),
            ),
      ],
    );
  }
}

const String _addTileId = '_add';

class _DesktopTile extends StatefulWidget {
  final String id;
  final Map<String, FocusNode> nodes;
  final bool moving;
  final KeyEventResult Function(String id, LogicalKeyboardKey key) onKey;
  final void Function(String id) onLongPress;
  final Widget child;

  const _DesktopTile({
    super.key,
    required this.id,
    required this.nodes,
    required this.onKey,
    required this.onLongPress,
    required this.child,
    this.moving = false,
  });

  @override
  State<_DesktopTile> createState() => _DesktopTileState();
}

class _DesktopTileState extends State<_DesktopTile> {
  late final FocusNode _node = FocusNode(debugLabel: 'desktop:${widget.id}');
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.nodes[widget.id] = _node;
  }

  @override
  void dispose() {
    if (widget.nodes[widget.id] == _node) widget.nodes.remove(widget.id);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final highlighted = _focused || widget.moving;
    return FocusKeyboardListener(
      onPressed: (key) => widget.onKey(widget.id, key),
      onLongPress: (key) {
        widget.onLongPress(widget.id);
        return KeyEventResult.handled;
      },
      child: Focus(
        focusNode: _node,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: GestureDetector(
          onTap: () => widget.onKey(widget.id, LogicalKeyboardKey.select),
          onLongPress: () => widget.onLongPress(widget.id),
          child: AnimatedScale(
            scale: _focused ? 1.03 : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: const Color(0x99121418),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: highlighted ? accent : Colors.white.withValues(alpha: 0.1),
                  width: highlighted ? 2 : 1,
                ),
                boxShadow: _focused ? [BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 18)] : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.child,
                    if (widget.moving)
                      const ColoredBox(
                        color: Color(0x66000000),
                        child: Center(child: Icon(Icons.open_with_rounded, size: 32, color: Colors.white)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
