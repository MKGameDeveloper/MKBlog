import 'dart:math';
import 'dart:ui';
import 'types.dart';

// ============================================================
// FLOOR GRAPH  (start -> rooms -> exactly one shop -> boss)
// ============================================================
FloorGraph generateFloor(int floor, Random rng) {
  final int cap = min(floor, 3);
  final int maxDepth = 3 + cap + (rng.nextBool() ? 1 : 0); // 4..7
  final nodes = <RoomNode>[];
  final byDepth = <List<int>>[];
  int idc = 0;

  for (int d = 0; d <= maxDepth; d++) {
    final count = (d == 0 || d == maxDepth) ? 1 : (rng.nextBool() ? 2 : 1);
    final ids = <int>[];
    for (int j = 0; j < count; j++) {
      final RoomType type = d == 0
          ? RoomType.start
          : (d == maxDepth ? RoomType.boss : RoomType.combat);
      nodes.add(RoomNode(idc, d, type, <int>[]));
      ids.add(idc);
      idc++;
    }
    byDepth.add(ids);
  }

  // exactly ONE shop per floor (a random middle room)
  final middle = nodes.where((n) => n.depth > 0 && n.depth < maxDepth).toList();
  if (middle.isNotEmpty) {
    final pick = middle[rng.nextInt(middle.length)];
    final idx = nodes.indexWhere((n) => n.id == pick.id);
    nodes[idx] = RoomNode(pick.id, pick.depth, RoomType.shop, pick.next);
  }

  // connect depths, guaranteeing coverage
  for (int d = 0; d < maxDepth; d++) {
    final cur = byDepth[d];
    final nxt = byDepth[d + 1];
    final covered = <int>{};
    for (final cid in cur) {
      final node = nodes.firstWhere((n) => n.id == cid);
      final links = (nxt.length > 1 && rng.nextBool()) ? 2 : 1;
      final shuffled = [...nxt]..shuffle(rng);
      for (int i = 0; i < links && i < shuffled.length; i++) {
        node.next.add(shuffled[i]);
        covered.add(shuffled[i]);
      }
    }
    for (final nid in nxt) {
      if (!covered.contains(nid)) {
        // pick ONE random parent in the current depth, then find it. (The pick
        // must be hoisted out of the predicate — evaluating it per-iteration
        // re-rolls the target every comparison and can match nothing → crash.)
        final cid = cur[rng.nextInt(cur.length)];
        final cNode = nodes.firstWhere((n) => n.id == cid);
        if (!cNode.next.contains(nid)) cNode.next.add(nid);
      }
    }
  }

  // randomize the biome per floor per run (no longer fixed by floor index)
  final biome = Biome.values[rng.nextInt(Biome.values.length)];
  return FloorGraph(nodes, byDepth[0][0], byDepth[maxDepth][0], maxDepth,
      biome: biome);
}

