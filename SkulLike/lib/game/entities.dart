import 'dart:ui';
import 'types.dart';
import 'skulls.dart';

class Entity {
  double x, y, w, h;
  double vx = 0, vy = 0;
  int facing = 1;
  bool onGround = false;
  double hp, maxHp;
  double hitFlash = 0;
  double hurtTimer = 0; // brief flinch animation on taking damage
  double animTime = 0;
  bool dead = false;
  double dr = 0; // damage reduction (0..1) — floor-scaled defense for foes
  final List<Status> statuses = [];

  Entity(this.x, this.y, this.w, this.h, this.maxHp) : hp = maxHp;

  bool hasStatus(StatusKind k) => statuses.any((s) => s.kind == k);

  /// Apply (or refresh, keeping the stronger/longer) a status effect.
  void addStatus(StatusKind k, double timer, double power) {
    // bosses are immune to stun (they never get locked out of their patterns)
    if (this is Boss && k == StatusKind.stun) return;
    for (final s in statuses) {
      if (s.kind == k) {
        if (timer > s.timer) s.timer = timer;
        if (power > s.power) s.power = power;
        return;
      }
    }
    statuses.add(Status(k, timer, power));
  }

  Rect get rect => Rect.fromLTWH(x, y, w, h);
  double get cx => x + w / 2;
  double get cy => y + h / 2;
  Offset get center => Offset(cx, cy);

  void damage(double d) {
    if (dr > 0 && d > 0) d *= (1 - dr); // defense mitigates direct hits
    hp -= d;
    if (hitFlash < 0.1) hitFlash = 0.14;
    hurtTimer = 0.18;
    // brief pushback on damage
    if (d > 0) {
      // small knockback impulse applied externally where appropriate
    }
    if (hp <= 0) {
      hp = 0;
      dead = true;
    }
  }

  void applyKnockback(double vx, double vy) {
    this.vx = vx;
    this.vy = vy;
  }
}

class Player extends Entity {
  // equipped skulls (1-2). active is the one in use.
  List<SkullSpec> skulls;
  int active = 0;

  // basic-attack combo
  int comboStep = 0;
  double attackTimer = 0;
  double attackDuration = 0.26;
  double comboWindow = 0;
  // buffered attack press: set when input arrives mid-swing, replayed when the
  // swing ends so rapid mashing chains 1→2→3 reliably.
  double attackBuffer = 0;
  // true once the 3rd-combo finisher flourish has fired this swing.
  bool finisherFired = false;
  // earth-slam cast in the air waits to burst until the player lands.
  bool slamPending = false;
  final Set<Entity> hitThisSwing = {};

  double invuln = 0;
  double coyote = 0;
  double swapCd = 0;
  bool hidden = false; // standing in a bush, breaks enemy line-of-sight

  // dodge (charges regenerate over time)
  int dodgeMax;
  double dodgeCharge;
  int airJumpsLeft = 0; // remaining mid-air jumps (double-jump perk)
  double dodgeTimer = 0;
  int dodgeDir = 1;

  // skill
  double skillTimer = 0; // remaining cooldown
  double skillActive = 0; // anim window
  // 석궁수 연속 사격: queued bolts left in the burst + per-shot cadence timer
  int burstShots = 0;
  double burstCd = 0;
  // 용기병 용의 비상: while >0 the player sprouts wings, flies (low gravity +
  // flap-to-ascend) and gains a large attack-power boost.
  double flyTimer = 0;
  // 사신 사신의 강림: while >0 the player is an invulnerable, undetectable ghost
  // that halves the HP/defense of any foe it touches.
  double ghostTimer = 0;
  // 망령기사 유령마 강림: while >0 the player rides a ghost horse — +50% move &
  // jump, incoming damage halved, and ramming a foe deals heavy collision damage
  // (each foe rammed only once per ride, tracked in [rammed]).
  double rideTimer = 0;
  final Set<Entity> rammed = {};
  // 야밤도 그림자 잠행: while >0 the player is a near-invisible shadow that foes
  // cannot perceive (like the reaper's ghost). Re-casting while active fires the
  // teleport-assassination instead of re-entering stealth.
  double stealthTimer = 0;
  // 약탈자 가시 반사: while >0 incoming damage is bounced back at the attacker
  // (bosses included).
  double reflectTimer = 0;
  // 검성 창천의 검기: while >0 a long blue blade-aura extends the basic-attack
  // reach and boosts damage (see atkMul / attackHitbox).
  double auraTimer = 0;
  // 검성 long dash: foes swept by the dash are damaged once each, tracked here.
  final Set<Entity> dashHits = {};
  // 저격수 레일건: while >0 the sniper auto-fires rail beams (recoiling backward);
  // [railgunCd] paces the shots.
  double railgunTimer = 0;
  double railgunCd = 0;

  Player(double x, double y, SkullSpec first, this.dodgeMax, double maxHp)
      : skulls = [first],
        dodgeCharge = dodgeMax.toDouble(),
        super(x, y, 34, 50, maxHp);

  SkullSpec get skull => skulls[active];
  bool get attacking => attackTimer > 0;
  bool get dodging => dodgeTimer > 0;

