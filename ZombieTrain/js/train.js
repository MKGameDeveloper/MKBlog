/* =========================================================================
 * train.js — 기차 모드(횡스크롤). 바이옴 배경 + 자원/크루 시뮬 + 이동/상호작용
 * ========================================================================= */
const Train = {
  CAR_W: 168, CAR_H: 104, GAP: 16, CAB_W: 148,
  player: { x: 0, t: 0 }, cam: { x: 0 }, scroll: 0, nearest: null, _lastBiome: null,

  enter() {
    const lay = this.layout();
    if (this.player.x < lay.xMin || this.player.x > lay.xMax) this.player.x = lay.cab.x + 20;
    this.cam.x = this.player.x;
    this._lastBiome = State.currentBiomeKey();
  },

  layout() {
    const n = state.cars.length, seg = this.CAR_W + this.GAP;
    const cab = { x: n*seg, w: this.CAB_W };
    const cars = [];
    for (let i=0;i<n;i++) cars.push({ car: state.cars[i], x: cab.x - (i+1)*seg, w: this.CAR_W });
    const xMin = (cars.length ? cars[cars.length-1].x : cab.x) + 12;
    const xMax = cab.x + cab.w - 12;
    return { cab, cars, xMin, xMax };
  },

  update(dt) {
    this.player.t += dt;
    const lay = this.layout();
    this.player.x = U.clamp(this.player.x + Input.x*150*dt, lay.xMin, lay.xMax);
    this.cam.x = U.lerp(this.cam.x, this.player.x, 1 - Math.pow(0.001, dt));
    this.nearest = this._findNearest(lay);
    this._sim(dt);
    if ((Input.interactEdge||Input.attackEdge) && this.nearest) { Input.interactEdge=false; Input.attackEdge=false; this._interact(); }
  },

  _findNearest(lay) {
    const px=this.player.x; let best=null, bestD=72;
    const cc=lay.cab.x+lay.cab.w/2; if (Math.abs(px-cc)<bestD){ best={type:'cab',x:cc,label:'🎛️ 운행실'}; bestD=Math.abs(px-cc); }
    lay.cars.forEach((c,i)=>{ const cx=c.x+c.w/2, d=Math.abs(px-cx);
      if (d<bestD){ bestD=d; const occ=c.car.companionId?State.crewById(c.car.companionId):null;
        const label = occ ? `${DATA.traits[occ.trait].icon} ${occ.name}` : '🚪 빈 객차';
        best={type:'car',idx:i,x:cx,label}; } });
    return best;
  },

  _sim(dt) {
    const r=state.res, eff=State.effects();
    const dark = Art.skyColors(state.dayT).dark;
    // 시간/낮밤
    state.dayT += dt / CONFIG.time.dayLengthSec * (state.running?1:0.5);
    while (state.dayT>=1){ state.dayT-=1; state.day++; state.stats.daysSurvived=state.day; }

    // 개인별 크루(식량/물/멘탈/감염/체력) — 기차 안은 비/추위로부터 보호됨
    state._exposed = false;
    State.updateCrew(dt, dark>0.45);

    // 내부 농사 성장(실시간, 워커 1명 점유)
    const f=state.innerFarm;
    if (f.active && !f.ripe){ f.progressSec += dt*eff.farmSpeedMul; if (f.progressSec>=CONFIG.farm.inner.growSec){ f.ripe=true; UI.toast('🌱 내부 농작물 수확 준비 완료'); } }

    if (state.running) {
      const spd=CONFIG.speeds[state.speedIdx];
      const dkm=spd.kmh*dt*CONFIG.distanceScale; state.distanceKm+=dkm; state.stats.km=state.distanceKm;
      this.scroll += spd.kmh*dt*1.1;
      r.fuel=U.clamp(r.fuel - CONFIG.fuel.perSec*spd.f*eff.fuelEffMul*dt, 0, CONFIG.max.fuel);
      if (eff.durRegenPerSec) r.durability=U.clamp(r.durability+eff.durRegenPerSec*dt,0,CONFIG.max.durability);

      // 바이옴 전환 알림
      const bk=State.currentBiomeKey();
      if (bk!==this._lastBiome){ this._lastBiome=bk; const b=DATA.biomes[bk]; UI.toast(`${b.icon} ${b.name} 진입`); }

      // 외부 농장 성장/소멸
      this._tickOuterFarms();

      // 정차 목표 도착
      if (state.stopTargetKm!=null && state.distanceKm>=state.stopTargetKm){
        state.stopTargetKm=null; this.stopTrain();
        UI.toast('📍 정차 목표 도착! 운행실에서 탐험을 시작하세요');
      }
      // 연료 고갈
      if (r.fuel<=0){ state.running=false; state.speedIdx=0; state.stranded=true;
        UI.toast('⛽ 연료 고갈! 기차가 멈췄습니다 — 주변은 불모지입니다'); }
    }
  },

  _tickOuterFarms() {
    for (const fm of state.farms) {
      if (fm.harvested || !fm.alive) continue;
      if (!fm.ripe && state.distanceKm>=fm.dueKm){ fm.ripe=true; UI.toast('🌾 외부 농장이 다 자랐습니다 — 맵에서 위치 확인 후 정차'); }
      if (fm.ripe && state.distanceKm > fm.dueKm + 90){
        // 수확 시기를 놓침 → 울타리 없으면 소멸(있으면 한 번 더 버팀)
        if (fm.fenced && !fm._saved){ fm._saved=true; fm.dueKm = state.distanceKm + 60; }
        else { fm.alive=false; UI.toast('🥀 방치된 외부 농장이 좀비/야생에 망가졌습니다'); }
      }
    }
  },

  setSpeedRunning(){ /* helper noop */ },
  stopTrain(){ state.speedIdx=0; state.running=false; UI.refresh(); State.save(); },

  _interact(){ if (this.nearest.type==='cab') UI.openCab(); else UI.openCar(this.nearest.idx); },

  /* ---------------- 렌더 ---------------- */
  render(ctx, w, h) {
    const railY = Art.trainBg(ctx, w, h, state.distanceKm, state.dayT);
    Art.rails(ctx, w, railY, this.scroll);

    ctx.save(); ctx.translate(-(this.cam.x - w/2), 0);
    const lay=this.layout(); const carTop=railY-this.CAR_H;
    const dmg=1 - state.res.durability/CONFIG.max.durability;

    // 연결기
    ctx.fillStyle='#1a1714';
    const segs=[...lay.cars.map(c=>({x:c.x,w:c.w})),{x:lay.cab.x,w:lay.cab.w}].sort((a,b)=>a.x-b.x);
    for (let i=0;i<segs.length-1;i++){ const a=segs[i],b=segs[i+1]; ctx.fillRect(a.x+a.w, carTop+this.CAR_H*0.55, b.x-(a.x+a.w), 8); }

    // 객차
    const fw=state.innerFarm; const workerCarId = fw.active ? (state.cars.find(c=>c.companionId===fw.workerId)||{}).id : null;
    lay.cars.forEach((c)=>{ const occ=c.car.companionId?State.crewById(c.car.companionId):null;
      const isFarm = fw.active && c.car.id===workerCarId;
      Art.car(ctx, c.x, carTop, c.w, this.CAR_H, { occupied:!!occ, farm:isFarm, ripe:fw.ripe, dmg });
      if (occ) Art.personSide(ctx, c.x+c.w*0.35, carTop+this.CAR_H-22, '#cfa', this.player.t+c.x);
    });
    Art.cab(ctx, lay.cab.x, carTop, lay.cab.w, this.CAR_H, dmg);
    Art.personSide(ctx, this.player.x, carTop+this.CAR_H-20, '#ffd34d', this.player.t);

    if (this.nearest){ const nx=this.nearest.x, ny=carTop-16; ctx.font='bold 13px sans-serif'; ctx.textAlign='center';
      const tw=ctx.measureText(this.nearest.label).width+20; ctx.fillStyle='rgba(0,0,0,0.6)';
      ctx.beginPath(); ctx.roundRect(nx-tw/2, ny-18, tw, 24, 6); ctx.fill();
      ctx.fillStyle='#fff'; ctx.fillText(this.nearest.label, nx, ny-1); }
    ctx.restore();

    const sky=Art.skyColors(state.dayT);
    if (sky.dark>0){ ctx.fillStyle=`rgba(8,10,24,${sky.dark*0.45})`; ctx.fillRect(0,0,w,h); }
    { const wk=State.weatherKind(); if (wk==='rain') Art.rain(ctx, w, h, state.weather.intensity, this.player.t); else if (wk==='heat') Art.heat(ctx, w, h, state.weather.intensity); }

    ctx.fillStyle='rgba(255,255,255,0.45)'; ctx.font='12px sans-serif'; ctx.textAlign='center';
    ctx.fillText(state.running ? '주행 중 — ◀▶ 이동, 가까운 칸에서 [A]' : '정차 중 — 운행실에서 출발/탐험', w/2, h-10);
  },
};
