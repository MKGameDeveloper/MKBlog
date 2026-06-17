/* ============================================================
 * world.js — 농장 맵: 타일, 오브젝트, 농사 로직
 * 한 칸(cell)은 ground 타입 + 선택적 object 하나를 가집니다.
 * ============================================================ */
(function () {
  'use strict';
  const T = 16;

  function World(type) {
    this.type = type || 'farm';        // 'farm'|'town'|'mountain'|'shop_in'|'house_in'
    this.indoor = false;
    if (this.type === 'town') { this.W = 40; this.H = 30; }
    else if (this.type === 'mountain') { this.W = 30; this.H = 20; }
    else if (this.type === 'shop_in' || this.type === 'house_in') { this.W = 12; this.H = 8; this.indoor = true; }
    else { this.W = 44; this.H = 34; }
    this.tiles = [];          // ground: 'grass'|'soil'|'water'|'path'|'pave'|'wood'|'wall'
    this.objects = new Map(); // "x,y" -> object
    this.watered = new Set(); // 오늘 물 준 흙 칸
    this.animals = [];        // 건물에서 생성된 동물
    this.npcs = [];           // 주민/점원
    this.entry = { x: 6, y: 6 }; // 외부에서 들어올 때 등장 위치(타일)
    this.gen();
  }

  World.prototype.key = function (x, y) { return x + ',' + y; };
  World.prototype.inB = function (x, y) { return x >= 0 && y >= 0 && x < this.W && y < this.H; };
  World.prototype.tileAt = function (x, y) { return this.inB(x, y) ? this.tiles[y][x] : 'water'; };
  World.prototype.objAt = function (x, y) { return this.objects.get(this.key(x, y)) || null; };
  World.prototype.setObj = function (x, y, o) { this.objects.set(this.key(x, y), o); };
  World.prototype.removeObj = function (x, y) { this.objects.delete(this.key(x, y)); };

  World.prototype.gen = function () {
    for (let y = 0; y < this.H; y++) {
      this.tiles[y] = [];
      for (let x = 0; x < this.W; x++) this.tiles[y][x] = 'grass';
    }
    if (this.type === 'town') this.genTown();
    else if (this.type === 'mountain') this.genMountain();
    else if (this.indoor) this.genInterior(this.type);
    else this.genFarm();
  };

  // 길 깔기(오브젝트 제거 포함)
  World.prototype.road = function (x, y) { if (this.inB(x, y)) { this.tiles[y][x] = 'path'; this.removeObj(x, y); } };

  // 굽이진 오솔길: 경유점들을 한 칸씩 이어 자연스러운 흙길을 만든다
  World.prototype.carveTrail = function (pts) {
    for (let i = 0; i < pts.length - 1; i++) {
      let x = pts[i][0], y = pts[i][1];
      const tx = pts[i + 1][0], ty = pts[i + 1][1];
      let guard = 0;
      while ((x !== tx || y !== ty) && guard++ < 500) {
        this.road(x, y);
        if (x !== tx && (y === ty || Math.random() < 0.6)) x += x < tx ? 1 : -1;
        else if (y !== ty) y += y < ty ? 1 : -1;
        else x += x < tx ? 1 : -1;
      }
      this.road(tx, ty);
    }
  };

  /* ---------- 농장 맵 ---------- */
  World.prototype.genFarm = function () {
    // 연못
    for (let y = 24; y < 30; y++)
      for (let x = 30; x < 37; x++)
        if ((x - 33) ** 2 + (y - 27) ** 2 < 10) this.tiles[y][x] = 'water';

    // 집 / 침대 / 출하 상자
    this.placeStructure(3, 3, 4, 3, { type: 'building', id: 'house' });
    this.setObj(5, 6, { type: 'bed' });
    this.setObj(8, 8, { type: 'bin' });

    // 동쪽으로 이어지는 길 + 마을행 워프(오른쪽 끝 문)
    for (let x = 1; x < this.W; x++) this.road(x, 16);
    for (const gy of [15, 16, 17]) { this.road(this.W - 1, gy); this.setObj(this.W - 1, gy, { type: 'warp', to: 'town', tx: 2, ty: 16, dir: 'right' }); }

    // 바위/잡초/나무 (구조물·길 회피)
    const free = (x, y) => this.inB(x, y) && this.tiles[y][x] === 'grass' && !this.objAt(x, y) && (y < 14 || y > 18);
    const farmZone = (x, y) => x > 9 && x < 28 && y > 8 && y < 30;
    for (let i = 0; i < 65; i++) {
      const x = (Math.random() * this.W) | 0, y = (Math.random() * this.H) | 0;
      if (!free(x, y)) continue;
      if (farmZone(x, y) && Math.random() < 0.6) continue;
      const large = Math.random() < 0.3;
      this.setObj(x, y, { type: 'rock', large, hp: large ? 4 : 1 });
    }
    for (let i = 0; i < 75; i++) {
      const x = (Math.random() * this.W) | 0, y = (Math.random() * this.H) | 0;
      if (free(x, y)) this.setObj(x, y, { type: 'weed' });
    }
    for (let i = 0; i < 42; i++) {
      const x = (Math.random() * this.W) | 0, y = (Math.random() * this.H) | 0;
      if (free(x, y) && !farmZone(x, y)) this.setObj(x, y, { type: 'tree', hp: 3 });
    }

    // 집 → 메인 길로 이어지는 굽이진 오솔길
    this.carveTrail([[6, 7], [7, 10], [10, 13], [10, 16]]);

    // 자연물(꽃·풀포기·덤불) — 길/도로 주변은 피함
    const free2 = (x, y) => this.inB(x, y) && this.tiles[y][x] === 'grass' && !this.objAt(x, y) && (y < 14 || y > 18);
    const fcols = ['#e0405a', '#e8a23a', '#f0e04a', '#d84ad8', '#5a8fe0'];
    const sc = (n, mk) => { for (let i = 0; i < n; i++) { const x = (Math.random() * this.W) | 0, y = (Math.random() * this.H) | 0; if (free2(x, y)) mk(x, y); } };
    sc(18, (x, y) => this.setObj(x, y, { type: 'flower', c: fcols[(Math.random() * fcols.length) | 0] }));
    sc(24, (x, y) => this.setObj(x, y, { type: 'grasstuft' }));
    sc(8, (x, y) => this.setObj(x, y, { type: 'bush' }));
    sc(10, (x, y) => this.setObj(x, y, { type: 'pebble' }));
  };

  /* ---------- 마을 맵 (돌 광장 + 둘러싼 건물) ---------- */
  World.prototype.genTown = function () {
    const T = 16;
    const PX0 = 6, PX1 = 33, PY0 = 12, PY1 = 22;   // 광장 범위

    // 1) 중앙 돌바닥 광장 (모서리를 깎아 직사각 느낌 완화)
    for (let y = PY0; y <= PY1; y++) for (let x = PX0; x <= PX1; x++) {
      const cut = (x < PX0 + 2 && y < PY0 + 2) || (x > PX1 - 2 && y < PY0 + 2) ||
        (x < PX0 + 2 && y > PY1 - 2) || (x > PX1 - 2 && y > PY1 - 2);
      if (!cut) this.tiles[y][x] = 'pave';
    }
    // 2) 농장행 진입로(왼쪽 흙길) + 워프 — 농장 진입 지점(41,16)
    for (let x = 0; x <= PX0; x++) { this.road(x, 16); this.road(x, 17); }
    for (const gy of [15, 16, 17]) { this.tiles[gy][0] = 'path'; this.removeObj(0, gy); this.setObj(0, gy, { type: 'warp', to: 'farm', tx: 41, ty: 16, dir: 'left' }); }
    // 동쪽 산(광산)으로 가는 길 + 워프
    for (let x = PX1; x < this.W; x++) { this.road(x, 16); this.road(x, 17); }
    for (const gy of [16, 17]) this.setObj(this.W - 1, gy, { type: 'warp', to: 'mountain', tx: 2, ty: 11, dir: 'right' });

    // 3) 광장을 마주보는 건물들 (문이 광장 쪽; 바닥은 광장 바로 위 y11)
    //    들어갈 수 있는 건물은 문 앞 칸에 입장 워프를 둔다.
    this.placeStructure(6, 8, 5, 4, { type: 'building', id: 'shop' });
    this.setObj(8, 12, { type: 'warp', enter: 'shop_in' });
    this.placeStructure(13, 9, 4, 3, { type: 'building', id: 'townhouse' });
    this.setObj(15, 12, { type: 'warp', enter: 'house_in' });
    this.placeStructure(18, 9, 3, 3, { type: 'building', id: 'townhouse' });
    this.placeStructure(23, 9, 4, 3, { type: 'building', id: 'townhouse' });
    this.setObj(25, 12, { type: 'warp', enter: 'house_in' });
    this.placeStructure(29, 8, 4, 4, { type: 'building', id: 'townhouse' });
    // 광장 아래쪽 건물(마을을 감쌈)
    this.placeStructure(10, 23, 4, 3, { type: 'building', id: 'townhouse' });
    this.placeStructure(24, 23, 4, 3, { type: 'building', id: 'townhouse' });

    // 4) 광장 중앙 분수 + 가로등 + 울타리
    this.setObj(19, 16, { type: 'fountain' });
    for (const [lx, ly] of [[PX0 + 1, PY0 + 1], [PX1 - 1, PY0 + 1], [PX0 + 1, PY1 - 1], [PX1 - 1, PY1 - 1]]) this.setObj(lx, ly, { type: 'lamp' });
    for (let x = PX0 + 3; x <= PX1 - 3; x += 1) if (x < 15 || x > 23) this.setObj(x, PY1, { type: 'fence' }); // 광장 아래 난간(가운데는 통로)

    // 5) 가장자리에 빽빽한 나무 + 자연물
    const free = (x, y) => this.inB(x, y) && this.tiles[y][x] === 'grass' && !this.objAt(x, y);
    const edge = (x, y) => x < 5 || x > 34 || y < 8 || y > 24;
    for (let i = 0; i < 110; i++) { const x = (Math.random() * this.W) | 0, y = (Math.random() * this.H) | 0; if (free(x, y) && edge(x, y)) this.setObj(x, y, { type: 'tree', hp: 99 }); }
    const fcols = ['#e0405a', '#e8a23a', '#d84ad8', '#f0e04a', '#5a8fe0', '#ffd0e0'];
    const sc = (n, mk) => { for (let i = 0; i < n; i++) { const x = (Math.random() * this.W) | 0, y = (Math.random() * this.H) | 0; if (free(x, y)) mk(x, y); } };
    sc(26, (x, y) => this.setObj(x, y, { type: 'flower', c: fcols[(Math.random() * fcols.length) | 0] }));
    sc(30, (x, y) => this.setObj(x, y, { type: 'grasstuft' }));
    sc(12, (x, y) => this.setObj(x, y, { type: 'bush' }));
    sc(8, (x, y) => this.setObj(x, y, { type: 'pebble' }));

    // 6) 주민(NPC) — 광장에서 배회 (피에르는 상점에 출근하므로 제외)
    const mk = (id, tx, ty) => { const d = DATA.NPCS[id]; return { id, name: d.name, color: d.portrait.cloth, x: tx * T, y: ty * T, dir: 'down', moveT: 0, frame: 0 }; };
    this.npcs = [mk('robin', 16, 18), mk('leah', 22, 15), mk('mayor', 27, 19), mk('maru', 13, 20)];
  };

  /* ---------- 산 맵 (광산 입구) ---------- */
  World.prototype.genMountain = function () {
    // 서쪽 진입로 + 마을행 워프
    for (let x = 0; x <= 11; x++) this.road(x, 11);
    for (const gy of [10, 11, 12]) { this.tiles[gy][0] = 'path'; this.removeObj(0, gy); this.setObj(0, gy, { type: 'warp', to: 'town', tx: 37, ty: 17, dir: 'left' }); }
    // 광산 건물 + 동굴 입구
    this.placeStructure(13, 4, 3, 3, { type: 'building', id: 'cavehouse' });
    this.setObj(14, 7, { type: 'cave' });
    this.carveTrail([[11, 11], [14, 11], [14, 8]]);
    // 산속 호수
    for (let y = 13; y < 18; y++) for (let x = 20; x < 27; x++) if ((x - 23) ** 2 + (y - 15) ** 2 < 9) this.tiles[y][x] = 'water';
    // 바위(채굴 가능) + 나무
    const free = (x, y) => this.inB(x, y) && this.tiles[y][x] === 'grass' && !this.objAt(x, y);
    for (let i = 0; i < 55; i++) { const x = (Math.random() * this.W) | 0, y = (Math.random() * this.H) | 0; if (free(x, y)) { const lg = Math.random() < 0.45; this.setObj(x, y, { type: 'rock', large: lg, hp: lg ? 4 : 1 }); } }
    for (let i = 0; i < 45; i++) { const x = (Math.random() * this.W) | 0, y = (Math.random() * this.H) | 0; if (free(x, y)) this.setObj(x, y, { type: 'tree', hp: 99 }); }
    this.npcs = [];
  };

  /* ---------- 건물 내부 ---------- */
  World.prototype.genInterior = function (kind) {
    const W = this.W, H = this.H;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++)
      this.tiles[y][x] = (x === 0 || y === 0 || x === W - 1 || y === H - 1) ? 'wall' : 'wood';
    const ex = (W / 2) | 0;
    this.tiles[H - 1][ex] = 'wood';                 // 아래 벽 출입구
    this.setObj(ex, H - 1, { type: 'warp', back: true });
    this.entry = { x: ex, y: H - 3 };

    if (kind === 'shop_in') {
      for (let x = 3; x <= 8; x++) this.setObj(x, 2, { type: 'counter' });
      this.setObj(2, 1, { type: 'shelf' }); this.setObj(9, 1, { type: 'shelf' }); this.setObj(W - 2, 3, { type: 'shelf' });
      this.npcs = [{ id: 'pierre', name: DATA.NPCS.pierre.name, color: '#3a72c0', role: 'keeper', fixed: true, hidden: false, x: 5 * 16, y: 1 * 16, dir: 'down', moveT: 0, frame: 0 }];
    } else { // house_in
      this.setObj(2, 2, { type: 'table' }); this.setObj(W - 3, 2, { type: 'shelf' }); this.setObj(2, H - 3, { type: 'table' });
      this.npcs = [];
    }
  };

  // 마을 주민 배회 AI
  World.prototype.updateNpcs = function (dt) {
    if (!this.npcs || !this.npcs.length) return;
    const T = 16;
    for (const n of this.npcs) {
      if (n.fixed) continue;             // 점원 등 고정 NPC는 배회하지 않음
      n.moveT -= dt;
      if (n.moveT <= 0) {
        const dirs = ['up', 'down', 'left', 'right', 'idle', 'idle'];
        n.dir = dirs[(Math.random() * dirs.length) | 0];
        n.moveT = 0.6 + Math.random() * 1.6;
      }
      if (n.dir === 'idle') continue;
      const sp = 18 * dt;
      let vx = 0, vy = 0;
      if (n.dir === 'up') vy = -sp; else if (n.dir === 'down') vy = sp; else if (n.dir === 'left') vx = -sp; else vx = sp;
      const nx = n.x + vx, ny = n.y + vy;
      const ftx = ((nx + 8) / T) | 0, fty = ((ny + 13) / T) | 0;
      if (!this.isSolid(ftx, fty)) { n.x = nx; n.y = ny; n.frame = (((n.x + n.y) / 7) | 0) & 1; }
      else n.moveT = 0; // 막히면 즉시 방향 재선택
    }
  };

  // 멀티타일 구조물 배치(앵커 칸에만 객체, 나머지는 occupied 마커)
  World.prototype.placeStructure = function (ax, ay, w, h, obj) {
    obj.w = w; obj.h = h; obj.ax = ax; obj.ay = ay;
    this.setObj(ax, ay, obj);
    for (let y = ay; y < ay + h; y++)
      for (let x = ax; x < ax + w; x++) {
        if (this.tiles[y]) this.tiles[y][x] = 'grass';
        if (x === ax && y === ay) continue;
        this.setObj(x, y, { type: 'occupied', anchor: [ax, ay] });
      }
  };

  // 충돌: 통행 불가 여부
  World.prototype.isSolid = function (x, y) {
    if (!this.inB(x, y)) return true;
    const t = this.tiles[y][x];
    if (t === 'water' || t === 'wall') return true;
    const o = this.objAt(x, y);
    if (!o) return false;
    return ['rock', 'tree', 'building', 'occupied', 'machine', 'bin', 'cavehouse', 'counter', 'shelf', 'table'].includes(o.type);
  };

  /* ---------------- 도구 동작 ---------------- */

  // 괭이: 밭 갈기
  World.prototype.till = function (x, y) {
    if (!this.inB(x, y)) return false;
    const t = this.tiles[y][x];
    if ((t === 'grass' || t === 'path') && !this.objAt(x, y)) {
      this.tiles[y][x] = 'soil';
      return true;
    }
    return false;
  };

  // 물뿌리개
  World.prototype.waterTile = function (x, y) {
    if (this.tiles[y] && this.tiles[y][x] === 'soil') { this.watered.add(this.key(x, y)); return true; }
    return false;
  };
  World.prototype.isWatered = function (x, y) { return this.watered.has(this.key(x, y)); };

  // 씨앗 심기
  World.prototype.plant = function (x, y, cropId, season) {
    if (this.tiles[y] && this.tiles[y][x] === 'soil' && !this.objAt(x, y)) {
      const c = DATA.CROPS[cropId];
      if (!c) return false;
      const inSeason = c.seasons.includes(season);
      this.setObj(x, y, { type: 'crop', id: cropId, growth: 0, ready: false, dead: !inSeason });
      return inSeason; // 제철 아니면 심자마자 시듦 → false 반환
    }
    return false;
  };

  // 수확: { items:[{id,qty}], ok } 또는 null
  World.prototype.harvest = function (x, y) {
    const o = this.objAt(x, y);
    if (!o || o.type !== 'crop') return null;
    if (o.dead) { this.removeObj(x, y); return { dead: true, items: [] }; }
    if (!o.ready) return null;
    const c = DATA.CROPS[o.id];
    const qty = c.yieldMin + ((Math.random() * (c.yieldMax - c.yieldMin + 1)) | 0);
    const result = { items: [{ id: o.id, qty }], crop: c };
    if (c.regrow) { o.growth = Math.max(0, c.grow - c.regrow); o.ready = false; }
    else this.removeObj(x, y);
    return result;
  };

  // 망치: 돌/자갈 캐기. hammer = {power, breakLarge}
  World.prototype.mineRock = function (x, y, hammer) {
    const o = this.objAt(x, y);
    if (!o) return null;
    if (o.type === 'pebble') { this.removeObj(x, y); return { broken: true, items: [{ id: 'stone', qty: 1 }] }; }
    if (o.type !== 'rock') return null;
    if (o.large && !hammer.breakLarge) return { blocked: true };
    o.hp -= hammer.power;
    if (o.hp <= 0) {
      this.removeObj(x, y);
      const drops = [{ id: 'stone', qty: o.large ? 2 + ((Math.random() * 2) | 0) : 1 }];
      if (o.large && Math.random() < 0.35) drops.push({ id: 'copper', qty: 1 });
      return { broken: true, items: drops };
    }
    return { hit: true };
  };

  // 낫: 잡초/풀포기/꽃/시든작물
  World.prototype.cutWeed = function (x, y) {
    const o = this.objAt(x, y);
    if (o && (o.type === 'weed' || o.type === 'grasstuft' || o.type === 'flower')) {
      this.removeObj(x, y);
      return { items: Math.random() < 0.5 ? [{ id: 'fiber', qty: 1 }] : [] };
    }
    return null;
  };

  // 도끼: 나무/그루터기/덤불/통나무
  World.prototype.chop = function (x, y) {
    const o = this.objAt(x, y);
    if (!o) return null;
    if (o.type === 'tree') {
      o.hp -= 1;
      if (o.hp <= 0) { this.setObj(x, y, { type: 'stump', hp: 1 }); return { broken: true, items: [{ id: 'wood', qty: 3 + ((Math.random() * 3) | 0) }] }; }
      return { hit: true, items: [{ id: 'wood', qty: 1 }] };
    }
    if (o.type === 'stump') { this.removeObj(x, y); return { broken: true, items: [{ id: 'wood', qty: 2 }] }; }
    if (o.type === 'log') { this.removeObj(x, y); return { broken: true, items: [{ id: 'wood', qty: 2 }] }; }
    if (o.type === 'bush') { this.removeObj(x, y); return { broken: true, items: [{ id: 'fiber', qty: 1 + ((Math.random() * 2) | 0) }] }; }
    return null;
  };

  // 기계/건물 설치
  World.prototype.placeMachine = function (x, y, machineId) {
    if (this.tiles[y] && this.tiles[y][x] !== 'water' && !this.objAt(x, y)) {
      this.setObj(x, y, { type: 'machine', id: machineId, job: null });
      return true;
    }
    return false;
  };
  World.prototype.placeSprinkler = function (x, y, id) {
    if (this.tiles[y] && this.tiles[y][x] !== 'water' && !this.objAt(x, y)) {
      this.setObj(x, y, { type: 'sprinkler', id, tier: DATA.SPRINKLERS[id].tier });
      return true;
    }
    return false;
  };
  World.prototype.placeBuilding = function (x, y, buildId) {
    const b = DATA.BUILDINGS[buildId];
    const [w, h] = b.size;
    for (let yy = y; yy < y + h; yy++)
      for (let xx = x; xx < x + w; xx++)
        if (!this.inB(xx, yy) || this.objAt(xx, yy) || this.tiles[yy][xx] === 'water') return false;
    const obj = { type: 'building', id: buildId, product: null };
    this.placeStructure(x, y, w, h, obj);
    // 동물 한 마리 배치
    if (b.produces === 'egg') this.animals.push({ kind: 'chicken', x: x + 0.5, y: y + h + 0.2, hx: x, hy: y, w, h });
    if (b.produces === 'milk') this.animals.push({ kind: 'cow', x: x + 1, y: y + h + 0.2, hx: x, hy: y, w, h });
    if (buildId === 'stable') this.animals.push({ kind: 'horse', x: x + 0.5, y: y + h + 0.2, hx: x, hy: y, w, h });
    return true;
  };

  /* ---------------- 하루 경과 처리 ---------------- */
  World.prototype.newDay = function (season, seasonChanged) {
    // 작물 성장 / 시듦
    for (const [k, o] of this.objects) {
      if (o.type !== 'crop') continue;
      const [x, y] = k.split(',').map(Number);
      const c = DATA.CROPS[o.id];
      if (seasonChanged && !c.seasons.includes(season)) { o.dead = true; continue; }
      if (o.dead) continue;
      if (this.watered.has(k)) {
        o.growth = Math.min(c.grow, o.growth + 1);
        if (o.growth >= c.grow) o.ready = true;
      }
    }
    this.watered.clear();

    // 스프링클러: 아침에 범위 내 '갈린 밭'을 자동 급수(다음 날 성장에 반영)
    for (const [k, o] of this.objects) {
      if (o.type !== 'sprinkler') continue;
      const a = k.split(',').map(Number);
      for (const [dx, dy] of DATA.sprinklerPattern(o.tier)) {
        const tx = a[0] + dx, ty = a[1] + dy;
        if (this.tiles[ty] && this.tiles[ty][tx] === 'soil') this.watered.add(this.key(tx, ty));
      }
    }

    // 가공 기계 진행
    for (const o of this.objects.values()) {
      if (o.type === 'machine' && o.job && o.job.daysLeft > 0) {
        o.job.daysLeft--;
        if (o.job.daysLeft <= 0) o.job.ready = true;
      }
    }
    // 건물 산출물
    for (const o of this.objects.values()) {
      if (o.type === 'building') {
        const b = DATA.BUILDINGS[o.id];
        if (b && b.produces) o.product = b.produces; // 매일 1개(미수거 시 갱신)
      }
    }
  };

  /* ---------------- 렌더 ---------------- */
  World.prototype.render = function (ctx, cam, season, time) {
    const x0 = Math.max(0, (cam.x / T | 0) - 1);
    const y0 = Math.max(0, (cam.y / T | 0) - 1);
    const x1 = Math.min(this.W, x0 + (cam.vw / T | 0) + 3);
    const y1 = Math.min(this.H, y0 + (cam.vh / T | 0) + 3);

    // 지형
    for (let y = y0; y < y1; y++) {
      for (let x = x0; x < x1; x++) {
        const sx = x * T - cam.x, sy = y * T - cam.y;
        const t = this.tiles[y][x];
        if (t === 'water') Sprites.water(ctx, sx, sy, time);
        else if (t === 'soil') Sprites.soil(ctx, sx, sy, this.isWatered(x, y));
        else if (t === 'path') Sprites.path(ctx, sx, sy, x, y);
        else if (t === 'pave') Sprites.pave(ctx, sx, sy, x, y);
        else if (t === 'wood') Sprites.woodFloor(ctx, sx, sy, x, y);
        else if (t === 'wall') Sprites.wallTile(ctx, sx, sy);
        else Sprites.grass(ctx, sx, sy, x, y, season);
      }
    }

    // 오브젝트 (위→아래 깊이감)
    for (let y = y0; y < y1; y++) {
      for (let x = x0; x < x1; x++) {
        const o = this.objAt(x, y);
        if (!o || o.type === 'occupied') continue;
        const sx = x * T - cam.x, sy = y * T - cam.y;
        this.drawObject(ctx, o, sx, sy, time, season);
      }
    }
    // 동물
    for (const a of this.animals) {
      const sx = a.x * T - cam.x, sy = a.y * T - cam.y;
      if (a.kind === 'chicken') Sprites.chicken(ctx, sx, sy);
      else if (a.kind === 'cow') Sprites.cow(ctx, sx, sy);
      else if (a.kind === 'horse') Sprites.horse(ctx, sx, sy);
    }
    // 주민/점원
    for (const n of this.npcs) {
      if (n.hidden) continue;
      if (n.x + T < cam.x || n.x - cam.x > cam.vw || n.y + T < cam.y || n.y - cam.y > cam.vh) continue;
      Sprites.npc(ctx, n.x - cam.x, n.y - cam.y, n.dir, n.color, n.frame);
    }
  };

  World.prototype.drawObject = function (ctx, o, sx, sy, time, season) {
    switch (o.type) {
      case 'weed': Sprites.weed(ctx, sx, sy); break;
      case 'rock': o.large ? Sprites.rockLarge(ctx, sx, sy) : Sprites.rockSmall(ctx, sx, sy); break;
      case 'tree': Sprites.tree(ctx, sx, sy, season); break;
      case 'stump': Sprites.stump(ctx, sx, sy); break;
      case 'crop': {
        const c = DATA.CROPS[o.id];
        if (o.dead) { Sprites.rect(ctx, sx + 6, sy + 4, 3, 10, '#7a6a4a'); break; }
        const stages = 4;
        const stage = Math.min(stages - 1, (o.growth / Math.max(1, c.grow) * (stages - 1)) | 0);
        Sprites.crop(ctx, sx, sy, c.tint, stage, stages, o.ready);
        break;
      }
      case 'machine': {
        const m = DATA.MACHINES[o.id];
        Sprites.machine(ctx, sx, sy, m.tint, !!(o.job && !o.job.ready), !!(o.job && o.job.ready));
        break;
      }
      case 'building': {
        const W = o.w * T;
        if (o.id === 'house') Sprites.house(ctx, sx, sy);
        else if (o.id === 'shop') {
          Sprites.building(ctx, sx, sy, o.w, o.h, '#cdb88a', { roof: '#566e8e', style: 'timber', dormer: false, vines: true });
          Sprites.clock(ctx, sx + (W >> 1), sy + 9);           // 박공 시계
          Sprites.rect(ctx, sx + W - 17, sy + 9, 14, 6, '#5a3a1c'); // 간판
          Sprites.rect(ctx, sx + W - 16, sy + 10, 12, 4, '#caa24a');
        } else if (o.id === 'cavehouse') {
          Sprites.building(ctx, sx, sy, o.w, o.h, '#8a8690', { roof: '#454048', style: 'stone', dormer: false });
          const mx = sx + (W >> 1);
          Sprites.rect(ctx, mx - 6, sy + o.h * T - 12, 12, 2, '#3a3a44');
          Sprites.rect(ctx, mx - 5, sy + o.h * T - 11, 10, 11, '#13111a'); // 갱도 입구
        } else if (o.id === 'townhouse') {
          const i = o.ax % 4;
          const cfg = [
            { tint: '#d8c6a0', roof: '#4a6a8a', style: 'timber', dormer: true, chimney: true },
            { tint: '#9a6b3e', roof: '#7a3f32', style: 'log', chimney: true },
            { tint: '#b6905c', roof: '#4a6a4a', style: 'plank', dormer: true },
            { tint: '#9aa0a8', roof: '#5a4a5a', style: 'stone', vines: true },
          ][i];
          Sprites.building(ctx, sx, sy, o.w, o.h, cfg.tint, cfg);
        } else {
          const b = DATA.BUILDINGS[o.id];
          const st = o.id === 'barn' ? 'log' : 'plank';
          Sprites.building(ctx, sx, sy, o.w, o.h, b.tint, { style: st, chimney: o.id === 'barn' });
        }
        if (o.product) { Sprites.rect(ctx, sx + (W >> 1) - 2, sy - 6, 4, 4, '#f5e04a'); }
        break;
      }
      case 'warp': {
        if (o.back || o.enter) { Sprites.doormat(ctx, sx, sy); break; } // 출입문 매트
        const c = 'rgba(40,28,16,.4)';
        for (let i = 0; i < 3; i++) {
          const t = i * 3;
          if (o.dir === 'right') { Sprites.rect(ctx, sx + 3 + t, sy + 7, 1, 2, c); Sprites.rect(ctx, sx + 4 + t, sy + 6, 1, 4, c); }
          else { Sprites.rect(ctx, sx + 12 - t, sy + 7, 1, 2, c); Sprites.rect(ctx, sx + 11 - t, sy + 6, 1, 4, c); }
        }
        break;
      }
      case 'counter': Sprites.counter(ctx, sx, sy); break;
      case 'shelf': Sprites.shelf(ctx, sx, sy); break;
      case 'table': Sprites.table(ctx, sx, sy); break;
      case 'sprinkler': Sprites.sprinkler(ctx, sx, sy, o.tier, time); break;
      case 'bush': Sprites.bush(ctx, sx, sy); break;
      case 'flower': Sprites.flower(ctx, sx, sy, o.c || '#e0405a'); break;
      case 'grasstuft': Sprites.grassTuft(ctx, sx, sy); break;
      case 'log': Sprites.log(ctx, sx, sy); break;
      case 'pebble': Sprites.pebble(ctx, sx, sy); break;
      case 'lamp': Sprites.lamp(ctx, sx, sy, false); break;
      case 'fence': Sprites.fence(ctx, sx, sy); break;
      case 'fountain': Sprites.fountain(ctx, sx, sy); break;
      case 'well': {
        Sprites.rect(ctx, sx + 3, sy + 7, 10, 7, '#8a8a92'); Sprites.rect(ctx, sx + 3, sy + 7, 10, 1, '#a8a8b0');
        Sprites.rect(ctx, sx + 4, sy + 8, 8, 3, '#2f3a48');
        Sprites.rect(ctx, sx + 4, sy + 3, 1, 5, '#6b4a2a'); Sprites.rect(ctx, sx + 11, sy + 3, 1, 5, '#6b4a2a');
        Sprites.rect(ctx, sx + 3, sy, 10, 4, '#9a4030'); Sprites.rect(ctx, sx + 3, sy, 10, 1, '#b85040');
        break;
      }
      case 'bin': Sprites.rect(ctx, sx + 2, sy + 4, 12, 10, '#6a5a3a'); Sprites.rect(ctx, sx + 2, sy + 4, 12, 2, '#8a7a4a'); Sprites.rect(ctx, sx + 3, sy + 3, 10, 2, '#4a3a22'); break;
      case 'cave': Sprites.rect(ctx, sx + 2, sy + 6, 12, 8, '#1a1a22'); Sprites.rect(ctx, sx + 1, sy + 4, 14, 3, '#3a3a44'); Sprites.rect(ctx, sx + 4, sy + 8, 8, 6, '#0a0a10'); break;
      case 'bed': Sprites.rect(ctx, sx + 2, sy + 4, 12, 10, '#b04a5a'); Sprites.rect(ctx, sx + 2, sy + 4, 5, 10, '#e0e0ea'); break;
    }
  };

  window.World = World;
})();
