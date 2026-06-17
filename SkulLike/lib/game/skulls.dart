import 'dart:math';
import 'package:flutter/material.dart';
import 'types.dart';

/// A playable skull (class). Defines look, basic-attack feel, and a skill.
class SkullSpec {
  final SkullType type;
  final String name;
  final String desc;
  final String category; // 검사 | 짐승형 | 마법형 | 기사 | 특수형
  final SkullTier tier; // rarer tiers drop less often
  final Color body; // head/body tint
  final Color eye; // eye flame
  final String weapon; // sword | staff | axe | daggers | claws | greatsword | scythe | bomb
  final String skill; // spin | magicburst | slam | blink | pounce | guard | explode | phase
  final String skillName;
  final double atkMul; // basic-attack damage multiplier
  final double reachMul; // basic-attack reach multiplier
  final double speedMul; // move speed multiplier
  final double atkDur; // basic-attack swing duration (lower = faster)
  final double skillCd; // skill cooldown (s)
  final int unlockCost; // souls to unlock in the graveyard
  const SkullSpec({
    required this.type,
    required this.name,
    required this.desc,
    required this.category,
    required this.tier,
    required this.body,
    required this.eye,
    required this.weapon,
    required this.skill,
    required this.skillName,
    this.atkMul = 1.0,
    this.reachMul = 1.0,
    this.speedMul = 1.0,
    this.atkDur = 0.26,
    this.skillCd = 4.0,
    this.unlockCost = 0,
  });

  /// Ranged classes fire a projectile as their basic attack (no melee combo)
  /// and are gated to a slow cadence so mashing can't exceed ~1 shot/sec.
  bool get rangedBasic => category == '마법형' || category == '궁수형';

  /// Throwers lob an arcing item (potion/bomb/rock) as their basic attack.
  bool get throwerBasic =>
      type == SkullType.alchemist ||
      type == SkullType.bomber ||
      type == SkullType.slinger;
}

