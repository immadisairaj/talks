import 'package:material_ui/material_ui.dart';

import 'checkout/checkout_screen.dart';
import 'common/frame_stats.dart';
import 'common/theme.dart';
import 'rewards/rewards_screen.dart';
import 'robot/robot_screen.dart';
import 'stadium/stadium_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FrameStats.instance.ensureListening();
  runApp(const ShowcaseApp());
}

class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeScreen(),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demos = <(String, String, IconData, WidgetBuilder)>[
      ('Stadium tickets', '20,000 seats, live bookings, pan & zoom', Icons.stadium_outlined, (_) => const StadiumScreen()),
      ('Savings reward', 'Scratch card → coins into the vault', Icons.savings_outlined, (_) => const RewardsScreen()),
      ('Checkout moments', 'Fly to cart · cashback coin rain', Icons.shopping_bag_outlined, (_) => const CheckoutScreen()),
      ('Robot vacuum', 'Live home map · rooms · no-go zones', Icons.cleaning_services_outlined, (_) => const RobotScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Demos')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: demos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final (t, s, icon, b) = demos[i];
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: b)),
            child: Panel(
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(gradient: Pal.goldGradient, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: const Color(0xFF111114)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700, fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(s, style: const TextStyle(color: Pal.muted, fontSize: 13)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: Pal.muted),
              ]),
            ),
          );
        },
      ),
    );
  }
}
