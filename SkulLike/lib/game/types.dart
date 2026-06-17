import 'package:flutter/material.dart';

// ---------------- world constants ----------------
const double kViewW = 1280;
const double kViewH = 720;
// world render zoom: >1 shows less of the map (closer view). HUD is unaffected.
const double kZoom = 1.4;
// pixel-art downsample factor: the world is rendered to a low-res framebuffer
// (kViewW/kPixelScale × kViewH/kPixelScale) then upscaled nearest-neighbor, so
// everything reads as chunky pixel art. Higher = chunkier (and blurrier — it
// throws away sprite detail). 1.0 = native crisp; 1.0–1.5 keeps a clean
// pixel-art read without mushing the sprites.
const double kPixelScale = 1.0;
const double kGroundY = 600; // top surface of the ground
const double kGravity = 2600;
const double kPlayerSpeed = 330;
const double kJumpVel = 880;
// Max reachable jump height = kJumpVel^2 / (2*kGravity) ~= 149px.
const double kStepRise = 125;
const double kDashSpeed = 760;
const double kDashTime = 0.22;

// ---------------- enums ----------------
enum EnemyKind { grunt, bat, mage, slime, archer, brute, goblin, dwarf, darkElf, plant, hammer, shield, fireMage, assassin, heretic, thief, knightSoldier, brawler, gargoyle, ghoul }
enum BossArchetype { charger, caster, jumper, boarSmash, iaido, flurry, guardian }
enum BossShape { humanoid, beast, golem, bird }
enum GamePhase { playing, gameover, victory }
enum BossState { idle, windup, active, recover }
enum RoomType { start, combat, shop, boss }
enum Biome { forest, cave, ruins, volcano, abyss, keep, kingdom, goblinCamp, dragonLair, dwarfMine, crystalMine, magma, bearCave, darkForest, silentJungle, bloodRiver }
enum SkullType {
  // original 8
  basic, beast, mage, rogue, berserker, knight, bomber, wraith,
  // common
  ronin, squire, brawler, hound, sprinter, footman, slinger, apprentice,
  imp, cutpurse, militia, scout, jester, miner, fisher, farmhand,
  drummer, torchbearer, vagrant, novice,
  // rare
  duelist, lancer, gunner, frostmage, pyromancer, ranger, ninja, monk,
  templar, corsair, warden, alchemist, conjurer, valkyrie, shaman, trapper,
  // epic
  warlord, archmage, dragoon, reaper, paladin, nightblade, stormcaller,
  ravager, spectreKnight, plagueDoctor,
  // legendary
  voidlord, seraph, lich, swordsaint,
  // sniper (epic): very long range, slow cadence, heavy single shots
  sniper,
}
enum SkullTier { common, rare, epic, legendary }
enum TownUI { none, blacksmith, depart, traits }
// debuffs: poison/burn/infect (DoT), slow, weaken (-atk) · buffs: regen, shield, haste, atkUp
// infect (전염) = plague-doctor contagion: damages its host AND spreads to nearby foes.
// bind (속박) = lich root: freezes the target in place (acts like a longer stun).
enum StatusKind { poison, burn, slow, weaken, regen, shield, haste, atkUp, bleed, stun, infect, bind }

/// UI/effect color for each status (used by HUD pills and in-world overlays).
Color statusColor(StatusKind k) {
  switch (k) {
    case StatusKind.poison:
      return const Color(0xFF8BC34A);
    case StatusKind.burn:
      return const Color(0xFFFF7043);
    case StatusKind.slow:
      return const Color(0xFF90CAF9);
    case StatusKind.weaken:
      return const Color(0xFFB0BEC5);
    case StatusKind.regen:
      return const Color(0xFF66BB6A);
    case StatusKind.shield:
      return const Color(0xFF4FC3F7);
    case StatusKind.haste:
      return const Color(0xFFFFD54F);
    case StatusKind.atkUp:
      return const Color(0xFFEF5350);
    case StatusKind.bleed:
      return const Color(0xFFD32F2F);
    case StatusKind.stun:
      return const Color(0xFFFFEE58);
    case StatusKind.infect:
      return const Color(0xFF76FF03);
    case StatusKind.bind:
      return const Color(0xFF7E57C2);
  }
}

// ---------------- simple data ----------------
class Particle {
  double x, y, vx, vy, life, maxLife, size;
  Color color;
  double grav;
  Particle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color,
      {this.grav = 1400})
      : maxLife = life;
}