const Map<SkullType, SkullSpec> kSkulls = {
  // ---------------- COMMON ----------------
  SkullType.basic: SkullSpec(
    type: SkullType.basic,
    name: '기본 해골',
    desc: '균형 잡힌 검사. 회전베기로 주변을 쓸어버린다.',
    category: '검사',
    tier: SkullTier.common,
    body: Color(0xFFECEFF1),
    eye: Color(0xFF26C6DA),
    weapon: 'sword',
    skill: 'spin',
    skillName: '회전베기',
    atkMul: 1.0,
    reachMul: 1.0,
    speedMul: 1.0,
    atkDur: 0.26,
    skillCd: 4.0,
    unlockCost: 0,
  ),
  SkullType.beast: SkullSpec(
    type: SkullType.beast,
    name: '야수 해골',
    desc: '짐승형. 빠른 이동과 손톱 연격, 도약 발톱으로 파고든다.',
    category: '짐승형',
    tier: SkullTier.common,
    body: Color(0xFFA1887F),
    eye: Color(0xFFFFA000),
    weapon: 'claws',
    skill: 'pounce',
    skillName: '도약 발톱',
    atkMul: 0.85,
    reachMul: 0.85,
    speedMul: 1.28,
    atkDur: 0.15,
    skillCd: 3.0,
    unlockCost: 40,
  ),
  // ---------------- RARE ----------------
  SkullType.mage: SkullSpec(
    type: SkullType.mage,
    name: '마법사 해골',
    desc: '마법형. 원거리 견제와 마력탄 폭발로 적을 흩어놓는다.',
    category: '마법형',
    tier: SkullTier.rare,
    body: Color(0xFF9C8CF0),
    eye: Color(0xFFFFE66D),
    weapon: 'staff',
    skill: 'magicburst',
    skillName: '마력 폭발',
    atkMul: 0.8,
    reachMul: 1.25,
    speedMul: 1.05,
    atkDur: 0.22,
    skillCd: 3.2,
    unlockCost: 60,
  ),
  SkullType.rogue: SkullSpec(
    type: SkullType.rogue,
    name: '암살자 해골',
    desc: '짐승처럼 빠른 쌍단검. 순간이동 베기로 적을 관통한다.',
    category: '특수형',
    tier: SkullTier.rare,
    body: Color(0xFF4DB6AC),
    eye: Color(0xFFFF8A65),
    weapon: 'daggers',
    skill: 'blink',
    skillName: '그림자 베기',
    atkMul: 0.7,
    reachMul: 0.9,
    speedMul: 1.18,
    atkDur: 0.17,
    skillCd: 3.0,
    unlockCost: 80,
  ),
  SkullType.berserker: SkullSpec(
    type: SkullType.berserker,
    name: '광전사 해골',
    desc: '느리지만 강력한 도끼. 대지 강타로 충격파를 날린다.',
    category: '검사',
    tier: SkullTier.rare,
    body: Color(0xFFE57373),
    eye: Color(0xFFFFCA28),
    weapon: 'axe',
    skill: 'slam',
    skillName: '대지 강타',
    atkMul: 1.6,
    reachMul: 1.15,
    speedMul: 0.86,
    atkDur: 0.34,
    skillCd: 5.0,
    unlockCost: 90,
  ),
  // ---------------- EPIC ----------------
  SkullType.knight: SkullSpec(
    type: SkullType.knight,
    name: '기사 해골',
    desc: '기사. 묵직한 대검 검술로 적을 크게 밀쳐내고, 거대한 검기(3배 크기)를 날려 적을 꿰뚫는다.',
    category: '기사',
    tier: SkullTier.epic,
    body: Color(0xFFB0BEC5),
    eye: Color(0xFF42A5F5),
    weapon: 'greatsword',
    skill: 'swordwave',
    skillName: '검기 베기',
    atkMul: 1.35,
    reachMul: 1.2,
    speedMul: 0.95,
    atkDur: 0.3,
    skillCd: 5.0,
    unlockCost: 140,
  ),
  SkullType.bomber: SkullSpec(
    type: SkullType.bomber,
    name: '폭심 해골',
    desc: '특수형. 폭탄을 휘두르고, 대폭발과 함께 사방으로 작은 폭탄들을 흩뿌려 연쇄 폭발시킨다.',
    category: '특수형',
    tier: SkullTier.epic,
    body: Color(0xFF8D6E63),
    eye: Color(0xFFFF7043),
    weapon: 'bomb',
    skill: 'explode',
    skillName: '대폭발',
    atkMul: 0.9,
    reachMul: 1.0,
    speedMul: 1.0,
    atkDur: 0.28,
    skillCd: 5.5,
    unlockCost: 140,
  ),
  // ---------------- LEGENDARY ----------------
  SkullType.wraith: SkullSpec(
    type: SkullType.wraith,
    name: '망령 해골',
    desc: '특수형 유령. 거대한 리치를 소환해 화면을 가르는 대낫으로 모든 적을 베고 검은 불꽃으로 태운다.',
    category: '특수형',
    tier: SkullTier.legendary,
    body: Color(0xFF7E57C2),
    eye: Color(0xFFB388FF),
    weapon: 'scythe',
    skill: 'grimscythe',
    skillName: '사령의 대낫',
    atkMul: 1.2,
    reachMul: 1.15,
    speedMul: 1.1,
    atkDur: 0.2,
    skillCd: 12.0,
    unlockCost: 220,
  ),

  // ============================ COMMON ============================
  SkullType.ronin: SkullSpec(type: SkullType.ronin, name: '낭인 해골', desc: '떠도는 검객. 균형 잡힌 검술.', category: '검사', tier: SkullTier.common, body: Color(0xFFCFD8DC), eye: Color(0xFF4DD0E1), weapon: 'sword', skill: 'spin', skillName: '회전베기', atkMul: 1.05, unlockCost: 40),
  SkullType.squire: SkullSpec(type: SkullType.squire, name: '견습 기사', desc: '방패를 든 수련생.', category: '기사', tier: SkullTier.common, body: Color(0xFFB0BEC5), eye: Color(0xFF90CAF9), weapon: 'sword', skill: 'guard', skillName: '방어 태세', atkMul: 1.1, speedMul: 0.98, unlockCost: 40),
  SkullType.brawler: SkullSpec(type: SkullType.brawler, name: '주먹꾼 해골', desc: '맨손 격투가.', category: '권사', tier: SkullTier.common, body: Color(0xFFD7A86E), eye: Color(0xFFFFB74D), weapon: 'gauntlet', skill: 'dashstrike', skillName: '돌진 베기', atkMul: 0.95, speedMul: 1.1, atkDur: 0.18, unlockCost: 40),
  SkullType.hound: SkullSpec(type: SkullType.hound, name: '사냥개 해골', desc: '네 발로 달리는 짐승.', category: '짐승형', tier: SkullTier.common, body: Color(0xFF8D6E63), eye: Color(0xFFFFA726), weapon: 'claws', skill: 'pounce', skillName: '도약 발톱', atkMul: 0.85, reachMul: 0.85, speedMul: 1.25, atkDur: 0.15, unlockCost: 40),
  SkullType.sprinter: SkullSpec(type: SkullType.sprinter, name: '질주자 해골', desc: '바람처럼 빠른 단검술.', category: '특수형', tier: SkullTier.common, body: Color(0xFF4DB6AC), eye: Color(0xFF80CBC4), weapon: 'daggers', skill: 'blink', skillName: '그림자 베기', atkMul: 0.7, speedMul: 1.2, atkDur: 0.16, unlockCost: 40),
  SkullType.footman: SkullSpec(type: SkullType.footman, name: '보병 해골', desc: '긴 창을 든 보병.', category: '창병', tier: SkullTier.common, body: Color(0xFF90A4AE), eye: Color(0xFFB0BEC5), weapon: 'spear', skill: 'quake', skillName: '대지 진동', atkMul: 1.1, reachMul: 1.2, atkDur: 0.28, unlockCost: 40),
  SkullType.slinger: SkullSpec(type: SkullType.slinger, name: '투석꾼 해골', desc: '원거리 견제형.', category: '궁수형', tier: SkullTier.common, body: Color(0xFFA1887F), eye: Color(0xFFFFCC80), weapon: 'bow', skill: 'volley', skillName: '화살 세례', atkMul: 0.75, reachMul: 1.3, atkDur: 0.22, unlockCost: 40),
  SkullType.apprentice: SkullSpec(type: SkullType.apprentice, name: '견습 마법사', desc: '기초 마법을 쓴다.', category: '마법형', tier: SkullTier.common, body: Color(0xFF9C8CF0), eye: Color(0xFFFFE082), weapon: 'staff', skill: 'magicburst', skillName: '마력 폭발', atkMul: 0.8, reachMul: 1.2, atkDur: 0.22, unlockCost: 40),
  SkullType.imp: SkullSpec(type: SkullType.imp, name: '임프 해골', desc: '작은 불꽃 악마.', category: '특수형', tier: SkullTier.common, body: Color(0xFFE57373), eye: Color(0xFFFF7043), weapon: 'claws', skill: 'flames', skillName: '화염 분출', atkMul: 0.8, speedMul: 1.1, atkDur: 0.18, unlockCost: 40),
  SkullType.cutpurse: SkullSpec(type: SkullType.cutpurse, name: '소매치기 해골', desc: '재빠른 도둑.', category: '특수형', tier: SkullTier.common, body: Color(0xFF80CBC4), eye: Color(0xFFFFD54F), weapon: 'daggers', skill: 'dashstrike', skillName: '돌진 베기', atkMul: 0.72, speedMul: 1.18, atkDur: 0.16, unlockCost: 40),
  SkullType.militia: SkullSpec(type: SkullType.militia, name: '민병 해골', desc: '창과 방패의 민병.', category: '창병', tier: SkullTier.common, body: Color(0xFF9E9E9E), eye: Color(0xFF81D4FA), weapon: 'spear', skill: 'guard', skillName: '방어 태세', atkMul: 1.0, reachMul: 1.15, unlockCost: 40),
  SkullType.scout: SkullSpec(type: SkullType.scout, name: '정찰병 해골', desc: '민첩한 궁수.', category: '궁수형', tier: SkullTier.common, body: Color(0xFF81C784), eye: Color(0xFFFFCC80), weapon: 'bow', skill: 'volley', skillName: '화살 세례', atkMul: 0.78, reachMul: 1.25, speedMul: 1.05, atkDur: 0.2, unlockCost: 40),
  SkullType.jester: SkullSpec(type: SkullType.jester, name: '광대 해골', desc: '변칙적인 칼춤.', category: '특수형', tier: SkullTier.common, body: Color(0xFFBA68C8), eye: Color(0xFFFFD54F), weapon: 'daggers', skill: 'blink', skillName: '그림자 베기', atkMul: 0.75, speedMul: 1.2, atkDur: 0.16, unlockCost: 40),
  SkullType.miner: SkullSpec(type: SkullType.miner, name: '광부 해골', desc: '곡괭이로 캐내고 광석을 던진다.', category: '검사', tier: SkullTier.common, body: Color(0xFF8D6E63), eye: Color(0xFFFFB300), weapon: 'pickaxe', skill: 'rockthrow', skillName: '광석 투척', atkMul: 1.3, speedMul: 0.9, atkDur: 0.32, unlockCost: 40),
  SkullType.fisher: SkullSpec(type: SkullType.fisher, name: '어부 해골', desc: '낚싯대를 채찍처럼 휘두르고 그물을 던진다.', category: '창병', tier: SkullTier.common, body: Color(0xFF4FC3F7), eye: Color(0xFF80DEEA), weapon: 'rod', skill: 'net', skillName: '그물 투척', atkMul: 1.0, reachMul: 1.6, atkDur: 0.28, unlockCost: 40),
  SkullType.farmhand: SkullSpec(type: SkullType.farmhand, name: '농부 해골', desc: '도끼질이 묵직하다.', category: '검사', tier: SkullTier.common, body: Color(0xFFA1887F), eye: Color(0xFFFFCA28), weapon: 'axe', skill: 'slam', skillName: '대지 강타', atkMul: 1.4, speedMul: 0.9, atkDur: 0.32, unlockCost: 40),
  SkullType.drummer: SkullSpec(type: SkullType.drummer, name: '북잡이 해골', desc: '망치로 땅을 울린다.', category: '검사', tier: SkullTier.common, body: Color(0xFFBCAAA4), eye: Color(0xFFFF8A65), weapon: 'hammer', skill: 'quake', skillName: '대지 진동', atkMul: 1.25, speedMul: 0.92, atkDur: 0.3, unlockCost: 40),
  SkullType.torchbearer: SkullSpec(type: SkullType.torchbearer, name: '횃불잡이 해골', desc: '불을 다루는 견습.', category: '마법형', tier: SkullTier.common, body: Color(0xFFFF8A65), eye: Color(0xFFFFB74D), weapon: 'staff', skill: 'flames', skillName: '화염 분출', atkMul: 0.85, reachMul: 1.1, atkDur: 0.22, unlockCost: 40),
  SkullType.vagrant: SkullSpec(type: SkullType.vagrant, name: '부랑자 해골', desc: '낡은 검 한 자루.', category: '검사', tier: SkullTier.common, body: Color(0xFFB0BEC5), eye: Color(0xFF26C6DA), weapon: 'sword', skill: 'spin', skillName: '회전베기', atkMul: 1.0, unlockCost: 40),
  SkullType.novice: SkullSpec(type: SkullType.novice, name: '초심자 해골', desc: '갓 입문한 마법사.', category: '마법형', tier: SkullTier.common, body: Color(0xFF9FA8DA), eye: Color(0xFFFFE066), weapon: 'staff', skill: 'magicburst', skillName: '마력 폭발', atkMul: 0.78, reachMul: 1.2, atkDur: 0.22, unlockCost: 40),

  // ============================= RARE =============================
  SkullType.duelist: SkullSpec(type: SkullType.duelist, name: '결투가 해골', desc: '날렵한 일대일 검술.', category: '검사', tier: SkullTier.rare, body: Color(0xFFE0E0E0), eye: Color(0xFF40C4FF), weapon: 'sword', skill: 'dashstrike', skillName: '돌진 베기', atkMul: 1.15, speedMul: 1.05, atkDur: 0.22, unlockCost: 80),
  SkullType.lancer: SkullSpec(type: SkullType.lancer, name: '창기병 해골', desc: '돌격하는 창술.', category: '창병', tier: SkullTier.rare, body: Color(0xFF90A4AE), eye: Color(0xFF4FC3F7), weapon: 'spear', skill: 'dashstrike', skillName: '돌진 베기', atkMul: 1.2, reachMul: 1.25, atkDur: 0.26, unlockCost: 80),
  SkullType.gunner: SkullSpec(type: SkullType.gunner, name: '석궁수 해골', desc: '강한 석궁수. 빠르고 묵직한 볼트를 쏘고, 연속 사격으로 5연발을 퍼붓는다.', category: '궁수형', tier: SkullTier.rare, body: Color(0xFF8D6E63), eye: Color(0xFFFFCC80), weapon: 'bow', skill: 'rapidshot', skillName: '연속 사격', atkMul: 0.85, reachMul: 1.3, atkDur: 0.2, unlockCost: 80),
  SkullType.frostmage: SkullSpec(type: SkullType.frostmage, name: '서리 마법사', desc: '얼음 마법을 다룬다.', category: '마법형', tier: SkullTier.rare, body: Color(0xFF81D4FA), eye: Color(0xFF80DEEA), weapon: 'staff', skill: 'frost', skillName: '서리 파편', atkMul: 0.85, reachMul: 1.2, atkDur: 0.22, unlockCost: 80),
  SkullType.pyromancer: SkullSpec(type: SkullType.pyromancer, name: '화염술사 해골', desc: '거대한 화염구를 날려 폭발시킨다.', category: '마법형', tier: SkullTier.rare, body: Color(0xFFFF7043), eye: Color(0xFFFFD166), weapon: 'staff', skill: 'firestorm', skillName: '화염 폭풍', atkMul: 0.9, reachMul: 1.1, atkDur: 0.22, unlockCost: 80),
  SkullType.ranger: SkullSpec(type: SkullType.ranger, name: '레인저 해골', desc: '숙련된 궁수.', category: '궁수형', tier: SkullTier.rare, body: Color(0xFF66BB6A), eye: Color(0xFFFFCC80), weapon: 'bow', skill: 'volley', skillName: '화살 세례', atkMul: 0.9, reachMul: 1.3, speedMul: 1.05, atkDur: 0.2, unlockCost: 80),
  SkullType.ninja: SkullSpec(type: SkullType.ninja, name: '닌자 해골', desc: '그림자 암살술.', category: '특수형', tier: SkullTier.rare, body: Color(0xFF455A64), eye: Color(0xFFFF8A65), weapon: 'daggers', skill: 'blink', skillName: '그림자 베기', atkMul: 0.85, speedMul: 1.25, atkDur: 0.15, unlockCost: 80),
  SkullType.monk: SkullSpec(type: SkullType.monk, name: '무승 해골', desc: '단련된 격투가. 맨주먹 연타와 정권지르기로 적을 기절시킨다.', category: '권사', tier: SkullTier.rare, body: Color(0xFFFFB74D), eye: Color(0xFFFFE082), weapon: 'gauntlet', skill: 'straightpunch', skillName: '정권지르기', atkMul: 1.05, speedMul: 1.1, atkDur: 0.18, unlockCost: 80),
  SkullType.templar: SkullSpec(type: SkullType.templar, name: '성전사 해골', desc: '대검과 굳건한 방어.', category: '기사', tier: SkullTier.rare, body: Color(0xFFCFD8DC), eye: Color(0xFF82B1FF), weapon: 'greatsword', skill: 'guard', skillName: '방어 태세', atkMul: 1.3, speedMul: 0.95, reachMul: 1.2, atkDur: 0.3, unlockCost: 80),
  SkullType.corsair: SkullSpec(type: SkullType.corsair, name: '해적 해골', desc: '거친 검객.', category: '검사', tier: SkullTier.rare, body: Color(0xFF8D6E63), eye: Color(0xFFFFD54F), weapon: 'sword', skill: 'dashstrike', skillName: '돌진 베기', atkMul: 1.1, speedMul: 1.05, atkDur: 0.22, unlockCost: 80),
  SkullType.warden: SkullSpec(type: SkullType.warden, name: '수문장 해골', desc: '견고한 창병.', category: '기사', tier: SkullTier.rare, body: Color(0xFF78909C), eye: Color(0xFF4FC3F7), weapon: 'spear', skill: 'bulwark', skillName: '강철 방벽', atkMul: 1.15, reachMul: 1.2, speedMul: 0.95, atkDur: 0.28, unlockCost: 80),
  SkullType.alchemist: SkullSpec(type: SkullType.alchemist, name: '연금술사 해골', desc: '폭발 반응을 부른다.', category: '마법형', tier: SkullTier.rare, body: Color(0xFF9CCC65), eye: Color(0xFFFFEE58), weapon: 'staff', skill: 'meteor', skillName: '유성 낙하', atkMul: 0.85, reachMul: 1.2, atkDur: 0.24, unlockCost: 80),
  SkullType.conjurer: SkullSpec(type: SkullType.conjurer, name: '소환술사 해골', desc: '해골 병사를 일으켜 적과 싸우게 한다.', category: '마법형', tier: SkullTier.rare, body: Color(0xFF80DEEA), eye: Color(0xFF18FFFF), weapon: 'staff', skill: 'summon', skillName: '해골 소환', atkMul: 0.85, reachMul: 1.2, atkDur: 0.22, unlockCost: 80),
  SkullType.valkyrie: SkullSpec(type: SkullType.valkyrie, name: '발키리 해골', desc: '발키리를 강림시켜 앞으로 돌진한다.', category: '창병', tier: SkullTier.rare, body: Color(0xFFE0E0E0), eye: Color(0xFFFFF176), weapon: 'spear', skill: 'valkyrie', skillName: '발키리 강림', atkMul: 1.2, reachMul: 1.2, speedMul: 1.05, atkDur: 0.24, unlockCost: 80),
  SkullType.shaman: SkullSpec(type: SkullType.shaman, name: '주술사 해골', desc: '치유의 힘을 다룬다.', category: '마법형', tier: SkullTier.rare, body: Color(0xFF66BB6A), eye: Color(0xFFA5D6A7), weapon: 'staff', skill: 'heal', skillName: '치유의 빛', atkMul: 0.85, reachMul: 1.15, atkDur: 0.22, unlockCost: 80),
  SkullType.trapper: SkullSpec(type: SkullType.trapper, name: '덫사냥꾼 해골', desc: '적이 밟으면 터지는 폭발 덫을 설치한다.', category: '궁수형', tier: SkullTier.rare, body: Color(0xFF8D6E63), eye: Color(0xFFAED581), weapon: 'bow', skill: 'trap', skillName: '폭발 덫 설치', atkMul: 0.88, reachMul: 1.25, atkDur: 0.2, unlockCost: 80),

  // ============================= EPIC =============================
  SkullType.warlord: SkullSpec(type: SkullType.warlord, name: '전쟁군주 해골', desc: '대검으로 전장을 가르고, 주변의 적을 지배해 공격력을 끌어올린 아군으로 부린다.', category: '검사', tier: SkullTier.epic, body: Color(0xFFEF9A9A), eye: Color(0xFFFF5252), weapon: 'greatsword', skill: 'charm', skillName: '군주의 지배', atkMul: 1.5, speedMul: 0.95, reachMul: 1.2, atkDur: 0.3, unlockCost: 150),
  SkullType.archmage: SkullSpec(type: SkullType.archmage, name: '대마법사 해골', desc: '모든 원소를 다룬다. 물·불·바람·땅 중 하나를 무작위로 시전한다 — 불 회오리, 떨어지는 물 구체, 회전하는 바람 칼날, 또는 거인 골렘.', category: '마법형', tier: SkullTier.epic, body: Color(0xFFB39DDB), eye: Color(0xFFFFE066), weapon: 'staff', skill: 'elements', skillName: '4원소 마법', atkMul: 1.0, reachMul: 1.3, atkDur: 0.22, skillCd: 9.0, unlockCost: 150),
  SkullType.dragoon: SkullSpec(type: SkullType.dragoon, name: '용기병 해골', desc: '용의 힘을 깨운 창술사. 평타가 용의 형상으로 뻗고, 용의 비상으로 날아올라(위/아래 키로 자유 비행) 공격력이 대폭 강화된다. 비행 중 3타 콤보를 맞히면 앞으로 돌격해 경로의 적을 꿰뚫는다.', category: '창병', tier: SkullTier.epic, body: Color(0xFF4DB6AC), eye: Color(0xFF1DE9B6), weapon: 'spear', skill: 'dragonform', skillName: '용의 비상', atkMul: 1.35, reachMul: 1.25, atkDur: 0.3, skillCd: 9.0, unlockCost: 150),
  SkullType.reaper: SkullSpec(type: SkullType.reaper, name: '사신 해골', desc: '낫으로 영혼을 거두는 사신. 강림하면 10초간 무적의 유령이 되어 적의 감지에서 사라지고, 스치는 적의 방어력과 체력을 절반으로 떨군다.', category: '특수형', tier: SkullTier.epic, body: Color(0xFF7E57C2), eye: Color(0xFFB388FF), weapon: 'scythe', skill: 'reaperghost', skillName: '사신의 강림', atkMul: 1.25, reachMul: 1.15, atkDur: 0.2, skillCd: 14.0, unlockCost: 150),
  SkullType.paladin: SkullSpec(type: SkullType.paladin, name: '성기사 해골', desc: '하늘에서 거대한 성검을 내리꽂는다. 낙하 중 닿은 적과 착지 범위에 큰 피해를 주고, 검은 10초간 바닥에 꽂혀 그 근처에 있으면 공격력이 대폭 오른다(멀어지면 사라짐).', category: '기사', tier: SkullTier.epic, body: Color(0xFFFFE082), eye: Color(0xFF82B1FF), weapon: 'greatsword', skill: 'swordfall', skillName: '천공의 대검', atkMul: 1.4, speedMul: 0.95, reachMul: 1.2, atkDur: 0.3, unlockCost: 150),
  SkullType.nightblade: SkullSpec(type: SkullType.nightblade, name: '야밤도 해골', desc: '어둠 속의 처형자. 그림자에 잠행하다(최대 10초), 잠행 중 재시전하면 주변 적들에게 순차 순간이동하며 출혈을 입힌다.', category: '특수형', tier: SkullTier.epic, body: Color(0xFF37474F), eye: Color(0xFFFF8A80), weapon: 'daggers', skill: 'shadowveil', skillName: '그림자 잠행', atkMul: 0.95, speedMul: 1.3, atkDur: 0.14, skillCd: 10.0, unlockCost: 150),
  SkullType.stormcaller: SkullSpec(type: SkullType.stormcaller, name: '폭풍술사 해골', desc: '넓은 범위의 모든 적 머리 위에 번개 구름을 씌워 추격하며, 6초간 낙뢰를 3번 내리꽂고 일정 확률로 기절시킨다.', category: '마법형', tier: SkullTier.epic, body: Color(0xFF4FC3F7), eye: Color(0xFF18FFFF), weapon: 'staff', skill: 'stormcloud', skillName: '낙뢰 구름', atkMul: 1.0, reachMul: 1.25, atkDur: 0.22, skillCd: 8.0, unlockCost: 150),
  SkullType.ravager: SkullSpec(type: SkullType.ravager, name: '약탈자 해골', desc: '광폭한 도끼질. 5초간 받는 모든 피해를 공격자에게 그대로 되돌린다 — 보스에게도 통한다.', category: '검사', tier: SkullTier.epic, body: Color(0xFFE57373), eye: Color(0xFFFFCA28), weapon: 'axe', skill: 'reflect', skillName: '가시 반사', atkMul: 1.7, speedMul: 0.85, atkDur: 0.34, skillCd: 10.0, unlockCost: 150),
  SkullType.spectreKnight: SkullSpec(type: SkullType.spectreKnight, name: '망령 기사', desc: '저주받은 사령기사. 대검을 들고, 유령마를 강림시켜 10초간 질주하며 부딪히는 적을 짓밟는다.', category: '특수형', tier: SkullTier.epic, body: Color(0xFF5C6BC0), eye: Color(0xFFB388FF), weapon: 'greatsword', skill: 'ghostride', skillName: '유령마 강림', atkMul: 1.3, reachMul: 1.15, atkDur: 0.26, skillCd: 13.0, unlockCost: 150),
  SkullType.plagueDoctor: SkullSpec(type: SkullType.plagueDoctor, name: '역병 의사', desc: '드넓게 역병 안개를 살포해 적을 전염시킨다. 전염은 주변으로 번지고, 전염된 적이 죽으면 다시 퍼진다.', category: '마법형', tier: SkullTier.epic, body: Color(0xFF9CCC65), eye: Color(0xFF76FF03), weapon: 'staff', skill: 'plague', skillName: '역병 살포', atkMul: 0.95, reachMul: 1.15, atkDur: 0.22, unlockCost: 150),

  // =========================== LEGENDARY ===========================
  SkullType.voidlord: SkullSpec(type: SkullType.voidlord, name: '공허군주 해골', desc: '반월도를 휘두르는 공허의 지배자. 적을 처치할 때마다 공허에서 몬스터(웨어울프·웨어베어·데스나이트·리치)가 태어나 함께 싸운다 — 약하지만 맵을 옮겨도 따라온다. 스킬은 공허 붕괴 폭발.', category: '특수형', tier: SkullTier.legendary, body: Color(0xFF512DA8), eye: Color(0xFFE040FB), weapon: 'falchion', skill: 'explode', skillName: '공허 붕괴', atkMul: 1.4, reachMul: 1.2, atkDur: 0.2, unlockCost: 240),
  SkullType.seraph: SkullSpec(type: SkullType.seraph, name: '치천사 해골', desc: '신성한 빛의 수호자. 이 스컬로 적을 처치할 때마다 공격력이 영구히 오른다. 스킬은 양옆으로 거대한 날개를 펼쳐 닿는 적을 5초간 기절시킨다.', category: '기사', tier: SkullTier.legendary, body: Color(0xFFFFF59D), eye: Color(0xFFFFFFFF), weapon: 'greatsword', skill: 'wings', skillName: '대천사의 날개', atkMul: 1.45, speedMul: 1.0, reachMul: 1.25, atkDur: 0.28, skillCd: 11.0, unlockCost: 240),
  SkullType.lich: SkullSpec(type: SkullType.lich, name: '리치 해골', desc: '죽음의 마법 지배자. 거대한 낫을 3연타로 넓게 휘둘러 앞뒤를 베고, 3타째엔 검은 검기를 날린다. 사령의 손아귀로 적을 속박해 짓이긴다.', category: '특수형', tier: SkullTier.legendary, body: Color(0xFF80CBC4), eye: Color(0xFFB388FF), weapon: 'scythe', skill: 'gravehands', skillName: '사령의 손아귀', atkMul: 1.1, reachMul: 1.3, atkDur: 0.24, unlockCost: 240),
  SkullType.swordsaint: SkullSpec(type: SkullType.swordsaint, name: '검성 해골', desc: '검의 경지에 이른 자. 공격이 매우 빠르고 대시가 길며, 대시 경로에 닿은 적을 벤다. 스킬은 10초간 칼에 긴 푸른 검기를 둘러 사거리와 위력을 끌어올린다.', category: '검사', tier: SkullTier.legendary, body: Color(0xFFE0F7FA), eye: Color(0xFF00E5FF), weapon: 'greatsword', skill: 'bladeaura', skillName: '창천의 검기', atkMul: 1.5, speedMul: 1.05, reachMul: 1.2, atkDur: 0.13, skillCd: 12.0, unlockCost: 240),

  // ============================ SNIPER (epic) ============================
  SkullType.sniper: SkullSpec(type: SkullType.sniper, name: '저격수 해골', desc: '궁수형. 사거리 매우 길고 강력한 저격(기본공격 2배 위력). 레일건은 5초간 뒤로 밀리며 직선 관통탄을 연속 발사한다.', category: '궁수형', tier: SkullTier.epic, body: Color(0xFF455A64), eye: Color(0xFF18FFFF), weapon: 'sniper', skill: 'railgun', skillName: '레일건', atkMul: 1.0, reachMul: 1.5, speedMul: 0.95, atkDur: 0.3, skillCd: 6.0, unlockCost: 160),
};

