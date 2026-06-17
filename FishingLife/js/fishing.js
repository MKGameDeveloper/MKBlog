/* =========================================================================
   FishingLife - Fishing minigame (driven by World, drawn as an overlay)
   Phases: idle -> casting -> waiting -> bite -> hooking -> reeling
   World calls: Fishing.beginCast(), Fishing.update(dt), Fishing.drawOverlay(ctx)
   ========================================================================= */
(function () {
  "use strict";

  const RARITY_DIFF = { common: 1.0, uncommon: 1.6, rare: 2.4, epic: 3.4, legendary: 4.6 };

  const Fishing = {
    phase: "idle",
    t: 0,
    fish: null, diff: 1,
    waitUntil: 0, biteUntil: 0,
    // bobber + rod origin (canvas px); origin tracks the rod tip each frame
    bobberX: 0, bobberY: 0, originX: 0, originY: 0, bobDip: 0,
    // reeling state: keep the fish inside the moving green zone
    zoneH: 0.3, zonePos: 0.5, zoneVel: 0, agility: 1,
    fishPos: 0.5, fishTarget: 0.5, fishTimer: 0,
    progress: 0.42, holding: false,
    // cast (rod swing) + hook-set (챔질) animation timers
    castT: 0, castDur: 0.6, hookT: 0, hookDur: 0.45,
    W: 0, H: 0,

    // ---- availability + selection (unchanged logic) -------------------
    availableFish() {
      const s = State.s;
      return DATA.FISH.filter(f => {
        if (!f.loc.includes(s.location)) return false;
        if (f.seasons.length && !f.seasons.includes(s.season)) return false;
        if (f.weathers.length && !f.weathers.includes(s.weather)) return false;
        if (f.times.length && !f.times.includes(s.time)) return false;
        if (f.minRod && s.rodTier < f.minRod) return false;
        return true;
      });
    },
    pickFish() {
      const list = this.availableFish();
      if (!list.length) return null;
      const bait = State.s.currentBait;
      const baitPow = (DATA.BAITS[bait] || {}).power || 1;
      const TIER = { common: 0, uncommon: 1, rare: 2, epic: 3, legendary: 4 };
      const weighted = list.map(f => {
        let w = DATA.RARITY[f.rarity].weight;
        // better bait (higher 유인력) tilts the odds toward higher-tier fish
        if (!f.junk) w *= Math.max(0.05, 1 + (baitPow - 1) * (TIER[f.rarity] || 0) * 0.8);
        if (f.bait && f.bait === bait) w *= 6;
        else if (f.bait && (bait === "worm" || bait === "mud")) w *= 0.5;
        if (f.junk) w *= 0.55;
        return { f, w };
      });
      const total = weighted.reduce((a, b) => a + b.w, 0);
      let r = Math.random() * total;
      for (const it of weighted) { r -= it.w; if (r <= 0) return it.f; }
      return weighted[weighted.length - 1].f;
    },
    makeInstance(f) {
      const size = Math.round((f.size[0] + Math.random() * (f.size[1] - f.size[0])) * 10) / 10;
      const sizeRatio = (size - f.size[0]) / Math.max(1, f.size[1] - f.size[0]);
      const value = Math.max(1, Math.round(f.value * (0.8 + sizeRatio * 0.6)));
      return { id: f.id, name: f.name, emoji: f.emoji, rarity: f.rarity, value, size, junk: !!f.junk, season: State.s.season };
    },

    // ---- flow ----------------------------------------------------------
    // do we own any bait? (auto-switch to whatever we have, so casts don't dead-end)
    hasBait() {
      const s = State.s;
      if ((s.baits[s.currentBait] || 0) > 0) return true;
      const alt = Object.keys(s.baits).find(k => s.baits[k] > 0);
      if (alt) { s.currentBait = alt; return true; }
      return false;
    },

    // step 1 — the cast: swing the rod & arc the line out (bait spent when it lands)
    beginCast(bobberX, bobberY, originX, originY) {
      this.bobberX = bobberX; this.bobberY = bobberY;
      this.originX = originX; this.originY = originY; this.bobDip = 0;
      this.fish = null;
      this.castT = 0; this.castDur = 0.6;
      this.phase = "casting";
      UI.refreshAction();
      return true;
    },

    // step 2 — line settles: consume bait and start waiting for a bite
    _startWaiting() {
      const s = State.s;
      let baitId = s.currentBait;
      if ((s.baits[baitId] || 0) <= 0) {
        const alt = Object.keys(s.baits).find(k => s.baits[k] > 0);
        if (alt) { s.currentBait = baitId = alt; }
        else {
          UI.toast("미끼가 없어요! ⚗️제작에서 🍂막미끼를 무료로 만들거나, 🪱흙더미에서 지렁이를 캐세요.", "warn");
          this.endToWorld(); return;
        }
      }
      s.baits[baitId] -= 1; State.save(); UI.refreshTopbar();
      const baitPow = (DATA.BAITS[baitId] || {}).power || 1;
      this.phase = "waiting";
      this.waitUntil = this.t + 1.6 + Math.random() * 4.5 / baitPow;
      UI.refreshAction();
    },

    cancel() { this.fish = null; this.phase = "idle"; },

    actionLabel() {
      switch (this.phase) {
        case "casting": return "🎣 던지는 중...";
        case "waiting": return "🫧 입질 대기중...";
        case "bite": return "❗ 챔질!";
        case "hooking": return "❗ 챔질!";
        case "reeling": return "💪 꾹! 끌어올리기";
        default: return "🎣";
      }
    },

    onAction() {
      if (this.phase === "bite") this.hook();
      else if (this.phase === "waiting") { this.waitUntil += 1.0; UI.toast("아직 입질이 없어요 🫧", "info"); }
    },

    triggerBite() {
      this.fish = this.pickFish();
      if (!this.fish) {
        UI.toast("지금 이곳엔 잡을 게 없네요...", "info");
        this.endToWorld(); return;
      }
      this.phase = "bite"; this.biteUntil = this.t + 1.4;
      UI.refreshAction(); UI.pulseAction();
    },

    // 챔질: play a quick rod-yank, then set up the reeling minigame
    hook() {
      this.phase = "hooking";
      this.hookT = 0; this.hookDur = 0.45;
      UI.refreshAction(); UI.pulseAction();
    },

    _startReeling() {
      const f = this.fish;
      const rodTier = State.s.rodTier;
      const rod = DATA.rodByTier(rodTier);
      const rodPow = rod ? rod.power : 1;
      const baseDiff = RARITY_DIFF[f.rarity] || 1;
      const sizeFactor = 1 + (f.size[1] / 700);
      // a higher-grade rod tames lower-tier fish: the more the rod outclasses the
      // fish's rarity, the weaker its activity. Same/higher-tier fish stay lively.
      const RARITY_RANK = { common: 1, uncommon: 2, rare: 3, epic: 4, legendary: 5 };
      const outclass = Math.max(0, rodTier - (RARITY_RANK[f.rarity] || 1));
      const tame = Math.max(0.35, 1 - outclass * 0.18);
      this.diff = Math.max(0.5, Math.min(6, baseDiff * sizeFactor * tame));
      // catch zone size: rod helps, difficulty shrinks it
      this.zoneH = Math.max(0.12, Math.min(0.6, 0.30 * rodPow / (1 + (this.diff - 1) * 0.16)));
      // zone responsiveness/speed: a better rod moves the bobber faster
      this.agility = 1 + (rodPow - 1) * 0.9;
      this.zonePos = 0.5; this.zoneVel = 0;
      this.fishPos = 0.5; this.fishTarget = 0.5; this.fishTimer = 0;
      this.progress = 0.42; this.holding = false;
      this.phase = "reeling"; UI.refreshAction();
    },

    finishCatch(success) {
      const f = this.fish;
      if (success) {
        const inst = this.makeInstance(f);
        window.Game && Game.onCatch(inst, f);
      } else {
        UI.toast(`${f.emoji} ${f.name}이(가) 도망쳤어요...`, "warn");
      }
      this.endToWorld();
    },

    endToWorld() {
      this.fish = null; this.phase = "idle";
      window.World && World.exitFishing();
      UI.refreshAction();
    },

    // ---- update --------------------------------------------------------
    update(dt) {
      this.t += dt;
      if (this.phase === "casting") {
        this.castT += dt;
        if (this.castT >= this.castDur) this._startWaiting();
        return;
      }
      if (this.phase === "hooking") {
        this.hookT += dt;
        if (this.hookT >= this.hookDur) this._startReeling();
        return;
      }
      if (this.phase === "waiting" && this.t >= this.waitUntil) this.triggerBite();
      if (this.phase === "bite") {
        this.bobDip = Math.sin(this.t * 28) * 6;
        if (this.t >= this.biteUntil) {
          UI.toast(`${this.fish.emoji} 놓쳤다! 너무 늦었어요`, "warn");
          this.endToWorld();
        }
      } else { this.bobDip *= 0.9; }
      if (this.phase === "reeling") this.updateReel(dt);
    },

    updateReel(dt) {
      // --- player zone physics (hold = up, gravity = down) ---
      // base is snappier than before; a better rod (agility) makes it faster still
      const grav = 2.0 * this.agility, lift = 3.4 * this.agility;
      this.zoneVel += (this.holding ? lift : -grav) * dt;
      this.zoneVel *= 0.86;
      this.zonePos += this.zoneVel * dt;
      if (this.zonePos < 0) { this.zonePos = 0; this.zoneVel = 0; }
      if (this.zonePos > 1) { this.zonePos = 1; this.zoneVel = 0; }

      // --- fish AI: pick a new target periodically, erratic with difficulty ---
      this.fishTimer -= dt;
      if (this.fishTimer <= 0) {
        this.fishTarget = Math.random();
        this.fishTimer = Math.max(0.25, 1.1 - this.diff * 0.12) * (0.6 + Math.random() * 0.8);
      }
      const fishSpeed = 1.1 + this.diff * 0.35;
      this.fishPos += (this.fishTarget - this.fishPos) * Math.min(1, fishSpeed * dt);

      // --- progress: in-zone fills, out drains ---
      const half = this.zoneH / 2;
      const inZone = Math.abs(this.fishPos - this.zonePos) <= half;
      this.progress += (inZone ? 0.42 : -(0.26 + (this.diff - 1) * 0.05)) * dt;
      if (this.progress >= 1) { this.progress = 1; this.finishCatch(true); }
      else if (this.progress <= 0) { this.progress = 0; this.finishCatch(false); }
    },

    // ---- draw overlay (on top of world) --------------------------------
    drawOverlay(ctx, W, H) {
      this.W = W; this.H = H;
      if (this.phase === "casting") { this.drawCast(ctx); return; }
      if (this.phase === "hooking") { this.drawHook(ctx); return; }
      if (this.phase === "waiting" || this.phase === "bite") {
        const bx = this.bobberX, by = this.bobberY + this.bobDip + Math.sin(this.t * 2) * 2;
        ctx.strokeStyle = "rgba(255,255,255,.7)"; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(this.originX, this.originY); ctx.lineTo(bx, by); ctx.stroke();
        ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(bx, by, 6, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = "#e84a5f"; ctx.beginPath(); ctx.arc(bx, by - 1, 6, Math.PI, 0); ctx.fill();
        // ripple ring
        const rr = (this.t * 30) % 30;
        ctx.strokeStyle = `rgba(255,255,255,${0.4 - rr / 75})`;
        ctx.beginPath(); ctx.ellipse(bx, by + 3, rr, rr / 2.5, 0, 0, Math.PI * 2); ctx.stroke();
        if (this.phase === "bite") {
          ctx.fillStyle = "#fff"; ctx.font = "bold 26px sans-serif"; ctx.textAlign = "center";
          ctx.fillText("❗", bx, by - 16 + Math.sin(this.t * 20) * 3);
        }
      }
      if (this.phase === "reeling") this.drawReel(ctx, W, H);
    },

    // the line arcing out toward the water while the rod swings
    drawCast(ctx) {
      const p = this.castDur ? Math.min(1, this.castT / this.castDur) : 1;
      const fly = Math.max(0, (p - 0.4) / 0.6);   // line shoots out in the back half of the swing
      if (fly <= 0) return;
      const sx = this.originX, sy = this.originY;
      const bx = sx + (this.bobberX - sx) * fly;
      const by = sy + (this.bobberY - sy) * fly - Math.sin(Math.PI * fly) * 28;  // little arc
      ctx.strokeStyle = "rgba(255,255,255,.7)"; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(bx, by); ctx.stroke();
      ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(bx, by, 5, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = "#e84a5f"; ctx.beginPath(); ctx.arc(bx, by - 1, 5, Math.PI, 0); ctx.fill();
    },

    // the hook-set yank: bobber snaps up out of the water with a splash
    drawHook(ctx) {
      const p = this.hookDur ? Math.min(1, this.hookT / this.hookDur) : 1;
      const jerk = Math.sin(Math.min(1, p) * Math.PI) * 20;   // rise then settle
      const bx = this.bobberX, by = this.bobberY - jerk;
      ctx.strokeStyle = "rgba(255,255,255,.85)"; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(this.originX, this.originY); ctx.lineTo(bx, by); ctx.stroke();
      ctx.fillStyle = "rgba(255,255,255,.85)";
      for (let i = 0; i < 4; i++) {
        const a = (i / 3) * Math.PI - Math.PI / 2, r = 6 + p * 10;
        ctx.beginPath(); ctx.arc(bx + Math.cos(a) * r, by + 3 + Math.sin(a) * r * 0.5, 1.6, 0, Math.PI * 2); ctx.fill();
      }
      ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(bx, by, 5, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = "#e84a5f"; ctx.beginPath(); ctx.arc(bx, by - 1, 5, Math.PI, 0); ctx.fill();
    },

    drawReel(ctx, W, H) {
      ctx.fillStyle = "rgba(8,20,32,.5)"; ctx.fillRect(0, 0, W, H);
      const barX = W * 0.5 - 30, barW = 60, barY = H * 0.14, barH = H * 0.62;
      ctx.fillStyle = "rgba(255,255,255,.12)"; roundRect(ctx, barX, barY, barW, barH, 14); ctx.fill();

      // catch zone (green)
      const zoneCenter = barY + (1 - this.zonePos) * barH, zonePx = this.zoneH * barH;
      ctx.fillStyle = "rgba(110,220,150,.55)";
      roundRect(ctx, barX + 4, zoneCenter - zonePx / 2, barW - 8, zonePx, 10); ctx.fill();

      // fish marker (swimming art)
      const fishY = barY + (1 - this.fishPos) * barH;
      if (window.FishArt && this.fish) FishArt.draw(ctx, this.fish.id, barX + barW / 2, fishY, 22, { t: this.t });
      else { ctx.font = "26px sans-serif"; ctx.textAlign = "center"; ctx.fillText(this.fish ? this.fish.emoji : "🐟", barX + barW / 2, fishY + 9); }

      // progress bar (right side)
      const pX = barX + barW + 18, pW = 16;
      ctx.fillStyle = "rgba(255,255,255,.15)"; roundRect(ctx, pX, barY, pW, barH, 8); ctx.fill();
      const fillH = this.progress * barH;
      const grad = ctx.createLinearGradient(0, barY + barH, 0, barY);
      grad.addColorStop(0, "#ffd34d"); grad.addColorStop(1, "#6fe3a0");
      ctx.fillStyle = grad; roundRect(ctx, pX, barY + barH - fillH, pW, fillH, 8); ctx.fill();

      // title + hint
      ctx.fillStyle = "#fff"; ctx.font = "bold 16px sans-serif"; ctx.textAlign = "center";
      ctx.fillText(this.fish.name, W / 2, barY - 20);
      const r = DATA.RARITY[this.fish.rarity];
      ctx.fillStyle = r.color; ctx.font = "bold 12px sans-serif";
      ctx.fillText(r.label, W / 2, barY - 4);
      ctx.fillStyle = "rgba(255,255,255,.85)"; ctx.font = "12px sans-serif";
      ctx.fillText("초록 칸에 물고기를 가두세요 (스페이스바 꾹! ↑)", W / 2, barY + barH + 24);
    },
  };

  function roundRect(ctx, x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    ctx.beginPath(); ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath();
  }

  window.Fishing = Fishing;
})();