// ============================================================
// ROOM LAYOUT
// ============================================================
RoomData buildRoom(RoomNode node, int floor, Random rng, FloorGraph g,
    {Set<String>? usedBosses}) {
  final type = node.type;
  final biome = kBiomes[g.biome]!;
  // room size class: combat rooms roll normal / wide / tall / huge so maps
  // vary a lot (some long, some towering, some both).
  double width;
  bool tall = false;
  if (type == RoomType.boss) {
    width = 1700.0;
  } else if (type == RoomType.shop) {
    width = 1500.0;
  } else if (type == RoomType.start) {
    width = 1500.0 + rng.nextDouble() * 600; // entrance stays normal-sized
  } else {
    final roll = rng.nextDouble();
    if (roll < 0.45) {
      width = 1500.0 + rng.nextDouble() * 600; // normal
    } else if (roll < 0.68) {
      width = 2500.0 + rng.nextDouble() * 1100; // wide
    } else if (roll < 0.85) {
      width = 1500.0 + rng.nextDouble() * 500; // tall
      tall = true;
    } else {
      width = 2500.0 + rng.nextDouble() * 1100; // huge (wide + tall)
      tall = true;
    }
  }

  const bottom = kGroundY + 320; // world floor (segments extend down to here)

  // ---- terraced ground: natural rolling terrain built from step columns ----
  // Slopes are approximated as short stairs (rise <= kStepUp) so the auto-step
  // in _moveAndCollide lets the player/enemies walk up them smoothly.
  final groundSegments = <Rect>[];
  if (type == RoomType.combat) {
    const terraceStep = 26.0; // < kStepUp so each step is auto-walkable
    const hillTop = kGroundY - 150; // highest the terrain may rise
    const valleyTop = kGroundY + 80; // deepest a dip may sink
    double curTop = kGroundY;
    const startFlat = 340.0; // flat landing zone around the entrance
    groundSegments.add(Rect.fromLTWH(0, curTop, startFlat, bottom - curTop));
    double gx = startFlat;
    while (gx < width) {
      // flat plateau
      final plateauW = 140 + rng.nextDouble() * 260;
      final endP = min(gx + plateauW, width);
      groundSegments.add(Rect.fromLTWH(gx, curTop, endP - gx, bottom - curTop));
      gx = endP;
      if (gx >= width) break;
      // a stairway transition up or down to the next plateau height
      final dir = rng.nextBool() ? -1.0 : 1.0;
      final steps = 1 + rng.nextInt(3);
      for (int s = 0; s < steps && gx < width; s++) {
        final nt = (curTop + dir * terraceStep).clamp(hillTop, valleyTop);
        if (nt == curTop) break; // reached a height limit
        curTop = nt;
        final stairW = 30 + rng.nextDouble() * 28;
        final endS = min(gx + stairW, width);
        groundSegments.add(Rect.fromLTWH(gx, curTop, endS - gx, bottom - curTop));
        gx = endS;
      }
    }
    if (gx < width) {
      groundSegments.add(Rect.fromLTWH(gx, curTop, width - gx, bottom - curTop));
    }
  } else {
    groundSegments.add(Rect.fromLTWH(0, kGroundY, width, bottom - kGroundY));
  }

  // terrain height (top Y) at a world x — used to anchor placed objects
  double groundTopAt(double qx) {
    for (final s in groundSegments) {
      if (qx >= s.left && qx < s.right) return s.top;
    }
    return kGroundY;
  }

  // overall bounding ground rect (back-compat / fall-back fill)
  double minTop = kGroundY;
  for (final s in groundSegments) {
    if (s.top < minTop) minTop = s.top;
  }
  final ground = Rect.fromLTWH(0, minTop, width, bottom - minTop);
  final solids = <Rect>[
    ...groundSegments,
    Rect.fromLTWH(-60, -600, 60, 1600),
    Rect.fromLTWH(width, -600, 60, 1600),
  ];

  // one-way floating platforms (reachable staircases), floating above terrain.
  // Tall rooms stack many climbable layers reaching high up.
  final platforms = <Rect>[];
  final surfaces = <Rect>[ground];
  if (type != RoomType.boss) {
    final maxLayers = tall ? 6 : 2;
    final topLimit = tall ? -260.0 - rng.nextDouble() * 200 : 130.0;
    double x = 320;
    while (x < width - 360) {
      if (rng.nextDouble() < 0.72) {
        double curY = groundTopAt(x);
        double lx = x;
        final layers = tall ? (3 + rng.nextInt(maxLayers - 2)) : (1 + (rng.nextDouble() < 0.45 ? 1 : 0));
        for (int L = 0; L < layers; L++) {
          final pw = L == 0 ? 120 + rng.nextDouble() * 120 : 90 + rng.nextDouble() * 80;
          final rise = L == 0 ? 90 + rng.nextDouble() * 55 : 100 + rng.nextDouble() * 45;
          final ny = curY - rise;
          if (ny < topLimit) break; // don't build past the room's headroom
          lx = (lx + (L == 0 ? 0 : rng.nextDouble() * 70 - 12))
              .clamp(40.0, width - pw - 40);
          final p = Rect.fromLTWH(lx, ny, pw, 20);
          platforms.add(p);
          surfaces.add(p);
          curY = ny;
        }
      }
      x += 250 + rng.nextDouble() * 210;
    }
  }

  // how far up the camera may scroll: derived from the highest platform so a
  // tall room reveals its upper reaches (normal rooms stay ground-locked).
  double highestTop = kGroundY;
  for (final p in platforms) {
    if (p.top < highestTop) highestTop = p.top;
  }
  final camMinY = min(0.0, highestTop - 110);

  // shop items first, so doors can be kept clear of them (prevents buying an
  // item and accidentally stepping into a portal placed on top of it).
  final shop = <ShopItem>[];
  if (type == RoomType.shop) {
    final defs = _shopDefs(rng);
    for (int i = 0; i < defs.length; i++) {
      final px = width * 0.42 + (i - (defs.length - 1) / 2) * 230;
      shop.add(ShopItem(defs[i].$1, defs[i].$2, defs[i].$3,
          Rect.fromLTWH(px - 32, kGroundY - 56, 64, 56)));
    }
  }
  final shopXs = [for (final s in shop) s.pedestal.center.dx];
  bool clearOfShops(double x) => shopXs.every((sx) => (sx - x).abs() > 150);

  // doors — spread across the room (ground ends + platform tops),
  // kept away from the start point so the player has to traverse the room.
  // In shop rooms doors hug the far right, clear of the merchandise.
  final doors = <Door>[];
  if (type != RoomType.boss) {
    final dn = node.next.length;
    final isShop = type == RoomType.shop;
    // candidate anchors: (centerX, bottomY of the door)
    final cands = <Offset>[];
    final fxStart = isShop ? 0.84 : 0.5;
    for (double fx = fxStart; fx <= 0.94; fx += 0.05) {
      final x = width * fx;
      if (isShop && !clearOfShops(x)) continue;
      cands.add(Offset(x, groundTopAt(x))); // ground spots (follow terrain)
    }
    for (final p in platforms) {
      if (p.center.dx > width * 0.42 &&
          p.width > 90 &&
          (!isShop || clearOfShops(p.center.dx))) {
        cands.add(Offset(p.center.dx, p.top)); // reachable elevated spots
      }
    }
    cands.shuffle(rng);
    // pick dn anchors that are spread apart horizontally
    final chosen = <Offset>[];
    for (final c in cands) {
      if (chosen.length >= dn) break;
      if (chosen.every((o) => (o.dx - c.dx).abs() > 180)) chosen.add(c);
    }
    int fi = 0;
    while (chosen.length < dn) {
      final fx = isShop ? (0.94 - 0.08 * fi) : (0.6 + 0.12 * fi);
      final dx = (width * fx).clamp(0.0, width - 80);
      chosen.add(Offset(dx, groundTopAt(dx)));
      fi++;
    }
    for (int i = 0; i < dn; i++) {
      final t = g.byId(node.next[i]);
      final a = chosen[i];
      doors.add(Door(
          Rect.fromLTWH(a.dx - 35, a.dy - 120, 70, 120), t.id, t.type));
    }
  }

  // keep bushes/traps clear of door positions
  final doorXs = [for (final d in doors) d.rect.center.dx];
  bool clearOfDoors(double x) =>
      doorXs.every((dx) => (dx - x).abs() > 110);

  // enemy spawns from the biome pool
  final spawns = <SpawnInfo>[];
  if (type == RoomType.combat) {
    final cnt = min(3 + floor ~/ 2 + rng.nextInt(3), 6);
    for (int i = 0; i < cnt; i++) {
      var kind = biome.pool[rng.nextInt(biome.pool.length)];
      // B3: dedicated fire casters (burn) only emerge from floor 6+, and more
      // often the deeper you go — shallow floors stay free of status mobs.
      if (floor >= 6 &&
          _fireBiome(g.biome) &&
          rng.nextDouble() < 0.12 + floor * 0.015) {
        kind = EnemyKind.fireMage;
      }
      // assassins prowl human strongholds from floor 3+
      if (floor >= 3 && _humanBiome(g.biome) && rng.nextDouble() < 0.18) {
        kind = EnemyKind.assassin;
      }
      // thieves haunt human strongholds at any depth
      if (_humanBiome(g.biome) && rng.nextDouble() < 0.12) {
        kind = EnemyKind.thief;
      }
      // heretics emerge in cursed/dark biomes from floor 6+
      if (floor >= 6 && _darkBiome(g.biome) && rng.nextDouble() < 0.14) {
        kind = EnemyKind.heretic;
      }
      // armored infantry guard royal strongholds (keep/kingdom)
      if (floor >= 2 &&
          (g.biome == Biome.keep || g.biome == Biome.kingdom) &&
          rng.nextDouble() < 0.2) {
        kind = EnemyKind.knightSoldier;
      }
      // bare-fisted thugs brawl in rough camps
      if ((g.biome == Biome.goblinCamp ||
              g.biome == Biome.bloodRiver ||
              g.biome == Biome.ruins) &&
          rng.nextDouble() < 0.16) {
        kind = EnemyKind.brawler;
      }
      // gargoyles perch in stone halls and caverns
      if ((g.biome == Biome.cave ||
              g.biome == Biome.ruins ||
              g.biome == Biome.keep ||
              g.biome == Biome.kingdom ||
              g.biome == Biome.crystalMine) &&
          rng.nextDouble() < 0.12) {
        kind = EnemyKind.gargoyle;
      }
      // ghouls claw out of cursed grounds from floor 4+
      if (floor >= 4 && _darkBiome(g.biome) && rng.nextDouble() < 0.16) {
        kind = EnemyKind.ghoul;
      }
      double sx, sy;
      if (kind == EnemyKind.bat) {
        sx = 320 + rng.nextDouble() * (width - 640);
        // bats roam higher in tall rooms
        sy = kGroundY - (150 + rng.nextDouble() * (tall ? 460 : 170));
      } else if (platforms.isNotEmpty && rng.nextBool()) {
        final s = platforms[rng.nextInt(platforms.length)];
        sx = s.left + rng.nextDouble() * max(20.0, s.width - 30);
        sy = s.top;
      } else {
        sx = 300 + rng.nextDouble() * max(120.0, width - 420);
        sy = groundTopAt(sx); // follow the terraced ground
      }
      if (sx < 300) sx = 300 + rng.nextDouble() * 160;
      spawns.add(SpawnInfo(kind, sx, sy));
    }
  }

  // treasure chest: rare in combat rooms (boss rooms get one on kill).
  // anchored to the terrain so it never floats or sinks into a slope/step.
  Chest? chest;
  if (type == RoomType.combat && rng.nextDouble() < 0.08) {
    final cx = width * (0.4 + rng.nextDouble() * 0.2);
    chest = Chest(cx, groundY: groundTopAt(cx));
  }

  // hideable bushes on the ground (not in boss rooms)
  final bushes = <Bush>[];
  if (type == RoomType.combat || type == RoomType.start) {
    final bn = 1 + rng.nextInt(3);
    for (int i = 0; i < bn; i++) {
      double bx = 0;
      for (int tryN = 0; tryN < 6; tryN++) {
        bx = width * (0.3 + rng.nextDouble() * 0.6);
        if (clearOfDoors(bx)) break;
        bx = -1;
      }
      if (bx < 0) continue; // couldn't find a spot away from doors
      final by = groundTopAt(bx);
      bushes.add(Bush(Rect.fromLTWH(bx - 45, by - 46, 90, 46)));
    }
  }

  // environmental hazards (combat rooms only) — biome-themed mix
  final traps = <Trap>[];
  if (type == RoomType.combat) {
    final List<String> trapPool;
    switch (g.biome) {
      case Biome.volcano:
      case Biome.magma:
      case Biome.dragonLair:
        trapPool = ['flame', 'flame', 'spike', 'arrow']; // fire vents
        break;
      case Biome.cave:
      case Biome.crystalMine:
      case Biome.dwarfMine:
        trapPool = ['saw', 'saw', 'spike', 'arrow']; // mining blades
        break;
      case Biome.keep:
      case Biome.kingdom:
        trapPool = ['arrow', 'arrow', 'spike', 'saw']; // fortress traps
        break;
      default:
        trapPool = ['spike', 'saw', 'arrow'];
    }
    final tn = rng.nextInt(3); // 0..2
    for (int i = 0; i < tn; i++) {
      final tx = width * (0.35 + rng.nextDouble() * 0.5);
      if (!clearOfDoors(tx)) continue; // never place a trap on a door
      final ty = groundTopAt(tx);
      final kind = trapPool[rng.nextInt(trapPool.length)];
      if (kind == 'spike') {
        traps.add(Trap('spike', tx - 32, ty - 18, 64, 18));
      } else if (kind == 'saw') {
        final span = 120 + rng.nextDouble() * 160;
        traps.add(Trap('saw', tx, ty - 22, 34, 22,
            minX: (tx - span).clamp(40.0, width - 80),
            maxX: (tx + span).clamp(80.0, width - 50)));
      } else if (kind == 'flame') {
        traps.add(Trap('flame', tx - 18, ty - 12, 36, 12));
      } else {
        traps.add(Trap('arrow', tx - 11, ty - 150, 22, 30));
      }
    }
  }

  final props = <RoomProp>[];
  if (type != RoomType.boss) {
    final usedX = <double>[];
    final List<String> propKinds;
    switch (g.biome) {
      case Biome.forest:
        propKinds = ['crate', 'torch', 'mushroom', 'pillar', 'root', 'banner'];
        break;
      case Biome.cave:
        propKinds = ['stone', 'stalactite', 'pillar', 'torch', 'skull', 'root'];
        break;
      case Biome.ruins:
        propKinds = ['barrel', 'banner', 'sign', 'pillar', 'rune', 'torch'];
        break;
      case Biome.volcano:
        propKinds = ['stone', 'torch', 'rune', 'sign', 'pillar'];
        break;
      case Biome.abyss:
        propKinds = ['skull', 'rune', 'pillar', 'torch', 'stone'];
        break;
      case Biome.keep:
        propKinds = ['banner', 'crate', 'pillar', 'torch', 'sign'];
        break;
      case Biome.kingdom:
        propKinds = ['banner', 'sign', 'pillar', 'crate', 'torch'];
        break;
      case Biome.goblinCamp:
        propKinds = ['skull', 'root', 'crate', 'torch', 'mushroom'];
        break;
      case Biome.dragonLair:
        propKinds = ['stone', 'rune', 'pillar', 'sign', 'torch'];
        break;
      case Biome.dwarfMine:
        propKinds = ['barrel', 'stone', 'pillar', 'torch', 'sign'];
        break;
      case Biome.crystalMine:
        propKinds = ['rune', 'stone', 'crystal', 'pillar', 'torch'];
        break;
      case Biome.magma:
        propKinds = ['stone', 'rune', 'torch', 'pillar'];
        break;
      case Biome.bearCave:
        propKinds = ['root', 'stone', 'skull', 'pillar'];
        break;
      case Biome.darkForest:
        propKinds = ['mushroom', 'root', 'banner', 'torch'];
        break;
      case Biome.silentJungle:
        propKinds = ['mushroom', 'root', 'banner', 'rune'];
        break;
      case Biome.bloodRiver:
        propKinds = ['skull', 'rune', 'stone', 'sign'];
        break;
      default:
        propKinds = ['crate', 'torch', 'pillar'];
    }
    final propCount = 2 + rng.nextInt(4);
    for (int i = 0; i < propCount; i++) {
      double px = -1;
      for (int attempt = 0; attempt < 6; attempt++) {
        px = width * (0.2 + rng.nextDouble() * 0.55);
        if (!clearOfDoors(px)) continue;
        if (usedX.any((x) => (x - px).abs() < 150)) continue;
        break;
      }
      if (px < 0) continue;
      usedX.add(px);
      // props sit on the ground at their x (follows the terraced terrain)
      final anchorY = groundTopAt(px) - 8;
      final kind = propKinds[rng.nextInt(propKinds.length)];
      Color color;
      double w0, h0;
      switch (kind) {
        case 'crate':
          color = const Color(0xFF8D6E63);
          w0 = 56;
          h0 = 44;
          break;
        case 'barrel':
          color = const Color(0xFF6D4C41);
          w0 = 42;
          h0 = 48;
          break;
        case 'torch':
          color = const Color(0xFFFFAB40);
          w0 = 22;
          h0 = 60;
          break;
        case 'skull':
          color = const Color(0xFFECEFF1);
          w0 = 34;
          h0 = 34;
          break;
        case 'mushroom':
          color = biome.accent;
          w0 = 34;
          h0 = 40;
          break;
        case 'stone':
          color = biome.hill;
          w0 = 44;
          h0 = 52;
          break;
        case 'banner':
          color = biome.accent;
          w0 = 44;
          h0 = 56;
          break;
        case 'pillar':
          color = biome.ground;
          w0 = 30;
          h0 = 60;
          break;
        case 'root':
          color = const Color(0xFF4E342E);
          w0 = 32;
          h0 = 62;
          break;
        case 'stalactite':
          color = const Color(0xFFB0BEC5);
          w0 = 24;
          h0 = 46;
          break;
        case 'rune':
          color = biome.accent;
          w0 = 32;
          h0 = 32;
          break;
        case 'crystal':
          color = biome.accent;
          w0 = 28;
          h0 = 48;
          break;
        case 'sign':
        default:
          color = const Color(0xFF6D4C41);
          w0 = 36;
          h0 = 44;
          break;
      }
      final rect = Rect.fromLTWH(px - w0 / 2, anchorY - h0, w0, h0);
      props.add(RoomProp(kind, rect, color));
    }
  }

  final boss = type == RoomType.boss
      ? pickBoss(floor, rng, usedBosses, g.biome)
      : null;
  if (boss != null) usedBosses?.add(boss.name);
  return RoomData(type, width, ground, platforms, solids, spawns, doors, shop,
      boss, chest, bushes, traps, props,
      groundSegments: groundSegments, camMinY: camMinY);
}

