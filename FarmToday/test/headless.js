/* 헤드리스 검증: Canvas/DOM을 스텁으로 대체해 게임 코드를 실제로 구동하며
 * 런타임 오류를 잡는다. (Node에서 실행) */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

// ---- 스텁 ----
// 어떤 그리기 메서드(arc/ellipse/fill/stroke 등)든 받아주는 Proxy 스텁
const ctxData = {
  measureText: (s) => ({ width: (s ? String(s).length : 0) * 4 }),
  createLinearGradient: () => ({ addColorStop() {} }),
  createRadialGradient: () => ({ addColorStop() {} }),
};
const ctx = new Proxy(ctxData, {
  get(t, p) { if (p in t) return t[p]; return () => {}; },
  set(t, p, v) { t[p] = v; return true; },
});
const canvas = {
  width: 0, height: 0, style: {},
  getContext: () => ctx,
  addEventListener() {},
  getBoundingClientRect: () => ({ left: 0, top: 0, width: 480, height: 270 }),
};
const store = {};
global.window = global;
global.document = { getElementById: () => canvas, addEventListener() {} };
global.addEventListener = () => {};
global.requestAnimationFrame = () => {}; // 자동 루프 방지(수동 구동)
global.performance = { now: () => Date.now() };
global.localStorage = {
  getItem: (k) => (k in store ? store[k] : null),
  setItem: (k, v) => { store[k] = String(v); },
  removeItem: (k) => { delete store[k]; },
};
global.innerWidth = 1280; global.innerHeight = 800;
global.console = console;

// ---- 스크립트 로드 ----
const files = ['data.js', 'sprites.js', 'input.js', 'world.js', 'player.js', 'cave.js', 'ui.js', 'game.js'];
for (const f of files) {
  const code = fs.readFileSync(path.join(__dirname, '..', 'js', f), 'utf8');
  vm.runInThisContext(code, { filename: f });
}

let failed = 0;
function step(name, fn) {
  // 각 테스트 시작 시 입력 상태 초기화(마우스 누름이 다음 테스트로 새는 것 방지)
  Input.keys = {}; Input.mouse.down = false; Input.mouse.clicked = false;
  try { fn(); console.log('  OK  ' + name); }
  catch (e) { failed++; console.log('  ERR ' + name + ' :: ' + e.message + '\n' + (e.stack || '').split('\n').slice(1, 3).join('\n')); }
}

const G = global.Game;

step('init (타이틀)', () => { G.init(); G.render(); });
step('새 게임 시작', () => { G.startNew(); });

// 농사 한 사이클
step('밭갈기/물주기/심기/수확', () => {
  const w = G.world, p = G.player;
  // 빈 풀밭 칸 찾기
  let tx = 15, ty = 15;
  for (let y = 12; y < 25 && !found(); y++) for (let x = 12; x < 25; x++) {
    if (w.tileAt(x, y) === 'grass' && !w.objAt(x, y)) { tx = x; ty = y; }
  }
  function found() { return false; }
  if (!w.till(tx, ty)) throw new Error('till 실패 @' + tx + ',' + ty);
  w.waterTile(tx, ty);
  if (w.tileAt(tx, ty) !== 'soil') throw new Error('soil 안됨');
  const inS = w.plant(tx, ty, 'parsnip', 'spring');
  if (!inS) throw new Error('plant 제철 실패');
  // 4일 물주며 성장
  for (let d = 0; d < 5; d++) { w.waterTile(tx, ty); w.newDay('spring', false); }
  const o = w.objAt(tx, ty);
  if (!o || !o.ready) throw new Error('성장 안됨: ' + JSON.stringify(o));
  const h = w.harvest(tx, ty);
  if (!h || !h.items.length) throw new Error('수확 실패');
  G._tx = tx; G._ty = ty;
});

step('모든 도구 useTool (농장)', () => {
  const p = G.player; const [fx, fy] = [G._tx, G._ty + 1];
  ['hoe', 'can', 'hammer', 'scythe', 'axe', 'sword'].forEach((t) => G.useTool(t, fx, fy));
});

step('상점 구매/판매', () => {
  G.buySeed('potato', 3);
  const st = G.player.inventory.find((s) => s.id === 'wood');
  if (st) G.sellStack(st, 1);
});

