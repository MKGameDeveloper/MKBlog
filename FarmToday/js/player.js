/* ============================================================
 * player.js — 플레이어: 이동, 애니메이션, 인벤토리, 핫바
 * ============================================================ */
(function () {
  'use strict';
  const T = 16;

  function Player(x, y) {
    this.x = x; this.y = y;     // 스프라이트 좌상단(px)
    this.dir = 'down';
    this.moving = false;
    this.walkT = 0; this.frame = 0;
    this.speed = 64;            // px/초
    this.energyMax = 200; this.energy = 200;
    this.hpMax = 100; this.hp = 100;
    this.money = 800;

    this.tools = ['hoe', 'can', 'hammer', 'scythe', 'axe', 'sword'];
    this.hammerLevel = 0; this.hoeLevel = 0; this.canLevel = 0; // 강화 단계
    this.canMax = DATA.CAN_UPGRADES[0].cap; this.canWater = this.canMax; // 물뿌리개 물 잔량
    this.charging = false; this.chargeT = 0;                   // 차징 상태
    this.inventory = [];        // [{id, qty, sell?, base?}]
    this.onHorse = false;
    this.hasStable = false;     // 마구간 보유 시 이동 속도 증가

    this.selIndex = 0;          // hotbar() 상의 선택 인덱스
    // 행동(도구질) 상태: 진행 중엔 이동 잠금
    this.actionTool = null;
    this.actionDur = 0;
    this.actionT = 0;           // 남은 시간

    // 시작 아이템
    this.addItem('parsnip_seed', 15);
    this.addItem('potato_seed', 5);
    this.addItem('wood', 50);
    this.addItem('stone', 20);
  }

  /* ---------- 인벤토리 ---------- */
  Player.prototype.addItem = function (id, qty, opts) {
    opts = opts || {};
    const sell = opts.sell;
    const found = this.inventory.find((s) => s.id === id && s.sell === sell && s.base === opts.base);
    if (found) found.qty += qty;
    else this.inventory.push({ id, qty, sell, base: opts.base });
  };
  Player.prototype.countItem = function (id) {
    return this.inventory.filter((s) => s.id === id).reduce((a, s) => a + s.qty, 0);
  };
  Player.prototype.removeItem = function (id, qty) {
    let need = qty;
    for (const s of this.inventory) {
      if (s.id !== id) continue;
      const take = Math.min(s.qty, need);
      s.qty -= take; need -= take;
      if (need <= 0) break;
    }
    this.inventory = this.inventory.filter((s) => s.qty > 0);
    return need <= 0;
  };
  Player.prototype.removeStack = function (stack, qty) {
    stack.qty -= qty;
    if (stack.qty <= 0) this.inventory = this.inventory.filter((s) => s.qty > 0);
  };

  // "사용 가능한" 인벤토리 아이템(씨앗/설치물)만 핫바에 노출
  Player.prototype.usableItems = function () {
    return this.inventory.filter((s) =>
      s.id.endsWith('_seed') || DATA.MACHINES[s.id] || DATA.BUILDINGS[s.id] || DATA.SPRINKLERS[s.id]
    );
  };
  // 핫바 = 도구 6 + 사용가능 아이템들
  Player.prototype.hotbar = function () {
    const list = this.tools.map((t) => ({ kind: 'tool', id: t }));
    for (const s of this.usableItems()) list.push({ kind: 'item', id: s.id, qty: s.qty });
    return list;
  };
  Player.prototype.active = function () {
    const hb = this.hotbar();
    if (this.selIndex >= hb.length) this.selIndex = hb.length - 1;
    if (this.selIndex < 0) this.selIndex = 0;
    return hb[this.selIndex];
  };
  Player.prototype.cycleSel = function (d) {
    const n = this.hotbar().length;
    this.selIndex = ((this.selIndex + d) % n + n) % n;
  };

  /* ---------- 위치/방향 ---------- */
  Player.prototype.centerTile = function () {
    return [((this.x + 8) / T) | 0, ((this.y + 12) / T) | 0];
  };
  Player.prototype.facingTile = function () {
    const [cx, cy] = this.centerTile();
    if (this.dir === 'up') return [cx, cy - 1];
    if (this.dir === 'down') return [cx, cy + 1];
    if (this.dir === 'left') return [cx - 1, cy];
    return [cx + 1, cy];
  };

  /* ---------- 행동(도구질) ---------- */
  Player.prototype.startAction = function (tool, dur) {
    this.actionTool = tool; this.actionDur = dur || 0.34; this.actionT = this.actionDur;
    this.moving = false; this.frame = 0;
  };
  Player.prototype.isActing = function () { return this.actionT > 0; };

  /* ---------- 이동 ---------- */
  Player.prototype.move = function (world, dt) {
    // 휘두르는 동안(스윙)에만 제자리 정지
    if (this.actionT > 0) {
      this.actionT -= dt;
      if (this.actionT <= 0) { this.actionT = 0; this.actionTool = null; }
      this.moving = false;
      return;
    }

    // 이동은 WASD만 (방향은 마우스 조준이 결정 — game.updateAim)
    let dx = 0, dy = 0;
    if (Input.isDown('w')) dy = -1; else if (Input.isDown('s')) dy = 1;
    if (Input.isDown('a')) dx = -1; else if (Input.isDown('d')) dx = 1;

    this.moving = !!(dx || dy);
    if (this.moving) {
      let base = this.hasStable ? 100 : this.speed;
      if (this.charging) base *= 0.5;   // 도구를 들고 클릭을 누른 채 차징 중이면 절반 속도
      const sp = (this.onHorse ? base * 1.9 : base) * dt;
      const len = Math.hypot(dx, dy) || 1;
      this.tryMove(world, (dx / len) * sp, 0);
      this.tryMove(world, 0, (dy / len) * sp);
      this.walkT += dt;
      if (this.walkT > 0.18) { this.walkT = 0; this.frame ^= 1; }
    } else { this.frame = 0; }
  };

  Player.prototype.tryMove = function (world, vx, vy) {
    const nx = this.x + vx, ny = this.y + vy;
    // 발 히트박스
    const fx = nx + 3, fy = ny + 11, fw = 10, fh = 4;
    const corners = [
      [fx, fy], [fx + fw, fy], [fx, fy + fh], [fx + fw, fy + fh],
    ];
    for (const [px, py] of corners) {
      if (world.isSolid((px / T) | 0, (py / T) | 0)) return;
    }
    this.x = nx; this.y = ny;
  };

  Player.prototype.render = function (ctx, cam) {
    const sx = this.x - cam.x, sy = this.y - cam.y;
    let action = null;
    if (this.actionT > 0 && this.actionTool) {
      action = { tool: this.actionTool, prog: 1 - this.actionT / this.actionDur, dir: this.dir };
    }
    Sprites.player(ctx, sx, sy, this.dir, this.moving ? this.frame : 0, this.onHorse, action);
  };

  window.Player = Player;
})();