List<(String, String, int)> _shopDefs(Random rng) {
  final pool = <(String, String, int)>[
    ('체력 회복 +50', 'heal', 14),
    ('최대 체력 +25', 'maxhp', 28),
    ('공격력 +25%', 'atk', 34),
    ('보호막 (20초)', 'shieldbuff', 24),
    ('재생 물약 (15초)', 'regenbuff', 22),
    ('신속 물약 (18초)', 'hastebuff', 22),
    ('격노 물약 (15초)', 'atkupbuff', 26),
    ('흡혈 부적 (영구)', 'lifesteal', 42),
  ];
  pool.shuffle(rng);
  return pool.take(3).toList();
}

// ---- difficulty-tiered boss pools (humanoids + monsters) ----
const _tier0 = <BossSpec>[
  BossSpec('멧돼지 왕', BossArchetype.boarSmash, BossShape.beast,
      Color(0xFF8D6E63), 330, 185, visual: 'boar'),
  BossSpec('고블린 족장', BossArchetype.guardian, BossShape.humanoid,
      Color(0xFF9B5DE5), 300, 130, visual: 'goblin'),
  BossSpec('거대 독수리', BossArchetype.jumper, BossShape.bird,
      Color(0xFF90A4AE), 300, 120, visual: 'eagle'),
  BossSpec('대형 붉은 곰', BossArchetype.boarSmash, BossShape.beast,
      Color(0xFFB71C1C), 380, 175, visual: 'redBear'),
  BossSpec('폭탄 사과나무', BossArchetype.caster, BossShape.humanoid,
      Color(0xFF6D4C41), 340, 40, visual: 'appleTree'),
];
const _tier1 = <BossSpec>[
  BossSpec('바위 골렘', BossArchetype.jumper, BossShape.golem,
      Color(0xFF8D6E63), 520, 110, visual: 'golem'),
  BossSpec('숲의 마녀', BossArchetype.caster, BossShape.humanoid,
      Color(0xFF00B4D8), 440, 70, visual: 'witch'),
  BossSpec('용병단장', BossArchetype.flurry, BossShape.humanoid,
      Color(0xFFFFB300), 500, 120, visual: 'mercenary'),
  BossSpec('암석괴인', BossArchetype.jumper, BossShape.golem,
      Color(0xFF757575), 580, 100, visual: 'rockBrute'),
  BossSpec('미이라', BossArchetype.flurry, BossShape.humanoid,
      Color(0xFFCDBE9A), 500, 95, visual: 'mummy'),
  BossSpec('그레이트 웜', BossArchetype.jumper, BossShape.beast,
      Color(0xFF8E6E53), 600, 90, visual: 'worm'),
  BossSpec('용인족 전사', BossArchetype.charger, BossShape.humanoid,
      Color(0xFF2E7D32), 580, 130, visual: 'dragonkin'),
];
const _tier2 = <BossSpec>[
  BossSpec('데스 나이트', BossArchetype.iaido, BossShape.humanoid,
      Color(0xFFEF476F), 660, 150, visual: 'knight'),
  BossSpec('도적 대장', BossArchetype.flurry, BossShape.humanoid,
      Color(0xFF26A69A), 600, 165, visual: 'bandit'),
  BossSpec('마왕', BossArchetype.caster, BossShape.humanoid,
      Color(0xFFB5179E), 760, 90, visual: 'demonKing'),
  BossSpec('도플갱어', BossArchetype.iaido, BossShape.humanoid,
      Color(0xFF455A64), 680, 160, visual: 'doppel'),
  BossSpec('늑대왕', BossArchetype.charger, BossShape.beast,
      Color(0xFF5C6BC0), 700, 175, visual: 'wolfKing'),
  BossSpec('거미 여제', BossArchetype.caster, BossShape.beast,
      Color(0xFF6A1B9A), 700, 120, visual: 'spider'),
  BossSpec('드래곤', BossArchetype.jumper, BossShape.beast,
      Color(0xFFD32F2F), 800, 135, visual: 'dragon'),
];

