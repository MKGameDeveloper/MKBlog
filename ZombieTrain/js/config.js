/* =========================================================================
 * config.js — 게임 밸런스 상수 (튜닝은 거의 전부 여기서)
 *  v2: 개인별 스탯 · 물 자원 · 바이옴 시퀀스 · 2.5D 탐험 · 감염/은신/확률 파밍
 * ========================================================================= */
const CONFIG = {
  personMax: 100,                         // 개인 스탯(체력/배고픔/목마름/멘탈/감염) 최대
  max: { food: 100, water: 100, fuel: 100, durability: 100 },  // 비축/기차 막대

  start: {
    food: 55, water: 55, fuel: 100, durability: 100,
    scrap: 16, parts: 5, meds: 2,
    cars: 2,                              // 객차 수(=동료 수용량)
  },

  // 주행 속도 (kmh=거리/표시, f=연료배율)
  speeds: [
    { name: '정지', kmh: 0,   f: 0 },
    { name: '저속', kmh: 45,  f: 0.6 },
    { name: '보통', kmh: 85,  f: 1.0 },
    { name: '고속', kmh: 130, f: 1.8 },
  ],
  defaultSpeedIdx: 2,
  distanceScale: 0.007,                    // km = kmh * dt * scale (보통≈0.6km/s)

  // 연료: 보통속도 실시간 약 10분에 고갈 (100 / 0.16 ≈ 625s)
  fuel: { perSec: 0.16 },

  // 개인 needs (초당)
  needs: {
    hungerRise: 0.34, thirstRise: 0.46,   // 미보급 시 상승 (배고픔≈5분, 목마름≈3.6분)
    hungerRecover: 7, thirstRecover: 8,   // 보급 중 하강
    foodPerCrewSec: 0.55, waterPerCrewSec: 0.7, // 보급 시 비축 소모/인
    starveHpPerSec: 1.0,                  // 배고픔/목마름 100일 때 체력 감소
    hpRecoverPerSec: 0.7,                 // 잘 먹고 마실 때 체력 회복
  },

  mental: {
    decayPerSec: 0.05, needPenalty: 0.22, // 배고픔/목마름 심할 때 추가 감소
    nightPenalty: 0.06, infectPenalty: 0.15,
    recoverPerSec: 0.12, furnitureBonus: 0.22,
    lowThreshold: 30,                     // 이하에서 작업 효율 저하
    deathHit: 18,                         // 동료 사망 시 전원 멘탈 타격
  },

  infection: {
    hitChance: 0.22,                      // 좀비 접촉 시 감염 확률
    risePerSec: 0.5, researchResist: 0.5, // 연구전문가 보유 시 진행 절반
    medsCure: 40,                         // 약 1개로 감염 감소량
    hpDrainPerSec: 0.6, drainAbove: 55,   // 감염>55에서 체력 감소
    turnAt: 100,                          // 100이면 사망/변이
    warnIntervalMin: 6, warnIntervalMax: 13,  // 경고 말풍선 간격(초) — '가끔' 표시
  },

  // 날씨(전역) — 맑음/비/폭염 전환. 비=체온↓, 폭염=체온↑
  weather: {
    minClearSec: 70, maxClearSec: 200,    // 맑음 지속
    minRainSec: 35, maxRainSec: 95,       // 비 지속
    minHeatSec: 40, maxHeatSec: 110,      // 폭염 지속
    rampPerSec: 0.18,                     // 강도(0~1) 보간 속도
    rainChance: 0.42, heatChance: 0.24,   // 전환 시 비/폭염 확률(나머지는 계속 맑음)
  },

  // 체온(개인) — 비/밤=하강, 폭염=상승. 실내·기차·은신처·옷으로 완화. 천천히 변함
  temp: {
    normal: 37, min: 28, max: 42,
    rainChill: 6,            // 완전한 비에 노출 시 목표 체온 하강폭
    heatRise: 4.2,           // 완전한 폭염에 노출 시 목표 체온 상승폭
    nightChill: 1.5,         // 야간 노출 추가 하강
    feverMax: 3.2,           // 감염 100%에서 발열로 상승하는 최대폭
    coolRate: 0.12,          // 노출 시 냉각 속도(°C/s) — 서서히
    heatRate: 0.12,          // 폭염 가열 속도(°C/s)
    warmRate: 0.5,           // 가벼운 회복 속도
    shelterWarmRate: 0.9,    // 실내/기차에서 평온 회복 속도
    clothHeatFactor: 0.5,    // 폭염에서 옷 보온값이 더위에 더해지는 비율
    coldWarnBelow: 35.5,     // 이하에서 멘탈 저하·경고
    coldHpBelow: 33,         // 이하에서 저체온 체력 감소
    feverWarnAbove: 38.6,    // 이상에서 발열/더위 경고
    feverHpAbove: 39.6,      // 이상에서 체력 감소
    hpDrainCold: 0.6, hpDrainFever: 0.35,
    mentalPenaltyCold: 0.15,
    steadyMul: 0.42,         // '안정형 체온' 특성 보유자의 체온 변화 속도 배율
  },

  // 인벤토리(탐험 중 휴대) — 무게 제한, 가방으로 확장, 기차에서 적재(자원으로 환산)
  inv: {
    baseCap: 10,             // 기본 휴대 무게(가방 장착 시 +가방 cap)
    porterBonus: 8,          // 짐꾼 특성 보유 시 기본 한도 추가
  },

  // 정차(탐험) 중 기차 내구도 — 기차에 붙은 좀비 수에 비례해서만 감소
  stop: {
    durPerZombiePerSec: 0.9,    // 기차에 붙은 좀비 1마리당 초당 내구도 감소
    threatGrowthPerSec: 0.015,  // 시간 경과에 따른 웨이브 규모 증가용
    durBreakHpPerSec: 1.5,
  },

  repair: { scrapPerDur: 0.30, partsPerDur: 0.05, perCarMul: 0.18 },
  addCar: { baseScrap: 45, baseParts: 14, growth: 1.7 },

  // 농사
  farm: {
    plantScrap: 3,
    inner: { growSec: 70, yield: 26 },          // 내부: 실시간 성장, 동료 1명 점유
    outer: { growKm: 120, yield: 60, decayChance: 0.5, fenceProtect: 0.8 }, // 외부: 거리 성장
    fenceScrap: 6, fenceParts: 2,
  },

  // 탐험(2.5D 탑뷰)
  explore: {
    playerSpeed: 92,                     // 느리게(이동이 멀고 어렵게)
    sprintMul: 1.4, sprintDrainPerSec: 17, staminaMax: 100, staminaRegen: 3.5,  // 달리기(소리 큼), 회복 느리게
    sprintRecoverAt: 35,                 // 스태미나 0으로 지치면 이만큼 회복돼야 다시 달릴 수 있음
    zombieSpeed: 66, zombieChaseRange: 200, zombieLoseRange: 300,
    detectRange: 175, hiddenDetectRange: 36,
    zombieGiveUpSec: 2.6,                // 시야 잃은 뒤 추격 포기까지 시간
    trainDriftMul: 0.5, trainAttackRange: 135,   // 평소 기차로 이동 속도배율 / 기차 공격 판정 반경
    trainSiegeDelaySec: 40,              // 정차 후 이 시간이 지나야 좀비가 기차로 몰려듦(그 전엔 배회)
    searchSec: 1.5, attackCooldown: 0.45, attackRange: 52,
    attackAngle: 28,                     // 맨손 부채꼴 반각(도) — 좁게(무기로 넓힘)
    wallThick: 9, doorGap: 44,           // 건물 벽 두께 / 출입문 폭(진입형 파밍)
    aimDecaySec: 0.7,                    // 조준선(클릭 지점) 유지 시간
    // 소리(청각) — 달리기/공격/문 부수기가 주변 좀비를 끌어들임(벽 무시)
    noiseWalk: 60, noiseRun: 270, noiseAttack: 190, noiseBreak: 360,
    investigateSec: 6, investigateSpeedMul: 0.78,   // 소리 조사 지속(도착 후 수색 시간 포함)/이동 속도
    // 잠긴 문 — 높은 확률로 잠겨 있음. 부수면(시간↑·소리 큼) 또는 제작전문가가 따면(빠름·조용) 진입
    lockChance: 0.62, doorBreakSec: 3.4, doorPickSec: 1.6, doorPickFastSec: 0.9,   // fast=열쇠공
    zombieDoorBreakPerSec: 0.10,         // 닫힌 문에 붙은 좀비 1마리당 초당 문 파손(여러 마리면 빨라짐)
    // 자동차 알람(기계전문가) — 부품으로 설치, 작동 시 넓은 반경의 좀비 유인
    alarmParts: 3, alarmInstallSec: 2.6, alarmRingSec: 12, alarmRadius: 720,
    contactDamage: 10, contactCooldown: 0.9,
    hurtFlashSec: 0.8,                   // 피격 후 동료 상태창이 불투명하게 강조되는 시간(탐험 중)
    // 동행 동료: 플레이어를 따라다니며 좀비를 자동 공격(피격 시 해당 동료의 실제 체력·감염에 반영)
    followerEngageRange: 175, followerAttackRange: 50, followerAttackCd: 0.7, followerSpeedMul: 1.12,
    waveIntervalSec: 64,                 // 좀비 추가 웨이브 간격(클수록 천천히 몰려옴)
    siegeSpawnRampSec: 150,              // 집결 시작 후 이 시간에 걸쳐 스폰 수 계수가 1→최대치로 증가
    siegeSpawnMax: 3,                    // 집결 지속 시 스폰 수 계수 최대 배율
    reExploreKm: 25,                     // 마지막 정차 후 이만큼 이동해야 다시 탐험 가능
    yScale: 0.62,                        // 2.5D: y축 압축(측면 기울임 느낌)
    wallH: 30,                           // 건물 벽 높이(돌출)
  },

  // 파밍 성공 확률 보정 + 무기 드롭
  loot: { survivalBonus: 0.10, mentalPenalty: 0.10,
    weaponChance: 0.11,          // 컨테이너당 무기 발견 확률
    weaponDurMin: 0.20, weaponDurMax: 0.60 },   // 발견 무기 내구도(최대치 대비 랜덤)

  time: { dayLengthSec: 150 },           // 하루 길이(낮밤)
  save: { key: 'zombietrain.save.v2' },
};
