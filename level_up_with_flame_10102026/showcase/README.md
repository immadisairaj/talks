# showcase: demo videos only

Four demos for the talk, in one dark, unbranded app. Flame 1.38.2 (stable) + flame_forge2d 0.20.0.

```bash
cd showcase
flutter create . --platforms android,ios,macos --project-name showcase   # once, for platform folders
flutter run --release -d <phone>      # use release for recording
```
Fonts: Inter (SIL OFL 1.1, see `assets/fonts/OFL.txt`). Images: generated vector art (`assets/source/generate_assets.py`).

See `SHOT_LIST.md` for what to record.

| Demo | Folder | Flame does | Flutter does |
|---|---|---|---|
| Stadium tickets | `lib/stadium/` | 20k seats in ~100 block components, culling, live bookings, tap → seat | Header, mode/size chips, legend, checkout bar |
| Savings reward | `lib/rewards/` | Forge2D coins, vault, scratch mask | Savings screen, dialog, Collect button, result sheet |
| Checkout moments | `lib/checkout/` | Fly-to-cart path, particles, cashback coin rain | Product page, cart badge, success screen |
| Robot vacuum | `lib/robot/` | Robot driving its plan with `dt`, lidar sweep, coverage painting, camera follow, tap/drag in map coordinates | Status, room chips with %, Clean all / Pause, no-go toggle, dock, speed |

The robot map's data and algorithms (`home_map.dart`: rooms, walls, A* planner, lawnmower stripes) are plain Dart with no Flame in them.
In a real product the pose and map would arrive from the robot (MQTT/WebSocket, a few times a second); here the robot is simulated.
