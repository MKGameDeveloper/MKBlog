import 'dart:math';
import 'dart:ui';
import 'types.dart';
import 'entities.dart';
import 'level_gen.dart';
import 'skulls.dart';
import 'meta.dart';

class GameWorld {
  final Random rng = Random();
  final MetaState meta;
  final bool town;

  // floor / room graph (run mode)
  late FloorGraph graph;
  int floor = 1;
  final int totalFloors = 20;
  int currentNodeId = 0;
  RoomType roomType = RoomType.start;
  late BiomeSpec biome;

  // active room
  late Player player;
  bool _playerReady = false; // true once the run's player has been created
  List<Enemy> enemies = [];
  List<Ally> allies = []; // temporary summoned skeleton soldiers
  // 치천사 천상의 분노: permanent (this-run) attack stacks gained per kill. Lives
  // on the world, so it persists across rooms but resets when a new run starts.
  int killStacks = 0;
  // 성기사 천공의 대검: a planted sword left in the ground after the skill lands.
  // While [paladinSwordTimer] > 0 it stands; standing near it (paladinSwordBuff)
  // grants a large attack boost (see atkMul).
  double paladinSwordTimer = 0;
  double paladinSwordX = 0;
  double paladinSwordY = 0; // ground point the blade is planted at
  bool paladinSwordBuff = false;
  Rect? shieldCrystal; // C4: while alive, shield knights are near-immune
  double shieldCrystalHp = 0;
  bool _crystalHitSwing = false;
  Boss? boss;
  List<Projectile> projectiles = [];
  List<Particle> particles = [];
  List<SkillFx> skillFx = [];
  Rect ground = Rect.zero;
  List<Rect> groundSegments = []; // terraced floor pieces (for rendering)
  List<Rect> platforms = [];
  List<Rect> solids = [];
  List<Door> doors = [];
  List<ShopItem> shopItems = [];
  List<Bush> bushes = [];
  List<Trap> traps = [];
  List<Mine> mines = []; // trapper-deployed explosive traps (hurt enemies)
  List<StormCloud> storms = []; // stormcaller thunderheads chasing foes
  List<RoomProp> props = [];
  Chest? chest;
  double roomWidth = 0;

  // perception: a recent attack/impact "noise" that nearby enemies hear
  double combatNoise = 0;
  double noiseX = 0, noiseY = 0;
  Rect? exitPortal;
  bool roomCleared = false;
  Offset? enterPrompt;

  // skull pickups lying on the ground (from chests / displaced slots)
  List<SkullDrop> skullDrops = [];
  SkullDrop? activeDrop; // nearest drop the player can interact with

  // town props
  Rect blacksmithRect = Rect.zero;
  Rect traitsRect = Rect.zero;
  Rect graveyardRect = Rect.zero;
  Rect departRect = Rect.zero;
  TownUI uiRequest = TownUI.none;
  String? townPrompt;
  Offset? townPromptPos;
  final int graveyardCost = 40;
  // graveyard pulls used this town visit (reset on entering town).
  int pullsUsed = 0;

  // persistent run stats
  List<SkullSpec> skullSlots = [];
  int activeSlot = 0;
  int gold = 0;
  double shopAtk = 1.0;
  double lifesteal = 0; // run relic: heal a fraction of melee damage dealt
  double maxHp = 100;
  double curHp = 100;
  int runSouls = 0;

  GamePhase phase = GamePhase.playing;
  int kills = 0;

  // input
  bool moveLeft = false, moveRight = false;
  // up/down held state — used for free vertical movement during 용기병 flight
  // (otherwise arrowUp/arrowDown keep their normal jump/interact roles).
  bool moveUp = false, moveDown = false;
  bool _jumpQueued = false,
      _attackQueued = false,
      _interactQueued = false,
      _dodgeQueued = false,
      _skillQueued = false,
      _swapQueued = false,
      _slot1Queued = false,
      _slot2Queued = false;

  // camera / fx
  double camX = 0;
  double camY = 0; // vertical scroll (used by tall rooms)
  double camMinY = 0; // how far up the camera may scroll (<=0)
  double shake = 0;
  double clock = 0;
  double bannerTimer = 0;
  String bannerText = '';
  double _transitionCd = 0;

  GameWorld(this.meta, {this.town = false}) {
    if (town) {
      _enterTown();
    } else {
      _startRun();
    }
  }

  void queueJump() => _jumpQueued = true;
  void queueAttack() => _attackQueued = true;
  void queueInteract() => _interactQueued = true;
  void queueDodge() => _dodgeQueued = true;
  void queueSkill() => _skillQueued = true;
  void queueSwap() => _swapQueued = true;
  void queueSlot1() => _slot1Queued = true;
  void queueSlot2() => _slot2Queued = true;
  void closeUI() => uiRequest = TownUI.none;

  /// Developer mode: instantly equip [t] into the active slot. Works both in
  /// town and mid-run. In town it also becomes the next run's start skull so
  /// the chosen class carries into the adventure.
  void devGiveSkull(SkullType t) {
    final s = skull(t);
    if (skullSlots.isEmpty) {
      skullSlots = [s];
      activeSlot = 0;
    } else {
      activeSlot = activeSlot.clamp(0, skullSlots.length - 1);
      skullSlots[activeSlot] = s;
    }
    player.skulls = List.of(skullSlots);
    player.active = activeSlot;
    player.skillTimer = 0; // new skull's skill is ready immediately
    if (town) {
      meta.preparedSkull = t;
      meta.save();
    }
    _banner('[DEV] ${s.name} 장착', 1.6);
  }

  RoomNode get node => graph.byId(currentNodeId);
  double get atkMul {
    double f = 1;
    if (player.hasStatus(StatusKind.weaken)) f *= 0.7;
    if (player.hasStatus(StatusKind.atkUp)) f *= 1.4;
    if (player.flyTimer > 0) f *= 1.9; // 용기병 비행 중 공격력 대폭 강화
    if (player.auraTimer > 0) f *= 1.4; // 검성 창천의 검기: 위력 상승
    if (paladinSwordBuff) f *= 1.8; // 성기사 천공의 대검 근처: 공격력 대폭 증가
    return player.skull.atkMul *
        shopAtk *
        (1 + meta.bonusAtkMul + meta.atkTraitMul(player.skull.category)) *
        _passiveAtkMul() *
        f;
  }

  // The active skull's signature passive (per-skull, not shared by class).
  PassiveInfo get _passive => passiveOf(player.skull.type);

  // Passive (atkUp / berserk): a steady or scaling attack-power bonus.
  double _passiveAtkMul() {
    final pv = _passive;
    switch (pv.kind) {
      case PassiveKind.atkUp:
        return 1.0 + pv.value;
      case PassiveKind.berserk:
        // the lower the HP, the bigger the bonus (up to pv.value)
        final frac = (player.hp / player.maxHp).clamp(0.0, 1.0);
        return 1.0 + pv.value * (1 - frac);
      case PassiveKind.killStack:
        // 치천사: permanent per-kill attack gain accumulated this run.
        return 1.0 + killStacks * pv.value;
      default:
        return 1.0;
    }
  }

  // Passive (crit): roll a critical hit for this strike. 1.8x on a crit.
  double _critMul() {
    final pv = _passive;
    if (pv.kind == PassiveKind.crit && rng.nextDouble() < pv.value) return 1.8;
    return 1.0;
  }

  // Passive: on-hit effect applied when a player attack lands, driven by the
  // active skull's signature passive (bleed/burn/poison/slow/stun/execute).
  void _playerOnHit(Entity e) {
    final pv = _passive;
    switch (pv.kind) {
      case PassiveKind.bleedHit:
        e.addStatus(StatusKind.bleed, 2.5, pv.value * atkMul);
        break;
      case PassiveKind.burnHit:
        if (rng.nextDouble() < pv.value) {
          e.addStatus(StatusKind.burn, 2.5, 5 * atkMul);
        }
        break;
      case PassiveKind.poisonHit:
        e.addStatus(StatusKind.poison, 3.5, pv.value);
        break;
      case PassiveKind.slowHit:
        e.addStatus(StatusKind.slow, 1.8, 1);
        break;
      case PassiveKind.stunHit:
        if (e is! Boss && rng.nextDouble() < pv.value) {
          e.addStatus(StatusKind.stun, 0.5, 1);
        }
        break;
      case PassiveKind.execute:
        if (e is! Boss && rng.nextDouble() < pv.value) {
          e.damage(99999); // execute — never on bosses
          _fx('runes', e.cx, e.cy, 0.4, const Color(0xFF18FFFF), size: 40);
        }
        break;
      default:
        break;
    }
  }

  void _updateStatuses(Entity e, double dt) {
    if (e.statuses.isEmpty) return;
    for (final s in e.statuses) {
      s.timer -= dt;
      switch (s.kind) {
        case StatusKind.poison:
        case StatusKind.burn:
        case StatusKind.bleed:
        case StatusKind.infect:
          // damage-over-time: poison/burn tick, bleed is a smaller persistent
          // bleed-out, infect (plague) ravages its host. All can be lethal —
          // clamp and mark dead so HP never sinks below 0 while still alive.
          // (Infection also spreads between enemies — see _spreadInfection.)
          e.hp -= s.power * dt;
          if (e.hp <= 0 && !e.dead) {
            e.hp = 0;
            e.dead = true;
          }
          break;
        case StatusKind.stun:
        case StatusKind.bind:
          // while stunned/bound, the entity cannot act; store as hurtTimer
          e.hurtTimer = max(e.hurtTimer, s.timer);
          break;
        case StatusKind.regen:
          e.hp = min(e.maxHp, e.hp + s.power * dt);
          break;
        default:
          break;
      }
    }
    e.statuses.removeWhere((s) => s.timer <= 0);
  }

  // ================================================================
  // TOWN
  // ================================================================
  void _enterTown() {
    floor = 0;
    biome = kBiomes[Biome.ruins]!;
    roomWidth = 2400;
    maxHp = 100 + meta.bonusMaxHp + meta.traitBonusHp;
    curHp = maxHp;
    shopAtk = 1.0;
    pullsUsed = 0;
    skullSlots = [skull(meta.startSkull)];
    activeSlot = 0;
    ground = Rect.fromLTWH(0, kGroundY, roomWidth, 320);
    groundSegments = [ground];
    solids = [
      ground,
      Rect.fromLTWH(-60, -600, 60, 1600),
      Rect.fromLTWH(roomWidth, -600, 60, 1600),
    ];
    platforms = [];
    enemies = [];
    boss = null;
    doors = [];
    shopItems = [];
    bushes = [];
    traps = [];
    mines = [];
    storms = [];
    chest = null;
    exitPortal = null;
    projectiles = [];
    particles = [];
    skillFx = [];
    skullDrops = [];
    activeDrop = null;
    blacksmithRect = Rect.fromLTWH(roomWidth * 0.24 - 40, kGroundY - 92, 80, 92);
    traitsRect = Rect.fromLTWH(roomWidth * 0.36 - 30, kGroundY - 130, 60, 130);
    graveyardRect = Rect.fromLTWH(roomWidth - 250, kGroundY - 120, 150, 120);
    departRect = Rect.fromLTWH(roomWidth * 0.5 - 38, kGroundY - 158, 76, 158);
    player = Player(roomWidth * 0.42, kGroundY - 50, skullSlots[0],
        meta.dodgeCharges, maxHp);
    camX = 0;
    camY = 0;
    camMinY = 0;
    phase = GamePhase.playing;
    _snapCamera();
    _banner('망자의 마을', 1.8);
  }

  void _updateTown(double dt) {
    if (uiRequest != TownUI.none) {
      _clearInput();
      _updateParticles(dt);
      return;
    }
    _updatePlayer(dt);
    _updateProjectiles(dt);
    _updateParticles(dt);
    _handleTownInteract();
    _camera(dt);
    _clearInput();
  }

  void _handleTownInteract() {
    townPrompt = null;
    townPromptPos = null;
    final p = player;
    void prompt(String s) {
      townPrompt = s;
      townPromptPos = Offset(p.cx, p.y - 26);
    }

    if (p.rect.overlaps(departRect.inflate(30))) {
      prompt('E: 모험 시작');
      if (_interactQueued) uiRequest = TownUI.depart;
    } else if (p.rect.overlaps(blacksmithRect.inflate(40))) {
      prompt('E: 대장장이 (강화)');
      if (_interactQueued) uiRequest = TownUI.blacksmith;
    } else if (p.rect.overlaps(traitsRect.inflate(40))) {
      prompt('E: 영혼의 비석 (특성)');
      if (_interactQueued) uiRequest = TownUI.traits;
    } else if (p.rect.overlaps(graveyardRect.inflate(40))) {
      final left = meta.maxPulls - pullsUsed;
      prompt(left > 0
          ? 'E: 무덤에서 해골 깨우기 (영혼 $graveyardCost · 남은 $left회)'
          : '무덤: 이번 방문 뽑기 소진 (다음 방문에 가능)');
      if (_interactQueued) _rollGraveyard();
    }
  }

  void _rollGraveyard() {
    if (pullsUsed >= meta.maxPulls) {
      _banner('이번 마을 방문엔 더 뽑을 수 없다', 1.6);
      return;
    }
    if (meta.souls < graveyardCost) {
      _banner('영혼이 부족하다 ($graveyardCost 필요)', 1.6);
      return;
    }
    // candidate pool = every skull except the default (no permanent unlocks).
    final pool = SkullType.values.where((t) => t != SkullType.basic);
    meta.souls -= graveyardCost;
    pullsUsed++;
    final t = rollSkull(rng, pool, luckMul: meta.luckMul)!;
    meta.preparedSkull = t; // one-time start skull, consumed next run
    meta.save();
    // reflect it immediately on the town avatar
    skullSlots[0] = skull(t);
    player.skulls = List.of(skullSlots);
    player.active = activeSlot.clamp(0, skullSlots.length - 1);
    final s = skull(t);
    _banner('[${tierLabel(s.tier)}] ${s.name}을(를) 깨웠다!  (이번 런 1회성 시작 해골)', 2.6);
    for (int i = 0; i < 26; i++) {
      final a = rng.nextDouble() * pi * 2;
      particles.add(Particle(graveyardRect.center.dx, graveyardRect.top,
          cos(a) * 220, sin(a) * 220 - 80, 0.7, 5, skull(t).eye,
          grav: 300));
    }
  }

  // ================================================================
  // RUN
  // ================================================================
  void _startRun() {
    floor = 1;
    gold = 0;
    meta.usedBosses.clear(); // no boss repeats within a single run
    shopAtk = 1.0;
    lifesteal = 0;
    maxHp = 100 + meta.bonusMaxHp + meta.traitBonusHp;
    curHp = maxHp;
    kills = 0;
    runSouls = 0;
    // consume the one-time prepared skull (basic if none was rolled)
    final startType = meta.takeStartSkull();
    meta.save();
    skullSlots = [skull(startType)];
    activeSlot = 0;
    phase = GamePhase.playing;
    graph = generateFloor(1, rng);
    _enterRoom(graph.startId);
  }

  void _enterRoom(int id) {
    currentNodeId = id;
    final n = graph.byId(id);
    roomType = n.type;
    biome = kBiomes[graph.biome]!;
    final data = buildRoom(n, floor, rng, graph, usedBosses: meta.usedBosses);
    roomWidth = data.width;
    ground = data.ground;
    groundSegments =
        data.groundSegments.isEmpty ? [data.ground] : data.groundSegments;
    camMinY = data.camMinY;
    platforms = data.platforms;
    solids = data.solids;
    doors = data.doors;
    shopItems = data.shopItems;
    bushes = data.bushes;
    traps = data.traps;
    mines = [];
    storms = [];
    chest = data.chest;
    exitPortal = null;
    enterPrompt = null;
    skullDrops = [];
    activeDrop = null;
    projectiles = [];
    particles = [];
    skillFx = [];
    camX = 0;
    camY = 0; // start at ground view; scrolls up as the player climbs
    _transitionCd = 0.3;

    // carry active buffs/debuffs across room transitions (the Player object
    // is recreated each room, so timed statuses must be transferred)
    final carried = _playerReady ? List.of(player.statuses) : <Status>[];
    player = Player(120, kGroundY - 50, skullSlots[activeSlot],
        meta.dodgeCharges, maxHp);
    player.skulls = List.of(skullSlots);
    player.active = activeSlot;
    player.hp = curHp.clamp(1, maxHp);
    player.statuses.addAll(carried);
    _playerReady = true;

    enemies = [for (final s in data.spawns) _scaleEnemy(_makeEnemy(s))];
    // 공허군주의 공허 몬스터는 방을 옮겨도 따라온다 — keep persistent minions and
    // regroup them at the new entrance; ordinary summons are left behind.
    allies = [for (final a in allies) if (a.persistent) a];
    for (final a in allies) {
      a.x = player.x + (rng.nextDouble() * 30 - 15);
      a.y = player.y;
      a.vx = 0;
      a.vy = 0;
      a.facing = player.facing;
    }
    // C4: a shield-crystal empowers shield knights; smash it to drop their guard
    shieldCrystal = null;
    shieldCrystalHp = 0;
    _crystalHitSwing = false;
    if (enemies.any((e) => e.kind == EnemyKind.shield)) {
      final cxp = (roomWidth * 0.72).clamp(360.0, roomWidth - 80.0);
      shieldCrystal = Rect.fromLTWH(cxp - 12, kGroundY - 54, 24, 54);
      shieldCrystalHp = 60 + floor * 4;
    }
    boss = (n.type == RoomType.boss && data.boss != null)
        ? (Boss(data.boss!, (roomWidth * 0.62).clamp(300.0, roomWidth - 240),
            kGroundY - 96)
          ..maxHp *= _floorHpMul
          ..hp = data.boss!.maxHp * _floorHpMul
          ..dr = _floorDr)
        : null;
    props = data.props;

    roomCleared = n.type == RoomType.start || n.type == RoomType.shop;
    if (roomCleared) n.cleared = true;

    switch (n.type) {
      case RoomType.start:
        _banner('$floor층 · ${biome.name}', 1.8);
        break;
      case RoomType.combat:
        _banner('전투의 방', 1.0);
        break;
      case RoomType.shop:
        _banner('상점 (E로 구매)', 1.6);
        break;
      case RoomType.boss:
        _banner('보스 — ${data.boss!.name}', 2.2);
        shake = 0.4;
        break;
    }
    _snapCamera();
  }

  Enemy _makeEnemy(SpawnInfo s) {
    switch (s.kind) {
      case EnemyKind.grunt:
        return Enemy(s.kind, s.x, s.y - 40, 32, 40, 26, rng.nextDouble() * 6)
          ..facing = rng.nextBool() ? 1 : -1;
      case EnemyKind.bat:
        return Enemy(s.kind, s.x, s.y, 32, 24, 16, rng.nextDouble() * 6);
      case EnemyKind.gargoyle:
        // tanky flying stone fiend: hovers, then dive-bombs the player
        return Enemy(s.kind, s.x, s.y - 90, 34, 30, 36, rng.nextDouble() * 6);
      case EnemyKind.ghoul:
        // lurching undead: hopping claw lunge, infects on contact
        return Enemy(s.kind, s.x, s.y - 40, 28, 40, 28, rng.nextDouble() * 6)
          ..facing = rng.nextBool() ? 1 : -1;
      case EnemyKind.mage:
        return Enemy(s.kind, s.x, s.y - 46, 30, 46, 22, rng.nextDouble() * 6);
      case EnemyKind.fireMage:
        // fire caster: lobs burning orbs (the only mob that inflicts burn)
        return Enemy(s.kind, s.x, s.y - 46, 30, 46, 24, rng.nextDouble() * 6)
          ..atkCd = 0.8 + rng.nextDouble();
      case EnemyKind.slime:
        return Enemy(s.kind, s.x, s.y - 26, 36, 26, 20, rng.nextDouble() * 6)
          ..facing = rng.nextBool() ? 1 : -1;
      case EnemyKind.archer:
        return Enemy(s.kind, s.x, s.y - 44, 30, 44, 20, rng.nextDouble() * 6)
          ..atkCd = 0.6 + rng.nextDouble();
      case EnemyKind.brute:
        return Enemy(s.kind, s.x, s.y - 54, 46, 54, 60, rng.nextDouble() * 6)
          ..facing = rng.nextBool() ? 1 : -1;
      case EnemyKind.goblin:
        // small, fast, low-hp melee skirmisher
        return Enemy(s.kind, s.x, s.y - 32, 26, 32, 18, rng.nextDouble() * 6)
          ..facing = rng.nextBool() ? 1 : -1;
      case EnemyKind.assassin:
        // agile humanoid: long dashing lunge, bleeds on contact
        return Enemy(s.kind, s.x, s.y - 42, 26, 42, 24, rng.nextDouble() * 6)
          ..facing = rng.nextBool() ? 1 : -1
          ..atkCd = 0.5 + rng.nextDouble();
      case EnemyKind.heretic:
        // robed cultist: ranged cursed bolts that weaken the player
        return Enemy(s.kind, s.x, s.y - 44, 28, 44, 26, rng.nextDouble() * 6)
          ..atkCd = 0.8 + rng.nextDouble();
      case EnemyKind.thief:
        // fast hit-and-run humanoid that snatches gold
        return Enemy(s.kind, s.x, s.y - 36, 26, 36, 20, rng.nextDouble() * 6)
          ..facing = rng.nextBool() ? 1 : -1
          ..atkCd = 0.4 + rng.nextDouble();
      case EnemyKind.knightSoldier:
        // armored infantry: telegraphed lunging slash, sturdy
        return Enemy(s.kind, s.x, s.y - 46, 30, 46, 44, rng.nextDouble() * 6)
          ..facing = rng.nextBool() ? 1 : -1
          ..atkCd = 0.8 + rng.nextDouble();
      case EnemyKind.brawler:
        // bare-fisted thug: quick forward jabs
        return Enemy(s.kind, s.x, s.y - 40, 28, 40, 32, rng.nextDouble() * 6)
          ..facing = rng.nextBool() ? 1 : -1;
      case EnemyKind.dwarf:
        // stout bruiser, tanky, hits hard with knockback
        return Enemy(s.kind, s.x, s.y - 38, 38, 38, 52, rng.nextDouble() * 6)
          ..facing = rng.nextBool() ? 1 : -1;
      case EnemyKind.darkElf:
        // ranged caster firing cursed bolts that inflict bleed
        return Enemy(s.kind, s.x, s.y - 46, 30, 46, 26, rng.nextDouble() * 6)
          ..atkCd = 0.8 + rng.nextDouble();
      case EnemyKind.plant:
        // ambush trap monster: dormant until the player approaches. Variant is
        // rolled per spawn (more exotic variants appear from deeper floors).
        return Enemy(s.kind, s.x, s.y - 30, 36, 30, 34, rng.nextDouble() * 6)
          ..t2 = 0 // t2 used as the "emerged" flag/timer
          ..plantVariant = floor < 2 ? 0 : rng.nextInt(4);
      case EnemyKind.hammer:
        // slow heavy hitter: ground slam with knockback + stun chance
        return Enemy(s.kind, s.x, s.y - 56, 46, 56, 80, rng.nextDouble() * 6)
          ..facing = rng.nextBool() ? 1 : -1;
      case EnemyKind.shield:
        // sturdy guard: blocks frontal hits while its shield is raised
        return Enemy(s.kind, s.x, s.y - 52, 42, 52, 90, rng.nextDouble() * 6)
          ..facing = rng.nextBool() ? 1 : -1;
    }
  }

