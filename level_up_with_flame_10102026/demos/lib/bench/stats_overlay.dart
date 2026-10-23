import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'frame_stats.dart';

/// Small FPS / build / raster readout shown on every demo.
class StatsOverlay extends StatefulWidget {
  const StatsOverlay({super.key});

  @override
  State<StatsOverlay> createState() => _StatsOverlayState();
}

class _StatsOverlayState extends State<StatsOverlay> {
  Timer? _timer;
  FrameSummary? _s;

  @override
  void initState() {
    super.initState();
    FrameStats.instance.ensureListening();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
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
    final text = s == null || s.frames == 0
        ? 'measuring…'
        : '${s.fps.toStringAsFixed(0)} fps · '
            'build ${s.buildP90.toStringAsFixed(1)} · '
            'raster ${s.rasterP90.toStringAsFixed(1)} ms (p90)';
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC1C1411),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFF7EFE4),
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
