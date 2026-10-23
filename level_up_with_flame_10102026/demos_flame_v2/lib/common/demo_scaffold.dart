import 'package:material_ui/material_ui.dart';

import '../bench/stats_overlay.dart';

/// Shared layout for every demo: Flutter app bar + controls, the canvas,
/// the live stats readout, and an optional Flutter bottom bar.
class DemoScaffold extends StatelessWidget {
  const DemoScaffold({
    super.key,
    required this.title,
    required this.body,
    this.controls,
    this.bottom,
  });

  final String title;
  final Widget body;
  final Widget? controls;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          if (controls != null)
            Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 8), child: controls),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: ClipRect(child: body)),
                const Positioned(left: 8, bottom: 8, child: StatsOverlay()),
              ],
            ),
          ),
          if (bottom != null) bottom!,
        ],
      ),
    );
  }
}
