import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays a network stream (RTSP, HLS, ...) filling its box. Muted unless [sound] is set.
class StreamView extends StatefulWidget {
  final String url;
  final bool sound;
  final BoxFit fit;

  const StreamView({super.key, required this.url, this.sound = false, this.fit = BoxFit.cover});

  @override
  State<StreamView> createState() => _StreamViewState();
}

class _StreamViewState extends State<StreamView> {
  static final _options = VideoPlayerOptions(mixWithOthers: true);
  VideoPlayerController? _video;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(StreamView old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _stop();
      _start();
    }
  }

  Future<void> _start() async {
    final url = widget.url;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url), videoPlayerOptions: _options);
    try {
      await controller.initialize();
      await controller.setVolume(widget.sound ? 1 : 0);
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted && url == widget.url) setState(() => _failed = true);
      return;
    }
    if (!mounted || url != widget.url) {
      await controller.dispose();
      return;
    }
    setState(() {
      _failed = false;
      _video = controller;
    });
  }

  void _stop() {
    _video?.dispose();
    _video = null;
    _failed = false;
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final playing = video != null && video.value.isInitialized;
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Colors.black26),
      if (playing)
        FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(width: video.value.size.width, height: video.value.size.height, child: VideoPlayer(video)),
        )
      else if (_failed)
        const Center(child: Icon(Icons.videocam_off_rounded))
      else
        const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      if (playing)
        Positioned(
          left: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(6)),
            child: const Text('LIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
    ]);
  }
}

/// Shows [child] over the whole screen; Back closes it.
Future<void> openFullscreen(BuildContext context, Widget child) => Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 100),
      pageBuilder: (_, __, ___) => ColoredBox(
        color: Colors.black,
        child: Focus(autofocus: true, child: SizedBox.expand(child: child)),
      ),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    ));
