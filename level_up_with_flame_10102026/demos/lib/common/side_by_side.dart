import 'package:material_ui/material_ui.dart';

import 'demo_scaffold.dart';
import 'palette.dart';

/// Runs several modes of one demo next to each other at the same load.
///
/// All panes share one UI thread, so the slowest pane sets the frame rate
/// for every pane. Pause a pane to show how much of the frame it was eating.
class SideBySideScreen<M extends Enum> extends StatefulWidget {
  const SideBySideScreen({
    super.key,
    required this.title,
    required this.modes,
    required this.label,
    required this.initialPanes,
    required this.loads,
    required this.initialLoad,
    required this.loadLabel,
    required this.paneBuilder,
    this.autopilotOption = false,
  });

  final String title;
  final List<M> modes;
  final String Function(M) label;
  final Set<M> initialPanes;
  final List<int> loads;
  final int initialLoad;
  final String Function(int) loadLabel;
  final bool autopilotOption;
  final Widget Function(M mode, int load, bool autopilot) paneBuilder;

  @override
  State<SideBySideScreen<M>> createState() => _SideBySideScreenState<M>();
}

class _SideBySideScreenState<M extends Enum> extends State<SideBySideScreen<M>> {
  late final Set<M> _panes = {...widget.initialPanes};
  final Set<M> _paused = {};
  late int _load = widget.initialLoad;
  bool _autopilot = true;
  int _gen = 0;

  @override
  Widget build(BuildContext context) {
    final panes = widget.modes.where(_panes.contains).toList();
    return DemoScaffold(
      title: widget.title,
      controls: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final m in widget.modes)
            FilterChip(
              label: Text(widget.label(m)),
              selected: _panes.contains(m),
              onSelected: (v) => setState(() => v ? _panes.add(m) : _panes.remove(m)),
            ),
          const SizedBox(width: 12),
          for (final n in widget.loads)
            ChoiceChip(
              label: Text(widget.loadLabel(n)),
              selected: _load == n,
              onSelected: (_) => setState(() {
                _load = n;
                _gen++;
              }),
            ),
          if (widget.autopilotOption)
            FilterChip(
              label: const Text('Autopilot'),
              selected: _autopilot,
              onSelected: (v) => setState(() {
                _autopilot = v;
                _gen++;
              }),
            ),
          IconButton(
            tooltip: 'Restart all panes',
            icon: const Icon(Icons.restart_alt),
            onPressed: () => setState(() => _gen++),
          ),
        ],
      ),
      body: Row(
        children: [
          for (var k = 0; k < panes.length; k++) ...[
            if (k > 0) const VerticalDivider(width: 1, color: Palette.card),
            Expanded(child: _pane(panes[k])),
          ],
        ],
      ),
    );
  }

  Widget _pane(M m) {
    final paused = _paused.contains(m);
    return Column(
      children: [
        Container(
          color: Palette.card,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.label(m)} · ${widget.loadLabel(_load)}',
                  style: const TextStyle(color: Palette.cream, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: paused ? 'Resume' : 'Pause',
                icon: Icon(paused ? Icons.play_arrow : Icons.pause, color: Palette.flame),
                onPressed: () => setState(() => paused ? _paused.remove(m) : _paused.add(m)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRect(
            child: paused
                ? const Center(child: Text('paused', style: TextStyle(color: Palette.muted)))
                : KeyedSubtree(
                    key: ValueKey('$m-$_load-$_autopilot-$_gen'),
                    child: widget.paneBuilder(m, _load, _autopilot),
                  ),
          ),
        ),
      ],
    );
  }
}