  // ================================================================
  void update(double dt) {
    if (dt > 0.05) dt = 0.05;
    clock += dt;
    if (shake > 0) shake -= dt;
    if (bannerTimer > 0) bannerTimer -= dt;
    if (_transitionCd > 0) _transitionCd -= dt;
    if (chest != null) chest!.t += dt;

    if (town) {
      _updateTown(dt);
      return;
    }

    if (phase != GamePhase.playing) {
      _updateParticles(dt);
      _clearInput();
      return;
    }

    _updatePlayer(dt);
    _updateStatuses(player, dt);
    // regenIdle passive: steady self-heal each second
    if (_passive.kind == PassiveKind.regenIdle && !player.dead) {
      player.hp = min(player.maxHp, player.hp + _passive.value * dt);
    }
    curHp = player.hp;
    if (player.dead && phase == GamePhase.playing) {
      phase = GamePhase.gameover;
      _banner('GAME OVER', 999);
    }
    if (combatNoise > 0) combatNoise -= dt;
    player.hidden = !player.attacking &&
        player.dodgeTimer <= 0 &&
        bushes.any((b) => player.rect.overlaps(b.rect));
    for (final e in enemies) {
      _updateEnemyAggro(e, dt);
      _updateEnemy(e, dt);
    }
    if (boss != null) _updateBoss(boss!, dt);
    for (final a in allies) {
      _updateAlly(a, dt);
    }
    allies.removeWhere((a) {
      if (a.life <= 0 || a.dead) {
        _allyPoof(a);
        return true;
      }
      return false;
    });
    _updateProjectiles(dt);
    _updateParticles(dt);
    _updateTraps(dt);
    _updateMines(dt);
    _updateStorms(dt);
    _spreadInfection(dt);
    _resolveCombat();

    final splits = <Enemy>[];
    enemies.removeWhere((e) {
      if (e.dead) {
        // an infected corpse bursts and spreads the plague to nearby foes
        if (e.hasStatus(StatusKind.infect)) {
          _plagueContagion(e.cx, e.cy);
        }
        _deathBurst(e);
        kills++;
        runSouls += 2;
        _awardGold(3 + rng.nextInt(4) + floor);
        // 치천사 천상의 분노: each kill permanently raises this run's attack.
        if (passiveOf(player.skull.type).kind == PassiveKind.killStack) {
          killStacks++;
        }
        // 공허군주: each kill births a weak void monster that fights at your side
        // and follows across rooms. Capped so they can't snowball endlessly.
        if (player.skull.type == SkullType.voidlord &&
            allies.where((a) => a.persistent).length < 5) {
          _spawnVoidMinion(e.cx, e.y);
        }
        // big slimes split into two small, aggressive slimes
        if (e.kind == EnemyKind.slime && e.w >= 34) {
          for (int i = -1; i <= 1; i += 2) {
            splits.add(Enemy(EnemyKind.slime, e.x, e.y - 8, 22, 16, 8,
                rng.nextDouble() * 6)
              ..facing = i
              ..aggro = true
              ..aggroTimer = 3.5
              ..vx = i * 120.0
              ..vy = -260);
          }
        }
        return true;
      }
      return false;
    });
    enemies.addAll(splits);
    if (boss != null && boss!.dead) {
      _deathBurst(boss!);
      _awardGold(25 + floor * 5);
      runSouls += 15;
      if (passiveOf(player.skull.type).kind == PassiveKind.killStack) {
        killStacks++;
      }
      chest ??= Chest(roomWidth * 0.5, groundY: kGroundY); // boss room is flat
      boss = null;
      _banner(floor >= totalFloors ? '최종 보스 처치!' : '포탈이 열렸다 → E로 입장', 2.4);
      exitPortal =
          Rect.fromLTWH(roomWidth * 0.66 - 35, kGroundY - 110, 70, 110);
    }

    if (roomType == RoomType.combat && !roomCleared && enemies.isEmpty) {
      roomCleared = true;
      node.cleared = true;
      _banner('클리어! 문이 열렸다', 1.4);
    }

    _handleTransitions();
    _handleChest();
    _handleShop();
    _camera(dt);
    curHp = player.hp;
    _clearInput();
  }

  void _clearInput() {
    _jumpQueued = _attackQueued = _interactQueued = false;
    _dodgeQueued = _skillQueued = _swapQueued = false;
    _slot1Queued = _slot2Queued = false;
  }

  // ----------------------------------------------------------------
  void _handleChest() {
    final c = chest;
    if (c != null && !c.opened) {
      if (player.rect.overlaps(c.rect.inflate(26))) {
        enterPrompt ??= Offset(player.cx, player.y - 24);
        if (_interactQueued) {
          c.opened = true;
          _interactQueued = false;
          _openChest(c);
        }
      }
    }
    // proximity for every ground skull; pick the nearest as the active one
    SkullDrop? nearest;
    double best = double.infinity;
    for (final d in skullDrops) {
      final dx = (player.cx - d.x).abs();
      final dy = (player.cy - (kGroundY - 60)).abs();
      d.near = dx < 90 && dy < 180;
      if (d.near && dx < best) {
        best = dx;
        nearest = d;
      }
    }
    activeDrop = nearest;
    if (activeDrop != null) {
      if (_slot1Queued) _equipSlot(0);
      if (_slot2Queued) _equipSlot(1);
    }
  }

  void _openChest(Chest c) {
    final equipped = skullSlots.map((s) => s.type).toSet();
    final onGround = skullDrops.map((d) => d.type).toSet();
    final avail = SkullType.values
        .where((t) => !equipped.contains(t) && !onGround.contains(t));
    shake = max(shake, 0.2);
    for (int i = 0; i < 22; i++) {
      final a = rng.nextDouble() * pi * 2;
      particles.add(Particle(c.x, kGroundY - 30, cos(a) * 220,
          sin(a) * 220 - 100, 0.6, 4, const Color(0xFFFFD166),
          grav: 400));
    }
    final rolled = rollSkull(rng, avail, luckMul: meta.luckMul);
    if (rolled == null) {
      _banner('이미 모든 해골을 보유 중', 1.8);
      return;
    }
    skullDrops.add(SkullDrop(rolled, c.x));
    final s = skull(rolled);
    _banner('[${tierLabel(s.tier)}] ${s.name} 발견!  ·  1/2 키로 슬롯 선택', 3.0);
  }

  void _equipSlot(int slot) {
    final drop = activeDrop;
    if (drop == null) return;
    final s = skull(drop.type);
    skullDrops.remove(drop);
    activeDrop = null;

    SkullSpec? displaced;
    if (slot == 0) {
      displaced = skullSlots[0];
      skullSlots[0] = s;
    } else {
      if (skullSlots.length < 2) {
        skullSlots.add(s);
      } else {
        displaced = skullSlots[1];
        skullSlots[1] = s;
      }
    }
    // the skull that was in the slot falls back onto the ground
    if (displaced != null) {
      skullDrops.add(SkullDrop(displaced.type, drop.x));
    }

    activeSlot = activeSlot.clamp(0, skullSlots.length - 1);
    player.skulls = List.of(skullSlots);
    player.active = activeSlot;
    _banner(
        displaced != null
            ? '${s.name} 장착 · ${displaced.name} 내려놓음'
            : '${s.name} → 슬롯 ${slot + 1} 장착!',
        1.8);
  }

  void _handleTransitions() {
    enterPrompt = null;
    if (exitPortal != null && player.rect.overlaps(exitPortal!)) {
      enterPrompt = Offset(player.cx, player.y - 24);
      if (_interactQueued && _transitionCd <= 0) {
        if (floor >= totalFloors) {
          phase = GamePhase.victory;
          runSouls += 40;
          _banner('승리! 모든 층 클리어 🏆', 999);
        } else {
          floor += 1;
          runSouls += 8;
          curHp = min(maxHp, curHp + 25);
          graph = generateFloor(floor, rng);
          _enterRoom(graph.startId);
        }
      }
      return;
    }
    if (!roomCleared) return;
    for (final d in doors) {
      if (player.rect.overlaps(d.rect)) {
        enterPrompt = Offset(player.cx, player.y - 24);
        if (_interactQueued && _transitionCd <= 0) _enterRoom(d.target);
        return;
      }
    }
  }

  void _handleShop() {
    if (roomType != RoomType.shop || !_interactQueued) return;
    for (final it in shopItems) {
      if (it.bought) continue;
      if (!player.rect.overlaps(it.pedestal.inflate(34))) continue;
      if (gold < it.cost) {
        _banner('골드가 부족하다', 1.0);
        return;
      }
      gold -= it.cost;
      it.bought = true;
      switch (it.kind) {
        case 'heal':
          player.hp = min(player.maxHp, player.hp + 50);
          break;
        case 'maxhp':
          maxHp += 25;
          player.maxHp = maxHp;
          player.hp += 25;
          break;
        case 'atk':
          shopAtk += 0.25;
          break;
        case 'shieldbuff':
          player.addStatus(StatusKind.shield, 20, 1);
          break;
        case 'regenbuff':
          player.addStatus(StatusKind.regen, 15, 4);
          break;
        case 'hastebuff':
          player.addStatus(StatusKind.haste, 18, 1);
          break;
        case 'atkupbuff':
          player.addStatus(StatusKind.atkUp, 15, 1);
          break;
        case 'lifesteal':
          lifesteal += 0.15;
          break;
      }
      curHp = player.hp;
      _banner('구매: ${it.name}', 1.4);
      for (int i = 0; i < 14; i++) {
        final a = rng.nextDouble() * pi * 2;
        particles.add(Particle(it.pedestal.center.dx, it.pedestal.top,
            cos(a) * 160, sin(a) * 160 - 80, 0.6, 4, const Color(0xFFFFD166),
            grav: 400));
      }
      return;
    }
  }

  void _awardGold(int amount) => gold += amount;

  // ----------------------------------------------------------------
  // Summoned skeleton soldier AI: seek nearest enemy, swing when adjacent,
  // loosely follow the player when no enemies remain, expire over time.
  void _updateAlly(Ally a, double dt) {
    if (!a.persistent) a.life -= dt; // void minions never decay
    a.animTime += dt;
    if (a.atkCd > 0) a.atkCd -= dt;
    if (a.jumpCd > 0) a.jumpCd -= dt;

    // nearest living target (enemy or boss)
    Entity? target;
    double best = 1e9;
    for (final e in enemies) {
      if (e.dead) continue;
      final d = (e.center - a.center).distance;
      if (d < best) {
        best = d;
        target = e;
      }
    }
    if (boss != null && !boss!.dead) {
      final d = (boss!.center - a.center).distance;
      if (d < best) {
        best = d;
        target = boss;
      }
    }

    a.vy += kGravity * dt;
    if (a.vy > 1200) a.vy = 1200;

    if (target != null && best < 600) {
      final dx = target.cx - a.cx;
      final dy = target.cy - a.cy;
      a.facing = dx >= 0 ? 1 : -1;
      // attack only when actually next to the target — close on BOTH axes
      final inRange = dx.abs() <= 34 && dy.abs() <= 46;
      if (!inRange) {
        a.vx = a.facing * 165.0;
        // jump to chase a target above, or to clear a wall/ledge in the way —
        // at the monsters' jump strength (~129px) so allies can actually climb
        // one-way platforms instead of barely hopping (the old -560 ≈ 60px).
        final blocked = _wallAhead(a) || !_groundAhead(a);
        if (a.onGround && a.jumpCd <= 0 && (dy < -34 || blocked)) {
          a.vy = -860;
          a.onGround = false;
          a.jumpCd = 0.7;
        }
      } else {
        a.vx = 0;
        if (a.atkCd <= 0) {
          a.atkCd = 0.6;
          final t = target;
          if (t is Boss) {
            _damageBoss(t, a.atk * atkMul);
          } else {
            t.damage(a.atk * atkMul);
            if (t is Enemy && t.kind != EnemyKind.bat) t.vx = a.facing * 120;
          }
          if (a.source != null) a.source!.attackAnim = 0.25;
          _hitSpark(target.cx, target.cy, a.facing);
        }
      }
    } else {
      // no target: regroup near the player
      final dx = player.cx - a.cx;
      if (dx.abs() > 60) {
        a.facing = dx >= 0 ? 1 : -1;
        a.vx = a.facing * 130.0;
      } else {
        a.vx = 0;
      }
    }

    // summons are fragile: enemies/boss touching one wound it (DPS-style so it
    // doesn't need per-hit bookkeeping). It dies when its HP runs out.
    for (final e in enemies) {
      if (!e.dead && e.rect.overlaps(a.rect)) {
        a.damage(_contactDmg(e.kind) * 1.6 * dt);
      }
    }
    if (boss != null && !boss!.dead && boss!.rect.overlaps(a.rect)) {
      a.damage(40 * dt);
    }

    _moveAndCollide(a, dt);

    // a charmed monster is rendered from its retained Enemy: keep that sprite's
    // transform/animation/health in sync with the ally driving it.
    final src = a.source;
    if (src != null) {
      src.x = a.x;
      src.y = a.y;
      src.facing = a.facing;
      src.animTime = a.animTime;
      src.hp = a.hp;
      src.maxHp = a.maxHp;
      src.vx = a.vx;
      src.vy = a.vy;
      src.onGround = a.onGround;
      src.aggro = false; // friendly now — no menacing red backlight
      if (src.attackAnim > 0) src.attackAnim -= dt;
    }
  }

  void _allyPoof(Ally a) {
    for (int i = 0; i < 12; i++) {
      final ang = rng.nextDouble() * pi * 2;
      particles.add(Particle(a.cx, a.cy, cos(ang) * 120, sin(ang) * 120 - 40,
          0.4, 4, const Color(0xFFB388FF),
          grav: 80));
    }
  }

  // 공허군주: birth one weak void monster (random type) at [x],[y]. It persists
  // across rooms and fights for the player until its small HP is worn down.
  void _spawnVoidMinion(double x, double y) {
    const kinds = ['werewolf', 'werebear', 'deathknight', 'lich'];
    final kind = kinds[rng.nextInt(kinds.length)];
    final hp = (player.maxHp * 0.22).clamp(18.0, 80.0);
    final atk = kind == 'werebear'
        ? 16.0
        : (kind == 'deathknight' ? 14.0 : (kind == 'lich' ? 11.0 : 12.0));
    allies.add(Ally(x - 11, y, 99999.0, hp,
        atk: atk, kind: kind, persistent: true)
      ..facing = player.facing
      ..vy = -200);
    _fx('runes', x, y - 10, 0.45, const Color(0xFFE040FB), size: 40);
    for (int s = 0; s < 12; s++) {
      final ang = rng.nextDouble() * pi * 2;
      particles.add(Particle(x, y, cos(ang) * 130, -rng.nextDouble() * 200, 0.5,
          5, s.isEven ? const Color(0xFFE040FB) : const Color(0xFF7E1FA0),
          grav: 260));
    }
  }

  // physics with one-way platforms
  void _moveAndCollide(Entity e, double dt, {bool oneWay = true}) {
    e.x += e.vx * dt;
    for (final s in solids) {
      if (e.rect.overlaps(s)) {
        // auto step-up: climb shallow ledges (stairs/slopes) without stopping
        final rise = (e.y + e.h) - s.top;
        if (e.vy >= -1 &&
            rise > 0 &&
            rise <= kStepUp &&
            _canStandAt(e, e.x, s.top - e.h)) {
          e.y = s.top - e.h;
          e.onGround = true;
          continue;
        }
        if (e.vx > 0) {
          e.x = s.left - e.w;
        } else if (e.vx < 0) {
          e.x = s.right;
        }
        e.vx = 0;
      }
    }
    final oldBottom = e.y + e.h;
    e.onGround = false;
    e.y += e.vy * dt;
    for (final s in solids) {
      if (e.rect.overlaps(s)) {
        if (e.vy > 0) {
          e.y = s.top - e.h;
          e.onGround = true;
        } else if (e.vy < 0) {
          e.y = s.bottom;
        }
        e.vy = 0;
      }
    }
    final canOneWay = oneWay && !(e is Enemy && e.dropTimer > 0);
    if (canOneWay && e.vy >= 0) {
      final newBottom = e.y + e.h;
      for (final p in platforms) {
        if (e.x + e.w > p.left + 2 &&
            e.x < p.right - 2 &&
            oldBottom <= p.top + 8 &&
            newBottom >= p.top) {
          e.y = p.top - e.h;
          e.vy = 0;
          e.onGround = true;
        }
      }
    }
  }

  bool _surfaceAt(double px, double py) {
    for (final s in solids) {
      if (s.contains(Offset(px, py))) return true;
    }
    for (final p in platforms) {
      if (px >= p.left && px <= p.right && py >= p.top && py <= p.top + 10) {
        return true;
      }
    }
    return false;
  }

  /// True if [e] could occupy the box at (nx, ny) without overlapping any solid
  /// (used to gate auto step-up so we never shove an entity into a ceiling).
  bool _canStandAt(Entity e, double nx, double ny) {
    final box = Rect.fromLTWH(nx, ny, e.w, e.h);
    for (final s in solids) {
      if (box.overlaps(s.deflate(0.5))) return false;
    }
    return true;
  }

  bool _groundAhead(Entity e) =>
      _surfaceAt(e.facing > 0 ? e.x + e.w + 4 : e.x - 4, e.y + e.h + 6);

  bool _wallAhead(Entity e) {
    final px = e.facing > 0 ? e.x + e.w + 4 : e.x - 4;
    for (final s in solids) {
      // shallow ledges (within auto step-up) don't count as walls
      if (px >= s.left &&
          px <= s.right &&
          e.y + e.h - 4 > s.top + kStepUp &&
          e.y + 4 < s.bottom) {
        return true;
      }
    }
    return false;
  }

  // ----------------------------------------------------------------
  // player
  void _updatePlayer(double dt) {
    final p = player;
    p.animTime += dt;
    if (p.hitFlash > 0) p.hitFlash -= dt;
    if (p.hurtTimer > 0) p.hurtTimer -= dt;
    if (p.invuln > 0) p.invuln -= dt;
    if (p.swapCd > 0) p.swapCd -= dt;
    if (p.skillTimer > 0) p.skillTimer -= dt;
    if (p.skillActive > 0) p.skillActive -= dt;
    if (p.flyTimer > 0) p.flyTimer -= dt;
    if (p.ghostTimer > 0) {
      p.ghostTimer -= dt;
      _ghostReap();
    }
    if (p.rideTimer > 0) {
      p.rideTimer -= dt;
      if (p.rideTimer <= 0) p.rammed.clear();
    }
    if (p.stealthTimer > 0) p.stealthTimer -= dt;
    if (p.reflectTimer > 0) p.reflectTimer -= dt;
    if (p.auraTimer > 0) p.auraTimer -= dt;
    // 석궁수 연속 사격: pace out the queued 5-bolt burst, one shot at a time
    if (!town && p.burstShots > 0) {
      p.burstCd -= dt;
      if (p.burstCd <= 0) {
        _fireBurstBolt(p);
        p.burstShots -= 1;
        p.burstCd = 0.1;
      }
    }
    // 저격수 레일건: auto-fire the barrage on a cadence while it lasts
    if (!town && p.railgunTimer > 0) {
      p.railgunTimer -= dt;
      p.railgunCd -= dt;
      if (p.railgunCd <= 0) {
        _railBeam(p);
        p.railgunCd = 0.5;
      }
    }
    // 성기사 천공의 대검: the planted blade stands for 10s; standing near it grants
    // a big attack buff that vanishes the moment the player steps away.
    if (paladinSwordTimer > 0) {
      paladinSwordTimer -= dt;
      paladinSwordBuff = paladinSwordTimer > 0 &&
          (p.cx - paladinSwordX).abs() < 120 &&
          (p.cy - paladinSwordY).abs() < 170;
    } else {
      paladinSwordBuff = false;
    }
    if (p.dodgeCharge < p.dodgeMax) p.dodgeCharge += dt / 1.1;
    // class perks (D3): rogue-likes get an extra dash; nimble get a mid-air jump
    p.dodgeMax = meta.dodgeCharges + (_skullExtraDash() ? 1 : 0);
    if (p.dodgeCharge > p.dodgeMax) p.dodgeCharge = p.dodgeMax.toDouble();
    if (p.onGround) p.airJumpsLeft = _skullAgile() ? 1 : 0;

    // stunned: drop all action/move input until it wears off
    if (p.hasStatus(StatusKind.stun)) {
      moveLeft = moveRight = false;
      moveUp = moveDown = false;
      _jumpQueued = _attackQueued = _dodgeQueued = false;
      _skillQueued = _swapQueued = false;
    }

    if (_swapQueued && skullSlots.length > 1 && p.swapCd <= 0) {
      activeSlot = 1 - activeSlot;
      p.active = activeSlot;
      p.swapCd = 0.4;
      for (int i = 0; i < 12; i++) {
        final a = rng.nextDouble() * pi * 2;
        particles.add(Particle(
            p.cx, p.cy, cos(a) * 150, sin(a) * 150, 0.4, 4, p.skull.eye,
            grav: 0));
      }
    }

    if (_dodgeQueued && p.dodgeTimer <= 0 && p.dodgeCharge >= 1) {
      p.dodgeCharge -= 1;
      // 검성: a noticeably longer dash that cuts foes along its path
      p.dodgeTimer = p.skull.type == SkullType.swordsaint ? kDashTime * 1.5 : kDashTime;
      if (p.skull.type == SkullType.swordsaint) p.dashHits.clear();
      p.dodgeDir = (moveLeft && !moveRight)
          ? -1
          : (moveRight && !moveLeft ? 1 : p.facing);
      p.facing = p.dodgeDir;
      p.invuln = max(p.invuln, p.dodgeTimer + 0.06);
      _dust(p.cx, p.y + p.h);
    }

    if (p.dodgeTimer > 0) {
      p.dodgeTimer -= dt;
      p.vx = p.dodgeDir * kDashSpeed;
      p.vy += kGravity * dt * 0.3;
      // 검성: damage every foe the dash sweeps through (once each)
      if (p.skull.type == SkullType.swordsaint) {
        final dmul = atkMul;
        final sweep = p.rect.inflate(8);
        for (final e in enemies) {
          if (e.dead || p.dashHits.contains(e) || !sweep.overlaps(e.rect)) {
            continue;
          }
          p.dashHits.add(e);
          e.damage(22 * dmul);
          _playerOnHit(e);
          _hitSpark(e.cx, e.cy, p.dodgeDir);
        }
        final db = boss;
        if (db != null &&
            !db.dead &&
            !p.dashHits.contains(db) &&
            sweep.overlaps(db.rect)) {
          p.dashHits.add(db);
          _damageBoss(db, 22 * dmul);
          _hitSpark(db.cx, db.cy, p.dodgeDir);
        }
      }
      if (rng.nextDouble() < 0.7) {
        particles.add(Particle(p.cx, p.cy, -p.dodgeDir * 60, 0, 0.25, 5,
            p.skull.eye.withOpacity(0.6),
            grav: 0));
      }
    } else {
      double dir = 0;
      if (moveLeft) dir -= 1;
      if (moveRight) dir += 1;
      if (p.attacking) dir *= 0.35;
      double sm = 1;
      if (p.hasStatus(StatusKind.slow)) sm *= 0.55;
      if (p.hasStatus(StatusKind.haste)) sm *= 1.45;
      if (p.rideTimer > 0) sm *= 1.5; // 망령기사 유령마: +50% move speed
      final horiz = kPlayerSpeed * p.skull.speedMul * sm * meta.traitSpeedMul;
      p.vx = dir * horiz;
      // allow turning while attacking so you can hit enemies behind you
      if (dir != 0) p.facing = dir > 0 ? 1 : -1;
      if (p.flyTimer > 0) {
        // 용의 비상: free vertical flight via up/down keys — a touch slower than
        // the horizontal move speed; hovers in place when no vertical key is held.
        double vdir = 0;
        if (moveUp) vdir -= 1;
        if (moveDown) vdir += 1;
        p.vy = vdir * horiz * 0.8;
      } else {
        p.vy += kGravity * dt;
      }
    }
    if (p.vy > 1600) p.vy = 1600;

    if (p.onGround) {
      p.coyote = 0.1;
    } else if (p.coyote > 0) {
      p.coyote -= dt;
    }
    // while flying (용의 비상) vertical movement is on the up/down keys, so a jump
    // press does nothing — only ground/air jumps run here.
    if (_jumpQueued && p.dodgeTimer <= 0 && p.flyTimer <= 0) {
      if (p.coyote > 0) {
        p.vy = -kJumpVel * (p.rideTimer > 0 ? 1.5 : 1.0); // 유령마: +50% jump
        p.coyote = 0;
        _dust(p.cx, p.y + p.h);
      } else if (p.airJumpsLeft > 0) {
        // mid-air jump perk: slightly weaker, with a ring of burst particles
        p.airJumpsLeft -= 1;
        p.vy = -kJumpVel * 0.92;
        for (int i = 0; i < 9; i++) {
          final a = (i / 9) * pi * 2;
          particles.add(Particle(p.cx, p.y + p.h, cos(a) * 130,
              sin(a).abs() * 90, 0.3, 4, p.skull.eye,
              grav: 260));
        }
      }
    }

    if (_attackQueued && p.dodgeTimer <= 0 && !town) _doAttack();
    if (p.attackBuffer > 0) p.attackBuffer -= dt;
    if (p.attackTimer > 0) {
      p.attackTimer -= dt;
      if (p.attackTimer <= 0) {
        p.comboWindow = 0.5;
        // a press buffered during the swing fires the next combo step now
        if (p.attackBuffer > 0 && p.dodgeTimer <= 0 && !town) {
          p.attackBuffer = 0;
          _doAttack();
        }
      }
    } else if (p.comboWindow > 0) {
      p.comboWindow -= dt;
      // don't drop the combo while a buffered press is still pending
      if (p.comboWindow <= 0 && p.attackBuffer <= 0) p.comboStep = 0;
    }

    if (_skillQueued && p.skillTimer <= 0 && p.dodgeTimer <= 0 && !town) {
      _doSkill();
    }

    _moveAndCollide(p, dt);

    // 용의 비상: cap the climb at the room's upward camera limit so the flying
    // player can't soar off the top of the screen (the camera tracks down to
    // camMinY, which is 0 in flat rooms).
    if (p.flyTimer > 0 && p.y < camMinY + 8) {
      p.y = camMinY + 8;
      if (p.vy < 0) p.vy = 0;
    }

    // earth-slam bursts the moment the diving player hits the ground
    if (p.slamPending && p.onGround) {
      p.slamPending = false;
      _slamShockwave(p, atkMul);
    }

    if (!town && p.y > kGroundY + 700) p.damage(9999);
    if (p.dead && phase == GamePhase.playing) {
      phase = GamePhase.gameover;
      _banner('GAME OVER', 999);
      shake = 0.5;
    }
  }

  // 사신 유령화: every foe the ghostly player overlaps has its HP and defense
  // halved — once each (tracked by Enemy.reaped). Bosses are exempt so the
  // HP-halving can't trivialize a boss fight.
  void _ghostReap() {
    final p = player;
    for (final e in enemies) {
      if (e.dead || e.reaped) continue;
      if (!p.rect.overlaps(e.rect)) continue;
      e.hp *= 0.5;
      e.dr *= 0.5;
      e.reaped = true;
      _fx('runes', e.cx, e.cy, 0.4, const Color(0xFFB388FF), size: 40);
      for (int i = 0; i < 12; i++) {
        final a = rng.nextDouble() * pi * 2;
        particles.add(Particle(e.cx, e.cy, cos(a) * 150, sin(a) * 150 - 30, 0.5,
            4, i.isEven ? const Color(0xFFB388FF) : const Color(0xFF7E57C2),
            grav: 80));
      }
    }
  }

