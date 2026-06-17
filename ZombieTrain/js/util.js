/* =========================================================================
 * util.js — 공용 헬퍼 + 시드 RNG
 * ========================================================================= */
const U = {
  clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v); },
  lerp(a, b, t) { return a + (b - a) * t; },
  dist(ax, ay, bx, by) { const dx = ax - bx, dy = ay - by; return Math.hypot(dx, dy); },
  dist2(ax, ay, bx, by) { const dx = ax - bx, dy = ay - by; return dx*dx + dy*dy; },

  // 정수 자원은 반올림, 막대는 그대로
  round1(v) { return Math.round(v * 10) / 10; },

  // DOM
  $(sel, root) { return (root || document).querySelector(sel); },
  $all(sel, root) { return Array.from((root || document).querySelectorAll(sel)); },
  el(tag, cls, html) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html != null) e.innerHTML = html;
    return e;
  },

  // 색
  rgba(hex, a) {
    const n = parseInt(hex.slice(1), 16);
    return `rgba(${(n>>16)&255},${(n>>8)&255},${n&255},${a})`;
  },
  shade(hex, amt) { // amt: -1..1 (음수=어둡게)
    const n = parseInt(hex.slice(1), 16);
    let r=(n>>16)&255, g=(n>>8)&255, b=n&255;
    const f = (c) => U.clamp(Math.round(c + (amt<0 ? c*amt : (255-c)*amt)), 0, 255);
    return `rgb(${f(r)},${f(g)},${f(b)})`;
  },

  // 배열
  pick(arr, rng) { return arr[Math.floor((rng ? rng.next() : Math.random()) * arr.length)]; },
};

// roundRect 폴백 (구형 브라우저 안전)
if (typeof CanvasRenderingContext2D !== 'undefined' && !CanvasRenderingContext2D.prototype.roundRect) {
  CanvasRenderingContext2D.prototype.roundRect = function(x, y, w, h, r) {
    if (typeof r === 'number') r = [r, r, r, r];
    else if (Array.isArray(r)) { while (r.length < 4) r.push(r[r.length-1]); }
    else r = [0,0,0,0];
    this.beginPath();
    this.moveTo(x + r[0], y);
    this.arcTo(x + w, y,     x + w, y + h, r[1]);
    this.arcTo(x + w, y + h, x,     y + h, r[2]);
    this.arcTo(x,     y + h, x,     y,     r[3]);
    this.arcTo(x,     y,     x + w, y,     r[0]);
    this.closePath();
    return this;
  };
}

// 결정적 RNG (mulberry32) — 같은 시드면 같은 맵
class RNG {
  constructor(seed) { this.s = (seed >>> 0) || 1; }
  next() {
    let t = (this.s += 0x6D2B79F5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  range(lo, hi) { return lo + this.next() * (hi - lo); }
  int(lo, hi) { return Math.floor(this.range(lo, hi + 1)); }
  chance(p) { return this.next() < p; }
  pick(arr) { return arr[Math.floor(this.next() * arr.length)]; }
}
