/*
 * Tazama "Nebula" visual style: shared colors, shapes and the default space background.
 * Licensed under GPL-3.0, see LICENSE.
 */

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

class Nebula {
  Nebula._();

  static const String fontFamily = 'Nunito';

  static const Color deep = Color(0xFF0B0A24);
  static const Color violet = Color(0xFF2A1752);
  static const Color surface = Color(0xFF15122C);
  static const Color surfaceHigh = Color(0xFF1F1A3D);
  static const Color lavender = Color(0xFFB49CFF);
  static const Color text = Color(0xFFEEEAFF);
  static const Color textMuted = Color(0xB3EEEAFF);

  /// Soft violet-tinted text shadow that reads on bright wallpapers.
  static const List<Shadow> textShadow = [Shadow(color: Color(0x99080620), blurRadius: 12, offset: Offset(0, 2))];

  static const double cardRadius = 18;

  static const LinearGradient baseGradient = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [deep, violet],
  );

  /// Paints the nebula: base gradient, two soft clouds and a faint starfield.
  /// Meant to be rendered once into a texture, not every frame.
  static void paintBackground(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..shader = baseGradient.createShader(rect));

    void cloud(Alignment center, double radius, Color color) {
      final shader = RadialGradient(
        center: center,
        radius: radius,
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = shader);
    }

    cloud(const Alignment(0.6, -0.65), 0.75, const Color(0x59AA6EFF));
    cloud(const Alignment(-0.75, 0.85), 0.7, const Color(0x475078FF));
    cloud(const Alignment(0.1, 0.2), 0.9, const Color(0x14C8A0FF));

    // Fixed seed so the sky looks the same on every start.
    final rnd = Random(7);
    final star = Paint()..isAntiAlias = true;
    final scale = rect.shortestSide / 1080;
    for (var i = 0; i < 220; i++) {
      final pos = Offset(rect.left + rnd.nextDouble() * rect.width, rect.top + rnd.nextDouble() * rect.height * 0.85);
      final r = (0.5 + rnd.nextDouble() * 1.3) * scale;
      star.color = const Color(0xFFD8CCFF).withValues(alpha: 0.12 + rnd.nextDouble() * 0.5);
      canvas.drawCircle(pos, r, star);
    }
  }

  static ui.Image renderBackground(Size size) {
    final recorder = ui.PictureRecorder();
    paintBackground(Canvas(recorder), Offset.zero & size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.width.round(), size.height.round());
    picture.dispose();
    return image;
  }
}
