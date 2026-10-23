import 'package:material_ui/material_ui.dart';

import '../common/fps_chip.dart';
import '../common/theme.dart';
import 'seat_layout.dart';
import 'stadium_views.dart';

const seatCounts = [2000, 10000, 20000];

/// Ticket booking for a 20,000-seat stadium with live bookings from others.
/// Switch between a plain-widgets implementation and Flame to record both.
class StadiumScreen extends StatefulWidget {
  const StadiumScreen({super.key});

  @override
  State<StadiumScreen> createState() => _StadiumScreenState();
}

class _StadiumScreenState extends State<StadiumScreen> {
  StadiumMode _mode = StadiumMode.flame;
  int _n = 20000;
  bool _autopilot = false;
  bool _fps = true;
  late SeatLayout _layout = SeatLayout(_n);

  void _reset({StadiumMode? mode, int? n, bool? autopilot}) => setState(() {
        _mode = mode ?? _mode;
        _n = n ?? _n;
        _autopilot = autopilot ?? _autopilot;
        _layout = SeatLayout(_n);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cup Final'),
            Text('Chennai · Sat, 7:30 PM', style: TextStyle(fontSize: 13, color: Pal.muted, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Autopilot camera',
            onPressed: () => _reset(autopilot: !_autopilot),
            icon: Icon(Icons.motion_photos_on, color: _autopilot ? Pal.gold : Pal.muted),
          ),
          IconButton(
            tooltip: 'FPS',
            onPressed: () => setState(() => _fps = !_fps),
            icon: Icon(Icons.speed, color: _fps ? Pal.gold : Pal.muted),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                SegmentedButton<StadiumMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: StadiumMode.widgets, label: Text('Widgets')),
                    ButtonSegment(value: StadiumMode.flame, label: Text('Flame')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => _reset(mode: s.first),
                ),
                const Spacer(),
                for (final n in seatCounts)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text('${n ~/ 1000}k'),
                      selected: _n == n,
                      showCheckmark: false,
                      onSelected: (_) => _reset(n: n),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRect(
                    child: KeyedSubtree(
                      key: ObjectKey(_layout),
                      child: buildStadium(_mode, _layout, autopilot: _autopilot),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 8,
                  child: _Tag(text: _mode == StadiumMode.flame ? 'Flame' : 'Flutter widgets', seats: _layout.n),
                ),
                if (_fps) const Positioned(right: 16, top: 8, child: FpsChip()),
                const Positioned(left: 16, bottom: 12, child: _Legend()),
              ],
            ),
          ),
          _CheckoutBar(layout: _layout),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.seats});
  final String text;
  final int seats;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xE60B0B0F), borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text('$text · ${(seats / 1000).toStringAsFixed(0)}k seats · live',
              style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(color: Pal.muted, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
        ]);
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xE60B0B0F), borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          dot(seatColors[0], 'Available'),
          dot(seatColors[1], 'Yours'),
          dot(seatColors[2], 'Booked'),
        ]),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.layout});
  final SeatLayout layout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Pal.surface, border: Border(top: BorderSide(color: Pal.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
          child: ValueListenableBuilder<Set<int>>(
            valueListenable: layout.selection,
            builder: (context, sel, _) {
              final total = sel.fold<int>(0, (sum, i) => sum + layout.price[i]);
              return Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(sel.isEmpty ? 'Pick your seats' : '${sel.length} seat${sel.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(sel.isEmpty ? 'Tap any seat in the stadium' : '₹${_fmt(total)}',
                        style: const TextStyle(color: Pal.muted, fontSize: 13)),
                  ]),
                ),
                FilledButton(onPressed: sel.isEmpty ? null : () {}, child: const Text('Book tickets')),
              ]);
            },
          ),
        ),
      ),
    );
  }

  static String _fmt(int v) {
    final s = v.toString();
    return s.length <= 3 ? s : '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }
}
