import 'dart:math' as math;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Summary of the frames seen in one measuring window.
class FrameSummary {
  FrameSummary({
    required this.frames,
    required this.seconds,
    required this.fps,
    required this.refreshRate,
    required this.buildP50,
    required this.buildP90,
    required this.buildP99,
    required this.rasterP50,
    required this.rasterP90,
    required this.rasterP99,
    required this.worstFrameMs,
    required this.jankPercent,
  });

  final int frames;
  final double seconds;
  final double fps;
  final double refreshRate;
  final double buildP50, buildP90, buildP99;
  final double rasterP50, rasterP90, rasterP99;

  /// Worst max(build, raster) in ms.
  final double worstFrameMs;

  /// Frames whose build or raster time went over the refresh budget.
  final double jankPercent;

  static FrameSummary empty(double refreshRate) => FrameSummary(
        frames: 0,
        seconds: 0,
        fps: 0,
        refreshRate: refreshRate,
        buildP50: 0,
        buildP90: 0,
        buildP99: 0,
        rasterP50: 0,
        rasterP90: 0,
        rasterP99: 0,
        worstFrameMs: 0,
        jankPercent: 0,
      );

  Map<String, Object> toJson() => {
        'frames': frames,
        'seconds': _r(seconds),
        'fps': _r(fps),
        'refreshRate': _r(refreshRate),
        'buildP50': _r(buildP50),
        'buildP90': _r(buildP90),
        'buildP99': _r(buildP99),
        'rasterP50': _r(rasterP50),
        'rasterP90': _r(rasterP90),
        'rasterP99': _r(rasterP99),
        'worstFrameMs': _r(worstFrameMs),
        'jankPercent': _r(jankPercent),
      };

  static double _r(double v) => (v * 10).roundToDouble() / 10;
}

/// Collects [FrameTiming]s from the engine. Works the same for widget
/// screens and Flame games, so numbers are comparable.
class FrameStats {
  FrameStats._();
  static final FrameStats instance = FrameStats._();

  final List<FrameTiming> _window = [];
  final List<FrameTiming> _live = [];
  bool _listening = false;
  bool _recording = false;

  void ensureListening() {
    if (_listening) return;
    _listening = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_recording) _window.addAll(timings);
    _live.addAll(timings);
    // Keep about the last second for the live overlay.
    final over = _live.length - 150;
    if (over > 0) _live.removeRange(0, over);
  }

  void startWindow() {
    ensureListening();
    _window.clear();
    _recording = true;
  }

  FrameSummary stopWindow() {
    _recording = false;
    final s = summarize(_window);
    _window.clear();
    return s;
  }

  /// Summary of roughly the last second, for the on-screen overlay.
  FrameSummary live() {
    ensureListening();
    if (_live.isEmpty) return FrameSummary.empty(refreshRate);
    final last = _live.last.timestampInMicroseconds(FramePhase.vsyncStart);
    final recent = _live
        .where((t) => last - t.timestampInMicroseconds(FramePhase.vsyncStart) <= 1000000)
        .toList();
    return summarize(recent);
  }

  static double get refreshRate {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 60;
    final r = views.first.display.refreshRate;
    return r.isFinite && r > 1 ? r : 60;
  }

  static FrameSummary summarize(List<FrameTiming> t) {
    final rate = refreshRate;
    if (t.length < 2) return FrameSummary.empty(rate);
    final first = t.first.timestampInMicroseconds(FramePhase.vsyncStart);
    final last = t.last.timestampInMicroseconds(FramePhase.vsyncStart);
    final seconds = (last - first) / 1e6;
    final build = [for (final f in t) f.buildDuration.inMicroseconds / 1000.0]..sort();
    final raster = [for (final f in t) f.rasterDuration.inMicroseconds / 1000.0]..sort();
    final budget = 1000 / rate;
    var jank = 0;
    var worst = 0.0;
    for (final f in t) {
      final m = math.max(f.buildDuration.inMicroseconds, f.rasterDuration.inMicroseconds) / 1000.0;
      if (m > budget) jank++;
      if (m > worst) worst = m;
    }
    return FrameSummary(
      frames: t.length,
      seconds: seconds,
      fps: seconds > 0 ? (t.length - 1) / seconds : 0,
      refreshRate: rate,
      buildP50: _p(build, .5),
      buildP90: _p(build, .9),
      buildP99: _p(build, .99),
      rasterP50: _p(raster, .5),
      rasterP90: _p(raster, .9),
      rasterP99: _p(raster, .99),
      worstFrameMs: worst,
      jankPercent: 100 * jank / t.length,
    );
  }

  static double _p(List<double> sorted, double q) =>
      sorted[math.min(sorted.length - 1, (q * sorted.length).floor())];
}
