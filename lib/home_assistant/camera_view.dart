import 'dart:async';

import 'package:flauncher/home_assistant/home_assistant_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

/// A camera picture: live video when [live] is set, otherwise refreshed snapshots. A direct
/// RTSP address set for the camera is played first (low delay, with sound); HA's HLS stream is the fallback.
class HaCameraView extends StatefulWidget {
  final String entityId;
  final bool live;
  final bool sound;

  const HaCameraView({super.key, required this.entityId, this.live = false, this.sound = false});

  @override
  State<HaCameraView> createState() => _HaCameraViewState();
}

class _HaCameraViewState extends State<HaCameraView> {
  static final _options = VideoPlayerOptions(mixWithOthers: true);
  VideoPlayerController? _video;
  Timer? _snapshotTimer;
  int _snapshot = 0;
  bool _streamFailed = false;

  @override
  void initState() {
    super.initState();
    _startSnapshots();
    if (widget.live) _startStream();
  }

  @override
  void didUpdateWidget(HaCameraView old) {
    super.didUpdateWidget(old);
    if (old.live != widget.live) {
      if (widget.live) {
        _startStream();
      } else {
        _stopStream();
      }
    }
  }

  void _startSnapshots() {
    final ha = context.read<HomeAssistantService>();
    _snapshotTimer = Timer.periodic(Duration(seconds: widget.live ? 2 : ha.cameraRefreshSeconds), (_) {
      if (mounted && (_video == null || !_video!.value.isInitialized)) setState(() => _snapshot++);
    });
  }

  Future<void> _startStream() async {
    final ha = context.read<HomeAssistantService>();
    final rtsp = ha.rtspUrlOf(widget.entityId);
    if (rtsp != null && await _play(VideoPlayerController.networkUrl(Uri.parse(rtsp), videoPlayerOptions: _options))) return;
    if (!mounted || !widget.live) return;
    final url = await ha.fetchHlsUrl(widget.entityId);
    if (!mounted || !widget.live) return;
    if (url == null || !await _play(VideoPlayerController.networkUrl(url, httpHeaders: ha.authHeaders, videoPlayerOptions: _options))) {
      if (mounted) setState(() => _streamFailed = true);
    }
  }

  /// Starts [controller]; true once it plays (or the view no longer wants it).
  Future<bool> _play(VideoPlayerController controller) async {
    try {
      await controller.initialize();
      await controller.setVolume(widget.sound ? 1 : 0);
      await controller.play();
    } catch (_) {
      await controller.dispose();
      return false;
    }
    if (!mounted || !widget.live) {
      await controller.dispose();
      return true;
    }
    setState(() => _video = controller);
    return true;
  }

  void _stopStream() {
    final video = _video;
    _video = null;
    video?.dispose();
    if (mounted) setState(() => _streamFailed = false);
  }

  @override
  void dispose() {
    _snapshotTimer?.cancel();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    final video = _video;
    return Stack(fit: StackFit.expand, children: [
      Image.network(
        ha.cameraSnapshotUri(widget.entityId, _snapshot).toString(),
        headers: ha.authHeaders,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: Colors.black26, child: Center(child: Icon(Icons.videocam_off_rounded))),
      ),
      if (video != null && video.value.isInitialized)
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(width: video.value.size.width, height: video.value.size.height, child: VideoPlayer(video)),
        ),
      if (widget.live && video == null && !_streamFailed)
        const Positioned(right: 8, top: 8, child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
      if (widget.live && video != null)
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