/// Transient skill-cast flourish drawn by the painter so each skill reads
/// distinctly (expanding rings, magic circles, afterimages, ground cracks…).
class SkillFx {
  final String kind; // ring|dualring|runes|ghost|crack|claw|slashArc|lightning
  final double x, y;
  final double x2, y2; // second endpoint (lightning bolts)
  double t = 0; // elapsed seconds
  final double maxT;
  final double dir; // facing for directional fx
  final double size; // base radius / reach
  final Color color;
  SkillFx(this.kind, this.x, this.y, this.maxT, this.color,
      {this.dir = 1, this.size = 80, double? x2, double? y2})
      : x2 = x2 ?? x,
        y2 = y2 ?? y;
  double get prog => (t / maxT).clamp(0.0, 1.0);
}

class Projectile {
  double x, y, vx, vy, r, life, dmg;
  bool fromBoss; // true = hurts player, false = hurts enemies
  Color color;
  String shape; // ball|arrow|orb|icicle|potion|bomb|net — painter look
  double grav; // >0 = arcing thrown projectile (potions, bombs, nets)
  // optional status inflicted on the entity this projectile strikes
  final StatusKind? onHit;
  final double onHitDur;
  final double onHitPow;
  // piercing projectiles pass through enemies, damaging each only once.
  // [hits] tracks already-struck targets (stored as Object to avoid importing
  // Entity here and creating a circular dependency).
  final bool pierce;
  final Set<Object> hits = {};
  // splash > 0 makes the projectile burst in a small radius on contact (mage
  // basic orbs), dealing 60% of [dmg] to everything caught in the blast.
  final double splash;
  Projectile(this.x, this.y, this.vx, this.vy, this.r, this.life, this.dmg,
      this.fromBoss, this.color,
      {this.shape = 'ball',
      this.grav = 0,
      this.onHit,
      this.onHitDur = 0,
      this.onHitPow = 0,
      this.pierce = false,
      this.splash = 0});
}

class SpawnInfo {
  final EnemyKind kind;
  final double x, y;
  SpawnInfo(this.kind, this.x, this.y);
}

/// An active buff/debuff with remaining [timer] (s) and a [power] magnitude
/// (DoT damage/sec, heal/sec, or just a marker for slow/weaken/etc.).
class Status {
  final StatusKind kind;
  double timer;
  double power;
  Status(this.kind, this.timer, this.power);
}

class BossSpec {
  final String name;
  final BossArchetype archetype;
  final BossShape shape;
  final Color color;
  final double maxHp;
  final double walkSpeed;
  // identity-specific look key for painter (boar/goblin/eagle/golem/witch/
  // mercenary/knight/bandit/demonKing). Falls back to [shape] when empty.
  final String visual;
  const BossSpec(this.name, this.archetype, this.shape, this.color, this.maxHp,
      this.walkSpeed, {this.visual = ''});
}

class Door {
  final Rect rect;
  final int target;
  final RoomType targetType;
  Door(this.rect, this.target, this.targetType);
}

class ShopItem {
  final String name;
  final String kind; // heal | maxhp | atk
  final int cost;
  final Rect pedestal;
  bool bought;
  ShopItem(this.name, this.kind, this.cost, this.pedestal,
      {this.bought = false});
}

class RoomProp {
  final String kind;
  final Rect rect;
  final Color color;
  RoomProp(this.kind, this.rect, this.color);
}

/// A treasure chest that, when opened, offers a random skull.
class Chest {
  final double x; // center on the ground
  final double groundY; // terrain top under the chest (rests on it)
  bool opened;
  double t = 0;
  Chest(this.x, {this.opened = false, this.groundY = kGroundY});
  Rect get rect => Rect.fromLTWH(x - 28, groundY - 38, 56, 38);
}

/// A skull lying on the ground that the player can pick up into a slot.
/// Created by opening a chest, or when a slotted skull is displaced.
class SkullDrop {
  final SkullType type;
  final double x; // center on the ground
  bool near = false;
  SkullDrop(this.type, this.x);
}

/// A bush the player can hide in to break enemy line-of-sight.
class Bush {
  final Rect rect;
  Bush(this.rect);
}

/// An environmental hazard. kind: 'spike' (static), 'saw' (patrols),
/// 'arrow' (periodically shoots toward the player).
class Trap {
  final String kind;
  double x, y, w, h;
  double t = 0; // fire / animation timer
  int dir = 1;
  double minX, maxX; // saw patrol bounds
  Trap(this.kind, this.x, this.y, this.w, this.h,
      {this.minX = 0, this.maxX = 0});
  Rect get rect => Rect.fromLTWH(x, y, w, h);
}

