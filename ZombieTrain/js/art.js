/* =========================================================================
 * art.js — 절차적 캔버스 드로잉
 *   기차 배경: 월드 거리 기반으로 바이옴 실루엣이 흘러가며 자연 전환
 *   탐험: 2.5D(측면 기울임) 오블리크 투영
 * ========================================================================= */
const Art = {
  skyColors(dayT) {
    const key = [
      { t:0.00, top:'#26344f', bot:'#5a6b7d' }, { t:0.22, top:'#5c86b8', bot:'#a9c4d8' },
      { t:0.52, top:'#7a5a8f', bot:'#e08a52' }, { t:0.72, top:'#2a2540', bot:'#5b3f55' },
      { t:1.00, top:'#0e1320', bot:'#231d33' },
    ];
    let a = key[0], b = key[key.length-1];
    for (let i=0;i<key.length-1;i++){ if (dayT>=key[i].t && dayT<=key[i+1].t){a=key[i];b=key[i+1];break;} }
    const f = (b.t===a.t)?0:(dayT-a.t)/(b.t-a.t);
    const mix=(c1,c2)=>{const n1=parseInt(c1.slice(1),16),n2=parseInt(c2.slice(1),16);
      return `rgb(${Math.round(U.lerp((n1>>16)&255,(n2>>16)&255,f))},${Math.round(U.lerp((n1>>8)&255,(n2>>8)&255,f))},${Math.round(U.lerp(n1&255,n2&255,f))})`;};
    return { top:mix(a.top,b.top), bot:mix(a.bot,b.bot), dark:U.clamp((dayT-0.55)/0.4,0,1) };
  },

  /* ---------------- 기차 배경(바이옴 시퀀스) ---------------- */
  // pxPerKm 레이어
  PXK_FAR: 5, PXK_MID: 15, PXK_NEAR: 34,

  trainBg(ctx, w, h, distanceKm, dayT) {
    const sky = this.skyColors(dayT);
    const g = ctx.createLinearGradient(0,0,0,h); g.addColorStop(0,sky.top); g.addColorStop(1,sky.bot);
    ctx.fillStyle = g; ctx.fillRect(0,0,w,h);
    // 해/달
    ctx.fillStyle = sky.dark>0.4 ? 'rgba(230,232,210,0.9)' : 'rgba(255,236,180,0.85)';
    ctx.beginPath(); ctx.arc(w*0.8, h*0.2, sky.dark>0.4?18:24, 0, 7); ctx.fill();

    const horizon = Math.round(h*0.60);
    // 먼 산맥(완만)
    this._farHills(ctx, w, horizon, distanceKm*this.PXK_FAR, sky.dark);

    // 중간 바이옴 실루엣 — 구간별로 해당 바이옴을 그림(자연 전환)
    const pxk = this.PXK_MID;
    const startKm = distanceKm - 6, endKm = distanceKm + w/pxk + 6;
    const seg0 = Math.floor(startKm/DATA.segmentKm), seg1 = Math.floor(endKm/DATA.segmentKm);
    for (let seg=seg0; seg<=seg1; seg++) {
      const km0 = seg*DATA.segmentKm, km1 = (seg+1)*DATA.segmentKm;
      const x0 = (km0-distanceKm)*pxk, x1 = (km1-distanceKm)*pxk;
      const bk = State.biomeKeyAt(km0);
      ctx.save(); ctx.beginPath(); ctx.rect(Math.max(0,x0), 0, Math.min(w,x1)-Math.max(0,x0)+1, horizon); ctx.clip();
      this._biomeBand(ctx, bk, x0, x1, horizon, seg, sky.dark, w);
      ctx.restore();
    }

    // 지면(바이옴 색)
    const gc = this._groundColor(State.biomeKeyAt(distanceKm), sky.dark);
    ctx.fillStyle = gc; ctx.fillRect(0, horizon, w, h-horizon);
    // 가까운 전봇대
    this._poles(ctx, w, horizon, distanceKm*this.PXK_NEAR);
    return horizon;
  },

  _farHills(ctx, w, baseY, off, dark) {
    ctx.fillStyle = U.shade('#39424a', dark*-0.5); const span=260; const start=-((off%span)+span)%span;
    ctx.beginPath(); ctx.moveTo(-10, baseY);
    for (let x=start; x<=w+span; x+=span) ctx.quadraticCurveTo(x+span*0.5, baseY-60, x+span, baseY);
    ctx.lineTo(w, baseY); ctx.closePath(); ctx.fill();
  },
  _poles(ctx, w, baseY, off) {
    const span=240; const start=-((off%span)+span)%span;
    ctx.strokeStyle='rgba(12,12,16,0.75)'; ctx.lineWidth=4;
    for (let x=start; x<=w+span; x+=span){ ctx.beginPath(); ctx.moveTo(x,baseY); ctx.lineTo(x,baseY-86); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(x-18,baseY-72); ctx.lineTo(x+18,baseY-72); ctx.stroke(); }
  },
  _groundColor(bk, dark) {
    const c = { city:'#33312e', mountain:'#4a4338', river:'#3a4a52', station:'#2f2f33',
      plains:'#3f4d2c', wasteland:'#43382c' }[bk] || '#33312e';
    return U.shade(c, dark*-0.4);
  },

  _biomeBand(ctx, bk, x0, x1, baseY, seg, dark, w) {
    const rng = new RNG(seg*131+7);
    const sh = (c)=>U.shade(c, -0.05 + dark*-0.35);
    if (bk==='city') {
      let x=x0; while (x<x1){ const bw=rng.int(34,70), bh=rng.int(70,210);
        ctx.fillStyle=sh('#222733'); ctx.fillRect(x, baseY-bh, bw, bh);
        ctx.fillStyle = dark>0.4?'rgba(255,205,90,0.12)':'rgba(20,20,30,0.3)';
        for (let wy=baseY-bh+10; wy<baseY-8; wy+=18) for (let wx=x+5; wx<x+bw-6; wx+=13) if (rng.chance(0.5)) ctx.fillRect(wx,wy,6,9);
        x += bw + rng.int(6,18); }
    } else if (bk==='mountain') {
      let x=x0-40; while (x<x1+40){ const pw=rng.int(150,260), ph=rng.int(150,300);
        ctx.fillStyle=sh('#4a4f50'); ctx.beginPath(); ctx.moveTo(x,baseY); ctx.lineTo(x+pw/2,baseY-ph); ctx.lineTo(x+pw,baseY); ctx.closePath(); ctx.fill();
        ctx.fillStyle=sh('#dfe6ea'); ctx.beginPath(); ctx.moveTo(x+pw/2,baseY-ph); ctx.lineTo(x+pw/2-18,baseY-ph+34); ctx.lineTo(x+pw/2+18,baseY-ph+34); ctx.closePath(); ctx.fill();
        x += pw*0.7; }
    } else if (bk==='river') {
      ctx.fillStyle=sh('#3c4f43'); ctx.fillRect(x0, baseY-34, x1-x0, 34); // 둑
      ctx.fillStyle = U.shade('#2f6f8f', dark*-0.4); ctx.fillRect(x0, baseY-14, x1-x0, 14);
      ctx.strokeStyle='rgba(200,230,240,0.25)'; ctx.lineWidth=2;
      for (let x=x0; x<x1; x+=26){ ctx.beginPath(); ctx.moveTo(x,baseY-8); ctx.lineTo(x+12,baseY-8); ctx.stroke(); }
      // 교각
      for (let x=x0+30; x<x1; x+=110){ ctx.fillStyle=sh('#3a3f44'); ctx.fillRect(x,baseY-58,8,58); }
    } else if (bk==='station') {
      ctx.fillStyle=sh('#444a5c'); ctx.fillRect(x0+10, baseY-70, Math.max(40,(x1-x0)-20), 70);
      ctx.fillStyle=sh('#2c3140'); ctx.fillRect(x0, baseY-22, x1-x0, 22); // 플랫폼
      ctx.fillStyle = dark>0.4?'rgba(255,210,120,0.5)':'rgba(255,255,255,0.4)';
      for (let x=x0+20; x<x1-10; x+=40) ctx.fillRect(x, baseY-58, 14, 16);
      for (let x=x0+24; x<x1; x+=120){ ctx.strokeStyle=sh('#555'); ctx.lineWidth=3; ctx.beginPath(); ctx.moveTo(x,baseY-22); ctx.lineTo(x,baseY-78); ctx.stroke(); }
    } else if (bk==='plains') {
      ctx.fillStyle=sh('#566b32'); ctx.fillRect(x0, baseY-16, x1-x0, 16);
      for (let x=x0; x<x1; x+=rng.int(60,120)){ ctx.fillStyle=sh('#2f5524'); ctx.beginPath(); ctx.arc(x, baseY-26, rng.int(12,20), 0, 7); ctx.fill();
        ctx.fillStyle=sh('#4a3522'); ctx.fillRect(x-2, baseY-22, 4, 12); }
      if (rng.chance(0.6)){ const fx=x0+rng.range(20,Math.max(30,x1-x0-60)); ctx.fillStyle=sh('#6b4a30'); ctx.fillRect(fx,baseY-44,46,44);
        ctx.fillStyle=sh('#7a3030'); ctx.beginPath(); ctx.moveTo(fx-4,baseY-44); ctx.lineTo(fx+23,baseY-62); ctx.lineTo(fx+50,baseY-44); ctx.fill(); }
    } else { // wasteland
      for (let x=x0; x<x1; x+=rng.int(50,100)){ ctx.strokeStyle=sh('#3a342c'); ctx.lineWidth=4;
        ctx.beginPath(); ctx.moveTo(x,baseY); ctx.lineTo(x+rng.range(-6,6),baseY-rng.int(30,60)); ctx.stroke();
        ctx.fillStyle=sh('#2c2922'); ctx.beginPath(); ctx.arc(x+rng.range(-20,20), baseY-4, rng.int(6,14), 0, 7); ctx.fill(); }
    }
  },

  rails(ctx, w, railY, scroll) {
    ctx.fillStyle='#1c1a17'; ctx.fillRect(0, railY+12, w, 8);
    const span=34; const start=-((scroll%span)+span)%span;
    ctx.fillStyle='#3a342c'; for (let x=start;x<=w;x+=span) ctx.fillRect(x, railY+9, 10, 16);
    ctx.fillStyle='#6b6256'; ctx.fillRect(0, railY+10, w, 3); ctx.fillRect(0, railY+20, w, 3);
  },

  /* ---------------- 기차(횡스크롤) ---------------- */
  cab(ctx,x,y,w,h,dmg){ const base='#7a2f2f';
    ctx.fillStyle=U.shade(base,-0.1); ctx.fillRect(x,y,w,h); ctx.fillStyle=U.shade(base,0.12); ctx.fillRect(x,y,w,12);
    ctx.fillStyle=U.shade(base,-0.25); ctx.beginPath(); ctx.moveTo(x+w,y); ctx.lineTo(x+w+26,y+h*0.45); ctx.lineTo(x+w,y+h*0.45); ctx.fill();
    ctx.fillStyle='#bfe2ff'; ctx.fillRect(x+w-34,y+12,26,22); ctx.fillStyle='#333'; ctx.fillRect(x+14,y-14,14,16);
    this._wheels(ctx,x,y+h,w); this._damage(ctx,x,y,w,h,dmg); },
  car(ctx,x,y,w,h,opts){ opts=opts||{}; const base=opts.occupied?'#3c5a78':'#445';
    ctx.fillStyle=U.shade(base,-0.08); ctx.fillRect(x,y,w,h); ctx.fillStyle=U.shade(base,0.14); ctx.fillRect(x,y,w,11);
    ctx.strokeStyle='rgba(0,0,0,0.3)'; ctx.lineWidth=2; ctx.strokeRect(x+0.5,y+0.5,w-1,h-1);
    ctx.fillStyle=opts.occupied?'#ffe9a8':'#9fb8cc'; for(let i=0;i<3;i++) ctx.fillRect(x+14+i*(w-28)/3, y+16, (w-28)/3-10, 20);
    ctx.fillStyle=U.shade(base,-0.3); ctx.fillRect(x+w/2-9, y+h-30, 18, 30);
    if (opts.farm){ ctx.font='15px serif'; ctx.textAlign='center'; ctx.fillText(opts.ripe?'🌾':'🌱', x+w/2, y-3); }
    this._wheels(ctx,x,y+h,w); this._damage(ctx,x,y,w,h,opts.dmg||0); },
  _wheels(ctx,x,baseY,w){ ctx.fillStyle='#15130f'; const ys=baseY-2;
    for (const wx of [x+24,x+w-24]){ ctx.beginPath(); ctx.arc(wx,ys,11,0,7); ctx.fill();
      ctx.fillStyle='#3a342c'; ctx.beginPath(); ctx.arc(wx,ys,4,0,7); ctx.fill(); ctx.fillStyle='#15130f'; } },
  _damage(ctx,x,y,w,h,dmg){ if (dmg<=0.02) return; ctx.strokeStyle=`rgba(20,12,8,${0.25+dmg*0.5})`; ctx.lineWidth=2;
    const r=new RNG(Math.floor(x)+1); const cr=Math.floor(dmg*7);
    for(let i=0;i<cr;i++){ let px=x+r.range(6,w-6),py=y+r.range(6,h-6); ctx.beginPath(); ctx.moveTo(px,py);
      for(let j=0;j<3;j++){ px+=r.range(-12,12); py+=r.range(-10,10); ctx.lineTo(px,py);} ctx.stroke(); }
    if (dmg>0.6){ ctx.fillStyle=`rgba(120,60,20,${(dmg-0.6)*0.6})`; ctx.fillRect(x,y,w,h);} },
  personSide(ctx,x,y,color,t){ const bob=Math.sin(t*8)*1.5; ctx.save(); ctx.translate(x,y+bob);
    ctx.strokeStyle='#2a2a2a'; ctx.lineWidth=4; ctx.lineCap='round'; const sw=Math.sin(t*10)*4;
    ctx.beginPath(); ctx.moveTo(0,0); ctx.lineTo(sw,12); ctx.stroke(); ctx.beginPath(); ctx.moveTo(0,0); ctx.lineTo(-sw,12); ctx.stroke();
    ctx.fillStyle=color; ctx.fillRect(-6,-18,12,18); ctx.fillStyle='#e9c39b'; ctx.beginPath(); ctx.arc(0,-24,6,0,7); ctx.fill(); ctx.restore(); },

  /* ---------------- 탐험 2.5D ----------------
   * P = { cx, cy, ys, oy }  (camera x/y, yScale, originY)
   * 화면좌표: sx = wx - cx ;  sy = (wy - cy)*ys + oy
   */
  sy(P, wy){ return (wy - P.cy)*P.ys + P.oy; },
  sx(P, wx){ return wx - P.cx; },

  exGround(ctx, sc, P, w, h){
    // 바이옴 색 지면 전체
    ctx.fillStyle = this._groundColor(sc.biomeKey, 0.1); ctx.fillRect(0,0,w,h);
    // 흙/풀 디테일
    const dr=new RNG(7); ctx.fillStyle='rgba(0,0,0,0.12)';
    for (let i=0;i<140;i++){ const x=this.sx(P,dr.range(0,sc.w)), y=this.sy(P,dr.range(0,sc.h)); ctx.fillRect(x,y,3,2); }
    // 도로(가로) — 2.5D 띠
    const ry0=this.sy(P, sc.h/2-50), ry1=this.sy(P, sc.h/2+50);
    ctx.fillStyle='#33333a'; ctx.fillRect(this.sx(P,0), ry0, sc.w, ry1-ry0);
    ctx.strokeStyle='rgba(220,200,80,0.4)'; ctx.lineWidth=3; ctx.setLineDash([18,16]);
    ctx.beginPath(); ctx.moveTo(this.sx(P,0),(ry0+ry1)/2); ctx.lineTo(this.sx(P,sc.w),(ry0+ry1)/2); ctx.stroke(); ctx.setLineDash([]);
  },

  _box(ctx, x, gy, w, wallH, roofH, roofColor, wallColor){
    // 그림자
    ctx.fillStyle='rgba(0,0,0,0.28)'; ctx.beginPath(); ctx.ellipse(x+w/2, gy+4, w*0.55, 8, 0,0,7); ctx.fill();
    // 앞벽
    ctx.fillStyle=wallColor; ctx.fillRect(x, gy-wallH, w, wallH);
    // 지붕(윗면)
    ctx.fillStyle=roofColor; ctx.fillRect(x, gy-wallH-roofH, w, roofH+2);
    ctx.strokeStyle='rgba(0,0,0,0.35)'; ctx.lineWidth=1.5; ctx.strokeRect(x+0.5, gy-wallH-roofH+0.5, w-1, wallH+roofH-1);
  },
  // 지붕/외관(lid). inside=true면 반투명 처리해 내부 가구가 보이게(진입형 파밍)
  exBuilding(ctx, b, P, inside){
    const x=this.sx(P,b.x), gyFront=this.sy(P, b.y+b.h), gyBack=this.sy(P, b.y);
    const roofH = gyFront - gyBack; // 윗면 두께(원근)
    const wallH = CONFIG.explore.wallH;
    if (inside){
      ctx.save(); ctx.globalAlpha=0.16;
      this._box(ctx, x, gyFront, b.w, wallH, roofH, U.shade(b.def.color,0.05), U.shade(b.def.color,-0.28));
      ctx.restore();
      ctx.strokeStyle='rgba(255,255,255,0.22)'; ctx.lineWidth=1.5; ctx.strokeRect(x+0.5, gyBack-0.5, b.w-1, gyFront-gyBack+1);
      ctx.font='bold 10px sans-serif'; ctx.fillStyle='rgba(230,235,240,0.55)'; ctx.textAlign='center'; ctx.textBaseline='alphabetic';
      ctx.fillText(`${b.def.icon} ${b.def.name} 내부`, x+b.w/2, gyBack+12);
      return;
    }
    this._box(ctx, x, gyFront, b.w, wallH, roofH, U.shade(b.def.color,0.05), U.shade(b.def.color,-0.28));
    // 라벨/아이콘(지붕 위)
    ctx.font='20px serif'; ctx.textAlign='center'; ctx.textBaseline='middle';
    ctx.fillText(b.def.icon, x+b.w/2, gyFront-wallH-roofH/2-2);
    ctx.font='bold 11px sans-serif'; ctx.fillStyle='rgba(255,255,255,0.9)';
    ctx.fillText(b.def.name, x+b.w/2, gyFront-wallH-roofH/2+14);
    // 출입구(앞벽): 🔒잠김 / 🚪닫힘 / 열림(들어갈 수 있음)
    const remaining = (b.furniture||[]).some(f=>!f.searched || (f.items&&f.items.length));
    const dw=CONFIG.explore.doorGap*0.6, dx=x+b.w/2-dw/2, dy=gyFront-wallH;
    ctx.font='12px sans-serif'; ctx.textBaseline='middle';
    if (b.locked){
      ctx.fillStyle='#241c12'; ctx.fillRect(dx, dy, dw, wallH);
      ctx.fillStyle='#ffcf6e'; ctx.fillText('🔒', x+b.w/2, dy+wallH/2);
    } else if (!b.open){
      ctx.fillStyle='#3a2e1c'; ctx.fillRect(dx, dy, dw, wallH);
      ctx.fillStyle='#caa86a'; ctx.fillText('🚪', x+b.w/2, dy+wallH/2);
    } else {
      ctx.fillStyle='#1a1712'; ctx.fillRect(dx, dy, dw, wallH);   // 열린 어두운 출입구
      ctx.fillStyle = remaining ? '#f1d27a' : '#7a8a6a';
      ctx.fillText(remaining?'🚪':'✓', x+b.w/2, dy+wallH/2);
    }
    ctx.textBaseline='alphabetic';
  },
  // 건물 바닥+벽(지붕 아래에 깔림 → 진입 시 보임)
  exRoomFloor(ctx, b, P, inside){
    const x=this.sx(P,b.x), y0=this.sy(P,b.y), y1=this.sy(P,b.y+b.h);
    ctx.fillStyle='rgba(0,0,0,0.26)'; ctx.beginPath(); ctx.ellipse(x+b.w/2, y1+5, b.w*0.55, 9, 0,0,7); ctx.fill();
    ctx.fillStyle=U.shade(b.def.color,-0.5); ctx.fillRect(x, y0, b.w, y1-y0);   // 바닥
    ctx.strokeStyle='rgba(255,255,255,0.04)'; ctx.lineWidth=1;                   // 타일 줄
    for (let gx=x+20; gx<x+b.w-4; gx+=22){ ctx.beginPath(); ctx.moveTo(gx,y0); ctx.lineTo(gx,y1); ctx.stroke(); }
    ctx.fillStyle=U.shade(b.def.color,-0.18);                                    // 벽(충돌과 동일 위치)
    for (const s of (b.walls||[])){ ctx.fillRect(this.sx(P,s.x), this.sy(P,s.y), s.w, this.sy(P,s.y+s.h)-this.sy(P,s.y)); }
    ctx.fillStyle='rgba(255,255,255,0.06)';
    for (const s of (b.walls||[])){ ctx.fillRect(this.sx(P,s.x), this.sy(P,s.y), s.w, 1.5); }
    if (b.doorGap){ const dx0=this.sx(P,b.doorGap.x0), dgw=b.doorGap.x1-b.doorGap.x0, fy=this.sy(P,b.y+b.h-CONFIG.explore.wallThick);
      if (b.open){ ctx.fillStyle=inside?'rgba(241,210,122,0.30)':'rgba(241,210,122,0.15)'; ctx.fillRect(dx0, y1-4, dgw, 6); }   // 열림: 발판
      else { // 닫힘/잠김: 문짝
        const wh=this.sy(P,b.y+b.h)-fy+4;
        ctx.fillStyle=b.locked?'#5a4326':'#6e5230'; ctx.fillRect(dx0, fy, dgw, wh);
        ctx.strokeStyle='rgba(0,0,0,0.45)'; ctx.lineWidth=1; ctx.strokeRect(dx0+0.5, fy+0.5, dgw-1, wh-1);
        ctx.fillStyle='#caa86a'; ctx.fillRect(dx0+dgw-7, fy+wh/2-1.5, 3, 3);   // 손잡이
        if (b.break>0){ ctx.fillStyle='rgba(0,0,0,0.6)'; ctx.fillRect(dx0, fy-7, dgw, 5);   // 파손 진행
          ctx.fillStyle='#ff6a4a'; ctx.fillRect(dx0+1, fy-6, (dgw-2)*U.clamp(b.break,0,1), 3); } }
    }
  },
  // 가구 컨테이너(캐비넷·책상·서랍장·냉장고·진열장…)
  exFurniture(ctx, f, P, searchable, near){
    const x=this.sx(P,f.x), gy=this.sy(P,f.y), d=f.def, w=d.w||24, hh=13;
    ctx.fillStyle='rgba(0,0,0,0.25)'; ctx.beginPath(); ctx.ellipse(x,gy+3,w*0.5,4.5,0,0,7); ctx.fill();
    ctx.fillStyle=U.shade(d.color,-0.22); ctx.fillRect(x-w/2, gy-hh, w, hh);     // 앞면
    ctx.fillStyle=d.color; ctx.fillRect(x-w/2, gy-hh-6, w, 7);                    // 윗면
    ctx.strokeStyle='rgba(0,0,0,0.4)'; ctx.lineWidth=1; ctx.strokeRect(x-w/2+0.5, gy-hh-6+0.5, w-1, hh+6);
    if (!searchable){ ctx.fillStyle='rgba(0,0,0,0.4)'; ctx.fillRect(x-w/2, gy-hh-6, w, hh+6); }   // 다 뒤진 건 어둡게
    ctx.font='12px serif'; ctx.textAlign='center'; ctx.textBaseline='middle';
    ctx.fillText(d.icon, x, gy-hh/2-1); ctx.textBaseline='alphabetic';
    if (!searchable){ ctx.fillStyle='rgba(120,220,140,0.85)'; ctx.font='10px sans-serif'; ctx.textAlign='center'; ctx.fillText('✓', x, gy-hh-10); }
    else if (near){ ctx.fillStyle='#f1d27a'; ctx.font='bold 11px sans-serif'; ctx.textAlign='center'; ctx.fillText('[E] '+d.name, x, gy-hh-11); }
  },
  // 공격 조준/판정 부채꼴(2.5D 투영) — 클릭 방향 ang, 반각 half, 반지름 r
  exAimFan(ctx, P, wx, wy, ang, half, r, alpha, solid){
    const cx=this.sx(P,wx), cy=this.sy(P,wy), ys=CONFIG.explore.yScale;
    ctx.save(); ctx.beginPath(); ctx.moveTo(cx,cy);
    const N=20; for (let i=0;i<=N;i++){ const a=ang-half+(2*half)*(i/N); ctx.lineTo(cx+Math.cos(a)*r, cy+Math.sin(a)*r*ys); }
    ctx.closePath();
    ctx.fillStyle=`rgba(255,236,150,${alpha})`; ctx.fill();
    ctx.lineWidth=solid?2.5:1.5; ctx.strokeStyle=`rgba(255,226,110,${Math.min(0.95, alpha*(solid?3:2))})`; ctx.stroke();
    ctx.restore();
  },
  // 소리 파동 — 달리기/공격/문 부수기 시 퍼지는 반경(2.5D 타원, 옅게)
  exNoiseRing(ctx, P, wx, wy, r){
    const cx=this.sx(P,wx), cy=this.sy(P,wy), ys=CONFIG.explore.yScale;
    ctx.save(); ctx.lineWidth=1.5;
    for (const k of [0.55, 1.0]){ ctx.beginPath(); ctx.ellipse(cx,cy,r*k,r*k*ys,0,0,7);
      ctx.strokeStyle=`rgba(255,210,120,${0.16*(1.2-k)})`; ctx.stroke(); }
    ctx.restore();
  },
  // 폭염(전역 날씨) — 따뜻한 주황 빛 + 위쪽 강한 햇빛
  heat(ctx, w, h, intensity){
    if (intensity<=0.02) return;
    ctx.save();
    ctx.fillStyle=`rgba(255,150,40,${intensity*0.10})`; ctx.fillRect(0,0,w,h);
    const g=ctx.createLinearGradient(0,0,0,h*0.5); g.addColorStop(0,`rgba(255,214,120,${intensity*0.20})`); g.addColorStop(1,'rgba(255,214,120,0)');
    ctx.fillStyle=g; ctx.fillRect(0,0,w,h*0.5);
    ctx.restore();
  },
  // 비(전역 날씨) — 화면 전체에 사선 빗줄기 + 푸른 어둑함
  rain(ctx, w, h, intensity, t){
    if (intensity<=0.02) return;
    ctx.save();
    const n=Math.floor(intensity*170);
    ctx.strokeStyle=`rgba(180,200,220,${0.16+intensity*0.22})`; ctx.lineWidth=1; ctx.beginPath();
    for (let i=0;i<n;i++){ const seed=i*9301+49297, sp=320+(seed%9)*45;
      const colX=(seed%1000)/1000*(w+60)-30;
      const y=((t*sp + (seed%977)) % (h+60))-30;
      const x=(colX + y*0.32) % (w+60) - 30;
      ctx.moveTo(x,y); ctx.lineTo(x-4, y+13); }
    ctx.stroke();
    ctx.fillStyle=`rgba(40,55,75,${intensity*0.16})`; ctx.fillRect(0,0,w,h);
    ctx.restore();
  },
  exCar(ctx, c, P, searchable){ const x=this.sx(P,c.x), gy=this.sy(P,c.y);
    ctx.fillStyle='rgba(0,0,0,0.25)'; ctx.beginPath(); ctx.ellipse(x,gy+3,22,7,0,0,7); ctx.fill();
    const ring = c.alarm==='ringing';
    ctx.fillStyle = ring?'#c2502f':(searchable?'#8a8f99':'#4a4d52'); ctx.beginPath(); ctx.roundRect(x-20,gy-22,40,22,6); ctx.fill();
    ctx.fillStyle='#cfe6ff'; ctx.fillRect(x-12,gy-18,24,11);
    ctx.font='12px serif'; ctx.textAlign='center'; ctx.textBaseline='middle';
    if (searchable) ctx.fillText('🚗',x,gy-26);
    else { ctx.fillStyle='rgba(120,220,140,0.85)'; ctx.font='10px sans-serif'; ctx.fillText('✓',x,gy-26); }
    ctx.textBaseline='alphabetic';
    if (c.alarm && c.alarm!=='none'){ const blink = ring ? (Math.floor((c.alarmT||0)*6)%2===0) : true;   // 작동 중엔 깜빡
      if (blink){ ctx.font='13px serif'; ctx.textAlign='center'; ctx.textBaseline='middle'; ctx.fillText('🔔', x+16, gy-24); ctx.textBaseline='alphabetic'; } } },
  exHide(ctx, hsp, P, occupied){ const x=this.sx(P,hsp.x), gy=this.sy(P,hsp.y);
    ctx.fillStyle='rgba(0,0,0,0.25)'; ctx.beginPath(); ctx.ellipse(x,gy+3,20,7,0,0,7); ctx.fill();
    ctx.globalAlpha = occupied?0.6:1; ctx.font='26px serif'; ctx.textAlign='center'; ctx.textBaseline='bottom';
    ctx.fillText(hsp.icon, x, gy+6); ctx.globalAlpha=1; ctx.textBaseline='alphabetic';
    if (occupied){ ctx.fillStyle='rgba(120,220,140,0.9)'; ctx.font='11px sans-serif'; ctx.textAlign='center'; ctx.fillText('은신중', x, gy-26); } },
  exFarmPlot(ctx, fp, P){ const x=this.sx(P,fp.x), gy=this.sy(P,fp.y);
    ctx.fillStyle='#5a3f28'; ctx.fillRect(x-26, gy-10, 52, 18);
    ctx.font='12px serif'; ctx.textAlign='center'; for(let i=0;i<3;i++) ctx.fillText('🌱', x-16+i*16, gy);
    if (fp.fenced){ ctx.strokeStyle='#9a7b4a'; ctx.lineWidth=2; ctx.strokeRect(x-30, gy-14, 60, 26); } },
  exTrainEdge(ctx, e, P){ const x=this.sx(P,e.x), gy=this.sy(P,e.y+e.h);
    this._box(ctx, x, gy, e.w, 36, this.sy(P,e.y+e.h)-this.sy(P,e.y), '#5a2323', '#7a2f2f');
    ctx.font='22px serif'; ctx.textAlign='center'; ctx.textBaseline='middle'; ctx.fillText('🚂', x+e.w/2, gy-34);
    ctx.fillStyle='#fff'; ctx.font='bold 11px sans-serif'; ctx.fillText('복귀', x+e.w/2, gy-12); ctx.textBaseline='alphabetic'; },

  // 사지(둥근 선)
  _limb(ctx, x1,y1,x2,y2,w,col){ ctx.strokeStyle=col; ctx.lineWidth=w; ctx.lineCap='round';
    ctx.beginPath(); ctx.moveTo(x1,y1); ctx.lineTo(x2,y2); ctx.stroke(); },

  /* 간단한 사람/좀비 골격 + 애니메이션
   * o: { t, phase, color, skin, scale, moving, run, faceX, attack(0~1), reach, lean,
   *      hurt, flash, zombie, alpha, wave } */
  _figure(ctx, x, gy, o){
    const s=o.scale||1, t=o.t||0, ph0=o.phase||0;
    const col=o.color||'#ffd34d', skin=o.skin||'#e9c39b';
    const moving=!!o.moving, run=!!o.run;
    const fx=(o.faceX==null||o.faceX>=0)?1:-1;
    const flash=!!o.flash, hurt=!!o.hurt;
    const alpha=(o.alpha==null)?1:o.alpha;
    // 걷기/뛰기 사이클(달리면 빠르고 크게)
    const freq=run?16:9, ph=t*freq+ph0;
    const amp=moving?((run?6.5:4.2)*s):0;
    const sw=Math.sin(ph)*amp;                                   // 다리 스윙
    const bob=moving?Math.abs(Math.sin(ph))*(run?2.4:1.2)*s      // 걷기 들썩
                    :Math.sin(t*2.4+ph0)*0.5*s;                  // 정지 시 숨쉬기
    const lean=(o.lean||0)*s*fx;                                 // 좀비 앞으로 숙임
    const recoil=hurt?-2.4*s*fx:0;                               // 피격 움찔(뒤로)
    const up=-bob;
    const hipY=gy-11*s+up, shY=gy-20*s+up, headY=gy-27*s+up+(hurt?1.6*s:0), hR=5.2*s;
    const bodyCol=flash?'#ffffff':(hurt?'#ff7b6b':col);
    const headCol=flash?'#ffe6da':(hurt?'#ffd0c0':skin);
    const legCol =flash?'#dddddd':U.shade(col,-0.35);
    ctx.save(); ctx.globalAlpha=alpha;
    ctx.fillStyle='rgba(0,0,0,0.3)'; ctx.beginPath(); ctx.ellipse(x,gy+2,8.5*s,3.4*s,0,0,7); ctx.fill();
    const cx=x+recoil, shX=cx+lean*0.6;
    // 다리(반대 위상)
    this._limb(ctx, cx, hipY, cx-sw, gy, 3.4*s, legCol);
    this._limb(ctx, cx, hipY, cx+sw, gy, 3.4*s, legCol);
    // 몸통
    this._limb(ctx, cx, hipY, shX, shY, 5*s, bodyCol);
    // 팔
    const armSwing=Math.sin(ph+Math.PI)*amp*0.85;
    if (o.attack>0){                                             // 공격: 정면으로 내지름
      const r=(7+11*o.attack)*s;
      this._limb(ctx, shX, shY+1*s, shX+fx*r, shY-2*s, 3.1*s, bodyCol);
      this._limb(ctx, shX, shY+1*s, shX+fx*(r-3*s), shY+4*s, 3.1*s, bodyCol);
    } else if (o.reach){                                         // 좀비: 양팔 앞으로(긁기)
      const claw=Math.sin(t*8+ph0)*2*s, r=10*s+claw;
      this._limb(ctx, shX, shY+1*s, shX+fx*r, shY-1*s+claw*0.5, 3*s, bodyCol);
      this._limb(ctx, shX, shY+1*s, shX+fx*r, shY+3*s-claw*0.5, 3*s, bodyCol);
    } else if (o.wave){                                          // 생존자: 손 흔들기
      const wv=Math.sin(t*8)*4*s;
      this._limb(ctx, shX, shY+1*s, cx-5*s, hipY, 3*s, bodyCol);
      this._limb(ctx, shX, shY+1*s, cx+6*s, shY-10*s+wv, 3*s, bodyCol);
    } else {                                                     // 평소: 양옆 흔들흔들
      this._limb(ctx, shX, shY+1*s, cx-4.5*s-armSwing*0.7, hipY+1*s, 3*s, bodyCol);
      this._limb(ctx, shX, shY+1*s, cx+4.5*s+armSwing*0.7, hipY+1*s, 3*s, bodyCol);
    }
    // 머리
    const headX=cx+lean*1.0;
    ctx.fillStyle=headCol; ctx.beginPath(); ctx.arc(headX,headY,hR,0,7); ctx.fill();
    if (flash){ ctx.strokeStyle='rgba(255,120,90,0.95)'; ctx.lineWidth=1.6; ctx.stroke(); }
    if (o.zombie){ ctx.fillStyle='rgba(170,35,28,0.9)';   // 붉은 눈
      ctx.fillRect(headX+fx*0.4-1.3*s, headY-0.8*s, 1.5*s,1.5*s);
      ctx.fillRect(headX+fx*2.6-1.3*s, headY-0.8*s, 1.3*s,1.3*s); }
    ctx.restore();
  },

  exPerson(ctx, p, P, color, t){
    const x=this.sx(P,p.x), gy=this.sy(P,p.y);
    const attack=p.swingT>0?U.clamp(p.swingT/0.18,0,1):0;
    this._figure(ctx, x, gy, { t, color:color||'#ffd34d', scale:1.06,
      moving:p.moving, run:p.running, faceX:p.faceX,
      attack, hurt:p.hitFlash>0, alpha:p.hidden?0.5:1 });
  },
  exFollower(ctx, f, P, t, m){
    const x=this.sx(P,f.x), gy=this.sy(P,f.y);
    if (f.swingT>0){ const cy=gy-12, rr=CONFIG.explore.followerAttackRange*0.9, a=U.clamp(f.swingT/0.18,0,1);
      ctx.save(); ctx.beginPath(); ctx.ellipse(x,cy,rr,rr*CONFIG.explore.yScale,0,0,Math.PI*2);
      ctx.strokeStyle=`rgba(120,232,205,${0.5*a})`; ctx.lineWidth=2; ctx.stroke(); ctx.restore(); }
    const attack=f.swingT>0?U.clamp(f.swingT/0.18,0,1):0;
    this._figure(ctx, x, gy, { t, color:'#5fcdb6', scale:1.0,
      moving:f.moving, run:f.run, faceX:f.faceX, attack, hurt:f.hurtT>0 });   // 동료=청록(플레이어=금색)
    const label=`${m?DATA.traits[m.trait].icon:'🤝'}${m?m.name:''}`;
    ctx.font='10px sans-serif'; ctx.textAlign='center';
    const lw=ctx.measureText(label).width+8;
    ctx.fillStyle='rgba(0,0,0,0.45)'; ctx.fillRect(x-lw/2, gy-38, lw, 13);
    ctx.fillStyle=(m&&m.infected)?'#ffb38a':'#bff0e4'; ctx.fillText(label, x, gy-28);
  },
  exZombie(ctx, z, P, t){
    const x=this.sx(P,z.x), gy=this.sy(P,z.y), r=z.r||9, col=z.color||'#5b7a4a';
    this._figure(ctx, x, gy, { t, phase:z.phase, color:col, skin:U.shade(col,0.22),
      scale:r/9, moving:z.moving, run:z.alerted, faceX:(z.hx==null?-1:(z.hx>=0?1:-1)),
      lean:3.4, reach:(z.alerted||z.atTrain), flash:z.hitFlash>0, zombie:true });
    if (z.hp<z.maxHp){ ctx.fillStyle='#2a0f0f'; ctx.fillRect(x-r,gy-r*2-16,r*2,3); ctx.fillStyle='#d33'; ctx.fillRect(x-r,gy-r*2-16,r*2*(z.hp/z.maxHp),3); }
    if (z.alerted){ ctx.fillStyle='#ff5a4a'; ctx.font='12px sans-serif'; ctx.textAlign='center'; ctx.fillText('!',x,gy-r*2-8); }
    else if (z.investigate){ ctx.fillStyle='#ffd06a'; ctx.font='bold 12px sans-serif'; ctx.textAlign='center'; ctx.fillText('?',x,gy-r*2-8); }   // 소리 조사 중
    else if (z.atTrain){ ctx.fillStyle='#ffae4a'; ctx.font='11px sans-serif'; ctx.textAlign='center'; ctx.fillText('⚒',x,gy-r*2-8); }
  },
  exSurvivor(ctx, s, P, t){
    const x=this.sx(P,s.x), gy=this.sy(P,s.y);
    this._figure(ctx, x, gy, { t, color:'#d9a441', scale:1.0, faceX:1, wave:true });
    ctx.font='13px serif'; ctx.textAlign='center'; ctx.fillText('🆘', x, gy-34+Math.sin(t*4)*2);
  },
};
