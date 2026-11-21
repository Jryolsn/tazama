import 'package:collection/collection.dart';
import 'package:flauncher/desktop/desktop_menus.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/nebula_theme.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/cached_blur_backdrop.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flauncher/widgets/dock_contour_painter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The category the taskbar shows: the chosen one, else Favorites, else the first with apps.
Category? taskbarCategory(List<Category> categories, int? chosenId) {
  final withApps = categories.where((c) => c.applications.isNotEmpty).toList();
  return withApps.firstWhereOrNull((c) => c.id == chosenId) ??
      withApps.firstWhereOrNull((c) => c.name == 'Favorites') ??
      withApps.firstOrNull;
}

/// One row of apps, always at the bottom. The button on the left switches category.
class Taskbar extends StatelessWidget {
  const Taskbar({super.key});

  @override
  Widget build(BuildContext context) {
    final apps = context.watch<AppsService>();
    final chosenId = context.select<SettingsService, int?>((s) => s.taskbarCategoryId);
    final category = taskbarCategory(apps.categories, chosenId);
    const radius = 10.0;

    final content = CustomPaint(
      foregroundPainter: const DockContourPainter(radius: radius, strokeWidth: 1.0),
      child: Container(
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Row(
          children: [
            _CategoryButton(category: category),
            Expanded(
              child: category == null
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No apps yet', style: TextStyle(color: Nebula.textMuted)),
                    )
                  : CategoryRow(
                      key: ValueKey(category.id),
                      category: category,
                      applications: category.applications,
                      showTitle: false,
                      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                    ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 48, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedBlurBackdrop(sigma: 5, child: content),
      ),
    );
  }
}

class _CategoryButton extends StatefulWidget {
  final Category? category;

  const _CategoryButton({required this.category});

  @override
  State<_CategoryButton> createState() => _CategoryButtonState();
}

class _CategoryButtonState extends State<_CategoryButton> {
  bool _focused = false;

  Future<void> _pick() async {
    final categories = context.read<AppsService>().categories.where((c) => c.applications.isNotEmpty);
    final id = await showDesktopChoices(context, 'Category', [
      for (final c in categories)
        DesktopChoice(c.id, c.name,
            subtitle: '${c.applications.length} ${c.applications.length == 1 ? 'app' : 'apps'}',
            selected: c.id == widget.category?.id),
    ]);
    if (id != null && mounted) await context.read<SettingsService>().setTaskbarCategoryId(id);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Actions(
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _pick())},
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: GestureDetector(
          onTap: _pick,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _focused ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _focused ? accent : Colors.transparent, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.category?.name ?? 'Apps',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Nebula.text),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.unfold_more_rounded, size: 18, color: Nebula.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