  void _doAttack() {
    final p = player;
    // While a swing is in progress, NEVER advance/reset here — just buffer the
    // press. Replaying at swing-end is what keeps mashing chaining 1→2→3.
    // (The old `> 0.06` guard let presses in the last sliver of a swing fall
    //  through and reset comboStep to 1, which broke fast mashing.)
    if (p.attackTimer > 0) {
      p.attackBuffer = 0.4;
      return;
    }
    // throwers lob an arcing item; ranged classes fire a straight projectile
    if (p.skull.throwerBasic) {
      _doThrownBasic(p);
      return;
    }
    if (p.skull.rangedBasic) {
      _doRangedBasic(p);
      return;
    }
    if (p.comboWindow > 0 && p.comboStep < 3) {
      p.comboStep += 1;
    } else {
      p.comboStep = 1;
    }
    p.attackDuration = p.skull.atkDur;
    p.attackTimer = p.attackDuration;
    p.comboWindow = 0;
    p.hitThisSwing.clear();
    p.finisherFired = false;
    if (p.onGround) p.vx += p.facing * 70;
    // 용기병: the basic attack manifests as a lunging dragon (cosmetic FX)
    if (p.skull.type == SkullType.dragoon) {
      _fx('dragon', p.cx + p.facing * 22, p.cy - 2, max(0.28, p.attackDuration),
          p.skull.eye,
          dir: p.facing.toDouble(), size: 78 * p.skull.reachMul);
    }
    _emitNoise(p.cx, p.cy, 0.5);
  }

  // Thrown basic attack: lob an arcing, class-appropriate item that shatters on
  // impact. Alchemist = poison potion, bomber = fire bomb, slinger = rock.
  void _doThrownBasic(Player p) {
    final sk = p.skull;
    // the slinger just chucks rocks — quicker than a potion/bomb wind-up
    final isRock = sk.type == SkullType.slinger;
    final cd = isRock ? 0.6 : 0.85;
    p.attackDuration = cd;
    p.attackTimer = cd;
    p.comboStep = 0;
    p.comboWindow = 0;
    p.finisherFired = false;
    final mul = atkMul;
    final String shape;
    final Color col;
    if (sk.type == SkullType.alchemist) {
      shape = 'potion';
      col = const Color(0xFF9CCC65);
    } else if (isRock) {
      shape = 'rock';
      col = const Color(0xFFFFB300);
    } else {
      shape = 'bomb';
      col = const Color(0xFF455A64);
    }
    final dmg = (isRock ? 15.0 : 20.0) * mul;
    projectiles.add(Projectile(p.cx + p.facing * 14, p.cy - 6,
        p.facing * (isRock ? 420.0 : 360.0), -260, 10, 1.6, dmg, false, col,
        shape: shape, grav: 640));
    _emitNoise(p.cx, p.cy, 0.5);
  }

  // Ranged basic attack: a single projectile on a slow cadence (so mashing,
  // via the buffer, can't fire faster than the cooldown). Archer = fast arrow,
  // mage = slightly slower magic orb.
  void _doRangedBasic(Player p) {
    final sk = p.skull;
    // lich: a reaching dark hand that roots (binds) whatever it strikes
    if (sk.type == SkullType.lich) {
      final cd = 0.85;
      p.attackDuration = cd;
      p.attackTimer = cd;
      p.comboStep = 0;
      p.comboWindow = 0;
      p.finisherFired = false;
      final dmg = 16.0 * atkMul * sk.reachMul;
      final fy = p.cy + 6;
      projectiles.add(Projectile(p.cx + p.facing * 16, fy, p.facing * 520.0, 0,
          16, 1.0, dmg, false, const Color(0xFF7E57C2),
          shape: 'darkhand',
          onHit: StatusKind.bind,
          onHitDur: 1.6,
          onHitPow: 1));
      for (int i = 0; i < 8; i++) {
        particles.add(Particle(
            p.cx + p.facing * 24,
            fy + (rng.nextDouble() - 0.5) * 16,
            p.facing * (120 + rng.nextDouble() * 220),
            (rng.nextDouble() - 0.5) * 70,
            0.3,
            3 + rng.nextDouble() * 2,
            i.isEven ? const Color(0xFF7E57C2) : const Color(0xFF311B92),
            grav: 0));
      }
      _emitNoise(p.cx, p.cy, 0.5);
      return;
    }
    final sniper = sk.weapon == 'sniper';
    final archer = sk.category == '궁수형';
    final gun = sk.type == SkullType.gunner; // crossbow: faster, heavier bolts
    final mage = !sniper && !archer; // 마법형 caster orb
    // sniper: slow cadence, very fast/long/heavy shot. Archers fire a touch
    // faster than before; mages stay near 1 shot/sec but their orb bursts.
    final cd = sniper ? 1.4 : (archer ? 0.58 : 1.0);
    p.attackDuration = cd;
    p.attackTimer = cd;
    p.comboStep = 0;
    p.comboWindow = 0;
    p.finisherFired = false;
    final mul = atkMul;
    // 저격수: basic shot hits twice as hard (84 vs the old 42)
    final dmg = (sniper ? 84.0 : (archer ? (gun ? 23.0 : 16.0) : 19.0)) *
        mul *
        sk.reachMul;
    // crossbow bolts fly noticeably faster than ordinary arrows
    final speed = sniper ? 1150.0 : (archer ? (gun ? 980.0 : 640.0) : 470.0);
    // bigger radius + fired a bit lower so flat ground enemies (slimes) connect
    final r = sniper ? 7.0 : (archer ? 9.0 : 12.0);
    final shape =
        sniper ? 'bolt' : (archer ? (gun ? 'bolt' : 'arrow') : 'orb');
    final life = sniper ? 2.4 : 1.7; // long-range round
    final fy = p.cy + 8;
    projectiles.add(Projectile(p.cx + p.facing * 16, fy,
        p.facing * speed, 0, r, life, dmg, false, sk.eye,
        shape: shape, splash: mage ? 56 : 0));
    // 연사 패시브: a chance to loose extra projectiles in the same breath
    final pv = _passive;
    if (pv.kind == PassiveKind.multishot && rng.nextDouble() < pv.value) {
      for (int i = 0; i < 2; i++) {
        final vyoff = (i == 0 ? -1.0 : 1.0) * 95.0; // small vertical fan
        projectiles.add(Projectile(p.cx + p.facing * 16, fy, p.facing * speed,
            vyoff, r, life, dmg, false, sk.eye,
            shape: shape, splash: mage ? 56 : 0));
      }
    }
    // muzzle flash
    for (int i = 0; i < 5; i++) {
      particles.add(Particle(
          p.cx + p.facing * 22,
          fy,
          p.facing * (60 + rng.nextDouble() * 120),
          (rng.nextDouble() - 0.5) * 90,
          0.22,
          3,
          sk.eye,
          grav: 0));
    }
    _emitNoise(p.cx, p.cy, 0.5);
  }

  // Fires a single crossbow bolt for the 석궁수's 연속 사격 burst. Aim follows
  // the player's current facing, so the burst can be steered while it lasts.
  void _fireBurstBolt(Player p) {
    final mul = atkMul;
    final fy = p.cy + 8;
    projectiles.add(Projectile(p.cx + p.facing * 16, fy, p.facing * 980.0, 0,
        8, 2.0, 20.0 * mul, false, p.skull.eye,
        shape: 'bolt'));
    for (int i = 0; i < 4; i++) {
      particles.add(Particle(
          p.cx + p.facing * 22,
          fy,
          p.facing * (60 + rng.nextDouble() * 140),
          (rng.nextDouble() - 0.5) * 80,
          0.2,
          3,
          p.skull.eye,
          grav: 0));
    }
    p.skillActive = 0.12; // brief recoil flourish per shot
    _emitNoise(p.cx, p.cy, 0.45);
  }

