import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The "infinite waveform" scrubber shown on the full player screen.
/// Bars before [progress] are highlighted amber (played), the rest violet.
/// Dragging horizontally calls [onSeek] with a 0.0–1.0 progress value.
class WaveformScrubber extends StatefulWidget {
  final double progress; // 0.0 - 1.0
  final ValueChanged<double> onSeek;
  final bool isPlaying;
  final int barCount;

  const WaveformScrubber({
    super.key,
    required this.progress,
    required this.onSeek,
    this.isPlaying = false,
    this.barCount = 48,
  });

  @override
  State<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends State<WaveformScrubber> with SingleTickerProviderStateMixin {
  late final List<double> _heights;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    if (widget.isPlaying) _pulse.repeat();
    final rnd = Random(7); // fixed seed so bars don't reshuffle on rebuild
    _heights = List.generate(widget.barCount, (i) {
      final base = sin(i * 0.5).abs();
      return 8 + base * 18 + rnd.nextDouble() * 8;
    });
  }

  @override
  void didUpdateWidget(covariant WaveformScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.isPlaying && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _handleDrag(DragUpdateDetails details, BoxConstraints constraints) {
    final dx = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
    widget.onSeek((dx / constraints.maxWidth).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final playedBars = (widget.progress * widget.barCount).round();
        return AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => GestureDetector(
          onHorizontalDragUpdate: (d) => _handleDrag(d, constraints),
          onTapDown: (d) {
            final dx = d.localPosition.dx.clamp(0.0, constraints.maxWidth);
            widget.onSeek((dx / constraints.maxWidth).clamp(0.0, 1.0));
          },
          child: SizedBox(
            height: 36,
            width: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(widget.barCount, (i) {
                final played = i < playedBars;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    height: _heights[i] * (widget.isPlaying ? 0.88 + 0.22 * sin((_pulse.value * 2 * pi) + i * 0.42) : 1.0),
                    decoration: BoxDecoration(
                      color: played ? AppColors.amber : AppColors.violetSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          ),
        );
      },
    );
  }
}
