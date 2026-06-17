/* ============================================================
 * data.js — 게임의 모든 정적 데이터
 * 작물 / 계절 / 아이템 / 가공 레시피 / 건물 / 도구 정의
 * 데이터 기반 설계: 여기에 항목을 추가하면 게임에 바로 반영됩니다.
 * ============================================================ */
(function () {
  'use strict';

  const SEASONS = ['spring', 'summer', 'fall', 'winter'];
  const SEASON_KO = { spring: '봄', summer: '여름', fall: '가을', winter: '겨울' };
  const DAYS_PER_SEASON = 28;

  /* ---------- 작물 ----------
   * grow    : 완전히 자라는 데 걸리는 일수(물을 준 날만 카운트)
   * regrow  : 다회 수확 작물의 재성장 일수 (null = 1회성 수확)
   * yieldMin/yieldMax : 한 번 수확 시 나오는 작물 개수 범위
   * fruit   : true면 통(keg) 가공 시 와인, false면 주스
   * mill    : 제분기로 가공 가능(밀 등)
   * sell    : 작물 1개 판매가 / seed : 씨앗 가격
   * tint    : 픽셀 작물 색상
   */
  const CROPS = {
    // ---- 봄 ----
    parsnip:     { name: '파스닙',   seasons: ['spring'], grow: 4,  regrow: null, yieldMin: 1, yieldMax: 1, fruit: false, sell: 35,  seed: 20,  tint: '#e8d36b' },
    potato:      { name: '감자',     seasons: ['spring'], grow: 6,  regrow: null, yieldMin: 1, yieldMax: 2, fruit: false, sell: 80,  seed: 50,  tint: '#c79a5b' },
    cauliflower: { name: '콜리플라워', seasons: ['spring'], grow: 12, regrow: null, yieldMin: 1, yieldMax: 1, fruit: false, sell: 175, seed: 80,  tint: '#f3f0e0' },
    kale:        { name: '케일',     seasons: ['spring'], grow: 6,  regrow: null, yieldMin: 1, yieldMax: 1, fruit: false, sell: 110, seed: 70,  tint: '#3f8f4a' },
    garlic:      { name: '마늘',     seasons: ['spring'], grow: 4,  regrow: null, yieldMin: 1, yieldMax: 1, fruit: false, sell: 60,  seed: 40,  tint: '#ece6da' },
    strawberry:  { name: '딸기',     seasons: ['spring'], grow: 8,  regrow: 4,    yieldMin: 1, yieldMax: 2, fruit: true,  sell: 120, seed: 100, tint: '#e7424b' },

    // ---- 여름 ----
    tomato:      { name: '토마토',   seasons: ['summer'], grow: 11, regrow: 4,    yieldMin: 1, yieldMax: 1, fruit: true,  sell: 60,  seed: 50,  tint: '#e34b3a' },
    pepper:      { name: '고추',     seasons: ['summer'], grow: 5,  regrow: 3,    yieldMin: 1, yieldMax: 1, fruit: true,  sell: 40,  seed: 40,  tint: '#d83434' },
    blueberry:   { name: '블루베리', seasons: ['summer'], grow: 13, regrow: 4,    yieldMin: 3, yieldMax: 3, fruit: true,  sell: 80,  seed: 80,  tint: '#3a6fd8' },
    melon:       { name: '멜론',     seasons: ['summer'], grow: 12, regrow: null, yieldMin: 1, yieldMax: 1, fruit: true,  sell: 250, seed: 80,  tint: '#7bbf5a' },
    hops:        { name: '홉',       seasons: ['summer'], grow: 11, regrow: 1,    yieldMin: 1, yieldMax: 1, fruit: true,  sell: 25,  seed: 60,  tint: '#9bcf5a' },
    wheat:       { name: '밀',       seasons: ['summer', 'fall'], grow: 4, regrow: null, yieldMin: 1, yieldMax: 1, fruit: false, mill: true, sell: 25, seed: 10, tint: '#d9c66b' },
    corn:        { name: '옥수수',   seasons: ['summer', 'fall'], grow: 14, regrow: 4, yieldMin: 1, yieldMax: 1, fruit: false, sell: 50, seed: 75, tint: '#f0d24a' },

    // ---- 가을 ----
    pumpkin:     { name: '호박',     seasons: ['fall'], grow: 13, regrow: null, yieldMin: 1, yieldMax: 1, fruit: false, sell: 320, seed: 100, tint: '#e08020' },
    cranberry:   { name: '크랜베리', seasons: ['fall'], grow: 7,  regrow: 5,    yieldMin: 2, yieldMax: 3, fruit: true,  sell: 75,  seed: 60,  tint: '#c41f3a' },
    grape:       { name: '포도',     seasons: ['fall'], grow: 10, regrow: 3,    yieldMin: 1, yieldMax: 1, fruit: true,  sell: 80,  seed: 60,  tint: '#7a3fa0' },
    eggplant:    { name: '가지',     seasons: ['fall'], grow: 5,  regrow: 5,    yieldMin: 1, yieldMax: 1, fruit: false, sell: 60,  seed: 20,  tint: '#5a2f7a' },
    yam:         { name: '얌',       seasons: ['fall'], grow: 10, regrow: null, yieldMin: 1, yieldMax: 1, fruit: false, sell: 160, seed: 60,  tint: '#c96a30' },
    // 겨울에는 노지 작물이 자라지 않습니다 (스타듀밸리 방식 — 광산/가공에 집중).
  };

  /* ---------- 일반 아이템(판매/재료) ----------
   * 작물/씨앗 외의 아이템. sell 가격과 표시명, 색상.
   */
  const ITEMS = {
    // 가공품
    wine:    { name: '와인',   sell: 0,   tint: '#7a1f3a', kind: 'good' },
    juice:   { name: '주스',   sell: 0,   tint: '#d88a2a', kind: 'good' },
    flour:   { name: '밀가루', sell: 50,  tint: '#efe9dc', kind: 'good' },
    butter:  { name: '버터',   sell: 240, tint: '#f0d878', kind: 'good' },
    cheese:  { name: '치즈',   sell: 230, tint: '#f2c64a', kind: 'good' },
    jam:     { name: '잼',     sell: 0,   tint: '#b52f5a', kind: 'good' },
    bread:   { name: '빵',     sell: 120, tint: '#d2a45a', kind: 'good' },
    // 축산물
    egg:     { name: '달걀',   sell: 50,  tint: '#f5efd8', kind: 'animal' },
    milk:    { name: '우유',   sell: 125, tint: '#f4f4ee', kind: 'animal' },
    // 채집/벌목
    wood:    { name: '나무',   sell: 5,   tint: '#8a5a32', kind: 'mat' },
    fiber:   { name: '섬유',   sell: 2,   tint: '#7faa55', kind: 'mat' },
    // 광물
    stone:   { name: '돌',     sell: 4,   tint: '#9aa0a8', kind: 'mineral' },
    copper:  { name: '구리 광석', sell: 12, tint: '#c87b40', kind: 'mineral' },
    iron:    { name: '철 광석',   sell: 22, tint: '#b6bcc4', kind: 'mineral' },
    gold:    { name: '금 광석',   sell: 55, tint: '#e8c84a', kind: 'mineral' },
    coal:    { name: '석탄',   sell: 10,  tint: '#3a3a40', kind: 'mineral' },
    quartz:  { name: '석영',   sell: 25,  tint: '#dfe6ef', kind: 'gem' },
    emerald: { name: '에메랄드', sell: 180, tint: '#3fc06a', kind: 'gem' },
    diamond: { name: '다이아몬드', sell: 420, tint: '#a8e8f0', kind: 'gem' },
    slimeball: { name: '슬라임 덩어리', sell: 8, tint: '#5fce6a', kind: 'mineral' },
  };

  /* ---------- 가공 기계 ----------
   * accepts(item) → output 객체 { id, qty, days } 또는 null
   * 동적 결과물(작물→와인 등)은 함수로 계산.
   */
  const MACHINES = {
    keg: {
      name: '발효통', price: 1000, mat: { wood: 30 }, tint: '#7a4a26',
      desc: '과일→와인, 채소→주스 (며칠 소요)',
      process(itemId) {
        const c = CROPS[itemId];
        if (!c) return null;
        if (c.fruit) return { id: 'wine', base: itemId, qty: 1, days: 6, sell: Math.round(c.sell * 3) };
        return { id: 'juice', base: itemId, qty: 1, days: 4, sell: Math.round(c.sell * 2.25) };
      },
    },
    mill: {
      name: '제분기', price: 800, mat: { wood: 20, stone: 20 }, tint: '#9a7a4a',
      desc: '밀→밀가루',
      process(itemId) {
        if (itemId === 'wheat') return { id: 'flour', qty: 1, days: 1, sell: ITEMS.flour.sell };
        return null;
      },
    },
    churn: {
      name: '버터 교반기', price: 1200, mat: { wood: 20 }, tint: '#caa86a',
      desc: '우유→버터 / 치즈',
      process(itemId) {
        if (itemId === 'milk') return { id: 'butter', qty: 1, days: 1, sell: ITEMS.butter.sell };
        return null;
      },
    },
    jar: {
      name: '보존 단지', price: 900, mat: { wood: 50, stone: 10 }, tint: '#6a8aa0',
      desc: '과일→잼, 채소→피클',
      process(itemId) {
        const c = CROPS[itemId];
        if (!c) return null;
        return { id: 'jam', base: itemId, qty: 1, days: 3, sell: Math.round(c.sell * 2 + 50) };
      },
    },
  };

  /* ---------- 스프링클러 ----------
   * tier: 0=상하좌우4칸, 1=주변8칸(3x3), 2=주변24칸(5x5)
   * 매일 아침 범위 내 갈린 밭에 자동 급수 (스타듀밸리 방식)
   */
  const SPRINKLERS = {
    sprinkler:  { name: '스프링클러',     price: 600,  mat: { copper: 3, iron: 2 },           tier: 0, tint: '#9aa6b0', desc: '아침마다 상하좌우 4칸 자동 급수' },
    qsprinkler: { name: '품질 스프링클러', price: 1500, mat: { iron: 3, gold: 1, quartz: 1 },  tier: 1, tint: '#d8c24a', desc: '아침마다 주변 8칸(3x3) 자동 급수' },
    isprinkler: { name: '이리듐 스프링클러', price: 3500, mat: { gold: 2, diamond: 1 },        tier: 2, tint: '#b06ad0', desc: '아침마다 주변 24칸(5x5) 자동 급수' },
  };
  function sprinklerPattern(tier) {
    if (tier === 0) return [[0, -1], [0, 1], [-1, 0], [1, 0]];
    const r = tier === 1 ? 1 : 2, out = [];
    for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) if (dx || dy) out.push([dx, dy]);
    return out;
  }

  /* ---------- 건물 ---------- */
  const BUILDINGS = {
    coop:   { name: '닭장',   price: 4000,  mat: { wood: 100, stone: 20 },  size: [3, 2], tint: '#b87a48', produces: 'egg',  desc: '닭이 매일 달걀을 낳습니다.' },
    barn:   { name: '외양간', price: 6000,  mat: { wood: 150, stone: 40 },  size: [4, 3], tint: '#a05838', produces: 'milk', desc: '소가 매일 우유를 만듭니다.' },
    stable: { name: '마구간', price: 10000, mat: { wood: 100, iron: 5 },    size: [3, 2], tint: '#8a6a4a', produces: null,   desc: '말을 타 이동 속도가 빨라집니다.' },
  };

  /* ---------- NPC(주민) ----------
   * portrait: 부드러운 2D 일러스트 초상화 파라미터 (나이/직업에 맞게)
   *   age: young | adult | old, style: short|ponytail|wavy|spiky|bald|bun
   */
  const NPCS = {
    pierre: {
      name: '피에르', role: '잡화점 주인',
      portrait: { skin: '#f1c79a', hair: '#5a3a1c', style: 'short', age: 'adult', gender: 'm', glasses: true, eye: '#4a3a2a', cloth: '#3a72c0', bg: '#dfeefb' },
      lines: ['어서 오게! 좋은 씨앗이 많이 들어왔다네.', '농사는 잘 되어가나?', '신선한 작물은 언제든 환영이야.'],
    },
    robin: {
      name: '로빈', role: '목수',
      portrait: { skin: '#f3cba0', hair: '#b5562a', style: 'ponytail', age: 'adult', gender: 'f', eye: '#4a6a3a', cloth: '#3a8a5a', bg: '#e8f3ea' },
      lines: ['건물 증축이 필요하면 말해요.', '오늘 날씨 정말 좋네요!', '나무 자재는 늘 모자라죠~'],
    },
    leah: {
      name: '레아', role: '예술가',
      portrait: { skin: '#f6d2ad', hair: '#caa24a', style: 'wavy', age: 'young', gender: 'f', eye: '#6a8a4a', cloth: '#7a9a5a', blush: true, bg: '#f1f3e0' },
      lines: ['숲에서 영감을 얻고 있어요.', '직접 기른 작물은 맛이 다르죠!', '조각 작품 보러 올래요?'],
    },
    maru: {
      name: '마루', role: '마을 청년',
      portrait: { skin: '#e6b385', hair: '#23232a', style: 'spiky', age: 'young', gender: 'm', eye: '#3a2a2a', cloth: '#4a6ac0', bg: '#e3e8fb' },
      lines: ['안녕! 농장 일은 할 만해?', '광산에서 좋은 광물 좀 캤어?', '언젠가 별을 연구하고 싶어.'],
    },
    mayor: {
      name: '이장 어르신', role: '촌장',
      portrait: { skin: '#e9c6a0', hair: '#dadada', style: 'bald', age: 'old', gender: 'm', beard: true, mustache: true, glasses: true, brows: '#c8c8c8', eye: '#4a4a4a', cloth: '#6a5a3a', bg: '#efe9dc' },
      lines: ['허허, 우리 마을에 온 걸 환영하네.', '젊은 농부가 오니 마을에 활기가 도는구만.', '계절마다 축제가 열린다네, 기대하시게.'],
    },
  };

  /* ---------- 도구 ---------- */
  const TOOLS = {
    hoe:    { name: '괭이',     desc: '흙을 갈아 밭을 만듭니다 (Space).' },
    can:    { name: '물뿌리개', desc: '갈린 밭/작물에 물을 줍니다.' },
    hammer: { name: '망치',     desc: '돌을 캡니다. 업그레이드하면 큰 돌도 부숩니다.' },
    scythe: { name: '낫',       desc: '잡초를 베고, 다 자란 작물을 수확합니다.' },
    axe:    { name: '도끼',     desc: '나무/그루터기를 베어 나무를 얻습니다.' },
    sword:  { name: '검',       desc: '동굴에서 몬스터를 공격합니다.' },
  };

  // 망치(곡괭이) 업그레이드 단계
  const HAMMER_UPGRADES = [
    { name: '나무 망치', power: 1, breakLarge: false },                 // 0
    { name: '구리 망치', power: 2, breakLarge: true,  price: 2000, mat: { copper: 5 } }, // 1 — 큰 돌 가능
    { name: '강철 망치', power: 3, breakLarge: true,  price: 5000, mat: { iron: 5 } },   // 2 — 더 빠름
  ];
  // 괭이 업그레이드 — maxStage: 차징 시 갈 수 있는 최대 범위 단계(0:1칸,1:3칸,2:3x3)
  const HOE_UPGRADES = [
    { name: '기본 괭이', maxStage: 0 },
    { name: '구리 괭이', maxStage: 1, price: 1500, mat: { copper: 5 } },
    { name: '강철 괭이', maxStage: 2, price: 4000, mat: { iron: 5 } },
  ];
  // 물뿌리개 업그레이드 — cap: 물 용량, maxStage: 차징 범위
  const CAN_UPGRADES = [
    { name: '기본 물뿌리개', maxStage: 0, cap: 20 },
    { name: '구리 물뿌리개', maxStage: 1, cap: 40, price: 1500, mat: { copper: 5 } },
    { name: '강철 물뿌리개', maxStage: 2, cap: 70, price: 4000, mat: { iron: 5 } },
  ];

  // 전역 노출
  window.DATA = {
    SEASONS, SEASON_KO, DAYS_PER_SEASON,
    CROPS, ITEMS, MACHINES, BUILDINGS, SPRINKLERS, NPCS, TOOLS, HAMMER_UPGRADES, HOE_UPGRADES, CAN_UPGRADES,
    sprinklerPattern,
    // 아이템의 표시명/판매가를 통합 조회하는 헬퍼
    displayName(id) {
      if (CROPS[id]) return CROPS[id].name;
      if (ITEMS[id]) return ITEMS[id].name;
      if (id.endsWith('_seed')) {
        const c = CROPS[id.replace('_seed', '')];
        return c ? c.name + ' 씨앗' : id;
      }
      if (MACHINES[id]) return MACHINES[id].name;
      if (SPRINKLERS[id]) return SPRINKLERS[id].name;
      if (BUILDINGS[id]) return BUILDINGS[id].name;
      if (TOOLS[id]) return TOOLS[id].name;
      return id;
    },
    tintOf(id) {
      if (CROPS[id]) return CROPS[id].tint;
      if (ITEMS[id]) return ITEMS[id].tint;
      if (SPRINKLERS[id]) return SPRINKLERS[id].tint;
      if (id.endsWith('_seed')) {
        const c = CROPS[id.replace('_seed', '')];
        return c ? c.tint : '#bbb';
      }
      return '#bbb';
    },
    // 판매가 (가공품은 인스턴스에 sell이 저장됨, 여기선 기본값)
    sellOf(id) {
      if (CROPS[id]) return CROPS[id].sell;
      if (ITEMS[id]) return ITEMS[id].sell;
      return 0;
    },
  };
})();
