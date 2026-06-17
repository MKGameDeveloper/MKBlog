/* =========================================================================
 * game.js — 메인 루프 / 입력 / 모드 전환 / 초기화
 * ========================================================================= */
const Input = { x: 0, y: 0, attackEdge: false, attackAimed: false, interactEdge: false, sprint: false };
const _keys = {};
const _dpad = { up:false, down:false, left:false, right:false };

const Game = {
  canvas: null, ctx: null, dpr: 1,
  view: { w: 0, h: 0 },
  last: 0, dt: 0,
  _hudT: 0,
  _startBlock: false,          // 시작 특성 선택 동안만 정지(그 외 메뉴는 게임 계속 진행)

  init() {
    this.canvas = document.getElementById('scene');
    this.ctx = this.canvas.getContext('2d');
    UI.init();
    this._bindInput();
    this._bindUI();
    window.addEventListener('resize', () => this.resize());
    this.resize();

    const loaded = State.load();
    if (!loaded) { state = State.fresh(); }
    state.stranded = state.stranded || false;
    Train.enter();
    UI.refresh();

    if (state.over) UI.showGameOver('crew');
    else if (!loaded) { this._startBlock = true; UI.showTraitSelect(); }

    requestAnimationFrame((t) => this.loop(t));
  },

  resize() {
    const rect = this.canvas.getBoundingClientRect();
    this.dpr = Math.min(window.devicePixelRatio || 1, 2);
    this.view.w = rect.width; this.view.h = rect.height;
    this.canvas.width = Math.round(rect.width * this.dpr);
    this.canvas.height = Math.round(rect.height * this.dpr);
    this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
  },

  // 정지: 시작 특성 선택 / 게임오버 일 때만. (일반 메뉴는 게임이 계속 진행됨)
  get paused() { return state.over || this._startBlock; },

  loop(ts) {
    const dt = Math.min(0.05, (ts - this.last) / 1000 || 0);
    this.last = ts; this.dt = dt;

    // 메뉴(모달)가 열려 있으면 게임은 계속 돌되, 뒤에서 캐릭터가 움직이지 않도록 입력만 차단
    const modalOpen = !document.getElementById('modal').classList.contains('hidden');
    if (modalOpen) { Input.x = 0; Input.y = 0; Input.attackEdge = false; Input.interactEdge = false; }
    else {
      Input.x = (_keys.right||_dpad.right?1:0) - (_keys.left||_dpad.left?1:0);
      Input.y = (_keys.down||_dpad.down?1:0) - (_keys.up||_dpad.up?1:0);
    }

    // 약탈/적재 인벤토리 창이 열려 있으면 탐험을 잠시 멈춤(가만히 물건을 정리)
    if (!this.paused && !UI._lootOpen) {
      State.tickWeather(dt);                                 // 날씨(전역) — 맑음/비/폭염 전환
      if (state.mode === 'train') Train.update(dt);
      else Explore.update(dt);
    }
    Input.attackEdge = false; Input.interactEdge = false;   // 소비되지 않은 입력이 다음 프레임으로 새지 않도록

    // 렌더
    const { w, h } = this.view;
    if (state.mode === 'train') Train.render(this.ctx, w, h);
    else Explore.render(this.ctx, w, h);

    // HUD는 5fps로 갱신(텍스트 깜빡임 방지)
    this._hudT += dt;
    if (this._hudT > 0.2) { this._hudT = 0; UI.refresh(); }

    requestAnimationFrame((t) => this.loop(t));
  },

  gameOver(reason) {
    state.over = true; state.running = false;
    UI.setExploreUI(false);
    UI.showGameOver(reason);
    State.save();
  },

  _showStart() {
    UI.openModal('🚂 좀비 트레인', `
      <p class="muted">끝없는 선로를 달리는 기차에서 살아남으세요.
        식량·연료·체력·기차 내구도를 관리하고, 도시를 탐험해 물자를 모으고,
        생존자를 구출해 동료로 삼으세요.</p>
      <p class="muted">조작: <b>◀▶▲▼</b> 이동 · <b>E</b> 상호작용(가구 약탈) · <b>클릭</b> 공격(부채꼴) · 하단 메뉴로 관리</p>
      <button class="big danger" onclick="UI.closeModal()">▶ 여정 시작</button>`);
  },

  // ---- 입력 바인딩 ----
  _bindInput() {
    const map = {
      ArrowLeft:'left', a:'left', A:'left',
      ArrowRight:'right', d:'right', D:'right',
      ArrowUp:'up', w:'up', W:'up',
      ArrowDown:'down', s:'down', S:'down',
    };
    window.addEventListener('keydown', (e) => {
      if (map[e.key]) { _keys[map[e.key]] = true; e.preventDefault(); }
      if (e.key===' ' || e.key==='Enter') { if (!this.paused) { Input.attackEdge = true; Input.attackAimed = false; } e.preventDefault(); }   // 공격(바라보는 방향)
      if (e.key==='e' || e.key==='E') { if (!this.paused) Input.interactEdge = true; e.preventDefault(); }      // 상호작용
      if (e.key==='Shift') Input.sprint = true;
      if (e.key==='Escape') UI.closeModal();
    });
    window.addEventListener('keyup', (e) => { if (map[e.key]) _keys[map[e.key]] = false; if (e.key==='Shift') Input.sprint = false; });
    window.addEventListener('blur', () => { Input.sprint = false; _keys.left=_keys.right=_keys.up=_keys.down=false; });

    // 캔버스 클릭/마우스 — 탐험 중 클릭한 지점으로 부채꼴 공격, 마우스 이동으로 조준선 표시
    const cv = this.canvas;
    cv.addEventListener('pointermove', (e) => { if (state.mode==='explore') Explore.setAim(e.clientX, e.clientY); });
    cv.addEventListener('pointerdown', (e) => { if (this.paused || state.mode!=='explore') return;
      Explore.setAim(e.clientX, e.clientY); Input.attackEdge = true; Input.attackAimed = true; e.preventDefault(); });

    // 온스크린 D-pad
    U.$all('#dpad button').forEach((b) => {
      const dir = b.dataset.dir;
      const on = (e) => { _dpad[dir] = true; e.preventDefault(); };
      const off = (e) => { _dpad[dir] = false; e.preventDefault(); };
      b.addEventListener('pointerdown', on);
      b.addEventListener('pointerup', off);
      b.addEventListener('pointerleave', off);
      b.addEventListener('pointercancel', off);
    });
    // 액션 버튼 (공격 / 상호작용 분리) — ⚔️ 버튼은 바라보는 방향으로 공격(모바일용)
    const atk = document.getElementById('attack-btn');
    if (atk) atk.addEventListener('pointerdown', (e) => { if (!this.paused) { Input.attackEdge = true; Input.attackAimed = false; } e.preventDefault(); e.stopPropagation(); });
    const itx = document.getElementById('interact-btn');
    if (itx) itx.addEventListener('pointerdown', (e) => { if (!this.paused) Input.interactEdge = true; e.preventDefault(); });
  },

  _bindUI() {
    const panels = {
      cab: () => UI.openCab(), repair: () => UI.openRepair(), addcar: () => UI.openAddCar(),
      roster: () => UI.openRoster(), farm: () => UI.openFarm(), help: () => UI.openHelp(),
      map: () => UI.openMap(), craft: () => UI.openCraft(),
    };
    U.$all('#nav button[data-panel]').forEach((b) => {
      b.onclick = () => { const f = panels[b.dataset.panel]; if (f) f(); };
    });
    document.getElementById('newgame-btn').onclick = () => {
      if (confirm('새 게임을 시작할까요? 현재 진행은 사라집니다.')) Actions.newGame();
    };
  },
};

window.addEventListener('DOMContentLoaded', () => Game.init());