// thematic boss visuals preferred per biome (used when one is available in the
// floor's difficulty tier and not yet seen this session)
const Map<Biome, List<String>> _biomeBoss = {
  Biome.forest: ['boar', 'witch', 'eagle', 'appleTree'],
  Biome.darkForest: ['witch', 'boar', 'wolfKing', 'appleTree'],
  Biome.silentJungle: ['eagle', 'witch', 'worm', 'appleTree', 'spider', 'dragonkin'],
  Biome.cave: ['golem', 'goblin', 'rockBrute', 'worm', 'spider'],
  Biome.crystalMine: ['golem', 'witch', 'rockBrute', 'spider'],
  Biome.dwarfMine: ['golem', 'goblin', 'rockBrute', 'worm'],
  Biome.goblinCamp: ['goblin', 'bandit'],
  Biome.ruins: ['demonKing', 'bandit', 'mummy'],
  Biome.volcano: ['demonKing', 'golem', 'rockBrute', 'dragon', 'dragonkin'],
  Biome.magma: ['demonKing', 'rockBrute', 'dragon'],
  Biome.dragonLair: ['dragon', 'dragonkin', 'demonKing', 'eagle', 'worm'],
  Biome.bearCave: ['boar', 'golem', 'redBear', 'wolfKing'],
  Biome.keep: ['knight', 'mercenary', 'doppel', 'mummy'],
  Biome.kingdom: ['knight', 'bandit', 'doppel'],
  Biome.abyss: ['demonKing', 'knight', 'doppel', 'worm', 'spider'],
  Biome.bloodRiver: ['bandit', 'demonKing', 'wolfKing'],
};

