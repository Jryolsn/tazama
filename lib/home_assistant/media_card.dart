import 'dart:async';

import 'package:flauncher/home_assistant/home_assistant_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// A media player: cover, title, progress and volume. OK plays/pauses, Left/Right change the volume.
class HaMediaCard extends StatefulWidget {
  final HaEntity entity;
  final String name;
  final bool autofocus;
  final VoidCallback onChanged;

  const HaMediaCard({
    super.key,
    required this.entity,
    required this.name,
    required this.autofocus,
    required this.onChanged,
  });

  @override
  State<HaMediaCard> createState() => _HaMediaCardState();
}

class _HaMediaCardState extends State<HaMediaCard> {
  Timer? _tick;
  double? _volume; // optimistic value while the user is adjusting

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.entity.state == 'playing') setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(HaMediaCard old) {
    super.didUpdateWidget(old);
    if (old.entity.volume != widget.entity.volume) _volume = null;
  }

  Future<void> _step(double delta) async {
    final ha = context.read<HomeAssistantService>();
    final current = _volume ?? widget.entity.volume;
    if (current == null) return;
    final next = (current + delta).clamp(0.0, 1.0);
    setState(() => _volume = next);
    await ha.setVolume(widget.entity.entityId, next);
    widget.onChanged();
  }

  Future<void> _service(String service) async {
    await context.read<HomeAssistantService>().callService('media_player', service, widget.entity.entityId);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HomeAssistantService>();
    final entity = widget.entity;
    final accent = Theme.of(context).colorScheme.primary;
    final theme = Theme.of(context).textTheme;
    final picture = ha.absoluteUrl(entity.picture);
    final position = entity.mediaPosition;
    final duration = entity.mediaDuration;
    final volume = _volume ?? entity.volume;
    final idle = entity.state == 'off' || entity.state == 'idle' || entity.unavailable;

    String time(double seconds) {
      final s = seconds.round();
      return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Focus(
        autofocus: widget.autofocus,
        onKeyEvent: (_, event) {
          if (event is KeyUpEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft) {
            _step(-0.05);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            _step(0.05);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.mediaTrackNext) {
            _service('media_next_track');
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.mediaTrackPrevious) {
            _service('media_previous_track');
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.mediaPlayPause) {
            _service('media_play_pause');
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () => _service('media_play_pause'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: focused ? 0.14 : 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: focused ? accent : Colors.white12, width: focused ? 2 : 1),
                boxShadow: focused ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 16)] : null,
              ),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: picture == null
                        ? const ColoredBox(color: Colors.black26, child: Icon(Icons.music_note_rounded))
                        : Image.network(picture.toString(),
                            headers: ha.authHeaders,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: Colors.black26, child: Icon(Icons.music_note_rounded))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(idle ? widget.name : (entity.mediaTitle ?? widget.name),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                        idle
                            ? (entity.unavailable ? 'unavailable' : entity.state)
                            : [if (entity.mediaArtist != null) entity.mediaArtist!, widget.name].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(entity.state == 'playing' ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            value: position != null && duration != null && duration > 0 ? position / duration : 0,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ),
                      if (position != null && duration != null) ...[
                        const SizedBox(width: 6),
                        Text('${time(position)} / ${time(duration)}', style: theme.bodySmall),
                      ],
                    ]),
                    if (volume != null)
                      Row(children: [
                        Icon(volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(minHeight: 5, value: volume, backgroundColor: Colors.white24),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${(volume * 100).round()}%', style: theme.bodySmall),
                      ]),
                  ]),
                ),
              ]),
            ),
          );
        }),
      ),
    );
  }
}
