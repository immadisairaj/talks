import 'package:material_ui/material_ui.dart';

import 'bench/bench.dart';
import 'bench/frame_stats.dart';
import 'common/palette.dart';
import 'demos/registry.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FrameStats.instance.ensureListening();
  registerSuites();
  Bench.instance.registerExtensions();
  runApp(const ShowcaseApp());
}

class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flame showcase',
      debugShowCheckedModeBanner: false,
      navigatorKey: Bench.instance.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Palette.flame, brightness: Brightness.dark),
        scaffoldBackgroundColor: Palette.ink,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Level Up with Flame · demos'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.speed),
            label: const Text('Run all benchmarks'),
            onPressed: () => Bench.instance.start('all'),
          ),
        ],
      ),
      body: ListView(
        children: [
          for (final d in demos)
            ListTile(
              title: Text(d.title),
              subtitle: Text(d.subtitle),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: d.builder)),
              trailing: d.suite == null
                  ? null
                  : IconButton(
                      tooltip: 'Run benchmark',
                      icon: const Icon(Icons.speed),
                      onPressed: () => Bench.instance.start(d.suite!),
                    ),
            ),
        ],
      ),
    );
  }
}
