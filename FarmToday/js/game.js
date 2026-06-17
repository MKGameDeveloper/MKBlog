/* ============================================================
 * game.js — 메인 컨트롤러: 루프, 시간, 도구 사용, 상호작용,
 *           상점/건설 거래, 동굴 출입, 저장/로드
 * ============================================================ */
(function () {
  'use strict';
  const T = 16;
  const SAVE_KEY = 'farmtoday_save_v1';

  const Game = {
    IW: 480, IH: 272,       // 논리 해상도(30x17 타일). 기기 해상도로 정수배 확대 렌더링.
    S: 1,                   // 기기픽셀당 아트픽셀 배율
    scene: 'farm',
    cam: { x: 0, y: 0, vw: 480, vh: 272 },
    timeRate: 2.4,            // 게임분/실초 (자면 빨리 넘김)
    time: 360, day: 1, seasonIdx: 0, year: 1,
    dayTransition: null,
    warpFlash: 0,
    hasSave: false,
    started: false,
    last: 0,

    get season() { return DATA.SEASONS[this.seasonIdx]; },

    init() {
      this.canvas = document.getElementById('game');
      this.ctx = this.canvas.getContext('2d');
      Input.init(this.canvas, this.IW, this.IH);
      this.hasSave = !!localStorage.getItem(SAVE_KEY);

      // 기기 해상도(devicePixelRatio)에서 정수배로 백킹 캔버스를 키워
      // 픽셀은 또렷하게, 텍스트는 고해상도로 선명하게 렌더링한다.
      const fit = () => {
        const dpr = window.devicePixelRatio || 1;
        const S = Math.max(1, Math.floor(Math.min(window.innerWidth * dpr / this.IW, window.innerHeight * dpr / this.IH)));
        this.canvas.width = this.IW * S;
        this.canvas.height = this.IH * S;
        this.canvas.style.width = (this.IW * S / dpr) + 'px';
        this.canvas.style.height = (this.IH * S / dpr) + 'px';
        this.S = S;
        this.ctx.imageSmoothingEnabled = false; // 캔버스 크기 변경 시 컨텍스트 초기화됨
      };
      window.addEventListener('resize', fit); fit();

      // 시작은 임시 월드(타이틀 배경)
      this.buildMaps();
      this.world = this.maps.farm;
      this.player = new Player(7 * T, 7 * T);
      UI.menu = 'title';
      this.scene = 'farm';

      this.last = performance.now();
      requestAnimationFrame((t) => this.loop(t));
    },

    // 야외 맵 + 실내 맵 + 동굴 생성
    buildMaps() {
      this.maps = { farm: new World('farm'), town: new World('town'), mountain: new World('mountain') };
      this.interiors = { shop_in: new World('shop_in'), house_in: new World('house_in') };
      this.cave = new Cave();
    },

    startNew() {
      localStorage.removeItem(SAVE_KEY);
      this.buildMaps();
      this.world = this.maps.farm;
      this.player = new Player(7 * T, 7 * T);
      this.time = 360; this.day = 1; this.seasonIdx = 0; this.year = 1;
      this.scene = 'farm';
      this.started = true;
      UI.toast('새 농장에 오신 걸 환영합니다! 동쪽 길로 나가면 마을이 있어요.', '#ffe');
    },

    // 씬 이름 → 맵 객체 (야외 또는 실내)
    mapOf(scene) { return this.maps[scene] || this.interiors[scene]; },
    // 현재 활동 맵(동굴 / 실내 / 야외)
    activeMap() { return this.scene === 'cave' ? this.cave : this.world; },
    shopOpen() { return this.time >= 540 && this.time < 1020; }, // 9:00~17:00
    talkTo(n) {
      const d = DATA.NPCS[n.id]; if (!d) return;
      UI.dialogue = { id: n.id, line: d.lines[(Math.random() * d.lines.length) | 0] };
    },

    // 야외 맵으로 워프
    gotoMap(toId, tx, ty) {
      this.scene = toId;
      this.world = this.maps[toId];
      this.player.x = tx * T; this.player.y = ty * T;
      this.player.actionT = 0; this.pending = null;
      this.warpFlash = 0.45;
      this.updateCamera();
      UI.toast({ town: '🏘 마을', farm: '🌾 농장', mountain: '⛰ 광산 입구' }[toId] || toId, '#ffe');
    },

    // 건물 안으로 들어가기 (문턱 워프). cx,cy = 밟은 문턱 칸
    enterBuilding(kind, cx, cy) {
      this.outReturn = { scene: this.scene, x: cx * T, y: (cy + 1) * T }; // 나올 때 문턱 한 칸 아래
      this.scene = kind; this.world = this.interiors[kind];
      const e = this.world.entry;
      this.player.x = e.x * T; this.player.y = e.y * T; this.player.dir = 'down';
      this.player.actionT = 0; this.pending = null; this.warpFlash = 0.45;
      if (kind === 'shop_in') { const k = this.world.npcs.find((n) => n.role === 'keeper'); if (k) k.hidden = !this.shopOpen(); }
      this.updateCamera();
      UI.toast(kind === 'shop_in' ? (this.shopOpen() ? '🏪 상점 (영업 중)' : '🏪 상점 (영업 종료)') : '🏠 실내', '#ffe');
    },
    exitBuilding() {
      const r = this.outReturn || { scene: 'town', x: 8 * T, y: 13 * T };
      this.scene = r.scene; this.world = this.maps[r.scene] || this.maps.town;
      this.player.x = r.x; this.player.y = r.y; this.player.dir = 'down';
      this.player.actionT = 0; this.pending = null; this.warpFlash = 0.45;
      this.updateCamera();
    },
    isPaused() { return !!UI.menu || !!this.dayTransition; },

    /* ---------------- 루프 ---------------- */
    loop(now) {
      let dt = (now - this.last) / 1000; this.last = now;
      if (dt > 0.1) dt = 0.1;
      this.update(dt);
      this.render();
      Input.endFrame();
      requestAnimationFrame((t) => this.loop(t));
    },

    update(dt) {
      UI.update(dt, this);
      if (this.warpFlash > 0) this.warpFlash = Math.max(0, this.warpFlash - dt);

      if (this.dayTransition) {
        this.dayTransition.t -= dt;
        if (this.dayTransition.t <= 0 || Input.justPressed(' ') || Input.justPressed('Enter') || Input.mouse.clicked) this.dayTransition = null;
        return;
      }
      if (UI.dialogue) {   // NPC 대화 중엔 월드 정지, 아무 키/클릭으로 닫기
        if (Input.justPressed('e') || Input.justPressed(' ') || Input.justPressed('Escape') || Input.mouse.clicked) UI.dialogue = null;
        return;
      }
      if (UI.menu) {
        if (Input.justPressed('Escape') || Input.justPressed('i') || Input.justPressed('b') || Input.justPressed('m')) {
          UI.closeMenu(this);
        }
        return;
      }

      // 핫바 선택
      for (let k = 1; k <= 9; k++) if (Input.justPressed('' + k)) { if (k - 1 < this.player.hotbar().length) this.player.selIndex = k - 1; }
      if (Input.justPressed('[')) this.player.cycleSel(-1);
      if (Input.justPressed(']')) this.player.cycleSel(1);

      // 메뉴 열기
      if (Input.justPressed('i')) { UI.menu = 'inventory'; return; }
      if (Input.justPressed('b')) { UI.menu = 'build'; return; }
      if (Input.justPressed('m')) { UI.menu = 'map'; return; }

      // 마우스로 4방향 조준 (스윙 중에는 방향 고정)
      this.updateAim();

      // 충전형 도구(괭이/물뿌리개): 마우스 누르는 동안 차징 → 이동 잠금
      const act = this.player.active();
      const chargeable = act && act.kind === 'tool' && (act.id === 'hoe' || act.id === 'can');
      this.player.charging = !!(chargeable && !this.player.isActing() && Input.mouse.down);

      // 이동 (행동/차징 중이면 내부에서 잠금)
      this.player.move(this.activeMap(), dt);
      for (const m of Object.values(this.maps)) m.updateNpcs(dt);

      // 행동 타격: 스윙 중간 지점에서 실제 효과 발생 (단일/광역/보충)
      if (this.pending) {
        const pl = this.player;
        if (!pl.isActing()) this.pending = null;
        else if (!this.pending.done && pl.actionT <= pl.actionDur * 0.5) { this.applyPending(); this.pending.done = true; }
      }

      // 입력: 도구는 마우스 클릭으로만. 충전형은 떼는 순간 광역 적용.
      if (!this.player.isActing()) {
        if (chargeable) {
          if (Input.mouse.down) this.player.chargeT += dt;
          else if (this.player.chargeT > 0) this.releaseCharge(act);
        } else {
          this.player.chargeT = 0;
          if (act && act.kind === 'tool') { if (Input.mouse.down) this.useActive(); }   // 도구: 누르면 휘두름(연타)
          else if (Input.mouse.clicked) this.useActive();                               // 씨앗/설치물: 클릭당 1회
        }
      }
      if (Input.justPressed('e') && !this.player.isActing()) this.interact();

      // 길 끝/문(워프 칸)에 들어서면 맵 전환 (스타듀식 경계/출입 전환)
      if (this.scene !== 'cave' && !this.player.isActing()) {
        const [cx, cy] = this.player.centerTile();
        const w = this.world.objAt(cx, cy);
        if (w && w.type === 'warp') {
          if (w.back) this.exitBuilding();
          else if (w.enter) this.enterBuilding(w.enter, cx, cy);
          else this.gotoMap(w.to, w.tx, w.ty);
          return;
        }
      }

      // 상점 점원 출근/퇴근 (영업시간에만 카운터에 있음)
      if (this.scene === 'shop_in') {
        const k = this.world.npcs.find((n) => n.role === 'keeper');
        if (k) k.hidden = !this.shopOpen();
      }

      // 시간 경과
      this.time += this.timeRate * dt;
      if (this.time >= 1560) this.sleep(true); // 새벽 2시 기절

      // 동굴 몬스터
      if (this.scene === 'cave') {
        this.cave.update(dt, this.player);
        if (this.player.hp <= 0) this.faint();
      }

      this.updateCamera();
    },

    // 마우스 위치 기준으로 캐릭터의 바라보는 방향(4방향)을 정함
    updateAim() {
      if (this.player.isActing()) return;          // 휘두르는 중엔 방향 고정
      const m = Input.mouse;
      const cx = this.player.x - this.cam.x + 8, cy = this.player.y - this.cam.y + 8;
      const dx = m.x - cx, dy = m.y - cy;
      if (Math.abs(dx) < 1 && Math.abs(dy) < 1) return;
      this.player.dir = Math.abs(dx) >= Math.abs(dy) ? (dx >= 0 ? 'right' : 'left') : (dy >= 0 ? 'down' : 'up');
    },

    updateCamera() {
      const map = this.activeMap();
      const mw = map.W * T, mh = map.H * T;
      this.cam.x = Math.max(0, Math.min(mw - this.IW, this.player.x + 8 - this.IW / 2));
      this.cam.y = Math.max(0, Math.min(mh - this.IH, this.player.y + 8 - this.IH / 2));
      if (mw < this.IW) this.cam.x = (mw - this.IW) / 2;
      if (mh < this.IH) this.cam.y = (mh - this.IH) / 2;
    },

    /* ---------------- 도구/아이템 사용 ---------------- */
    useActive() {
      const p = this.player, a = p.active();
      if (!a) return;
      const [fx, fy] = p.facingTile();

      if (a.kind === 'tool') {
        if (p.energy <= 0) { UI.toast('너무 지쳤어요. 잠을 자야 해요.', '#f88'); return; }
        // 휘두르기 시작 — 실제 효과는 스윙 중간(타격 시점)에 발생
        p.startAction(a.id, a.id === 'sword' ? 0.26 : 0.34);
        this.pending = { tool: a.id, fx, fy, done: false };
        return;
      }
      // 아이템(씨앗/설치물) — 즉시 실행 (현재 야외 맵 기준)
      if (this.scene === 'cave' || this.world.indoor) { UI.toast('여기선 심기/설치를 할 수 없어요.', '#fc8'); return; }
      if (a.id.endsWith('_seed')) {
        if (this.world.tileAt(fx, fy) === 'soil' && !this.world.objAt(fx, fy)) {
          const cropId = a.id.replace('_seed', '');
          const inSeason = this.world.plant(fx, fy, cropId, this.season);
          p.removeItem(a.id, 1);
          if (!inSeason) UI.toast('제철이 아니라 바로 시들었습니다.', '#f88');
        } else UI.toast('갈아 놓은 빈 밭에만 심을 수 있어요.', '#fc8');
      } else if (DATA.MACHINES[a.id]) {
        if (this.world.placeMachine(fx, fy, a.id)) { p.removeItem(a.id, 1); UI.toast(DATA.MACHINES[a.id].name + ' 설치 완료', '#cfe'); }
        else UI.toast('여기엔 설치할 수 없어요.', '#fc8');
      } else if (DATA.SPRINKLERS[a.id]) {
        if (this.world.placeSprinkler(fx, fy, a.id)) { p.removeItem(a.id, 1); UI.toast(DATA.SPRINKLERS[a.id].name + ' 설치 — 아침마다 자동 급수!', '#cfe'); }
        else UI.toast('여기엔 설치할 수 없어요.', '#fc8');
      } else if (DATA.BUILDINGS[a.id]) {
        if (this.world.placeBuilding(fx, fy, a.id)) {
          p.removeItem(a.id, 1);
          if (a.id === 'stable') { p.hasStable = true; UI.toast('마구간 건설! 이동 속도가 빨라집니다.', '#cfe'); }
          else UI.toast(DATA.BUILDINGS[a.id].name + ' 건설 완료', '#cfe');
        } else UI.toast('공간이 부족합니다 (' + DATA.BUILDINGS[a.id].size.join('x') + ' 빈 칸 필요).', '#fc8');
      }
    },

    /* ----- 차징(괭이/물뿌리개) ----- */
    chargeStage(toolId, ct) {
      const max = toolId === 'hoe' ? this.player.hoeLevel : this.player.canLevel;
      return Math.min(max, Math.floor((ct || 0) / 0.3)); // 0.3초마다 한 단계, 강화 단계가 상한
    },
    areaTiles(stage) {
      const [fx, fy] = this.player.facingTile();
      if (stage <= 0) return [[fx, fy]];
      if (stage === 1) {
        return (this.player.dir === 'up' || this.player.dir === 'down')
          ? [[fx - 1, fy], [fx, fy], [fx + 1, fy]] : [[fx, fy - 1], [fx, fy], [fx, fy + 1]];
      }
      const t = []; for (let y = fy - 1; y <= fy + 1; y++) for (let x = fx - 1; x <= fx + 1; x++) t.push([x, y]); return t;
    },
    releaseCharge(a) {
      const p = this.player, [fx, fy] = p.facingTile(), ct = p.chargeT; p.chargeT = 0;
      // 물뿌리개로 물(연못)을 바라보면 보충
      if (a.id === 'can' && this.world.tileAt(fx, fy) === 'water') { p.startAction('can', 0.3); this.pending = { tool: 'can', refill: true, done: false }; return; }
      if (p.energy <= 0) { UI.toast('너무 지쳤어요. 잠을 자야 해요.', '#f88'); return; }
      if (a.id === 'can' && p.canWater <= 0) { UI.toast('물이 없어요! 연못에서 채우세요.', '#fc8'); return; }
      p.startAction(a.id, 0.34);
      this.pending = { tool: a.id, tiles: this.areaTiles(this.chargeStage(a.id, ct)), done: false };
    },
    // 스윙 중간에 실제 효과 적용
    applyPending() {
      const pd = this.pending, p = this.player;
      if (pd.refill) { p.canWater = p.canMax; UI.toast('물을 가득 채웠어요.', '#cfe'); return; }
      if (pd.tiles) {
        if (pd.tool === 'can') {
          let empty = false;
          for (const [tx, ty] of pd.tiles) {
            if (p.canWater <= 0) { empty = true; break; }
            if (this.world.waterTile(tx, ty)) { p.canWater--; p.energy = Math.max(0, p.energy - 2); }
          }
          if (empty) UI.toast('물이 부족해요! 연못에서 채우세요.', '#fc8');
        } else for (const [tx, ty] of pd.tiles) this.useTool(pd.tool, tx, ty);
      } else this.useTool(pd.tool, pd.fx, pd.fy);
    },

    useTool(tool, fx, fy) {
      const p = this.player;
      if (this.scene === 'cave') {
        p.energy = Math.max(0, p.energy - 2);
        if (tool === 'hammer') {
          const res = this.cave.mineRock(fx, fy, DATA.HAMMER_UPGRADES[p.hammerLevel]);
          if (res && res.broken) { res.items.forEach((it) => p.addItem(it.id, it.qty)); this.dropToast(res.items); }
        } else if (tool === 'sword') {
          const res = this.cave.attack(p.x, p.y, p.dir, 2 + p.hammerLevel);
          if (res.items.length) { res.items.forEach((it) => p.addItem(it.id, it.qty)); this.dropToast(res.items); }
        }
        return;
      }
      // 물뿌리개: 물 보충 / 물 주기(잔량 소모)
      if (tool === 'can') {
        if (this.world.tileAt(fx, fy) === 'water') { p.canWater = p.canMax; UI.toast('물을 가득 채웠어요.', '#cfe'); return; }
        if (p.canWater <= 0) { UI.toast('물이 없어요! 연못에서 채우세요.', '#fc8'); return; }
        if (this.world.waterTile(fx, fy)) { p.canWater--; p.energy = Math.max(0, p.energy - 2); }
        return;
      }
      const COST = { hoe: 2, hammer: 2, scythe: 1, axe: 2 };
      p.energy = Math.max(0, p.energy - (COST[tool] || 1));
      switch (tool) {
        case 'hoe': this.world.till(fx, fy); break;
        case 'hammer': {
          const res = this.world.mineRock(fx, fy, DATA.HAMMER_UPGRADES[p.hammerLevel]);
          if (res && res.blocked) UI.toast('큰 돌이에요. 더 좋은 망치가 필요합니다.', '#fc8');
          else if (res && res.broken) { res.items.forEach((it) => p.addItem(it.id, it.qty)); this.dropToast(res.items); }
          break;
        }
        case 'scythe': {
          const o = this.world.objAt(fx, fy);
          if (o && o.type === 'crop' && o.dead) { this.world.removeObj(fx, fy); UI.toast('시든 작물을 정리했어요.', '#caa'); }
          else { const w = this.world.cutWeed(fx, fy); if (w) w.items.forEach((it) => p.addItem(it.id, it.qty)); }
          break;
        }
        case 'axe': { const c = this.world.chop(fx, fy); if (c) { c.items.forEach((it) => p.addItem(it.id, it.qty)); if (c.broken) this.dropToast(c.items); } break; }
        case 'sword': UI.toast('검은 동굴에서 사용하세요.', '#fc8'); break;
      }
    },

    dropToast(items) {
      const s = items.map((it) => DATA.displayName(it.id) + ' x' + it.qty).join(', ');
      if (s) UI.toast('+ ' + s, '#cfe');
    },

    /* ---------------- 상호작용(E) ---------------- */
    interact() {
      const p = this.player;
      const [fx, fy] = p.facingTile();
      const [cx, cy] = p.centerTile();
      // 정면 또는 발밑
      const m = this.activeMap();
      // NPC 대화 — 바라보는 칸에 주민이 있으면
      const fcx = fx * T + 8, fcy = fy * T + 8;
      for (const n of (m.npcs || [])) {
        if (n.hidden) continue;
        if (Math.abs((n.x + 8) - fcx) < 14 && Math.abs((n.y + 8) - fcy) < 14) { this.talkTo(n); return; }
      }
      for (const [x, y] of [[fx, fy], [cx, cy]]) {
        let o = m.objAt(x, y);
        if (o && o.type === 'occupied') o = m.objAt(o.anchor[0], o.anchor[1]);
        if (!o) continue;
        if (o.type === 'crop') {                          // 작물 수확(상호작용)
          if (o.dead) { UI.toast('시든 작물 — 낫으로 정리하세요.', '#caa'); return; }
          if (!o.ready) { UI.toast('아직 덜 자랐어요.', 'rgba(255,255,255,.7)'); return; }
          const h = this.world.harvest(x, y);
          if (h && h.items.length) { h.items.forEach((it) => p.addItem(it.id, it.qty)); this.dropToast(h.items); }
          return;
        }
        if (o.type === 'bed') { this.sleep(false); return; }
        if (o.type === 'counter') {                       // 상점 카운터
          if (this.shopOpen()) { UI.menu = 'shop'; UI.shopTab = 'buy'; }
          else UI.toast('영업 시간이 아닙니다 (오전 9시~오후 5시).', '#fc8');
          return;
        }
        if (o.type === 'bin') { UI.menu = 'shop'; UI.shopTab = 'sell'; return; }
        if (o.type === 'cave') { this.enterCave(); return; }
        if (o.type === 'machine') {                       // 가공: 완성품은 바로 수거, 비었으면 재료 투입
          if (o.job && o.job.ready) this.collectMachine(o);
          else if (o.job) UI.toast(DATA.displayName(o.job.id) + ' 가공 중... ' + o.job.daysLeft + '일 남음', '#caa');
          else { UI.machineTarget = o; UI.menu = 'machine'; }
          return;
        }
        if (o.type === 'building' && DATA.BUILDINGS[o.id]) {
          if (o.product) { p.addItem(o.product, 1); UI.toast('+ ' + DATA.displayName(o.product), '#cfe'); o.product = null; }
          else UI.toast(DATA.BUILDINGS[o.id].name + ': 오늘 산출물 없음 (자고 나면 생김).', '#caa');
          return;
        }
        if (o.type === 'exit') { this.exitCave(); return; }
        if (o.type === 'ladder') { this.descend(); return; }
      }
      UI.toast('상호작용할 대상이 없어요.', 'rgba(255,255,255,.6)');
    },

    /* ---------------- 시간/수면 ---------------- */
    sleep(passedOut) {
      this.day++;
      let seasonChanged = false;
      if (this.day > DATA.DAYS_PER_SEASON) {
        this.day = 1; this.seasonIdx = (this.seasonIdx + 1) % 4; seasonChanged = true;
        if (this.seasonIdx === 0) this.year++;
      }
      // 모든 야외 맵의 하루 처리(작물 성장·가공·산출물)
      for (const m of Object.values(this.maps)) m.newDay(this.season, seasonChanged);
      this.time = 360;
      this.player.energy = passedOut ? this.player.energyMax * 0.55 | 0 : this.player.energyMax;
      this.player.hp = this.player.hpMax;
      this.player.canWater = this.player.canMax;   // 아침엔 물뿌리개 가득
      this.player.chargeT = 0; this.player.charging = false;
      // 항상 농장 집(침대 옆)에서 기상
      this.scene = 'farm'; this.world = this.maps.farm;
      this.player.x = 6 * T; this.player.y = 7 * T; this.player.actionT = 0; this.pending = null;
      this.save();
      const title = passedOut ? '기절했다가 깨어났습니다...' : '잘 잤다!';
      this.dayTransition = {
        t: 1.6, title,
        line: DATA.SEASON_KO[this.season] + ' ' + this.day + '일 (' + this.year + '년차)',
      };
    },

    /* ---------------- 동굴 ---------------- */
    enterCave() {
      this.outReturn = { scene: this.scene, x: this.player.x, y: this.player.y };
      this.cave.gen(1);
      this.scene = 'cave';
      this.player.x = this.cave.entry.x; this.player.y = this.cave.entry.y;
      this.player.onHorse = false; this.player.actionT = 0; this.pending = null;
      const si = this.player.tools.indexOf('sword'); if (si >= 0) this.player.selIndex = si;
      UI.toast('동굴 1층. 망치로 채굴, 검으로 슬라임 처치!', '#cfe');
    },
    descend() {
      this.cave.gen(this.cave.depth + 1);
      this.player.x = this.cave.entry.x; this.player.y = this.cave.entry.y;
      UI.toast('동굴 ' + this.cave.depth + '층으로 내려갑니다.', '#cfe');
    },
    backFromCave() {
      const r = this.outReturn || { scene: 'mountain', x: 14 * T, y: 8 * T };
      this.scene = r.scene; this.world = this.maps[r.scene] || this.maps.mountain;
      this.player.x = r.x; this.player.y = r.y; this.player.actionT = 0; this.pending = null;
    },
    exitCave() { this.backFromCave(); UI.toast('동굴에서 나왔습니다.', '#cfe'); },
    faint() {
      const loss = Math.floor(this.player.money * 0.1);
      this.player.money -= loss;
      this.backFromCave();
      this.player.hp = this.player.hpMax;
      UI.toast('쓰러졌습니다! 돈 ' + loss + 'G를 잃고 밖으로 나왔습니다.', '#f88');
    },

    /* ---------------- 거래 ---------------- */
    buySeed(id, n) {
      const cost = DATA.CROPS[id].seed * n;
      if (this.player.money < cost) { UI.toast('소지금이 부족합니다.', '#f88'); return; }
      this.player.money -= cost; this.player.addItem(id + '_seed', n);
      UI.toast(DATA.CROPS[id].name + ' 씨앗 x' + n + ' 구매', '#cfe');
    },
    sellStack(stack, qty) {
      qty = Math.min(qty, stack.qty);
      const v = (stack.sell != null ? stack.sell : DATA.sellOf(stack.id)) * qty;
      this.player.removeStack(stack, qty);
      this.player.money += v;
      UI.toast('+' + v + 'G', '#ffe');
    },
    hasMaterials(mat) { return Object.entries(mat || {}).every(([k, v]) => this.player.countItem(k) >= v); },
    spendMaterials(mat) { Object.entries(mat || {}).forEach(([k, v]) => this.player.removeItem(k, v)); },
    buyBuildable(id, kind) {
      const d = kind === 'machine' ? DATA.MACHINES[id] : kind === 'sprinkler' ? DATA.SPRINKLERS[id] : DATA.BUILDINGS[id];
      if (this.player.money < d.price) { UI.toast('소지금이 부족합니다.', '#f88'); return; }
      if (!this.hasMaterials(d.mat)) { UI.toast('재료가 부족합니다.', '#f88'); return; }
      this.player.money -= d.price; this.spendMaterials(d.mat);
      this.player.addItem(id, 1);
      UI.toast(d.name + ' 구매! 핫바에서 선택 후 Space로 설치하세요.', '#cfe');
    },
    upgradeTool(kind) {
      const arr = { hammer: DATA.HAMMER_UPGRADES, hoe: DATA.HOE_UPGRADES, can: DATA.CAN_UPGRADES }[kind];
      const key = { hammer: 'hammerLevel', hoe: 'hoeLevel', can: 'canLevel' }[kind];
      if (!arr) return;
      const next = arr[this.player[key] + 1];
      if (!next) return;
      if (this.player.money < next.price) { UI.toast('소지금이 부족합니다.', '#f88'); return; }
      if (!this.hasMaterials(next.mat)) { UI.toast('재료가 부족합니다.', '#f88'); return; }
      this.player.money -= next.price; this.spendMaterials(next.mat);
      this.player[key]++;
      if (kind === 'can') { this.player.canMax = DATA.CAN_UPGRADES[this.player.canLevel].cap; this.player.canWater = this.player.canMax; }
      UI.toast(next.name + ' 강화 완료!', '#cfe');
    },
    loadMachine(o, stack) {
      const out = DATA.MACHINES[o.id].process(stack.id);
      if (!out) return;
      this.player.removeStack(stack, 1);
      o.job = { id: out.id, base: out.base, daysLeft: out.days, sell: out.sell, ready: false };
      UI.toast('가공 시작: ' + DATA.displayName(out.id) + ' (' + out.days + '일)', '#cfe');
    },
    collectMachine(o) {
      this.player.addItem(o.job.id, 1, { sell: o.job.sell, base: o.job.base });
      UI.toast('+ ' + (o.job.base ? DATA.displayName(o.job.base) + ' ' : '') + DATA.displayName(o.job.id), '#cfe');
      o.job = null;
    },

    /* ---------------- 저장/로드 ---------------- */
    serializeMap(m) {
      return { type: m.type, tiles: m.tiles, objects: Array.from(m.objects.entries()), watered: Array.from(m.watered), animals: m.animals, npcs: m.npcs };
    },
    restoreMap(d) {
      const m = new World(d.type);
      m.tiles = d.tiles; m.objects = new Map(d.objects); m.watered = new Set(d.watered); m.animals = d.animals || [];
      if (d.npcs) m.npcs = d.npcs;
      return m;
    },
    save() {
      try {
        // 실내/동굴에 있을 땐 야외 복귀 지점/맵을 저장(실내·동굴 상태는 영구 저장 안 함)
        const onOverworld = !!this.maps[this.scene];
        const r = onOverworld ? { scene: this.scene, x: this.player.x, y: this.player.y } : (this.outReturn || { scene: 'farm', x: 6 * T, y: 7 * T });
        const data = {
          time: this.time, day: this.day, seasonIdx: this.seasonIdx, year: this.year,
          scene: r.scene,
          player: {
            x: r.x, y: r.y, money: this.player.money,
            energy: this.player.energy, hammerLevel: this.player.hammerLevel,
            inventory: this.player.inventory, hasStable: this.player.hasStable,
          },
          maps: {
            farm: this.serializeMap(this.maps.farm),
            town: this.serializeMap(this.maps.town),
            mountain: this.serializeMap(this.maps.mountain),
          },
        };
        localStorage.setItem(SAVE_KEY, JSON.stringify(data));
        this.hasSave = true;
      } catch (e) { console.warn('save failed', e); }
    },
    load() {
      try {
        const data = JSON.parse(localStorage.getItem(SAVE_KEY));
        if (!data || !data.maps) { this.startNew(); return; }
        this.time = data.time; this.day = data.day; this.seasonIdx = data.seasonIdx; this.year = data.year;
        this.maps = {
          farm: this.restoreMap(data.maps.farm),
          town: this.restoreMap(data.maps.town),
          mountain: data.maps.mountain ? this.restoreMap(data.maps.mountain) : new World('mountain'),
        };
        this.interiors = { shop_in: new World('shop_in'), house_in: new World('house_in') };
        this.cave = new Cave();
        this.player = new Player(data.player.x, data.player.y);
        Object.assign(this.player, {
          money: data.player.money, energy: data.player.energy,
          hammerLevel: data.player.hammerLevel, inventory: data.player.inventory,
          hasStable: !!data.player.hasStable,
        });
        this.scene = this.maps[data.scene] ? data.scene : 'farm';
        this.world = this.maps[this.scene];
        this.started = true;
        UI.toast('불러왔습니다.', '#cfe');
      } catch (e) { console.warn('load failed', e); this.startNew(); }
    },

    /* ---------------- 렌더 ---------------- */
    render() {
      const ctx = this.ctx, S = this.S || 1;
      // 기기 해상도로 정수배 확대(좌표 변환). 픽셀/텍스트 모두 선명.
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
      ctx.setTransform(S, 0, 0, S, 0, 0);

      ctx.fillStyle = '#000'; ctx.fillRect(0, 0, this.IW, this.IH);

      if (this.scene === 'cave') this.cave.render(ctx, this.cam, this.time * 100);
      else this.world.render(ctx, this.cam, this.season, performance.now());

      // 타깃 칸 하이라이트(도구 들고 있을 때)
      if (!this.isPaused()) this.drawTargetHL(ctx);

      this.player.render(ctx, this.cam);

      // 가까운 NPC 이름표
      if (this.scene !== 'cave' && this.world.npcs) {
        const ptx = (this.player.x + 8) / T, pty = (this.player.y + 8) / T;
        for (const n of this.world.npcs) {
          if (n.hidden) continue;
          const ntx = (n.x + 8) / T, nty = (n.y + 8) / T;
          if (Math.abs(ntx - ptx) < 4.5 && Math.abs(nty - pty) < 4) {
            UI.textC(ctx, n.name, n.x + 8 - this.cam.x, n.y - 7 - this.cam.y, '#fff', 7);
          }
        }
      }

      // 밤이 되면 어둡게(야외 맵만 — 실내/동굴 제외)
      if (this.scene !== 'cave' && !this.world.indoor) {
        const t = this.time;
        let dark = 0;
        if (t > 1080) dark = Math.min(0.5, (t - 1080) / 600 * 0.5); // 18:00부터 점점
        if (dark > 0) { ctx.fillStyle = 'rgba(10,10,40,' + dark + ')'; ctx.fillRect(0, 0, this.IW, this.IH); }
      }

      UI.drawHUD(ctx, this);
      UI.render(ctx, this);
      if (UI.dialogue) UI.drawDialogue(ctx, this);

      if (this.dayTransition) this.drawDayTransition(ctx);
      // 맵 전환 페이드-인
      if (this.warpFlash > 0) { ctx.fillStyle = 'rgba(0,0,0,' + Math.min(0.85, this.warpFlash * 1.9) + ')'; ctx.fillRect(0, 0, this.IW, this.IH); }

      ctx.setTransform(1, 0, 0, 1, 0, 0);
    },

    drawTargetHL(ctx) {
      const a = this.player.active(), p = this.player;
      if (!a) return;
      const chargeable = a.kind === 'tool' && (a.id === 'hoe' || a.id === 'can');
      const tiles = (chargeable && p.charging) ? this.areaTiles(this.chargeStage(a.id, p.chargeT)) : [p.facingTile()];
      ctx.strokeStyle = 'rgba(255,255,255,.5)';
      for (const [tx, ty] of tiles) ctx.strokeRect(tx * T - this.cam.x + 0.5, ty * T - this.cam.y + 0.5, T - 1, T - 1);
      // 차징 게이지
      if (chargeable && p.charging) {
        const max = a.id === 'hoe' ? p.hoeLevel : p.canLevel;
        if (max > 0) {
          const sx = p.x - this.cam.x, sy = p.y - this.cam.y;
          Sprites.rect(ctx, sx, sy - 6, 16, 3, 'rgba(0,0,0,.55)');
          Sprites.rect(ctx, sx + 1, sy - 5, Math.round(14 * (this.chargeStage(a.id, p.chargeT) / max)), 1, '#ffe04a');
        }
      }
    },

    drawDayTransition(ctx) {
      const a = Math.min(0.85, this.dayTransition.t);
      ctx.fillStyle = 'rgba(0,0,0,' + a + ')'; ctx.fillRect(0, 0, this.IW, this.IH);
      UI.textC(ctx, this.dayTransition.title, this.IW / 2, this.IH / 2 - 14, '#ffe', 14);
      UI.textC(ctx, this.dayTransition.line, this.IW / 2, this.IH / 2 + 6, '#cfe', 10);
    },
  };

  window.Game = Game;
  window.addEventListener('load', () => Game.init());
})();