SkullSpec skull(SkullType t) => kSkulls[t]!;
List<SkullType> get allSkullTypes => SkullType.values;

// ============================================================
// PASSIVES — each skull has its OWN signature passive (not shared by class).
// [value] meaning depends on [kind]: a fraction (atkUp/armor/evade/lifesteal/
// crit/berserk chance-or-bonus), a proc chance (burnHit/stunHit/execute), a
// status power (bleedHit/poisonHit), per-second heal (regenIdle), or just a
// marker (slowHit). The human-readable line is generated by [passiveDesc].
// ============================================================
enum PassiveKind {
  atkUp,
  armor,
  evade,
  lifesteal,
  crit,
  bleedHit,
  burnHit,
  poisonHit,
  slowHit,
  stunHit,
  execute,
  berserk,
  regenIdle,
  multishot,
  killStack, // permanent attack gain per kill (this-run), e.g. seraph
}

class PassiveInfo {
  final String name; // signature passive name (per skull)
  final PassiveKind kind;
  final double value;
  const PassiveInfo(this.name, this.kind, this.value);
}

/// Generated Korean description for a passive, derived from kind + value so the
/// numbers in the UI always match the mechanics.
String passiveDesc(PassiveInfo p) {
  final pct = (p.value * 100).round();
  switch (p.kind) {
    case PassiveKind.atkUp:
      return '공격력 +$pct%';
    case PassiveKind.armor:
      return '받는 피해 -$pct%';
    case PassiveKind.evade:
      return '$pct% 확률로 공격 회피';
    case PassiveKind.lifesteal:
      return '근접 피해의 $pct%만큼 체력 회복';
    case PassiveKind.crit:
      return '$pct% 확률로 치명타(피해 1.8배)';
    case PassiveKind.bleedHit:
      return '공격 적중 시 출혈을 입힌다';
    case PassiveKind.burnHit:
      return '공격 적중 시 $pct% 확률로 화상';
    case PassiveKind.poisonHit:
      return '공격 적중 시 중독을 입힌다';
    case PassiveKind.slowHit:
      return '공격 적중 시 둔화시킨다';
    case PassiveKind.stunHit:
      return '공격 적중 시 $pct% 확률로 기절';
    case PassiveKind.execute:
      return '보스가 아닌 적 적중 시 $pct% 확률로 즉사';
    case PassiveKind.berserk:
      return '체력이 낮을수록 공격력 증가 (최대 +$pct%)';
    case PassiveKind.regenIdle:
      return '초당 체력 ${p.value.toStringAsFixed(0)} 회복';
    case PassiveKind.multishot:
      return '$pct% 확률로 화살을 추가 발사(연사)';
    case PassiveKind.killStack:
      return '적 처치 시마다 공격력 영구 +$pct% (이번 모험 동안 누적)';
  }
}