  void _doSkill() {
    final p = player;
    p.skillTimer = p.skull.skillCd;
    p.skillActive = 0.32;
    _emitNoise(p.cx, p.cy, 0.7);
    final mul = atkMul;
    switch (p.skull.skill) {
      case 'spin':
        shake = max(shake, 0.2);
        _fx('ring', p.cx, p.cy, 0.42, p.skull.eye, size: 115);
        const radius = 100.0;
        for (final e in [...enemies, if (boss != null) boss!]) {
          if ((e.center - p.center).distance < radius + e.w / 2) {
            e.damage(16 * mul);
            final dir = e.cx >= p.cx ? 1 : -1;
            if (e is Enemy && e.kind != EnemyKind.bat) {
              e.vx = dir * 320.0;
              e.vy = -160;
            }
            _hitSpark(e.cx, e.cy, dir);
          }
        }
        for (int i = 0; i < 26; i++) {
          final a = (i / 26) * pi * 2;
          particles.add(Particle(p.cx, p.cy, cos(a) * 260, sin(a) * 260, 0.4,
              5, p.skull.eye,
              grav: 0));
        }
        break;
      case 'magicburst':
        _fx('runes', p.cx, p.cy, 0.5, p.skull.eye,
            dir: p.facing.toDouble(), size: 48);
        for (int i = 0; i < 5; i++) {
          final a = -pi / 2 + (i - 2) * 0.5;
          projectiles.add(Projectile(p.cx, p.cy, cos(a) * 420, sin(a) * 420,
              10, 1.4, 14 * mul, false, p.skull.eye));
        }
        for (int i = -1; i <= 1; i++) {
          projectiles.add(Projectile(p.cx, p.cy, p.facing * 460.0, i * 80.0,
              11, 1.6, 16 * mul, false, p.skull.eye));
        }
        break;
      case 'slam':
        // earth slam: drive straight down; the shockwave bursts on landing.
        if (p.onGround) {
          _slamShockwave(p, mul);
        } else {
          p.vy = max(p.vy, 1050); // dive into the ground
          p.slamPending = true;
          shake = max(shake, 0.12);
          _fx('ring', p.cx, p.cy, 0.22, const Color(0xFFFFB300), size: 38);
        }
        break;
      case 'blink':
        final oldX = p.cx;
        p.x = (p.x + p.facing * 230).clamp(20.0, roomWidth - p.w - 20);
        p.invuln = max(p.invuln, 0.3);
        final lo = min(oldX, p.cx), hi = max(oldX, p.cx);
        for (final e in [...enemies, if (boss != null) boss!]) {
          if (e.cx >= lo - 20 && e.cx <= hi + 20 && (e.cy - p.cy).abs() < 80) {
            e.damage(20 * mul);
            _hitSpark(e.cx, e.cy, p.facing);
          }
        }
        for (double t = 0; t <= 1; t += 0.1) {
          particles.add(Particle(lo + (hi - lo) * t, p.cy, 0, 0, 0.3, 6,
              p.skull.eye.withOpacity(0.7),
              grav: 0));
        }
        _fx('ghost', lo, p.cy, 0.4, p.skull.eye,
            dir: p.facing.toDouble(), size: hi - lo);
        break;
      case 'pounce':
        // beast: short forward lunge raking enemies with claws
        final oldX = p.cx;
        p.x = (p.x + p.facing * 200).clamp(20.0, roomWidth - p.w - 20);
        p.vy = -180;
        p.invuln = max(p.invuln, 0.25);
        final lo = min(oldX, p.cx), hi = max(oldX, p.cx);
        for (final e in [...enemies, if (boss != null) boss!]) {
          if (e.cx >= lo - 30 && e.cx <= hi + 30 && (e.cy - p.cy).abs() < 90) {
            e.damage(15 * mul);
            final dir = e.cx >= p.cx ? 1 : -1;
            if (e is Enemy && e.kind != EnemyKind.bat) {
              e.vx = dir * 240.0;
              e.vy = -150;
            }
            _hitSpark(e.cx, e.cy, dir);
          }
        }
        for (int i = 0; i < 14; i++) {
          particles.add(Particle(p.cx, p.cy, p.facing * (120 + rng.nextDouble() * 200),
              (rng.nextDouble() - 0.5) * 160, 0.3, 4, p.skull.eye,
              grav: 200));
        }
        // beast charge leaves blood-red claw streaks
        _fx('claw', p.cx, p.cy, 0.32, const Color(0xFFE53935),
            dir: p.facing.toDouble(), size: 80);
        shake = max(shake, 0.1);
        break;
      case 'guard':
        // knight: brief invulnerable stance + repelling counter shockwave
        p.invuln = max(p.invuln, 1.0);
        p.vx = 0;
        shake = max(shake, 0.18);
        _fx('ring', p.cx, p.cy, 0.45, const Color(0xFF64B5F6), size: 150);
        for (final e in [...enemies, if (boss != null) boss!]) {
          if ((e.center - p.center).distance < 150 + e.w / 2) {
            e.damage(14 * mul);
            final dir = e.cx >= p.cx ? 1 : -1;
            if (e is Enemy) {
              e.vx = dir * 360.0;
              e.vy = -180;
            }
            _hitSpark(e.cx, e.cy, dir);
          }
        }
        for (int i = 0; i < 28; i++) {
          final a = (i / 28) * pi * 2;
          particles.add(Particle(p.cx, p.cy, cos(a) * 240, sin(a) * 240, 0.45,
              5, p.skull.eye,
              grav: 0));
        }
        break;
      case 'explode':
        // bomber: large radial blast
        shake = max(shake, 0.42);
        _fx('dualring', p.cx, p.cy, 0.5, const Color(0xFFFF7043), size: 175);
        const radius = 175.0;
        for (final e in [...enemies, if (boss != null) boss!]) {
          if ((e.center - p.center).distance < radius + e.w / 2) {
            e.damage(30 * mul);
            e.addStatus(StatusKind.burn, 2.5, 8 * mul); // DoT scales with player atk
            final dir = e.cx >= p.cx ? 1 : -1;
            if (e is Enemy) {
              e.vx = dir * 420.0;
              e.vy = -300;
            }
            _hitSpark(e.cx, e.cy, dir);
          }
        }
        for (int i = 0; i < 40; i++) {
          final a = rng.nextDouble() * pi * 2;
          final sp = 180 + rng.nextDouble() * 300;
          particles.add(Particle(
              p.cx,
              p.cy,
              cos(a) * sp,
              sin(a) * sp - 60,
              0.5 + rng.nextDouble() * 0.4,
              5 + rng.nextDouble() * 5,
              i.isEven ? const Color(0xFFFF7043) : const Color(0xFFFFD166),
              grav: 500));
        }
        // 폭심: the big blast also hurls a scatter of small bombs in every
        // direction with random force; each arcs off and bursts (see _arcSplash).
        if (p.skull.type == SkullType.bomber) {
          for (int i = 0; i < 9; i++) {
            final ang = rng.nextDouble() * pi * 2;
            final sp = 150 + rng.nextDouble() * 380; // random force
            projectiles.add(Projectile(p.cx, p.cy - 8, cos(ang) * sp,
                sin(ang) * sp - 60, 7, 2.6, 14 * mul, false,
                const Color(0xFF263238),
                shape: 'bomb', grav: 760));
          }
        }
        break;
      case 'ghostride':
        // 망령기사: summon a ghost steed and ride for 10s — +50% move & jump
        // (see _updatePlayer), incoming damage halved (see _hurtPlayer), and
        // ramming foes deals heavy collision damage (see the ride block in
        // _resolveCombat). [rammed] resets so each foe can be trampled again.
        p.rideTimer = 10.0;
        p.rammed.clear();
        p.invuln = max(p.invuln, 0.4);
        p.vy = min(p.vy, -260); // a small rearing hop as the steed appears
        shake = max(shake, 0.2);
        _fx('ring', p.cx, p.cy, 0.5, const Color(0xFFB388FF), size: 140);
        _fx('ghost', p.cx, p.cy, 0.5, p.skull.eye,
            dir: p.facing.toDouble(), size: 70);
        for (int i = 0; i < 26; i++) {
          final a = (i / 26) * pi * 2;
          particles.add(Particle(p.cx, p.cy, cos(a) * 200, sin(a) * 200, 0.5, 5,
              i.isEven ? const Color(0xFFB388FF) : const Color(0xFFE1BEE7),
              grav: 0));
        }
        _banner('유령마 강림 — 10초간 질주!', 1.8);
        break;
      case 'shadowveil':
        // 야밤도: melt into the shadows (unseen, untouchable for up to 10s). Cast
        // again while veiled to detect every nearby foe and blink-assassinate
        // them one after another (heavy damage + bleed), ending the veil.
        if (p.stealthTimer > 0) {
          const huntR = 440.0;
          final marks = <Entity>[
            for (final e in enemies)
              if (!e.dead && (e.center - p.center).distance <= huntR) e,
            if (boss != null &&
                !boss!.dead &&
                (boss!.center - p.center).distance <= huntR)
              boss!,
          ];
          if (marks.isEmpty) {
            p.skillTimer = 0.4; // nothing to hunt — stay veiled, no real cd
            _banner('감지된 적이 없다', 1.2);
            break;
          }
          marks.sort((a, b) => (a.center - p.center)
              .distance
              .compareTo((b.center - p.center).distance));
          final hitDmg = 30.0 * mul;
          for (final e in marks) {
            final tx = e.cx, ty = e.cy;
            _fx('ghost', p.cx, p.cy, 0.28, p.skull.eye,
                dir: (tx >= p.cx ? 1 : -1).toDouble(),
                size: (tx - p.cx).abs());
            p.x = (e.cx - p.w / 2).clamp(20.0, roomWidth - p.w - 20);
            p.y = (e.cy - p.h / 2).clamp(0.0, kGroundY);
            p.facing = tx >= p.cx ? 1 : -1;
            if (e is Boss) {
              _damageBoss(e, hitDmg);
            } else {
              e.damage(hitDmg);
            }
            e.addStatus(StatusKind.bleed, 3.0, 6 * mul);
            _hitSpark(tx, ty, p.facing);
            for (int s = 0; s < 10; s++) {
              final a2 = rng.nextDouble() * pi * 2;
              particles.add(Particle(tx, ty, cos(a2) * 170, sin(a2) * 170 - 30,
                  0.45, 4,
                  s.isEven ? const Color(0xFFFF8A80) : const Color(0xFF37474F),
                  grav: 80));
            }
          }
          p.stealthTimer = 0;
          p.invuln = max(p.invuln, 0.4);
          p.skillTimer = p.skull.skillCd;
          shake = max(shake, 0.22);
          _banner('그림자 처형 — ${marks.length}타!', 1.6);
        } else {
          p.stealthTimer = 10.0;
          p.invuln = max(p.invuln, 0.4);
          p.skillTimer = 0.4; // allow the assassination re-cast while veiled
          _fx('ghost', p.cx, p.cy, 0.5, p.skull.eye,
              dir: p.facing.toDouble(), size: 60);
          for (int s = 0; s < 18; s++) {
            final a2 = rng.nextDouble() * pi * 2;
            particles.add(Particle(p.cx, p.cy, cos(a2) * 150, sin(a2) * 150, 0.5,
                4, const Color(0xFF37474F),
                grav: 0));
          }
          _banner('그림자 잠행 — 다시 눌러 처형', 1.6);
        }
        break;
      case 'reflect':
        // 약탈자: for 5s, every hit taken is bounced back at the attacker — even
        // bosses (see the reflect block in _hurtPlayer).
        p.reflectTimer = 5.0;
        p.invuln = max(p.invuln, 0.3);
        shake = max(shake, 0.18);
        _fx('ring', p.cx, p.cy, 0.5, const Color(0xFFFFCA28), size: 130);
        for (int s = 0; s < 24; s++) {
          final a2 = (s / 24) * pi * 2;
          particles.add(Particle(p.cx, p.cy, cos(a2) * 80, sin(a2) * 80, 0.6, 5,
              const Color(0xFFFFCA28),
              grav: 0));
        }
        _banner('가시 반사 — 5초간 피해 반사!', 1.6);
        break;
      case 'elements':
        {
          // 대마법사: cast one of the four elements at random.
          final el = rng.nextInt(4);
          if (el == 0) {
            // 불: a great fire tornado drifts forward, searing everything it
            // touches with a heavy burn.
            projectiles.add(Projectile(p.cx + p.facing * 20, p.y + p.h - 34,
                p.facing * 150.0, 0, 30, 1.9, 16 * mul, false,
                const Color(0xFFFF7043),
                shape: 'firetornado',
                pierce: true,
                onHit: StatusKind.burn,
                onHitDur: 3.0,
                onHitPow: 11 * mul));
            shake = max(shake, 0.2);
            _banner('불의 원소 — 화염 회오리!', 1.5);
          } else if (el == 1) {
            // 물: detect nearby foes and drop a water orb onto each one's head.
            const wr = 520.0;
            final marks = <Entity>[
              for (final e in enemies)
                if (!e.dead && (e.center - p.center).distance <= wr) e,
              if (boss != null &&
                  !boss!.dead &&
                  (boss!.center - p.center).distance <= wr)
                boss!,
            ];
            for (final e in marks) {
              projectiles.add(Projectile(e.cx, e.cy - 300, 0, 600, 12, 1.4,
                  20 * mul, false, const Color(0xFF4FC3F7),
                  shape: 'orb',
                  onHit: StatusKind.slow,
                  onHitDur: 1.8,
                  onHitPow: 1));
              _fx('runes', e.cx, e.cy - 300, 0.4, const Color(0xFF4FC3F7),
                  size: 30);
            }
            _banner(marks.isEmpty
                ? '물의 원소 — 감지된 적이 없다'
                : '물의 원소 — ${marks.length}개의 구체 낙하!', 1.5);
          } else if (el == 2) {
            // 바람: a storm of spinning wind blades flies out in all directions
            // and lingers for ~3s, slicing anything they pass through.
            for (int k = 0; k < 12; k++) {
              final a = (k / 12) * pi * 2;
              projectiles.add(Projectile(p.cx, p.cy, cos(a) * 250, sin(a) * 250,
                  12, 3.0, 12 * mul, false, const Color(0xFFB2FF59),
                  shape: 'windblade', pierce: true));
            }
            _fx('ring', p.cx, p.cy, 0.5, const Color(0xFFB2FF59), size: 120);
            shake = max(shake, 0.12);
            _banner('바람의 원소 — 회전 칼날!', 1.5);
          } else {
            // 땅: raise an earth-giant golem that fights at your side for 10s.
            allies.add(Ally(p.cx + p.facing * 34, p.y - 8, 10.0, p.maxHp,
                atk: 24, kind: 'earthgolem')
              ..facing = p.facing
              ..vy = -120);
            _fx('crack', p.cx + p.facing * 34, p.y + p.h, 0.5,
                const Color(0xFF8D6E63), size: 160);
            for (int s = 0; s < 18; s++) {
              final a2 = rng.nextDouble() * pi * 2;
              particles.add(Particle(p.cx + p.facing * 34, p.y + p.h,
                  cos(a2) * 140, -rng.nextDouble() * 200, 0.6, 5,
                  s.isEven ? const Color(0xFF8D6E63) : const Color(0xFF5D4037),
                  grav: 400));
            }
            shake = max(shake, 0.22);
            _banner('땅의 원소 — 거인 골렘 강림!', 1.6);
          }
        }
        break;
      case 'reaperghost':
        // 사신: become an invulnerable, undetectable ghost for 10s. Enemies lose
        // all aggro (see _updateEnemyAggro) and any foe brushed by the wraithly
        // body has its HP and defense halved (see _ghostReap).
        p.ghostTimer = 10.0;
        p.invuln = max(p.invuln, 0.4); // brief i-frames on cast
        _fx('ring', p.cx, p.cy, 0.5, const Color(0xFFB388FF), size: 130);
        _fx('ghost', p.cx, p.cy, 0.5, p.skull.eye,
            dir: p.facing.toDouble(), size: 70);
        for (int i = 0; i < 26; i++) {
          final a = (i / 26) * pi * 2;
          particles.add(Particle(p.cx, p.cy, cos(a) * 180, sin(a) * 180, 0.5, 5,
              const Color(0xFFB388FF),
              grav: 0));
        }
        _banner('사신의 강림 — 10초 무적 유령화!', 1.8);
        break;
      case 'grimscythe':
        // 망령(전설): summon a screen-filling lich that sweeps a giant scythe
        // across the whole view, smiting every on-screen foe and searing them
        // with a 3s black-flame burn.
        shake = max(shake, 0.45);
        final vw = _viewW, vh = _viewH;
        final lf = camX - 30, rt = camX + vw + 30;
        final tp = camY - 60, bt = camY + vh + 60;
        final gdmg = 70.0 * mul;
        for (final e in [...enemies, if (boss != null) boss!]) {
          if (e.dead) continue;
          if (e.cx < lf || e.cx > rt || e.cy < tp || e.cy > bt) continue;
          if (e is Boss) {
            _damageBoss(e, gdmg);
          } else {
            e.damage(gdmg);
          }
          e.addStatus(StatusKind.burn, 3.0, 14 * mul); // 검은 불꽃 화상
          _hitSpark(e.cx, e.cy, 1);
          for (int i = 0; i < 14; i++) {
            final ang = rng.nextDouble() * pi * 2;
            final sp = 60 + rng.nextDouble() * 170;
            particles.add(Particle(e.cx, e.cy - 8, cos(ang) * sp,
                sin(ang) * sp - 70, 0.6 + rng.nextDouble() * 0.5, 6,
                i.isEven ? const Color(0xFF1A0A24) : const Color(0xFF7E1FA0),
                grav: -50));
          }
        }
        _fx('lichscythe', camX + vw / 2, camY + vh * 0.34, 0.95, p.skull.eye,
            dir: p.facing.toDouble(), size: vw);
        _banner('사령의 대낫 — 검은 불꽃!', 1.8);
        break;
      case 'volley':
        // archer skill: a fan of actual arrows (not energy balls)
        for (int i = -2; i <= 2; i++) {
          final ang = i * 0.18;
          projectiles.add(Projectile(p.cx, p.cy - 6, p.facing * cos(ang) * 520,
              sin(ang) * 520, 7, 1.6, 12 * mul, false,
              const Color(0xFFCFD8DC),
              shape: 'arrow'));
        }
        break;
      case 'rapidshot':
        // 석궁수: a rapid 5-bolt burst, loosed one-by-one over ~0.5s. The first
        // bolt fires on the next tick; the rest are paced in _updatePlayer.
        p.burstShots = 5;
        p.burstCd = 0;
        break;
      case 'meteor':
        // alchemist hurls falling potion flasks; others call down meteors
        final isAlch = p.skull.type == SkullType.alchemist;
        for (int i = 0; i < 3; i++) {
          final tx = p.cx + (i - 1) * 140 + (rng.nextDouble() - 0.5) * 40;
          projectiles.add(Projectile(tx, p.cy - 260, 0, 540, 12, 1.2, 22 * mul,
              false, isAlch ? const Color(0xFF9CCC65) : const Color(0xFFFF7043),
              shape: isAlch ? 'potion' : 'ball'));
        }
        shake = max(shake, 0.2);
        break;
      case 'gravehands':
        // lich: a forest of dark hands erupts from the ground across a very
        // wide radius, rooting (binding) and crushing every enemy caught in it.
        shake = max(shake, 0.5);
        const radius = 460.0;
        for (final e in [...enemies, if (boss != null) boss!]) {
          if ((e.cx - p.cx).abs() < radius && (e.cy - p.cy).abs() < 240) {
            if (e is Boss) {
              _damageBoss(e, 46 * mul);
            } else {
              e.damage(46 * mul);
              if (e is Enemy) e.vy = -260;
            }
            e.addStatus(StatusKind.bind, 2.2, 1);
            _hitSpark(e.cx, e.cy, p.facing);
          }
        }
        // dark hands clawing up from the ground all across the radius
        for (double ox = -radius; ox <= radius; ox += 46) {
          final hx = (p.cx + ox).clamp(20.0, roomWidth - 20);
          final gy = p.y + p.h; // erupt from the floor line under the lich
          _fx('handrise', hx, gy, 0.55 + rng.nextDouble() * 0.2,
              const Color(0xFF7E57C2), size: 46 + rng.nextDouble() * 26);
          for (int s = 0; s < 3; s++) {
            particles.add(Particle(
                hx + (rng.nextDouble() - 0.5) * 24,
                gy,
                (rng.nextDouble() - 0.5) * 60,
                -180 - rng.nextDouble() * 220,
                0.5 + rng.nextDouble() * 0.4,
                4 + rng.nextDouble() * 4,
                s.isEven ? const Color(0xFF7E57C2) : const Color(0xFF311B92),
                grav: 380));
          }
        }
        _fx('runes', p.cx, p.cy, 0.6, const Color(0xFFB388FF), size: 90);
        break;
      case 'summon':
        // conjurer: raise temporary skeleton soldiers that fight then crumble
        final spawn = min(3, 6 - allies.length).clamp(0, 3);
        for (int i = 0; i < spawn; i++) {
          final ox = p.cx + (i - 1) * 36.0 + (rng.nextDouble() - 0.5) * 10;
          allies.add(Ally(ox - 10, p.y, 7.0, player.maxHp / 2)
            ..facing = p.facing
            ..vy = -240);
          _fx('runes', ox, p.cy, 0.4, const Color(0xFFB388FF), size: 36);
          for (int s = 0; s < 8; s++) {
            final ang = rng.nextDouble() * pi * 2;
            particles.add(Particle(ox, p.y + p.h, cos(ang) * 90,
                -rng.nextDouble() * 170, 0.4, 4, const Color(0xFFB388FF),
                grav: 220));
          }
        }
        shake = max(shake, 0.12);
        break;
      case 'stormcloud':
        // 폭풍술사: detect every foe in a wide radius and conjure a thunderhead
        // over each. Each cloud chases its target for 6s, calling down 3
        // lightning bolts that may stun (see _updateStorms / _stormStrike).
        const stormRadius = 600.0;
        final perBolt = 22.0 * mul;
        final struck = <Entity>[
          for (final e in enemies)
            if (!e.dead && (e.center - p.center).distance <= stormRadius) e,
          if (boss != null &&
              !boss!.dead &&
              (boss!.center - p.center).distance <= stormRadius)
            boss!,
        ];
        for (final tg in struck) {
          storms.add(StormCloud(tg, tg.cx, tg.cy - 130, dmg: perBolt));
          _fx('runes', tg.cx, tg.cy - 130, 0.5, const Color(0xFF80DEEA),
              size: 38);
        }
        _fx('ring', p.cx, p.cy, 0.5, const Color(0xFF18FFFF), size: 480);
        shake = max(shake, 0.16);
        _banner(
            struck.isEmpty ? '감지된 적이 없다' : '${struck.length}곳에 번개 구름!', 1.6);
        break;
      case 'quake':
        shake = max(shake, 0.3);
        _fx('crack', p.cx, p.y + p.h, 0.55, const Color(0xFF8D6E63), size: 320);
        for (final e in enemies) {
          if (e.onGround &&
              (e.cx - p.cx).abs() < 320 &&
              (e.cy - p.cy).abs() < 90) {
            e.damage(20 * mul);
            e.vy = -260;
            _hitSpark(e.cx, e.cy, e.cx >= p.cx ? 1 : -1);
          }
        }
        if (boss != null && (boss!.cx - p.cx).abs() < 320) {
          _damageBoss(boss!, 20 * mul);
        }
        for (int i = 0; i < 18; i++) {
          particles.add(Particle(p.cx + (rng.nextDouble() - 0.5) * 600,
              p.y + p.h, (rng.nextDouble() - 0.5) * 100,
              -rng.nextDouble() * 200, 0.5, 6, const Color(0xFF8D6E63),
              grav: 600));
        }
        break;
      case 'charm':
        // 전쟁군주: dominate every regular enemy within a wide radius (same scale
        // as the plague cloud), turning them into buffed allies that round on
        // their former comrades. Bosses are immune (never in [enemies]).
        const charmRadius = 360.0;
        const charmGold = Color(0xFFFFD166);
        _fx('ring', p.cx, p.cy, 0.6, charmGold, size: 460);
        final dominated = <Enemy>[
          for (final e in enemies)
            if (!e.dead && (e.center - p.center).distance <= charmRadius) e
        ];
        for (final e in dominated) {
          enemies.remove(e);
          // a charmed unit keeps its own body/HP, gains an attack buff, and
          // fights for ~12s before the domination wears off (it then crumbles).
          allies.add(Ally(e.x, e.y, 12.0, e.hp, atk: 16, source: e)
            ..facing = p.facing
            ..vx = e.vx
            ..vy = e.vy
            ..onGround = e.onGround
            ..animTime = e.animTime);
          e.aggro = false;
          e.statuses.clear(); // shed any debuffs on conversion
          _fx('runes', e.cx, e.cy, 0.45, charmGold, size: 42);
          for (int s = 0; s < 12; s++) {
            final a2 = rng.nextDouble() * pi * 2;
            particles.add(Particle(e.cx, e.cy, cos(a2) * 150,
                sin(a2) * 150 - 40, 0.55, 5, charmGold,
                grav: 120));
          }
        }
        shake = max(shake, 0.2);
        if (dominated.isEmpty) {
          // nothing to dominate (e.g. a boss fight) — the warlord turns the
          // command on himself, gaining a strong attack buff instead.
          p.addStatus(StatusKind.atkUp, 10.0, 1);
          _fx('ring', p.cx, p.cy, 0.45, const Color(0xFFFF5252), size: 150);
          for (int s = 0; s < 18; s++) {
            final a2 = rng.nextDouble() * pi * 2;
            particles.add(Particle(p.cx, p.cy, cos(a2) * 180, sin(a2) * 180,
                0.5, 5, const Color(0xFFFF5252),
                grav: 0));
          }
          _banner('지배할 적이 없다 — 전쟁군주의 격노! 공격력 강화', 1.8);
        } else {
          _banner('${dominated.length}명의 적을 지배했다!', 1.6);
        }
        break;
      case 'bladeaura':
        // 검성: wreathe the blade in a long blue aura for 10s — greatly extended
        // reach (see attackHitbox) and boosted damage (see atkMul).
        p.auraTimer = 10.0;
        p.invuln = max(p.invuln, 0.3);
        shake = max(shake, 0.16);
        _fx('ring', p.cx, p.cy, 0.5, const Color(0xFF00E5FF), size: 130);
        _fx('slashArc', p.cx + p.facing * 40, p.cy, 0.4, const Color(0xFF18FFFF),
            dir: p.facing.toDouble(), size: 150);
        for (int s = 0; s < 22; s++) {
          final a2 = (s / 22) * pi * 2;
          particles.add(Particle(p.cx, p.cy, cos(a2) * 150, sin(a2) * 150, 0.6,
              5, s.isEven ? const Color(0xFF00E5FF) : const Color(0xFFB2EBF2),
              grav: 0));
        }
        _banner('창천의 검기 — 10초간 검기 확장!', 1.6);
        break;
      case 'wings':
        // 치천사: unfurl two enormous wings (each spanning the plague-cloud range)
        // that stun every foe they touch for 5s, with light holy damage.
        {
          const wingReach = 680.0; // plague-doctor scale, per wing
          _fx('seraphwings', p.cx, p.cy, 0.7, const Color(0xFFFFF59D),
              dir: p.facing.toDouble(), size: wingReach);
          shake = max(shake, 0.22);
          for (final e in [...enemies, if (boss != null) boss!]) {
            if ((e.cx - p.cx).abs() < wingReach && (e.cy - p.cy).abs() < 220) {
              if (e is Boss) {
                _damageBoss(e, 14 * mul); // bosses shrug off the stun
              } else {
                e.damage(14 * mul);
                e.addStatus(StatusKind.stun, 5.0, 1);
              }
              _hitSpark(e.cx, e.cy, e.cx >= p.cx ? 1 : -1);
            }
          }
          for (int s = 0; s < 40; s++) {
            final side = s.isEven ? 1 : -1;
            particles.add(Particle(
                p.cx,
                p.cy - 10,
                side * (60 + rng.nextDouble() * 520),
                (rng.nextDouble() - 0.5) * 300,
                0.7,
                5,
                s % 3 == 0 ? const Color(0xFFFFF59D) : const Color(0xFFFFFFFF),
                grav: -20));
          }
          _banner('대천사의 날개 — 적 5초 기절!', 1.8);
        }
        break;
      case 'dashstrike':
        final sx = p.cx;
        p.x = (p.x + p.facing * 260).clamp(20.0, roomWidth - p.w - 20);
        p.invuln = max(p.invuln, 0.3);
        final dlo = min(sx, p.cx), dhi = max(sx, p.cx);
        for (final e in [...enemies, if (boss != null) boss!]) {
          if (e.cx >= dlo - 30 && e.cx <= dhi + 30 && (e.cy - p.cy).abs() < 100) {
            if (e is Boss) {
              _damageBoss(e, 24 * mul);
            } else {
              e.damage(24 * mul);
            }
            _hitSpark(e.cx, e.cy, p.facing);
          }
        }
        for (double t = 0; t <= 1; t += 0.1) {
          particles.add(Particle(dlo + (dhi - dlo) * t, p.cy, 0, 0, 0.3, 6,
              p.skull.eye,
              grav: 0));
        }
        _fx('ghost', dlo, p.cy, 0.32, p.skull.eye,
            dir: p.facing.toDouble(), size: dhi - dlo);
        // martial artists land a flurry of fists instead of a blade arc
        if (p.skull.category == '권사') {
          _fx('fist', p.cx, p.cy, 0.34, p.skull.eye,
              dir: p.facing.toDouble(), size: 64);
        } else {
          _fx('slashArc', p.cx, p.cy, 0.3, p.skull.eye,
              dir: p.facing.toDouble(), size: 90);
        }
        shake = max(shake, 0.12);
        break;
      case 'straightpunch':
        // 정권지르기: one heavy straight punch — a big fist drives forward,
        // knocking back and stunning every foe caught in front of the player.
        shake = max(shake, 0.22);
        p.vx += p.facing * 140; // small step into the strike
        final reach = 160.0 * p.skull.reachMul;
        for (final e in [...enemies, if (boss != null) boss!]) {
          final ahead = (e.cx - p.cx) * p.facing; // >0 = in front
          if (ahead > -26 && ahead < reach + e.w / 2 && (e.cy - p.cy).abs() < 96) {
            if (e is Boss) {
              _damageBoss(e, 46 * mul); // bosses shrug off the stun
            } else {
              e.damage(40 * mul);
              e.addStatus(StatusKind.stun, 1.6, 1);
              e.vx = p.facing * 380;
              e.vy = -200;
            }
            _hitSpark(e.cx, e.cy, p.facing);
          }
        }
        _fx('bigfist', p.cx + p.facing * 12, p.cy, 0.34, p.skull.eye,
            dir: p.facing.toDouble(), size: reach);
        for (int i = 0; i < 20; i++) {
          final spread = (rng.nextDouble() - 0.5) * 0.9;
          particles.add(Particle(
              p.cx + p.facing * reach * 0.8,
              p.cy + spread * 60,
              p.facing * (160 + rng.nextDouble() * 320),
              spread * 240,
              0.42,
              6,
              i.isEven ? p.skull.eye : const Color(0xFFFFFFFF),
              grav: 0));
        }
        break;
      case 'dragonform':
        // 용기병: sprout wings and take to the air for a few seconds, with a
        // big attack-power boost (see flyTimer in atkMul and _updatePlayer).
        p.flyTimer = 6.0;
        p.vy = -380; // lift off the ground
        p.invuln = max(p.invuln, 0.5);
        shake = max(shake, 0.18);
        _fx('ring', p.cx, p.cy, 0.5, p.skull.eye, size: 140);
        for (int i = 0; i < 28; i++) {
          final a = (i / 28) * pi * 2;
          particles.add(Particle(p.cx, p.cy, cos(a) * 220, sin(a) * 220, 0.5, 5,
              i.isEven ? p.skull.eye : const Color(0xFFFFFFFF),
              grav: 0));
        }
        _banner('용의 비상 — 공격력 대폭 강화!', 1.6);
        break;
      case 'bulwark':
        p.invuln = max(p.invuln, 1.4);
        p.hp = min(p.maxHp, p.hp + 12);
        p.addStatus(StatusKind.shield, 6, 1);
        _fx('ring', p.cx, p.cy, 0.5, const Color(0xFF4FC3F7), size: 120);
        for (int i = 0; i < 26; i++) {
          final a = (i / 26) * pi * 2;
          particles.add(Particle(p.cx, p.cy, cos(a) * 180, sin(a) * 180, 0.5, 5,
              const Color(0xFF4FC3F7),
              grav: 0));
        }
        break;
      case 'heal':
        p.hp = min(p.maxHp, p.hp + 24);
        p.addStatus(StatusKind.regen, 5, 5);
        for (int i = 0; i < 18; i++) {
          particles.add(Particle(p.cx + (rng.nextDouble() - 0.5) * 40, p.cy, 0,
              -80 - rng.nextDouble() * 80, 0.7, 5, const Color(0xFF66BB6A),
              grav: -40));
        }
        break;
      case 'flames':
        for (final e in [...enemies, if (boss != null) boss!]) {
          if ((e.cx - p.cx).abs() < 220 &&
              (e.cx - p.cx) * p.facing > -20 &&
              (e.cy - p.cy).abs() < 110) {
            if (e is Boss) {
              _damageBoss(e, 12 * mul);
            } else {
              e.damage(12 * mul);
            }
            e.addStatus(StatusKind.burn, 3, 7 * mul); // DoT scales with player atk
            _hitSpark(e.cx, e.cy, p.facing);
          }
        }
        for (int i = 0; i < 22; i++) {
          particles.add(Particle(p.cx, p.cy,
              p.facing * (120 + rng.nextDouble() * 300),
              (rng.nextDouble() - 0.5) * 160, 0.4, 6,
              i.isEven ? const Color(0xFFFF7043) : const Color(0xFFFFD166),
              grav: 0));
        }
        break;
      case 'firestorm':
        // pyromancer: hurl a large, far-reaching fireball that detonates into a
        // fiery blast (see _fireballExplode) on impact or at the end of flight.
        projectiles.add(Projectile(p.cx + p.facing * 16, p.cy - 6,
            p.facing * 470.0, 0, 16, 1.7, 12 * mul, false,
            const Color(0xFFFF7043),
            shape: 'fireball'));
        shake = max(shake, 0.12);
        break;
      case 'plague':
        // plague doctor: belch a huge cloud of green miasma that INFECTS every
        // enemy caught in it (전염 status — not raw poison). Infection ravages
        // the host, leaps to nearby foes (_spreadInfection), and bursts again
        // when an infected enemy dies (_plagueContagion).
        _fx('ring', p.cx + p.facing * 230, p.cy, 0.6,
            const Color(0xFF76FF03), size: 420);
        for (final e in [...enemies, if (boss != null) boss!]) {
          if ((e.cx - p.cx) * p.facing > -80 &&
              (e.cx - p.cx).abs() < 680 &&
              (e.cy - p.cy).abs() < 320) {
            if (e is Boss) {
              _damageBoss(e, 8 * mul);
            } else {
              e.damage(8 * mul);
            }
            e.addStatus(StatusKind.infect, 4.0, 8);
            _hitSpark(e.cx, e.cy, p.facing);
          }
        }
        for (int i = 0; i < 64; i++) {
          particles.add(Particle(
              p.cx + p.facing * 60,
              p.cy - 10 + (rng.nextDouble() - 0.5) * 200,
              p.facing * (80 + rng.nextDouble() * 760),
              (rng.nextDouble() - 0.5) * 240 - 20,
              0.8 + rng.nextDouble() * 0.6,
              7 + rng.nextDouble() * 5,
              i.isEven ? const Color(0xFF9CCC65) : const Color(0xFF7CB342),
              grav: -30));
        }
        break;
      case 'swordwave':
        // 기사: launch a HUGE crescent of sword energy (3x the old size) that
        // pierces every foe in its path (see piercing handling in _resolveCombat).
        projectiles.add(Projectile(p.cx + p.facing * 24, p.cy - 4,
            p.facing * 520.0, 0, 72, 1.5, 24 * mul, false, p.skull.eye,
            shape: 'swordwave', pierce: true));
        _fx('slashArc', p.cx + p.facing * 40, p.cy, 0.34, p.skull.eye,
            dir: p.facing.toDouble(), size: 150);
        shake = max(shake, 0.18);
        break;
      case 'swordfall':
        // 성기사: call down a giant blade that pierces every foe on the way down
        // for heavy damage, then crashes into the ground (radial damage) and
        // stays planted there for 10s (see _swordfallImpact).
        final tx = (p.cx + p.facing * 150).clamp(40.0, roomWidth - 40);
        projectiles.add(Projectile(tx, p.cy - 340, 0, 640, 22, 1.6, 26 * mul,
            false, p.skull.eye,
            shape: 'swordfall', pierce: true));
        break;
      case 'trap':
        // trapper: deploy an explosive trap at the player's feet. It arms
        // shortly, then detonates when an enemy steps on it (see _updateMines).
        final mx = (p.cx + p.facing * 26).clamp(30.0, roomWidth - 30);
        mines.add(Mine(mx, p.y + p.h - 4, dmg: 26 * mul));
        for (int i = 0; i < 8; i++) {
          particles.add(Particle(mx, p.y + p.h - 6, (rng.nextDouble() - 0.5) * 70,
              -rng.nextDouble() * 70, 0.35, 3, const Color(0xFFAED581),
              grav: 160));
        }
        // cap simultaneous traps so the room can't be flooded
        if (mines.length > 4) mines.removeAt(0);
        break;
      case 'net':
        // fisher: lob a weighted net that snares (slows) on hit
        projectiles.add(Projectile(p.cx + p.facing * 14, p.cy - 6,
            p.facing * 340.0, -150, 15, 2.0, 12 * mul, false,
            const Color(0xFFB0BEC5),
            shape: 'net', grav: 420));
        break;
      case 'rockthrow':
        // miner: hurl a spread of rocks/ore in an arc
        for (int i = -1; i <= 1; i++) {
          projectiles.add(Projectile(p.cx + p.facing * 14, p.cy - 8,
              p.facing * (300 + i * 30.0), -300 + i * 50.0, 9, 1.9, 16 * mul,
              false, const Color(0xFF9E8576),
              shape: 'rock', grav: 720));
        }
        shake = max(shake, 0.12);
        break;
      case 'valkyrie':
        // summon a spectral valkyrie that charges forward through enemies
        final reach = 290.0;
        final lo = p.facing >= 0 ? p.cx : p.cx - reach;
        final area = Rect.fromLTWH(lo, p.cy - 60, reach, 120);
        for (final e in [...enemies, if (boss != null) boss!]) {
          if (area.overlaps(e.rect)) {
            if (e is Boss) {
              _damageBoss(e, 22 * mul);
            } else {
              e.damage(22 * mul);
            }
            final dir = e.cx >= p.cx ? 1 : -1;
            if (e is Enemy && e.kind != EnemyKind.bat) {
              e.vx = dir * 340.0;
              e.vy = -200;
            }
            _hitSpark(e.cx, e.cy, dir);
          }
        }
        _fx('ghost', lo, p.cy, 0.42, const Color(0xFFFFF59D),
            dir: p.facing.toDouble(), size: reach);
        _fx('slashArc', p.cx + p.facing * reach * 0.66, p.cy, 0.34,
            const Color(0xFFFFF59D), dir: p.facing.toDouble(), size: 120);
        shake = max(shake, 0.2);
        break;
      case 'frost':
        // sharp icicles instead of round bolts
        for (int i = -1; i <= 1; i++) {
          projectiles.add(Projectile(p.cx, p.cy - 4, p.facing * 380.0,
              i * 90.0, 9, 1.8, 10 * mul, false, const Color(0xFF80DEEA),
              shape: 'icicle'));
        }
        for (int i = 0; i < 8; i++) {
          particles.add(Particle(p.cx + p.facing * 14, p.cy - 4,
              p.facing * (60 + rng.nextDouble() * 160),
              (rng.nextDouble() - 0.5) * 120, 0.3, 3,
              const Color(0xFFB3E5FC), grav: 80));
        }
        break;
      case 'railgun':
        // 저격수: begin a 5-second railgun barrage. Rail beams auto-fire on a
        // cadence (see _updatePlayer), each shoving the sniper backward. The
        // first beam goes off immediately.
        p.railgunTimer = 5.0;
        p.railgunCd = 0;
        _railBeam(p);
        _banner('레일건 — 5초 연속 사격!', 1.6);
        break;
    }
  }

  // 저격수 레일건: one piercing rail beam down the sniper's facing, with backward
  // recoil. Fired both on cast and repeatedly during the 5s barrage.
  void _railBeam(Player p) {
    final mul = atkMul;
    const reach = 820.0;
    final lo = p.facing >= 0 ? p.cx : p.cx - reach;
    final beam = Rect.fromLTWH(lo, p.cy - 22, reach, 44);
    for (final e in [...enemies, if (boss != null) boss!]) {
      if (beam.overlaps(e.rect)) {
        if (e is Boss) {
          _damageBoss(e, 48 * mul);
        } else {
          e.damage(48 * mul);
        }
        _hitSpark(e.cx, e.cy, p.facing);
      }
    }
    final endX = (p.cx + p.facing * reach).clamp(0.0, roomWidth);
    skillFx.add(SkillFx('lightning', p.cx, p.cy, 0.3, const Color(0xFF18FFFF),
        x2: endX, y2: p.cy));
    for (double t = 0; t <= 1; t += 0.04) {
      particles.add(Particle(
          p.cx + (endX - p.cx) * t,
          p.cy + (rng.nextDouble() - 0.5) * 12,
          0, 0, 0.26, 4, const Color(0xFFB2EBF2),
          grav: 0));
    }
    p.vx -= p.facing * 150.0; // recoil — the sniper is shoved backward
    shake = max(shake, 0.24);
    _emitNoise(p.cx, p.cy, 0.6);
  }

  // Earth-slam ground burst: vibration + crack + uppercut shockwave. Fired the
  // instant the player touches the ground (so the impact lands with the player).
  void _slamShockwave(Player p, double mul) {
    shake = max(shake, 0.38);
    _fx('crack', p.cx, p.y + p.h, 0.5, const Color(0xFFFFB300), size: 300);
    _fx('ring', p.cx, p.y + p.h, 0.32, const Color(0xFFFFD166), size: 95);
    for (final e in [...enemies, if (boss != null) boss!]) {
      if ((e.cx - p.cx).abs() < 290 && (e.cy - p.cy).abs() < 130) {
        if (e is Boss) {
          _damageBoss(e, 26 * mul);
        } else {
          e.damage(26 * mul);
        }
        final dir = e.cx >= p.cx ? 1 : -1;
        if (e is Enemy) {
          e.vx = dir * 260.0;
          e.vy = -300;
        }
        _hitSpark(e.cx, e.cy, dir);
      }
    }
    for (int i = 0; i < 22; i++) {
      final a = (i / 22) * pi;
      particles.add(Particle(p.cx, p.y + p.h, cos(a) * 300, -sin(a) * 220, 0.5,
          7, const Color(0xFFFFB300),
          grav: 700));
    }
  }

