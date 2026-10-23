import 'package:material_ui/material_ui.dart';

import '../../bench/bench.dart';
import '../../common/demo_scaffold.dart';
import 'dots_views.dart';

const dotCounts = [500, 1000, 2000, 5000, 10000];

List<Scenario> dotsSuite() => [
      for (final n in dotCounts)
        for (final m in DotsMode.values)
          Scenario(suite: 'dots', mode: m.name, load: n, build: () => buildDots(m, n)),
    ];

class DotsScreen extends StatefulWidget {
  const DotsScreen({super.key});

  @override
  State<DotsScreen> createState() => _DotsScreenState();
}

class _DotsScreenState extends State<DotsScreen> {
  DotsMode _mode = DotsMode.widgets;
  int _n = 1000;

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Bouncing dots',
      controls: Column(
        children: [
          SegmentedButton<DotsMode>(
            showSelectedIcon: false,
            segments: [
              for (final m in DotsMode.values) ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final n in dotCounts)
                ChoiceChip(
                  label: Text('$n'),
                  selected: _n == n,
                  onSelected: (_) => setState(() => _n = n),
                ),
            ],
          ),
        ],
      ),
      body: KeyedSubtree(key: ValueKey('$_mode-$_n'), child: buildDots(_mode, _n)),
    );
  }
}