const Map<SkullType, PassiveInfo> kPassives = {
  // ---- original 8 ----
  SkullType.basic: PassiveInfo('전천후', PassiveKind.atkUp, 0.08),
  SkullType.beast: PassiveInfo('야성의 발톱', PassiveKind.bleedHit, 3),
  SkullType.mage: PassiveInfo('마력 점화', PassiveKind.burnHit, 0.35),
  SkullType.rogue: PassiveInfo('급소 노리기', PassiveKind.crit, 0.20),
  SkullType.berserker: PassiveInfo('광폭화', PassiveKind.berserk, 0.40),
  SkullType.knight: PassiveInfo('강철 의지', PassiveKind.armor, 0.15),
  SkullType.bomber: PassiveInfo('발화', PassiveKind.burnHit, 0.40),
  SkullType.wraith: PassiveInfo('영혼 흡수', PassiveKind.lifesteal, 0.18),
  // ---- common ----
  SkullType.ronin: PassiveInfo('검로', PassiveKind.crit, 0.10),
  SkullType.squire: PassiveInfo('수련', PassiveKind.armor, 0.08),
  SkullType.brawler: PassiveInfo('연타', PassiveKind.lifesteal, 0.10),
  SkullType.hound: PassiveInfo('추적 본능', PassiveKind.evade, 0.12),
  SkullType.sprinter: PassiveInfo('잔상', PassiveKind.evade, 0.15),
  SkullType.footman: PassiveInfo('방진', PassiveKind.armor, 0.08),
  SkullType.slinger: PassiveInfo('둔화 투척', PassiveKind.slowHit, 1),
  SkullType.apprentice: PassiveInfo('미열', PassiveKind.burnHit, 0.25),
  SkullType.imp: PassiveInfo('불씨', PassiveKind.burnHit, 0.30),
  SkullType.cutpurse: PassiveInfo('기습', PassiveKind.crit, 0.12),
  SkullType.militia: PassiveInfo('결속', PassiveKind.armor, 0.08),
  SkullType.scout: PassiveInfo('견제 사격', PassiveKind.slowHit, 1),
  SkullType.jester: PassiveInfo('교란', PassiveKind.evade, 0.12),
  SkullType.miner: PassiveInfo('단단한 손', PassiveKind.atkUp, 0.12),
  SkullType.fisher: PassiveInfo('낚아채기', PassiveKind.slowHit, 1),
  SkullType.farmhand: PassiveInfo('억센 팔', PassiveKind.atkUp, 0.12),
  SkullType.drummer: PassiveInfo('진동', PassiveKind.stunHit, 0.10),
  SkullType.torchbearer: PassiveInfo('불꽃', PassiveKind.burnHit, 0.30),
  SkullType.vagrant: PassiveInfo('생존 본능', PassiveKind.evade, 0.08),
  SkullType.novice: PassiveInfo('점화 학습', PassiveKind.burnHit, 0.20),
  // ---- rare ----
  SkullType.duelist: PassiveInfo('일격필살', PassiveKind.crit, 0.18),
  SkullType.lancer: PassiveInfo('돌파', PassiveKind.atkUp, 0.14),
  SkullType.gunner: PassiveInfo('관통탄', PassiveKind.slowHit, 1),
  SkullType.frostmage: PassiveInfo('한기', PassiveKind.slowHit, 1),
  SkullType.pyromancer: PassiveInfo('연소', PassiveKind.burnHit, 0.40),
  SkullType.ranger: PassiveInfo('연사', PassiveKind.multishot, 0.30),
  SkullType.ninja: PassiveInfo('암살술', PassiveKind.crit, 0.22),
  SkullType.monk: PassiveInfo('내공', PassiveKind.lifesteal, 0.14),
  SkullType.templar: PassiveInfo('신념', PassiveKind.armor, 0.14),
  SkullType.corsair: PassiveInfo('약탈', PassiveKind.lifesteal, 0.12),
  SkullType.warden: PassiveInfo('수호', PassiveKind.armor, 0.14),
  SkullType.alchemist: PassiveInfo('맹독 조제', PassiveKind.poisonHit, 5),
  SkullType.conjurer: PassiveInfo('집중', PassiveKind.atkUp, 0.12),
  SkullType.valkyrie: PassiveInfo('전투의 함성', PassiveKind.berserk, 0.30),
  SkullType.shaman: PassiveInfo('생명 순환', PassiveKind.regenIdle, 2),
  SkullType.trapper: PassiveInfo('약점 포착', PassiveKind.slowHit, 1),
  // ---- epic ----
  SkullType.warlord: PassiveInfo('군주의 위압', PassiveKind.atkUp, 0.18),
  SkullType.archmage: PassiveInfo('대화염', PassiveKind.burnHit, 0.45),
  SkullType.dragoon: PassiveInfo('낙뢰격', PassiveKind.crit, 0.18),
  SkullType.reaper: PassiveInfo('영혼 수확', PassiveKind.lifesteal, 0.20),
  SkullType.paladin: PassiveInfo('성스러운 가호', PassiveKind.armor, 0.18),
  SkullType.nightblade: PassiveInfo('처형', PassiveKind.execute, 0.06),
  SkullType.stormcaller: PassiveInfo('감전', PassiveKind.stunHit, 0.15),
  SkullType.ravager: PassiveInfo('피의 갈증', PassiveKind.berserk, 0.45),
  SkullType.spectreKnight: PassiveInfo('저주', PassiveKind.bleedHit, 4),
  SkullType.plagueDoctor: PassiveInfo('역병 보균', PassiveKind.poisonHit, 5),
  // ---- legendary ----
  SkullType.voidlord: PassiveInfo('공허 침식', PassiveKind.crit, 0.25),
  SkullType.seraph: PassiveInfo('천상의 분노', PassiveKind.killStack, 0.2),
  SkullType.lich: PassiveInfo('죽음의 손길', PassiveKind.poisonHit, 7),
  SkullType.swordsaint: PassiveInfo('심검', PassiveKind.crit, 0.30),
  // ---- sniper ----
  SkullType.sniper: PassiveInfo('저격수의 눈', PassiveKind.execute, 0.08),
};