  // 3rd-combo finisher: a flashy bonus burst, flavored by skull category and
  // amplified by tier (higher tier = more damage + extra rings).
  void _finisher(Player p, double mul) {
    final sk = p.skull;
    double tb; // tier amplifier
    switch (sk.tier) {
      case SkullTier.common:
        tb = 1.0;
        break;
      case SkullTier.rare:
        tb = 1.2;
        break;
      case SkullTier.epic:
        tb = 1.45;
        break;
      case SkullTier.legendary:
        tb = 1.8;
        break;
    }
    final facing = p.facing.toDouble();
    final col = sk.eye;
    final cat = sk.category;
    String fxKind;
    double reach, half, dmg;
    if (cat == '짐승형') {
      fxKind = 'claw';
      reach = 130;
      half = 72;
      dmg = 14;
    } else if (cat == '기사') {
      fxKind = 'crack';
      reach = 175;
      half = 74;
      dmg = 16;
    } else if (cat == '마법형') {
      fxKind = 'ring';
      reach = 120;
      half = 110;
      dmg = 14;
    } else if (cat == '권사') {
      fxKind = 'claw';
      reach = 110;
      half = 52;
      dmg = 15;
    } else if (cat == '창병') {
      fxKind = 'slashArc';
      reach = 165;
      half = 46;
      dmg = 14;
    } else if (cat == '궁수형') {
      fxKind = 'slashArc';
      reach = 120;
      half = 42;
      dmg = 11;
    } else if (sk.weapon == 'scythe') {
      // wraith / reaper / spectreKnight / voidlord: sweeping great scythe
      fxKind = 'slashArc';
      reach = 165;
      half = 88;
      dmg = 17;
    } else {
      // 검사 / 특수형 default: heavy horizontal slash
      fxKind = 'slashArc';
      reach = 145;
      half = 70;
      dmg = 15;
    }
    dmg = dmg * tb * mul;
    final left = facing >= 0 ? p.cx : p.cx - reach;
    final area = Rect.fromLTWH(left, p.cy - half, reach, half * 2);
    for (final e in [...enemies, if (boss != null) boss!]) {
      if (area.overlaps(e.rect)) {
        if (e is Boss) {
          _damageBoss(e, dmg);
        } else {
          e.damage(dmg);
        }
        final dir = e.cx >= p.cx ? 1 : -1;
        if (e is Enemy && e.kind != EnemyKind.bat) {
          e.vx = dir * 360.0;
          e.vy = -180;
        }
        _hitSpark(e.cx, e.cy, dir);
      }
    }
    shake = max(shake, 0.2);
    if (fxKind == 'crack') {
      _fx('crack', p.cx, p.y + p.h, 0.45, col, size: reach);
      _fx('ring', p.cx, p.y + p.h, 0.3, col, size: 72);
    } else if (fxKind == 'ring') {
      _fx('ring', p.cx, p.cy, 0.4, col, size: 115);
    } else {
      _fx(fxKind, p.cx, p.cy, 0.34, col, dir: facing, size: reach * 0.8);
    }
    // higher tiers get richer accents
    if (sk.tier == SkullTier.epic || sk.tier == SkullTier.legendary) {
      _fx('ring', p.cx, p.cy, 0.45, col, size: reach * 0.9);
    }
    if (sk.tier == SkullTier.legendary) {
      _fx('dualring', p.cx, p.cy, 0.5, const Color(0xFFFFFFFF), size: reach);
    }
    // 리치: the 3rd-hit finisher hurls a black crescent of dark sword-energy.
    if (sk.type == SkullType.lich) {
      projectiles.add(Projectile(p.cx + facing * 18, p.cy - 4, facing * 520.0, 0,
          22, 1.4, dmg * 0.9, false, const Color(0xFF1A0A24),
          shape: 'swordwave', pierce: true));
      _fx('slashArc', p.cx + facing * 30, p.cy, 0.3, const Color(0xFF7E1FA0),
          dir: facing, size: 96);
    }
    // 용기병: a 3-combo finisher while airborne (용의 비상) launches a forward
    // dragon-dash that gores every monster along its path.
    if (sk.type == SkullType.dragoon && p.flyTimer > 0) {
      final fromX = p.cx;
      p.x = (p.x + facing * 300).clamp(20.0, roomWidth - p.w - 20);
      p.invuln = max(p.invuln, 0.3);
      final lo = min(fromX, p.cx) - 30, hi = max(fromX, p.cx) + 30;
      for (final e in [...enemies, if (boss != null) boss!]) {
        if (e.cx >= lo && e.cx <= hi && (e.cy - p.cy).abs() < 120) {
          if (e is Boss) {
            _damageBoss(e, 30 * mul);
          } else {
            e.damage(30 * mul);
            final dir = e.cx >= fromX ? 1 : -1;
            if (e is Enemy && e.kind != EnemyKind.bat) {
              e.vx = dir * 360.0;
              e.vy = -180;
            }
          }
          _hitSpark(e.cx, e.cy, p.facing);
        }
      }
      _fx('dragon', p.cx, p.cy - 2, 0.34, col, dir: facing, size: 120);
      for (double t = 0; t <= 1; t += 0.08) {
        particles.add(Particle(lo + (hi - lo) * t, p.cy, 0, 0, 0.3, 6,
            col.withOpacity(0.7),
            grav: 0));
      }
      shake = max(shake, 0.18);
    }
  }

  // ----------------------------------------------------------------
  // perception
  void _emitNoise(double x, double y, double dur) {
    if (dur > combatNoise) combatNoise = dur;
    noiseX = x;
    noiseY = y;
  }

  bool _lineOfSight(Entity a, Entity b) {
    const steps = 14;
    for (int i = 1; i < steps; i++) {
      final t = i / steps;
      final x = a.cx + (b.cx - a.cx) * t;
      final y = a.cy + (b.cy - a.cy) * t;
      for (final s in solids) {
        if (s.contains(Offset(x, y))) return false;
      }
    }
    return true;
  }

  void _updateEnemyAggro(Enemy e, double dt) {
    final p = player;
    if (e.aggroTimer > 0) e.aggroTimer -= dt;
    if (e.jumpCd > 0) e.jumpCd -= dt;
    if (e.dropTimer > 0) e.dropTimer -= dt;
    // 사신 유령화 / 야밤도 그림자 잠행: the player is imperceptible — drop aggro
    if (p.ghostTimer > 0 || p.stealthTimer > 0) {
      e.aggro = false;
      e.aggroTimer = 0;
      return;
    }
    final dx = (p.cx - e.cx).abs();
    final dy = (p.cy - e.cy).abs();
    bool sees = false;
    // sight: roughly the same vertical level, in range, no wall between.
    // dy gate stops enemies from noticing a player a platform above/below.
    if (!p.hidden && dx < 460 && dy < 90 && _lineOfSight(e, p)) sees = true;
    // a recent attack/impact noise wakes nearby enemies even without sight
    if (combatNoise > 0 &&
        (e.cx - noiseX).abs() < 380 &&
        (e.cy - noiseY).abs() < 170) {
      sees = true;
    }
    if (sees) {
      e.aggro = true;
      e.aggroTimer = 3.5;
    } else {
      if (p.hidden) e.aggroTimer = min(e.aggroTimer, 0.3);
      if (e.aggroTimer <= 0) e.aggro = false;
    }
  }

  /// Ground melee navigation: chase when aggro (jumping up / dropping down
  /// platforms to follow), otherwise patrol back and forth.
  void _groundNav(Enemy e, double dt, double chaseSpeed, double patrolSpeed) {
    final p = player;
    final dx = p.cx - e.cx;
    if (e.aggro) {
      e.facing = dx > 0 ? 1 : -1;
      e.vx = e.facing * chaseSpeed;
      final blocked = !_groundAhead(e) || _wallAhead(e);
      if (e.onGround && e.jumpCd <= 0) {
        final wantUp = p.cy < e.cy - 50 && dx.abs() < 280;
        if (wantUp || blocked) {
          e.vy = -820;
          e.jumpCd = 0.9;
        }
      }
      // drop through a one-way platform to reach a player below
      if (e.onGround && p.cy > e.cy + 60 && dx.abs() < 200) {
        e.dropTimer = 0.25;
      }
    } else {
      e.vx = e.facing * patrolSpeed;
      if (!_groundAhead(e) || _wallAhead(e)) {
        e.facing = -e.facing;
        e.vx = e.facing * patrolSpeed;
      }
    }
  }