/// An explosive trap the trapper deploys on the ground. After a short arming
/// delay it detonates (radial blast hurting enemies) when a foe steps on it,
/// or harmlessly despawns once [life] runs out.
class Mine {
  double x, y; // center, resting on the ground
  double arm; // arming delay (s) before it can trigger
  double life; // despawn timer (s)
  bool triggered = false;
  double fuse = 0; // brief delay between trigger and blast (telegraph)
  final double dmg; // blast damage (baked with atkMul at placement)
  Mine(this.x, this.y, {this.dmg = 26, this.arm = 0.35, this.life = 14});
  Rect get rect => Rect.fromLTWH(x - 20, y - 14, 40, 14);
}

class RoomData {
  final RoomType type;
  final double width;
  final Rect ground;
  final List<Rect> platforms; // one-way (pass from below, land on top)
  final List<Rect> solids; // fully solid (ground + walls)
  final List<SpawnInfo> spawns;
  final List<Door> doors;
  final List<ShopItem> shopItems;
  final BossSpec? boss;
  final Chest? chest;
  final List<Bush> bushes;
  final List<Trap> traps;
  final List<RoomProp> props;
  // terraced floor pieces (steps/slopes). Flat rooms use a single segment.
  final List<Rect> groundSegments;
  // how far the camera may scroll up (negative); 0 = ground-locked view
  final double camMinY;
  RoomData(this.type, this.width, this.ground, this.platforms, this.solids,
      this.spawns, this.doors, this.shopItems, this.boss, this.chest,
      this.bushes, this.traps, this.props,
      {this.groundSegments = const [], this.camMinY = 0});
}

/// Max height an entity auto-steps over (stairs/slopes feel walkable).
const double kStepUp = 30;

class RoomNode {
  final int id;
  final int depth;
  final RoomType type;
  final List<int> next;
  bool cleared;
  RoomNode(this.id, this.depth, this.type, this.next, {this.cleared = false});
}

class FloorGraph {
  final List<RoomNode> nodes;
  final int startId;
  final int bossId;
  final int maxDepth;
  final Biome biome; // chosen per floor per run (randomized)
  FloorGraph(this.nodes, this.startId, this.bossId, this.maxDepth,
      {this.biome = Biome.forest});
  RoomNode byId(int id) => nodes.firstWhere((n) => n.id == id);
  List<RoomNode> atDepth(int d) => nodes.where((n) => n.depth == d).toList();
}

// ---------------- biomes ----------------
class BiomeSpec {
  final String name;
  final Color skyTop, skyBottom, hill, ground, platform, accent;
  final List<EnemyKind> pool;
  const BiomeSpec(this.name, this.skyTop, this.skyBottom, this.hill,
      this.ground, this.platform, this.accent, this.pool);
}

