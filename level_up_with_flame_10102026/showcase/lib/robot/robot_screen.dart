import 'package:flame/game.dart' hide Matrix4;
import 'package:material_ui/material_ui.dart';

import '../common/fps_chip.dart';
import '../common/theme.dart';
import 'robot_game.dart';

const speeds = [1.0, 4.0, 10.0];

/// A robot vacuum's companion app: live map, tap a room to clean it,
/// draw no-go zones, follow the robot. The map is Flame; the rest is Flutter.
class RobotScreen extends StatefulWidget {
  const RobotScreen({super.key});

  @override
  State<RobotScreen> createState() => _RobotScreenState();
}

class _RobotScreenState extends State<RobotScreen> {
  final RobotGame _game = RobotGame();
  bool _fps = true;

  void _set(VoidCallback f) => setState(f);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Home'),
            Text('Robot vacuum · live map', style: TextStyle(fontSize: 13, color: Pal.muted, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Follow robot',
            onPressed: () => _set(() => _game.follow = !_game.follow),
            icon: Icon(Icons.my_location, color: _game.follow ? Pal.gold : Pal.muted),
          ),
          IconButton(
            tooltip: 'FPS',
            onPressed: () => _set(() => _fps = !_fps),
            icon: Icon(Icons.speed, color: _fps ? Pal.gold : Pal.muted),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: ClipRect(child: GameWidget(game: _game))),
                Positioned(left: 16, top: 8, child: _StateTag(game: _game)),
                if (_fps) const Positioned(right: 16, top: 8, child: FpsChip()),
                if (_game.zoneMode)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: _Banner(
                      onClear: () => _game.clearZones(),
                      onDone: () => _set(() => _game.zoneMode = false),
                    ),
                  ),
              ],
            ),
          ),
          _ControlPanel(game: _game, onChanged: () => setState(() {})),
        ],
      ),
    );
  }
}

String _stateText(RobotStatus s) => switch (s.state) {
      RobotState.idle => 'Paused',
      RobotState.cleaning => 'Cleaning ${s.room ?? ''}'.trim(),
      RobotState.returning => 'Returning to dock',
      RobotState.charging => s.battery >= 99.5 ? 'Docked · fully charged' : 'Charging',
    };

class _StateTag extends StatelessWidget {
  const _StateTag({required this.game});
  final RobotGame game;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<RobotStatus>(
        valueListenable: game.status,
        builder: (context, s, _) {
          final color = switch (s.state) {
            RobotState.cleaning => const Color(0xFF6FE3FF),
            RobotState.returning => Pal.gold,
            RobotState.charging => Pal.green,
            RobotState.idle => Pal.muted,
          };
          return DecoratedBox(
            decoration: BoxDecoration(color: const Color(0xE60B0B0F), borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(_stateText(s), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          );
        },
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.onClear, required this.onDone});
  final VoidCallback onClear;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF015151C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x66FF5D6C)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Row(children: [
            const Icon(Icons.block, size: 18, color: Color(0xFFFF5D6C)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Drag on the map to add a no-go zone',
                  style: TextStyle(color: Pal.text, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            TextButton(onPressed: onClear, child: const Text('Clear')),
            TextButton(onPressed: onDone, child: const Text('Done')),
          ]),
        ),
      );
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.game, required this.onChanged});
  final RobotGame game;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Pal.surface, border: Border(top: BorderSide(color: Pal.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: ValueListenableBuilder<RobotStatus>(
            valueListenable: game.status,
            builder: (context, s, _) {
              final busy = s.state == RobotState.cleaning || s.state == RobotState.returning;
              return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  _Stat(
                    icon: s.battery > 20 ? Icons.battery_5_bar : Icons.battery_alert,
                    value: '${s.battery.round()}%',
                    label: 'Battery',
                  ),
                  _Stat(icon: Icons.crop_square, value: '${s.areaM2.toStringAsFixed(1)} m²', label: 'Cleaned'),
                  _Stat(icon: Icons.timer_outlined, value: '${s.minutes.floor()} min', label: 'Time'),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: game.map.rooms.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, k) {
                      final done = s.roomDone.length > k ? s.roomDone[k] : 0.0;
                      final active = s.room == game.map.rooms[k].name;
                      return ActionChip(
                        onPressed: () => game.cleanRooms([k]),
                        side: BorderSide(color: active ? const Color(0xFF6FE3FF) : Pal.line),
                        label: Text('${game.map.rooms[k].name}  ${(done * 100).clamp(0, 100).round()}%'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? game.pause : game.cleanAll,
                      child: Text(busy ? 'Pause' : 'Clean all'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'No-go zone',
                    onPressed: () {
                      game.zoneMode = !game.zoneMode;
                      onChanged();
                    },
                    icon: Icon(Icons.block, color: game.zoneMode ? const Color(0xFFFF5D6C) : Pal.text),
                  ),
                  IconButton.outlined(
                    tooltip: 'Send to dock',
                    onPressed: game.goToDock,
                    icon: const Icon(Icons.home_outlined, color: Pal.text),
                  ),
                  const SizedBox(width: 4),
                  SegmentedButton<double>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      for (final v in speeds) ButtonSegment(value: v, label: Text('${v.round()}×')),
                    ],
                    selected: {game.speed},
                    onSelectionChanged: (v) {
                      game.speed = v.first;
                      onChanged();
                    },
                  ),
                ]),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Row(children: [
          Icon(icon, size: 20, color: Pal.gold),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700, fontSize: 15)),
            Text(label, style: const TextStyle(color: Pal.muted, fontSize: 11)),
          ]),
        ]),
      );
}