step('건설물 구매 + 설치(기계/건물)', () => {
  const p = G.player;
  p.money = 999999; p.addItem('wood', 500); p.addItem('stone', 500); p.addItem('iron', 50); p.addItem('copper', 50);
  G.buyBuildable('keg', 'machine');
  G.buyBuildable('coop', 'building');
  // 설치
  const w = G.world;
  let placed = false;
  for (let y = 13; y < 28 && !placed; y++) for (let x = 13; x < 28; x++) {
    if (w.tileAt(x, y) === 'grass' && !w.objAt(x, y)) { if (w.placeMachine(x, y, 'keg')) { G._kx = x; G._ky = y; placed = true; break; } }
  }
  if (!placed) throw new Error('기계 설치 실패');
});

step('가공: 기계에 재료 투입 + 진행 + 수거', () => {
  const w = G.world, p = G.player;
  const o = w.objAt(G._kx, G._ky);
  p.addItem('grape', 2);
  const grapeStack = p.inventory.find((s) => s.id === 'grape');
  G.loadMachine(o, grapeStack);
  if (!o.job) throw new Error('job 안생김');
  for (let d = 0; d < 7; d++) w.newDay('fall', false);
  if (!o.job.ready) throw new Error('가공 미완료');
  G.collectMachine(o);
  if (!p.inventory.find((s) => s.id === 'wine')) throw new Error('와인 미수령');
});

step('망치 업그레이드', () => { G.upgradeTool('hammer'); if (G.player.hammerLevel !== 1) throw new Error('업글 실패'); });

step('수면 + 계절 전환(30일)', () => {
  for (let i = 0; i < 30; i++) G.sleep(false);
  G.dayTransition = null;
});

step('동굴: 입장/채굴/전투/하강/탈출', () => {
  G.enterCave();
  if (G.scene !== 'cave') throw new Error('입장 실패');
  // 바위 채굴
  const c = G.cave;
  let rk = null;
  for (const [k, o] of c.objects) if (o.type === 'rock') { rk = k.split(',').map(Number); break; }
  if (rk) for (let i = 0; i < 10; i++) c.mineRock(rk[0], rk[1], DATA.HAMMER_UPGRADES[G.player.hammerLevel]);
  // 전투
  if (c.monsters[0]) { G.player.x = c.monsters[0].x; G.player.y = c.monsters[0].y - 8; }
  for (let i = 0; i < 20; i++) c.attack(G.player.x, G.player.y, 'down', 5);
  c.update(0.1, G.player);
  G.descend();
  if (c.depth !== 2) throw new Error('하강 실패');
  G.exitCave();
  if (G.scene !== 'farm') throw new Error('탈출 실패');
  G.faint();
});

step('맵 이동: 농장→마을→농장 (길 워프)', () => {
  G.scene = 'farm'; G.world = G.maps.farm; UI.menu = null; G.dayTransition = null; G.pending = null;
  const p = G.player;
  p.x = 40 * 16; p.y = 16 * 16; p.actionT = 0; p.dir = 'right'; p.hasStable = false;
  Input.keys = {}; Input.keys['d'] = true;
  let guard = 0;
  while (G.scene === 'farm' && guard++ < 500) G.update(0.03);
  Input.keys = {};
  if (G.scene !== 'town') throw new Error('농장→마을 워프 실패 (scene=' + G.scene + ')');
  if (G.world !== G.maps.town) throw new Error('world 갱신 안됨');
  Input.keys = {}; Input.keys['a'] = true; guard = 0;
  while (G.scene === 'town' && guard++ < 500) G.update(0.03);
  Input.keys = {};
  if (G.scene !== 'farm') throw new Error('마을→농장 워프 실패 (scene=' + G.scene + ')');
});