  // ----------------------------------------------------------------
  // enemies
  void _updateEnemy(Enemy e, double dt) {
    e.animTime += dt;
    _updateStatuses(e, dt);
    if (e.hitFlash > 0) e.hitFlash -= dt;
    if (e.hurtTimer > 0) e.hurtTimer -= dt;
    if (e.attackAnim > 0) e.attackAnim -= dt;
    if (e.windup > 0) e.windup -= dt;
    // stunned enemies cannot act — just fall and slide to a stop
    if (e.hasStatus(StatusKind.stun) || e.hasStatus(StatusKind.bind)) {
      e.vy += kGravity * dt;
      e.vx *= 0.8;
      _moveAndCollide(e, dt);
      return;
    }
    final p = player;
    final dx = p.cx - e.cx;
    final dist = dx.abs();

    switch (e.kind) {
      case EnemyKind.grunt:
        e.vy += kGravity * dt;
        e.atkCd -= dt;
        e.t2 -= dt;
        if (e.t2 > 0) {
          e.vx = e.facing * 280; // mid lunge bite
        } else if (e.aggro && dist < 80 && e.onGround && e.atkCd <= 0) {
          e.facing = dx > 0 ? 1 : -1;
          e.t2 = 0.18;
          e.atkCd = 1.3;
          e.attackAnim = 0.28;
          e.vx = e.facing * 280;
        } else {
          _groundNav(e, dt, 150, 70);
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.bat:
        e.facing = dx > 0 ? 1 : -1;
        if (e.aggro) {
          final ang = atan2((p.cy - 30) - e.cy, p.cx - e.cx);
          e.vx = cos(ang) * 175;
          e.vy = sin(ang) * 175 + sin(e.animTime * 6 + e.phase) * 45;
        } else {
          // hover lazily around its spawn height
          e.vx = sin(e.animTime * 0.8 + e.phase) * 40;
          e.vy = (e.homeY - e.cy) * 1.6 + sin(e.animTime * 4 + e.phase) * 28;
        }
        e.x += e.vx * dt;
        e.y += e.vy * dt;
        e.x = e.x.clamp(20.0, roomWidth - e.w - 20);
        e.y = e.y.clamp(40.0, kGroundY - e.h);
        break;
      case EnemyKind.gargoyle:
        e.atkCd -= dt;
        e.t2 -= dt;
        if (e.t2 > 0) {
          // mid dive — velocity was set at dive start, just coast
        } else if (e.aggro && dist < 400 && e.atkCd <= 0) {
          e.atkCd = 2.2 + rng.nextDouble();
          e.t2 = 0.45;
          final ang = atan2(p.cy - e.cy, p.cx - e.cx);
          e.vx = cos(ang) * 500;
          e.vy = sin(ang) * 500;
          e.facing = e.vx >= 0 ? 1 : -1;
        } else if (e.aggro) {
          final ang = atan2((p.cy - 70) - e.cy, p.cx - e.cx);
          e.vx = cos(ang) * 120;
          e.vy = sin(ang) * 120 + sin(e.animTime * 5 + e.phase) * 30;
          e.facing = dx > 0 ? 1 : -1;
        } else {
          e.vx = sin(e.animTime * 0.7 + e.phase) * 30;
          e.vy = (e.homeY - e.cy) * 1.4;
        }
        e.x += e.vx * dt;
        e.y += e.vy * dt;
        e.x = e.x.clamp(20.0, roomWidth - e.w - 20);
        e.y = e.y.clamp(30.0, kGroundY - e.h);
        break;
      case EnemyKind.ghoul:
        e.vy += kGravity * dt;
        e.atkCd -= dt;
        e.t2 -= dt;
        if (e.t2 > 0) {
          e.vx = e.facing * 300;
        } else if (e.aggro && dist < 110 && e.onGround && e.atkCd <= 0) {
          e.facing = dx > 0 ? 1 : -1;
          e.t2 = 0.28;
          e.atkCd = 1.4 + rng.nextDouble() * 0.5;
          e.attackAnim = 0.3;
          e.vx = e.facing * 300;
          e.vy = -120;
        } else {
          _groundNav(e, dt, 110, 55);
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.mage:
        e.vy += kGravity * dt;
        e.vx = 0;
        e.facing = dx > 0 ? 1 : -1;
        e.atkCd -= dt;
        if (e.aggro && dist < 580 && e.atkCd <= 0) {
          e.atkCd = 2.2 + rng.nextDouble();
          e.attackAnim = 0.3;
          final ang = atan2(p.cy - e.cy, p.cx - e.cx);
          projectiles.add(Projectile(e.cx, e.cy - 6, cos(ang) * 320,
              sin(ang) * 320, 9, 3.0, 11, true, const Color(0xFFB388FF)));
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.fireMage:
        e.vy += kGravity * dt;
        e.vx = 0;
        e.facing = dx > 0 ? 1 : -1;
        e.atkCd -= dt;
        if (e.aggro && dist < 560 && e.atkCd <= 0) {
          e.atkCd = 2.4 + rng.nextDouble();
          e.attackAnim = 0.3;
          final ang = atan2(p.cy - e.cy, p.cx - e.cx);
          projectiles.add(Projectile(e.cx, e.cy - 6, cos(ang) * 300,
              sin(ang) * 300, 10, 3.0, 11, true, const Color(0xFFFF7043),
              shape: 'orb',
              onHit: StatusKind.burn,
              onHitDur: 3.0,
              onHitPow: _foePow(5)));
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.slime:
        e.vy += kGravity * dt;
        if (e.aggro) e.facing = dx > 0 ? 1 : -1;
        e.atkCd -= dt;
        if (e.onGround) {
          if (e.aggro && e.atkCd <= 0) {
            e.vy = -540;
            e.vx = e.facing * 170;
            e.atkCd = 0.8 + rng.nextDouble() * 0.7;
            e.attackAnim = 0.35;
          } else {
            e.vx *= 0.8;
          }
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.archer:
        e.vy += kGravity * dt;
        e.facing = dx > 0 ? 1 : -1;
        e.atkCd -= dt;
        // kite: back away if the player gets too close
        if (e.aggro && dist < 180 && e.onGround) {
          e.vx = -e.facing * 90;
          if (!_groundAhead(e) || _wallAhead(e)) e.vx = 0;
        } else {
          e.vx = 0;
        }
        if (e.aggro && dist < 640 && dist > 120 && e.atkCd <= 0) {
          e.atkCd = 1.7 + rng.nextDouble();
          e.attackAnim = 0.3;
          final ang = atan2(p.cy - e.cy, p.cx - e.cx);
          projectiles.add(Projectile(e.cx, e.cy - 6, cos(ang) * 470,
              sin(ang) * 470, 6, 2.6, 10, true, const Color(0xFFFFCC80)));
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.brute:
        e.vy += kGravity * dt;
        e.atkCd -= dt;
        e.t2 -= dt;
        if (e.t2 > 0) {
          e.vx = e.facing * 430; // mid-lunge
        } else if (e.aggro && dist < 360 && e.atkCd <= 0) {
          e.facing = dx > 0 ? 1 : -1;
          e.t2 = 0.4;
          e.atkCd = 2.4;
          e.vx = e.facing * 430;
          e.attackAnim = 0.4;
        } else {
          _groundNav(e, dt, 110, 45);
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.goblin:
        // fast, jittery skirmisher with a quick dash bite
        e.vy += kGravity * dt;
        e.atkCd -= dt;
        e.t2 -= dt;
        if (e.t2 > 0) {
          e.vx = e.facing * 360;
        } else if (e.aggro && dist < 90 && e.onGround && e.atkCd <= 0) {
          e.facing = dx > 0 ? 1 : -1;
          e.t2 = 0.16;
          e.atkCd = 0.9;
          e.attackAnim = 0.24;
          e.vx = e.facing * 360;
        } else {
          _groundNav(e, dt, 210, 95);
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.assassin:
        // dashing lunger: closes long gaps fast, then darts in with a leap
        e.vy += kGravity * dt;
        e.atkCd -= dt;
        e.t2 -= dt;
        if (e.t2 > 0) {
          e.vx = e.facing * 460;
        } else if (e.aggro && dist < 230 && e.onGround && e.atkCd <= 0) {
          e.facing = dx > 0 ? 1 : -1;
          e.t2 = 0.22;
          e.atkCd = 1.2 + rng.nextDouble() * 0.5;
          e.attackAnim = 0.28;
          e.vx = e.facing * 460;
          e.vy = -170; // small leap into the lunge
        } else {
          _groundNav(e, dt, 235, 115);
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.heretic:
        e.vy += kGravity * dt;
        e.vx = 0;
        e.facing = dx > 0 ? 1 : -1;
        e.atkCd -= dt;
        if (e.aggro && dist < 600 && e.atkCd <= 0) {
          e.atkCd = 2.0 + rng.nextDouble();
          e.attackAnim = 0.3;
          final ang = atan2(p.cy - e.cy, p.cx - e.cx);
          projectiles.add(Projectile(e.cx, e.cy - 8, cos(ang) * 280,
              sin(ang) * 280, 9, 3.2, 10, true, const Color(0xFFCE93D8),
              shape: 'orb',
              onHit: StatusKind.weaken,
              onHitDur: 4.0,
              onHitPow: 1));
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.thief:
        e.vy += kGravity * dt;
        e.atkCd -= dt;
        e.t2 -= dt;
        if (e.t2 > 0) {
          e.vx = -e.facing * 300; // flee after the snatch
        } else if (e.aggro && dist < 130 && e.onGround && e.atkCd <= 0) {
          e.facing = dx > 0 ? 1 : -1;
          e.t2 = 0.5;
          e.atkCd = 1.8;
          e.attackAnim = 0.24;
          e.vx = e.facing * 380; // dart in
        } else {
          _groundNav(e, dt, 220, 100);
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.knightSoldier:
        e.vy += kGravity * dt;
        e.atkCd -= dt;
        e.t2 -= dt;
        if (e.windup > 0) {
          e.vx = 0;
          e.windup -= dt;
          if (e.windup <= 0) e.t2 = 0.2; // release the lunge after telegraph
        } else if (e.t2 > 0) {
          e.vx = e.facing * 320;
        } else if (e.aggro && dist < 120 && e.onGround && e.atkCd <= 0) {
          e.facing = dx > 0 ? 1 : -1;
          e.windup = 0.4;
          e.atkCd = 2.0;
          e.attackAnim = 0.6;
          e.vx = 0;
        } else {
          _groundNav(e, dt, 130, 70);
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.brawler:
        e.vy += kGravity * dt;
        e.atkCd -= dt;
        e.t2 -= dt;
        if (e.t2 > 0) {
          e.vx = e.facing * 210;
        } else if (e.aggro && dist < 80 && e.onGround && e.atkCd <= 0) {
          e.facing = dx > 0 ? 1 : -1;
          e.t2 = 0.3;
          e.atkCd = 0.8;
          e.attackAnim = 0.3;
          e.vx = e.facing * 210;
        } else {
          _groundNav(e, dt, 185, 95);
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.dwarf:
        // slow, stubborn bruiser; heavy melee shove (knockback on contact)
        e.vy += kGravity * dt;
        e.atkCd -= dt;
        e.t2 -= dt;
        if (e.t2 > 0) {
          e.vx = e.facing * 220;
        } else if (e.aggro && dist < 100 && e.onGround && e.atkCd <= 0) {
          e.facing = dx > 0 ? 1 : -1;
          e.t2 = 0.3;
          e.atkCd = 1.8;
          e.attackAnim = 0.34;
          e.vx = e.facing * 220;
        } else {
          _groundNav(e, dt, 95, 40);
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.darkElf:
        // ranged caster firing cursed bolts that bleed
        e.vy += kGravity * dt;
        e.facing = dx > 0 ? 1 : -1;
        e.atkCd -= dt;
        // kite away if the player closes in
        if (e.aggro && dist < 200 && e.onGround) {
          e.vx = -e.facing * 110;
          if (!_groundAhead(e) || _wallAhead(e)) e.vx = 0;
        } else {
          e.vx = 0;
        }
        if (e.aggro && dist < 620 && dist > 120 && e.atkCd <= 0) {
          e.atkCd = 1.9 + rng.nextDouble();
          e.attackAnim = 0.3;
          final ang = atan2(p.cy - e.cy, p.cx - e.cx);
          projectiles.add(Projectile(e.cx, e.cy - 6, cos(ang) * 430,
              sin(ang) * 430, 7, 2.8, 9, true, const Color(0xFFCE93D8),
              onHit: StatusKind.bleed, onHitDur: 3.5, onHitPow: 5));
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.plant:
        _updatePlant(e, dt, dist);
        break;
      case EnemyKind.hammer:
        // heavy slow walker; winds up a ground slam that stuns + launches
        e.vy += kGravity * dt;
        e.atkCd -= dt;
        if (e.windup > 0) {
          e.vx = 0;
          if (e.windup <= dt && e.onGround) _hammerSlam(e); // slam on release
        } else if (e.aggro && dist < 120 && e.onGround && e.atkCd <= 0) {
          e.facing = dx > 0 ? 1 : -1;
          e.windup = 0.55; // telegraph
          e.atkCd = 2.6;
          e.attackAnim = 0.55;
          e.vx = 0;
        } else {
          _groundNav(e, dt, 85, 35);
        }
        _moveAndCollide(e, dt);
        break;
      case EnemyKind.shield:
        // defensive guard: raises a shield (blocks frontal melee), bashes up close
        e.vy += kGravity * dt;
        if (shieldCrystal != null) e.t2 = 1.0; // crystal keeps the shield up
        e.atkCd -= dt;
        if (e.t2 > 0) e.t2 -= dt; // t2>0 == shield raised (guarding)
        if (e.aggro && dist < 96 && e.onGround && e.atkCd <= 0 && e.t2 <= 0) {
          e.facing = dx > 0 ? 1 : -1;
          e.atkCd = 1.6;
          e.attackAnim = 0.3;
          e.vx = e.facing * 170; // shove
        } else if (e.aggro && e.t2 <= 0 && e.atkCd <= 0.9 &&
            rng.nextDouble() < 0.02) {
          e.t2 = 1.6; // raise shield for a while
        } else if (e.t2 <= 0) {
          _groundNav(e, dt, 95, 40);
        } else {
          // shuffle forward slowly behind the shield
          e.facing = dx > 0 ? 1 : -1;
          e.vx = e.facing * 45;
        }
        _moveAndCollide(e, dt);
        break;
    }
  }

  double _groundTopAt(double x) {
    for (final g in groundSegments) {
      if (x >= g.left && x <= g.right) return g.top;
    }
    return kGroundY;
  }

  // Plant trap monster, by variant. Emerges (t2: 0→1) only under its trigger
  // condition and retracts (t2→0) otherwise, so it stays hidden — from the
  // player and the minimap — until it strikes.
  void _updatePlant(Enemy e, double dt, double dist) {
    final p = player;
    e.vx = 0;
    e.vy += kGravity * dt;

    if (e.plantVariant == 3) {
      // overhead ambush: rises ONLY when the player passes above it, then lashes
      // up to bind. Invisible until triggered.
      final above =
          (p.cx - e.cx).abs() < 60 && p.cy < e.cy - 20 && p.cy > e.cy - 220;
      if (above) {
        e.aggro = true;
        if (e.t2 < 1) e.t2 = min(1, e.t2 + dt * 6); // snap up fast
        e.atkCd -= dt;
        if (e.t2 >= 1 && e.atkCd <= 0) {
          e.atkCd = 2.0;
          e.attackAnim = 0.3;
          if (p.invuln <= 0 && (p.cx - e.cx).abs() < 52) {
            _hurtPlayer(8, e.cx);
            p.addStatus(StatusKind.bind, 1.2, 1);
          }
          _fx('handrise', e.cx, e.cy - 6, 0.4, const Color(0xFF66BB6A),
              size: 64);
        }
      } else {
        e.aggro = false;
        if (e.t2 > 0) e.t2 = max(0, e.t2 - dt * 2);
      }
      _moveAndCollide(e, dt);
      return;
    }

    // variants 0/1/2: ranged ambush — emerge when the player is nearby
    final near = dist < 190 && (p.cy - e.cy).abs() < 90;
    if (near) {
      e.aggro = true;
      if (e.t2 < 1) e.t2 = min(1, e.t2 + dt * 4); // emerge
      e.atkCd -= dt;
      if (e.t2 >= 1 && e.atkCd <= 0) {
        e.attackAnim = 0.3;
        final ang = atan2(p.cy - e.cy, p.cx - e.cx);
        if (e.plantVariant == 2) {
          // fireball plant: burning orb
          e.atkCd = 1.8 + rng.nextDouble();
          projectiles.add(Projectile(e.cx, e.cy - 8, cos(ang) * 320,
              sin(ang) * 320, 9, 2.6, 9, true, const Color(0xFFFF7043),
              shape: 'ball',
              onHit: StatusKind.burn,
              onHitDur: 2.5,
              onHitPow: _foePow(5)));
        } else {
          // poison spitter (variant 0, and the teleporter before it blinks)
          e.atkCd = 1.6 + rng.nextDouble();
          projectiles.add(Projectile(e.cx, e.cy - 8, cos(ang) * 300,
              sin(ang) * 300, 8, 2.6, 8, true, const Color(0xFF9CCC65),
              onHit: StatusKind.poison,
              onHitDur: 3.5,
              onHitPow: _foePow(5)));
        }
        // teleporter: blink to a fresh ambush spot after spitting
        if (e.plantVariant == 1) _plantBlink(e);
      }
    } else {
      e.aggro = false;
      if (e.t2 > 0) e.t2 = max(0, e.t2 - dt * 2); // retract
    }
    _moveAndCollide(e, dt);
  }

  // Teleporter plant: vanish in a puff and resurface on the ground elsewhere,
  // offset from the player, then re-ambush from there.
  void _plantBlink(Enemy e) {
    for (int i = 0; i < 10; i++) {
      final a = rng.nextDouble() * pi * 2;
      particles.add(Particle(e.cx, e.cy, cos(a) * 120, sin(a) * 120 - 30, 0.4, 4,
          const Color(0xFFB388FF),
          grav: 60));
    }
    final side = rng.nextBool() ? 1 : -1;
    final nx = (player.cx + side * (150 + rng.nextDouble() * 160))
        .clamp(40.0, roomWidth - 40 - e.w);
    e.x = nx;
    e.y = _groundTopAt(e.cx) - e.h;
    e.t2 = 0; // sink and re-emerge from the new position
    e.atkCd = 0.7;
    for (int i = 0; i < 10; i++) {
      final a = rng.nextDouble() * pi * 2;
      particles.add(Particle(e.cx, e.cy, cos(a) * 120, sin(a) * 120 - 30, 0.4, 4,
          const Color(0xFFB388FF),
          grav: 60));
    }
  }

  // ----------------------------------------------------------------
  // boss
  void _updateBoss(Boss b, double dt) {
    b.animTime += dt;
    if (b.hitFlash > 0) b.hitFlash -= dt;
    if (b.hurtTimer > 0) b.hurtTimer -= dt;
    if (b.subTimer > 0) b.subTimer -= dt;
    if (b.guard > 0) b.guard -= dt;
    if (!b.enraged && b.hp < b.maxHp * 0.5) {
      b.enraged = true;
      _banner('${b.name}이(가) 분노한다!', 1.4);
      shake = max(shake, 0.3);
    }
    final p = player;
    final lockFacing = b.state == BossState.active &&
        (b.pattern == 'charge' ||
            b.pattern == 'smash' ||
            b.pattern == 'wideslash' ||
            b.pattern == 'triplesmash' ||
            b.pattern == 'divebomb' ||
            b.pattern == 'swoop' ||
            b.pattern == 'approach');
    if (!lockFacing) {
      b.facing = p.cx >= b.cx ? 1 : -1;
    }
    // keep flyers aloft through every telegraph (windup) and the active/recover
    // of their aerial skills (casts, feathers, repositions). The active phase of
    // a ground-dive — and the exhausted rest — let gravity carry them down.
    if (_isFlying(b) && b.pattern != 'rest') {
      final aerial = b.state == BossState.windup ||
          (b.state != BossState.idle &&
              b.pattern != 'divebomb' &&
              b.pattern != 'teleslam' &&
              b.pattern != 'swoop');
      if (aerial) {
        b.hover = max(b.hover, 0.1);
        if (b.hoverTargetY == 0) b.hoverTargetY = kGroundY - 250;
      }
    }
    // flyers (witch/eagle) float while aloft; gravity only pulls them down when
    // they are exhausted (resting) or mid ground-dive.
    if (b.hover > 0) {
      b.hover -= dt;
      final dy = b.hoverTargetY - b.y;
      b.vy = dy.clamp(-150.0, 150.0);
      b.airborne = true;
    } else {
      b.vy += kGravity * dt;
    }
    b.stateTimer -= dt;

    switch (b.state) {
      case BossState.idle:
        b.atkCd -= dt;
        final dxx = p.cx - b.cx;
        // keep flyers aloft and gently circling; ground bosses stroll closer
        if (_isFlying(b)) {
          _hoverIdle(b, dxx);
        } else {
          b.vx = dxx.abs() > 120 ? b.facing * b.spec.walkSpeed * 0.5 : 0;
        }
        // pull the next step from the themed playbook (refill when drained)
        if (b.atkCd <= 0 && dxx.abs() < 920) {
          if (b.queue.isEmpty) b.queue.addAll(_bossPlaybook(b));
          var step = b.queue.removeAt(0);
          if (step == 'rand') step = _pickBossSkill(b);
          b.pattern = step;
          b.state = BossState.windup;
          b.stateTimer = _bossWindup(b);
          b.vx = 0;
          if (b.pattern == 'beam') b.guard = b.stateTimer; // charge behind shield
        }
        _moveAndCollide(b, dt, oneWay: false);
        break;
      case BossState.windup:
        b.vx = 0;
        _moveAndCollide(b, dt, oneWay: false);
        if (b.stateTimer <= 0) _bossStartAttack(b);
        break;
      case BossState.active:
        _bossActive(b, dt);
        break;
      case BossState.recover:
        b.vx *= 0.8;
        _moveAndCollide(b, dt, oneWay: false);
        if (b.stateTimer <= 0) {
          b.state = BossState.idle;
          // short, readable gap between steps so the playbook flows as a combo
          final base = b.enraged ? 0.3 : 0.55;
          b.atkCd = base + rng.nextDouble() * 0.35;
        }
        break;
    }
  }

  bool _isFlying(Boss b) =>
      b.spec.visual == 'witch' || b.spec.visual == 'eagle';

  // keep a flyer aloft, bobbing and drifting toward the player between attacks
  void _hoverIdle(Boss b, double dxx) {
    b.hover = 0.2;
    b.hoverTargetY = (kGroundY - 250) + sin(b.animTime * 2) * 18;
    b.vx = dxx.abs() > 220 ? b.facing * b.spec.walkSpeed * 0.8 : b.vx * 0.9;
  }

  // Each boss runs a themed, ORDERED playbook (one cycle's worth of steps) that
  // weaves basics, repositions, defence and signature skills so its fight reads
  // as a distinct combo rather than random single attacks. 'rand' slots resolve
  // to a pick from the boss's signature skill pool at dequeue time. When the
  // queue drains it is refilled with a fresh cycle.
  List<String> _bossPlaybook(Boss b) {
    switch (b.spec.visual) {
      // ---- grounded bruisers: pummel, close gaps, guard, big skills ----
      case 'boar':
      case 'redBear':
      case 'wolfKing':
        return const ['basic', 'basic', 'charge', 'basic', 'rand', 'approach',
          'basic', 'rand', 'guard', 'rand', 'charge', 'rand'];
      case 'goblin':
        return const ['basic', 'guard', 'basic', 'approach', 'rand', 'basic',
          'rand', 'guard', 'rand', 'approach', 'rand'];
      case 'golem':
      case 'rockBrute':
        return const ['basic', 'basic', 'approach', 'rand', 'basic', 'rand',
          'guard', 'rand', 'approach', 'rand'];
      // ---- swordmasters: pressure with basics, dash, parry-guard, skills ----
      case 'knight':
      case 'doppel':
        return const ['basic', 'basic', 'approach', 'basic', 'rand', 'guard',
          'rand', 'approach', 'basic', 'rand', 'rand'];
      case 'mercenary':
        return const ['basic', 'basic', 'approach', 'rand', 'basic', 'rand',
          'guard', 'approach', 'rand', 'rand'];
      case 'bandit':
        return const ['basic', 'approach', 'basic', 'rand', 'reposition',
          'rand', 'basic', 'rand', 'reposition', 'rand'];
      case 'dragonkin':
        return const ['basic', 'approach', 'basic', 'rand', 'basic', 'rand',
          'guard', 'rand', 'approach', 'rand'];
      // ---- spellcasters: keep distance, weave casts, shield, repeat ----
      case 'witch':
        // soar and rain magic, then descend exhausted (마나탈진) to be punished
        return const ['rand', 'reposition', 'rand', 'rand', 'reposition',
          'rand', 'rest'];
      case 'demonKing':
        return const ['rand', 'reposition', 'rand', 'basic', 'rand', 'guard',
          'rand', 'reposition', 'rand', 'rand'];
      case 'mummy':
        return const ['rand', 'approach', 'basic', 'rand', 'reposition', 'rand',
          'guard', 'rand', 'rand'];
      case 'spider':
        return const ['rand', 'reposition', 'rand', 'basic', 'rand', 'rand',
          'reposition', 'rand'];
      // ---- eagle: aerial harassment, low sweeps, then a tired landing ----
      case 'eagle':
        return const ['feathers', 'swoop', 'feathers', 'divebomb', 'swoop',
          'rest'];
      // ---- exploding apple tree: rooted; scatters apples, raises roots ----
      case 'appleTree':
        return const ['appleScatter', 'basic', 'roots', 'guard', 'appleScatter',
          'roots', 'rand', 'guard'];
      // ---- great worm: burrow, erupt, slam ----
      case 'worm':
        return const ['leap', 'smash', 'basic', 'triplesmash', 'approach',
          'smash', 'rand'];
      // ---- dragon: breathe fire, dive, charge ----
      case 'dragon':
        return const ['firebreath', 'basic', 'approach', 'divebomb', 'rand',
          'charge', 'rand'];
    }
    // fallback for any unthemed boss: simple basics + its legacy archetype skill
    final legacy = () {
      switch (b.spec.archetype) {
        case BossArchetype.charger:
          return 'charge';
        case BossArchetype.caster:
          return 'cast';
        case BossArchetype.jumper:
          return 'leap';
        case BossArchetype.boarSmash:
          return 'smash';
        case BossArchetype.iaido:
          return 'iaido';
        case BossArchetype.flurry:
          return 'flurry';
        case BossArchetype.guardian:
          return 'guard';
      }
    }();
    return ['basic', 'basic', 'approach', legacy, 'guard', legacy];
  }

  // Signature-skill pool that fills the 'rand' slots in a boss's playbook.
  // Orb projectiles ('cast') are reserved for genuine spellcasters; every other
  // boss expresses itself through themed melee / AoE / shaped projectiles.
  List<String> _bossSkillPool(Boss b) {
    switch (b.spec.visual) {
      case 'knight':
        return const ['teleslam', 'beam', 'iaido', 'swordbeam'];
      case 'mercenary':
        return const ['flurry', 'wideslash', 'swordbeam'];
      case 'bandit':
        return const ['knives', 'flurry', 'wideslash'];
      case 'doppel':
        return const ['iaido', 'flurry', 'knives', 'swordbeam'];
      case 'dragonkin':
        return const ['wideslash', 'swordbeam', 'divebomb', 'firebreath'];
      case 'witch':
        return const ['cast', 'vortex', 'teleslam'];
      case 'demonKing':
        return const ['cast', 'teleslam', 'vortex', 'beam', 'wideslash'];
      case 'mummy':
        return const ['flurry', 'wideslash', 'vortex'];
      case 'spider':
        return const ['webshot', 'vortex', 'teleslam', 'wideslash'];
      case 'goblin':
        return const ['smash', 'wideslash'];
      case 'boar':
        return const ['smash', 'wideslash', 'charge'];
      case 'redBear':
      case 'golem':
      case 'rockBrute':
        return const ['smash', 'triplesmash', 'wideslash', 'leap'];
      case 'wolfKing':
        return const ['charge', 'smash', 'flurry'];
      case 'eagle':
        return const ['feathers', 'swoop', 'divebomb'];
      case 'appleTree':
        return const ['appleScatter', 'roots'];
      case 'worm':
        return const ['smash', 'leap', 'triplesmash'];
      case 'dragon':
        return const ['firebreath', 'divebomb', 'charge', 'wideslash'];
    }
    return const ['wideslash'];
  }

  String _pickBossSkill(Boss b) {
    final pool = _bossSkillPool(b);
    if (pool.length == 1) return pool.first;
    String pick = pool.first;
    for (int i = 0; i < 5; i++) {
      pick = pool[rng.nextInt(pool.length)];
      if (pick != b.pattern) break; // avoid repeating the same skill back-to-back
    }
    return pick;
  }

  double _bossWindup(Boss b) {
    switch (b.pattern) {
      case 'basic':
        return 0.4; // brief but clearly visible tell before a melee swipe
      case 'iaido':
        return 1.0; // long telegraph before the quick draw
      case 'beam':
        return b.enraged ? 0.9 : 1.3; // charge up behind a shield
      case 'teleslam':
        return 0.5;
      case 'guard':
        return 0.3;
      case 'smash':
        return 0.5;
      case 'triplesmash':
        return 0.5;
      case 'swordbeam':
        return 0.7;
      case 'divebomb':
        return 0.4;
      case 'vortex':
        return 0.7;
      case 'approach':
        return 0.12; // near-instant reposition
      case 'reposition':
        return 0.12;
      case 'rest':
        return 0.15;
      case 'appleScatter':
        return 0.6;
      case 'roots':
        return 0.7;
      case 'feathers':
        return 0.4;
      case 'swoop':
        return 0.5;
      case 'firebreath':
        return 0.6;
      case 'knives':
        return 0.35;
      case 'webshot':
        return 0.5;
      default:
        return 0.55;
    }
  }

  void _bossStartAttack(Boss b) {
    b.state = BossState.active;
    final p = player;
    switch (b.pattern) {
      case 'basic':
        // lunging melee swipe after the telegraph
        b.stateTimer = 0.28;
        b.vx = b.facing * 130;
        _bossSlash(b, 150, b.enraged ? 16 : 11, 260);
        shake = max(shake, 0.14);
        break;
      case 'charge':
        b.stateTimer = 0.6;
        b.vx = b.facing * b.spec.walkSpeed * 3.4;
        shake = 0.2;
        break;
      case 'cast':
        b.stateTimer = 0.45;
        final base = atan2(p.cy - b.cy, p.cx - b.cx);
        for (int i = -1; i <= 1; i++) {
          final ang = base + i * 0.26;
          projectiles.add(Projectile(b.cx, b.cy - 10, cos(ang) * 360,
              sin(ang) * 360, 12, 3.5, 16, true, b.spec.color,
              shape: 'orb'));
        }
        break;
      case 'leap':
        b.stateTimer = 1.8;
        b.vy = -1250;
        b.vx = b.facing * 260;
        b.airborne = true;
        break;
      case 'smash':
        // dash forward, then smash the ground at the end (in _bossActive)
        b.stateTimer = 0.7;
        b.vx = b.facing * b.spec.walkSpeed * 3.6;
        shake = 0.2;
        break;
      case 'iaido':
        // instant long-range quick-draw slash
        b.stateTimer = 0.35;
        b.vx = b.facing * 200;
        _bossSlash(b, 380, b.enraged ? 34 : 26, 460);
        shake = 0.25;
        break;
      case 'flurry':
        // rapid multi-slash over the active window
        b.stateTimer = 1.0;
        b.subTimer = 0;
        b.hits = 0;
        break;
      case 'guard':
        // raise a shield, then counter when it drops
        b.stateTimer = 1.4;
        b.guard = 1.4;
        b.vx = 0;
        break;
      case 'teleslam':
        // vanish, reappear above the player, crash down into an eruption
        b.guard = 0;
        b.x = (p.cx - b.w / 2).clamp(40.0, roomWidth - b.w - 40);
        b.y = kGroundY - 360;
        b.vx = 0;
        b.vy = 60;
        b.airborne = true;
        b.stateTimer = 2.2;
        for (int i = 0; i < 18; i++) {
          final a = rng.nextDouble() * pi * 2;
          particles.add(Particle(b.cx, b.cy, cos(a) * 160, sin(a) * 160, 0.4, 6,
              b.spec.color,
              grav: 0));
        }
        break;
      case 'beam':
        // release of the charged stance: sword-beams fly out in all directions
        b.guard = 0;
        b.stateTimer = 0.6;
        b.vx = 0;
        final n = b.enraged ? 12 : 9;
        for (int i = 0; i < n; i++) {
          final ang = i / n * pi * 2;
          projectiles.add(Projectile(b.cx, b.cy - 6, cos(ang) * 560,
              sin(ang) * 560, 9, 2.6, b.enraged ? 20 : 15, true,
              const Color(0xFFE3F2FD),
              shape: 'bolt'));
        }
        shake = max(shake, 0.3);
        break;
      case 'wideslash':
        // lunge forward with a big sweeping slash
        b.stateTimer = 0.7;
        b.vx = b.facing * b.spec.walkSpeed * 2.6;
        b.subTimer = 0.18;
        _bossSlash(b, 220, b.enraged ? 30 : 22, 420);
        shake = 0.22;
        break;
      case 'triplesmash':
        // three consecutive leaps, slamming the ground on each landing
        b.hits = 0;
        b.airborne = true;
        b.vy = -820;
        b.vx = (p.cx - b.cx).sign * b.spec.walkSpeed * 1.6;
        b.stateTimer = 3.2; // safety cap
        shake = max(shake, 0.15);
        break;
      case 'swordbeam':
        // fire a straight piercing sword-beam forward
        b.vx = 0;
        b.stateTimer = 0.5;
        final bd = b.enraged ? 26.0 : 20.0;
        projectiles.add(Projectile(b.cx + b.facing * 30, b.cy - 4,
            b.facing * 620, 0, 14, 1.6, bd, true, const Color(0xFFE3F2FD),
            shape: 'bolt', pierce: true));
        projectiles.add(Projectile(b.cx + b.facing * 30, b.cy - 18,
            b.facing * 620, 0, 9, 1.6, bd * 0.6, true, const Color(0xFFB3E5FC),
            shape: 'bolt', pierce: true));
        projectiles.add(Projectile(b.cx + b.facing * 30, b.cy + 12,
            b.facing * 620, 0, 9, 1.6, bd * 0.6, true, const Color(0xFFB3E5FC),
            shape: 'bolt', pierce: true));
        shake = max(shake, 0.25);
        break;
      case 'divebomb':
        // flying bosses: lock the player's position, soar up, then dive there
        b.aimX = p.cx;
        b.subTimer = 0;
        b.airborne = true;
        b.vy = -1000;
        b.vx = 0;
        b.stateTimer = 2.6;
        shake = max(shake, 0.12);
        break;
      case 'vortex':
        // suck the player inward over the active window, then detonate
        b.vx = 0;
        b.stateTimer = 1.1;
        _fx('ring', b.cx, b.cy, 1.1, const Color(0xFFE040FB), size: 150);
        break;
      case 'approach':
        // quick gap-closer toward the player (no telegraphed hit, body checks)
        b.stateTimer = 0.4;
        b.vx = b.facing * b.spec.walkSpeed * (_isFlying(b) ? 2.4 : 1.8);
        break;
      case 'reposition':
        // hop/glide away to re-establish spacing (casters & rogues)
        b.stateTimer = 0.35;
        b.facing = p.cx >= b.cx ? 1 : -1; // face player while retreating
        b.vx = -b.facing * b.spec.walkSpeed * 2.2;
        if (!_isFlying(b) && b.onGround) b.vy = -360; // little back-hop
        break;
      case 'rest':
        // exhaustion: flyers drop from the sky and stand panting, vulnerable
        b.hover = 0;
        b.airborne = false;
        b.guard = 0;
        b.stateTimer = b.enraged ? 1.4 : 2.0;
        b.vx = 0;
        break;
      case 'appleScatter':
        // lob a fan of apples that arc out and burst on landing
        b.stateTimer = 0.7;
        b.vx = 0;
        final n = b.enraged ? 6 : 4;
        for (int i = 0; i < n; i++) {
          final spread = (i / (n - 1) - 0.5) * 2; // -1..1
          final tx = (p.cx + spread * 260).clamp(60.0, roomWidth - 60.0);
          final dx = tx - b.cx;
          final vx0 = dx / 0.85; // reach target in ~0.85s
          projectiles.add(Projectile(b.cx, b.cy - 30, vx0, -520, 11, 1.2,
              b.enraged ? 18 : 13, true, const Color(0xFFE53935),
              shape: 'apple', grav: 1300));
        }
        break;
      case 'roots':
        // gnarled roots race along the ground outward from the trunk
        b.vx = 0;
        b.hits = 0;
        b.subTimer = 0;
        b.aimX = (p.cx >= b.cx ? 1 : -1).toDouble(); // travel direction
        b.stateTimer = 1.3;
        shake = max(shake, 0.15);
        break;
      case 'feathers':
        // airborne volley of razor feathers raining toward the player
        b.stateTimer = 0.5;
        final base = atan2((p.cy - b.cy).abs() + 40, (p.cx - b.cx));
        final n = b.enraged ? 7 : 5;
        for (int i = 0; i < n; i++) {
          final ang = base + (i - (n - 1) / 2) * 0.16;
          projectiles.add(Projectile(b.cx, b.cy + 10, cos(ang) * 420,
              sin(ang) * 420 + 60, 9, 2.4, b.enraged ? 16 : 12, true,
              b.spec.color,
              shape: 'feather'));
        }
        break;
      case 'swoop':
        // drop to a low glide and rush across the ground, talons out
        b.hover = 0.55;
        b.hoverTargetY = kGroundY - b.h - 6; // skim just above the floor
        b.vx = b.facing * b.spec.walkSpeed * 3.4;
        b.stateTimer = 0.7;
        shake = max(shake, 0.12);
        break;
      case 'firebreath':
        // exhale a short cone of fireballs forward (dragon)
        b.vx = 0;
        b.stateTimer = 0.6;
        for (int i = 0; i < 3; i++) {
          final ang = (i - 1) * 0.22;
          projectiles.add(Projectile(b.cx + b.facing * 40, b.cy - 6,
              b.facing * cos(ang) * 420, sin(ang) * 420, 13, 1.8,
              b.enraged ? 20 : 15, true, const Color(0xFFFF7043),
              shape: 'fireball'));
        }
        shake = max(shake, 0.2);
        break;
      case 'knives':
        // throw a fan of spinning blades forward (bandit/doppel)
        b.vx = 0;
        b.stateTimer = 0.4;
        final base = atan2(p.cy - b.cy, p.cx - b.cx);
        for (int i = -1; i <= 1; i++) {
          final ang = base + i * 0.2;
          projectiles.add(Projectile(b.cx + b.facing * 20, b.cy - 6,
              cos(ang) * 520, sin(ang) * 520, 7, 2.0, b.enraged ? 14 : 10, true,
              const Color(0xFFCFD8DC),
              shape: 'arrow'));
        }
        break;
      case 'webshot':
        // spit a sticky web that slows on contact (spider)
        b.vx = 0;
        b.stateTimer = 0.45;
        final ang = atan2(p.cy - b.cy, p.cx - b.cx);
        projectiles.add(Projectile(b.cx, b.cy, cos(ang) * 340, sin(ang) * 340,
            12, 2.4, b.enraged ? 12 : 8, true, const Color(0xFFE0E0E0),
            shape: 'net', onHit: StatusKind.slow, onHitDur: 2.5, onHitPow: 1));
        break;
    }
  }

  void _bossActive(Boss b, double dt) {
    switch (b.pattern) {
      case 'basic':
        _moveAndCollide(b, dt, oneWay: false);
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.4;
        }
        break;
      case 'charge':
        _moveAndCollide(b, dt, oneWay: false);
        if (rng.nextDouble() < 0.6) {
          particles.add(Particle(b.cx, b.cy + 20, (rng.nextDouble() - 0.5) * 60,
              -rng.nextDouble() * 60, 0.4, 6, b.spec.color.withOpacity(0.7),
              grav: 0));
        }
        if (b.stateTimer <= 0 || b.vx == 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.6;
        }
        break;
      case 'cast':
        b.vx = 0;
        _moveAndCollide(b, dt, oneWay: false);
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.5;
        }
        break;
      case 'beam':
        b.vx = 0;
        _moveAndCollide(b, dt, oneWay: false);
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.5;
        }
        break;
      case 'leap':
        _moveAndCollide(b, dt, oneWay: false);
        if (b.airborne && b.onGround) {
          b.airborne = false;
          _shockwave(b);
          b.state = BossState.recover;
          b.stateTimer = 0.7;
        } else if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.6;
        }
        break;
      case 'teleslam':
        _moveAndCollide(b, dt, oneWay: false);
        if (b.airborne && b.onGround) {
          b.airborne = false;
          _bossErupt(b); // ground spikes erupt outward, launching the player
          b.state = BossState.recover;
          b.stateTimer = 0.9;
        } else if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.6;
        }
        break;
      case 'smash':
        _moveAndCollide(b, dt, oneWay: false);
        if (rng.nextDouble() < 0.6) {
          particles.add(Particle(b.cx, b.cy + 20, (rng.nextDouble() - 0.5) * 60,
              -rng.nextDouble() * 60, 0.4, 6, b.spec.color.withOpacity(0.7),
              grav: 0));
        }
        if (b.stateTimer <= 0 || b.vx == 0) {
          _bossSmash(b); // ground break -> launches the player upward
          b.state = BossState.recover;
          b.stateTimer = 0.9;
        }
        break;
      case 'iaido':
        b.vx *= 0.85;
        _moveAndCollide(b, dt, oneWay: false);
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.6;
        }
        break;
      case 'wideslash':
        b.vx *= 0.9;
        _moveAndCollide(b, dt, oneWay: false);
        // a second sweep mid-lunge
        if (b.subTimer > 0 && b.subTimer - dt <= 0) {
          _bossSlash(b, 230, b.enraged ? 24 : 18, 380);
        }
        b.subTimer -= dt;
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.6;
        }
        break;
      case 'flurry':
        b.vx = b.facing * 80;
        _moveAndCollide(b, dt, oneWay: false);
        if (b.subTimer <= 0 && b.hits < (b.enraged ? 6 : 4)) {
          b.subTimer = 0.16;
          b.hits++;
          _bossSlash(b, 150, 10, 160);
          shake = max(shake, 0.1);
        }
        b.subTimer -= dt;
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.5;
        }
        break;
      case 'guard':
        b.vx = 0;
        _moveAndCollide(b, dt, oneWay: false);
        if (rng.nextDouble() < 0.4) {
          final a = rng.nextDouble() * pi * 2;
          particles.add(Particle(b.cx + cos(a) * 50, b.cy + sin(a) * 50, 0, 0,
              0.3, 4, const Color(0xFF64B5F6),
              grav: 0));
        }
        if (b.stateTimer <= 0) {
          _bossSmash(b); // counterattack shockwave
          b.guard = 0;
          b.state = BossState.recover;
          b.stateTimer = 0.6;
        }
        break;
      case 'triplesmash':
        _moveAndCollide(b, dt, oneWay: false);
        if (b.airborne && b.onGround) {
          b.airborne = false;
          _bossSmash(b);
          b.hits++;
          if (b.hits < 3) {
            b.airborne = true;
            b.vy = -820;
            b.vx = (player.cx - b.cx).sign * b.spec.walkSpeed * 1.6;
          } else {
            b.state = BossState.recover;
            b.stateTimer = 0.8;
          }
        } else if (b.stateTimer <= 0) {
          b.airborne = false;
          b.state = BossState.recover;
          b.stateTimer = 0.6;
        }
        break;
      case 'swordbeam':
        b.vx = 0;
        _moveAndCollide(b, dt, oneWay: false);
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.5;
        }
        break;
      case 'divebomb':
        _moveAndCollide(b, dt, oneWay: false);
        if (b.subTimer < 0.5 && b.vy >= -40) {
          // apex reached -> dive diagonally to the locked position
          b.subTimer = 1;
          b.vx = (b.aimX - b.cx).sign * 520;
          b.vy = 900;
        }
        if (b.subTimer >= 0.5 && b.airborne && b.onGround) {
          b.airborne = false;
          _bossErupt(b);
          b.state = BossState.recover;
          b.stateTimer = 0.9;
        } else if (b.stateTimer <= 0) {
          b.airborne = false;
          b.state = BossState.recover;
          b.stateTimer = 0.6;
        }
        break;
      case 'vortex':
        b.vx = 0;
        _moveAndCollide(b, dt, oneWay: false);
        final pv = player;
        pv.x = (pv.x + (b.cx - pv.cx).sign * 240 * dt)
            .clamp(20.0, roomWidth - pv.w - 20);
        if (rng.nextDouble() < 0.7) {
          final a = rng.nextDouble() * pi * 2;
          final rad = 70 + rng.nextDouble() * 40;
          particles.add(Particle(b.cx + cos(a) * rad, b.cy + sin(a) * rad,
              -cos(a) * 220, -sin(a) * 220, 0.3, 4, b.spec.color,
              grav: 0));
        }
        if (b.stateTimer <= 0) {
          shake = max(shake, 0.4);
          _fx('dualring', b.cx, b.cy, 0.45, const Color(0xFFE040FB), size: 150);
          if (pv.invuln <= 0 && (pv.center - b.center).distance < 140) {
            _hurtPlayer(b.enraged ? 30 : 24, b.cx, kb: 1.6);
          }
          for (int i = 0; i < 30; i++) {
            final a = rng.nextDouble() * pi * 2;
            final sp = 200 + rng.nextDouble() * 260;
            particles.add(Particle(b.cx, b.cy, cos(a) * sp, sin(a) * sp, 0.5, 6,
                i.isEven ? const Color(0xFFE040FB) : const Color(0xFFFFFFFF),
                grav: 0));
          }
          b.state = BossState.recover;
          b.stateTimer = 0.7;
        }
        break;
      case 'approach':
        _moveAndCollide(b, dt, oneWay: false);
        if (b.stateTimer <= 0 || b.vx == 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.15; // chain straight into the next step
        }
        break;
      case 'reposition':
        b.vx *= 0.9;
        _moveAndCollide(b, dt, oneWay: false);
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.2;
        }
        break;
      case 'rest':
        // panting on the ground — no guard, easy to punish (see _damageBoss)
        b.vx = 0;
        _moveAndCollide(b, dt, oneWay: false);
        if (rng.nextDouble() < 0.25) {
          particles.add(Particle(b.cx + (rng.nextDouble() - 0.5) * 40,
              b.cy - 30, (rng.nextDouble() - 0.5) * 30, -30 - rng.nextDouble() * 30,
              0.5, 4, const Color(0xFF90A4AE),
              grav: -40));
        }
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.4;
        }
        break;
      case 'appleScatter':
        b.vx = 0;
        _moveAndCollide(b, dt, oneWay: false);
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.5;
        }
        break;
      case 'roots':
        b.vx = 0;
        _moveAndCollide(b, dt, oneWay: false);
        // advance the root front outward, erupting at each step
        b.subTimer -= dt;
        if (b.subTimer <= 0 && b.hits < 7) {
          b.subTimer = 0.12;
          b.hits++;
          final rx = (b.cx + b.aimX * b.hits * 64).clamp(20.0, roomWidth - 20.0);
          _rootErupt(b, rx, b.enraged ? 14 : 10);
        }
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.6;
        }
        break;
      case 'feathers':
        _moveAndCollide(b, dt, oneWay: false);
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.4;
        }
        break;
      case 'swoop':
        _moveAndCollide(b, dt, oneWay: false);
        if (rng.nextDouble() < 0.5) {
          particles.add(Particle(b.cx, b.cy, -b.facing * 80, 0, 0.3, 5,
              b.spec.color.withOpacity(0.7),
              grav: 0));
        }
        // talons clip the player on contact (handled by body overlap), end on
        // timeout or when the rush stalls against a wall
        if (b.stateTimer <= 0 || b.vx == 0) {
          b.hover = 0;
          b.state = BossState.recover;
          b.stateTimer = 0.45;
        }
        break;
      case 'firebreath':
        b.vx = 0;
        _moveAndCollide(b, dt, oneWay: false);
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.5;
        }
        break;
      case 'knives':
        b.vx = 0;
        _moveAndCollide(b, dt, oneWay: false);
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.35;
        }
        break;
      case 'webshot':
        b.vx = 0;
        _moveAndCollide(b, dt, oneWay: false);
        if (b.stateTimer <= 0) {
          b.state = BossState.recover;
          b.stateTimer = 0.4;
        }
        break;
    }
  }

  // a root bursts up from the ground at [rx]; on contact it binds (속박) the
  // player in place and bites for [dmg]. Used by the apple-tree boss.
  void _rootErupt(Boss b, double rx, double dmg) {
    for (int i = 0; i < 5; i++) {
      particles.add(Particle(rx + (rng.nextDouble() - 0.5) * 16, kGroundY,
          (rng.nextDouble() - 0.5) * 30, -200 - rng.nextDouble() * 160, 0.6, 7,
          const Color(0xFF5D4037),
          grav: 700));
    }
    particles.add(Particle(rx, kGroundY - 30, 0, -40, 0.5, 9,
        const Color(0xFF33691E),
        grav: -30));
    final p = player;
    if (p.invuln <= 0 &&
        p.onGround &&
        (p.cx - rx).abs() < 36 &&
        (p.cy - kGroundY).abs() < 120) {
      _hurtPlayer(dmg, rx, kb: 0.2);
      p.addStatus(StatusKind.bind, 1.2, 1); // rooted in place
    }
  }

  // apple-tree fruit detonation when an apple finishes its arc
  void _appleExplode(Projectile pr) {
    shake = max(shake, 0.2);
    _fx('ring', pr.x, pr.y, 0.35, const Color(0xFFFF7043), size: 84);
    for (int i = 0; i < 18; i++) {
      final a = rng.nextDouble() * pi * 2;
      final sp = 120 + rng.nextDouble() * 200;
      particles.add(Particle(pr.x, pr.y, cos(a) * sp, sin(a) * sp - 30, 0.5, 6,
          i.isEven ? const Color(0xFFFF7043) : const Color(0xFFE53935),
          grav: 500));
    }
    final p = player;
    if (p.invuln <= 0 && (p.center - Offset(pr.x, pr.y)).distance < 78) {
      _hurtPlayer(pr.dmg, pr.x, kb: 1.2);
      p.addStatus(StatusKind.burn, 2.5, _foePow(5));
    }
  }

  // teleslam landing: a ring of erupting ground spikes that launches the player
  void _bossErupt(Boss b) {
    shake = max(shake, 0.5);
    _fx('crack', b.cx, b.y + b.h, 0.55, const Color(0xFFFFB300), size: 340);
    for (int i = 0; i < 36; i++) {
      final a = (i / 36) * pi * 2;
      particles.add(Particle(b.cx, b.y + b.h, cos(a) * 340, -sin(a).abs() * 220,
          0.6, 9, b.spec.color,
          grav: 700));
    }
    // erupting earth spikes left/right
    for (int s = -1; s <= 1; s += 2) {
      for (int i = 1; i <= 6; i++) {
        particles.add(Particle(b.cx + s * i * 36.0, kGroundY,
            (rng.nextDouble() - 0.5) * 40, -260 - rng.nextDouble() * 160, 0.7, 8,
            const Color(0xFF6D4C41),
            grav: 800));
      }
    }
    final p = player;
    if (p.onGround && (p.cx - b.cx).abs() < 320 && p.invuln <= 0) {
      _launchPlayer(620, b.cx);
    }
  }

  void _bossSmash(Boss b) {
    shake = max(shake, 0.45);
    for (int i = 0; i < 30; i++) {
      final a = (i / 30) * pi * 2;
      particles.add(Particle(b.cx, b.y + b.h, cos(a) * 300,
          -sin(a).abs() * 180, 0.6, 9, b.spec.color,
          grav: 700));
    }
    for (int i = 0; i < 8; i++) {
      particles.add(Particle(b.cx + (rng.nextDouble() - 0.5) * 200, b.y + b.h,
          (rng.nextDouble() - 0.5) * 200, -200 - rng.nextDouble() * 200, 0.8, 6,
          const Color(0xFF6D4C41),
          grav: 800));
    }
    final p = player;
    if (p.onGround && (p.cx - b.cx).abs() < 280 && p.invuln <= 0) {
      _launchPlayer(560, b.cx);
    }
  }

  void _bossSlash(Boss b, double reach, double dmg, double kb) {
    final p = player;
    final hb = Rect.fromLTWH(b.facing == 1 ? b.x + b.w - 10 : b.cx - reach,
        b.cy - 50, reach, 100);
    for (int i = 0; i < 10; i++) {
      particles.add(Particle(
          b.cx + b.facing * (40 + i * reach / 12),
          b.cy - 30 + (rng.nextDouble() - 0.5) * 60,
          b.facing * 120,
          0,
          0.25,
          5,
          b.spec.color,
          grav: 0));
    }
    if (p.invuln <= 0 && hb.overlaps(p.rect)) {
      _hurtPlayer(dmg, b.cx);
      p.vx += b.facing * kb;
    }
  }

  // hammer enemy ground slam: shockwave that knocks back and stuns nearby
  void _hammerSlam(Enemy e) {
    shake = max(shake, 0.3);
    _fx('crack', e.cx, e.y + e.h, 0.45, const Color(0xFFBCAAA4), size: 200);
    for (int i = 0; i < 18; i++) {
      final a = (i / 18) * pi * 2;
      particles.add(Particle(e.cx, e.y + e.h, cos(a) * 220,
          -sin(a).abs() * 160, 0.5, 6, const Color(0xFF8D6E63),
          grav: 700));
    }
    final p = player;
    if (p.onGround && (p.cx - e.cx).abs() < 150 && p.invuln <= 0) {
      _hurtPlayer(16, e.cx, stun: 0.7, kb: 1.5);
    }
  }

  void _launchPlayer(double up, double fromX) {
    final p = player;
    if (p.invuln > 0) return;
    p.damage(18 * _floorAtkMul); // floor-scaled launch impact
    p.invuln = 0.9;
    p.vy = -up;
    p.vx = (p.cx < fromX ? -1 : 1) * 160;
    shake = max(shake, 0.3);
    for (int i = 0; i < 12; i++) {
      particles.add(Particle(p.cx, p.cy, (rng.nextDouble() - 0.5) * 260,
          -rng.nextDouble() * 300, 0.5, 5, const Color(0xFFFFF176)));
    }
    if (p.dead && phase == GamePhase.playing) {
      phase = GamePhase.gameover;
      _banner('GAME OVER', 999);
    }
  }

  void _damageBoss(Boss b, double dmg) {
    if (b.guard > 0) dmg *= 0.3; // guarded: heavily mitigated
    if (b.pattern == 'rest') dmg *= 1.6; // exhausted: punish window
    b.damage(dmg);
  }

  void _shockwave(Boss b) {
    shake = 0.35;
    for (int i = 0; i < 24; i++) {
      final a = (i / 24) * pi * 2;
      particles.add(Particle(b.cx, b.y + b.h, cos(a) * 260,
          -sin(a).abs() * 130, 0.5, 8, b.spec.color,
          grav: 600));
    }
    final p = player;
    if (p.onGround && (p.cx - b.cx).abs() < 230 && p.invuln <= 0) {
      _hurtPlayer(22, b.cx);
    }
  }

  // ----------------------------------------------------------------
  void _updateTraps(double dt) {
    // once the room is cleared, traps go dormant (no more triggering)
    if (roomCleared) return;
    final p = player;
    for (final tr in traps) {
      switch (tr.kind) {
        case 'spike':
          if (p.invuln <= 0 && p.rect.overlaps(tr.rect)) {
            _hurtPlayer(12, p.cx);
          }
          break;
        case 'saw':
          tr.x += tr.dir * 110 * dt;
          if (tr.x <= tr.minX) {
            tr.x = tr.minX;
            tr.dir = 1;
          } else if (tr.x >= tr.maxX) {
            tr.x = tr.maxX;
            tr.dir = -1;
          }
          tr.t += dt;
          if (p.invuln <= 0 && p.rect.overlaps(tr.rect)) {
            _hurtPlayer(10, tr.rect.center.dx);
          }
          break;
        case 'arrow':
          tr.t -= dt;
          if (tr.t <= 0 && (p.cx - tr.x).abs() < 700) {
            tr.t = 2.0;
            final d = (p.cx >= tr.x) ? 1 : -1;
            projectiles.add(Projectile(tr.rect.center.dx, tr.rect.center.dy,
                d * 360.0, 0, 6, 3.0, 9, true, const Color(0xFFCFD8DC)));
          }
          break;
        case 'flame':
          // fire vent: erupts a column for ~1s on a 2.4s cycle, burns on hit
          tr.t += dt;
          final cycle = tr.t % 2.4;
          if (cycle > 1.4) {
            final flame = Rect.fromLTWH(tr.x, tr.y - 96, tr.w, 96 + tr.h);
            if (p.invuln <= 0 && p.rect.overlaps(flame)) {
              _hurtPlayer(10, p.cx);
              p.addStatus(StatusKind.burn, 2.5, _foePow(6)); // trap burn scales w/ floor
            }
            // embers
            if (rng.nextDouble() < 0.5) {
              particles.add(Particle(
                  tr.x + rng.nextDouble() * tr.w,
                  tr.y,
                  (rng.nextDouble() - 0.5) * 60,
                  -160 - rng.nextDouble() * 160,
                  0.5,
                  4,
                  rng.nextBool()
                      ? const Color(0xFFFF7043)
                      : const Color(0xFFFFCA28),
                  grav: -60));
            }
          }
          break;
      }
    }
  }

  // Trapper mines: count down arming/life, blink+puff while armed, and detonate
  // when an enemy steps onto an armed trap (or fizzle out when life expires).
  void _updateMines(double dt) {
    if (mines.isEmpty) return;
    for (final m in mines) {
      if (m.triggered) {
        m.fuse -= dt;
        if (m.fuse <= 0) {
          _mineExplode(m);
          m.life = 0; // remove after blast
        }
        continue;
      }
      if (m.arm > 0) {
        m.arm -= dt;
        continue;
      }
      m.life -= dt;
      // a foe stepping onto an armed trap trips it
      final foe = [...enemies, if (boss != null) boss!].any(
          (e) => !e.dead && e.rect.overlaps(m.rect.inflate(6)));
      if (foe) {
        m.triggered = true;
        m.fuse = 0.12;
      } else if (m.life <= 0) {
        // fizzle: small puff so it doesn't vanish silently
        for (int i = 0; i < 6; i++) {
          particles.add(Particle(m.x, m.y, (rng.nextDouble() - 0.5) * 60,
              -rng.nextDouble() * 60, 0.4, 3, const Color(0xFF90A4AE),
              grav: 120));
        }
      }
    }
    mines.removeWhere((m) => m.life <= 0 && !m.triggered);
    mines.removeWhere((m) => m.triggered && m.fuse <= 0);
  }

  void _updateStorms(double dt) {
    if (storms.isEmpty) return;
    for (final c in storms) {
      c.t += dt;
      if (c.boltFlash > 0) c.boltFlash -= dt;
      final tgt = c.target;
      // the cloud dissipates if its target dies or leaves the field
      final gone = tgt.dead ||
          (tgt is Enemy && !enemies.contains(tgt)) ||
          (tgt is Boss && boss == null);
      if (gone) {
        c.life = 0;
        continue;
      }
      // hover above the chased target
      c.x = tgt.cx;
      c.y = tgt.cy - 130;
      c.life -= dt;
      if (c.strikesLeft > 0) {
        c.strikeCd -= dt;
        if (c.strikeCd <= 0) {
          c.strikeCd = 2.0; // 3 bolts spaced across the 6s lifetime
          c.strikesLeft -= 1;
          c.boltFlash = 0.22;
          _stormStrike(c, tgt);
        }
      }
    }
    storms.removeWhere((c) => c.life <= 0);
  }

  // One lightning bolt from a storm cloud onto its target: damage + a chance to
  // stun (bosses shrug off the stun), with a bolt FX and a spark burst.
  void _stormStrike(StormCloud c, Entity tgt) {
    if (tgt is Boss) {
      _damageBoss(tgt, c.dmg);
    } else {
      tgt.damage(c.dmg);
      if (rng.nextDouble() < 0.35) tgt.addStatus(StatusKind.stun, 1.0, 1);
    }
    skillFx.add(SkillFx('lightning', c.x, c.y, 0.26, const Color(0xFF80DEEA),
        x2: tgt.cx, y2: tgt.cy));
    _hitSpark(tgt.cx, tgt.cy, 1);
    shake = max(shake, 0.12);
    for (int s = 0; s < 10; s++) {
      final a = rng.nextDouble() * pi * 2;
      final sp = 90 + rng.nextDouble() * 180;
      particles.add(Particle(tgt.cx, tgt.cy, cos(a) * sp, sin(a) * sp, 0.25, 3,
          s.isEven ? const Color(0xFF80DEEA) : const Color(0xFFFFFFFF),
          grav: 0));
    }
  }

  // Mage basic-orb burst: a small radial pop dealing 60% of [dmg] to every foe
  // in range. Compensates casters for their slow, hard-to-aim shots.
  // True if this projectile is a lobbed/arcing shot (potion, bomb, net, rock…).
  bool _arcs(Projectile pr) => pr.grav != 0;

  // Area-of-effect impact for arcing shots: full damage + status to every foe
  // in a radius (hard-to-aim lobs shouldn't reward only a single hit).
  void _arcSplash(Projectile pr, double x, double y) {
    _thrownBurst(pr);
    shake = max(shake, 0.14);
    final c = Offset(x, y);
    const radius = 74.0;
    for (final e in [...enemies, if (boss != null) boss!]) {
      if (e.dead) continue;
      if ((e.center - c).distance < radius + e.w / 2) {
        if (e is Boss) {
          _damageBoss(e, pr.dmg);
        } else {
          e.damage(pr.dmg);
          _playerOnHit(e);
        }
        if (pr.onHit != null) e.addStatus(pr.onHit!, pr.onHitDur, pr.onHitPow);
        switch (pr.shape) {
          case 'potion':
            e.addStatus(StatusKind.poison, 3.5, 6);
            break;
          case 'bomb':
            e.addStatus(StatusKind.burn, 3, 8);
            break;
          case 'net':
            e.addStatus(StatusKind.slow, 3, 1);
            break;
        }
        _hitSpark(e.cx, e.cy, e.cx >= x ? 1 : -1);
      }
    }
  }

  void _magicSplash(double x, double y, double dmg, Color color) {
    _fx('ring', x, y, 0.28, color, size: 60);
    final c = Offset(x, y);
    const radius = 56.0;
    for (final e in [...enemies, if (boss != null) boss!]) {
      if (e.dead) continue;
      if ((e.center - c).distance < radius + e.w / 2) {
        if (e is Boss) {
          _damageBoss(e, dmg * 0.6);
        } else {
          e.damage(dmg * 0.6);
        }
        _hitSpark(e.cx, e.cy, e.cx >= x ? 1 : -1);
      }
    }
    for (int i = 0; i < 12; i++) {
      final a = rng.nextDouble() * pi * 2;
      final sp = 70 + rng.nextDouble() * 130;
      particles.add(Particle(x, y, cos(a) * sp, sin(a) * sp, 0.32, 4,
          color.withOpacity(0.9), grav: 0));
    }
  }

  // Trapper mine detonation: radial blast + knockback against enemies.
  void _mineExplode(Mine m) {
    shake = max(shake, 0.26);
    _fx('dualring', m.x, m.y, 0.4, const Color(0xFFFFB300), size: 120);
    _emitNoise(m.x, m.y, 0.8);
    const radius = 120.0;
    final center = Offset(m.x, m.y);
    for (final e in [...enemies, if (boss != null) boss!]) {
      if (e.dead) continue;
      if ((e.center - center).distance < radius + e.w / 2) {
        if (e is Boss) {
          _damageBoss(e, m.dmg);
        } else {
          e.damage(m.dmg);
        }
        e.addStatus(StatusKind.burn, 2, 6);
        final dir = e.cx >= m.x ? 1 : -1;
        if (e is Enemy) {
          e.vx = dir * 300.0;
          e.vy = -240;
        }
        _hitSpark(e.cx, e.cy, dir);
      }
    }
    for (int i = 0; i < 26; i++) {
      final a = rng.nextDouble() * pi * 2;
      final sp = 130 + rng.nextDouble() * 240;
      particles.add(Particle(m.x, m.y, cos(a) * sp, sin(a) * sp - 50,
          0.4 + rng.nextDouble() * 0.4, 4 + rng.nextDouble() * 5,
          i.isEven ? const Color(0xFFFF7043) : const Color(0xFFFFD166),
          grav: 360));
    }
  }

  // Pyromancer fireball detonation: a radial blast that burns. Damage scales
  // off the projectile's own dmg (baked with atkMul at cast time).
  void _fireballExplode(Projectile pr) {
    shake = max(shake, 0.3);
    _fx('dualring', pr.x, pr.y, 0.45, const Color(0xFFFF7043), size: 135);
    final dmg = pr.dmg * 1.5;
    final center = Offset(pr.x, pr.y);
    const radius = 135.0;
    for (final e in [...enemies, if (boss != null) boss!]) {
      if (e.dead) continue;
      if ((e.center - center).distance < radius + e.w / 2) {
        if (e is Boss) {
          _damageBoss(e, dmg);
        } else {
          e.damage(dmg);
        }
        e.addStatus(StatusKind.burn, 3, 8);
        _hitSpark(e.cx, e.cy, e.cx >= pr.x ? 1 : -1);
      }
    }
    for (int i = 0; i < 34; i++) {
      final a = rng.nextDouble() * pi * 2;
      final sp = 140 + rng.nextDouble() * 280;
      particles.add(Particle(pr.x, pr.y, cos(a) * sp, sin(a) * sp - 40,
          0.45 + rng.nextDouble() * 0.4, 5 + rng.nextDouble() * 5,
          i.isEven ? const Color(0xFFFF7043) : const Color(0xFFFFD166),
          grav: 360));
    }
  }

  // Paladin sword-fall impact: the descending blade crashes into the ground for
  // a heavy radial blow + knockback. Damage scales off the projectile's dmg.
  void _swordfallImpact(Projectile pr) {
    shake = max(shake, 0.38);
    _fx('crack', pr.x, pr.y, 0.5, const Color(0xFFFFD166), size: 150);
    _fx('dualring', pr.x, pr.y, 0.45, pr.color, size: 150);
    final dmg = pr.dmg * 2.0;
    final center = Offset(pr.x, pr.y);
    const radius = 150.0;
    for (final e in [...enemies, if (boss != null) boss!]) {
      if (e.dead) continue;
      if ((e.center - center).distance < radius + e.w / 2) {
        if (e is Boss) {
          _damageBoss(e, dmg);
        } else {
          e.damage(dmg);
        }
        final dir = e.cx >= pr.x ? 1 : -1;
        if (e is Enemy) {
          e.vx = dir * 320.0;
          e.vy = -240;
        }
        _hitSpark(e.cx, e.cy, dir);
      }
    }
    for (int i = 0; i < 30; i++) {
      final a = rng.nextDouble() * pi * 2;
      final sp = 120 + rng.nextDouble() * 250;
      particles.add(Particle(pr.x, pr.y, cos(a) * sp, sin(a) * sp - 50,
          0.45 + rng.nextDouble() * 0.4, 4 + rng.nextDouble() * 5,
          i.isEven ? pr.color : const Color(0xFFFFF59D),
          grav: 380));
    }
    // 성기사: the blade stays planted in the ground for 10s, empowering the
    // paladin while he fights near it (see paladinSwordBuff in _updatePlayer).
    if (player.skull.type == SkullType.paladin) {
      paladinSwordTimer = 10.0;
      paladinSwordX = pr.x;
      paladinSwordY = pr.y;
      _banner('천공의 대검이 꽂혔다 — 근처에서 공격력 대폭 증가!', 1.8);
    }
  }

  // Plague contagion: when an infected enemy dies, a fresh miasma burst infects
  // its neighbours — chaining the disease outward through the death sweep.
  void _plagueContagion(double x, double y) {
    _fx('ring', x, y, 0.42, const Color(0xFF76FF03), size: 120);
    for (int i = 0; i < 18; i++) {
      final a = rng.nextDouble() * pi * 2;
      final sp = 50 + rng.nextDouble() * 140;
      particles.add(Particle(x, y, cos(a) * sp, sin(a) * sp - 30,
          0.6 + rng.nextDouble() * 0.4, 6 + rng.nextDouble() * 3,
          i.isEven ? const Color(0xFF9CCC65) : const Color(0xFF558B2F),
          grav: -20));
    }
    const radius = 180.0;
    for (final e in enemies) {
      if (e.dead || e.hasStatus(StatusKind.infect)) continue;
      if ((e.cx - x).abs() < radius && (e.cy - y).abs() < radius) {
        e.addStatus(StatusKind.infect, 4.0, 7);
      }
    }
    final b = boss;
    if (b != null &&
        !b.dead &&
        (b.cx - x).abs() < radius &&
        (b.cy - y).abs() < radius) {
      b.addStatus(StatusKind.infect, 4.0, 7);
    }
  }

  // Living contagion: each infected enemy occasionally jumps the plague to a
  // nearby healthy enemy, so the disease keeps creeping through the pack even
  // before anyone dies. The bursts on death are handled by _plagueContagion.
  void _spreadInfection(double dt) {
    if (enemies.length < 2) return;
    final infected = [
      for (final e in enemies)
        if (!e.dead && e.hasStatus(StatusKind.infect)) e
    ];
    if (infected.isEmpty) return;
    for (final src in infected) {
      // chance to leap to a new host this frame (~1.4 jumps/sec per source)
      if (rng.nextDouble() > 1.4 * dt) continue;
      for (final e in enemies) {
        if (e.dead || identical(e, src) || e.hasStatus(StatusKind.infect)) {
          continue;
        }
        if ((e.center - src.center).distance < 150) {
          e.addStatus(StatusKind.infect, 4.0, 7);
          _fx('ring', e.cx, e.cy, 0.3, const Color(0xFF76FF03), size: 36);
          break; // one leap per source per frame
        }
      }
    }
  }

  // ----------------------------------------------------------------
  void _updateProjectiles(double dt) {
    for (final pr in projectiles) {
      if (pr.grav != 0) pr.vy += pr.grav * dt; // arcing thrown items
      final oldY = pr.y;
      pr.x += pr.vx * dt;
      pr.y += pr.vy * dt;
      pr.life -= dt;
      bool struck = false;
      for (final s in solids) {
        if (s.contains(Offset(pr.x, pr.y))) {
          struck = true;
          break;
        }
      }
      // one-way platforms: only collide when descending across the top surface
      // (rising projectiles pass through, matching the platform's one-way rule).
      if (!struck && pr.vy > 60) {
        for (final pf in platforms) {
          if (pr.x > pf.left &&
              pr.x < pf.right &&
              oldY <= pf.top &&
              pr.y >= pf.top) {
            pr.y = pf.top;
            struck = true;
            break;
          }
        }
      }
      if (struck) {
        if (!pr.fromBoss && _arcs(pr)) {
          _arcSplash(pr, pr.x, pr.y); // lobbed shots burst for area damage
        } else {
          if (!pr.fromBoss && _shatters(pr.shape)) _thrownBurst(pr);
          if (!pr.fromBoss && pr.splash > 0) {
            _magicSplash(pr.x, pr.y, pr.dmg, pr.color);
          }
        }
        pr.life = 0;
      }
    }
    projectiles.removeWhere((pr) {
      final gone = pr.life <= 0 || pr.x < -60 || pr.x > roomWidth + 60;
      if (gone) {
        if (pr.shape == 'fireball') _fireballExplode(pr);
        if (pr.shape == 'swordfall') _swordfallImpact(pr);
        if (pr.shape == 'apple') _appleExplode(pr);
      }
      return gone;
    });
  }

  bool _shatters(String shape) =>
      shape == 'potion' || shape == 'bomb' || shape == 'net';

  // shaped projectiles shatter + apply a status when they strike a target
  void _projectileOnHit(Projectile pr, Entity e) {
    _playerOnHit(e);
    if (pr.onHit != null) e.addStatus(pr.onHit!, pr.onHitDur, pr.onHitPow);
    if (!_shatters(pr.shape)) return;
    _thrownBurst(pr);
    switch (pr.shape) {
      case 'potion':
        e.addStatus(StatusKind.poison, 3.5, 6);
        break;
      case 'bomb':
        e.addStatus(StatusKind.burn, 3, 8);
        break;
      case 'net':
        e.addStatus(StatusKind.slow, 3, 1);
        break;
    }
  }

  // splash burst + lingering ground effect when a thrown item lands/hits
  void _thrownBurst(Projectile pr) {
    final col = pr.color;
    for (int i = 0; i < 16; i++) {
      final a = rng.nextDouble() * pi * 2;
      final sp = 80 + rng.nextDouble() * 200;
      particles.add(Particle(pr.x, pr.y, cos(a) * sp, sin(a) * sp - 40, 0.45,
          4 + rng.nextDouble() * 4, col,
          grav: 400));
    }
    if (pr.shape == 'bomb') {
      shake = max(shake, 0.2);
      _fx('ring', pr.x, pr.y, 0.34, const Color(0xFFFF7043), size: 70);
    } else {
      _fx('ring', pr.x, pr.y, 0.3, col, size: 50);
    }
  }

  void _updateParticles(double dt) {
    for (final pa in particles) {
      pa.vy += pa.grav * dt;
      pa.x += pa.vx * dt;
      pa.y += pa.vy * dt;
      pa.life -= dt;
    }
    particles.removeWhere((pa) => pa.life <= 0);
    for (final fx in skillFx) {
      fx.t += dt;
    }
    skillFx.removeWhere((fx) => fx.t >= fx.maxT);
  }

  void _fx(String kind, double x, double y, double maxT, Color color,
      {double dir = 1, double size = 80}) {
    skillFx.add(SkillFx(kind, x, y, maxT, color, dir: dir, size: size));
  }

  // ----------------------------------------------------------------
  void _resolveCombat() {
    final p = player;
    final mul = atkMul;
    if (!p.attacking) _crystalHitSwing = false;
    if (p.attacking && !p.skull.rangedBasic) {
      final elapsed = p.attackDuration - p.attackTimer;
      if (elapsed > 0.04 && elapsed < p.attackDuration * 0.72) {
        if (p.comboStep >= 3 && !p.finisherFired) {
          p.finisherFired = true;
          _finisher(p, mul);
        }
        final hb = p.attackHitbox();
        final baseDmg =
            p.comboStep >= 3 ? 20.0 : (p.comboStep == 2 ? 13.0 : 10.0);
        final dmg = baseDmg * mul;
        // 기사: basic hits send foes flying far back
        final kb = (p.comboStep >= 3 ? 380.0 : 190.0) *
            (p.skull.type == SkullType.knight ? 2.3 : 1.0);
        for (final e in enemies) {
          if (!p.hitThisSwing.contains(e) && hb.overlaps(e.rect)) {
            // a raised shield blocks most frontal melee and shoves you back
            final front = (p.cx - e.cx) >= 0 ? 1 : -1;
            final blocked =
                e.kind == EnemyKind.shield && e.t2 > 0 && front == e.facing;
            final crit = _critMul();
            double dmgE = (blocked ? dmg * 0.15 : dmg) * crit;
            if (e.kind == EnemyKind.shield && shieldCrystal != null) {
              dmgE *= 0.12; // crystal shields the knight from real damage
            }
            e.damage(dmgE);
            if (crit > 1.0) {
              _fx('ring', e.cx, e.cy, 0.22, const Color(0xFFFFD166), size: 34);
            }
            if (!blocked) _playerOnHit(e);
            final ls = lifesteal +
                (_passive.kind == PassiveKind.lifesteal ? _passive.value : 0);
            if (ls > 0) p.hp = min(p.maxHp, p.hp + dmgE * ls);
            p.hitThisSwing.add(e);
            if (blocked) {
              p.vx = -p.facing * 220; // recoil off the shield
              _fx('ring', e.cx + e.facing * 18, e.cy, 0.2,
                  const Color(0xFFB0BEC5), size: 40);
            } else if (e.kind != EnemyKind.bat) {
              e.vx = p.facing * kb;
              e.vy = -130;
            }
            _hitSpark(e.cx, e.cy, p.facing);
            shake = max(shake, p.comboStep >= 3 ? 0.18 : 0.08);
          }
        }
        if (shieldCrystal != null &&
            !_crystalHitSwing &&
            hb.overlaps(shieldCrystal!)) {
          _crystalHitSwing = true;
          shieldCrystalHp -= dmg;
          _hitSpark(shieldCrystal!.center.dx, shieldCrystal!.center.dy, p.facing);
          if (shieldCrystalHp <= 0) _breakShieldCrystal();
        }
        final b = boss;
        if (b != null && !p.hitThisSwing.contains(b) && hb.overlaps(b.rect)) {
          final crit = _critMul();
          final dmgB = dmg * crit;
          _damageBoss(b, dmgB);
          if (crit > 1.0) {
            _fx('ring', b.cx, b.cy - 10, 0.22, const Color(0xFFFFD166),
                size: 40);
          }
          _playerOnHit(b);
          final ls = lifesteal +
              (_passive.kind == PassiveKind.lifesteal ? _passive.value : 0);
          if (ls > 0) p.hp = min(p.maxHp, p.hp + dmgB * ls);
          p.hitThisSwing.add(b);
          _hitSpark(b.cx, b.cy - 10, p.facing);
          shake = max(shake, 0.12);
        }
      }
    }

    for (final pr in projectiles) {
      if (pr.fromBoss) continue;
      // piercing projectiles (e.g. knight's sword wave) pass through, striking
      // every enemy once instead of dying on first contact.
      if (pr.pierce) {
        for (final e in enemies) {
          if (!pr.hits.contains(e) &&
              e.rect.inflate(pr.r).contains(Offset(pr.x, pr.y))) {
            e.damage(pr.dmg);
            _projectileOnHit(pr, e);
            _hitSpark(pr.x, pr.y, pr.vx >= 0 ? 1 : -1);
            pr.hits.add(e);
          }
        }
        final pb = boss;
        if (pb != null &&
            !pr.hits.contains(pb) &&
            pb.rect.inflate(pr.r).contains(Offset(pr.x, pr.y))) {
          _damageBoss(pb, pr.dmg);
          _projectileOnHit(pr, pb);
          _hitSpark(pr.x, pr.y, pr.vx >= 0 ? 1 : -1);
          pr.hits.add(pb);
        }
        continue;
      }
      bool hit = false;
      for (final e in enemies) {
        if (e.rect.inflate(pr.r).contains(Offset(pr.x, pr.y))) {
          if (_arcs(pr)) {
            _arcSplash(pr, pr.x, pr.y);
          } else {
            e.damage(pr.dmg);
            _projectileOnHit(pr, e);
            _hitSpark(pr.x, pr.y, pr.vx >= 0 ? 1 : -1);
            if (pr.splash > 0) _magicSplash(pr.x, pr.y, pr.dmg, pr.color);
          }
          hit = true;
          break;
        }
      }
      final b = boss;
      if (!hit &&
          b != null &&
          b.rect.inflate(pr.r).contains(Offset(pr.x, pr.y))) {
        if (_arcs(pr)) {
          _arcSplash(pr, pr.x, pr.y);
        } else {
          _damageBoss(b, pr.dmg);
          _projectileOnHit(pr, b);
          _hitSpark(pr.x, pr.y, pr.vx >= 0 ? 1 : -1);
          if (pr.splash > 0) _magicSplash(pr.x, pr.y, pr.dmg, pr.color);
        }
        hit = true;
      }
      if (!hit &&
          shieldCrystal != null &&
          shieldCrystal!.inflate(pr.r).contains(Offset(pr.x, pr.y))) {
        shieldCrystalHp -= pr.dmg;
        _hitSpark(pr.x, pr.y, pr.vx >= 0 ? 1 : -1);
        if (shieldCrystalHp <= 0) _breakShieldCrystal();
        hit = true;
      }
      if (hit) pr.life = 0;
    }

    // 망령기사 유령마: trample foes the steed rams into (each once per ride).
    if (p.rideTimer > 0) {
      for (final e in enemies) {
        if (e.dead || p.rammed.contains(e) || !e.rect.overlaps(p.rect)) continue;
        p.rammed.add(e);
        e.damage(46 * mul);
        final dir = e.cx >= p.cx ? 1 : -1;
        if (e.kind != EnemyKind.bat) {
          e.vx = dir * 460.0;
          e.vy = -240;
        }
        _hitSpark(e.cx, e.cy, dir);
        shake = max(shake, 0.16);
      }
      final rb = boss;
      if (rb != null &&
          !rb.dead &&
          !p.rammed.contains(rb) &&
          rb.rect.overlaps(p.rect)) {
        p.rammed.add(rb);
        _damageBoss(rb, 40 * mul);
        _hitSpark(rb.cx, rb.cy, rb.cx >= p.cx ? 1 : -1);
      }
    }
    if (p.invuln <= 0) {
      for (final e in enemies) {
        if (e.rect.overlaps(p.rect)) {
          _hurtPlayer(_contactDmg(e.kind), e.cx, source: e);
          _contactProc(e.kind, e.cx);
          break;
        }
      }
    }
    final b = boss;
    if (b != null && p.invuln <= 0 && b.rect.overlaps(p.rect)) {
      _hurtPlayer(b.state == BossState.active ? 20 : 13, b.cx, source: b);
    }
    if (p.invuln <= 0) {
      for (final pr in projectiles) {
        if (pr.fromBoss &&
            (Offset(pr.x, pr.y) - p.center).distance < pr.r + 20) {
          _hurtPlayer(pr.dmg, pr.x, source: boss);
          if (pr.onHit != null) {
            p.addStatus(pr.onHit!, pr.onHitDur, pr.onHitPow);
          }
          pr.life = 0;
          break;
        }
      }
    }
  }

  double _contactDmg(EnemyKind k) {
    switch (k) {
      case EnemyKind.bat:
        return 8;
      case EnemyKind.gargoyle:
        return 12;
      case EnemyKind.ghoul:
        return 11;
      case EnemyKind.mage:
      case EnemyKind.archer:
      case EnemyKind.fireMage:
        return 9;
      case EnemyKind.slime:
        return 8;
      case EnemyKind.brute:
        return 16;
      case EnemyKind.grunt:
        return 11;
      case EnemyKind.goblin:
        return 8;
      case EnemyKind.assassin:
        return 12;
      case EnemyKind.heretic:
        return 9;
      case EnemyKind.thief:
        return 6;
      case EnemyKind.knightSoldier:
        return 14;
      case EnemyKind.brawler:
        return 10;
      case EnemyKind.dwarf:
        return 13;
      case EnemyKind.darkElf:
        return 9;
      case EnemyKind.plant:
        return 10;
      case EnemyKind.hammer:
        return 16;
      case EnemyKind.shield:
        return 12;
    }
  }

  /// Status-effect power scaled by floor so shallow-floor foes inflict weak
  /// status damage and deep-floor foes inflict heavy (A4: difficulty scaled).
  double _foePow(double base) => base * (0.5 + floor * 0.09);

  // ---- floor-based difficulty scaling (applied to enemies & bosses) ----
  // Deep floors ramp hard: HP, attack and defense all climb steeply so even the
  // weakest foe (bat: 8 base) hits for ~20 by floor 10 (8 * (1 + 0.15*10)).
  double get _floorHpMul => 1 + 0.16 * floor;
  double get _floorAtkMul => 1 + 0.15 * floor;
  double get _floorDr => (0.016 * floor).clamp(0.0, 0.35);

  /// 0 → 1 reinforcement factor used purely for the deep-floor "darkening
  /// crimson" tint on foes/bosses; tracks the same ramp the stats follow.
  double get reinforce => ((floor - 3) / 13).clamp(0.0, 1.0);

  // Scale a freshly-built foe's HP and defense by the current floor.
  Enemy _scaleEnemy(Enemy e) {
    e.maxHp *= _floorHpMul;
    e.hp = e.maxHp;
    e.dr = _floorDr;
    return e;
  }

  /// Status the player suffers on melee contact with [k]. Knockback applies at
  /// any depth; status effects only from floor 6+ (low floors stay clean).
  void _contactProc(EnemyKind k, double fromX) {
    final p = player;
    final dir = p.cx < fromX ? -1 : 1;
    switch (k) {
      case EnemyKind.dwarf:
        p.vx = dir * 160;
        break;
      case EnemyKind.hammer:
        p.vx = dir * 320; // heavy slam knockback
        break;
      case EnemyKind.shield:
        p.vx = dir * 220;
        break;
      case EnemyKind.thief:
        // snatch a little gold, then it is shoved away as it flees
        final steal = min(gold, 3 + floor);
        gold -= steal;
        p.vx = dir * 120;
        break;
      default:
        break;
    }
    if (floor < 6) return; // no status-inflicting hits on shallow floors
    switch (k) {
      case EnemyKind.goblin:
        p.addStatus(StatusKind.bleed, 2.5, _foePow(4));
        break;
      case EnemyKind.assassin:
        p.addStatus(StatusKind.bleed, 3.0, _foePow(5));
        break;
      case EnemyKind.slime:
        p.addStatus(StatusKind.poison, 3.0, _foePow(5));
        break;
      case EnemyKind.ghoul:
        p.addStatus(StatusKind.poison, 3.5, _foePow(6));
        break;
      case EnemyKind.plant:
        p.addStatus(StatusKind.poison, 3.5, _foePow(6));
        break;
      case EnemyKind.hammer:
        p.addStatus(StatusKind.stun, 0.5, 1);
        break;
      default:
        break;
    }
  }

  // Class perks (D3): agile classes get a mid-air jump; rogue-likes get a dash.
  bool _skullAgile() {
    final c = player.skull.category;
    return c == '특수형' || c == '짐승형';
  }

  bool _skullExtraDash() => player.skull.category == '특수형';

  // Class perk (D3): evasion chance for nimble classes, scaled by skull tier.
  double _perkEvade() {
    final pv = _passive;
    return pv.kind == PassiveKind.evade ? pv.value : 0.0;
  }

  void _hurtPlayer(double d, double fromX,
      {double stun = 0, double kb = 1.0, Entity? source}) {
    final p = player;
    if (p.ghostTimer > 0) return; // 사신 유령화: untouchable
    if (p.stealthTimer > 0) return; // 야밤도 그림자 잠행: unseen, untouchable
    if (p.invuln > 0) return;
    d *= _floorAtkMul; // floor-scaled foe attack power
    // 약탈자 가시 반사: bounce the incoming blow back at whoever dealt it. Falls
    // back to the boss when the source is unknown (most stray hits in a boss
    // fight come from the boss). Bosses are not immune.
    if (p.reflectTimer > 0) {
      final tgt = source ?? boss;
      if (tgt is Boss && !tgt.dead) {
        _damageBoss(tgt, d);
        _fx('ring', tgt.cx, tgt.cy - 10, 0.3, const Color(0xFFFFCA28), size: 44);
      } else if (tgt is Enemy && !tgt.dead) {
        tgt.damage(d);
        _fx('ring', tgt.cx, tgt.cy, 0.3, const Color(0xFFFFCA28), size: 40);
        _hitSpark(tgt.cx, tgt.cy, tgt.cx >= p.cx ? 1 : -1);
      }
    }
    if (p.rideTimer > 0) d *= 0.5; // 망령기사 유령마: incoming damage halved
    // class perk (D3): nimble classes can evade a hit entirely
    final evade = _perkEvade();
    if (evade > 0 && rng.nextDouble() < evade) {
      p.invuln = 0.4;
      _fx('ghost', p.cx, p.cy, 0.25, const Color(0xFF80DEEA),
          dir: p.facing.toDouble(), size: 30);
      return;
    }
    if (p.hasStatus(StatusKind.shield)) d *= 0.4;
    d *= (1 - meta.defenseDrFor(p.skull.category)); // defense trait
    if (_passive.kind == PassiveKind.armor) {
      d *= (1 - _passive.value); // armor passive: reduce damage taken
    }
    p.damage(d);
    p.invuln = 0.85;
    p.vx = (p.cx < fromX ? -1 : 1) * 260 * kb;
    p.vy = -260;
    if (stun > 0) p.addStatus(StatusKind.stun, stun, 1);
    shake = max(shake, 0.25);
    for (int i = 0; i < 10; i++) {
      particles.add(Particle(p.cx, p.cy, (rng.nextDouble() - 0.5) * 300,
          -rng.nextDouble() * 260, 0.5, 5, const Color(0xFFFF5252)));
    }
    if (p.dead && phase == GamePhase.playing) {
      phase = GamePhase.gameover;
      _banner('GAME OVER', 999);
    }
  }

  // ----------------------------------------------------------------
  void _breakShieldCrystal() {
    final c = shieldCrystal;
    if (c == null) return;
    shieldCrystal = null;
    shake = max(shake, 0.3);
    _banner('수정 파괴 — 기사단의 방패가 풀렸다!', 1.4);
    for (int i = 0; i < 24; i++) {
      final a = rng.nextDouble() * pi * 2;
      final sp = 120 + rng.nextDouble() * 240;
      particles.add(Particle(c.center.dx, c.center.dy, cos(a) * sp, sin(a) * sp,
          0.5, 5, const Color(0xFF82B1FF),
          grav: 200));
    }
  }

  void _hitSpark(double x, double y, int dir) {
    for (int i = 0; i < 9; i++) {
      final a = rng.nextDouble() * pi * 2;
      final sp = 110 + rng.nextDouble() * 240;
      particles.add(Particle(
          x,
          y,
          cos(a) * sp + dir * 120,
          sin(a) * sp - 40,
          0.3 + rng.nextDouble() * 0.2,
          3 + rng.nextDouble() * 3,
          i.isEven ? const Color(0xFFFFF59D) : const Color(0xFFFFFFFF),
          grav: 300));
    }
  }

  void _dust(double x, double y) {
    for (int i = 0; i < 6; i++) {
      particles.add(Particle(x, y, (rng.nextDouble() - 0.5) * 120,
          -rng.nextDouble() * 80, 0.4, 4, const Color(0xFFBDBDBD),
          grav: 200));
    }
  }

  void _deathBurst(Entity e) {
    final c = e is Boss ? e.spec.color : const Color(0xFFE0E0E0);
    final n = e is Boss ? 42 : 14;
    for (int i = 0; i < n; i++) {
      final a = rng.nextDouble() * pi * 2;
      final sp = 120 + rng.nextDouble() * (e is Boss ? 420 : 240);
      particles.add(Particle(e.cx, e.cy, cos(a) * sp, sin(a) * sp - 80,
          0.6 + rng.nextDouble() * 0.5, 4 + rng.nextDouble() * 5, c,
          grav: 500));
    }
  }

  // visible world extent given the zoom (camX/camY are the view's top-left)
  double get _viewW => kViewW / kZoom;
  double get _viewH => kViewH / kZoom;
  double get _camTargetX =>
      (player.cx - _viewW / 2).clamp(0.0, max(0.0, roomWidth - _viewW));
  double get _camTargetY {
    const vBottom = kGroundY + 120; // lowest the view bottom may reach
    final maxY = max(camMinY, vBottom - _viewH);
    return (player.cy - _viewH * 0.55).clamp(camMinY, maxY);
  }

  void _camera(double dt) {
    camX += (_camTargetX - camX) * min(1.0, dt * 8);
    camY += (_camTargetY - camY) * min(1.0, dt * 6);
  }

  /// Snap the camera to the player immediately (on room/town entry, no pan).
  void _snapCamera() {
    camX = _camTargetX;
    camY = _camTargetY;
  }

  void _banner(String t, double dur) {
    bannerText = t;
    bannerTimer = dur;
  }

  Offset get shakeOffset {
    if (shake <= 0) return Offset.zero;
    final m = shake * 14;
    return Offset((rng.nextDouble() - 0.5) * m, (rng.nextDouble() - 0.5) * m);
  }
}
