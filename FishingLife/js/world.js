/* =========================================================================
   FishingLife - Overworld: a walkable character that visits fishing spots,
   the shop, the quest board, traps, house and a travel sign.
   Owns the canvas + main loop; hands off to Fishing for the minigame.
   ========================================================================= */
(function () {
  "use strict";
  const el = (id) => document.getElementById(id);

  const WATER_Y1 = 0.40;        // top 40% of the scene is water
  const BOTTOM_MARGIN = 96;     // keep player above on-screen controls
  const FISH_REACH = 140;       // how close to the shoreline you can cast from

  // ground color themes per location
  const GROUND = {
    grass: ["#74b85e", "#5b9a48"],
    sand:  ["#ecd9a0", "#dcc382"],
    rock:  ["#9aa0a8", "#7c828c"],
    cave:  ["#2c3340", "#1b2029"],
    snowy: ["#dfe8ef", "#c2cfda"],
    town:  ["#c7bfae", "#aba391"],
  };
  // water color by time of day
  const WATERPAL = {
    morning: ["#7fc6e6", "#2f7fae"],
    day:     ["#5fb6e0", "#246f9e"],
    evening: ["#6f86b4", "#39507a"],
    night:   ["#274a86", "#13233f"],
  };

  // Layouts use normalized coords (0..1). objects sit on land; fish/trap markers
  // sit at the shoreline. shop & house only exist in the village (pond).
  const LAYOUTS = {
    pond: { ground: "grass", spawn: [0.5, 0.72], objects: [
      { type: "trap", nx: 0.47, ny: 0.43, label: "통발" },
      { type: "dig", nx: 0.82, ny: 0.66, label: "지렁이 파기" },
      { type: "questboard", nx: 0.16, ny: 0.64, label: "의뢰 게시판" },
      { type: "travel", nx: 0.9, ny: 0.82, label: "이동" },
    ], decor: [["🌳", 0.07, 0.55], ["🌷", 0.22, 0.8], ["🌾", 0.34, 0.78], ["🦆", 0.4, 0.3, "water"], ["🪷", 0.6, 0.25, "water"]] },

    // downtown: services only (no fishing) — reached via the travel sign / map
    town: { ground: "town", noWater: true, spawn: [0.5, 0.82], objects: [
      { type: "shop", nx: 0.22, ny: 0.60, label: "상점" },
      { type: "realestate", nx: 0.50, ny: 0.55, label: "부동산" },
      { type: "house", nx: 0.78, ny: 0.60, label: "내 집" },
      { type: "travel", nx: 0.90, ny: 0.84, label: "낚시터로" },
    ], decor: [["🌳", 0.10, 0.86], ["🌳", 0.66, 0.88], ["🚲", 0.36, 0.9], ["🌳", 0.93, 0.62], ["🪧", 0.5, 0.93]] },

    river: { ground: "grass", spawn: [0.5, 0.74], objects: [
      { type: "trap", nx: 0.49, ny: 0.43, label: "통발" },
      { type: "dig", nx: 0.84, ny: 0.68, label: "지렁이 파기" },
      { type: "questboard", nx: 0.16, ny: 0.66, label: "의뢰 게시판" },
      { type: "travel", nx: 0.9, ny: 0.78, label: "이동" },
    ], decor: [["🌲", 0.1, 0.6], ["🌲", 0.85, 0.62], ["🪨", 0.3, 0.78], ["🍃", 0.5, 0.2, "water"]] },

    valley: { ground: "rock", spawn: [0.5, 0.74], objects: [
      { type: "trap", nx: 0.5, ny: 0.44, label: "통발" },
      { type: "dig", nx: 0.84, ny: 0.68, label: "지렁이 파기" },
      { type: "questboard", nx: 0.16, ny: 0.66, label: "의뢰 게시판" },
      { type: "travel", nx: 0.9, ny: 0.78, label: "이동" },
    ], decor: [["⛰️", 0.12, 0.58], ["🌲", 0.82, 0.6], ["🪨", 0.4, 0.8], ["🪨", 0.65, 0.78]] },

    lake: { ground: "grass", spawn: [0.5, 0.74], objects: [
      { type: "trap", nx: 0.5, ny: 0.43, label: "통발" },
      { type: "dig", nx: 0.84, ny: 0.68, label: "지렁이 파기" },
      { type: "questboard", nx: 0.16, ny: 0.66, label: "의뢰 게시판" },
      { type: "travel", nx: 0.9, ny: 0.78, label: "이동" },
    ], decor: [["🌲", 0.1, 0.62], ["🛶", 0.25, 0.5], ["🌾", 0.8, 0.75]] },

    sea: { ground: "sand", spawn: [0.5, 0.74], objects: [
      { type: "trap", nx: 0.5, ny: 0.43, label: "통발" },
      { type: "dig", nx: 0.84, ny: 0.68, label: "지렁이 파기" },
      { type: "questboard", nx: 0.16, ny: 0.66, label: "의뢰 게시판" },
      { type: "travel", nx: 0.9, ny: 0.78, label: "이동" },
    ], decor: [["🌴", 0.1, 0.6], ["⛱️", 0.82, 0.62], ["🐚", 0.4, 0.78], ["🏖️", 0.6, 0.8]] },

    cave: { ground: "cave", spawn: [0.5, 0.74], objects: [
      { type: "trap", nx: 0.5, ny: 0.44, label: "통발" },
      { type: "dig", nx: 0.84, ny: 0.68, label: "지렁이 파기" },
      { type: "questboard", nx: 0.16, ny: 0.66, label: "의뢰 게시판" },
      { type: "travel", nx: 0.9, ny: 0.78, label: "이동" },
    ], decor: [["🪨", 0.1, 0.6], ["💎", 0.85, 0.7], ["🟢", 0.35, 0.78], ["🪨", 0.6, 0.75]] },

    moon: { ground: "sand", spawn: [0.5, 0.74], objects: [
      { type: "trap", nx: 0.5, ny: 0.43, label: "통발" },
      { type: "dig", nx: 0.84, ny: 0.68, label: "지렁이 파기" },
      { type: "questboard", nx: 0.16, ny: 0.66, label: "의뢰 게시판" },
      { type: "travel", nx: 0.9, ny: 0.78, label: "이동" },
    ], decor: [["🌙", 0.15, 0.55], ["⭐", 0.8, 0.5], ["🐚", 0.4, 0.8], ["🌴", 0.85, 0.7]] },
  };

  const SOLID = { shop: 30, house: 30, realestate: 30 };  // types that block movement (radius)

  const World = {
    canvas: null, ctx: null, W: 0, H: 0,
    player: { x: 0, y: 0, r: 15, vx: 0, vy: 0, facing: "down", phase: 0, moving: false },
    keys: new Set(),
    dpad: { up: false, down: false, left: false, right: false },
    holdAction: false, holdSpace: false,
    layout: null, objects: [], decor: [],
    nearObj: null, mode: "world",
    t: 0, last: 0,
    rain: [], snow: [], _btnKey: "",

    init(canvas) {
      this.canvas = canvas; this.ctx = canvas.getContext("2d");
      this.resize();
      window.addEventListener("resize", () => this.resize());
      this.initParticles();
      this.bindInput();
      this.enterLocation(State.s.location);
      this.last = performance.now();
      requestAnimationFrame((ts) => this.loop(ts));
    },

    resize() {
      const dpr = window.devicePixelRatio || 1;
      const rect = this.canvas.getBoundingClientRect();
      this.W = rect.width; this.H = rect.height;
      this.canvas.width = rect.width * dpr; this.canvas.height = rect.height * dpr;
      this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      if (this.layout) this.resolveObjects();
    },

    initParticles() {
      this.rain = Array.from({ length: 90 }, () => ({ x: Math.random(), y: Math.random(), len: 8 + Math.random() * 10, sp: 0.5 + Math.random() * 0.6 }));
      this.snow = Array.from({ length: 70 }, () => ({ x: Math.random(), y: Math.random(), r: 1 + Math.random() * 2.5, sp: 0.05 + Math.random() * 0.1, sw: Math.random() * 2 }));
    },

    landTop() { return this.H * WATER_Y1; },

    resolveObjects() {
      const L = this.layout;
      this.objects = L.objects.map(o => ({ ...o, cx: o.nx * this.W, cy: o.ny * this.H }));
      this.decor = (L.decor || []).map(d => ({ emoji: d[0], x: d[1] * this.W, y: d[2] * this.H, layer: d[3] || "land" }));
    },

    enterLocation(locId) {
      this.layout = LAYOUTS[locId] || LAYOUTS.pond;
      this.resolveObjects();
      const [sx, sy] = this.layout.spawn;
      this.player.x = sx * this.W;
      this.player.y = Math.min(sy * this.H, this.H - BOTTOM_MARGIN);
      this.player.vx = this.player.vy = 0; this.player.facing = "down";
      this.mode = "world"; this.nearObj = null;
      this.updateActionButton();
    },

    exitFishing() { this.mode = "world"; this.updateActionButton(); },

    // ---- input ---------------------------------------------------------
    isModalOpen() { return !el("modal").classList.contains("hidden"); },

    bindInput() {
      const MOVE = { ArrowUp: "up", KeyW: "up", ArrowDown: "down", KeyS: "down", ArrowLeft: "left", KeyA: "left", ArrowRight: "right", KeyD: "right" };
      window.addEventListener("keydown", (e) => {
        if (this.isModalOpen()) return;
        if (MOVE[e.code]) { this.keys.add(MOVE[e.code]); e.preventDefault(); return; }
        // Space = 낚시 전용 통합 키: 낚시 시작 · 챔질 · 끌어올리기(꾹) 모두 Space로
        if (e.code === "Space") {
          e.preventDefault();
          if (this.mode === "fishing" && Fishing.phase === "reeling") { this.holdSpace = true; return; }
          if (!e.repeat) this.pressAction();
          return;
        }
        // E / Enter = 일반 오브젝트 상호작용만 (낚시는 Space 전용 — 물가에선 동작 안 함)
        if ((e.code === "KeyE" || e.code === "Enter") && !e.repeat) {
          if (this.mode === "world" && this.nearObj) this.interact();
        }
        if (e.code === "Escape" && this.mode === "fishing") { Fishing.cancel(); this.exitFishing(); UI.toast("낚시를 그만뒀어요.", "info"); }
      });
      window.addEventListener("keyup", (e) => {
        if (MOVE[e.code]) this.keys.delete(MOVE[e.code]);
        if (e.code === "Space") this.holdSpace = false;
      });

      // on-screen dpad
      document.querySelectorAll("#dpad button").forEach(b => {
        const dir = b.dataset.dir;
        const on = (e) => { this.dpad[dir] = true; e.preventDefault(); };
        const off = (e) => { this.dpad[dir] = false; if (e) e.preventDefault(); };
        b.addEventListener("pointerdown", on);
        b.addEventListener("pointerup", off);
        b.addEventListener("pointerleave", off);
        b.addEventListener("pointercancel", off);
      });

      // action button (press = interact / cast / hook; hold = reel)
      const act = el("action-btn");
      act.addEventListener("pointerdown", (e) => {
        e.preventDefault();
        if (this.mode === "fishing" && Fishing.phase === "reeling") this.holdAction = true;
        else this.pressAction();
      });
      const release = () => { this.holdAction = false; };
      act.addEventListener("pointerup", release);
      act.addEventListener("pointerleave", release);
      act.addEventListener("pointercancel", release);

      // tapping/holding the water also reels
      this.canvas.addEventListener("pointerdown", (e) => {
        if (this.mode === "fishing" && Fishing.phase === "reeling") { this.holdAction = true; e.preventDefault(); }
      });
      window.addEventListener("pointerup", release);

      el("exit-fishing").addEventListener("click", () => {
        if (this.mode === "fishing") { Fishing.cancel(); this.exitFishing(); UI.toast("낚시를 그만뒀어요.", "info"); }
      });
    },

    pressAction() {
      if (this.isModalOpen()) return;
      if (this.mode === "fishing") { Fishing.onAction(); return; }
      this.interact();
    },

    // ---- interaction ---------------------------------------------------
    interact() {
      const o = this.nearObj;
      if (!o) { if (this.canFishHere()) this.startFishing(); return; }
      switch (o.type) {
        case "trap": this.trapInteract(); break;
        case "dig": Actions.digWorms(); break;
        case "questboard": UI.openPanel("quests"); break;
        case "shop": UI.openPanel("shop"); break;
        case "realestate": UI.openPanel("estate"); break;
        case "house":
          if (State.s.hasHouse) UI.openPanel("house");
          else { UI.toast("아직 내 집이 없어요. 🏢 부동산에서 구입하세요!", "warn"); UI.openPanel("estate"); }
          break;
        case "travel": UI.openPanel("map"); break;
      }
    },

    // can the player cast from where they're standing? (near a watery shoreline)
    canFishHere() {
      if (this.layout.noWater) return false;
      return (this.player.y - this.landTop()) < FISH_REACH;
    },

    // free-form casting: throw the line into the water straight ahead
    startFishing() {
      if (!Fishing.hasBait()) {
        UI.toast("미끼가 없어요! ⚗️제작에서 🍂막미끼를 무료로 만들거나, 🪱흙더미에서 지렁이를 캐세요.", "warn");
        return;
      }
      const p = this.player;
      p.facing = "up"; p.moving = false; p.phase = 0;
      this.keys.clear(); this.holdAction = this.holdSpace = false;
      const handX = p.x, handY = p.y - 26;
      const bobX = Math.max(24, Math.min(this.W - 24, p.x));
      const bobY = this.landTop() * 0.5;
      this.mode = "fishing";
      Fishing.beginCast(bobX, bobY, handX, handY);
      this.updateActionButton();
    },

    trapInteract() {
      const s = State.s;
      const placedIdx = s.traps.findIndex(t => t.loc === s.location);
      if (placedIdx >= 0) { Actions.collectTrap(placedIdx); return; }
      const ownId = Object.keys(s.ownedTraps).find(k => s.ownedTraps[k] > 0);
      if (ownId) Actions.placeTrap(ownId);
      else UI.toast("설치할 통발이 없어요. 상점에서 구입하세요 🪤", "warn");
    },

    // ---- update --------------------------------------------------------
    loop(ts) {
      const dt = Math.min(0.05, (ts - this.last) / 1000); this.last = ts;
      this.update(dt); this.draw();
      requestAnimationFrame((t) => this.loop(t));
    },

    update(dt) {
      this.t += dt;
      if (this.mode === "fishing") {
        if (!this.isModalOpen()) {              // freeze the catch while a menu is open
          Fishing.holding = this.holdAction || this.holdSpace;
          Fishing.update(dt);
        }
        this.updateActionButton();
        return;
      }
      this.updateMovement(dt);
      this.findNearObj();
      this.updateActionButton();
    },

    updateMovement(dt) {
      const p = this.player;
      let dx = 0, dy = 0;
      if (!this.isModalOpen()) {
        if (this.keys.has("left") || this.dpad.left) dx -= 1;
        if (this.keys.has("right") || this.dpad.right) dx += 1;
        if (this.keys.has("up") || this.dpad.up) dy -= 1;
        if (this.keys.has("down") || this.dpad.down) dy += 1;
      }
      const mag = Math.hypot(dx, dy);
      p.moving = mag > 0;
      if (mag > 0) {
        dx /= mag; dy /= mag;
        if (Math.abs(dx) > Math.abs(dy)) p.facing = dx > 0 ? "right" : "left";
        else p.facing = dy > 0 ? "down" : "up";
        p.phase += dt * 10;
      } else { p.phase = 0; }

      const speed = Math.max(150, this.H * 0.32);
      const nx = p.x + dx * speed * dt;
      const ny = p.y + dy * speed * dt;

      // axis-separated movement with collision
      if (!this.blocked(nx, p.y)) p.x = nx;
      if (!this.blocked(p.x, ny)) p.y = ny;

      // bounds: stay on land, within screen, above controls
      const top = this.landTop() + p.r;
      p.x = Math.max(p.r, Math.min(this.W - p.r, p.x));
      p.y = Math.max(top, Math.min(this.H - BOTTOM_MARGIN, p.y));
    },

    blocked(x, y) {
      const p = this.player;
      for (const o of this.objects) {
        const sr = SOLID[o.type]; if (!sr) continue;
        if (Math.hypot(x - o.cx, y - (o.cy + 6)) < sr * 0.7 + p.r) return true;
      }
      return false;
    },

    findNearObj() {
      const p = this.player; let best = null, bd = 78;
      for (const o of this.objects) {
        const d = Math.hypot(p.x - o.cx, p.y - o.cy);
        if (d < bd) { bd = d; best = o; }
      }
      this.nearObj = best;
    },

    // ---- action button / chrome ---------------------------------------
    updateActionButton() {
      const fishing = this.mode === "fishing";
      // chrome (exit btn / dpad / nav) — only touch the DOM when it changes
      if (fishing !== this._chromeFishing) {
        this._chromeFishing = fishing;
        el("exit-fishing").classList.toggle("hidden", !fishing);
        el("nav").classList.toggle("hidden", fishing);
        el("dpad").classList.toggle("dim", fishing);   // movement N/A while fishing
      }
      // action button label — only when it changes
      const btn = el("action-btn");
      let key, label, bite = false, disabled = false;
      if (fishing) {
        key = "f:" + Fishing.phase; label = Fishing.actionLabel();
        bite = Fishing.phase === "bite";
      } else if (this.nearObj) {
        key = "o:" + this.nearObj.type; label = PROMPT_ICON[this.nearObj.type] + " " + this.nearObj.label;
      } else if (this.canFishHere()) {
        key = "fishhere"; label = "🎣 낚시하기";
      } else {
        key = "none"; label = "🔍 둘러보기"; disabled = true;
      }
      if (key !== this._btnKey) {
        this._btnKey = key;
        btn.textContent = label;
        btn.classList.toggle("bite", bite);
        btn.classList.toggle("disabled", disabled);
      }
    },

    // ---- draw ----------------------------------------------------------
    draw() {
      const ctx = this.ctx, W = this.W, H = this.H, top = this.landTop();
      const time = State.s.time;

      if (this.layout.noWater) {
        this.drawCityscape(ctx, W, top, time);
      } else {
        // --- water (top) ---
        const wp = WATERPAL[time] || WATERPAL.day;
        let wg = ctx.createLinearGradient(0, 0, 0, top);
        wg.addColorStop(0, wp[0]); wg.addColorStop(1, wp[1]);
        ctx.fillStyle = wg; ctx.fillRect(0, 0, W, top);
        ctx.strokeStyle = "rgba(255,255,255,.12)"; ctx.lineWidth = 2;
        for (let i = 0; i < 5; i++) {
          const y = 16 + i * (top - 16) / 5;
          ctx.beginPath();
          for (let x = 0; x <= W; x += 12) {
            const yy = y + Math.sin(x * 0.045 + this.t * 1.5 + i) * 3;
            x === 0 ? ctx.moveTo(x, yy) : ctx.lineTo(x, yy);
          }
          ctx.stroke();
        }
        // moon/stars at night reflected over water top
        if (time === "night") {
          ctx.fillStyle = "rgba(255,255,255,.8)";
          for (let i = 0; i < 30; i++) {
            const sx = (i * 91.7 % W), sy = (i * 37.3 % (top * 0.8));
            if ((Math.sin(this.t * 0.7 + i) + 1) > 1.3) ctx.fillRect(sx, sy, 1.5, 1.5);
          }
          ctx.fillStyle = "#f4f3d6"; ctx.beginPath(); ctx.arc(W * 0.82, top * 0.22, 16, 0, Math.PI * 2); ctx.fill();
        }
        // water decor (lily pads etc.)
        this.decor.filter(d => d.layer === "water").forEach(d => {
          ctx.font = "22px sans-serif"; ctx.textAlign = "center";
          ctx.fillText(d.emoji, d.x, d.y + Math.sin(this.t + d.x) * 2);
        });
        // --- shoreline strip ---
        ctx.fillStyle = "rgba(232,210,150,.55)"; ctx.fillRect(0, top - 6, W, 14);
      }

      // --- ground (bottom) ---
      const gp = GROUND[this.layout.ground] || GROUND.grass;
      let gg = ctx.createLinearGradient(0, top, 0, H);
      gg.addColorStop(0, gp[0]); gg.addColorStop(1, gp[1]);
      ctx.fillStyle = gg; ctx.fillRect(0, top + 6, W, H - top);
      // subtle ground texture dots
      ctx.fillStyle = "rgba(0,0,0,.05)";
      for (let i = 0; i < 50; i++) {
        const gx = (i * 73.1 % W), gy = top + 14 + ((i * 51.7) % (H - top - 20));
        ctx.fillRect(gx, gy, 3, 2);
      }

      // land decor
      this.decor.filter(d => d.layer === "land").forEach(d => {
        ctx.font = "30px sans-serif"; ctx.textAlign = "center";
        ctx.fillStyle = "rgba(0,0,0,.18)"; ctx.beginPath();
        ctx.ellipse(d.x, d.y + 14, 13, 5, 0, 0, Math.PI * 2); ctx.fill();
        ctx.fillText(d.emoji, d.x, d.y + 8);
      });

      // objects, sorted by y so nearer ones overlap correctly
      const drawList = [...this.objects].sort((a, b) => a.cy - b.cy);
      drawList.forEach(o => this.drawObject(ctx, o));
      // interaction arrows on top of every interactable
      this.objects.forEach(o => this.drawObjArrow(ctx, o, o === this.nearObj));

      // player (insert by depth: draw after objects above it, before below — simple: draw last)
      this.drawCharacter(ctx);

      // location label
      ctx.fillStyle = time === "night" || this.layout.ground === "cave" ? "rgba(255,255,255,.8)" : "rgba(20,40,60,.7)";
      ctx.font = "bold 13px sans-serif"; ctx.textAlign = "left";
      const loc = DATA.locById(State.s.location);
      ctx.fillText(`${loc.emoji} ${loc.name}`, 12, 20);

      // weather
      this.drawWeather(ctx, W, H, top);

      // prompt bubble above the near object
      if (this.mode === "world" && this.nearObj) this.drawPrompt(ctx, this.nearObj);
      // hint to cast when standing by open water
      else if (this.mode === "world" && this.canFishHere()) this.drawFishHint(ctx);

      // fishing overlay
      if (this.mode === "fishing") Fishing.drawOverlay(ctx, W, H);

      // cave darkness vignette
      if (this.layout.ground === "cave") {
        const vg = ctx.createRadialGradient(this.player.x, this.player.y, 40, this.player.x, this.player.y, Math.max(W, H) * 0.6);
        vg.addColorStop(0, "rgba(0,0,0,0)"); vg.addColorStop(1, "rgba(0,0,0,.55)");
        ctx.fillStyle = vg; ctx.fillRect(0, 0, W, H);
      }
    },

    // town backdrop: sky + building silhouettes with lit windows
    drawCityscape(ctx, W, top, time) {
      const sky = time === "night" ? ["#1b2452", "#3a4a86"]
        : time === "evening" ? ["#ff9e7d", "#ffd29e"]
          : time === "morning" ? ["#ffd9a0", "#cdeaf5"] : ["#9fd8ff", "#dff2ff"];
      const g = ctx.createLinearGradient(0, 0, 0, top);
      g.addColorStop(0, sky[0]); g.addColorStop(1, sky[1]);
      ctx.fillStyle = g; ctx.fillRect(0, 0, W, top);
      const night = time === "night";
      const bw = W / 7;
      for (let i = 0; i < 7; i++) {
        const bh = top * (0.42 + (Math.sin(i * 12.9) * 0.5 + 0.5) * 0.5);
        ctx.fillStyle = night ? "#2a3358" : "rgba(110,124,150,.55)";
        ctx.fillRect(i * bw + 3, top - bh, bw - 6, bh);
        ctx.fillStyle = night ? "rgba(255,221,130,.55)" : "rgba(255,255,255,.28)";
        for (let wy = top - bh + 9; wy < top - 9; wy += 14)
          for (let wx = i * bw + 9; wx < i * bw + bw - 11; wx += 12) ctx.fillRect(wx, wy, 5, 7);
      }
    },

    drawObject(ctx, o) {
      // shadow
      ctx.fillStyle = "rgba(0,0,0,.2)"; ctx.beginPath();
      ctx.ellipse(o.cx, o.cy + 16, 18, 6, 0, 0, Math.PI * 2); ctx.fill();

      if (o.type === "realestate") {
        ctx.fillStyle = "#7e8ba6"; ctx.fillRect(o.cx - 23, o.cy - 26, 46, 48);
        ctx.fillStyle = "#aebccf"; ctx.fillRect(o.cx - 23, o.cy - 26, 46, 6);
        ctx.fillStyle = "#3a5f8a";
        for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) ctx.fillRect(o.cx - 16 + c * 13, o.cy - 14 + r * 12, 9, 8);
        ctx.fillStyle = "#2f6a4a"; ctx.fillRect(o.cx - 23, o.cy + 16, 46, 8);
        ctx.font = "12px sans-serif"; ctx.textAlign = "center"; ctx.fillStyle = "#fff"; ctx.fillText("부동산", o.cx, o.cy + 23);
      } else if (o.type === "shop") {
        // stall: body + striped awning
        ctx.fillStyle = "#c98a5b"; roundRect(ctx, o.cx - 26, o.cy - 6, 52, 28, 4); ctx.fill();
        ctx.fillStyle = "#8a5a36"; ctx.fillRect(o.cx - 26, o.cy - 6, 52, 5);
        for (let i = 0; i < 6; i++) { ctx.fillStyle = i % 2 ? "#e85f5f" : "#f4f1e8"; ctx.fillRect(o.cx - 26 + i * 9, o.cy - 18, 9, 12); }
        ctx.font = "20px sans-serif"; ctx.textAlign = "center"; ctx.fillText("🏪", o.cx, o.cy + 14);
      } else if (o.type === "house") {
        ctx.fillStyle = "#e8d6b0"; ctx.fillRect(o.cx - 24, o.cy - 4, 48, 26);
        ctx.fillStyle = "#b5562f"; ctx.beginPath();
        ctx.moveTo(o.cx - 30, o.cy - 4); ctx.lineTo(o.cx, o.cy - 28); ctx.lineTo(o.cx + 30, o.cy - 4); ctx.closePath(); ctx.fill();
        ctx.fillStyle = "#7a5230"; ctx.fillRect(o.cx - 7, o.cy + 4, 14, 18);
        ctx.font = "16px sans-serif"; ctx.textAlign = "center"; ctx.fillText("🏡", o.cx, o.cy - 6);
      } else if (o.type === "dig") {
        // a small mound of dirt with a worm peeking out
        ctx.fillStyle = "#6e5235"; ctx.beginPath(); ctx.ellipse(o.cx, o.cy + 6, 22, 12, 0, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = "#5a4129";
        ctx.beginPath(); ctx.ellipse(o.cx - 7, o.cy + 4, 5, 3, 0, 0, 7); ctx.fill();
        ctx.beginPath(); ctx.ellipse(o.cx + 8, o.cy + 8, 6, 3, 0, 0, 7); ctx.fill();
        ctx.font = "20px sans-serif"; ctx.textAlign = "center"; ctx.fillText("🪱", o.cx, o.cy + 1);
      } else {
        // simple marker: emoji on a small post/platform
        const map = { fish: "🎣", trap: "🪤", questboard: "📜", travel: "🪧" };
        if (o.type === "questboard") {
          ctx.fillStyle = "#7a5230"; ctx.fillRect(o.cx - 18, o.cy - 4, 36, 22);
          ctx.fillStyle = "#caa978"; ctx.fillRect(o.cx - 15, o.cy - 1, 30, 16);
        }
        ctx.font = "30px sans-serif"; ctx.textAlign = "center";
        ctx.fillText(map[o.type], o.cx, o.cy + 10);
      }
    },

    // a small opaque arrow that hovers over every interactable (gold + bigger when nearest)
    drawObjArrow(ctx, o, near) {
      const off = (o.type === "shop" || o.type === "house") ? 46 : 30;
      const bob = Math.sin(this.t * 3 + o.cx * 0.05) * (near ? 4 : 2);
      const ay = o.cy - off - bob;
      const s = near ? 10 : 6.5;
      ctx.beginPath();
      ctx.moveTo(o.cx - s, ay - s); ctx.lineTo(o.cx + s, ay - s); ctx.lineTo(o.cx, ay + s * 0.7); ctx.closePath();
      ctx.fillStyle = near ? "#ffd34d" : "#ffffff";
      ctx.strokeStyle = "rgba(0,0,0,.35)"; ctx.lineWidth = 1.4;
      ctx.fill(); ctx.stroke();
    },

    drawPrompt(ctx, o) {
      const txt = "▶ " + o.label;
      ctx.font = "bold 12px sans-serif"; ctx.textAlign = "center";
      const w = ctx.measureText(txt).width + 20;
      const off = (o.type === "shop" || o.type === "house") ? 66 : 50;
      const bx = o.cx, by = o.cy - off + Math.sin(this.t * 4) * 2;
      ctx.fillStyle = "rgba(12,26,40,.92)";
      roundRect(ctx, bx - w / 2, by - 14, w, 22, 8); ctx.fill();
      ctx.strokeStyle = "#ffe178"; ctx.lineWidth = 1.5;
      roundRect(ctx, bx - w / 2, by - 14, w, 22, 8); ctx.stroke();
      ctx.fillStyle = "#fff"; ctx.fillText(txt, bx, by + 1);
    },

    // little "cast here" hint that floats above the player near water
    drawFishHint(ctx) {
      const p = this.player;
      const txt = "🎣 낚시 (Space)";
      ctx.font = "bold 12px sans-serif"; ctx.textAlign = "center";
      const w = ctx.measureText(txt).width + 20;
      const bx = p.x, by = p.y - 56 + Math.sin(this.t * 4) * 2;
      ctx.fillStyle = "rgba(12,26,40,.9)";
      roundRect(ctx, bx - w / 2, by - 14, w, 22, 8); ctx.fill();
      ctx.strokeStyle = "#9fe8c0"; ctx.lineWidth = 1.5;
      roundRect(ctx, bx - w / 2, by - 14, w, 22, 8); ctx.stroke();
      ctx.fillStyle = "#fff"; ctx.fillText(txt, bx, by + 1);
    },

    drawCharacter(ctx) {
      const p = this.player;
      const fx = p.x, fy = p.y;
      const bob = p.moving ? Math.abs(Math.sin(p.phase)) * 3 : 0;
      const step = p.moving ? Math.sin(p.phase) * 3 : 0;

      // straining wobble while reeling a fish in (sway + fast tremble)
      const reeling = this.mode === "fishing" && window.Fishing && Fishing.phase === "reeling";
      const lean = reeling ? Math.sin(this.t * 6.5) * 3 + Math.sin(this.t * 19) * 1.4 : 0;
      const vjit = reeling ? Math.abs(Math.sin(this.t * 12)) * 1.6 : 0;

      // shadow (feet stay planted)
      ctx.fillStyle = "rgba(0,0,0,.25)"; ctx.beginPath();
      ctx.ellipse(fx, fy, 13, 5, 0, 0, Math.PI * 2); ctx.fill();

      const bodyTop = fy - 34 - bob + vjit;
      // legs (planted at fx)
      ctx.fillStyle = "#3a4a63";
      ctx.fillRect(fx - 7, fy - 12 - bob, 5, 12 + step);
      ctx.fillRect(fx + 2, fy - 12 - bob, 5, 12 - step);
      // upper body leans & trembles around cx
      const cx = fx + lean;
      // body (shirt)
      ctx.fillStyle = "#39c0c8";
      roundRect(ctx, cx - 10, bodyTop, 20, 22, 6); ctx.fill();
      // arms
      ctx.fillStyle = "#2a9aa1";
      if (this.mode === "fishing") {
        this.drawRod(ctx, cx, bodyTop);
      } else {
        ctx.fillRect(cx - 13, bodyTop + 4, 4, 12);
        ctx.fillRect(cx + 9, bodyTop + 4, 4, 12);
      }
      // head
      const hx = cx, hy = bodyTop - 8;
      ctx.fillStyle = "#f6d2ad"; ctx.beginPath(); ctx.arc(hx, hy, 10, 0, Math.PI * 2); ctx.fill();
      // hair
      ctx.fillStyle = "#5a3a25"; ctx.beginPath(); ctx.arc(hx, hy - 2, 10, Math.PI, 0); ctx.fill();
      ctx.fillRect(hx - 10, hy - 3, 20, 4);
      // hat brim
      ctx.fillStyle = "#c98a5b"; ctx.fillRect(hx - 12, hy - 3, 24, 3);
      // face by direction
      ctx.fillStyle = "#33291f";
      if (p.facing === "up") {
        // back of head, no face
      } else if (p.facing === "left") {
        ctx.beginPath(); ctx.arc(hx - 4, hy + 1, 1.6, 0, Math.PI * 2); ctx.fill();
      } else if (p.facing === "right") {
        ctx.beginPath(); ctx.arc(hx + 4, hy + 1, 1.6, 0, Math.PI * 2); ctx.fill();
      } else {
        ctx.beginPath(); ctx.arc(hx - 4, hy + 1, 1.6, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(hx + 4, hy + 1, 1.6, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = "rgba(232,120,120,.5)";
        ctx.beginPath(); ctx.arc(hx - 6, hy + 4, 2, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(hx + 6, hy + 4, 2, 0, Math.PI * 2); ctx.fill();
      }
      // sweat beads flinging off the temples while straining
      if (reeling) this.drawSweat(ctx, hx, hy);
    },

    // beads of sweat that bead up at the temples and fling off — the "뻘뻘" effort look
    drawSweat(ctx, hx, hy) {
      for (let i = 0; i < 4; i++) {
        const ph = (this.t * 1.6 + i * 0.27) % 1;          // 0..1 loop, staggered
        const side = i % 2 ? 1 : -1;
        const sx = hx + side * (9 + ph * 11);
        const sy = hy - 8 + ph * 16;                       // bead near the head, then drop away
        const a = 0.9 * (1 - ph);
        const r = 2.6 - ph * 1.1;
        ctx.fillStyle = "rgba(175,222,255," + a.toFixed(3) + ")";
        ctx.beginPath(); ctx.arc(sx, sy, Math.max(0.6, r), 0, Math.PI * 2); ctx.fill();
        // little pointed tail to read as a droplet
        ctx.beginPath();
        ctx.moveTo(sx - r, sy); ctx.lineTo(sx, sy - r * 2.1); ctx.lineTo(sx + r, sy); ctx.closePath();
        ctx.fill();
      }
    },

    // the rod the character holds while fishing — animates the cast & the hook-set
    drawRod(ctx, fx, bodyTop) {
      const F = window.Fishing || {};
      const D = Math.PI / 180;
      const handX = fx + 6, handY = bodyTop + 6, rodLen = 22;
      let ang = -82 * D;                                  // steady up-forward hold
      if (F.phase === "casting") {
        const p = F.castDur ? Math.min(1, F.castT / F.castDur) : 1;
        const a0 = -150 * D, a1 = -52 * D;               // over-shoulder → forward
        const f = p < 0.3 ? -0.12 * (p / 0.3) : (p - 0.3) / 0.7;  // tiny wind-back, then whip
        ang = a0 + (a1 - a0) * Math.max(0, f);
      } else if (F.phase === "hooking") {
        const p = F.hookDur ? Math.min(1, F.hookT / F.hookDur) : 1;
        const k = Math.sin(Math.min(1, p) * Math.PI);    // 0 → 1 → 0 sharp flick
        ang = -82 * D + (-46 * D) * k;                   // yank up & back, then settle
      } else if (F.phase === "waiting") {
        ang += Math.sin(this.t * 2) * 0.05;              // gentle idle sway
      } else if (F.phase === "reeling") {
        ang += Math.sin(this.t * 17) * 0.07 + Math.sin(this.t * 5) * 0.04;  // straining tremble
      }
      const tipX = handX + Math.cos(ang) * rodLen;
      const tipY = handY + Math.sin(ang) * rodLen;
      // forearm reaching to the grip
      ctx.fillStyle = "#2a9aa1";
      ctx.fillRect(fx - 3, bodyTop + 4, (handX - fx) + 5, 4);
      // rod
      ctx.strokeStyle = "#7a4a25"; ctx.lineWidth = 2; ctx.lineCap = "round";
      ctx.beginPath(); ctx.moveTo(handX, handY); ctx.lineTo(tipX, tipY); ctx.stroke();
      ctx.lineCap = "butt";
      // keep the fishing line anchored to the moving rod tip
      F.originX = tipX; F.originY = tipY;
    },

    drawWeather(ctx, W, H, top) {
      const w = State.s.weather;
      if (w === "rain") {
        ctx.strokeStyle = "rgba(200,225,255,.5)"; ctx.lineWidth = 1.5;
        this.rain.forEach(d => {
          d.y += d.sp * 0.02; if (d.y > 1) { d.y = 0; d.x = Math.random(); }
          const x = d.x * W, y = d.y * H;
          ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x - 3, y + d.len); ctx.stroke();
        });
        ctx.fillStyle = "rgba(60,80,110,.14)"; ctx.fillRect(0, 0, W, H);
      } else if (w === "snow") {
        ctx.fillStyle = "rgba(255,255,255,.9)";
        this.snow.forEach(s => {
          s.y += s.sp * 0.02; s.x += Math.sin(this.t + s.sw) * 0.0006;
          if (s.y > 1) { s.y = 0; s.x = Math.random(); }
          ctx.beginPath(); ctx.arc(s.x * W, s.y * H, s.r, 0, Math.PI * 2); ctx.fill();
        });
      } else if (w === "cloudy") {
        ctx.fillStyle = "rgba(180,190,200,.10)"; ctx.fillRect(0, 0, W, top);
      }
    },
  };

  const PROMPT_ICON = { fish: "🎣", trap: "🪤", dig: "🪱", questboard: "📜", shop: "🏪", house: "🏡", realestate: "🏢", travel: "🪧" };

  function roundRect(ctx, x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    ctx.beginPath(); ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
  }

  window.World = World;
})();
