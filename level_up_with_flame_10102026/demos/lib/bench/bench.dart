import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../flame_version.dart';
import 'frame_stats.dart';

/// One measured configuration: a demo in one mode at one load.
class Scenario {
  const Scenario({
    required this.suite,
    required this.mode,
    required this.load,
    required this.build,
    this.note = '',
  });

  final String suite;
  final String mode;
  final int load;
  final String note;
  final Widget Function() build;

  String get label => '$suite · $mode · $load${note.isEmpty ? '' : ' · $note'}';
}

class BenchResult {
  BenchResult(this.scenario, this.summary);
  final Scenario scenario;
  final FrameSummary summary;

  Map<String, Object> toJson() => {
        'suite': scenario.suite,
        'mode': scenario.mode,
        'load': scenario.load,
        if (scenario.note.isNotEmpty) 'note': scenario.note,
        ...summary.toJson(),
      };
}

typedef SuiteBuilder = List<Scenario> Function();

/// Global benchmark state, reachable from the UI and from the VM service.
class Bench {
  Bench._();
  static final Bench instance = Bench._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final Map<String, SuiteBuilder> suites = {};

  String status = 'idle';
  String? suite;
  int index = 0;
  int total = 0;
  String current = '';
  final List<BenchResult> results = [];
  Duration warmup = const Duration(seconds: 2);
  Duration measure = const Duration(seconds: 6);

  void register(String name, SuiteBuilder builder) => suites[name] = builder;

  Map<String, Object?> device() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final v = views.isEmpty ? null : views.first;
    return {
      'platform': defaultTargetPlatform.name,
      'flame': flameVersion,
      'web': kIsWeb,
      'buildMode': kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
      'refreshRate': FrameStats.refreshRate,
      if (v != null) 'logicalSize': '${(v.physicalSize.width / v.devicePixelRatio).round()}x${(v.physicalSize.height / v.devicePixelRatio).round()}',
      if (v != null) 'dpr': v.devicePixelRatio,
    };
  }

  Map<String, Object?> toJson() => {
        'status': status,
        'suite': suite,
        'progress': '$index/$total',
        'current': current,
        'device': device(),
        'results': [for (final r in results) r.toJson()],
      };

  /// Results as a Markdown table (paste straight into RESULTS.md).
  String markdown() {
    final d = device();
    final b = StringBuffer()
      ..writeln('Suite: $suite · Flame ${d['flame']} · ${d['platform']} · ${d['buildMode']} · ${d['refreshRate']} Hz · ${d['logicalSize']}')
      ..writeln()
      ..writeln('| suite | mode | load | fps | build p90 | raster p90 | worst ms | jank % |')
      ..writeln('|---|---|---:|---:|---:|---:|---:|---:|');
    for (final r in results) {
      final s = r.summary;
      b.writeln('| ${r.scenario.suite} | ${r.scenario.mode} | ${r.scenario.load} | ${s.fps.toStringAsFixed(1)} | '
          '${s.buildP90.toStringAsFixed(1)} | ${s.rasterP90.toStringAsFixed(1)} | '
          '${s.worstFrameMs.toStringAsFixed(1)} | ${s.jankPercent.toStringAsFixed(0)} |');
    }
    return b.toString();
  }

  /// Starts [name] by pushing the runner screen. Returns false if unknown or busy.
  bool start(String name, {int? warmupMs, int? measureMs}) {
    final b = suites[name];
    final nav = navigatorKey.currentState;
    if (b == null || nav == null || status == 'running') return false;
    if (warmupMs != null) warmup = Duration(milliseconds: warmupMs);
    if (measureMs != null) measure = Duration(milliseconds: measureMs);
    nav.push(MaterialPageRoute<void>(builder: (_) => BenchRunScreen(suiteName: name, scenarios: b())));
    return true;
  }

  void registerExtensions() {
    developer.registerExtension('ext.showcase.suites', (method, params) async {
      return developer.ServiceExtensionResponse.result(jsonEncode({'suites': suites.keys.toList()}));
    });
    developer.registerExtension('ext.showcase.run', (method, params) async {
      final ok = start(
        params['suite'] ?? '',
        warmupMs: int.tryParse(params['warmupMs'] ?? ''),
        measureMs: int.tryParse(params['measureMs'] ?? ''),
      );
      return developer.ServiceExtensionResponse.result(jsonEncode({'started': ok, 'suite': params['suite']}));
    });
    developer.registerExtension('ext.showcase.results', (method, params) async {
      return developer.ServiceExtensionResponse.result(jsonEncode(toJson()));
    });
  }
}