// cursed/dark biomes where heretic cultists belong (C1)
bool _darkBiome(Biome b) =>
    b == Biome.darkForest ||
    b == Biome.abyss ||
    b == Biome.ruins ||
    b == Biome.bloodRiver ||
    b == Biome.silentJungle;

// human strongholds where assassin-type humanoids belong (C1)
bool _humanBiome(Biome b) =>
    b == Biome.keep ||
    b == Biome.kingdom ||
    b == Biome.ruins ||
    b == Biome.abyss ||
    b == Biome.goblinCamp ||
    b == Biome.bloodRiver;

// fire-themed biomes where burning fire-casters belong (B2/B3)
bool _fireBiome(Biome b) =>
    b == Biome.volcano || b == Biome.magma || b == Biome.dragonLair;

BossSpec pickBoss(int floor, Random rng, [Set<String>? used, Biome? biome]) {
  // 20-stage curve: early (1-7) → mid (8-13) → late/final (14-20)
  final tier = floor <= 7 ? _tier0 : (floor <= 13 ? _tier1 : _tier2);
  final seen = used ?? <String>{};
  // a boss never repeats within a run: take only ones not yet seen this run
  var fresh = tier.where((b) => !seen.contains(b.name)).toList();
  // if this tier is exhausted, borrow unused bosses from the other tiers
  if (fresh.isEmpty) {
    fresh = [..._tier0, ..._tier1, ..._tier2]
        .where((b) => !seen.contains(b.name))
        .toList();
  }
  // absolute last resort (every boss already seen this run): reuse the tier
  final pool = fresh.isNotEmpty ? fresh : tier;
  // within the unused pool, prefer ones matching the biome's theme
  if (biome != null) {
    final pref = _biomeBoss[biome] ?? const [];
    final themed = pool.where((b) => pref.contains(b.visual)).toList();
    if (themed.isNotEmpty) return themed[rng.nextInt(themed.length)];
  }
  return pool[rng.nextInt(pool.length)];
}
