/* ============================================================
 * ui.js — HUD, 핫바, 상점/건설/가방 메뉴, 알림(토스트)
 * 저해상도 캔버스에 직접 그리며, 마우스 클릭으로 메뉴 조작.
 * ============================================================ */
(function () {
  'use strict';

  const UI = {
    menu: null,            // null|'shop'|'build'|'inventory'|'machine'|'title'|'help'|'map'
    dialogue: null,        // { id, line } — NPC 대화창
    shopTab: 'buy',
    toasts: [],
    machineTarget: null,   // 가공 메뉴 대상 기계 오브젝트

    toast(text, color) { this.toasts.push({ text, t: 2.6, color: color || '#fff' }); if (this.toasts.length > 5) this.toasts.shift(); },

    // 메뉴 닫기: 게임이 아직 시작 안 됐으면 타이틀로 복귀
    closeMenu(game) { this.menu = game.started ? null : 'title'; },

    text(ctx, s, x, y, color, size) {
      ctx.font = (size || 8) + 'px "Courier New", monospace';
      ctx.textBaseline = 'top';
      ctx.fillStyle = color || '#fff';
      ctx.fillText(s, x, y);
    },
    textC(ctx, s, cx, y, color, size) {
      ctx.font = (size || 8) + 'px "Courier New", monospace';
      const w = ctx.measureText(s).width;
      this.text(ctx, s, cx - w / 2, y, color, size);
    },

    _btn(ctx, x, y, w, h, label, enabled) {
      const m = Input.mouse;
      const hover = m.x >= x && m.x <= x + w && m.y >= y && m.y <= y + h;
      const on = enabled !== false;
      ctx.fillStyle = !on ? '#3a3a44' : hover ? '#6a8a5a' : '#4a6a4a';
      ctx.fillRect(x, y, w, h);
      ctx.strokeStyle = '#222'; ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
      this.textC(ctx, label, x + w / 2, y + (h - 8) / 2, on ? '#fff' : '#888', 8);
      const clicked = hover && m.clicked && on;
      if (clicked) Input.mouse.clicked = false;
      return clicked;
    },

    // 아이템/도구 아이콘
    icon(ctx, x, y, entry) {
      const id = entry.id;
      if (entry.kind === 'tool') {
        const map = { hoe: '#9a6a3a', can: '#7aa0c0', hammer: '#8a8a90', scythe: '#b0b0b0', axe: '#7a6a5a', sword: '#cdd6e0' };
        Sprites.rect(ctx, x + 2, y + 2, 12, 12, map[id] || '#999');
        const lbl = { hoe: '괭', can: '물', hammer: '망', scythe: '낫', axe: '도', sword: '검' }[id] || '?';
        this.textC(ctx, lbl, x + 8, y + 4, '#000', 8);
        return;
      }
      const tint = DATA.tintOf(id);
      Sprites.rect(ctx, x + 3, y + 3, 10, 10, tint);
      if (id.endsWith('_seed')) { Sprites.rect(ctx, x + 5, y + 9, 6, 4, '#7a5a3a'); }
    },

    /* ---------------- HUD ---------------- */
    drawHUD(ctx, game) {
      const p = game.player, W = game.IW;
      // 돈
      Sprites.rect(ctx, 4, 4, 64, 13, 'rgba(0,0,0,.5)');
      Sprites.rect(ctx, 7, 7, 7, 7, '#e8c84a');
      this.text(ctx, game.player.money + 'G', 18, 6, '#ffe', 8);

      // 물뿌리개 선택 시 물 잔량 표시
      const act = p.active();
      if (act && act.kind === 'tool' && act.id === 'can') {
        Sprites.rect(ctx, 4, 19, 66, 11, 'rgba(0,0,0,.5)');
        Sprites.rect(ctx, 7, 22, 5, 5, p.canWater > 0 ? '#5aa6e0' : '#5a5a5a');
        this.text(ctx, '물 ' + p.canWater + '/' + p.canMax, 15, 20, p.canWater > 0 ? '#bfe6f2' : '#f88', 8);
      }

      // 날짜/시간
      const dateStr = DATA.SEASON_KO[game.season] + ' ' + game.day + '일 · ' + game.year + '년차';
      const tw = ctx.measureText(dateStr).width;
      Sprites.rect(ctx, W - 96, 4, 92, 24, 'rgba(0,0,0,.5)');
      this.text(ctx, dateStr, W - 92, 6, '#fff', 8);
      this.text(ctx, this.clockStr(game.time), W - 92, 16, game.time > 1320 ? '#f5a25a' : '#cfe', 8);

      // 에너지/체력 바
      this.bar(ctx, W - 12, 32, 8, 60, p.energy / p.energyMax, '#6ad06a', '에너지');
      if (game.scene === 'cave') this.bar(ctx, W - 24, 32, 8, 60, p.hp / p.hpMax, '#e05a5a', '체력');

      this.drawHotbar(ctx, game);
      this.drawToasts(ctx, game);

      // 힌트
      this.text(ctx, 'WASD:이동  마우스:조준  클릭:도구(길게=차징)  E:수확/상호작용  1~9:핫바  I/B/M', 4, game.IH - 9, 'rgba(255,255,255,.6)', 7);
    },

    bar(ctx, x, y, w, h, frac, color, label) {
      Sprites.rect(ctx, x, y, w, h, 'rgba(0,0,0,.5)');
      const fh = Math.max(0, (h - 2) * frac) | 0;
      Sprites.rect(ctx, x + 1, y + 1 + (h - 2 - fh), w - 2, fh, color);
    },

    drawHotbar(ctx, game) {
      const p = game.player, hb = p.hotbar();
      const n = Math.min(hb.length, 12);
      const slot = 18, gap = 1, total = n * (slot + gap);
      const x0 = (game.IW - total) / 2 | 0, y0 = game.IH - slot - 12;
      for (let i = 0; i < n; i++) {
        const x = x0 + i * (slot + gap);
        const sel = i === p.selIndex;
        Sprites.rect(ctx, x, y0, slot, slot, sel ? 'rgba(255,240,160,.95)' : 'rgba(0,0,0,.55)');
        ctx.strokeStyle = sel ? '#fff' : '#000'; ctx.strokeRect(x + 0.5, y0 + 0.5, slot - 1, slot - 1);
        this.icon(ctx, x + 1, y0 + 1, hb[i]);
        if (hb[i].kind === 'item') this.text(ctx, '' + hb[i].qty, x + 2, y0 + slot - 9, '#fff', 7);
        if (i < 9) this.text(ctx, '' + (i + 1), x + 1, y0 - 8, 'rgba(255,255,255,.7)', 7);
      }
      // 선택 이름
      const a = p.active();
      if (a) {
        const nm = a.kind === 'tool' ? DATA.TOOLS[a.id].name + (a.id === 'hammer' ? ' (' + DATA.HAMMER_UPGRADES[p.hammerLevel].name + ')' : '') : DATA.displayName(a.id);
        this.textC(ctx, nm, game.IW / 2, y0 - 9, '#ffe', 8);
      }
    },

    drawToasts(ctx, game) {
      let y = 30;
      for (const t of this.toasts) {
        const alpha = Math.min(1, t.t);
        ctx.globalAlpha = alpha;
        this.textC(ctx, t.text, game.IW / 2, y, t.color, 8);
        ctx.globalAlpha = 1;
        y += 11;
      }
    },

    clockStr(min) {
      const total = Math.floor(min / 10) * 10;   // 스타듀처럼 10분 단위 표기 (hh:mm)
      let h = (total / 60) | 0, m = total % 60;
      const ampm = h < 12 || h >= 24 ? '오전' : '오후';
      let hh = h % 12; if (hh === 0) hh = 12;
      return ampm + ' ' + hh + ':' + (m < 10 ? '0' + m : m);
    },

    update(dt, game) {
      for (const t of this.toasts) t.t -= dt;
      this.toasts = this.toasts.filter((t) => t.t > 0);
    },

    /* ---------------- 메뉴 렌더 + 조작 ---------------- */
    render(ctx, game) {
      if (!this.menu) return;
      // 어둡게
      Sprites.rect(ctx, 0, 0, game.IW, game.IH, 'rgba(0,0,0,.55)');
      if (this.menu === 'title') return this.drawTitle(ctx, game);
      if (this.menu === 'help') return this.drawHelp(ctx, game);
      if (this.menu === 'shop') return this.drawShop(ctx, game);
      if (this.menu === 'build') return this.drawBuild(ctx, game);
      if (this.menu === 'inventory') return this.drawInventory(ctx, game);
      if (this.menu === 'machine') return this.drawMachine(ctx, game);
      if (this.menu === 'map') return this.drawMap(ctx, game);
    },

    panel(ctx, game, title) {
      const x = 20, y = 18, w = game.IW - 40, h = game.IH - 36;
      Sprites.rect(ctx, x, y, w, h, '#cdb89a');
      Sprites.rect(ctx, x, y, w, 14, '#8a6a44');
      ctx.strokeStyle = '#5a4426'; ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
      this.text(ctx, title, x + 6, y + 3, '#fff', 8);
      if (this._btn(ctx, x + w - 16, y + 2, 12, 10, 'X')) this.closeMenu(game);
      return { x, y, w, h };
    },

    drawTitle(ctx, game) {
      this.textC(ctx, '🌾 FARM TODAY', game.IW / 2, 60, '#ffe', 20);
      this.textC(ctx, '스타듀밸리 스타일 농장 게임', game.IW / 2, 88, '#cfe', 9);
      if (this._btn(ctx, game.IW / 2 - 50, 120, 100, 18, game.hasSave ? '이어하기' : '새 게임 시작')) {
        if (game.hasSave) game.load(); else game.startNew();
        this.menu = null;
      }
      if (game.hasSave && this._btn(ctx, game.IW / 2 - 50, 144, 100, 16, '새 게임(초기화)')) { game.startNew(); this.menu = null; }
      if (this._btn(ctx, game.IW / 2 - 50, game.hasSave ? 166 : 144, 100, 16, '조작법 보기')) this.menu = 'help';
      this.textC(ctx, 'v0.1 · 코드로 그린 픽셀아트', game.IW / 2, game.IH - 16, 'rgba(255,255,255,.5)', 7);
    },

    drawHelp(ctx, game) {
      const r = this.panel(ctx, game, '조작법');
      const lines = [
        'WASD : 이동 (방향키는 사용 안 함)   1~9 또는 [ ]:핫바   I:가방 B:건설 M:지도',
        '마우스 : 캐릭터 기준 4방향 조준   클릭 : 그 방향으로 도구 휘두르기',
        '괭이/물뿌리개는 클릭을 길게 눌러 차징(강화↑=범위↑). 차징 중엔 절반 속도로 이동',
        'E : 주민과 대화 · 수확 · 기계 수거 · 상점 카운터 · 침대 · 광산 · 산출물 · 문 출입',
        '',
        '괭이→밭갈기, 망치→돌·자갈, 낫→잡초·풀·꽃, 도끼→나무·덤불·통나무',
        '수확은 다 자란 작물에 E. 술통 등 완성품도 E로 수거.',
        '물뿌리개는 물이 한정 — 다 쓰면 연못에 대고 Space로 보충.',
        '도구를 강화하면 차징 시 더 넓은 범위를 한 번에 처리.',
        '스프링클러(B에서 제작)를 밭에 두면 아침마다 주변을 자동 급수.',
        '농장→마을→산(광산)으로 길이 이어짐. 건물 문(매트)으로 들어가면 실내.',
        '상점은 영업시간(오전9~오후5시)에 주인이 있어야 거래 가능.',
      ];
      lines.forEach((l, i) => this.text(ctx, l, r.x + 8, r.y + 22 + i * 11, '#2a2018', 8));
      if (this._btn(ctx, r.x + r.w / 2 - 30, r.y + r.h - 18, 60, 14, '닫기')) this.closeMenu(game);
    },

    /* ----- 상점 ----- */
    drawShop(ctx, game) {
      const r = this.panel(ctx, game, '피어의 잡화점');
      const p = game.player;
      if (this._btn(ctx, r.x + 6, r.y + 16, 50, 12, '구매', true)) this.shopTab = 'buy';
      if (this._btn(ctx, r.x + 60, r.y + 16, 50, 12, '판매', true)) this.shopTab = 'sell';
      this.text(ctx, '소지금 ' + p.money + 'G', r.x + r.w - 80, r.y + 18, '#2a2018', 8);

      if (this.shopTab === 'buy') {
        const seeds = Object.keys(DATA.CROPS).filter((id) => DATA.CROPS[id].seasons.includes(game.season));
        let y = r.y + 32;
        if (seeds.length === 0) this.text(ctx, '이번 계절에는 씨앗이 없습니다 (겨울).', r.x + 8, y, '#5a4426', 8);
        seeds.forEach((id) => {
          const c = DATA.CROPS[id];
          Sprites.rect(ctx, r.x + 8, y, 10, 10, c.tint);
          this.text(ctx, c.name + ' 씨앗', r.x + 22, y + 1, '#2a2018', 8);
          this.text(ctx, c.seed + 'G', r.x + 110, y + 1, '#3a5a2a', 8);
          this.text(ctx, '판매 ' + c.sell + 'G · ' + c.grow + '일' + (c.regrow ? ' (다회)' : ''), r.x + 150, y + 1, '#6a5436', 7);
          if (this._btn(ctx, r.x + r.w - 84, y, 36, 11, 'x1')) game.buySeed(id, 1);
          if (this._btn(ctx, r.x + r.w - 44, y, 38, 11, 'x10')) game.buySeed(id, 10);
          y += 13;
        });
        // 도구 강화(망치/괭이/물뿌리개)
        y += 8;
        this.text(ctx, '— 도구 강화 —', r.x + 8, y, '#5a4426', 8); y += 11;
        const ups = [['hammer', DATA.HAMMER_UPGRADES, p.hammerLevel], ['hoe', DATA.HOE_UPGRADES, p.hoeLevel], ['can', DATA.CAN_UPGRADES, p.canLevel]];
        for (const [kind, arr, lvl] of ups) {
          const next = arr[lvl + 1]; if (!next) continue;
          this.text(ctx, next.name, r.x + 8, y + 1, '#2a2018', 8);
          const matStr = Object.entries(next.mat || {}).map(([k, v]) => DATA.displayName(k) + 'x' + v).join('+');
          this.text(ctx, next.price + 'G' + (matStr ? ' +' + matStr : ''), r.x + 96, y + 1, '#6a5436', 7);
          if (this._btn(ctx, r.x + r.w - 56, y, 50, 11, '강화')) game.upgradeTool(kind);
          y += 13;
        }
      } else {
        this.drawSellList(ctx, game, r);
      }
    },

    drawSellList(ctx, game, r) {
      const p = game.player;
      const sellable = p.inventory.filter((s) => {
        const v = s.sell != null ? s.sell : DATA.sellOf(s.id);
        return v > 0 && !DATA.MACHINES[s.id] && !DATA.BUILDINGS[s.id];
      });
      let y = r.y + 32;
      if (!sellable.length) this.text(ctx, '판매할 물건이 없습니다.', r.x + 8, y, '#5a4426', 8);
      sellable.slice(0, 14).forEach((s) => {
        const v = s.sell != null ? s.sell : DATA.sellOf(s.id);
        Sprites.rect(ctx, r.x + 8, y, 10, 10, DATA.tintOf(s.id));
        const nm = (s.base ? DATA.displayName(s.base) + ' ' : '') + DATA.displayName(s.id);
        this.text(ctx, nm + ' x' + s.qty, r.x + 22, y + 1, '#2a2018', 8);
        this.text(ctx, v + 'G/개', r.x + r.w - 150, y + 1, '#3a5a2a', 8);
        if (this._btn(ctx, r.x + r.w - 96, y, 42, 11, '1개')) game.sellStack(s, 1);
        if (this._btn(ctx, r.x + r.w - 50, y, 44, 11, '전체')) game.sellStack(s, s.qty);
        y += 13;
      });
    },

    /* ----- 건설 ----- */
    drawBuild(ctx, game) {
      const r = this.panel(ctx, game, '건설 / 설치  (구매 후 핫바에서 선택→Space로 설치)');
      const p = game.player;
      let y = r.y + 20;
      this.text(ctx, '보유: 나무 ' + p.countItem('wood') + ' · 돌 ' + p.countItem('stone') + ' · ' + p.money + 'G', r.x + 8, y, '#2a2018', 8);
      y += 14;
      const entries = [
        ...Object.keys(DATA.SPRINKLERS).map((id) => ({ id, d: DATA.SPRINKLERS[id], kind: 'sprinkler' })),
        ...Object.keys(DATA.MACHINES).map((id) => ({ id, d: DATA.MACHINES[id], kind: 'machine' })),
        ...Object.keys(DATA.BUILDINGS).map((id) => ({ id, d: DATA.BUILDINGS[id], kind: 'building' })),
      ];
      entries.forEach((e) => {
        Sprites.rect(ctx, r.x + 8, y, 9, 9, e.d.tint);
        this.text(ctx, e.d.name, r.x + 20, y, '#2a2018', 8);
        const matStr = Object.entries(e.d.mat || {}).map(([k, v]) => DATA.displayName(k) + 'x' + v).join('+');
        this.text(ctx, e.d.price + 'G ' + (matStr ? '+ ' + matStr : ''), r.x + 96, y, '#3a5a2a', 7);
        this.text(ctx, e.d.desc, r.x + 20, y + 9, '#6a5436', 7);
        if (this._btn(ctx, r.x + r.w - 56, y, 50, 12, '구매')) game.buyBuildable(e.id, e.kind);
        y += 19;
      });
    },

    /* ----- 가방 ----- */
    drawInventory(ctx, game) {
      const r = this.panel(ctx, game, '가방');
      const p = game.player;
      const cols = 10, slot = 22, x0 = r.x + 8, y0 = r.y + 20;
      p.inventory.forEach((s, i) => {
        const x = x0 + (i % cols) * slot, y = y0 + ((i / cols) | 0) * slot;
        Sprites.rect(ctx, x, y, slot - 2, slot - 2, 'rgba(0,0,0,.25)');
        Sprites.rect(ctx, x + 4, y + 3, 12, 12, DATA.tintOf(s.id));
        if (s.id.endsWith('_seed')) Sprites.rect(ctx, x + 6, y + 11, 8, 4, '#7a5a3a');
        this.text(ctx, '' + s.qty, x + 2, y + slot - 11, '#fff', 7);
      });
      // 마우스 오버 이름
      const m = Input.mouse;
      p.inventory.forEach((s, i) => {
        const x = x0 + (i % cols) * slot, y = y0 + ((i / cols) | 0) * slot;
        if (m.x >= x && m.x <= x + slot && m.y >= y && m.y <= y + slot) {
          const nm = (s.base ? DATA.displayName(s.base) + ' ' : '') + DATA.displayName(s.id);
          this.text(ctx, nm, r.x + 8, r.y + r.h - 14, '#2a2018', 8);
        }
      });
    },

    /* ----- 지도 ----- */
    drawMap(ctx, game) {
      const r = this.panel(ctx, game, '지도  (M으로 닫기)');
      const pad = 6, gap = 10, topY = r.y + 18;
      const aw = (r.w - pad * 2 - gap * 2) / 3, ah = r.h - 44;
      const boxes = [
        { id: 'farm', map: game.maps.farm, label: '🌾 농장', x: r.x + pad, y: topY, w: aw, h: ah },
        { id: 'town', map: game.maps.town, label: '🏘 마을', x: r.x + pad + aw + gap, y: topY, w: aw, h: ah },
        { id: 'mountain', map: game.maps.mountain, label: '⛰ 광산', x: r.x + pad + (aw + gap) * 2, y: topY, w: aw, h: ah },
      ];
      for (const b of boxes) this.drawMapBox(ctx, game, b);
      // 맵을 잇는 길 표시
      const midY = topY + ah * 0.5;
      for (let i = 0; i < 2; i++) Sprites.rect(ctx, boxes[i].x + aw - 1, midY - 1, gap + 2, 3, '#b0936a');

      let note = '';
      if (game.scene === 'cave') note = '※ 현재 위치: 동굴 ' + game.cave.depth + '층';
      else if (game.world && game.world.indoor) note = '※ 현재 위치: 건물 실내';
      if (note) this.text(ctx, note, r.x + pad, r.y + r.h - 26, '#b22', 8);
      this.text(ctx, '● 나   ● 주민   ■ 시설', r.x + pad, r.y + r.h - 14, '#2a2018', 8);
      if (this._btn(ctx, r.x + r.w - 72, r.y + r.h - 18, 64, 14, '게임 저장')) { game.save(); this.toast('저장했습니다.', '#cfe'); }
    },
    drawMapBox(ctx, game, b) {
      const { id, map, x, y, w, h } = b;
      const sx = w / map.W, sy = h / map.H;
      Sprites.rect(ctx, x, y, w, h, '#83b25f');
      for (let ty = 0; ty < map.H; ty++) for (let tx = 0; tx < map.W; tx++) {
        const t = map.tiles[ty][tx];
        if (t === 'path') Sprites.rect(ctx, x + tx * sx, y + ty * sy, Math.ceil(sx), Math.ceil(sy), '#b0936a');
        else if (t === 'pave') Sprites.rect(ctx, x + tx * sx, y + ty * sy, Math.ceil(sx), Math.ceil(sy), '#b8b2a2');
        else if (t === 'water') Sprites.rect(ctx, x + tx * sx, y + ty * sy, Math.ceil(sx), Math.ceil(sy), '#4a82bf');
      }
      ctx.strokeStyle = '#4a3a22'; ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
      this.text(ctx, b.label, x + 3, y + 2, '#fff', 8);
      const px = (tx) => x + tx * sx, py = (ty) => y + ty * sy;
      const labels = [];
      for (const [k, o] of map.objects) {
        const a = k.split(',').map(Number);
        let nm = null, col = null;
        if (o.type === 'building') {
          if (o.id === 'house') { nm = '집'; col = '#c98a5a'; }
          else if (o.id === 'shop') { nm = '상점'; col = '#4a9a4a'; }
          else if (o.id === 'cavehouse') { nm = '광산'; col = '#6a6470'; }
          else if (o.id === 'townhouse') { col = '#b88a5a'; }
          else if (DATA.BUILDINGS[o.id]) { nm = DATA.BUILDINGS[o.id].name; col = DATA.BUILDINGS[o.id].tint; }
        } else if (o.type === 'bin') { nm = '출하'; col = '#6a5a3a'; }
        else if (o.type === 'cave') { nm = '광산'; col = '#1a1a22'; }
        else if (o.type === 'warp') { col = '#caa040'; }   // 문은 점만(라벨 생략)
        else continue;
        Sprites.rect(ctx, px(a[0]) - 1, py(a[1]) - 1, 3, 3, col);
        if (nm) labels.push({ x: px(a[0]), y: py(a[1]), nm });
      }
      labels.forEach((l) => this.text(ctx, l.nm, l.x + 2, l.y - 3, '#241c12', 7));
      for (const n of (map.npcs || [])) {
        const mx = px((n.x + 8) / 16), my = py((n.y + 8) / 16);
        Sprites.rect(ctx, mx - 1, my - 1, 3, 3, n.color);
        this.text(ctx, n.name, mx + 2, my - 3, '#10204a', 7);
      }
      if (game.scene === id) {
        const mx = px((game.player.x + 8) / 16), my = py((game.player.y + 8) / 16);
        Sprites.rect(ctx, mx - 2, my - 2, 5, 5, '#e23a3a');
        Sprites.rect(ctx, mx - 1, my - 1, 3, 3, '#fff');
        this.text(ctx, '나', mx + 3, my - 4, '#e23a3a', 8);
      }
    },

    /* ----- 가공 기계 메뉴 ----- */
    drawMachine(ctx, game) {
      const o = this.machineTarget;
      if (!o) { this.menu = null; return; }
      const m = DATA.MACHINES[o.id];
      const r = this.panel(ctx, game, m.name + ' — ' + m.desc);
      const p = game.player;
      if (o.job && o.job.ready) {
        this.text(ctx, '완성! ' + (o.job.base ? DATA.displayName(o.job.base) + ' ' : '') + DATA.displayName(o.job.id) + ' 준비됨', r.x + 8, r.y + 22, '#2a2018', 8);
        if (this._btn(ctx, r.x + 8, r.y + 36, 90, 14, '수거하기')) { game.collectMachine(o); this.menu = null; }
        return;
      }
      if (o.job) {
        this.text(ctx, '가공 중... ' + o.job.daysLeft + '일 남음', r.x + 8, r.y + 22, '#2a2018', 8);
        return;
      }
      // 투입 가능한 재료 목록
      this.text(ctx, '재료를 넣으세요:', r.x + 8, r.y + 20, '#2a2018', 8);
      let y = r.y + 32;
      const candidates = p.inventory.filter((s) => m.process(s.id));
      if (!candidates.length) this.text(ctx, '넣을 수 있는 재료가 없습니다.', r.x + 8, y, '#5a4426', 8);
      candidates.forEach((s) => {
        const out = m.process(s.id);
        Sprites.rect(ctx, r.x + 8, y, 10, 10, DATA.tintOf(s.id));
        this.text(ctx, DATA.displayName(s.id) + ' x' + s.qty + ' → ' + DATA.displayName(out.id) + ' (' + out.days + '일, ' + out.sell + 'G)', r.x + 22, y + 1, '#2a2018', 8);
        if (this._btn(ctx, r.x + r.w - 60, y, 54, 11, '투입')) { game.loadMachine(o, s); }
        y += 13;
      });
    },

    /* ----- NPC 대화창 ----- */
    drawDialogue(ctx, game) {
      const d = DATA.NPCS[this.dialogue.id]; if (!d) { this.dialogue = null; return; }
      const W = game.IW, boxH = 64, x = 8, y = game.IH - boxH - 8, w = W - 16;
      Sprites.rect(ctx, x, y, w, boxH, 'rgba(22,18,30,.92)');
      ctx.strokeStyle = '#e8d9b0'; ctx.lineWidth = 1; ctx.strokeRect(x + 1.5, y + 1.5, w - 3, boxH - 3);
      const ps = 52;
      this.drawPortrait(ctx, x + 6, y + 6, ps, d.portrait);
      ctx.strokeStyle = '#e8d9b0'; ctx.strokeRect(x + 6.5, y + 6.5, ps - 1, ps - 1);
      const tx = x + ps + 16;
      this.text(ctx, d.name, tx, y + 8, '#ffe9b0', 10);
      this.text(ctx, d.role, tx + ctx.measureText(d.name).width + 8, y + 10, '#9ad0ff', 8);
      this.wrapText(ctx, this.dialogue.line, tx, y + 26, w - ps - 26, '#f4f0e8', 9, 12);
      this.text(ctx, '▶ 클릭/E', x + w - 46, y + boxH - 12, 'rgba(255,255,255,.55)', 7);
    },
    wrapText(ctx, s, x, y, maxW, color, size, lh) {
      ctx.font = size + 'px "Courier New", monospace';
      let line = '', yy = y;
      for (const ch of String(s)) {
        if (ch !== ' ' && ctx.measureText(line + ch).width > maxW) { this.text(ctx, line, x, yy, color, size); line = ch; yy += lh; }
        else line += ch;
      }
      if (line) this.text(ctx, line, x, yy, color, size);
    },

    /* ----- 부드러운 2D 일러스트 초상화 (픽셀 아님) ----- */
    drawPortrait(ctx, X, Y, S, prof) {
      prof = prof || {};
      const sh = (c, a) => Sprites.shade(c, a);
      const skin = prof.skin || '#f1c79a', hair = prof.hair || '#5a3a1c';
      const cx = X + S / 2, faceR = S * 0.32, faceCY = Y + S * 0.46;
      const TAU = Math.PI * 2;
      const E = () => TAU; // 풀원
      // 배경
      ctx.fillStyle = prof.bg || '#e9eef5'; ctx.fillRect(X, Y, S, S);
      // 어깨/옷
      ctx.fillStyle = prof.cloth || '#5a7a9a';
      ctx.beginPath(); ctx.ellipse(cx, Y + S * 1.05, S * 0.46, S * 0.3, 0, Math.PI, TAU); ctx.fill();
      ctx.fillStyle = sh(prof.cloth || '#5a7a9a', 18);
      ctx.beginPath(); ctx.moveTo(cx, Y + S * 0.74); ctx.lineTo(cx - S * 0.1, Y + S); ctx.lineTo(cx + S * 0.1, Y + S); ctx.closePath(); ctx.fill();
      // 목
      ctx.fillStyle = sh(skin, -16); ctx.fillRect(cx - S * 0.09, Y + S * 0.62, S * 0.18, S * 0.16);
      // 뒤 머리(롱/번/물결 — 얼굴 뒤)
      if (prof.style === 'ponytail' || prof.style === 'wavy' || prof.style === 'bun' || prof.gender === 'f') {
        ctx.fillStyle = hair;
        ctx.beginPath(); ctx.ellipse(cx, faceCY + S * 0.06, faceR * 1.25, faceR * 1.35, 0, 0, E()); ctx.fill();
        if (prof.style === 'ponytail') { ctx.beginPath(); ctx.ellipse(cx + faceR * 1.2, faceCY + S * 0.1, S * 0.07, S * 0.2, 0.3, 0, E()); ctx.fill(); }
      }
      // 얼굴
      ctx.fillStyle = skin; ctx.beginPath(); ctx.ellipse(cx, faceCY, faceR, faceR * 1.22, 0, 0, E()); ctx.fill();
      // 귀
      ctx.beginPath(); ctx.ellipse(cx - faceR, faceCY + 2, S * 0.05, S * 0.07, 0, 0, E()); ctx.ellipse(cx + faceR, faceCY + 2, S * 0.05, S * 0.07, 0, 0, E()); ctx.fill();
      // 볼터치
      if (prof.blush) { ctx.fillStyle = 'rgba(240,140,150,.4)'; ctx.beginPath(); ctx.ellipse(cx - faceR * 0.55, faceCY + faceR * 0.45, S * 0.06, S * 0.04, 0, 0, E()); ctx.ellipse(cx + faceR * 0.55, faceCY + faceR * 0.45, S * 0.06, S * 0.04, 0, 0, E()); ctx.fill(); }
      // 눈
      const eX = faceR * 0.46, eY = faceCY + (prof.age === 'old' ? S * 0.02 : -S * 0.01);
      const eSz = prof.age === 'young' ? S * 0.075 : S * 0.06;
      for (const g of [-1, 1]) {
        const ex = cx + g * eX;
        ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.ellipse(ex, eY, eSz, eSz * 1.2, 0, 0, E()); ctx.fill();
        ctx.fillStyle = prof.eye || '#5a3a2a'; ctx.beginPath(); ctx.arc(ex, eY + eSz * 0.12, eSz * 0.66, 0, E()); ctx.fill();
        ctx.fillStyle = '#15110f'; ctx.beginPath(); ctx.arc(ex, eY + eSz * 0.12, eSz * 0.34, 0, E()); ctx.fill();
        ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(ex - eSz * 0.22, eY - eSz * 0.12, eSz * 0.2, 0, E()); ctx.fill();
      }
      // 눈썹
      ctx.strokeStyle = prof.brows || sh(hair, -8); ctx.lineWidth = Math.max(1, S * 0.022); ctx.lineCap = 'round';
      for (const g of [-1, 1]) { const bx = cx + g * eX; ctx.beginPath(); ctx.moveTo(bx - eSz, eY - eSz * 1.5); ctx.quadraticCurveTo(bx, eY - eSz * (prof.age === 'old' ? 1.5 : 2), bx + eSz, eY - eSz * 1.4); ctx.stroke(); }
      // 코
      ctx.strokeStyle = sh(skin, -26); ctx.lineWidth = Math.max(1, S * 0.018);
      ctx.beginPath(); ctx.moveTo(cx, eY + eSz * 1.3); ctx.lineTo(cx - S * 0.02, eY + eSz * 2.4); ctx.stroke();
      // 입
      const my = faceCY + faceR * 0.62;
      ctx.strokeStyle = '#a8524a'; ctx.lineWidth = Math.max(1, S * 0.022);
      ctx.beginPath(); ctx.moveTo(cx - S * 0.08, my); ctx.quadraticCurveTo(cx, my + (prof.frown ? -S * 0.025 : S * 0.045), cx + S * 0.08, my); ctx.stroke();
      // 수염/콧수염(노인 등)
      if (prof.beard) { ctx.fillStyle = hair; ctx.beginPath(); ctx.ellipse(cx, faceCY + faceR * 0.85, faceR * 0.92, faceR * 0.55, 0, 0, Math.PI); ctx.fill(); }
      if (prof.mustache) { ctx.fillStyle = hair; ctx.beginPath(); ctx.ellipse(cx, my - S * 0.012, faceR * 0.5, S * 0.04, 0, 0, E()); ctx.fill(); }
      // 주름(노인)
      if (prof.age === 'old') { ctx.strokeStyle = 'rgba(120,90,70,.35)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(cx - faceR * 0.5, faceCY - faceR * 0.25); ctx.quadraticCurveTo(cx, faceCY - faceR * 0.38, cx + faceR * 0.5, faceCY - faceR * 0.25); ctx.stroke(); }
      // 앞머리(스타일별)
      ctx.fillStyle = hair;
      const topY = faceCY - faceR * 1.15;
      if (prof.style === 'bald') {
        ctx.beginPath(); ctx.ellipse(cx, faceCY + faceR * 0.1, faceR * 1.05, faceR * 1.2, 0, Math.PI * 1.05, Math.PI * 1.95); ctx.fill(); // 옆/뒤 머리만
      } else if (prof.style === 'spiky') {
        ctx.beginPath(); ctx.moveTo(cx - faceR, faceCY - faceR * 0.5);
        for (let i = 0; i <= 6; i++) { const t = i / 6; ctx.lineTo(cx - faceR + t * faceR * 2, topY - (i % 2 ? S * 0.08 : 0)); }
        ctx.lineTo(cx + faceR, faceCY - faceR * 0.5); ctx.closePath(); ctx.fill();
      } else { // short/ponytail/wavy/bun 공통 앞머리 캡
        ctx.beginPath(); ctx.ellipse(cx, faceCY - faceR * 0.55, faceR * 1.08, faceR * 0.85, 0, Math.PI, TAU); ctx.fill();
        ctx.fillStyle = skin; ctx.beginPath(); ctx.ellipse(cx, faceCY - faceR * 0.35, faceR * 0.6, faceR * 0.5, 0, Math.PI, TAU); ctx.fill(); // 이마
      }
      if (prof.style === 'bun') { ctx.fillStyle = hair; ctx.beginPath(); ctx.arc(cx, topY - S * 0.02, S * 0.09, 0, E()); ctx.fill(); }
      // 안경
      if (prof.glasses) {
        ctx.strokeStyle = '#3a3a40'; ctx.lineWidth = Math.max(1, S * 0.02);
        for (const g of [-1, 1]) { const ex = cx + g * eX; ctx.beginPath(); ctx.ellipse(ex, eY + eSz * 0.1, eSz * 1.25, eSz * 1.15, 0, 0, E()); ctx.stroke(); }
        ctx.beginPath(); ctx.moveTo(cx - eX + eSz, eY); ctx.lineTo(cx + eX - eSz, eY); ctx.stroke();
      }
    },
  };

  window.UI = UI;
})();
