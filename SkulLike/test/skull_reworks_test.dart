import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skul_like/game/world.dart';
import 'package:skul_like/game/meta.dart';
import 'package:skul_like/game/types.dart';
import 'package:skul_like/game/painter.dart';

// Exercises the 6 reworked skulls (망령기사/야밤도/약탈자/대마법사/리치/공허군주):
// equip each, then hammer skill + attack + jump for a long stretch while ALSO
// rendering every frame, so both the world-update logic AND the new painter
// code (ghost horse, void minions, falchion, fire-tornado / wind-blade, reflect
// aura, stealth) are surfaced for runtime exceptions.
void _render(GameWorld world) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  GamePainter(world).paint(canvas, const Size(1280, 720));
  recorder.endRecording().dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const reworked = <SkullType>[
    SkullType.spectreKnight, // 유령마 강림 (ride)
    SkullType.nightblade, // 그림자 잠행 (stealth + assassinate)
    SkullType.ravager, // 가시 반사 (reflect)
    SkullType.archmage, // 4원소 마법 (elements)
    SkullType.lich, // 낫 3연타 + 검은 검기
    SkullType.voidlord, // 공허 몬스터 소환
    SkullType.swordsaint, // 창천의 검기 (blade aura + long dash)
    SkullType.seraph, // 대천사의 날개 (wing stun) + 영구 공격력 패시브
    SkullType.knight, // 3배 검기 + 큰 넉백
    SkullType.bomber, // 대폭발 + 사방 폭탄 산개
    SkullType.paladin, // 천공의 대검 (꽂힘 10초 + 근접 버프)
    SkullType.sniper, // 기본공격 2배 + 레일건 5초 연사
    SkullType.dragoon, // 용의 비상 자유비행 + 비행 3타 돌격, 드래곤 날개
  ];

  for (final t in reworked) {
    test('reworked skull ${t.name} casts, fights and renders without throwing',
        () {
      final meta = MetaState();
      final world = GameWorld(meta, town: false);
      world.devGiveSkull(t);
      for (int i = 0; i < 1800; i++) {
        // force the cooldown to zero periodically so the skill actually fires
        // (and, for the nightblade, so the stealth re-cast assassination runs)
        if (i % 25 == 0) {
          world.player.skillTimer = 0;
          world.queueSkill();
        }
        world.queueAttack();
        if (i % 9 == 0) world.queueJump();
        if (i % 11 == 0) world.queueDodge(); // 검성 긴 대시 경로 피해 경로
        // 용기병 자유 비행: drive up/down so vertical flight + caps run
        world.moveUp = i % 40 < 12;
        world.moveDown = i % 40 >= 28;
        world.update(1 / 60);
        if (i % 4 == 0) _render(world);
      }
      expect(world.player.hp, isNotNull);
    });
  }

  test('archmage 4원소: many casts cover fire/water/wind/earth branches', () {
    final meta = MetaState();
    final world = GameWorld(meta, town: false);
    world.devGiveSkull(SkullType.archmage);
    for (int i = 0; i < 6000; i++) {
      if (i % 12 == 0) {
        world.player.skillTimer = 0;
        world.queueSkill();
      }
      world.update(1 / 60);
      if (i % 6 == 0) _render(world);
    }
    expect(world.player.hp, isNotNull);
  });
}
