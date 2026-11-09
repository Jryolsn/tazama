/*
 * Tazama settings: pick the home screen layout, with a small preview of each.
 * Licensed under GPL-3.0, see LICENSE.
 */

import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/settings_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeLayoutPage extends StatelessWidget {
  static const String routeName = "home_layout_panel";

  const HomeLayoutPage({super.key});

  static const List<(String, String, String)> layouts = [
    (HOME_LAYOUT_ROWS, 'Rows', 'Dock at the bottom, categories below'),
    (HOME_LAYOUT_ORBIT, 'Orbit', 'Big clock in the middle, floating cards'),
    (HOME_LAYOUT_AURORA, 'Aurora', 'Clock on the left, apps on the right'),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final current = settings.homeLayout;
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        const SettingsPageHeader(title: 'Home layout'),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final (id, name, hint) in layouts)
                  SettingsFocusCard(
                    autofocus: id == current,
                    onPressed: () => settings.setHomeLayout(id),
                    builder: (context, highlighted) => Row(
                      children: [
                        Container(
                          width: 128,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: id == current ? accent : Colors.white.withValues(alpha: 0.12),
                              width: id == current ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: CustomPaint(painter: HomeLayoutThumbnail(id, accent)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(hint, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        if (id == current) Icon(Icons.check_circle_rounded, color: accent, size: 22),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Miniature of a home layout: where the clock and the cards sit.
class HomeLayoutThumbnail extends CustomPainter {
  final String layout;
  final Color accent;

  const HomeLayoutThumbnail(this.layout, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B0A24), Color(0xFF2A1752)],
        ).createShader(Offset.zero & size),
    );
    final card = Paint()..color = Colors.white.withValues(alpha: 0.28);
    final focus = Paint()..color = accent;
    final text = Paint()..color = Colors.white.withValues(alpha: 0.8);

    void rr(double x, double y, double cw, double ch, Paint p) =>
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, cw, ch), Radius.circular(ch * 0.25)), p);

    switch (layout) {
      case HOME_LAYOUT_ORBIT:
        rr(w * 0.36, h * 0.24, w * 0.28, h * 0.14, text);
        for (int i = 0; i < 5; i++) {
          rr(w * 0.17 + i * w * 0.135, h * 0.62, w * 0.11, w * 0.062, i == 2 ? focus : card);
        }
        break;
      case HOME_LAYOUT_AURORA:
        rr(w * 0.06, h * 0.12, w * 0.18, h * 0.13, text);
        rr(w * 0.06, h * 0.3, w * 0.12, h * 0.05, card);
        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < 3; c++) {
            rr(w * 0.36 + c * w * 0.2, h * 0.14 + r * h * 0.26, w * 0.17, h * 0.18, r == 0 && c == 1 ? focus : card);
          }
        }
        break;
      default:
        rr(w * 0.8, h * 0.08, w * 0.13, h * 0.06, text);
        rr(w * 0.08, h * 0.5, w * 0.84, h * 0.2, Paint()..color = Colors.white.withValues(alpha: 0.1));
        for (int i = 0; i < 5; i++) {
          rr(w * 0.11 + i * w * 0.16, h * 0.53, w * 0.14, h * 0.14, i == 1 ? focus : card);
        }
        for (int i = 0; i < 6; i++) {
          rr(w * 0.08 + i * w * 0.145, h * 0.8, w * 0.12, h * 0.12, card);
        }
    }
  }

  @override
  bool shouldRepaint(covariant HomeLayoutThumbnail old) => old.layout != layout || old.accent != accent;
}
