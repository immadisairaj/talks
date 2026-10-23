import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../bench/bench.dart';
import '../../common/demo_scaffold.dart';
import '../../common/palette.dart';
import 'factory_model.dart';
import 'factory_views.dart';

const machineCounts = [20, 40, 80, 160];

List<Scenario> factorySuite() => [
      for (final n in machineCounts)
        for (final m in FactoryMode.values)
          Scenario(
            suite: 'factory',
            mode: m.name,
            load: n,
            note: 'autopilot + 20 Hz sensors',
            build: () => buildFactory(m, Factory(n), autopilot: true),
          ),
    ];

class FactoryScreen extends StatefulWidget {
  const FactoryScreen({super.key});

  @override
  State<FactoryScreen> createState() => _FactoryScreenState();
}

class _FactoryScreenState extends State<FactoryScreen> {
  FactoryMode _mode = FactoryMode.flame;
  int _n = 40;
  bool _autopilot = false;
  late Factory _f = Factory(_n);

  void _reset({FactoryMode? mode, int? n, bool? autopilot}) => setState(() {
        _mode = mode ?? _mode;
        _n = n ?? _n;
        _autopilot = autopilot ?? _autopilot;
        _f = Factory(_n);
      });

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Live factory floor',
      controls: Column(
        children: [
          SegmentedButton<FactoryMode>(
            showSelectedIcon: false,
            segments: [for (final m in FactoryMode.values) ButtonSegment(value: m, label: Text(m.label))],
            selected: {_mode},
            onSelectionChanged: (s) => _reset(mode: s.first),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final n in machineCounts)
              ChoiceChip(label: Text('$n machines'), selected: _n == n, onSelected: (_) => _reset(n: n)),
            FilterChip(label: const Text('Autopilot'), selected: _autopilot, onSelected: (v) => _reset(autopilot: v)),
          ]),
        ],
      ),
      body: KeyedSubtree(
        key: ObjectKey(_f),
        child: buildFactory(_mode, _f, autopilot: _autopilot, onTap: (m) => showMachineSheet(context, m)),
      ),
    );
  }
}

/// Plain Flutter bottom sheet, opened from either mode, refreshing live.
void showMachineSheet(BuildContext context, Machine m) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Palette.card,
    builder: (_) => _MachineSheet(m),
  );
}

class _MachineSheet extends StatefulWidget {
  const _MachineSheet(this.m);
  final Machine m;

  @override
  State<_MachineSheet> createState() => _MachineSheetState();
}

class _MachineSheetState extends State<_MachineSheet> {
  late final Timer _t;
  final List<double> _history = [];

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 200), (_) {
      setState(() {
        _history.add(widget.m.temp);
        if (_history.length > 60) _history.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Palette.cream)),
          const SizedBox(height: 8),
          Text(
            '${m.temp.toStringAsFixed(1)} °C · power ${(m.power * 100).round()}%${m.alarm ? ' · ALARM' : ''}',
            style: TextStyle(color: m.alarm ? Palette.flame : Palette.muted, fontSize: 16),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 80, child: CustomPaint(size: Size.infinite, painter: _Spark(_history))),
        ],
      ),
    );
  }
}

class _Spark extends CustomPainter {
  _Spark(this.v);
  final List<double> v;

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final p = Path();
    for (var i = 0; i < v.length; i++) {
      final x = size.width * i / 59;
      final y = size.height * (1 - (v[i] - 35) / 65);
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = Palette.flame
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_Spark old) => true;
}
