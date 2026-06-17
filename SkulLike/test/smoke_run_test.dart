import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skul_like/game/world.dart';
import 'package:skul_like/game/meta.dart';

// Smoke test: start a run and step the world for a while to surface any
// exceptions thrown during init / the update loop (the "freeze on start" bug).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('run starts and updates without throwing', () {
    final meta = MetaState();
    final world = GameWorld(meta, town: false);
    for (int i = 0; i < 1200; i++) {
      world.update(1 / 60);
    }
    expect(world.player.hp, isNotNull);
  });

  test('town starts and updates without throwing', () {
    final meta = MetaState();
    final world = GameWorld(meta, town: true);
    for (int i = 0; i < 300; i++) {
      world.update(1 / 60);
    }
    expect(world.player.hp, isNotNull);
  });
}
