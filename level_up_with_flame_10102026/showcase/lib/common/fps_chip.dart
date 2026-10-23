import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'frame_stats.dart';
import 'theme.dart';

/// Small live FPS readout for the performance recordings.
class FpsChip extends StatefulWidget {
  const FpsChip({super.key});

  @override
  State<FpsChip> createState() => _FpsChipState();
}

class _FpsChipState extends State<FpsChip> {
  Timer? _timer;
  FrameSummary? _s;

  @override
  void initState() {
    super.initState();
    FrameStats.instance.ensureListening();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() => _s = FrameStats.instance.live());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final fps = s == null || s.frames == 0 ? null : s.fps;
    final ok = fps != null && fps >= s!.refreshRate * 0.9;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE60B0B0F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ok ? Pal.green : const Color(0xFFE5484D)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            fps == null ? '— fps' : '${fps.toStringAsFixed(0)} fps',
            style: TextStyle(
              color: ok ? Pal.green : const Color(0xFFFF8A8D),
              fontWeight: FontWeight.w700,
              fontSize: 14,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
