/* ============================================================
 * cave.js — 동굴: 광물 채굴 + 몬스터(슬라임) 전투
 * 농장과 별도의 그리드. 깊이(depth)가 깊을수록 좋은 광물.
 * ============================================================ */
(function () {
  'use strict';
  const T = 16;

  function Cave() {
    this.W = 32; this.H = 22;
    this.depth = 0;
    this.tiles = [];
    this.objects = new Map();
    this.monsters = [];
    this.entry = { x: 2 * T, y: 2 * T };
  }

  Cave.prototype.key = function (x, y) { return x + ',' + y; };
  Cave.prototype.inB = function (x, y) { return x >= 0 && y >= 0 && x < this.W && y < this.H; };
  Cave.prototype.objAt = function (x, y) { return this.objects.get(this.key(x, y)) || null; };

  Cave.prototype.gen = function (depth) {
    this.depth = depth;
    this.objects.clear();
    this.monsters = [];
    this.tiles = [];
    for (let y = 0; y < this.H; y++) {
      this.tiles[y] = [];
      for (let x = 0; x < this.W; x++) {
        const wall = x === 0 || y === 0 || x === this.W - 1 || y === this.H - 1;
        this.tiles[y][x] = wall ? 'wall' : 'floor';
        if (wall) this.objects.set(this.key(x, y), { type: 'wall' });
      }
    }
    // 출구(위로) — 입구 자리
    this.objects.set(this.key(2, 2), { type: 'exit' });
    this.entry = { x: 2 * T, y: 3 * T };

    // 광맥 바위
    const rocks = 30 + depth * 4;
    for (let i = 0; i < rocks; i++) {
      const x = 1 + ((Math.random() * (this.W - 2)) | 0);
      const y = 1 + ((Math.random() * (this.H - 2)) | 0);
      if (this.objAt(x, y) || (x <= 3 && y <= 3)) continue;
      this.objects.set(this.key(x, y), { type: 'rock', hp: 2 + ((depth / 3) | 0) });
    }
    // 다음 층 사다리
    for (let tries = 0; tries < 50; tries++) {
      const x = 3 + ((Math.random() * (this.W - 6)) | 0);
      const y = 3 + ((Math.random() * (this.H - 6)) | 0);
      if (!this.objAt(x, y)) { this.objects.set(this.key(x, y), { type: 'ladder' }); break; }
    }
    // 슬라임
    const mob = 2 + ((depth / 2) | 0);
    for (let i = 0; i < mob; i++) {
      const x = 4 + ((Math.random() * (this.W - 8)) | 0);
      const y = 4 + ((Math.random() * (this.H - 8)) | 0);
      this.monsters.push({ x: x * T, y: y * T, hp: 3 + depth, hurtT: 0, contactCd: 0 });
    }
  };

  Cave.prototype.isSolid = function (x, y) {
    if (!this.inB(x, y)) return true;
    const o = this.objAt(x, y);
    return !!o && (o.type === 'wall' || o.type === 'rock');
  };

  // 깊이에 따른 광물 드롭 테이블
  Cave.prototype.rollDrop = function () {
    const d = this.depth, r = Math.random();
    const drops = [{ id: 'stone', qty: 1 + ((Math.random() * 2) | 0) }];
    if (r < 0.04 + d * 0.004) drops.push({ id: 'diamond', qty: 1 });
    else if (r < 0.10 + d * 0.01) drops.push({ id: 'emerald', qty: 1 });
    else if (r < 0.20) drops.push({ id: 'quartz', qty: 1 });
    if (Math.random() < 0.30) drops.push({ id: 'coal', qty: 1 });
    // 금속: 깊이별
    const m = Math.random();
    if (d >= 8 && m < 0.25) drops.push({ id: 'gold', qty: 1 });
    else if (d >= 4 && m < 0.4) drops.push({ id: 'iron', qty: 1 });
    else if (m < 0.5) drops.push({ id: 'copper', qty: 1 });
    return drops;
  };

  Cave.prototype.mineRock = function (x, y, hammer) {
    const o = this.objAt(x, y);
    if (!o || o.type !== 'rock') return null;
    o.hp -= hammer.power;
    if (o.hp <= 0) {
      this.objects.delete(this.key(x, y));
      // 가끔 추가 사다리 노출
      if (Math.random() < 0.08) this.objects.set(this.key(x, y), { type: 'ladder' });
      return { broken: true, items: this.rollDrop() };
    }
    return { hit: true };
  };

  // 검 공격: 플레이어 정면 범위의 몬스터에 데미지
  Cave.prototype.attack = function (px, py, dir, power) {
    const cx = px + 8, cy = py + 12;
    const ax = cx + (dir === 'left' ? -14 : dir === 'right' ? 14 : 0);
    const ay = cy + (dir === 'up' ? -14 : dir === 'down' ? 14 : 0);
    let hitAny = false;
    const loot = [];
    for (const m of this.monsters) {
      if (m.hp <= 0) continue;
      const mx = m.x + 8, my = m.y + 10;
      if (Math.abs(mx - ax) < 14 && Math.abs(my - ay) < 14) {
        m.hp -= power; m.hurtT = 0.2; hitAny = true;
        // 넉백
        m.x += (dir === 'left' ? -6 : dir === 'right' ? 6 : 0);
        m.y += (dir === 'up' ? -6 : dir === 'down' ? 6 : 0);
        if (m.hp <= 0) {
          loot.push({ id: 'slimeball', qty: 1 });
          if (Math.random() < 0.4) loot.push({ id: 'coal', qty: 1 });
          if (Math.random() < 0.2) loot.push({ id: 'copper', qty: 1 });
        }
      }
    }
    this.monsters = this.monsters.filter((m) => m.hp > 0);
    return { hit: hitAny, items: loot };
  };

  // 몬스터 AI + 플레이어 접촉 데미지
  Cave.prototype.update = function (dt, player) {
    for (const m of this.monsters) {
      if (m.hurtT > 0) { m.hurtT -= dt; continue; }
      if (m.contactCd > 0) m.contactCd -= dt;
      const dx = (player.x - m.x), dy = (player.y - m.y);
      const dist = Math.hypot(dx, dy) || 1;
      if (dist < 110) {
        const sp = 26 * dt;
        const nx = m.x + (dx / dist) * sp, ny = m.y + (dy / dist) * sp;
        if (!this.isSolid(((nx + 8) / T) | 0, ((ny + 10) / T) | 0)) { m.x = nx; m.y = ny; }
      }
      // 접촉 데미지
      if (dist < 12 && m.contactCd <= 0) {
        player.hp = Math.max(0, player.hp - (3 + (this.depth / 3 | 0)));
        m.contactCd = 1.0;
      }
    }
  };

  Cave.prototype.render = function (ctx, cam, time) {
    // 어두운 배경
    Sprites.rect(ctx, 0, 0, cam.vw, cam.vh, '#15131a');
    const x0 = Math.max(0, (cam.x / T | 0) - 1), y0 = Math.max(0, (cam.y / T | 0) - 1);
    const x1 = Math.min(this.W, x0 + (cam.vw / T | 0) + 3);
    const y1 = Math.min(this.H, y0 + (cam.vh / T | 0) + 3);
    for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) {
      const sx = x * T - cam.x, sy = y * T - cam.y;
      if (this.tiles[y][x] === 'wall') Sprites.rect(ctx, sx, sy, T, T, '#2a2630');
      else Sprites.floor(ctx, sx, sy);
    }
    for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) {
      const o = this.objAt(x, y); if (!o) continue;
      const sx = x * T - cam.x, sy = y * T - cam.y;
      if (o.type === 'rock') Sprites.oreRock(ctx, sx, sy, '#caa040');
      else if (o.type === 'ladder') { Sprites.rect(ctx, sx + 5, sy + 2, 6, 12, '#caa86a'); for (let i = 0; i < 4; i++) Sprites.rect(ctx, sx + 5, sy + 3 + i * 3, 6, 1, '#7a5a3a'); }
      else if (o.type === 'exit') { Sprites.rect(ctx, sx + 3, sy + 2, 10, 12, '#3a8a4a'); Sprites.rect(ctx, sx + 6, sy + 4, 4, 8, '#cfe'); }
    }
    for (const m of this.monsters) Sprites.slime(ctx, m.x - cam.x, m.y - cam.y, time + m.x);
  };

  window.Cave = Cave;
})();