step('마우스 조준 + 클릭 차징 밭갈기 (이동잠금/체력)', () => {
  G.scene = 'farm'; G.world = G.maps.farm;
  const w = G.world, p = G.player;
  UI.menu = null; G.dayTransition = null; G.pending = null; p.charging = false; p.chargeT = 0; p.hoeLevel = 0;
  let tx = -1, ty = -1;
  for (let y = 14; y < 26 && ty < 0; y++) for (let x = 14; x < 26; x++) {
    if (w.tileAt(x, y) === 'grass' && !w.objAt(x, y) && w.tileAt(x, y + 1) === 'grass' && !w.objAt(x, y + 1)) { tx = x; ty = y; break; }
  }
  if (tx < 0) throw new Error('빈 칸 못찾음');
  p.x = tx * 16; p.y = ty * 16 - 4; p.actionT = 0; p.selIndex = 0; p.energy = 100;
  G.updateCamera();
  // 마우스를 캐릭터 아래쪽에 둬서 '아래' 조준 → 정면칸 = (tx,ty+1)
  const cxs = p.x - G.cam.x + 8, cys = p.y - G.cam.y + 8;
  const aim = () => { Input.mouse.x = cxs; Input.mouse.y = cys + 40; };
  aim(); Input.mouse.down = true;
  for (let i = 0; i < 3; i++) { aim(); G.update(0.02); }
  if (p.dir !== 'down') throw new Error('마우스 아래 조준 실패: ' + p.dir);
  if (!p.charging) throw new Error('차징 시작 안됨');
  Input.mouse.down = false;                       // 클릭 떼면 스윙 적용
  let g = 0; while ((p.charging || p.isActing() || G.pending) && g++ < 200) { aim(); G.update(0.02); }
  if (w.tileAt(tx, ty + 1) !== 'soil') throw new Error('밭갈기 미적용');
  if (!(p.energy < 100)) throw new Error('체력 미소모');
});

step('차징 중 이동(절반속도) + 스윙 시 정지', () => {
  G.scene = 'farm'; G.world = G.maps.farm; const w = G.world, p = G.player;
  UI.menu = null; G.pending = null; p.charging = false; p.chargeT = 0; p.selIndex = 0; p.hoeLevel = 0; p.energy = 200;
  const ok = (x, y) => w.tileAt(x, y) === 'grass' && !w.objAt(x, y);
  let tx = -1, ty = -1;
  for (let y = 14; y < 26 && ty < 0; y++) for (let x = 14; x < 22; x++) { if (ok(x, y) && ok(x + 1, y) && ok(x + 2, y) && ok(x + 3, y)) { tx = x; ty = y; break; } }
  if (tx < 0) throw new Error('빈 strip 못찾음');
  p.x = tx * 16; p.y = ty * 16; p.actionT = 0; G.updateCamera();
  const cxs = p.x - G.cam.x + 8, cys = p.y - G.cam.y + 8;
  Input.mouse.down = true; Input.keys['d'] = true;
  const x0 = p.x;
  for (let i = 0; i < 5; i++) { Input.mouse.x = cxs + 40; Input.mouse.y = cys; G.update(0.05); }
  if (!p.charging) throw new Error('차징 상태 아님');
  if (!(p.x > x0)) throw new Error('차징 중 이동 불가(정지됨)');
  Input.mouse.down = false; Input.mouse.x = cxs + 40; Input.mouse.y = cys; G.update(0.02); // 떼면 스윙
  const xs = p.x; let moved = false, g = 0;
  while (p.isActing() && g++ < 100) { G.update(0.02); if (p.x !== xs) moved = true; }
  if (moved) throw new Error('스윙 중 이동됨');
  Input.keys = {}; Input.mouse.down = false;
});

step('수확은 상호작용(E)으로', () => {
  G.scene = 'farm'; G.world = G.maps.farm; const w = G.world, p = G.player; UI.menu = null; G.pending = null;
  let tx = -1, ty = -1;
  for (let y = 15; y < 26 && ty < 0; y++) for (let x = 14; x < 26; x++) {
    if (w.tileAt(x, y) === 'grass' && !w.objAt(x, y) && w.tileAt(x, y - 1) === 'grass' && !w.objAt(x, y - 1)) { tx = x; ty = y; break; }
  }
  if (tx < 0) throw new Error('빈 칸 못찾음');
  w.till(tx, ty); w.plant(tx, ty, 'parsnip', 'spring');
  for (let d = 0; d < 5; d++) { w.waterTile(tx, ty); w.newDay('spring', false); }
  if (!w.objAt(tx, ty) || !w.objAt(tx, ty).ready) throw new Error('성장 안됨');
  p.x = tx * 16; p.y = (ty - 1) * 16 - 4; p.dir = 'down'; p.actionT = 0; // (tx,ty-1)에서 아래 바라봄
  const before = p.countItem('parsnip');
  G.interact();
  if (p.countItem('parsnip') <= before) throw new Error('E 수확 실패');
  if (w.objAt(tx, ty)) throw new Error('1회성 작물 제거 안됨');
});