PassiveInfo passiveOf(SkullType t) =>
    kPassives[t] ?? const PassiveInfo('—', PassiveKind.atkUp, 0);

/// Drop/roll weight per tier — better skulls are rarer.
int tierWeight(SkullTier t) {
  switch (t) {
    case SkullTier.common:
      return 100;
    case SkullTier.rare:
      return 45;
    case SkullTier.epic:
      return 16;
    case SkullTier.legendary:
      return 5;
  }
}

String tierLabel(SkullTier t) {
  switch (t) {
    case SkullTier.common:
      return '일반';
    case SkullTier.rare:
      return '희귀';
    case SkullTier.epic:
      return '영웅';
    case SkullTier.legendary:
      return '전설';
  }
}

Color tierColor(SkullTier t) {
  switch (t) {
    case SkullTier.common:
      return const Color(0xFFB0BEC5);
    case SkullTier.rare:
      return const Color(0xFF42A5F5);
    case SkullTier.epic:
      return const Color(0xFFB388FF);
    case SkullTier.legendary:
      return const Color(0xFFFFD166);
  }
}

/// Pick a skull from [candidates], weighted so rarer tiers appear less often.
/// [luckMul] (>=1) scales up the weight of rare+ tiers — higher = more likely
/// to roll better skulls (driven by the village luck trait).
/// Returns null when [candidates] is empty.
SkullType? rollSkull(Random rng, Iterable<SkullType> candidates,
    {double luckMul = 1.0}) {
  final pool = candidates.toList();
  if (pool.isEmpty) return null;
  final weights = [
    for (final t in pool) _luckedWeight(skull(t).tier, luckMul)
  ];
  final total = weights.fold<double>(0, (a, b) => a + b);
  double r = rng.nextDouble() * total;
  for (int i = 0; i < pool.length; i++) {
    r -= weights[i];
    if (r < 0) return pool[i];
  }
  return pool.last;
}

/// Tier weight with the luck multiplier applied to rare+ tiers (common stays).
double _luckedWeight(SkullTier t, double luckMul) {
  final base = tierWeight(t).toDouble();
  if (t == SkullTier.common) return base;
  return base * luckMul;
}
