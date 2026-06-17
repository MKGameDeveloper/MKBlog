import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'types.dart';

/// Persistent meta-progression saved across runs (souls, upgrades, skulls).
class MetaState {
  int souls = 0;
  int upMaxHp = 0; // each level: +20 max hp
  int upAtk = 0; // each level: +10% attack
  int upDodge = 0; // each level: +1 dodge charge (max 2)
  // one-time start skull rolled at the graveyard; consumed at run start.
  // persisted so it survives an app restart, cleared once a run begins.
  SkullType? preparedSkull;

  // ---- village traits (skill-tree, persisted, expensive) ----
  int trAttack = 0; // attack focus
  int trDefense = 0; // defense focus
  int trUtility = 0; // utility (souls / move speed)
  int trPull = 0; // extra graveyard pulls (gated behind utility)
  int trLuck = 0; // higher-tier skull roll chance (gated behind utility)

  // bosses already encountered this app session (NOT persisted) — a boss
  // won't reappear until the game is restarted.
  final Set<String> usedBosses = {};

  static const _kSouls = 'souls';
  static const _kHp = 'upMaxHp';
  static const _kAtk = 'upAtk';
  static const _kDodge = 'upDodge';
  static const _kPrepared = 'preparedSkull';
  static const _kTrAtk = 'trAttack';
  static const _kTrDef = 'trDefense';
  static const _kTrUtil = 'trUtility';
  static const _kTrPull = 'trPull';
  static const _kTrLuck = 'trLuck';

  // ---- derived bonuses ----
  double get bonusMaxHp => upMaxHp * 20.0;
  double get bonusAtkMul => upAtk * 0.10;
  int get dodgeCharges => 1 + upDodge;

  int get maxDodgeLevel => 2;
  int hpCost() => 20 + upMaxHp * 18;
  int atkCost() => 25 + upAtk * 22;
  int dodgeCost() => 60 + upDodge * 80;

  // ---- trait limits / cost / effects ----
  int traitMax(String k) => k == 'pull' ? 2 : 5;
  int traitLevel(String k) {
    if (k == 'attack') return trAttack;
    if (k == 'defense') return trDefense;
    if (k == 'utility') return trUtility;
    if (k == 'pull') return trPull;
    if (k == 'luck') return trLuck;
    return 0;
  }

  /// Prereq for graveyard-pull and luck nodes: invest in utility first.
  bool traitUnlocked(String k) =>
      (k == 'pull' || k == 'luck') ? trUtility >= 2 : true;
  int traitCost(int lv) => (120 * pow(1.6, lv)).round();

  /// Pulls allowed per town visit (base 1, raised by the pull trait).
  int get maxPulls => 1 + trPull;
  double atkTraitMul(String cat) {
    double m = trAttack * 0.06;
    if (cat == '검사' || cat == '짐승형' || cat == '권사' || cat == '창병') {
      m += trAttack * 0.04; // extra for melee-attack categories
    }
    return m;
  }

  double defenseDrFor(String cat) {
    double dr = trDefense * 0.05;
    if (cat == '기사') dr += trDefense * 0.03; // knights tank better
    return dr.clamp(0.0, 0.7);
  }

  double get traitBonusHp => trDefense * 15.0;
  double get soulGainMul => 1 + trUtility * 0.12;
  double get traitSpeedMul => 1 + trUtility * 0.03;

  /// Multiplier applied to rare+ tier weights when rolling skulls.
  /// Each luck level makes higher-tier skulls noticeably more likely.
  double get luckMul => 1 + trLuck * 0.35;

  /// Start skull for the next run: the prepared (one-time) skull, else basic.
  SkullType get startSkull => preparedSkull ?? SkullType.basic;

  /// Consume the prepared skull at run start (it does not carry to later runs).
  SkullType takeStartSkull() {
    final t = preparedSkull ?? SkullType.basic;
    preparedSkull = null;
    return t;
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    souls = p.getInt(_kSouls) ?? 0;
    upMaxHp = p.getInt(_kHp) ?? 0;
    upAtk = p.getInt(_kAtk) ?? 0;
    upDodge = p.getInt(_kDodge) ?? 0;
    trAttack = p.getInt(_kTrAtk) ?? 0;
    trDefense = p.getInt(_kTrDef) ?? 0;
    trUtility = p.getInt(_kTrUtil) ?? 0;
    trPull = p.getInt(_kTrPull) ?? 0;
    trLuck = p.getInt(_kTrLuck) ?? 0;
    final sn = p.getString(_kPrepared) ?? '';
    preparedSkull = sn.isEmpty
        ? null
        : SkullType.values
            .firstWhere((t) => t.name == sn, orElse: () => SkullType.basic);
    if (preparedSkull == SkullType.basic) preparedSkull = null;
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kSouls, souls);
    await p.setInt(_kHp, upMaxHp);
    await p.setInt(_kAtk, upAtk);
    await p.setInt(_kDodge, upDodge);
    await p.setInt(_kTrAtk, trAttack);
    await p.setInt(_kTrDef, trDefense);
    await p.setInt(_kTrUtil, trUtility);
    await p.setInt(_kTrPull, trPull);
    await p.setInt(_kTrLuck, trLuck);
    await p.setString(_kPrepared, preparedSkull?.name ?? '');
  }

  // ---- mutations (caller saves) ----
  bool buyHp() {
    if (souls < hpCost()) return false;
    souls -= hpCost();
    upMaxHp++;
    return true;
  }

  bool buyAtk() {
    if (souls < atkCost()) return false;
    souls -= atkCost();
    upAtk++;
    return true;
  }

  bool buyDodge() {
    if (upDodge >= maxDodgeLevel || souls < dodgeCost()) return false;
    souls -= dodgeCost();
    upDodge++;
    return true;
  }

  /// Buy one level of a trait node. Respects prereq, max level and cost.
  bool buyTrait(String k) {
    final lv = traitLevel(k);
    if (lv >= traitMax(k) || !traitUnlocked(k)) return false;
    final c = traitCost(lv);
    if (souls < c) return false;
    souls -= c;
    if (k == 'attack') trAttack++;
    if (k == 'defense') trDefense++;
    if (k == 'utility') trUtility++;
    if (k == 'pull') trPull++;
    if (k == 'luck') trLuck++;
    return true;
  }
}