step('물뿌리개: 사용/소진/연못 보충', () => {
  const w = G.world, p = G.player; G.scene = 'farm'; G.world = w; UI.menu = null;
  let tx = -1, ty = -1;
  for (let y = 14; y < 26 && ty < 0; y++) for (let x = 14; x < 26; x++) {
    if (w.tileAt(x, y) === 'grass' && !w.objAt(x, y) && w.tileAt(x + 1, y) === 'grass' && !w.objAt(x + 1, y)) { tx = x; ty = y; break; }
  }
  if (tx < 0) throw new Error('빈 칸 못찾음');
  w.till(tx, ty); w.till(tx + 1, ty); p.canMax = 20; p.canWater = 1;
  G.useTool('can', tx, ty);
  if (!w.isWatered(tx, ty)) throw new Error('물 안줌'); if (p.canWater !== 0) throw new Error('물 소모 안됨');
  G.useTool('can', tx + 1, ty);
  if (w.isWatered(tx + 1, ty)) throw new Error('물 없는데 물 줌');
  let found = false;
  for (let y = 0; y < w.H && !found; y++) for (let x = 0; x < w.W; x++) if (w.tileAt(x, y) === 'water') { G.useTool('can', x, y); found = true; break; }
  if (!found) throw new Error('농장에 물(연못)이 없음');
  if (p.canWater !== p.canMax) throw new Error('연못 보충 안됨');
});

step('도구 강화 + 차징 범위', () => {
  const p = G.player; p.money = 999999; p.addItem('copper', 30); p.addItem('iron', 30);
  G.upgradeTool('hoe'); if (p.hoeLevel !== 1) throw new Error('괭이 강화 실패');
  G.upgradeTool('can'); if (p.canLevel !== 1) throw new Error('물뿌리개 강화 실패');
  if (p.canMax !== DATA.CAN_UPGRADES[1].cap) throw new Error('물 용량 갱신 안됨');
  p.dir = 'down';
  if (G.areaTiles(G.chargeStage('hoe', 0)).length !== 1) throw new Error('탭=1칸 아님');
  if (G.areaTiles(G.chargeStage('hoe', 0.4)).length !== 3) throw new Error('강화 차징 범위 아님');
});

step('스프링클러 제작/설치/아침 자동급수', () => {
  const w = G.world, p = G.player; G.scene = 'farm'; G.world = w; UI.menu = null;
  p.money = 999999; p.addItem('copper', 10); p.addItem('iron', 10);
  if (DATA.sprinklerPattern(0).length !== 4) throw new Error('패턴0(4칸) 아님');
  if (DATA.sprinklerPattern(1).length !== 8) throw new Error('패턴1(8칸) 아님');
  if (DATA.sprinklerPattern(2).length !== 24) throw new Error('패턴2(24칸) 아님');
  G.buyBuildable('sprinkler', 'sprinkler');
  if (p.countItem('sprinkler') < 1) throw new Error('제작(구매) 실패');
  const ok = (x, y) => w.tileAt(x, y) === 'grass' && !w.objAt(x, y);
  let cx = -1, cy = -1;
  for (let y = 16; y < 24 && cy < 0; y++) for (let x = 16; x < 24; x++) {
    if (ok(x, y) && ok(x, y - 1) && ok(x, y + 1) && ok(x - 1, y) && ok(x + 1, y) && ok(x - 1, y - 1)) { cx = x; cy = y; break; }
  }
  if (cx < 0) throw new Error('적당한 빈 칸 못찾음');
  if (!w.placeSprinkler(cx, cy, 'sprinkler')) throw new Error('설치 실패');
  w.till(cx, cy - 1); w.till(cx, cy + 1); w.till(cx - 1, cy); w.till(cx + 1, cy); w.till(cx - 1, cy - 1);
  w.watered.clear();
  w.newDay('spring', false);                 // 아침 자동급수
  if (!w.isWatered(cx, cy - 1) || !w.isWatered(cx + 1, cy)) throw new Error('스프링클러가 인접 밭에 급수 안함');
  if (w.isWatered(cx - 1, cy - 1)) throw new Error('기본 스프링클러가 대각선까지 급수함');
});

