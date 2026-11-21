/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:ui' as ui;

import 'package:flauncher/actions.dart';
import 'package:flauncher/custom_traversal_policy.dart';
import 'package:flauncher/desktop/desktop.dart';
import 'package:flauncher/desktop/taskbar.dart';
import 'package:flauncher/providers/app_lock_service.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/brightness_service.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/services.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/nebula_theme.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/widgets/focus_aware_app_bar.dart';
import 'package:flauncher/widgets/wallpaper_video_background.dart';
import 'package:flauncher/media_panel/media_panel_settings_page.dart';
import 'package:flauncher/home_assistant/settings/home_assistant_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

class FLauncher extends StatefulWidget {
  const FLauncher({super.key});

  @override
  State<FLauncher> createState() => _FLauncherState();
}

class _FLauncherState extends State<FLauncher> with WidgetsBindingObserver {
  final GlobalKey<FocusAwareAppBarState> _appBarKey = GlobalKey();
  final GlobalKey<DesktopState> _desktopKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSettingsIfAsked());
  }

  /// The quick panel (hold Back / YouTube button) can ask Arc to open its settings.
  Future<void> _openSettingsIfAsked() async {
    try {
      final target = await const MethodChannel('me.efesser.flauncher/method').invokeMethod<Object?>('consumeOpenSettings');
      if (!mounted) return;
      if (target == 'home_assistant') {
        openHomeAssistantSettings(context);
      } else if (target == 'media_panel') {
        showDialog(context: context, builder: (_) => const SettingsPanel(initialRoute: MediaPanelSettingsPage.routeName));
      } else if (target == 'settings' || target == true) {
        showDialog(context: context, builder: (_) => const SettingsPanel());
      }
    } catch (_) {
      // older native side
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<WatchNextService>().refreshPermissionAndItems();
      context.read<AppLockService>().refresh();
      context.read<BrightnessService>().applyCurrentSlotBrightness();
      _openSettingsIfAsked();
    }
  }

  /// Up from the taskbar goes to the widget right above the focused app.
  KeyEventResult _onTaskbarKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || event.logicalKey != LogicalKeyboardKey.arrowUp) return KeyEventResult.ignored;
    final box = FocusManager.instance.primaryFocus?.context?.findRenderObject();
    if (box is! RenderBox) return KeyEventResult.ignored;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    return _desktopKey.currentState?.focusFromBelow(rect) == true ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      MoveFocusToSettingsIntent: CallbackAction<MoveFocusToSettingsIntent>(
        onInvoke: (_) => _appBarKey.currentState?.focusSettings(),
      ),
    },
    child: FocusTraversalGroup(
      policy: RowByRowTraversalPolicy(),
      child: Stack(
        children: [
          RepaintBoundary(
            child: Consumer<WallpaperService>(
              builder: (_, wallpaperService, __) {
                final author = wallpaperService.slideshowAuthor;
                final redditCredit = wallpaperService.redditWallpaperCredit;
                return Stack(
                  children: [
                    // Crossfade between wallpapers (each one has a revision-based key).
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 1500),
                      child: _wallpaper(context, wallpaperService),
                    ),
                    if (redditCredit != null)
                      Positioned(
                        right: 24,
                        top: 64,
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            redditCredit,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              shadows: const [Shadow(blurRadius: 4)],
                            ),
                          ),
                        ),
                      )
                    else if (author != null)
                      Positioned(
                        right: 24,
                        top: 64,
                        // Material gives the text the app font instead of the debug fallback style.
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            AppLocalizations.of(context)!.unsplashPhotoCredit(author),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              shadows: const [Shadow(blurRadius: 4)],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: FocusAwareAppBar(key: _appBarKey),
            body: Selector<AppsService, bool>(
              selector: (_, appsService) => appsService.initialized,
              builder: (context, initialized, _) => initialized
                  ? Column(
                      children: [
                        Expanded(child: Desktop(key: _desktopKey)),
                        Focus(
                          canRequestFocus: false,
                          skipTraversal: true,
                          onKeyEvent: _onTaskbarKey,
                          child: const Taskbar(),
                        ),
                      ],
                    )
                  : _emptyState(context),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _wallpaper(BuildContext context, WallpaperService wallpaperService) {
    final screenSize = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final videoFile = wallpaperService.wallpaperVideoFile;
    if (videoFile != null) {
      return SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: WallpaperVideoBackground(
          key: ValueKey("background_video_${wallpaperService.wallpaperRevision}"),
          file: videoFile,
        ),
      );
    }
    if (wallpaperService.wallpaper != null) {
      return Image(
        image: ResizeImage(wallpaperService.wallpaper!, height: (screenSize.height * dpr).round()),
        key: ValueKey("background_${wallpaperService.wallpaperRevision}"),
        fit: BoxFit.cover,
        height: screenSize.height,
        width: screenSize.width,
      );
    } else {
      final g = wallpaperService.gradient;
      return _CachedGradientBackground(key: const Key("background"), gradient: g.gradient, nebula: g.nebula);
    }
  }

  Widget _emptyState(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(localizations.loading, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

/// Renders a [Gradient] once into a rasterized [ui.Image] and blits it as a
/// texture instead of evaluating the gradient shader every frame.
///
/// On low-end GPUs (e.g. Android TV sticks) a full-screen live gradient is
/// noticeably more expensive to raster than a cached texture, so this keeps the
/// background as cheap as a static image wallpaper.
class _CachedGradientBackground extends StatefulWidget {
  final Gradient gradient;
  final bool nebula;

  const _CachedGradientBackground({super.key, required this.gradient, this.nebula = false});

  @override
  State<_CachedGradientBackground> createState() => _CachedGradientBackgroundState();
}

class _CachedGradientBackgroundState extends State<_CachedGradientBackground> {
  ui.Image? _image;
  Size _renderedSize = Size.zero;
  Gradient? _renderedGradient;
  bool _rendering = false;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _render(Size size) async {
    if (_rendering) {
      return;
    }
    _rendering = true;
    final ui.Image image;
    if (widget.nebula) {
      image = Nebula.renderBackground(size);
    } else {
      final recorder = ui.PictureRecorder();
      final rect = Offset.zero & size;
      Canvas(recorder).drawRect(rect, Paint()..shader = widget.gradient.createShader(rect));
      final picture = recorder.endRecording();
      image = picture.toImageSync(size.width.round(), size.height.round());
      picture.dispose();
    }
    _rendering = false;
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = image;
      _renderedSize = size;
      _renderedGradient = widget.gradient;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final needsRender = size != _renderedSize || widget.gradient != _renderedGradient;
        if (needsRender && size.width > 0 && size.height > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (size != _renderedSize || widget.gradient != _renderedGradient)) {
              _render(size);
            }
          });
        }
        final image = _image;
        if (image != null && !needsRender) {
          return RawImage(image: image, width: size.width, height: size.height, fit: BoxFit.fill);
        }
        // First frame (and while re-rendering): paint the gradient live once to avoid a flash.
        return DecoratedBox(decoration: BoxDecoration(gradient: widget.gradient));
      },
    );
  }
}
