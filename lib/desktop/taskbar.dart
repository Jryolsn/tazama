import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/nebula_theme.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/cached_blur_backdrop.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flauncher/widgets/dock_contour_painter.dart';
import 'package:flauncher/widgets/focus_keyboard_listener.dart';
import 'package:flauncher/widgets/settings/launcher_sections_panel_page.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Height of the app cards row in the taskbar.
const double kTaskbarRowHeight = 72;

/// Categories with apps, in the user's order.
List<Category> taskbarCategories(AppsService apps) =>
    apps.launcherSections.whereType<Category>().where((c) => c.applications.isNotEmpty).toList();

/// The category the taskbar shows: the chosen one, else Favorites, else the first with apps.
Category? taskbarCategory(List<Category> categories, int? chosenId) {
  final withApps = categories.where((c) => c.applications.isNotEmpty).toList();
  return withApps.firstWhereOrNull((c) => c.id == chosenId) ??
      withApps.firstWhereOrNull((c) => c.name == 'Favorites') ??
      withApps.firstOrNull;
}

/// One compact row of apps, always at the bottom.
/// Up/Down switch category; Up from the first category goes to the desktop.
/// Left from the first app shows a gear for the category settings.
class Taskbar extends StatefulWidget {
  /// Moves focus to the desktop widget above [from]; false when there is none.
  final bool Function(Rect from) onUpFromTop;

  const Taskbar({super.key, required this.onUpFromTop});

  @override
  State<Taskbar> createState() => _TaskbarState();
}

class _TaskbarState extends State<Taskbar> {
  final FocusNode _rowNode = FocusNode(debugLabel: 'taskbar-row', canRequestFocus: false, skipTraversal: true);
  final FocusNode _gearNode = FocusNode(debugLabel: 'taskbar-gear');
  bool _gearShown = false;
  bool _focused = false;
  bool _labelPinned = false;
  Timer? _labelTimer;

  @override
  void dispose() {
    _labelTimer?.cancel();
    _rowNode.dispose();
    _gearNode.dispose();
    super.dispose();
  }

  /// App focus nodes of the row, left to right.
  List<FocusNode> get _appNodes {
    final nodes = _rowNode.traversalDescendants.where((n) => n.context != null && n.rect.width > 0).toList();
    nodes.sort((a, b) => a.rect.left.compareTo(b.rect.left));
    return nodes;
  }

  int get _focusedIndex {
    final primary = FocusManager.instance.primaryFocus;
    final nodes = _appNodes;
    return nodes.indexWhere((n) => n == primary || (primary != null && primary.ancestors.contains(n)));
  }

  void _showLabel() {
    _labelTimer?.cancel();
    setState(() => _labelPinned = true);
    _labelTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _labelPinned = false);
    });
  }

  Future<void> _switchCategory(List<Category> categories, int index) async {
    final column = _gearNode.hasFocus ? -1 : _focusedIndex;
    await context.read<SettingsService>().setTaskbarCategoryId(categories[index].id);
    _showLabel();
    if (column < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nodes = _appNodes;
      if (nodes.isNotEmpty) nodes[column.clamp(0, nodes.length - 1)].requestFocus();
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final apps = context.read<AppsService>();
    final categories = taskbarCategories(apps);
    final current = taskbarCategory(categories, context.read<SettingsService>().taskbarCategoryId);
    final index = current == null ? -1 : categories.indexOf(current);

    if (key == LogicalKeyboardKey.arrowUp) {
      if (index > 0) {
        _switchCategory(categories, index - 1);
        return KeyEventResult.handled;
      }
      final focused = FocusManager.instance.primaryFocus;
      if (focused == null) return KeyEventResult.ignored;
      return widget.onUpFromTop(focused.rect) ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (index >= 0 && index < categories.length - 1) _switchCategory(categories, index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_gearNode.hasFocus) return KeyEventResult.handled;
      if (_focusedIndex == 0) {
        setState(() => _gearShown = true);
        WidgetsBinding.instance.addPostFrameCallback((_) => _gearNode.requestFocus());
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.arrowRight && _gearNode.hasFocus) {
      _appNodes.firstOrNull?.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _openCategorySettings() => showDialog(
        context: context,
        builder: (_) => const SettingsPanel(initialRoute: LauncherSectionsPanelPage.routeName),
      );

  @override
  Widget build(BuildContext context) {
    final apps = context.watch<AppsService>();
    final chosenId = context.select<SettingsService, int?>((s) => s.taskbarCategoryId);
    final categories = taskbarCategories(apps);
    final category = taskbarCategory(categories, chosenId);
    final index = category == null ? -1 : categories.indexOf(category);
    final accent = Theme.of(context).colorScheme.primary;
    const radius = 10.0;

    final bar = CustomPaint(
      foregroundPainter: const DockContourPainter(radius: radius, strokeWidth: 1.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Row(
          children: [
            // Where this category sits among the others.
            SizedBox(
              width: 16,
              child: categories.length < 2
                  ? null
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < categories.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            width: 4,
                            height: i == index ? 12 : 4,
                            decoration: BoxDecoration(
                              color: i == index ? Nebula.text : Colors.white30,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
            ),
            Expanded(
              child: Focus(
                focusNode: _rowNode,
                child: category == null
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No apps yet', style: TextStyle(color: Nebula.textMuted)),
                      )
                    : CategoryRow(
                        key: ValueKey(category.id),
                        category: category,
                        applications: category.applications,
                        showTitle: false,
                        rowHeight: kTaskbarRowHeight,
                        padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                      ),
              ),
            ),
          ],
        ),
      ),
    );

    final labelVisible = category != null && (_labelPinned || _focused);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _onKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 0, 48, 10),
        child: Row(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: _gearShown
                  ? Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _GearButton(
                        node: _gearNode,
                        accent: accent,
                        onPressed: _openCategorySettings,
                        onFocusLost: () {
                          // Keep it while the settings dialog is open, so focus can return to it.
                          if (ModalRoute.of(context)?.isCurrent ?? true) setState(() => _gearShown = false);
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: CachedBlurBackdrop(sigma: 5, child: bar),
                  ),
                  // Category name floats above the bar, so it takes no room.
                  Positioned(
                    left: 6,
                    top: -22,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: labelVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          category?.name ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: Nebula.textMuted,
                            shadows: Nebula.textShadow,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GearButton extends StatefulWidget {
  final FocusNode node;
  final Color accent;
  final VoidCallback onPressed;
  final VoidCallback onFocusLost;

  const _GearButton({required this.node, required this.accent, required this.onPressed, required this.onFocusLost});

  @override
  State<_GearButton> createState() => _GearButtonState();
}

class _GearButtonState extends State<_GearButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => FocusKeyboardListener(
        onPressed: (key) {
          if (!longPressableKeys.contains(key)) return KeyEventResult.ignored;
          widget.onPressed();
          return KeyEventResult.handled;
        },
        child: Focus(
          focusNode: widget.node,
          onFocusChange: (focused) {
            setState(() => _focused = focused);
            if (!focused) widget.onFocusLost();
          },
          child: GestureDetector(
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _focused ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.06),
                border: Border.all(color: _focused ? widget.accent : Colors.transparent, width: 1.5),
              ),
              child: const Icon(Icons.tune_rounded, size: 20, color: Nebula.text),
            ),
          ),
        ),
      );
}