step('자연물 제거 (낫/도끼/망치)', () => {
  const w = G.world; G.scene = 'farm'; G.world = w;
  let bx = -1, by = -1;
  for (let y = 16; y < 24 && by < 0; y++) for (let x = 16; x < 24; x++) { if (w.tileAt(x, y) === 'grass' && !w.objAt(x, y)) { bx = x; by = y; break; } }
  if (bx < 0) throw new Error('빈 칸 못찾음');
  w.setObj(bx, by, { type: 'flower', c: '#e0405a' });
  if (!w.cutWeed(bx, by) || w.objAt(bx, by)) throw new Error('낫으로 꽃 제거 실패');
  w.setObj(bx, by, { type: 'grasstuft' });
  if (!w.cutWeed(bx, by) || w.objAt(bx, by)) throw new Error('낫으로 풀포기 제거 실패');
  w.setObj(bx, by, { type: 'bush' });
  if (!(w.chop(bx, by) || {}).broken || w.objAt(bx, by)) throw new Error('도끼로 덤불 제거 실패');
  w.setObj(bx, by, { type: 'log' });
  if (!(w.chop(bx, by) || {}).broken || w.objAt(bx, by)) throw new Error('도끼로 통나무 제거 실패');
  w.setObj(bx, by, { type: 'pebble' });
  if (!(w.mineRock(bx, by, DATA.HAMMER_UPGRADES[0]) || {}).broken || w.objAt(bx, by)) throw new Error('망치로 자갈 제거 실패');
});

step('NPC 배회 + 마을/지도 렌더', () => {
  const town = G.maps.town;
  if (!town.npcs.length) throw new Error('마을 NPC 없음');
  for (let i = 0; i < 80; i++) town.updateNpcs(0.05);
  for (const n of town.npcs) {
    const tx = ((n.x + 8) / 16) | 0, ty = ((n.y + 13) / 16) | 0;
    if (town.isSolid(tx, ty)) throw new Error('NPC가 벽에 끼임: ' + n.name);
  }
  G.scene = 'town'; G.world = town; G.render();   // 마을(NPC 포함) 렌더
  UI.menu = 'map'; G.render(); UI.menu = null;     // 지도 렌더
  G.scene = 'farm'; G.world = G.maps.farm;
});

step('NPC 대화 (E로 말걸기 / 클릭으로 닫기 / 초상화 렌더)', () => {
  G.scene = 'town'; G.world = G.maps.town; UI.menu = null; UI.dialogue = null;
  const npc = G.world.npcs[0]; if (!npc) throw new Error('마을 NPC 없음');
  npc.x = 20 * 16; npc.y = 16 * 16;            // 위치 스냅
  const p = G.player; p.x = 20 * 16; p.y = 17 * 16; p.dir = 'up'; p.actionT = 0;
  G.interact();
  if (!UI.dialogue) throw new Error('대화 안 열림');
  if (!DATA.NPCS[UI.dialogue.id]) throw new Error('대화 NPC 프로필 없음');
  G.render();                                  // 초상화/대화창 렌더(오류 없어야)
  Input.mouse.clicked = true; G.update(0.02);  // 클릭으로 닫기
  if (UI.dialogue) throw new Error('대화 안 닫힘');
  G.scene = 'farm'; G.world = G.maps.farm;
});

step('마을→산→마을 (길 워프)', () => {
  G.scene = 'town'; G.world = G.maps.town; UI.menu = null; G.dayTransition = null; G.pending = null;
  const p = G.player; p.x = 36 * 16; p.y = 17 * 16; p.hasStable = false; p.actionT = 0;
  Input.keys = {}; Input.keys['d'] = true; let g = 0;
  while (G.scene === 'town' && g++ < 500) G.update(0.03);
  Input.keys = {};
  if (G.scene !== 'mountain') throw new Error('마을→산 실패 (' + G.scene + ')');
  Input.keys = {}; Input.keys['a'] = true; g = 0;
  while (G.scene === 'mountain' && g++ < 500) G.update(0.03);
  Input.keys = {};
  if (G.scene !== 'town') throw new Error('산→마을 실패 (' + G.scene + ')');
});

