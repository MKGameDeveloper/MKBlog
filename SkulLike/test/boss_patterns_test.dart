import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skul_like/game/world.dart';
import 'package:skul_like/game/meta.dart';
import 'package:skul_like/game/types.dart';
import 'package:skul_like/game/entities.dart';

// Drive every boss through many update ticks (including the enraged phase) so
// each visual's themed playbook — basics, repositions, guards and every
// signature skill (apple scatter, roots, feathers, swoop, rest, firebreath,
// knives, web, …) — is exercised and proven not to throw.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const visuals = [
    'boar', 'goblin', 'eagle', 'redBear', 'appleTree', 'golem', 'witch',
    'mercenary', 'rockBrute', 'mummy', 'worm', 'dragonkin', 'knight', 'bandit',
    'demonKing', 'doppel', 'wolfKing', 'spider', 'dragon',
  ];

  for (final v in visuals) {
    test('boss "$v" runs its full playbook without throwing', () {
      final meta = MetaState();
      final world = GameWorld(meta, town: false);
      final spec = BossSpec('테스트 $v', BossArchetype.charger,
          BossShape.humanoid, const Color(0xFF4488FF), 500, 120, visual: v);
      final boss = Boss(spec, 600, kGroundY - 96);
      world.boss = boss;

      for (int i = 0; i < 1400; i++) {
        // keep the player alive so the loop keeps stepping the boss
        world.player.hp = world.player.maxHp;
        world.player.invuln = 0;
        // after a while, force (and hold) the enraged phase below 50% hp
        if (i >= 400) boss.hp = boss.maxHp * 0.4;
        world.update(1 / 60);
        // never let the boss actually die / get cleared mid-test
        if (world.boss == null || world.boss!.dead) {
          boss.dead = false;
          boss.hp = boss.maxHp * (i >= 400 ? 0.4 : 1.0);
          world.boss = boss;
        }
      }
      expect(world.boss, isNotNull);
    });
  }
}