/// Runs each scenario full screen: warm-up, then a measured window.
class BenchRunScreen extends StatefulWidget {
  const BenchRunScreen({super.key, required this.suiteName, required this.scenarios});

  final String suiteName;
  final List<Scenario> scenarios;

  @override
  State<BenchRunScreen> createState() => _BenchRunScreenState();
}

class _BenchRunScreenState extends State<BenchRunScreen> {
  final Bench _b = Bench.instance;
  int _i = 0;
  bool _done = false;
  bool _cancelled = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _b
      ..status = 'running'
      ..suite = widget.suiteName
      ..total = widget.scenarios.length
      ..results.clear();
    FrameStats.instance.ensureListening();
    _runCurrent();
  }

  void _runCurrent() {
    if (_cancelled) return;
    if (_i >= widget.scenarios.length) {
      setState(() => _done = true);
      _b
        ..status = 'done'
        ..index = widget.scenarios.length
        ..current = '';
      developer.log(jsonEncode(_b.toJson()), name: 'showcase.results');
      debugPrint('[showcase] ===== ${widget.suiteName} done =====');
      _b.markdown().split('\n').forEach(debugPrint);
      debugPrint('[showcase] JSON: ${jsonEncode(_b.toJson())}');
      return;
    }
    final s = widget.scenarios[_i];
    _b
      ..index = _i
      ..current = s.label;
    _timer = Timer(_b.warmup, () {
      FrameStats.instance.startWindow();
      _timer = Timer(_b.measure, () {
        final summary = FrameStats.instance.stopWindow();
        _b.results.add(BenchResult(s, summary));
        debugPrint('[showcase] ${s.label}: ${summary.fps.toStringAsFixed(1)} fps, '
            'build p90 ${summary.buildP90.toStringAsFixed(1)} ms, raster p90 ${summary.rasterP90.toStringAsFixed(1)} ms, '
            'worst ${summary.worstFrameMs.toStringAsFixed(1)} ms, jank ${summary.jankPercent.toStringAsFixed(0)}%');
        if (!mounted) return;
        setState(() => _i++);
        _runCurrent();
      });
    });
  }

  @override
  void dispose() {
    _cancelled = true;
    _timer?.cancel();
    if (_b.status == 'running') _b.status = 'cancelled';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return ResultsScreen(title: widget.suiteName, results: _b.results);
    final s = widget.scenarios[_i];
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: KeyedSubtree(key: ValueKey(_i), child: s.build())),
          Positioned(
            left: 12,
            right: 12,
            top: MediaQuery.paddingOf(context).top + 8,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(color: const Color(0xCC1C1411), borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Benchmark ${_i + 1}/${widget.scenarios.length}: ${s.label}',
                    style: const TextStyle(color: Color(0xFFF7EFE4), fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.title, required this.results});

  final String title;
  final List<BenchResult> results;

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]);
    return Scaffold(
      appBar: AppBar(
        title: Text('Results: $title'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.table_chart),
            label: const Text('Copy table'),
            onPressed: () => _copy(context, Bench.instance.markdown()),
          ),
          TextButton.icon(
            icon: const Icon(Icons.data_object),
            label: const Text('Copy JSON'),
            onPressed: () => _copy(context, jsonEncode(Bench.instance.toJson())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 14,
            columns: const [
              DataColumn(label: Text('suite')),
              DataColumn(label: Text('mode')),
              DataColumn(label: Text('load'), numeric: true),
              DataColumn(label: Text('fps'), numeric: true),
              DataColumn(label: Text('build p90'), numeric: true),
              DataColumn(label: Text('raster p90'), numeric: true),
              DataColumn(label: Text('worst ms'), numeric: true),
              DataColumn(label: Text('jank %'), numeric: true),
            ],
            rows: [
              for (final r in results)
                DataRow(cells: [
                  DataCell(Text(r.scenario.suite, style: style)),
                  DataCell(Text(r.scenario.mode, style: style)),
                  DataCell(Text('${r.scenario.load}', style: style)),
                  DataCell(Text(r.summary.fps.toStringAsFixed(1), style: style)),
                  DataCell(Text(r.summary.buildP90.toStringAsFixed(1), style: style)),
                  DataCell(Text(r.summary.rasterP90.toStringAsFixed(1), style: style)),
                  DataCell(Text(r.summary.worstFrameMs.toStringAsFixed(1), style: style)),
                  DataCell(Text(r.summary.jankPercent.toStringAsFixed(0), style: style)),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