const Map<Biome, BiomeSpec> kBiomes = {
  Biome.forest: BiomeSpec(
    '숲',
    Color(0xFF14132B),
    Color(0xFF1B2A1B),
    Color(0xFF18301E),
    Color(0xFF2E4A32),
    Color(0xFF4C7A3A),
    Color(0xFF9CCC65),
    [EnemyKind.grunt, EnemyKind.bat, EnemyKind.slime],
  ),
  Biome.cave: BiomeSpec(
    '동굴',
    Color(0xFF0E0E18),
    Color(0xFF1A1726),
    Color(0xFF20203A),
    Color(0xFF33304A),
    Color(0xFF4A4668),
    Color(0xFF80DEEA),
    [EnemyKind.bat, EnemyKind.slime, EnemyKind.archer],
  ),
  Biome.ruins: BiomeSpec(
    '폐허',
    Color(0xFF1A1622),
    Color(0xFF2A2433),
    Color(0xFF332B40),
    Color(0xFF4A4055),
    Color(0xFF6A5B7A),
    Color(0xFFCE93D8),
    [EnemyKind.grunt, EnemyKind.mage, EnemyKind.archer],
  ),
  Biome.volcano: BiomeSpec(
    '화산',
    Color(0xFF1F0E0E),
    Color(0xFF2E1414),
    Color(0xFF3A1A14),
    Color(0xFF4A241E),
    Color(0xFF7A3A2A),
    Color(0xFFFF7043),
    [EnemyKind.brute, EnemyKind.mage, EnemyKind.bat],
  ),
  Biome.abyss: BiomeSpec(
    '심연',
    Color(0xFF0A0A14),
    Color(0xFF140A1E),
    Color(0xFF1E1430),
    Color(0xFF2A1E40),
    Color(0xFF40305A),
    Color(0xFFB388FF),
    [EnemyKind.brute, EnemyKind.archer, EnemyKind.mage, EnemyKind.grunt],
  ),
  Biome.keep: BiomeSpec(
    '기사단 숙소',
    Color(0xFF141416),
    Color(0xFF212427),
    Color(0xFF30343A),
    Color(0xFF4A4F56),
    Color(0xFF6D6F75),
    Color(0xFFFFD166),
    [EnemyKind.grunt, EnemyKind.archer, EnemyKind.shield, EnemyKind.hammer],
  ),
  Biome.kingdom: BiomeSpec(
    '적대 왕국',
    Color(0xFF17121A),
    Color(0xFF2A2128),
    Color(0xFF3A3138),
    Color(0xFF564E57),
    Color(0xFF7A6E7A),
    Color(0xFFEF9A9A),
    [EnemyKind.grunt, EnemyKind.mage, EnemyKind.shield, EnemyKind.archer],
  ),
  Biome.goblinCamp: BiomeSpec(
    '고블린 부락',
    Color(0xFF15160E),
    Color(0xFF1E2410),
    Color(0xFF273118),
    Color(0xFF334028),
    Color(0xFF576B47),
    Color(0xFF9CCC65),
    [EnemyKind.goblin, EnemyKind.goblin, EnemyKind.bat, EnemyKind.archer],
  ),
  Biome.dragonLair: BiomeSpec(
    '드래곤 레어',
    Color(0xFF160E10),
    Color(0xFF291017),
    Color(0xFF3A2022),
    Color(0xFF4A2A2E),
    Color(0xFF6A3A3E),
    Color(0xFFFF7043),
    [EnemyKind.brute, EnemyKind.hammer, EnemyKind.mage],
  ),
  Biome.dwarfMine: BiomeSpec(
    '드워프 광산',
    Color(0xFF0F1214),
    Color(0xFF161A1C),
    Color(0xFF2A2E30),
    Color(0xFF3E4346),
    Color(0xFF5A6064),
    Color(0xFFFFD166),
    [EnemyKind.dwarf, EnemyKind.dwarf, EnemyKind.hammer, EnemyKind.slime],
  ),
  Biome.crystalMine: BiomeSpec(
    '수정 광산',
    Color(0xFF0A0E14),
    Color(0xFF0F1620),
    Color(0xFF16202A),
    Color(0xFF24323E),
    Color(0xFF355067),
    Color(0xFF80DEEA),
    [EnemyKind.dwarf, EnemyKind.darkElf, EnemyKind.bat],
  ),
  Biome.magma: BiomeSpec(
    '끓는 화산',
    Color(0xFF1A0A08),
    Color(0xFF2B0F0D),
    Color(0xFF3C1711),
    Color(0xFF4E2118),
    Color(0xFF7A2E1F),
    Color(0xFFFF7043),
    [EnemyKind.brute, EnemyKind.hammer, EnemyKind.mage],
  ),
  Biome.bearCave: BiomeSpec(
    '붉은 곰 동굴',
    Color(0xFF110E0B),
    Color(0xFF221913),
    Color(0xFF33221A),
    Color(0xFF4A362C),
    Color(0xFF6D4C41),
    Color(0xFFFF7043),
    [EnemyKind.brute, EnemyKind.grunt, EnemyKind.plant],
  ),
  Biome.darkForest: BiomeSpec(
    '어두운 숲길',
    Color(0xFF07120A),
    Color(0xFF0F1E10),
    Color(0xFF132714),
    Color(0xFF213A26),
    Color(0xFF356B3C),
    Color(0xFF66BB6A),
    [EnemyKind.grunt, EnemyKind.plant, EnemyKind.archer],
  ),
  Biome.silentJungle: BiomeSpec(
    '침묵의 칼날 열대림',
    Color(0xFF0B1312),
    Color(0xFF11201A),
    Color(0xFF163028),
    Color(0xFF234235),
    Color(0xFF3A6A56),
    Color(0xFFB2FF59),
    [EnemyKind.plant, EnemyKind.bat, EnemyKind.darkElf],
  ),
  Biome.bloodRiver: BiomeSpec(
    '핏빛 죽음의 강',
    Color(0xFF1A0707),
    Color(0xFF2B0A0A),
    Color(0xFF3A0F0F),
    Color(0xFF4B1414),
    Color(0xFF6E2323),
    Color(0xFFEF5350),
    [EnemyKind.darkElf, EnemyKind.darkElf, EnemyKind.slime, EnemyKind.hammer],
  ),
};

Biome biomeForFloor(int floor) {
  const order = [
    Biome.forest,
    Biome.cave,
    Biome.ruins,
    Biome.volcano,
    Biome.abyss,
    Biome.keep,
    Biome.kingdom,
    Biome.goblinCamp,
    Biome.dragonLair,
    Biome.dwarfMine,
    Biome.crystalMine,
    Biome.magma,
    Biome.bearCave,
    Biome.darkForest,
    Biome.silentJungle,
    Biome.bloodRiver
  ];
  return order[(floor - 1).clamp(0, order.length - 1)];
}