step('상점 입장(영업중) + 카운터 구매 + 퇴장', () => {
  G.scene = 'town'; G.world = G.maps.town; UI.menu = null; G.pending = null; G.dayTransition = null;
  const p = G.player; G.time = 600; // 10:00 영업중
  p.x = 8 * 16; p.y = 13 * 16; p.actionT = 0;
  Input.keys = {}; Input.keys['w'] = true; let g = 0;
  while (G.scene === 'town' && g++ < 200) G.update(0.03);
  Input.keys = {};
  if (G.scene !== 'shop_in') throw new Error('상점 입장 실패 (' + G.scene + ')');
  const k = G.world.npcs.find((n) => n.role === 'keeper');
  if (!k || k.hidden) throw new Error('점원이 출근하지 않음');
  p.x = 6 * 16; p.y = 3 * 16; p.dir = 'up'; G.interact();
  if (UI.menu !== 'shop') throw new Error('영업중인데 구매 메뉴 안 열림'); UI.menu = null;
  p.x = G.world.entry.x * 16; p.y = G.world.entry.y * 16;
  Input.keys = {}; Input.keys['s'] = true; g = 0;
  while (G.scene === 'shop_in' && g++ < 200) G.update(0.03);
  Input.keys = {};
  if (G.scene !== 'town') throw new Error('상점 퇴장 실패 (' + G.scene + ')');
});

step('영업 종료 시 구매 불가', () => {
  G.scene = 'town'; G.world = G.maps.town; UI.menu = null; G.pending = null;
  const p = G.player; G.time = 1200; // 20:00 영업종료
  p.x = 8 * 16; p.y = 13 * 16; p.actionT = 0;
  Input.keys = {}; Input.keys['w'] = true; let g = 0;
  while (G.scene === 'town' && g++ < 200) G.update(0.03);
  Input.keys = {};
  if (G.scene !== 'shop_in') throw new Error('입장 실패');
  G.update(0.03);
  const k = G.world.npcs.find((n) => n.role === 'keeper');
  if (k && !k.hidden) throw new Error('영업종료인데 점원이 있음');
  p.x = 6 * 16; p.y = 3 * 16; p.dir = 'up'; G.interact();
  if (UI.menu === 'shop') throw new Error('영업종료인데 구매됨');
  UI.menu = null;
  G.exitBuilding();
});

step('산 광산 → 동굴 입장/탈출', () => {
  G.scene = 'mountain'; G.world = G.maps.mountain; UI.menu = null; G.pending = null;
  const p = G.player; p.x = 14 * 16; p.y = 8 * 16; p.dir = 'up';
  G.interact();
  if (G.scene !== 'cave') throw new Error('동굴 입장 실패 (' + G.scene + ')');
  G.exitCave();
  if (G.scene !== 'mountain') throw new Error('동굴→산 복귀 실패 (' + G.scene + ')');
});

step('새 맵/실내 렌더', () => {
  G.scene = 'mountain'; G.world = G.maps.mountain; G.render();
  G.scene = 'shop_in'; G.world = G.interiors.shop_in; G.render();
  G.scene = 'house_in'; G.world = G.interiors.house_in; G.render();
  G.scene = 'farm'; G.world = G.maps.farm;
});

step('각 메뉴 렌더', () => {
  ['title', 'help', 'shop', 'build', 'inventory', 'map'].forEach((m) => { UI.menu = m; G.render(); });
  UI.menu = 'machine'; UI.machineTarget = G.world.objAt(G._kx, G._ky); G.render();
  UI.menu = null;
});

step('마우스 4방향 조준', () => {
  G.scene = 'farm'; G.world = G.maps.farm; UI.menu = null; const p = G.player;
  p.x = 20 * 16; p.y = 16 * 16; p.actionT = 0; G.updateCamera();
  const cxs = p.x - G.cam.x + 8, cys = p.y - G.cam.y + 8;
  const check = (mx, my, want) => { Input.mouse.x = mx; Input.mouse.y = my; G.update(0.02); if (p.dir !== want) throw new Error('조준 ' + want + ' 실패: ' + p.dir); };
  check(cxs + 50, cys, 'right'); check(cxs - 50, cys, 'left'); check(cxs, cys + 50, 'down'); check(cxs, cys - 50, 'up');
});

step('update 프레임 30회 (마우스/이동 시뮬)', () => {
  Input.keys['d'] = true; Input.mouse.down = true; Input.mouse.x = 240; Input.mouse.y = 120;
  for (let i = 0; i < 30; i++) { G.update(0.05); G.render(); Input.endFrame(); }
  Input.keys = {}; Input.mouse.down = false;
});

step('저장/로드 왕복', () => {
  G.save();
  G.load();
  if (!G.player || !G.world) throw new Error('로드 후 상태 없음');
  G.render();
});

console.log('\n' + (failed ? '❌ ' + failed + '개 실패' : '✅ 전체 통과'));
process.exit(failed ? 1 : 0);
