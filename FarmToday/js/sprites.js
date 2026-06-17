/* ============================================================
 * sprites.js — 픽셀 아트(코드로 그림). 스타듀밸리풍 16px 타일.
 * 모든 도형은 fillRect 기반이라 좌표 변환으로 확대해도 또렷합니다.
 * ============================================================ */
(function () {
  'use strict';

  const T = 16;

  function hash(x, y) {
    let h = (x * 374761393 + y * 668265263) ^ 0x5bd1e995;
    h = (h ^ (h >> 13)) * 1274126177;
    return ((h ^ (h >> 16)) >>> 0) / 4294967295;
  }
  function rect(ctx, x, y, w, h, c) { ctx.fillStyle = c; ctx.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h)); }
  function px(ctx, x, y, c) { ctx.fillStyle = c; ctx.fillRect(Math.round(x), Math.round(y), 1, 1); }
  // 대각선(브레젠험) — 하프팀버 보/지붕 사선용
  function diag(ctx, x0, y0, x1, y1, c) {
    let x = Math.round(x0), y = Math.round(y0); const X = Math.round(x1), Y = Math.round(y1);
    const dx = Math.abs(X - x), dy = Math.abs(Y - y), sx = x < X ? 1 : -1, sy = y < Y ? 1 : -1;
    let err = dx - dy, g = 0;
    while (g++ < 90) { px(ctx, x, y, c); if (x === X && y === Y) break; const e2 = 2 * err; if (e2 > -dy) { err -= dy; x += sx; } if (e2 < dx) { err += dx; y += sy; } }
  }
  function shade(hex, amt) {
    const n = parseInt(hex.slice(1), 16);
    let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
    r = Math.max(0, Math.min(255, r + amt)); g = Math.max(0, Math.min(255, g + amt)); b = Math.max(0, Math.min(255, b + amt));
    return '#' + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
  }
  function shadow(ctx, x, y, w) { rect(ctx, x + (16 - w) / 2, y + 13, w, 2, 'rgba(0,0,0,.22)'); rect(ctx, x + (16 - w) / 2 + 1, y + 12, w - 2, 1, 'rgba(0,0,0,.14)'); }

  const Sprites = {
    T, hash, shade, rect, px,

    /* ---------- 지형 ---------- */
    grass(ctx, x, y, gx, gy, season) {
      const pal = {
        spring: ['#6fc05a', '#62b04e', '#7fce69'],
        summer: ['#5cae44', '#4f9e3a', '#6cbe52'],
        fall: ['#a89a4e', '#9a8a3e', '#b8aa5e'],
        winter: ['#dfeaf0', '#cfe0e8', '#eef4f8'],
      }[season] || ['#6fc05a', '#62b04e', '#7fce69'];
      const v = hash(gx, gy);
      rect(ctx, x, y, T, T, pal[0]);
      // 부드러운 얼룩
      rect(ctx, x, y, T, T / 2, pal[v > 0.5 ? 2 : 0]);
      // 풀포기 몇 개(결정론적)
      for (let i = 0; i < 3; i++) {
        const h = hash(gx * 5 + i, gy * 9 - i);
        if (h < 0.4) continue;
        const bx = x + (h * 12 | 0) + 2, by = y + (hash(gx - i, gy * 3 + i) * 9 | 0) + 4;
        rect(ctx, bx, by, 1, 3, pal[1]);
        px(ctx, bx - 1, by + 1, pal[1]); px(ctx, bx + 1, by, pal[1]);
      }
      if (season === 'spring' && v > 0.93) { px(ctx, x + 5, y + 6, '#f4e04a'); px(ctx, x + 6, y + 6, '#fff'); }
    },
    soil(ctx, x, y, watered) {
      const base = watered ? '#5a4030' : '#7a5538';
      rect(ctx, x, y, T, T, base);
      // 갈아엎은 이랑(스타듀풍 격자 음영)
      rect(ctx, x, y, T, 1, shade(base, 18));
      rect(ctx, x, y + T - 1, T, 1, shade(base, -22));
      const dk = shade(base, -16), lt = shade(base, 12);
      for (let r = 3; r < T; r += 5) { rect(ctx, x + 1, y + r, T - 2, 1, dk); rect(ctx, x + 1, y + r + 1, T - 2, 1, lt); }
      if (watered) { rect(ctx, x + 2, y + 5, 2, 1, 'rgba(120,170,210,.5)'); rect(ctx, x + 9, y + 10, 2, 1, 'rgba(120,170,210,.5)'); }
    },
    water(ctx, x, y, t) {
      rect(ctx, x, y, T, T, '#3f74b0');
      rect(ctx, x, y, T, T / 2, '#4a82bf');
      for (let i = 0; i < 3; i++) {
        const yy = y + 3 + i * 5 + (Math.sin(t / 500 + i + x) * 1.2 | 0);
        rect(ctx, x + 2 + (i % 2), yy, 5, 1, 'rgba(210,235,255,.6)');
      }
    },
    // 자연스러운 흙길(오솔길) — 격자 없이 부드러운 흙바닥 + 잔돌
    path(ctx, x, y, gx, gy, season) {
      const dirt = '#b89a72';
      rect(ctx, x, y, T, T, dirt);
      rect(ctx, x, y, T, T / 2, shade(dirt, 6));
      // 흙 얼룩/자갈(결정론적, 타일 경계가 안 보이도록 분산)
      for (let i = 0; i < 6; i++) {
        const h = hash(gx * 7 + i, gy * 11 - i);
        const bx = x + (h * T | 0), by = y + (hash(gx - i, gy * 5 + i) * T | 0);
        const c = h > 0.66 ? shade(dirt, -16) : h > 0.33 ? shade(dirt, 12) : shade(dirt, -6);
        px(ctx, bx, by, c);
        if (h > 0.9) { px(ctx, bx + 1, by, '#9aa0a8'); px(ctx, bx, by + 1, '#8a8f97'); } // 잔돌
      }
    },
    floor(ctx, x, y) {
      rect(ctx, x, y, T, T, '#403942');
      rect(ctx, x, y, T, T / 2, '#473f49');
      px(ctx, x + 3, y + 4, '#352f38'); px(ctx, x + 11, y + 10, '#352f38');
    },
    // 광장 돌바닥(둥근 자갈)
    pave(ctx, x, y, gx, gy) {
      rect(ctx, x, y, T, T, '#8c8576');               // 줄눈(어두운 바탕)
      const cols = ['#c8c2b2', '#b4ad9c', '#beb7a6', '#aaa392'];
      for (let j = 0; j < 2; j++) for (let i = 0; i < 2; i++) {
        const sxp = x + i * 8 + (j ? 1 : 0), syp = y + j * 8;
        const c = cols[(hash(gx * 2 + i, gy * 2 + j) * cols.length) | 0];
        rect(ctx, sxp + 1, syp + 1, 6, 6, c);
        px(ctx, sxp + 1, syp + 1, shade(c, 14)); px(ctx, sxp + 6, syp + 6, shade(c, -18));
      }
    },
    lamp(ctx, x, y, night) {
      shadow(ctx, x, y, 5);
      rect(ctx, x + 7, y + 4, 2, 10, '#3a3a42'); rect(ctx, x + 5, y + 13, 6, 1, '#2a2a30');
      rect(ctx, x + 5, y, 6, 5, '#3a3a42'); rect(ctx, x + 5, y, 6, 1, '#52525a');
      rect(ctx, x + 6, y + 1, 4, 3, night ? '#fff0b0' : '#caa84a'); px(ctx, x + 7, y + 2, '#fff');
      if (night) { px(ctx, x + 5, y + 2, 'rgba(255,240,160,.5)'); px(ctx, x + 10, y + 2, 'rgba(255,240,160,.5)'); }
    },
    fence(ctx, x, y) {
      const w = '#8a6a44';
      rect(ctx, x + 2, y + 5, 2, 9, w); rect(ctx, x + 12, y + 5, 2, 9, w);
      rect(ctx, x, y + 7, T, 2, w); rect(ctx, x, y + 10, T, 2, shade(w, -12));
      px(ctx, x + 2, y + 5, shade(w, 16)); px(ctx, x + 12, y + 5, shade(w, 16));
    },
    fountain(ctx, x, y) {
      shadow(ctx, x, y, 13);
      rect(ctx, x + 1, y + 7, 14, 8, '#9aa0a8'); rect(ctx, x + 1, y + 7, 14, 1, '#b8bec6');
      rect(ctx, x + 1, y + 14, 14, 1, '#74747c');
      rect(ctx, x + 3, y + 9, 10, 4, '#3f74b0'); rect(ctx, x + 4, y + 9, 8, 1, '#6aa6d6');
      rect(ctx, x + 7, y + 2, 2, 6, '#9aa0a8');
      px(ctx, x + 7, y + 1, '#bfe6f2'); px(ctx, x + 9, y + 2, '#bfe6f2'); px(ctx, x + 6, y + 3, '#bfe6f2'); px(ctx, x + 8, y + 4, '#bfe6f2');
    },

    /* ---------- 실내(건물 내부) ---------- */
    woodFloor(ctx, x, y, gx, gy) {
      const b = '#a9763f';
      rect(ctx, x, y, T, T, b);
      for (let r = 0; r < T; r += 4) { rect(ctx, x, y + r, T, 1, shade(b, -16)); rect(ctx, x, y + r + 1, T, 1, shade(b, 8)); }
      rect(ctx, x + ((gx + gy) % 2 ? 6 : 12), y, 1, T, shade(b, -22));
    },
    wallTile(ctx, x, y) {
      rect(ctx, x, y, T, T, '#8a6f9a');
      rect(ctx, x, y, T, T / 2, '#977aa6');
      for (let i = 2; i < T; i += 5) px(ctx, x + i, y + 3, 'rgba(255,255,255,.12)');
      rect(ctx, x, y + T - 4, T, 4, '#6a4a3a'); rect(ctx, x, y + T - 5, T, 1, '#9a7a5a'); // 걸레받이
    },
    counter(ctx, x, y) {
      rect(ctx, x, y + 5, T, 9, '#8a5a32');
      rect(ctx, x, y + 4, T, 2, '#caa070'); rect(ctx, x, y + 6, T, 1, '#a06c3c');
      rect(ctx, x, y + 13, T, 1, '#5a3a1c');
    },
    shelf(ctx, x, y) {
      rect(ctx, x + 1, y + 1, 14, 14, '#7a5a3a'); rect(ctx, x + 1, y + 1, 14, 1, '#9a7a4a');
      const gc = ['#e0405a', '#3fc06a', '#e8c84a', '#5a8fe0', '#caa040', '#d84ad8'];
      for (let r = 0; r < 3; r++) { rect(ctx, x + 1, y + 1 + r * 5, 14, 1, '#5a3a1c'); for (let i = 0; i < 3; i++) rect(ctx, x + 2 + i * 4, y + 2 + r * 5, 3, 3, gc[((x >> 2) + y + r * 3 + i) % gc.length]); }
    },
    table(ctx, x, y) {
      shadow(ctx, x, y, 10);
      rect(ctx, x + 2, y + 6, 12, 5, '#8a5a32'); rect(ctx, x + 2, y + 6, 12, 1, '#a06c3c');
      rect(ctx, x + 3, y + 10, 2, 4, '#5a3a1c'); rect(ctx, x + 11, y + 10, 2, 4, '#5a3a1c');
      rect(ctx, x + 6, y + 3, 4, 3, '#e0405a'); px(ctx, x + 7, y + 3, '#fff'); // 화병
    },
    sprinkler(ctx, x, y, tier, t) {
      const tint = ['#9aa6b0', '#d8c24a', '#b06ad0'][tier] || '#9aa6b0';
      rect(ctx, x + 4, y + 11, 8, 3, shade(tint, -26));        // 받침
      rect(ctx, x + 5, y + 6, 6, 6, tint); rect(ctx, x + 5, y + 6, 6, 1, shade(tint, 22));
      rect(ctx, x + 5, y + 11, 6, 1, shade(tint, -22));
      rect(ctx, x + 7, y + 3, 2, 3, shade(tint, -10));         // 분사구
      // 물방울(살짝 반짝)
      const blink = ((t || 0) / 300 | 0) % 2;
      const w = blink ? '#bfe6f2' : '#9cd2f0';
      px(ctx, x + 2, y + 8, w); px(ctx, x + 13, y + 8, w); px(ctx, x + 7, y + 1, w);
      px(ctx, x + 1, y + 10, w); px(ctx, x + 14, y + 10, w);
    },
    doormat(ctx, x, y) {
      rect(ctx, x + 3, y + 9, 10, 5, '#8a4a3a'); rect(ctx, x + 3, y + 9, 10, 1, '#a86a5a');
      rect(ctx, x + 5, y + 11, 6, 1, '#caa');
      px(ctx, x + 7, y + 6, 'rgba(255,255,255,.5)'); px(ctx, x + 8, y + 7, 'rgba(255,255,255,.5)'); // 아래 화살표
    },

    /* ---------- 오브젝트 ---------- */
    weed(ctx, x, y) {
      shadow(ctx, x, y, 8);
      const g = '#4f9e3a', g2 = '#3f7e2a';
      rect(ctx, x + 7, y + 9, 1, 5, g2);
      rect(ctx, x + 4, y + 8, 3, 1, g); rect(ctx, x + 3, y + 6, 3, 2, g);
      rect(ctx, x + 9, y + 7, 3, 1, g); rect(ctx, x + 10, y + 5, 3, 2, shade(g, 12));
      rect(ctx, x + 6, y + 4, 3, 3, shade(g, 16));
      px(ctx, x + 5, y + 5, '#e7d24b');
    },
    rockSmall(ctx, x, y) {
      shadow(ctx, x, y, 9);
      const c = '#9197a0';
      rect(ctx, x + 4, y + 8, 8, 5, c);
      rect(ctx, x + 5, y + 7, 6, 1, shade(c, 16));
      rect(ctx, x + 4, y + 12, 8, 1, shade(c, -26));
      rect(ctx, x + 6, y + 9, 3, 2, shade(c, -14));
      px(ctx, x + 5, y + 8, shade(c, 24));
    },
    rockLarge(ctx, x, y) {
      shadow(ctx, x, y, 13);
      const c = '#7f858f';
      rect(ctx, x + 2, y + 4, 12, 10, c);
      rect(ctx, x + 3, y + 3, 10, 1, shade(c, 18));
      rect(ctx, x + 2, y + 13, 12, 1, shade(c, -26));
      rect(ctx, x + 2, y + 4, 1, 9, shade(c, 12));
      rect(ctx, x + 5, y + 7, 5, 4, shade(c, -16));
      px(ctx, x + 4, y + 6, shade(c, 26)); px(ctx, x + 11, y + 11, shade(c, -20));
    },
    oreRock(ctx, x, y, oreTint) {
      this.rockLarge(ctx, x, y);
      px(ctx, x + 6, y + 7, oreTint); px(ctx, x + 9, y + 9, oreTint); px(ctx, x + 7, y + 10, shade(oreTint, 34)); px(ctx, x + 10, y + 6, oreTint);
    },
    tree(ctx, x, y, season) {
      shadow(ctx, x + 1, y, 11);
      const trunk = '#6b4a2a';
      rect(ctx, x + 7, y + 8, 3, 7, trunk); rect(ctx, x + 7, y + 8, 1, 7, '#7e5a36');
      if (season === 'winter') {                      // 겨울: 앙상한 가지 + 눈
        rect(ctx, x + 6, y - 6, 2, 14, trunk);
        rect(ctx, x + 3, y - 2, 4, 1, trunk); rect(ctx, x + 9, y - 4, 4, 1, trunk); rect(ctx, x + 8, y + 1, 4, 1, trunk);
        px(ctx, x + 4, y - 3, '#eaf4fa'); px(ctx, x + 11, y - 5, '#eaf4fa'); px(ctx, x + 7, y - 7, '#eaf4fa');
        return;
      }
      const pal = season === 'fall' ? ['#9a4e1a', '#c4791f', '#dba23a']
        : season === 'spring' ? ['#3a8a33', '#4fa343', '#6fc05a']
          : ['#2f6e2f', '#3d8a3a', '#52a648'];
      const d = pal[0], m = pal[1], l = pal[2];
      rect(ctx, x + 3, y - 1, 10, 8, d); rect(ctx, x + 2, y + 1, 12, 4, d);
      rect(ctx, x + 4, y - 4, 8, 5, m); rect(ctx, x + 5, y - 7, 6, 4, m); rect(ctx, x + 6, y - 8, 4, 2, l);
      px(ctx, x + 5, y - 3, l); px(ctx, x + 9, y - 5, l); px(ctx, x + 7, y + 1, l); px(ctx, x + 11, y + 3, d); px(ctx, x + 4, y + 4, d);
      if (season === 'spring') { px(ctx, x + 6, y - 5, '#f6c0d8'); px(ctx, x + 10, y - 2, '#f6c0d8'); px(ctx, x + 4, y + 1, '#f6c0d8'); }
    },
    stump(ctx, x, y) {
      shadow(ctx, x, y, 8);
      rect(ctx, x + 5, y + 8, 6, 5, '#7a512c'); rect(ctx, x + 5, y + 8, 6, 1, '#9a6a3a');
      rect(ctx, x + 6, y + 9, 4, 2, '#8a5e34'); px(ctx, x + 7, y + 10, '#5a3a1c');
    },

    /* ---------- 작물 ---------- */
    crop(ctx, x, y, tint, stage, stages, ready) {
      const frac = stage / Math.max(1, stages - 1);
      const stemH = 2 + (frac * 10 | 0);
      const baseY = y + 14;
      shadow(ctx, x, y, 6);
      if (stage === 0) { px(ctx, x + 7, baseY - 1, '#caa86a'); px(ctx, x + 8, baseY - 1, '#b8965a'); rect(ctx, x + 7, baseY - 2, 1, 2, '#4f9e3a'); return; }
      rect(ctx, x + 7, baseY - stemH, 2, stemH, '#3f8a2e'); rect(ctx, x + 7, baseY - stemH, 1, stemH, '#52a83c');
      rect(ctx, x + 4, baseY - stemH + 2, 3, 2, '#4f9e3a');
      rect(ctx, x + 9, baseY - stemH + 4, 3, 2, '#4f9e3a');
      rect(ctx, x + 5, baseY - stemH + 5, 2, 2, '#3f7e2a');
      if (ready) {
        rect(ctx, x + 5, baseY - stemH - 2, 5, 5, tint);
        rect(ctx, x + 5, baseY - stemH - 2, 5, 1, shade(tint, 26));
        px(ctx, x + 6, baseY - stemH - 1, shade(tint, 40)); px(ctx, x + 9, baseY - stemH + 1, shade(tint, -34));
        rect(ctx, x + 6, baseY - stemH - 3, 3, 1, '#3f8a2e');
      } else if (stage >= stages - 2) {
        rect(ctx, x + 6, baseY - stemH - 1, 3, 3, shade(tint, -8));
      }
    },

    machine(ctx, x, y, tint, busy, ready) {
      shadow(ctx, x, y, 12);
      rect(ctx, x + 2, y + 3, 12, 12, tint);
      rect(ctx, x + 2, y + 3, 12, 1, shade(tint, 26));
      rect(ctx, x + 2, y + 3, 1, 12, shade(tint, 16));
      rect(ctx, x + 2, y + 14, 12, 1, shade(tint, -28));
      rect(ctx, x + 4, y + 1, 8, 3, shade(tint, -12)); rect(ctx, x + 4, y + 1, 8, 1, shade(tint, 4));
      rect(ctx, x + 4, y + 8, 8, 1, shade(tint, -18));
      if (ready) { rect(ctx, x + 6, y + 5, 4, 4, '#f5e04a'); px(ctx, x + 7, y + 4, '#fff'); px(ctx, x + 8, y + 4, '#fff'); }
      else if (busy) { rect(ctx, x + 6, y + 6, 4, 3, '#c9b0b0'); px(ctx, x + 7, y + 3, '#cde'); }
    },

    // 튜더/통나무/판자/돌 벽 + 기와 지붕 + 도머창 + 2층 창 — 스타듀풍 건물
    building(ctx, x, y, w, h, tint, opt) {
      opt = opt || {};
      const W = w * T, H = h * T;
      const style = opt.style || 'timber';
      const roofC = opt.roof || shade(tint, -44);
      const rh = Math.min(Math.round(H * 0.45), 8 + h * 3);
      const wy = y + rh - 1, wallH = H - (rh - 1);
      const beam = shade(tint, -36), half = W / 2;

      rect(ctx, x - 1, y + H - 1, W + 2, 2, 'rgba(0,0,0,.22)');

      // ===== 벽 바탕 + 재질 =====
      rect(ctx, x, wy, W, wallH, tint);
      if (style === 'log') {
        for (let r = 0; r < wallH - 3; r += 3) { rect(ctx, x, wy + r, W, 1, shade(tint, 16)); rect(ctx, x, wy + r + 2, W, 1, shade(tint, -20)); }
        rect(ctx, x, wy, 2, wallH, shade(tint, -10)); rect(ctx, x + W - 2, wy, 2, wallH, shade(tint, -16));
        for (let r = 1; r < wallH - 2; r += 3) { px(ctx, x + 1, wy + r, shade(tint, 26)); px(ctx, x + W - 2, wy + r, shade(tint, 8)); }
      } else if (style === 'plank') {
        for (let i = 3; i < W; i += 4) rect(ctx, x + i, wy, 1, wallH, shade(tint, -14));
        rect(ctx, x, wy, W, 1, shade(tint, 16));
      } else if (style === 'stone') {
        for (let r = 0; r < wallH; r += 4) {
          rect(ctx, x, wy + r, W, 1, shade(tint, -16));
          const off = (((r / 4) | 0) % 2) ? 4 : 0;
          for (let i = off; i < W; i += 8) rect(ctx, x + i, wy + r, 1, 4, shade(tint, -16));
        }
      } else { // timber — 튜더 하프팀버
        rect(ctx, x, wy, 2, wallH, beam); rect(ctx, x + W - 2, wy, 2, wallH, beam);
        for (let i = 1; i < w; i++) rect(ctx, x + i * T - 1, wy, 2, wallH, beam);
        rect(ctx, x, wy, W, 2, beam); rect(ctx, x, wy + (wallH >> 1) - 1, W, 2, beam);
        for (let p = 0; p < w; p++) {                          // 패널마다 대각보 /\
          const a = x + p * T + 2, b = a + (T - 4), mid = (a + b) / 2;
          diag(ctx, a, wy + wallH - 3, mid, wy + 3, beam);
          diag(ctx, b, wy + wallH - 3, mid, wy + 3, beam);
        }
      }
      rect(ctx, x, wy, 1, wallH, shade(tint, 12));
      rect(ctx, x + W - 1, wy, 1, wallH, shade(tint, -24));

      // ===== 돌 기초 =====
      const fy = y + H - 3;
      rect(ctx, x, fy, W, 3, '#9a9aa2'); rect(ctx, x, fy, W, 1, '#b6b6be');
      for (let i = 2; i < W; i += 4) px(ctx, x + i, fy + 1, '#74747c');

      // ===== 박공 지붕 + 기와 결 =====
      for (let r = 0; r < rh; r++) {
        const t = rh > 1 ? r / (rh - 1) : 1;
        const inset = Math.round((1 - t) * (half - 3));
        const m = r % 3, c = m === 0 ? shade(roofC, 16) : m === 2 ? shade(roofC, -16) : roofC;
        rect(ctx, x + inset, y + r, W - inset * 2, 1, c);
      }
      rect(ctx, x + Math.round(half) - 3, y, 6, 1, shade(roofC, 30));   // 용마루
      rect(ctx, x - 2, y + rh - 2, W + 4, 1, shade(roofC, 6));          // 처마
      rect(ctx, x - 2, y + rh - 1, W + 4, 1, shade(roofC, -30));
      diag(ctx, x + Math.round(half) - 3, y, x - 2, y + rh - 2, shade(roofC, -36)); // 사선 외곽
      diag(ctx, x + Math.round(half) + 2, y, x + W + 1, y + rh - 2, shade(roofC, -36));

      // ===== 중앙 도머(작은 박공창) =====
      if (opt.dormer && w >= 3) {
        const dwd = 9, ddx = x + Math.round(half) - (dwd >> 1), ddy = y + Math.max(2, rh - 11);
        for (let r = 0; r < 4; r++) rect(ctx, ddx + (3 - r), ddy + r, dwd - (3 - r) * 2, 1, shade(roofC, 12));
        rect(ctx, ddx, ddy + 4, dwd, 6, shade(tint, 8)); rect(ctx, ddx, ddy + 4, dwd, 1, beam); rect(ctx, ddx, ddy + 9, dwd, 1, beam);
        this.window(ctx, ddx + 1, ddy + 4);
      }

      // ===== 굴뚝 =====
      if (opt.chimney) { const cx2 = x + W - 9; rect(ctx, cx2, y + 2, 4, rh, '#8a7066'); rect(ctx, cx2 - 1, y + 1, 6, 2, '#6a5046'); }

      // ===== 아치문 + 계단 =====
      const dw = 8, dx = x + Math.round(W / 2) - (dw >> 1), dyy = y + H - 12;
      rect(ctx, dx - 1, dyy, dw + 2, 12, beam);
      rect(ctx, dx, dyy + 1, dw, 11, '#3a2410'); rect(ctx, dx + 1, dyy + 2, dw - 2, 10, '#7a4a24');
      rect(ctx, dx + 1, dyy, dw - 2, 2, '#3a2410'); rect(ctx, dx + (dw >> 1), dyy + 2, 1, 10, shade('#7a4a24', -20));
      px(ctx, dx + dw - 3, dyy + 6, '#e8c84a');
      rect(ctx, dx - 2, y + H - 1, dw + 4, 1, '#a8a8b0');

      // ===== 창문(아래층 + 위층) =====
      const loY = wy + wallH - 9;
      this.window(ctx, x + 3, loY); this.window(ctx, x + W - 9, loY);
      if (!opt.dormer && wallH > 18) { this.window(ctx, x + 3, wy + 3); this.window(ctx, x + W - 9, wy + 3); }

      // ===== 넝쿨 =====
      if (opt.vines) for (let i = 2; i < W - 2; i += 6) {
        const vy = wy + 1 + (hash(x + i, y * 3) * 4 | 0), vl = 5 + (hash(i, y) * 6 | 0);
        rect(ctx, x + i, vy, 1, vl, '#3f8a3a'); px(ctx, x + i - 1, vy + 2, '#52a848'); px(ctx, x + i + 1, vy + vl - 1, '#347a30');
      }
    },
    window(ctx, x, y) {
      rect(ctx, x, y, 6, 6, '#46280f');
      rect(ctx, x + 1, y + 1, 4, 4, '#bfe6f2'); rect(ctx, x + 1, y + 1, 4, 1, '#ffffff');
      rect(ctx, x + 3, y + 1, 1, 4, '#46280f'); rect(ctx, x + 1, y + 3, 4, 1, '#46280f');
    },
    clock(ctx, cx, cy) {
      rect(ctx, cx - 3, cy - 4, 7, 9, '#3a2a1a'); rect(ctx, cx - 4, cy - 3, 9, 7, '#3a2a1a');
      rect(ctx, cx - 2, cy - 3, 5, 7, '#f2ead0'); rect(ctx, cx - 3, cy - 2, 7, 5, '#f2ead0');
      rect(ctx, cx, cy - 2, 1, 3, '#3a2a1a'); rect(ctx, cx, cy, 3, 1, '#3a2a1a');
    },
    house(ctx, x, y) {
      this.building(ctx, x, y, 4, 3, '#e2cda2', { roof: '#9a4030', style: 'timber', dormer: true, chimney: true });
    },

    // ----- 자연물(장식) -----
    bush(ctx, x, y) {
      shadow(ctx, x, y, 10);
      const g = '#3f8a3a';
      rect(ctx, x + 3, y + 7, 10, 6, g);
      rect(ctx, x + 4, y + 5, 8, 3, shade(g, 14)); rect(ctx, x + 5, y + 4, 6, 2, shade(g, 24));
      px(ctx, x + 5, y + 9, shade(g, -20)); px(ctx, x + 10, y + 10, shade(g, -20)); px(ctx, x + 7, y + 6, shade(g, 30));
      if (((x + y) >> 4) % 3 === 0) { px(ctx, x + 6, y + 8, '#e0405a'); px(ctx, x + 10, y + 9, '#e0405a'); }
    },
    flower(ctx, x, y, c) {
      rect(ctx, x + 7, y + 9, 1, 4, '#3f8a2e');
      rect(ctx, x + 6, y + 6, 3, 3, c); px(ctx, x + 7, y + 7, '#fff8d0');
      px(ctx, x + 5, y + 7, c); px(ctx, x + 9, y + 7, c); px(ctx, x + 7, y + 5, c); px(ctx, x + 7, y + 9, shade(c, -10));
    },
    grassTuft(ctx, x, y) {
      const g = '#5aa83a';
      rect(ctx, x + 5, y + 9, 1, 4, g); rect(ctx, x + 7, y + 8, 1, 5, shade(g, -8)); rect(ctx, x + 9, y + 10, 1, 3, g);
      px(ctx, x + 6, y + 8, g); px(ctx, x + 8, y + 7, shade(g, 12)); px(ctx, x + 10, y + 9, shade(g, -6));
    },
    log(ctx, x, y) {
      shadow(ctx, x, y, 13);
      const w = '#7a512c';
      rect(ctx, x + 2, y + 8, 12, 5, w); rect(ctx, x + 2, y + 8, 12, 1, shade(w, 16)); rect(ctx, x + 2, y + 12, 12, 1, shade(w, -22));
      rect(ctx, x + 2, y + 9, 3, 3, '#9a6a3a'); px(ctx, x + 3, y + 10, '#caa070');
      for (let i = 6; i < 14; i += 3) px(ctx, x + i, y + 10, shade(w, -16));
    },
    pebble(ctx, x, y) {
      const c = '#9aa0a8';
      rect(ctx, x + 6, y + 10, 4, 3, c); px(ctx, x + 6, y + 10, shade(c, 18)); px(ctx, x + 9, y + 12, shade(c, -18));
      px(ctx, x + 11, y + 11, shade(c, 6));
    },

    chicken(ctx, x, y) {
      shadow(ctx, x, y, 8);
      rect(ctx, x + 4, y + 6, 7, 6, '#f6f2e6'); rect(ctx, x + 4, y + 6, 7, 1, '#fff');
      rect(ctx, x + 9, y + 3, 4, 4, '#f6f2e6');
      px(ctx, x + 12, y + 4, '#222'); rect(ctx, x + 13, y + 5, 2, 1, '#e8a23a');
      rect(ctx, x + 9, y + 2, 2, 1, '#d83434'); px(ctx, x + 10, y + 1, '#e85454');
      rect(ctx, x + 5, y + 12, 1, 2, '#e8a23a'); rect(ctx, x + 8, y + 12, 1, 2, '#e8a23a');
    },
    cow(ctx, x, y) {
      shadow(ctx, x, y, 12);
      rect(ctx, x + 2, y + 5, 11, 7, '#f6f6f0'); rect(ctx, x + 2, y + 5, 11, 1, '#fff');
      rect(ctx, x + 11, y + 3, 4, 4, '#f6f6f0');
      px(ctx, x + 5, y + 6, '#3a3a3a'); rect(ctx, x + 7, y + 8, 3, 2, '#3a3a3a'); rect(ctx, x + 3, y + 9, 2, 2, '#3a3a3a');
      px(ctx, x + 14, y + 4, '#222'); rect(ctx, x + 13, y + 6, 2, 1, '#e6a0a0');
      rect(ctx, x + 3, y + 12, 1, 2, '#caa'); rect(ctx, x + 10, y + 12, 1, 2, '#caa');
    },
    horse(ctx, x, y) {
      shadow(ctx, x, y, 12);
      rect(ctx, x + 2, y + 5, 11, 6, '#8a5a32'); rect(ctx, x + 2, y + 5, 11, 1, '#a06c3c');
      rect(ctx, x + 11, y + 2, 3, 5, '#8a5a32');
      rect(ctx, x + 10, y + 1, 2, 4, '#4a2f18'); rect(ctx, x + 6, y + 4, 5, 1, '#4a2f18');
      px(ctx, x + 13, y + 3, '#111');
      rect(ctx, x + 3, y + 11, 1, 3, '#3a2414'); rect(ctx, x + 6, y + 11, 1, 3, '#3a2414'); rect(ctx, x + 10, y + 11, 1, 3, '#3a2414');
    },
    slime(ctx, x, y, t) {
      const bob = Math.sin(t / 220) * 1 | 0;
      const c = '#5fce6a';
      rect(ctx, x + 2, y + 13 + bob, 11, 1, 'rgba(0,0,0,.25)');
      rect(ctx, x + 3, y + 7 + bob, 10, 7, c);
      rect(ctx, x + 4, y + 5 + bob, 8, 3, shade(c, 16));
      rect(ctx, x + 5, y + 5 + bob, 6, 1, shade(c, 30));
      px(ctx, x + 6, y + 9 + bob, '#173d1a'); px(ctx, x + 10, y + 9 + bob, '#173d1a');
      rect(ctx, x + 3, y + 13 + bob, 10, 1, shade(c, -26));
    },

    /* ---------- 마을 주민(NPC) ---------- */
    npc(ctx, x, y, dir, color, frame) {
      shadow(ctx, x, y, 8);
      const skin = '#f1c27d', hair = '#3a2a1a';
      const lf = frame ? 1 : 0;
      rect(ctx, x + 5, y + 12 - lf, 2, 3 + lf, '#46464f');
      rect(ctx, x + 9, y + 12 - (1 - lf), 2, 3 + (1 - lf), '#46464f');
      rect(ctx, x + 4, y + 7, 8, 6, color);
      rect(ctx, x + 4, y + 7, 8, 1, shade(color, 20));
      rect(ctx, x + 3, y + 8, 2, 4, color); rect(ctx, x + 11, y + 8, 2, 4, color);
      rect(ctx, x + 5, y + 2, 6, 6, skin);
      rect(ctx, x + 4, y + 1, 8, 3, hair);
      rect(ctx, x + 4, y + 2, 1, 3, hair); rect(ctx, x + 11, y + 2, 1, 3, hair);
      if (dir === 'down') { px(ctx, x + 6, y + 5, '#222'); px(ctx, x + 9, y + 5, '#222'); }
      else if (dir === 'up') { rect(ctx, x + 4, y + 1, 8, 5, hair); }
      else if (dir === 'left') px(ctx, x + 6, y + 5, '#222');
      else px(ctx, x + 9, y + 5, '#222');
    },

    /* ---------- 플레이어 ----------
     * action = { tool, prog(0..1), dir } 있으면 도구질 포즈/스윙.
     */
    player(ctx, x, y, dir, frame, onHorse, action) {
      if (onHorse) { this.horse(ctx, x, y + 3); y -= 4; }
      const skin = '#f1c27d', skinSh = '#dca65e', hair = '#6b4a2a';
      const hat = '#d8b24c', hatSh = '#a8842c';
      const ov = '#3457a0', ovSh = '#274382', shirt = '#e8e2d4';
      const boot = '#5a3a22';
      shadow(ctx, x, y, 9);
      const bob = frame ? -1 : 0;            // 걷기 상하 흔들림
      const yy = y + bob;

      // 다리/장화 (걷기 시 번갈아)
      const lf = frame ? 1 : 0;
      rect(ctx, x + 5, yy + 12 - lf, 2, 3 + lf, boot);
      rect(ctx, x + 9, yy + 12 - (1 - lf), 2, 3 + (1 - lf), boot);

      // 멜빵바지(몸통)
      rect(ctx, x + 4, yy + 7, 8, 6, ov);
      rect(ctx, x + 4, yy + 7, 8, 1, shade(ov, 18));
      rect(ctx, x + 4, yy + 12, 8, 1, ovSh);
      // 셔츠(어깨/멜빵 사이)
      rect(ctx, x + 4, yy + 6, 8, 2, shirt);
      rect(ctx, x + 6, yy + 7, 1, 3, ovSh); rect(ctx, x + 9, yy + 7, 1, 3, ovSh); // 멜빵
      px(ctx, x + 6, yy + 9, '#d8c84a'); px(ctx, x + 9, yy + 9, '#d8c84a'); // 단추

      // 팔/소매
      const swing = action ? (Math.sin(action.prog * Math.PI) * 3 | 0) : 0;
      rect(ctx, x + 2, yy + 7 + (action ? -swing : 0), 2, 4, shirt);
      rect(ctx, x + 12, yy + 7, 2, 4, shirt);
      px(ctx, x + 2, yy + 11 + (action ? -swing : 0), skin); px(ctx, x + 13, yy + 11, skin);

      // 머리
      rect(ctx, x + 5, yy + 1, 6, 6, skin);
      rect(ctx, x + 5, yy + 6, 6, 1, skinSh);
      // 머리카락
      rect(ctx, x + 4, yy + 1, 8, 2, hair);
      rect(ctx, x + 4, yy + 2, 1, 3, hair); rect(ctx, x + 11, yy + 2, 1, 3, hair);
      // 밀짚모자
      rect(ctx, x + 3, yy, 10, 2, hat); rect(ctx, x + 3, yy + 1, 10, 1, hatSh);
      rect(ctx, x + 5, yy - 2, 6, 2, hat); rect(ctx, x + 5, yy - 2, 6, 1, shade(hat, 16));
      // 얼굴(방향)
      if (dir === 'down') { px(ctx, x + 6, yy + 4, '#3a2a1a'); px(ctx, x + 9, yy + 4, '#3a2a1a'); px(ctx, x + 7, yy + 5, skinSh); }
      else if (dir === 'up') { rect(ctx, x + 4, yy + 1, 8, 4, hair); rect(ctx, x + 3, yy, 10, 2, hat); rect(ctx, x + 5, yy - 2, 6, 2, hat); }
      else if (dir === 'left') { px(ctx, x + 6, yy + 4, '#3a2a1a'); rect(ctx, x + 10, yy + 2, 1, 4, hair); }
      else { px(ctx, x + 9, yy + 4, '#3a2a1a'); rect(ctx, x + 5, yy + 2, 1, 4, hair); }

      if (action) this.toolInHand(ctx, x, yy, dir, action.tool, action.prog);
    },

    // 손에 든 도구 + 스윙 호 (prog 0→1: 들어올렸다가 내리침)
    toolInHand(ctx, x, y, dir, tool, prog) {
      const colors = { hoe: '#b07a3a', can: '#7aa6cf', hammer: '#9aa0aa', scythe: '#c2c8d0', axe: '#9aa0aa', sword: '#dce4ee' };
      const handle = '#7a5a32';
      const c = colors[tool] || '#ccc';
      // 내리침 각도(0=위로, 1=정면 아래)
      const e = prog < 0.45 ? (prog / 0.45) * 0.3 : 0.3 + ((prog - 0.45) / 0.55) * 0.7; // 빠르게 내려침
      const sgn = dir === 'left' ? -1 : 1;
      let hx, hy;
      if (dir === 'up') { hx = x + 8; hy = y + 6 - 8 * (1 - e); }
      else if (dir === 'down') { hx = x + 9; hy = y + 4 + 8 * e; }
      else { hx = x + 8 + sgn * (3 + 6 * e); hy = y + 4 + 6 * e; }
      // 자루
      rect(ctx, hx - 1, hy - 4, 2, 7, handle);
      // 머리(도구별)
      if (tool === 'hoe') rect(ctx, hx - 2 + sgn, hy - 5, 3, 2, c);
      else if (tool === 'axe') { rect(ctx, hx - 3, hy - 5, 4, 3, c); rect(ctx, hx - 3, hy - 5, 1, 3, shade(c, 20)); }
      else if (tool === 'hammer') rect(ctx, hx - 3, hy - 5, 6, 3, c);
      else if (tool === 'scythe') { rect(ctx, hx, hy - 6, 4, 1, c); rect(ctx, hx + 3, hy - 6, 1, 3, c); }
      else if (tool === 'sword') rect(ctx, hx - 1, hy - 9, 2, 7, c);
      else if (tool === 'can') { rect(ctx, hx - 3, hy - 4, 6, 4, c); rect(ctx, hx + 2, hy - 3, 3, 1, c); if (prog > 0.5) for (let i = 0; i < 3; i++) px(ctx, hx + 5 + i, hy - 1 + i, '#9cd2f0'); }
    },
  };

  window.Sprites = Sprites;
})();
