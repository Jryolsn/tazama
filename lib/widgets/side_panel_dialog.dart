import 'package:flauncher/actions.dart';
import 'package:flutter/material.dart';

import 'settings/settings_theme.dart';

/// The sliding settings surface.
///
/// Dark glass material: a soft dark gradient with a faint accent glow in
/// the top corner and a single specular hairline on the inner edge. Deliberately
/// avoids [BackdropFilter] and elevation shadows, both of which force expensive
/// offscreen layers on TV GPUs.
class SidePanelDialog extends StatelessWidget {
  final Widget child;
  final double width;
  final bool isRightSide;

  const SidePanelDialog({
    required this.child,
    this.width = 250,
    this.isRightSide = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    // Floating panel: inset from the screen edge, rounded on all corners.
    final radius = BorderRadius.circular(SettingsStyle.panelRadius);

    return Align(
      alignment: isRightSide ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.all(SettingsStyle.panelInset),
        child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: const [BoxShadow(color: Color(0x9905041A), blurRadius: 48, offset: Offset(0, 18))],
        ),
        child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: width,
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [SettingsStyle.panelTop, SettingsStyle.panelBottom],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: isRightSide ? const Alignment(1, -1.2) : const Alignment(-1, -1.2),
                        radius: 1.4,
                        colors: [
                          accentColor.withValues(alpha: 0.20),
                          accentColor.withValues(alpha: 0.04),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // Soft rim light around the whole panel.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(color: const Color(0x24DCCDFF)),
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Actions(
                    actions: {BackIntent: BackAction(context)},
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}
