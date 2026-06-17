/* =========================================================================
 * data.js — 정적 콘텐츠 (특성 · 바이옴 시퀀스 · 건물/약탈 · 이름)
 * ========================================================================= */
const DATA = {
  /* ---- 특성(모든 캐릭터가 1개 보유, 플레이어 포함) ----
   * 탐험형(swift/brawler/tough)은 직접 나가는 플레이어 본인에게 큰 효과,
   * 동료가 보유 시엔 정차 중 기차 방어에 기여. 나머지는 기차 상시 패시브.
   */
  traits: {
    survival:  { key:'survival',  name:'생존전문가', icon:'🧭', kind:'explore',
      desc:'파밍 성공률 +10%p, 좀비 탐지 범위 감소' },
    swift:     { key:'swift',     name:'빠른 걸음',  icon:'👟', kind:'explore',
      desc:'탐험 이동 속도 +28% (본인 탐험 시)' },
    brawler:   { key:'brawler',   name:'강한 공격력', icon:'💪', kind:'explore',
      desc:'탐험 근접 공격 위력·범위 ↑ / 동료면 기차 방어' },
    tough:     { key:'tough',     name:'튼튼함',     icon:'🧱', kind:'explore',
      desc:'좀비 접촉 피해 감소 / 동료면 기차 방어' },
    locksmith: { key:'locksmith', name:'열쇠공',    icon:'🔑', kind:'explore',
      desc:'맨손으로 잠긴 문을 빠르고 조용히 땁니다(제작전문가 없이도)' },
    steady:    { key:'steady',    name:'안정형 체온', icon:'🌡️', kind:'explore',
      desc:'체온이 천천히 변합니다 — 추위·더위에 강함' },
    porter:    { key:'porter',    name:'짐꾼',      icon:'🧳', kind:'explore',
      desc:'기본 휴대 무게 한도 +8 — 더 많이 나릅니다' },
    mechanic:  { key:'mechanic',  name:'기계전문가', icon:'🛠️', kind:'explore',
      desc:'파밍지에서 부품으로 자동차에 알람 설치 — 작동 시 넓은 반경의 좀비를 유인' },
    farming:   { key:'farming',   name:'농사전문가', icon:'🌾', kind:'passive',
      desc:'농작물 수확·성장 ↑, 울타리 보호 ↑' },
    crafting:  { key:'crafting',  name:'제작전문가', icon:'🔧', kind:'passive',
      desc:'수리·증설·울타리 비용 ↓, 주행 중 내구도 회복, 자물쇠 따기 가능' },
    research:  { key:'research',  name:'연구원',     icon:'🔬', kind:'passive',
      desc:'감염 진행 절반, 연료 효율 ↑' },
    furniture: { key:'furniture', name:'가구전문가', icon:'🪑', kind:'passive',
      desc:'전원 멘탈 회복 ↑, 외부 농사·울타리 효율 ↑' },
  },
  traitOrder: ['survival','swift','brawler','tough','locksmith','steady','porter','mechanic','farming','crafting','research','furniture'],

  // 자원별 1회 획득량(어디서 나오든 공통) — 건물·가구 mul 로 가감
  lootAmounts: { food:[5,14], water:[4,12], fuel:[6,18], scrap:[2,6], parts:[1,4], meds:[1,2] },

  /* ---- 아이템(탐험 인벤토리) ----
   * kind:'res'  — 기차에 적재하면 res[resKey] += amount 로 환산되는 물자
   * kind:'bag'  — 장착 시 휴대 무게 +cap
   * kind:'cloth'— 장착 시 보온(warmth). rain=비 저항(0~1). 폭염에선 오히려 더움
   * weight: 1개당 무게
   */
  items: {
    cannedfood: { key:'cannedfood', name:'통조림',   icon:'🥫', kind:'res', res:'food',  amount:8,  weight:1.5 },
    waterbottle:{ key:'waterbottle',name:'물병',     icon:'🧴', kind:'res', res:'water', amount:7,  weight:1.5 },
    fuelcan:    { key:'fuelcan',    name:'연료통',   icon:'🛢️', kind:'res', res:'fuel',  amount:14, weight:4.0 },
    scrapmetal: { key:'scrapmetal', name:'고철',     icon:'🔩', kind:'res', res:'scrap', amount:4,  weight:2.0 },
    partpile:   { key:'partpile',   name:'부품',     icon:'⚙️', kind:'res', res:'parts', amount:3,  weight:1.0 },
    medkit:     { key:'medkit',     name:'구급킷',   icon:'💊', kind:'res', res:'meds',  amount:2,  weight:0.5 },
    // 가방(휴대량↑)
    smallbag:   { key:'smallbag',   name:'작은 가방', icon:'👜', kind:'bag', cap:6,  weight:1.0 },
    backpack:   { key:'backpack',   name:'배낭',     icon:'🎒', kind:'bag', cap:14, weight:2.0 },
    duffel:     { key:'duffel',     name:'더플백',   icon:'🧳', kind:'bag', cap:22, weight:3.0 },
    // 옷(보온)
    raincoat:   { key:'raincoat',   name:'우비',     icon:'🧥', kind:'cloth', warmth:1.2, rain:0.7, weight:1.0 },
    jacket:     { key:'jacket',     name:'재킷',     icon:'🧥', kind:'cloth', warmth:2.6, rain:0.2, weight:1.6 },
    coat:       { key:'coat',       name:'두꺼운 코트',icon:'🧥', kind:'cloth', warmth:4.6, rain:0.3, weight:2.6 },
  },
  // 자원 키 → 자원 아이템 키
  resItem: { food:'cannedfood', water:'waterbottle', fuel:'fuelcan', scrap:'scrapmetal', parts:'partpile', meds:'medkit' },
  bagKeys: ['smallbag','backpack','duffel'],
  clothKeys: ['raincoat','jacket','coat'],

  /* ---- 가구(건물 내부 약탈 컨테이너 — 좀보이드식) ----
   * 건물에 들어가면 내부에 배치된 가구를 하나씩 뒤집니다. 가구마다 나오는 자원 경향(bias)이
   * 다르고(냉장고=식량/물, 캐비넷=부품/약 등), 건물 자체의 weights와 합쳐져 최종 확률이 됩니다.
   * w/h: 렌더 크기 / success: 약탈 성공 확률 / mul: 획득량 배율 / searches: 시도 횟수
   */
  furniture: {
    fridge:  { key:'fridge',  name:'냉장고',  icon:'🧊', color:'#ccd6df', success:0.58, searches:1, mul:1.0, w:26, h:22,
      weights:{ food:6, water:5, meds:1 } },
    cabinet: { key:'cabinet', name:'캐비넷',  icon:'🗄️', color:'#9b8f78', success:0.50, searches:1, mul:0.95, w:24, h:20,
      weights:{ scrap:4, parts:4, meds:2, fuel:1 }, gear:'bag', gearChance:0.18 },
    desk:    { key:'desk',    name:'책상',    icon:'📒', color:'#7a5c43', success:0.50, searches:1, mul:0.9, w:30, h:18,
      weights:{ parts:4, scrap:3, meds:2, food:1 } },
    drawer:  { key:'drawer',  name:'서랍장',  icon:'🧰', color:'#8a6a4a', success:0.50, searches:1, mul:0.95, w:24, h:18,
      weights:{ food:3, water:2, meds:3, scrap:2 }, gear:'cloth', gearChance:0.22 },
    shelf:   { key:'shelf',   name:'진열장',  icon:'🛒', color:'#587d6b', success:0.55, searches:2, mul:1.0, w:34, h:16,
      weights:{ food:5, water:4, scrap:1, parts:1 } },
    counter: { key:'counter', name:'계산대',  icon:'💰', color:'#6b6450', success:0.45, searches:1, mul:0.9, w:30, h:16,
      weights:{ meds:2, parts:2, scrap:2, food:1 }, gear:'bag', gearChance:0.12 },
    wardrobe:{ key:'wardrobe',name:'옷장',    icon:'🚪', color:'#6a5240', success:0.55, searches:1, mul:0.9, w:26, h:20,
      weights:{ scrap:2, parts:1, water:1 }, gear:'cloth', gearChance:0.6 },
  },

  /* ---- 건물(약탈) ----
   * 건물에 들어가면 내부의 furniture(가구)를 하나씩 뒤집니다(좀보이드식).
   * weights: 건물의 기본 자원 경향 — 가구의 bias와 합쳐져 최종 확률이 됨(주유소=연료 등 색깔 유지)
   * mul    : 획득량 배율(기본 1) · success: 가구 약탈 성공률 보정용 기준
   * furniture: 내부에 배치할 가구 종류 목록(많을수록 약탈 횟수↑)
   */
  buildings: {
    convenience:{ key:'convenience', name:'편의점', icon:'🏪', color:'#2e7d6b', success:0.50,
      weights:{ food:5, water:4, scrap:1, parts:1, fuel:1, meds:1 },
      furniture:['shelf','fridge','counter','shelf'] },
    house:      { key:'house',       name:'가정집', icon:'🏠', color:'#7a5c43', success:0.45,
      weights:{ food:3, water:3, scrap:3, parts:3, fuel:2, meds:1 },     // 골고루
      furniture:['fridge','drawer','cabinet','wardrobe','desk'] },
    market:     { key:'market',      name:'마트',   icon:'🛒', color:'#3f7d3a', success:0.50, mul:1.2,
      weights:{ food:6, water:5, scrap:2, parts:1, fuel:1, meds:1 },
      furniture:['shelf','shelf','fridge','counter','shelf'] },
    gas:        { key:'gas',         name:'주유소', icon:'⛽', color:'#b5602f', success:0.35, mul:1.2,
      weights:{ fuel:7, scrap:2, parts:2, food:1 },
      furniture:['cabinet','counter','shelf','cabinet'] },
    hardware:   { key:'hardware',    name:'철물점', icon:'🔩', color:'#566270', success:0.45,
      weights:{ parts:5, scrap:6, fuel:1 },
      furniture:['cabinet','cabinet','drawer','desk'] },
    station:    { key:'station',     name:'역사',   icon:'🚉', color:'#5b6b8a', success:0.45,
      weights:{ scrap:4, parts:3, food:2, water:1, fuel:1 },
      furniture:['cabinet','desk','counter','shelf'] },
    pharmacy:   { key:'pharmacy',    name:'약국',   icon:'💊', color:'#8a4f6b', success:0.45,
      weights:{ meds:5, water:3, food:1 },
      furniture:['shelf','cabinet','drawer','counter'] },
    well:       { key:'well',        name:'급수탑', icon:'🚰', color:'#3a6b8a', success:0.60, mul:1.1,
      weights:{ water:8, food:1 },
      furniture:['shelf','drawer','cabinet'] },
  },
  // 자동차: 연료 또는 부품(잡템) 랜덤
  car: { key:'car', name:'버려진 차', icon:'🚗', success:0.40, searches:1, mul:0.6,
    weights:{ fuel:5, parts:4, scrap:2 } },

  /* ---- 좀비 타입 ----
   * speedMul: 이동속도 배율 / hp: [min,max] / dmgMul: 접촉·기차공격 위력 배율 / r: 크기 / color
   * 정차가 길어질수록(탐험 경과 시간) 강한 타입 출현 (explore._zombieWeights)
   */
  zombieTypes: {
    normal: { key:'normal', name:'좀비',     speedMul:1.0,  hp:[3,3], dmgMul:1.0, r:9,  color:'#5b7a4a' },  // 맨손(공격력1) 3대
    runner: { key:'runner', name:'질주 좀비', speedMul:2.15, hp:[1,1], dmgMul:1.0, r:8,  color:'#b6d05a' },
    tank:   { key:'tank',   name:'거구 좀비', speedMul:0.62, hp:[5,7], dmgMul:1.2, r:13, color:'#3f5a3a' },
    brute:  { key:'brute',  name:'흉포 좀비', speedMul:1.05, hp:[3,4], dmgMul:2.0, r:11, color:'#9a5236' },
  },

  /* ---- 무기(제작) ----
   * range: 공격 사거리(맨손은 config.explore.attackRange) / dmg: 공격력(맨손 1)
   * angle: 부채꼴 반각(도) — 클수록 한 번에 넓게 휩쓺(맨손은 config.explore.attackAngle)
   * dur: 기본 내구도(제작전문가 보유 시 +40%) — 공격이 적중할 때마다 1 감소, 0이면 파손
   */
  weapons: {
    club:    { key:'club',    name:'몽둥이', icon:'🏏', range:64, angle:60, dmg:2, dur:40, scrap:6,  parts:1 },
    spear:   { key:'spear',   name:'창',     icon:'🔱', range:104,angle:30, dmg:2, dur:30, scrap:8,  parts:2 },
    machete: { key:'machete', name:'마체테', icon:'🔪', range:72, angle:78, dmg:3, dur:50, scrap:10, parts:2 },
    axe:     { key:'axe',     name:'도끼',   icon:'🪓', range:66, angle:90, dmg:4, dur:26, scrap:12, parts:3 },
  },

  // 은신처(좀비 탐지 회피)
  hideTypes: [
    { name:'덤불', icon:'🌳' }, { name:'컨테이너', icon:'📦' }, { name:'폐버스', icon:'🚌' },
  ],

  /* ---- 바이옴(노선 구간) ----
   * canFarm : 외부 농사 가능(평야/도시 외곽)
   * stop    : 정차/탐험 가능(산·강은 경관만 지나감)
   */
  biomes: {
    city:     { key:'city',     name:'도시',   icon:'🏙️', danger:1.6, stop:true,  canFarm:false,
      buildings:['market','convenience','hardware','house','gas','house','pharmacy'], zombies:11, cars:3, survivor:0.5 },
    mountain: { key:'mountain', name:'산',     icon:'⛰️', danger:0.8, stop:true,  canFarm:false,
      buildings:['house','well'], zombies:4, cars:0, survivor:0.3 },
    river:    { key:'river',    name:'강',     icon:'🌊', danger:0.7, stop:true,  canFarm:true,
      buildings:['house','well','gas'], zombies:4, cars:1, survivor:0.3 },
    station:  { key:'station',  name:'기차역', icon:'🚉', danger:1.2, stop:true,  canFarm:false,
      buildings:['station','convenience','house','hardware','pharmacy'], zombies:7, cars:1, survivor:0.5 },
    plains:   { key:'plains',   name:'평야',   icon:'🌾', danger:0.9, stop:true,  canFarm:true,
      buildings:['house','gas','well'], zombies:5, cars:2, survivor:0.4 },
    wasteland:{ key:'wasteland',name:'불모지', icon:'🏜️', danger:1.3, stop:true,  canFarm:false,
      buildings:['house'], zombies:6, cars:1, survivor:0.15 },
  },
  // 배경이 지나가는 순서(순환). 정차 가능한 바이옴이 노선 노드가 됨
  biomeSequence: ['city','mountain','river','station','plains','city','mountain','plains','station','river'],
  segmentKm: 34,           // 한 바이옴 구간 길이

  names: ['지훈','서연','민준','하윤','도윤','수아','준서','지우','은우','채원',
          '현우','다은','시우','예린','건우','유진','준혁','소율','태양','보라',
          '강','레이','노바','한','셰인','미라','카이','루카','테오','이안'],
};
