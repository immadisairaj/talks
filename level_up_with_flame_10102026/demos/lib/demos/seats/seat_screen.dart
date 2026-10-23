import 'package:material_ui/material_ui.dart';

import '../../bench/bench.dart';
import '../../common/demo_scaffold.dart';
import '../../common/palette.dart';
import 'seat_layout.dart';
import 'seat_views.dart';

const seatCounts = [2000, 5000, 10000, 20000];

List<Scenario> seatsSuite() => [
      for (final n in seatCounts)
        for (final m in SeatMode.values)
          Scenario(
            suite: 'seats',
            mode: m.name,
            load: n,
            note: 'autopilot + 30 bookings/s',
            build: () => buildSeatMap(m, SeatLayout(n), autopilot: true),
          ),
    ];

class SeatScreen extends StatefulWidget {
  const SeatScreen({super.key});

  @override
  State<SeatScreen> createState() => _SeatScreenState();
}

class _SeatScreenState extends State<SeatScreen> {
  SeatMode _mode = SeatMode.flameSections;
  int _n = 10000;
  bool _autopilot = false;
  late SeatLayout _layout = SeatLayout(_n);

  void _reset({SeatMode? mode, int? n, bool? autopilot}) => setState(() {
        _mode = mode ?? _mode;
        _n = n ?? _n;
        _autopilot = autopilot ?? _autopilot;
        _layout = SeatLayout(_n);
      });

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Stadium seat map',
      controls: Column(
        children: [
          SegmentedButton<SeatMode>(
            showSelectedIcon: false,
            segments: [for (final m in SeatMode.values) ButtonSegment(value: m, label: Text(m.label))],
            selected: {_mode},
            onSelectionChanged: (s) => _reset(mode: s.first),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final n in seatCounts)
                ChoiceChip(label: Text('${n ~/ 1000}k'), selected: _n == n, onSelected: (_) => _reset(n: n)),
              FilterChip(
                label: const Text('Autopilot'),
                selected: _autopilot,
                onSelected: (v) => _reset(autopilot: v),
              ),
            ],
          ),
        ],
      ),
      body: KeyedSubtree(
        key: ObjectKey(_layout),
        child: buildSeatMap(_mode, _layout, autopilot: _autopilot),
      ),
      bottom: CheckoutBar(layout: _layout),
    );
  }
}

/// Plain Flutter UI fed by the canvas through a ValueNotifier.
class CheckoutBar extends StatelessWidget {
  const CheckoutBar({super.key, required this.layout});
  final SeatLayout layout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.card,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: ValueListenableBuilder<Set<int>>(
            valueListenable: layout.selection,
            builder: (context, sel, _) {
              final total = sel.fold<int>(0, (sum, i) => sum + layout.price[i]);
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      sel.isEmpty ? 'Tap seats to select' : '${sel.length} seats · ₹$total',
                      style: const TextStyle(fontSize: 16, color: Palette.cream),
                    ),
                  ),
                  FilledButton(onPressed: sel.isEmpty ? null : () {}, child: const Text('Checkout')),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
