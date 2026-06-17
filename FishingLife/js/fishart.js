/* =========================================================================
   FishingLife - FishArt: draws species-like fish with canvas vector art.
   Each fish/creature/junk has parameters that shape a recognizable drawing.
   Used in the reeling minigame (animated) and as cached data-URLs in panels.
   All kind() functions draw in a normalized space (length ~ -1..1, facing +x).
   ========================================================================= */
(function () {
  "use strict";

  // ART[id] = { kind, c1(back), c2(mid), belly, fin, pat, patC, height, tail, glow, whiskers }
  const ART = {
    // ---- pond ----
    minnow:   { kind: "fish", c1: "#8a9a6b", c2: "#cfd6bf", belly: 0.9, fin: "#b8c0a0", height: 0.38, tail: "fork", pat: "stripe", patC: "rgba(80,110,70,.4)" },
    carp:     { kind: "round", c1: "#b07a32", c2: "#e0b266", belly: 1.0, fin: "#caa05a", height: 0.62, tail: "fan", pat: "scales", patC: "rgba(120,80,30,.25)", whiskers: true },
    crucian:  { kind: "round", c1: "#7d6a3a", c2: "#c7b274", belly: 1.0, fin: "#a8965e", height: 0.66, tail: "fan", pat: "scales", patC: "rgba(90,75,40,.2)" },
    goldfish: { kind: "round", c1: "#ff7a18", c2: "#ffb050", belly: 1.0, fin: "#ff9a3a", height: 0.7, tail: "fancy", pat: "none" },
    loach:    { kind: "eel", c1: "#5b4a32", c2: "#8a7350", belly: 0.8, fin: "#6f5b3c", height: 0.32, whiskers: true, pat: "spots", patC: "rgba(40,30,20,.4)" },
    frog:     { kind: "frog", c1: "#5a8a3a", c2: "#7fb454", belly: "#dfe6b0" },

    // ---- river ----
    trout:    { kind: "fish", c1: "#5f7a4a", c2: "#cdd6c2", belly: 0.95, fin: "#9aa888", height: 0.46, tail: "fan", pat: "troutspots", patC: "rgba(40,55,35,.55)", stripe: "rgba(220,90,120,.5)" },
    smallmouth:{ kind: "fish", c1: "#5a6a3e", c2: "#b9b07a", belly: 0.95, fin: "#8a8052", height: 0.52, tail: "fan", pat: "bars", patC: "rgba(50,60,35,.3)" },
    catfish:  { kind: "catfish", c1: "#4a4a4f", c2: "#8a8a86", belly: 0.95, fin: "#5f5f5a", height: 0.5, tail: "fan", whiskers: true, pat: "none" },
    eel:      { kind: "eel", c1: "#3f4a3a", c2: "#7a8a5f", belly: 0.7, fin: "#55603f", height: 0.3, pat: "none" },
    sweetfish:{ kind: "fish", c1: "#7a8a6a", c2: "#dfe4d2", belly: 0.9, fin: "#cfae50", height: 0.4, tail: "fork", pat: "none" },

    // ---- valley ----
    chargr:   { kind: "fish", c1: "#3f5a5f", c2: "#9fb0a8", belly: 0.95, fin: "#e88a4a", height: 0.46, tail: "fan", pat: "lightspots", patC: "rgba(245,200,160,.7)" },
    masu:     { kind: "fish", c1: "#6a7a52", c2: "#c8cbb0", belly: 0.95, fin: "#9aa080", height: 0.46, tail: "fan", pat: "parr", patC: "rgba(60,70,45,.45)", stripe: "rgba(210,90,90,.4)" },
    gudgeon:  { kind: "fish", c1: "#7a6a4a", c2: "#c2b48c", belly: 0.9, fin: "#9a8a60", height: 0.36, tail: "fork", pat: "spots", patC: "rgba(60,50,30,.35)" },
    graytrout:{ kind: "fish", c1: "#7a6a3a", c2: "#d8c886", belly: 0.95, fin: "#b09a52", height: 0.48, tail: "fan", pat: "troutspots", patC: "rgba(60,50,25,.5)" },
    crystalfish:{ kind: "fish", c1: "#6fd8e8", c2: "#d8f6ff", belly: 0.95, fin: "#9fe8f4", height: 0.5, tail: "fan", pat: "none", glow: "rgba(140,230,255,.5)", crystal: true },

    // ---- lake ----
    pike:     { kind: "long", c1: "#5a6a40", c2: "#bcc08a", belly: 0.92, fin: "#8a9060", height: 0.42, tail: "fan", pat: "lightspots", patC: "rgba(230,235,200,.55)" },
    lakefish: { kind: "fish", c1: "#5a6a4a", c2: "#cdd2bc", belly: 0.95, fin: "#9aa088", height: 0.52, tail: "fan", pat: "troutspots", patC: "rgba(45,55,35,.5)", stripe: "rgba(210,100,120,.4)" },
    turtle:   { kind: "turtle", c1: "#5a6a3a", c2: "#7f8a4a", belly: "#cdb87a" },
    mandarin: { kind: "fish", c1: "#7a6a3a", c2: "#d8c47a", belly: 0.95, fin: "#a07a40", height: 0.55, tail: "fan", pat: "blotch", patC: "rgba(70,55,25,.5)" },

    // ---- sea ----
    mackerel: { kind: "tuna", c1: "#2f5a7a", c2: "#cfe0ea", belly: 0.95, fin: "#5a7a90", height: 0.42, tail: "fork", pat: "wavy", patC: "rgba(20,45,75,.6)" },
    snapper:  { kind: "round", c1: "#d8506a", c2: "#ff9aab", belly: 0.95, fin: "#e0607a", height: 0.62, tail: "fork", pat: "speckle", patC: "rgba(120,180,220,.55)" },
    tuna:     { kind: "tuna", c1: "#2a3f6a", c2: "#9fb0c8", belly: 0.95, fin: "#ffd24a", height: 0.5, tail: "fork", pat: "none" },
    squid:    { kind: "squid", c1: "#e8a8b0", c2: "#f4d0d4", fin: "#d88a94" },
    octopus:  { kind: "octopus", c1: "#c85a6a", c2: "#e88a96" },
    shark:    { kind: "shark", c1: "#5a6a78", c2: "#aeb8c2", belly: "#e6ecf0" },
    marlin:   { kind: "marlin", c1: "#2a4a8a", c2: "#9fc0e8", belly: "#eef4fb", fin: "#3a5aa0" },
    jellyfish:{ kind: "jelly", c1: "rgba(180,200,235,.7)", c2: "rgba(210,225,245,.5)" },

    // ---- cave ----
    blindfish:{ kind: "fish", c1: "#e8d0d6", c2: "#fbeef0", belly: 0.95, fin: "#e0c0c8", height: 0.42, tail: "fan", pat: "none", noEye: true },
    glowfish: { kind: "fish", c1: "#1f3a4a", c2: "#2f5a6a", belly: 0.9, fin: "#3f7a8a", height: 0.46, tail: "fan", pat: "glowspots", patC: "#7fffd0", glow: "rgba(80,240,200,.45)" },
    axolotl:  { kind: "axolotl", c1: "#f2a8b6", c2: "#ffd0d8", fin: "#ff8aa0", glow: "rgba(255,170,200,.3)" },
    cavedragon:{ kind: "dragon", c1: "#243a44", c2: "#3f6a72", belly: "#1a2a30", fin: "#5fd8c0", glow: "rgba(80,220,200,.4)" },

    // ---- moon ----
    moonjelly:{ kind: "jelly", c1: "rgba(200,220,255,.8)", c2: "rgba(230,240,255,.55)", glow: "rgba(180,210,255,.55)" },
    starfish: { kind: "star", c1: "#e8943a", c2: "#ffbf6a" },
    lunarkoi: { kind: "round", c1: "#f4f4f8", c2: "#ffffff", belly: 1.0, fin: "#e0e0ea", height: 0.66, tail: "fancy", pat: "koi", patC: "#e8623f", glow: "rgba(220,230,255,.5)" },
    leviathan:{ kind: "dragon", c1: "#1f3a3f", c2: "#2f6a64", belly: "#15282a", fin: "#4fd0b8", glow: "rgba(70,210,190,.4)", big: true },
    kraken:   { kind: "octopus", c1: "#6a2a3a", c2: "#9a3a4a", glow: "rgba(160,40,60,.35)", big: true },

    // ---- junk ----
    boot:     { kind: "boot" },
    can:      { kind: "can" },
    seaweed:  { kind: "weed" },
    treasure: { kind: "chest" },
  };

  function fallback(id) {
    const f = window.DATA && DATA.fishById(id);
    const col = (f && DATA.RARITY[f.rarity].color) || "#7fb0d0";
    return { kind: "fish", c1: col, c2: "#dfe9f0", belly: 0.95, fin: col, height: 0.5, tail: "fan", pat: "none" };
  }

  // ---------- generic smooth fish body ----------
  function bodyPath(ctx, L, H, belly) {
    ctx.beginPath();
    ctx.moveTo(-L, 0);
    ctx.bezierCurveTo(-L * 0.6, -H, L * 0.15, -H, L * 0.72, -H * 0.4);
    ctx.quadraticCurveTo(L * 1.02, -H * 0.18, L * 1.02, 0);
    ctx.quadraticCurveTo(L * 1.02, H * 0.18 * belly, L * 0.72, H * 0.4 * belly);
    ctx.bezierCurveTo(L * 0.15, H * belly, -L * 0.6, H * belly, -L, 0);
    ctx.closePath();
  }

  function applyPattern(ctx, p, L, H) {
    const pat = p.pat;
    if (pat === "stripe" && p.patC) { ctx.fillStyle = p.patC; ctx.fillRect(-L, -H * 0.12, 2 * L, H * 0.22); }
    if (p.stripe) { ctx.fillStyle = p.stripe; ctx.fillRect(-L, -H * 0.08, 2 * L, H * 0.18); }
    if (pat === "bars") {
      ctx.fillStyle = p.patC; for (let x = -L * 0.5; x < L * 0.8; x += L * 0.32) ctx.fillRect(x, -H, L * 0.1, 2 * H);
    } else if (pat === "parr") {
      ctx.fillStyle = p.patC; for (let x = -L * 0.55; x < L * 0.8; x += L * 0.28) { ctx.beginPath(); ctx.ellipse(x, 0, L * 0.06, H * 0.5, 0, 0, 7); ctx.fill(); }
    } else if (pat === "spots" || pat === "troutspots") {
      ctx.fillStyle = p.patC;
      const pts = [[-0.45, -0.25], [-0.15, 0.15], [0.2, -0.3], [0.05, -0.5], [0.45, 0.05], [-0.3, 0.4], [0.2, 0.4], [-0.55, 0.1], [0.5, -0.3]];
      const s = pat === "troutspots" ? 0.1 : 0.09;
      pts.forEach(([x, y]) => { ctx.beginPath(); ctx.arc(x * L, y * H * 1.4, H * s, 0, 7); ctx.fill(); });
    } else if (pat === "lightspots") {
      ctx.fillStyle = p.patC;
      for (let i = 0; i < 12; i++) { const x = (-0.6 + (i % 4) * 0.4) * L, y = (-0.4 + Math.floor(i / 4) * 0.4) * H; ctx.beginPath(); ctx.ellipse(x, y, H * 0.13, H * 0.08, 0, 0, 7); ctx.fill(); }
    } else if (pat === "glowspots") {
      ctx.fillStyle = p.patC;
      [[-0.4, -0.2], [-0.1, 0.2], [0.25, -0.1], [0.0, -0.4], [0.4, 0.2]].forEach(([x, y]) => { ctx.beginPath(); ctx.arc(x * L, y * H, H * 0.1, 0, 7); ctx.fill(); });
    } else if (pat === "wavy") {
      ctx.strokeStyle = p.patC; ctx.lineWidth = 0.045;
      for (let i = 0; i < 4; i++) { ctx.beginPath(); for (let x = -L; x <= L; x += 0.08) ctx.lineTo(x, -H * 0.55 + i * H * 0.28 + Math.sin(x * 7) * 0.05); ctx.stroke(); }
    } else if (pat === "scales") {
      ctx.strokeStyle = p.patC; ctx.lineWidth = 0.02;
      for (let r = 0; r < 4; r++) for (let c = 0; c < 6; c++) { const x = -L * 0.6 + c * L * 0.26, y = -H * 0.5 + r * H * 0.34; ctx.beginPath(); ctx.arc(x, y, H * 0.16, 0.2, Math.PI - 0.2); ctx.stroke(); }
    } else if (pat === "blotch") {
      ctx.fillStyle = p.patC;
      [[-0.4, -0.1, 0.3], [0.1, 0.1, 0.28], [0.45, -0.2, 0.2], [-0.1, -0.4, 0.22]].forEach(([x, y, r]) => { ctx.beginPath(); ctx.ellipse(x * L, y * H, r * L, r * H * 1.2, 0.3, 0, 7); ctx.fill(); });
    } else if (pat === "speckle") {
      ctx.fillStyle = p.patC;
      for (let i = 0; i < 14; i++) { const x = (Math.sin(i * 12.9) * 0.6) * L, y = (Math.cos(i * 7.1) * 0.5) * H; ctx.beginPath(); ctx.arc(x, y, H * 0.05, 0, 7); ctx.fill(); }
    } else if (pat === "koi" && p.patC) {
      ctx.fillStyle = p.patC;
      [[-0.3, -0.1, 0.34], [0.25, 0.05, 0.27], [0.55, -0.2, 0.16]].forEach(([x, y, r]) => { ctx.beginPath(); ctx.ellipse(x * L, y * H, r, r * 0.85, 0, 0, 7); ctx.fill(); });
    }
  }

  function eye(ctx, x, y, r, noEye) {
    if (noEye) { ctx.strokeStyle = "rgba(120,90,90,.5)"; ctx.lineWidth = 0.02; ctx.beginPath(); ctx.moveTo(x - r, y); ctx.lineTo(x + r, y); ctx.stroke(); return; }
    ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.fill();
    ctx.fillStyle = "#16242e"; ctx.beginPath(); ctx.arc(x + r * 0.25, y, r * 0.55, 0, 7); ctx.fill();
    ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(x + r * 0.05, y - r * 0.25, r * 0.18, 0, 7); ctx.fill();
  }

  const KIND = {
    fish(ctx, p, t) { drawFish(ctx, p, t, 0.82); },
    long(ctx, p, t) { drawFish(ctx, p, t, 1.0, 0.7); },     // pike: longer, lower body
    round(ctx, p, t) { drawFish(ctx, p, t, 0.74); },         // tall body via height param
    tuna(ctx, p, t) { drawFish(ctx, p, t, 0.88, 1, true); }, // pointed nose + fork

    eel(ctx, p, t) {
      const H = p.height;
      ctx.lineJoin = "round";
      const grad = ctx.createLinearGradient(0, -H, 0, H);
      grad.addColorStop(0, p.c1); grad.addColorStop(1, p.c2);
      ctx.fillStyle = grad; ctx.beginPath();
      const top = [], bot = [];
      for (let i = 0; i <= 20; i++) {
        const x = -1 + i / 10;            // -1..1
        const yc = Math.sin(x * 3 + t * 4) * 0.12;
        const h = H * (1 - Math.abs(x) * 0.35) * (x > 0.8 ? (1 - x) * 5 : 1);
        top.push([x, yc - h]); bot.push([x, yc + h]);
      }
      ctx.moveTo(top[0][0], top[0][1]);
      top.forEach(pt => ctx.lineTo(pt[0], pt[1]));
      for (let i = bot.length - 1; i >= 0; i--) ctx.lineTo(bot[i][0], bot[i][1]);
      ctx.closePath(); ctx.fill();
      ctx.strokeStyle = "rgba(0,0,0,.2)"; ctx.lineWidth = 0.025; ctx.stroke();
      if (p.pat) { ctx.save(); ctx.clip(); applyPattern(ctx, p, 0.9, H); ctx.restore(); }
      const hx = 0.9, hy = Math.sin(3 + t * 4) * 0.12;
      eye(ctx, hx, hy - H * 0.2, H * 0.2, p.noEye);
      if (p.whiskers) { ctx.strokeStyle = p.c1; ctx.lineWidth = 0.018; for (const s of [-1, 1]) { ctx.beginPath(); ctx.moveTo(hx, hy + H * 0.1); ctx.quadraticCurveTo(hx + 0.15, hy + 0.1 * s + 0.1, hx + 0.25, hy + 0.2 * s); ctx.stroke(); } }
    },

    catfish(ctx, p, t) {
      drawFish(ctx, p, t, 0.8, 1.05);
      // big whiskers drawn over
      const wig = Math.sin(t * 5) * 0.05;
      ctx.strokeStyle = p.c1; ctx.lineWidth = 0.02;
      for (const s of [-1, 1]) {
        ctx.beginPath(); ctx.moveTo(0.7, 0.05 * s);
        ctx.quadraticCurveTo(1.0, 0.2 * s + wig, 1.25, 0.4 * s + wig); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(0.72, 0.12 * s);
        ctx.quadraticCurveTo(0.95, 0.35 * s, 1.1, 0.55 * s + wig); ctx.stroke();
      }
    },

    shark(ctx, p, t) {
      const wig = Math.sin(t * 5) * 0.08;
      ctx.fillStyle = p.c1;
      // tail (crescent)
      ctx.beginPath(); ctx.moveTo(-0.8, 0);
      ctx.lineTo(-1.15, -0.45 + wig); ctx.lineTo(-0.95, 0); ctx.lineTo(-1.1, 0.4 + wig); ctx.closePath(); ctx.fill();
      // body
      ctx.beginPath();
      ctx.moveTo(-0.85, 0);
      ctx.bezierCurveTo(-0.5, -0.42, 0.4, -0.4, 1.05, -0.05);
      ctx.bezierCurveTo(0.6, 0.05, 0.2, 0.4, -0.2, 0.42);
      ctx.quadraticCurveTo(-0.6, 0.4, -0.85, 0); ctx.closePath();
      const g = ctx.createLinearGradient(0, -0.4, 0, 0.4); g.addColorStop(0, p.c1); g.addColorStop(0.6, p.c2); g.addColorStop(1, p.belly);
      ctx.fillStyle = g; ctx.fill();
      // dorsal fin
      ctx.fillStyle = p.c1; ctx.beginPath();
      ctx.moveTo(-0.05, -0.38); ctx.lineTo(0.25, -0.95); ctx.lineTo(0.35, -0.32); ctx.closePath(); ctx.fill();
      // pectoral
      ctx.beginPath(); ctx.moveTo(0.35, 0.2); ctx.lineTo(0.2, 0.7); ctx.lineTo(0.6, 0.35); ctx.closePath(); ctx.fill();
      // gills
      ctx.strokeStyle = "rgba(0,0,0,.2)"; ctx.lineWidth = 0.02;
      for (let i = 0; i < 4; i++) { ctx.beginPath(); ctx.moveTo(0.55 + i * 0.05, -0.25); ctx.lineTo(0.5 + i * 0.05, 0.2); ctx.stroke(); }
      eye(ctx, 0.78, -0.12, 0.07);
      // mouth
      ctx.strokeStyle = "rgba(0,0,0,.45)"; ctx.lineWidth = 0.025;
      ctx.beginPath(); ctx.moveTo(1.05, -0.05); ctx.quadraticCurveTo(0.85, 0.18, 0.7, 0.16); ctx.stroke();
    },

    marlin(ctx, p, t) {
      drawFish(ctx, { ...p, height: 0.42, tail: "fork", pat: "none" }, t, 0.78, 1, true);
      // long bill
      ctx.strokeStyle = p.c1; ctx.lineWidth = 0.06; ctx.lineCap = "round";
      ctx.beginPath(); ctx.moveTo(0.8, -0.05); ctx.lineTo(1.5, -0.12); ctx.stroke();
      // tall sail dorsal
      ctx.fillStyle = p.fin; ctx.beginPath();
      ctx.moveTo(-0.1, -0.35); ctx.quadraticCurveTo(0.2, -1.1, 0.5, -0.3); ctx.closePath(); ctx.fill();
    },

    squid(ctx, p, t) {
      const wig = Math.sin(t * 4);
      const g = ctx.createLinearGradient(0, -1, 0, 0.4); g.addColorStop(0, p.c1); g.addColorStop(1, p.c2);
      // mantle (pointing right = head down-left)
      ctx.fillStyle = g; ctx.beginPath();
      ctx.moveTo(0.2, -0.95); ctx.quadraticCurveTo(0.55, -0.2, 0.3, 0.2);
      ctx.quadraticCurveTo(0, 0.35, -0.3, 0.2); ctx.quadraticCurveTo(-0.05, -0.2, -0.1, -0.95);
      ctx.quadraticCurveTo(0.05, -1.1, 0.2, -0.95); ctx.closePath(); ctx.fill();
      // fins at top
      ctx.fillStyle = p.fin; ctx.beginPath(); ctx.ellipse(0.05, -0.9, 0.35, 0.18, 0, 0, 7); ctx.fill();
      // tentacles at bottom
      ctx.strokeStyle = p.c2; ctx.lineWidth = 0.08; ctx.lineCap = "round";
      for (let i = -3; i <= 3; i++) {
        ctx.beginPath(); ctx.moveTo(i * 0.07, 0.2);
        ctx.quadraticCurveTo(i * 0.12 + wig * 0.1, 0.7, i * 0.16 + Math.sin(t * 3 + i) * 0.1, 1.0); ctx.stroke();
      }
      eye(ctx, -0.12, -0.1, 0.1); eye(ctx, 0.18, -0.1, 0.1);
    },

    octopus(ctx, p, t) {
      const g = ctx.createRadialGradient(0, -0.2, 0.1, 0, -0.2, 0.8); g.addColorStop(0, p.c2); g.addColorStop(1, p.c1);
      // legs
      ctx.strokeStyle = p.c1; ctx.lineWidth = 0.12; ctx.lineCap = "round";
      for (let i = -4; i <= 4; i++) {
        const ph = t * 3 + i;
        ctx.beginPath(); ctx.moveTo(i * 0.08, 0.1);
        ctx.quadraticCurveTo(i * 0.18, 0.6 + Math.sin(ph) * 0.1, i * 0.26 + Math.sin(ph) * 0.12, 0.95); ctx.stroke();
      }
      // head/mantle
      ctx.fillStyle = g; ctx.beginPath(); ctx.ellipse(0, -0.25, 0.62, 0.7, 0, 0, 7); ctx.fill();
      eye(ctx, -0.22, -0.25, 0.13); eye(ctx, 0.22, -0.25, 0.13);
    },

    turtle(ctx, p, t) {
      // flippers
      ctx.fillStyle = p.c1;
      ctx.beginPath(); ctx.ellipse(-0.55, 0.25, 0.3, 0.16, -0.5, 0, 7); ctx.fill();
      ctx.beginPath(); ctx.ellipse(0.45, 0.3, 0.28, 0.15, 0.6, 0, 7); ctx.fill();
      // head
      ctx.fillStyle = p.c2; ctx.beginPath(); ctx.ellipse(0.7, -0.1, 0.22, 0.17, 0, 0, 7); ctx.fill();
      eye(ctx, 0.78, -0.12, 0.05);
      // shell
      const g = ctx.createLinearGradient(0, -0.6, 0, 0.4); g.addColorStop(0, p.c2); g.addColorStop(1, p.c1);
      ctx.fillStyle = g; ctx.beginPath(); ctx.ellipse(0, -0.05, 0.62, 0.5, 0, 0, 7); ctx.fill();
      ctx.strokeStyle = "rgba(0,0,0,.25)"; ctx.lineWidth = 0.022;
      ctx.beginPath(); ctx.ellipse(0, -0.05, 0.42, 0.32, 0, 0, 7); ctx.stroke();
      for (let a = 0; a < 6; a++) { const an = a / 6 * Math.PI * 2; ctx.beginPath(); ctx.moveTo(Math.cos(an) * 0.42, -0.05 + Math.sin(an) * 0.32); ctx.lineTo(Math.cos(an) * 0.62, -0.05 + Math.sin(an) * 0.5); ctx.stroke(); }
    },

    frog(ctx, p, t) {
      ctx.fillStyle = p.c1;
      // back legs
      ctx.beginPath(); ctx.ellipse(-0.5, 0.35, 0.28, 0.18, 0.5, 0, 7); ctx.fill();
      ctx.beginPath(); ctx.ellipse(0.5, 0.35, 0.28, 0.18, -0.5, 0, 7); ctx.fill();
      const g = ctx.createLinearGradient(0, -0.6, 0, 0.5); g.addColorStop(0, p.c2); g.addColorStop(0.7, p.c1); g.addColorStop(1, p.belly);
      ctx.fillStyle = g; ctx.beginPath(); ctx.ellipse(0, 0.05, 0.62, 0.5, 0, 0, 7); ctx.fill();
      // eyes bulging on top
      for (const s of [-1, 1]) {
        ctx.fillStyle = p.c2; ctx.beginPath(); ctx.arc(s * 0.28, -0.45, 0.2, 0, 7); ctx.fill();
        ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(s * 0.28, -0.45, 0.12, 0, 7); ctx.fill();
        ctx.fillStyle = "#1a2a10"; ctx.beginPath(); ctx.arc(s * 0.28, -0.45, 0.06, 0, 7); ctx.fill();
      }
      ctx.strokeStyle = "rgba(0,0,0,.3)"; ctx.lineWidth = 0.025;
      ctx.beginPath(); ctx.arc(0, 0.0, 0.4, 0.2, Math.PI - 0.2); ctx.stroke();
    },

    jelly(ctx, p, t) {
      const g = ctx.createRadialGradient(0, -0.2, 0.1, 0, -0.2, 0.7); g.addColorStop(0, p.c2); g.addColorStop(1, p.c1);
      ctx.fillStyle = g; ctx.beginPath();
      ctx.moveTo(-0.6, -0.1); ctx.quadraticCurveTo(-0.6, -0.85, 0, -0.85); ctx.quadraticCurveTo(0.6, -0.85, 0.6, -0.1);
      ctx.quadraticCurveTo(0.3, 0.05, 0.2, -0.1); ctx.quadraticCurveTo(0, 0.08, -0.2, -0.1); ctx.quadraticCurveTo(-0.3, 0.05, -0.6, -0.1);
      ctx.closePath(); ctx.fill();
      ctx.strokeStyle = p.c1; ctx.lineWidth = 0.04; ctx.lineCap = "round";
      for (let i = -3; i <= 3; i++) { ctx.beginPath(); ctx.moveTo(i * 0.13, -0.1); ctx.quadraticCurveTo(i * 0.13 + Math.sin(t * 3 + i) * 0.08, 0.5, i * 0.1, 0.95); ctx.stroke(); }
    },

    star(ctx, p, t) {
      const g = ctx.createRadialGradient(0, 0, 0.1, 0, 0, 0.9); g.addColorStop(0, p.c2); g.addColorStop(1, p.c1);
      ctx.fillStyle = g; ctx.beginPath();
      for (let i = 0; i < 10; i++) { const an = -Math.PI / 2 + i * Math.PI / 5; const r = i % 2 ? 0.34 : 0.9; const x = Math.cos(an) * r, y = Math.sin(an) * r; i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); }
      ctx.closePath(); ctx.fill();
      ctx.fillStyle = "rgba(255,255,255,.5)";
      for (let i = 0; i < 5; i++) { const an = -Math.PI / 2 + i * 2 * Math.PI / 5; ctx.beginPath(); ctx.arc(Math.cos(an) * 0.45, Math.sin(an) * 0.45, 0.05, 0, 7); ctx.fill(); }
    },

    axolotl(ctx, p, t) {
      drawFish(ctx, { ...p, height: 0.4, tail: "fan", fin: p.fin, c1: p.c1, c2: p.c2, belly: 0.95, pat: "none" }, t, 0.78);
      // frilly external gills behind head
      ctx.strokeStyle = p.fin; ctx.lineWidth = 0.04; ctx.lineCap = "round";
      for (let i = -1; i <= 1; i++) { for (const s of [-1, 1]) { ctx.beginPath(); ctx.moveTo(0.55, -0.1 * s); ctx.quadraticCurveTo(0.85, (-0.3 + i * 0.15) * s, 1.0, (-0.4 + i * 0.2) * s); ctx.stroke(); } }
      // smile
      ctx.strokeStyle = "rgba(150,80,100,.6)"; ctx.lineWidth = 0.025;
      ctx.beginPath(); ctx.arc(0.7, 0.0, 0.18, 0.1, 1.2); ctx.stroke();
    },

    dragon(ctx, p, t) {
      const H = p.big ? 0.34 : 0.3;
      const grad = ctx.createLinearGradient(0, -H, 0, H); grad.addColorStop(0, p.c2); grad.addColorStop(1, p.c1);
      ctx.fillStyle = grad; ctx.beginPath();
      const top = [], bot = [];
      for (let i = 0; i <= 24; i++) {
        const x = -1 + i / 12; const yc = Math.sin(x * 3.2 + t * 3) * 0.18;
        const h = H * (1 - Math.abs(x) * 0.3) * (x > 0.82 ? (1 - x) * 5.5 : 1);
        top.push([x, yc - h]); bot.push([x, yc + h]);
      }
      ctx.moveTo(top[0][0], top[0][1]); top.forEach(pt => ctx.lineTo(pt[0], pt[1]));
      for (let i = bot.length - 1; i >= 0; i--) ctx.lineTo(bot[i][0], bot[i][1]);
      ctx.closePath(); ctx.fill();
      // dorsal spikes along the back
      ctx.fillStyle = p.fin;
      for (let i = 2; i < top.length - 2; i += 2) { const [x, y] = top[i]; ctx.beginPath(); ctx.moveTo(x - 0.04, y); ctx.lineTo(x, y - 0.18); ctx.lineTo(x + 0.04, y); ctx.closePath(); ctx.fill(); }
      const hx = 1.0, hy = Math.sin(3.2 + t * 3) * 0.18;
      // horns
      ctx.strokeStyle = p.fin; ctx.lineWidth = 0.04; ctx.lineCap = "round";
      ctx.beginPath(); ctx.moveTo(hx - 0.1, hy - H * 0.6); ctx.lineTo(hx + 0.05, hy - H * 1.4); ctx.stroke();
      // glowing eye
      ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(hx - 0.02, hy - H * 0.3, 0.08, 0, 7); ctx.fill();
      ctx.fillStyle = p.fin; ctx.beginPath(); ctx.arc(hx - 0.02, hy - H * 0.3, 0.045, 0, 7); ctx.fill();
    },

    // ---- junk ----
    boot(ctx) {
      ctx.fillStyle = "#5a4636"; ctx.beginPath();
      ctx.moveTo(-0.35, -0.7); ctx.lineTo(0.05, -0.7); ctx.lineTo(0.05, 0.2); ctx.lineTo(0.7, 0.2);
      ctx.quadraticCurveTo(0.85, 0.2, 0.85, 0.45); ctx.lineTo(-0.35, 0.45); ctx.closePath(); ctx.fill();
      ctx.fillStyle = "#3a2c20"; ctx.fillRect(-0.4, 0.45, 1.3, 0.12);
      ctx.strokeStyle = "#7a6452"; ctx.lineWidth = 0.03; ctx.strokeRect(-0.32, -0.6, 0.3, 0.7);
    },
    can(ctx) {
      ctx.fillStyle = "#b9c2c8"; ctx.beginPath(); ctx.ellipse(0, -0.55, 0.4, 0.12, 0, 0, 7); ctx.fill();
      ctx.fillRect(-0.4, -0.55, 0.8, 1.0);
      ctx.fillStyle = "#9aa4ab"; ctx.beginPath(); ctx.ellipse(0, 0.45, 0.4, 0.12, 0, 0, 7); ctx.fill();
      ctx.fillStyle = "#d6dde1"; ctx.fillRect(-0.3, -0.3, 0.18, 0.7);
      ctx.strokeStyle = "#8a949b"; ctx.lineWidth = 0.02; ctx.strokeRect(-0.4, -0.55, 0.8, 1.0);
    },
    weed(ctx, p, t) {
      ctx.strokeStyle = "#3f8a4a"; ctx.lineWidth = 0.1; ctx.lineCap = "round";
      for (let i = -2; i <= 2; i++) {
        ctx.beginPath(); ctx.moveTo(i * 0.18, 0.8);
        ctx.quadraticCurveTo(i * 0.28 + Math.sin(t * 2 + i) * 0.12, 0.0, i * 0.2, -0.85); ctx.stroke();
      }
    },
    chest(ctx) {
      ctx.fillStyle = "#8a5a2c"; ctx.fillRect(-0.6, -0.1, 1.2, 0.6);
      ctx.fillStyle = "#a06a34"; ctx.beginPath(); ctx.moveTo(-0.6, -0.1); ctx.quadraticCurveTo(0, -0.6, 0.6, -0.1); ctx.closePath(); ctx.fill();
      ctx.fillStyle = "#ffd24a"; ctx.fillRect(-0.62, -0.05, 1.24, 0.1); ctx.fillRect(-0.08, -0.25, 0.16, 0.6);
      ctx.fillStyle = "#fff3b0"; ctx.beginPath(); ctx.arc(0, 0.18, 0.08, 0, 7); ctx.fill();
    },
  };

  // generic fish used by several kinds
  function drawFish(ctx, p, t, L, lenScale, pointed) {
    L = (L || 0.82) * (lenScale || 1);
    const H = p.height || 0.5, belly = p.belly == null ? 1 : (typeof p.belly === "number" ? p.belly : 1);
    const wig = Math.sin(t * 6) * 0.06;

    // tail
    ctx.fillStyle = p.fin;
    ctx.beginPath(); ctx.moveTo(-L * 0.95, 0);
    if (p.tail === "fork") { ctx.lineTo(-L - 0.34, -H * 0.95 + wig); ctx.lineTo(-L - 0.16, 0); ctx.lineTo(-L - 0.34, H * 0.95 + wig); }
    else if (p.tail === "fancy") { ctx.quadraticCurveTo(-L - 0.5, -H * 1.2 + wig, -L - 0.3, -H * 0.2); ctx.quadraticCurveTo(-L - 0.55, H * 0.2 + wig, -L - 0.45, H * 1.2 + wig); ctx.quadraticCurveTo(-L - 0.2, H * 0.4, -L * 0.95, 0); }
    else { ctx.lineTo(-L - 0.3, -H * 0.85 + wig); ctx.quadraticCurveTo(-L - 0.38, 0, -L - 0.3, H * 0.85 + wig); }
    ctx.closePath(); ctx.fill();

    // dorsal fin
    ctx.beginPath(); ctx.moveTo(-L * 0.2, -H * 0.92);
    ctx.quadraticCurveTo(L * 0.08, -H * 1.45, L * 0.36, -H * 0.62); ctx.lineTo(-L * 0.2, -H * 0.5); ctx.closePath(); ctx.fill();

    // body
    bodyPath(ctx, L, H, belly);
    const g = ctx.createLinearGradient(0, -H, 0, H * belly);
    g.addColorStop(0, p.c1); g.addColorStop(0.55, p.c2); g.addColorStop(1, p.belC || p.c2);
    ctx.fillStyle = g; ctx.fill();

    // pattern (clipped)
    ctx.save(); bodyPath(ctx, L, H, belly); ctx.clip(); applyPattern(ctx, p, L, H);
    if (p.crystal) { ctx.strokeStyle = "rgba(255,255,255,.55)"; ctx.lineWidth = 0.02; for (let i = -2; i <= 2; i++) { ctx.beginPath(); ctx.moveTo(i * 0.3 * L, -H); ctx.lineTo(i * 0.3 * L + 0.15, H); ctx.stroke(); } }
    ctx.restore();

    // pectoral fin
    ctx.fillStyle = p.fin; ctx.beginPath(); ctx.moveTo(L * 0.22, H * 0.18);
    ctx.quadraticCurveTo(L * 0.1, H * 0.72, L * 0.5, H * 0.5); ctx.closePath(); ctx.fill();

    // gill line
    ctx.strokeStyle = "rgba(0,0,0,.16)"; ctx.lineWidth = 0.03;
    ctx.beginPath(); ctx.moveTo(L * 0.52, -H * 0.5); ctx.quadraticCurveTo(L * 0.44, 0, L * 0.52, H * 0.5); ctx.stroke();

    // mouth (pointed nose for tuna/marlin)
    ctx.strokeStyle = "rgba(0,0,0,.35)"; ctx.lineWidth = 0.025;
    ctx.beginPath(); ctx.moveTo(L * 1.0, pointed ? -H * 0.05 : H * 0.02); ctx.lineTo(L * 0.82, H * 0.16); ctx.stroke();

    // whiskers (carp etc.)
    if (p.whiskers) { ctx.strokeStyle = p.c1; ctx.lineWidth = 0.018; for (const s of [-1, 1]) { ctx.beginPath(); ctx.moveTo(L * 0.95, H * 0.1); ctx.quadraticCurveTo(L * 1.05, H * (0.1 + 0.15 * s), L * 1.1, H * (0.2 + 0.25 * s)); ctx.stroke(); } }

    // eye
    eye(ctx, L * 0.74, -H * 0.16, H * 0.2, p.noEye);

    // outline
    bodyPath(ctx, L, H, belly); ctx.strokeStyle = "rgba(0,0,0,.22)"; ctx.lineWidth = 0.022; ctx.stroke();
  }

  const FishArt = {
    cache: {},
    params(id) { return ART[id] || fallback(id); },

    draw(ctx, id, cx, cy, size, opts) {
      opts = opts || {};
      const p = this.params(id);
      const t = opts.t || 0;
      const face = opts.face === "left" ? -1 : 1;
      ctx.save();
      ctx.translate(cx, cy);
      if (p.glow) {
        const gg = ctx.createRadialGradient(0, 0, size * 0.15, 0, 0, size * 1.3);
        gg.addColorStop(0, p.glow); gg.addColorStop(1, "rgba(0,0,0,0)");
        ctx.fillStyle = gg; ctx.beginPath(); ctx.arc(0, 0, size * 1.3, 0, 7); ctx.fill();
      }
      ctx.scale(size * face, size);
      ctx.lineJoin = "round";
      (KIND[p.kind] || KIND.fish)(ctx, p, t);
      ctx.restore();
    },

    // cached PNG data-URL for use as <img> in DOM panels (static, face right)
    dataURL(id, w, h) {
      w = w || 76; h = h || 56;
      const key = id + "@" + w + "x" + h;
      if (this.cache[key]) return this.cache[key];
      const dpr = 2;
      const cv = document.createElement("canvas");
      cv.width = w * dpr; cv.height = h * dpr;
      const ctx = cv.getContext("2d");
      ctx.scale(dpr, dpr);
      const size = Math.min(w * 0.46, h * 0.62);
      this.draw(ctx, id, w / 2, h / 2, size, {});
      const url = cv.toDataURL();
      this.cache[key] = url;
      return url;
    },

    img(id, cls) {
      return `<img class="${cls || "fish-img"}" src="${this.dataURL(id)}" alt="" draggable="false">`;
    },
  };

  window.FishArt = FishArt;
})();
