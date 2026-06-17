/* =========================================================================
   FishingLife - Game Data
   All static content: fish, locations, gear, bait recipes, quests.
   Loaded as a plain script -> everything hangs off window.DATA
   ========================================================================= */
(function () {
  "use strict";

  // --- Seasons & Weather enums -------------------------------------------
  const SEASONS = ["spring", "summer", "fall", "winter"];
  const WEATHERS = ["sunny", "cloudy", "rain", "snow"];

  const SEASON_LABEL = {
    spring: "봄", summer: "여름", fall: "가을", winter: "겨울",
  };
  const WEATHER_LABEL = {
    sunny: "맑음 ☀️", cloudy: "흐림 ☁️", rain: "비 🌧️", snow: "눈 ❄️",
  };
  const TIME_LABEL = { morning: "아침", day: "낮", evening: "저녁", night: "밤" };

  // --- Rarity ------------------------------------------------------------
  const RARITY = {
    common:    { label: "흔함",   color: "#9fb6c4", weight: 100, mult: 1.0 },
    uncommon:  { label: "보통",   color: "#6fcf97", weight: 55,  mult: 1.6 },
    rare:      { label: "희귀",   color: "#56a3ff", weight: 22,  mult: 3.0 },
    epic:      { label: "에픽",   color: "#b06bff", weight: 8,   mult: 6.5 },
    legendary: { label: "전설",   color: "#ffb443", weight: 2,   mult: 16  },
  };

  // --- Locations ---------------------------------------------------------
  // unlockCost: 0 = available from start. needsBoat: minimum boat tier.
  const LOCATIONS = [
    { id: "town",   name: "도심지",        emoji: "🏙️", desc: "상점과 부동산이 있는 번화가. 물고기를 팔고 장비를 사자.", unlockCost: 0, needsBoat: 0, town: true },
    { id: "pond",   name: "잔잔한 연못",   emoji: "🪷", desc: "초보 낚시꾼의 고향. 잔잔하고 평화롭다.", unlockCost: 0, needsBoat: 0 },
    { id: "river",  name: "흐르는 강",     emoji: "🏞️", desc: "물살이 빠른 강. 활기찬 물고기들이 산다.", unlockCost: 0, needsBoat: 0 },
    { id: "valley", name: "산지 계곡",     emoji: "⛰️", desc: "차갑고 맑은 계곡물. 송어가 유명하다.", unlockCost: 300, needsBoat: 0 },
    { id: "lake",   name: "넓은 호수",     emoji: "🛶", desc: "깊은 호수. 배가 있어야 한가운데로 갈 수 있다.", unlockCost: 1200, needsBoat: 1 },
    { id: "sea",    name: "푸른 바다",     emoji: "🌊", desc: "끝없는 바다. 거대한 물고기가 숨어있다.", unlockCost: 4000, needsBoat: 2 },
    { id: "cave",   name: "신비한 동굴호수", emoji: "🕳️", desc: "빛이 닿지 않는 동굴. 발광 생물의 보금자리.", unlockCost: 9000, needsBoat: 2 },
    { id: "moon",   name: "달빛 해변",     emoji: "🌙", desc: "밤에만 열리는 신비로운 해변. 전설이 잠든 곳.", unlockCost: 20000, needsBoat: 3 },
  ];

  // --- Fish database -----------------------------------------------------
  // seasons / weathers / times: empty array = any.
  // bait: id of a bait that boosts this fish's bite chance (optional).
  const FISH = [
    // ---- Pond ----
    { id: "minnow",    name: "피라미",     emoji: "🐟", rarity: "common",   value: 6,   loc: ["pond","river"], seasons: [], weathers: [], times: [], size: [4,12] },
    { id: "carp",      name: "잉어",       emoji: "🐠", rarity: "common",   value: 14,  loc: ["pond","lake"],  seasons: [], weathers: [], times: [], size: [25,70] },
    { id: "crucian",   name: "붕어",       emoji: "🐟", rarity: "common",   value: 11,  loc: ["pond"],         seasons: ["spring","summer","fall"], weathers: [], times: [], size: [10,30] },
    { id: "frog",      name: "황소개구리", emoji: "🐸", rarity: "uncommon", value: 22,  loc: ["pond"],         seasons: ["summer"], weathers: ["rain"], times: ["night"], size: [8,20], bait: "worm" },
    { id: "goldfish",  name: "금붕어",     emoji: "🐡", rarity: "rare",     value: 65,  loc: ["pond"],         seasons: ["spring"], weathers: ["sunny"], times: [], size: [5,18] },
    { id: "loach",     name: "미꾸라지",   emoji: "🐟", rarity: "common",   value: 9,   loc: ["pond","river"], seasons: [], weathers: ["rain"], times: [], size: [10,20] },

    // ---- River ----
    { id: "trout",     name: "무지개송어", emoji: "🐟", rarity: "uncommon", value: 30,  loc: ["river","valley"], seasons: ["spring","fall"], weathers: [], times: [], size: [20,55] },
    { id: "smallmouth",name: "배스",       emoji: "🐠", rarity: "uncommon", value: 28,  loc: ["river","lake"],  seasons: ["summer"], weathers: [], times: ["day","evening"], size: [25,60] },
    { id: "catfish",   name: "메기",       emoji: "🐡", rarity: "rare",     value: 80,  loc: ["river","lake"],  seasons: [], weathers: ["rain"], times: ["night"], size: [40,120], bait: "stinkbait" },
    { id: "eel",       name: "장어",       emoji: "🐍", rarity: "rare",     value: 95,  loc: ["river","sea"],   seasons: ["summer"], weathers: [], times: ["night"], size: [40,90], bait: "shrimp" },
    { id: "sweetfish", name: "은어",       emoji: "🐟", rarity: "uncommon", value: 34,  loc: ["river"],         seasons: ["summer"], weathers: ["sunny"], times: [], size: [15,30] },

    // ---- Valley ----
    { id: "chargr",    name: "곤들매기",   emoji: "🐟", rarity: "rare",     value: 110, loc: ["valley"],        seasons: ["winter","spring"], weathers: [], times: [], size: [20,45] },
    { id: "masu",      name: "산천어",     emoji: "🐟", rarity: "uncommon", value: 40,  loc: ["valley"],        seasons: ["spring"], weathers: [], times: ["morning"], size: [15,35] },
    { id: "gudgeon",   name: "버들치",     emoji: "🐟", rarity: "common",   value: 12,  loc: ["valley"],        seasons: [], weathers: [], times: [], size: [6,14] },
    { id: "graytrout", name: "열목어",     emoji: "🐟", rarity: "epic",     value: 260, loc: ["valley"],        seasons: ["winter"], weathers: ["snow"], times: [], size: [30,70], bait: "fly" },
    { id: "crystalfish",name:"수정어",     emoji: "💎", rarity: "legendary",value: 1400,loc: ["valley"],        seasons: ["winter"], weathers: ["snow"], times: ["morning"], size: [20,40], bait: "fly" },

    // ---- Lake ----
    { id: "pike",      name: "강꼬치고기", emoji: "🐠", rarity: "rare",     value: 120, loc: ["lake"],          seasons: ["fall"], weathers: [], times: [], size: [40,100] },
    { id: "lakefish",  name: "송어왕",     emoji: "🐟", rarity: "epic",     value: 300, loc: ["lake"],          seasons: ["fall","winter"], weathers: ["cloudy"], times: ["evening"], size: [50,90], bait: "spinner" },
    { id: "turtle",    name: "자라",       emoji: "🐢", rarity: "uncommon", value: 45,  loc: ["lake","pond"],   seasons: ["summer"], weathers: ["sunny"], times: ["day"], size: [20,40] },
    { id: "mandarin",  name: "쏘가리",     emoji: "🐠", rarity: "rare",     value: 140, loc: ["lake","river"],  seasons: ["summer"], weathers: [], times: ["night"], size: [25,55], bait: "shrimp" },

    // ---- Sea ----
    { id: "mackerel",  name: "고등어",     emoji: "🐟", rarity: "common",   value: 20,  loc: ["sea"],           seasons: [], weathers: [], times: [], size: [20,40] },
    { id: "snapper",   name: "참돔",       emoji: "🐠", rarity: "uncommon", value: 60,  loc: ["sea"],           seasons: ["spring"], weathers: [], times: ["morning"], size: [30,70] },
    { id: "tuna",      name: "참치",       emoji: "🐟", rarity: "epic",     value: 420, loc: ["sea"],           seasons: ["summer"], weathers: ["sunny"], times: ["day"], size: [100,250], bait: "spinner" },
    { id: "squid",     name: "오징어",     emoji: "🦑", rarity: "uncommon", value: 50,  loc: ["sea"],           seasons: ["fall"], weathers: [], times: ["night"], size: [20,50] },
    { id: "octopus",   name: "문어",       emoji: "🐙", rarity: "rare",     value: 130, loc: ["sea"],           seasons: [], weathers: [], times: ["night"], size: [30,80] },
    { id: "shark",     name: "상어",       emoji: "🦈", rarity: "epic",     value: 600, loc: ["sea"],           seasons: ["summer"], weathers: ["cloudy"], times: [], size: [150,400], minRod: 3 },
    { id: "marlin",    name: "청새치",     emoji: "🗡️", rarity: "legendary",value: 2200,loc: ["sea"],           seasons: ["summer"], weathers: ["sunny"], times: ["day"], size: [200,450], minRod: 3, bait: "spinner" },
    { id: "jellyfish", name: "해파리",     emoji: "🎐", rarity: "common",   value: 8,   loc: ["sea"],           seasons: ["summer"], weathers: [], times: [], size: [10,40] },

    // ---- Cave ----
    { id: "blindfish", name: "동굴장님고기",emoji: "🐟", rarity: "rare",     value: 160, loc: ["cave"],          seasons: [], weathers: [], times: [], size: [8,20] },
    { id: "glowfish",  name: "발광어",     emoji: "✨", rarity: "epic",     value: 380, loc: ["cave"],          seasons: [], weathers: [], times: ["night"], size: [10,30], bait: "glowbait" },
    { id: "axolotl",   name: "우파루파",   emoji: "🦎", rarity: "epic",     value: 450, loc: ["cave"],          seasons: [], weathers: [], times: [], size: [10,25], bait: "glowbait" },
    { id: "cavedragon",name: "동굴용어",   emoji: "🐉", rarity: "legendary",value: 3000,loc: ["cave"],          seasons: ["winter"], weathers: [], times: ["night"], size: [60,140], minRod: 4, bait: "glowbait" },

    // ---- Moon Beach ----
    { id: "moonjelly", name: "달빛해파리", emoji: "🌕", rarity: "rare",     value: 200, loc: ["moon"],          seasons: [], weathers: [], times: ["night"], size: [20,50] },
    { id: "starfish",  name: "별불가사리", emoji: "⭐", rarity: "uncommon", value: 70,  loc: ["moon"],          seasons: [], weathers: [], times: ["night"], size: [10,30] },
    { id: "lunarkoi",  name: "월광비단잉어",emoji: "🎏", rarity: "epic",     value: 700, loc: ["moon"],          seasons: ["fall"], weathers: ["cloudy"], times: ["night"], size: [40,80], bait: "moonbait" },
    { id: "leviathan", name: "리바이어던", emoji: "🐲", rarity: "legendary",value: 8000,loc: ["moon"],          seasons: [], weathers: ["rain"], times: ["night"], size: [300,800], minRod: 5, bait: "moonbait" },
    { id: "kraken",    name: "크라켄",     emoji: "🦑", rarity: "legendary",value: 6500,loc: ["moon"],          seasons: ["winter"], weathers: [], times: ["night"], size: [200,600], minRod: 5, bait: "moonbait" },

    // ---- Junk (caught everywhere, low/zero value, adds realism) ----
    { id: "boot",      name: "낡은 장화",  emoji: "🥾", rarity: "common",   value: 2,   loc: ["pond","river","lake","sea","valley","cave","moon"], seasons: [], weathers: [], times: [], size: [25,30], junk: true },
    { id: "can",       name: "빈 깡통",    emoji: "🥫", rarity: "common",   value: 1,   loc: ["pond","river","lake","sea","valley","cave","moon"], seasons: [], weathers: [], times: [], size: [10,12], junk: true },
    { id: "seaweed",   name: "해초",       emoji: "🌿", rarity: "common",   value: 3,   loc: ["pond","river","lake","sea","valley","cave","moon"], seasons: [], weathers: [], times: [], size: [20,60], junk: true },
    { id: "treasure",  name: "보물상자",   emoji: "💰", rarity: "epic",     value: 500, loc: ["sea","lake","moon"], seasons: [], weathers: [], times: [], size: [30,30], junk: true },
  ];

  // --- Rods --------------------------------------------------------------
  // tier 1 owned at start. power = larger catch zone in minigame.
  const RODS = [
    { id: "rod1", tier: 1, name: "낡은 대나무 낚싯대", emoji: "🎣", cost: 0,     power: 1.0,  desc: "할아버지가 물려준 첫 낚싯대." },
    { id: "rod2", tier: 2, name: "유리섬유 낚싯대",   emoji: "🎣", cost: 250,   power: 1.25, desc: "가볍고 튼튼하다. 입질을 놓치기 어렵다." },
    { id: "rod3", tier: 3, name: "카본 낚싯대",       emoji: "🎣", cost: 1500,  power: 1.55, desc: "대형 어종도 거뜬히 끌어올린다." },
    { id: "rod4", tier: 4, name: "장인의 낚싯대",     emoji: "🎏", cost: 6000,  power: 1.9,  desc: "명인이 손수 만든 예술품." },
    { id: "rod5", tier: 5, name: "전설의 낚싯대",     emoji: "🌟", cost: 25000, power: 2.4,  desc: "전설의 물고기를 낚기 위한 궁극의 장비." },
  ];

  // --- Boats -------------------------------------------------------------
  const BOATS = [
    { id: "boat0", tier: 0, name: "도보",         emoji: "🚶", cost: 0,     desc: "물가에서만 낚시할 수 있다." },
    { id: "boat1", tier: 1, name: "나무 보트",     emoji: "🛶", cost: 800,  desc: "호수로 나갈 수 있다." },
    { id: "boat2", tier: 2, name: "모터보트",     emoji: "🚤", cost: 3500, desc: "바다와 동굴호수까지 항해 가능." },
    { id: "boat3", tier: 3, name: "원양 어선",     emoji: "⛴️", cost: 15000,desc: "어떤 깊은 바다도 두렵지 않다." },
  ];

  // --- Bait & crafting ---------------------------------------------------
  // Base materials are gathered or bought; baits are crafted.
  const MATERIALS = {
    worm:    { id: "worm",    name: "지렁이",   emoji: "🪱", buy: 5 },
    bread:   { id: "bread",   name: "빵조각",   emoji: "🍞", buy: 4 },
    shrimp:  { id: "shrimp",  name: "새우",     emoji: "🦐", buy: 15 },
    fishmeal:{ id: "fishmeal",name: "생선살",   emoji: "🍣", buy: 0  }, // from fish
    herb:    { id: "herb",    name: "약초",     emoji: "🌿", buy: 12 },
    glowmoss:{ id: "glowmoss",name: "발광이끼", emoji: "🟢", buy: 0  }, // cave only
    pearl:   { id: "pearl",   name: "진주",     emoji: "⚪", buy: 0  }, // rare drop
  };

  // Baits boost bite chance & influence which fish bite.
  const BAITS = {
    worm:     { id: "worm",     name: "지렁이 미끼", emoji: "🪱", power: 1.0, desc: "가장 기본적인 미끼." },
    mud:      { id: "mud",      name: "막미끼",     emoji: "🍂", power: 0.6, desc: "흙과 잡초를 뭉친 조잡한 미끼. 공짜지만 입질이 느리다.", recipe: {}, batch: 3 },
    stinkbait:{ id: "stinkbait",name: "떡밥",       emoji: "🟤", power: 1.3, desc: "메기를 유인한다.", recipe: { bread: 2, fishmeal: 1 }, batch: 5 },
    shrimp:   { id: "shrimp",   name: "새우 미끼",   emoji: "🦐", power: 1.4, desc: "장어·쏘가리가 좋아한다.", recipe: { shrimp: 2 }, batch: 4 },
    fly:      { id: "fly",      name: "제물낚시",   emoji: "🪰", power: 1.5, desc: "계곡 어종을 노린다.", recipe: { herb: 1, worm: 2 }, batch: 4 },
    spinner:  { id: "spinner",  name: "스피너 루어", emoji: "🥄", power: 1.7, desc: "대형 포식어를 끌어들인다.", recipe: { fishmeal: 3, herb: 1 }, batch: 3 },
    glowbait: { id: "glowbait", name: "발광 미끼",   emoji: "🟢", power: 1.9, desc: "어둠 속 생물을 유혹한다.", recipe: { glowmoss: 2, shrimp: 1 }, batch: 3 },
    moonbait: { id: "moonbait", name: "월광 미끼",   emoji: "🌙", power: 2.3, desc: "전설을 부른다.", recipe: { pearl: 1, glowmoss: 2, herb: 2 }, batch: 2 },
  };

  // --- Fish traps (통발) -------------------------------------------------
  const TRAPS = [
    { id: "trap1", name: "대나무 통발", emoji: "🪤", cost: 150,  capacity: 3, desc: "물속에 두면 시간이 지나며 물고기가 들어온다." },
    { id: "trap2", name: "철망 통발",   emoji: "🪤", cost: 700,  capacity: 6, desc: "더 많이, 더 좋은 물고기를 담는다." },
  ];

  // --- House & Aquarium --------------------------------------------------
  const HOUSE = { id: "house", name: "호숫가 오두막", emoji: "🏡", cost: 5000, desc: "나만의 보금자리. 아쿠아리움을 지을 수 있다." };
  const AQUARIUMS = [
    { id: "aq1", name: "작은 어항",   emoji: "🐠", cost: 400,  slots: 4,  desc: "잡은 물고기를 전시한다." },
    { id: "aq2", name: "유리 수조",   emoji: "🐟", cost: 2000, slots: 10, desc: "더 많은 물고기를 키운다." },
    { id: "aq3", name: "대형 아쿠아리움", emoji: "🌊", cost: 12000, slots: 24, desc: "꿈에 그리던 나만의 아쿠아리움." },
  ];

  // --- Quests (의뢰) -----------------------------------------------------
  // Generated from templates at runtime, but a few hand-made story quests too.
  const QUEST_GIVERS = [
    { name: "마을 식당 주인", emoji: "🧑‍🍳" },
    { name: "수족관 관장",   emoji: "🧑‍🔬" },
    { name: "낚시 동호회장", emoji: "🎽" },
    { name: "신비한 상인",   emoji: "🧙" },
  ];

  window.DATA = {
    SEASONS, WEATHERS, SEASON_LABEL, WEATHER_LABEL, TIME_LABEL, RARITY,
    LOCATIONS, FISH, RODS, BOATS, MATERIALS, BAITS, TRAPS, HOUSE, AQUARIUMS,
    QUEST_GIVERS,
    fishById: id => FISH.find(f => f.id === id),
    locById:  id => LOCATIONS.find(l => l.id === id),
    rodByTier:tier => RODS.find(r => r.tier === tier),
    boatByTier:tier => BOATS.find(b => b.tier === tier),
  };
})();