  Rect attackHitbox() {
    // 리치: a sweeping scythe — wider than usual and reaching partly BEHIND the
    // skull, so the 3-hit combo clips foes on both sides.
    if (skull.type == SkullType.lich) {
      final fwd = (comboStep >= 3 ? 104.0 : 86.0) * skull.reachMul;
      const back = 36.0; // partial reach behind the swing
      const hh = 72.0;
      final hx = facing == 1 ? cx - back : cx - fwd;
      return Rect.fromLTWH(hx, cy - hh / 2, fwd + back, hh);
    }
    final base = comboStep >= 3 ? 90.0 : 66.0;
    // 검성 창천의 검기: the blue aura greatly lengthens the blade's reach.
    final auraMul = auraTimer > 0 ? 1.9 : 1.0;
    final reach = base * skull.reachMul * auraMul;
    const hh = 58.0;
    final hx = facing == 1 ? x + w - 6 : x - reach + 6;
    final hy = cy - hh / 2;
    return Rect.fromLTWH(hx, hy, reach, hh);
  }
}

class Enemy extends Entity {
  final EnemyKind kind;
  double atkCd = 0;
  double t2 = 0; // generic sub-timer (lunge / hop windows)
  double phase;
  double homeY;
  // plant trap variant: 0=poison spitter, 1=teleporter, 2=fireball,
  // 3=overhead ambush (rises only when the player passes above, then binds).
  int plantVariant = 0;

  // perception / navigation
  bool aggro = false;
  double aggroTimer = 0; // stays aggro briefly after losing sight
  double jumpCd = 0; // cooldown between navigation jumps
  double dropTimer = 0; // while >0, falls through one-way platforms
  bool reaped = false; // touched by the reaper's ghost — HP/defense already cut

  // animation
  double attackAnim = 0; // counts down during an attack motion
  double windup = 0; // counts down during a pre-attack telegraph

  Enemy(this.kind, double x, double y, double w, double h, double hp,
      this.phase)
      : homeY = y,
        super(x, y, w, h, hp);
}

/// A temporary friendly fighter. Seeks the nearest enemy, swings at it, and
/// crumbles when its lifetime runs out. Two flavors: a conjured skeleton
/// soldier (default look), or a charmed monster — when [source] is set it
/// renders as that creature and keeps its size.
class Ally extends Entity {
  double life; // remaining lifetime (s)
  final double maxLife;
  double atkCd = 0;
  double jumpCd = 0; // cooldown between chase jumps
  double atk; // damage dealt per swing (before atkMul)
  final Enemy? source; // charmed monster to render as (null = skeleton)
  // 공허군주 공허 몬스터: a creature kind to render as ('werewolf'|'werebear'|
  // 'deathknight'|'lich'); empty = ordinary skeleton/charmed soldier.
  final String kind;
  // persistent void minions don't decay over time and survive room transitions
  // (they only die when their HP is whittled down by foes).
  final bool persistent;

  Ally(double x, double y, this.maxLife, double hp,
      {this.atk = 8, this.source, this.kind = '', this.persistent = false})
      : life = maxLife,
        super(x, y, source?.w ?? _kindW(kind), source?.h ?? _kindH(kind), hp);

  static double _kindW(String kind) {
    switch (kind) {
      case 'earthgolem':
        return 42;
      case 'werebear':
        return 30;
      case 'werewolf':
      case 'deathknight':
        return 24;
      case 'lich':
        return 22;
      default:
        return 20; // skeleton soldier
    }
  }

  static double _kindH(String kind) {
    switch (kind) {
      case 'earthgolem':
        return 56;
      case 'werebear':
        return 38;
      case 'deathknight':
        return 36;
      case 'werewolf':
        return 34;
      case 'lich':
        return 34;
      default:
        return 30;
    }
  }
}

/// A thunderhead conjured over a single foe by the stormcaller. It chases its
/// [target] for [life] seconds, calling down [strikesLeft] lightning bolts
/// (paced by [strikeCd]) that damage and may stun.
class StormCloud {
  final Entity target;
  double x, y; // hovers above the target
  double life; // remaining lifetime (s)
  int strikesLeft; // bolts still to fall
  double strikeCd; // time until the next bolt
  double t = 0; // animation clock
  double boltFlash = 0; // brief brighten right after a strike
  final double dmg; // damage per bolt (baked with atkMul at cast)
  StormCloud(this.target, this.x, this.y,
      {this.life = 6, this.strikesLeft = 3, this.strikeCd = 0.8, this.dmg = 22});
}

class Boss extends Entity {
  final BossSpec spec;
  BossState state = BossState.idle;
  double stateTimer = 0;
  double atkCd = 2.2;
  bool airborne = false;

  // pattern sub-state
  double subTimer = 0; // generic timer for multi-hit / sub-phases
  int hits = 0; // counter within a multi-hit pattern (e.g. flurry)
  double guard = 0; // >0 = guarding (reduced incoming damage)
  bool enraged = false; // second phase below 50% hp
  // multi-pattern: chosen per attack cycle; idle basic/guard cadence
  String pattern = '';
  double idleActCd = 0;
  double aimX = 0; // locked target x for dive/observed-position attacks
  // sequenced behaviour: a themed playbook is enqueued and consumed one step at
  // a time so each boss weaves basics → moves → skills → defence distinctly,
  // instead of picking a single random pattern every cycle.
  final List<String> queue = <String>[];
  // flight: while [hover] > 0 gravity is disabled and the boss floats toward
  // [hoverTargetY] (witch/eagle soar; they descend to rest when it runs out).
  double hover = 0;
  double hoverTargetY = 0;

  Boss(this.spec, double x, double y) : super(x, y, 84, 96, spec.maxHp);

  String get name => spec.name;
}
