/* =========================================================================
 * explore.js — 탐험 모드(2.5D 탑뷰). 은신/감염/확률 파밍/외부 농사
 * ========================================================================= */
const Explore = {
  enter(biomeKey) {
    state.mode='explore'; state.explore=this._generate(biomeKey); UI.setExploreUI(true);
    const b=DATA.biomes[biomeKey];
    UI.toast(`🧭 ${b.icon} ${b.name} 정차 — 천천히 이동하며 은신처를 활용하세요`);
  },

  _generate(biomeKey) {
    const biome=DATA.biomes[biomeKey];
    // 게임 시드를 섞어 새 게임마다 마을 배치가 달라지게(같은 게임 내 같은 지점은 일관)
    const rng=new RNG((Math.floor(state.distanceKm*7+state.day*131+17)+(state.seed||0))>>>0);
    const big = biomeKey==='city';
    const W = big?3400:2800, H = big?2200:1800;   // 탐험 맵 확대(미니맵으로 길찾기)
    const sc={ biomeKey, biome, w:W, h:H,
      player:{ x:120, y:H/2, dir:{x:1,y:0}, hurtT:0, hitFlash:0, atkCd:0, swingT:0, searchTarget:null, searchT:0,
        doorTarget:null, doorT:0, breaking:false, alarmTarget:null, alarmT:0, hidden:false, stamina:CONFIG.explore.staminaMax },
      buildings:[], cars:[], zombies:[], hides:[], farmSpots:[], survivor:null,
      trainEdge:{ x:0, y:H/2-80, w:60, h:160 },
      threat:0, elapsed:0, durLost:0, cam:{x:0,y:0}, msg:'', msgT:0, _nextWave:CONFIG.explore.waveIntervalSec,
      noiseR:0, noiseX:0, noiseY:0,
      seenTypes:new Set(['normal']), attackers:0, attackPower:0 };

    // 건물(넓게 분산 → 이동이 멀고 어렵게). 빈 격자칸을 더 채워 건물을 늘림(생성 확률↑)
    const cols=3, mx=380, my=240, cellW=(W-mx-120)/cols, rowH=380;
    const capRows=Math.max(1, Math.floor((H-170-my)/rowH)), cap=cols*capRows;
    const pool=biome.buildings.slice();
    const target=Math.min(cap, Math.round(pool.length*1.7)+(big?3:2));
    const keys=pool.slice(); while (keys.length<target) keys.push(rng.pick(pool));   // 풀에서 추가로 채움
    for (let i=keys.length-1;i>0;i--){ const j=rng.int(0,i); const tmp=keys[i]; keys[i]=keys[j]; keys[j]=tmp; }
    keys.forEach((key,idx)=>{ const def=DATA.buildings[key]; const col=idx%cols, row=Math.floor(idx/cols);
      const bw=rng.int(176,236), bh=rng.int(140,186);
      const bx=mx+col*cellW+rng.range(10,Math.max(14,cellW-bw-10));
      const by=my+row*rowH+rng.range(0,80); if (by+bh>H-170) return;
      const b={ def, x:bx, y:by, w:bw, h:bh };
      this._buildRoom(b, rng);   // 벽(출입문·잠금 포함)·내부 가구 생성
      sc.buildings.push(b); });

    const nCars=Math.round(biome.cars*1.4);
    for (let i=0;i<nCars;i++) sc.cars.push({ x:rng.range(mx,W-160), y:rng.range(160,H-160), searchesLeft:DATA.car.searches });

    // 은신처(맵이 커진 만큼 더 배치)
    const nHide=rng.int(6,10);
    for (let i=0;i<nHide;i++){ const t=rng.pick(DATA.hideTypes); sc.hides.push({ x:rng.range(160,W-120), y:rng.range(120,H-120), name:t.name, icon:t.icon, r:46 }); }

    // 외부 농사 자리(평야/강 등)
    if (biome.canFarm) for (let i=0;i<rng.int(2,4);i++) sc.farmSpots.push({ x:rng.range(W*0.4,W-200), y:rng.range(200,H-200), planted:false, fenced:false, farmId:null });

    const nZ=Math.round(biome.zombies*1.4);   // 맵 확대에 맞춰 좀비도 약간 증가(밀도 유지)
    for (let i=0;i<nZ;i++){ let x,y,tr=0; do{ x=rng.range(W*0.3,W-60); y=rng.range(60,H-60); tr++; } while (U.dist(x,y,sc.player.x,sc.player.y)<420 && tr<20); sc.zombies.push(this._mkZombie(x,y,rng)); }

    // 생존자(동료)는 마을 입장 때마다 즉석에서 랜덤 — 있을 수도/없을 수도, 누구인지도 매번 다름
    if (Math.random()<biome.survivor && State.freeCars()>0){ const b=sc.buildings.length?U.pick(sc.buildings):null;
      sc.survivor={ x:b?b.door.x:W*0.6, y:b?b.door.y+40:H*0.5, trait:U.pick(DATA.traitOrder), name:U.pick(DATA.names) }; }

    // 동행 동료 — 플레이어 근처에서 출발해 따라다니며 좀비를 함께 상대
    sc.followers=[];
    State.followers().forEach((m,i)=>{ const a=i*2.4;
      sc.followers.push({ crewId:m.id, x:sc.player.x-34+Math.cos(a)*14, y:sc.player.y+Math.sin(a)*22,
        dir:{x:1,y:0}, hurtT:0, hitFlash:0, atkCd:0, swingT:0 }); });
    return sc;
  },
  // 경과 시간에 따른 타입 출현 가중치(오래 정차할수록 강한 좀비)
  _zombieWeights(elapsed){ const t=elapsed||0; const w={ normal:6 };
    if (t>30) w.runner=Math.min(5,(t-30)/10);
    if (t>55) w.tank=Math.min(4,(t-55)/12);
    if (t>80){ w.brute=Math.min(4,(t-80)/12); w.normal=3; }
    return w; },
  _mkZombie(x,y,rng,elapsed){ const key=this._pickWeighted(this._zombieWeights(elapsed||0), rng);
    const t=DATA.zombieTypes[key]; const hp=rng.int(t.hp[0],t.hp[1]);
    return { x,y, typeKey:key, hp, maxHp:hp, speedMul:t.speedMul, dmgMul:t.dmgMul, r:t.r, color:t.color,
      phase:rng.range(0,6.28), wx:0,wy:0,wt:0, alerted:false, attacking:false, lastX:null, lastY:null, loseT:0 }; },

  // 건물을 '진입형 방'으로 구성: 벽(출입문 틈) + 내부 가구 컨테이너(좀보이드식)
  _buildRoom(b, rng){
    const wt=CONFIG.explore.wallThick, dg=CONFIG.explore.doorGap;
    const x=b.x, y=b.y, w=b.w, h=b.h;
    const doorX = x + w*0.5 - dg/2;
    b.door = { x:x+w*0.5, y:y+h+14 };        // 진입 안내 지점(문 앞)
    b.doorGap = { x0:doorX, x1:doorX+dg };
    b.doorWall = { x:doorX, y:y+h-wt, w:dg, h:wt };   // 문이 닫혀 있을 때 출입문을 막는 벽
    b.locked = rng.chance(CONFIG.explore.lockChance); // 높은 확률로 잠김(부수거나 따야 진입)
    b.open = false; b.break = 0;                       // 문 열림 여부 / 좀비 파손 진행도
    b.walls = [
      { x:x,        y:y,      w:w,                 h:wt },   // 뒷벽
      { x:x,        y:y,      w:wt,                h:h  },   // 좌벽
      { x:x+w-wt,   y:y,      w:wt,                h:h  },   // 우벽
      { x:x,        y:y+h-wt, w:doorX-x,           h:wt },   // 앞벽(문 좌)
      { x:doorX+dg, y:y+h-wt, w:(x+w)-(doorX+dg),  h:wt },   // 앞벽(문 우)
    ];
    // 내부 가구 배치(문 앞 통로는 비움)
    const pool = b.def.furniture || ['cabinet','desk'];
    b.furniture = [];
    const ix0=x+wt+18, ix1=x+w-wt-18, iy0=y+wt+16, iy1=y+h-wt-34;
    pool.forEach((fk)=>{ const fdef=DATA.furniture[fk]; if (!fdef) return;
      let fx,fy,tries=0;
      do { fx=rng.range(ix0,ix1); fy=rng.range(iy0,iy1); tries++; }
      while (tries<16 && b.furniture.some(o=>U.dist(fx,fy,o.x,o.y)<34));
      const weights={};
      for (const k in b.def.weights) weights[k]=(weights[k]||0)+b.def.weights[k];
      for (const k in fdef.weights)  weights[k]=(weights[k]||0)+fdef.weights[k]*2;   // 가구 색깔을 더 강하게
      b.furniture.push({ def:fdef, x:fx, y:fy, searchesLeft:fdef.searches||1, weights,
        mul:(b.def.mul||1)*(fdef.mul||1), success:fdef.success!=null?fdef.success:b.def.success }); });
  },

  /* ---------------- 업데이트 ---------------- */
  update(dt) {
    const sc=state.explore; if (!sc) return; const C=CONFIG.explore; const p=sc.player;
    sc.elapsed+=dt; sc.msgT=Math.max(0,sc.msgT-dt);
    if (sc.aim) sc.aim.t=Math.max(0,sc.aim.t-dt);
    p.hurtT=Math.max(0,p.hurtT-dt); p.hitFlash=Math.max(0,p.hitFlash-dt); p.atkCd=Math.max(0,p.atkCd-dt); p.swingT=Math.max(0,p.swingT-dt);

    // 은신/실내/비노출 판정(체온·날씨용) — updateCrew 전에 갱신
    p.hidden = sc.hides.some(hsp=>U.dist(p.x,p.y,hsp.x,hsp.y)<hsp.r);
    const wt=CONFIG.explore.wallThick; p.inside=null;
    for (const b of sc.buildings){ if (p.x>b.x+wt && p.x<b.x+b.w-wt && p.y>b.y+wt && p.y<b.y+b.h-wt){ p.inside=b; break; } }
    const e0=sc.trainEdge; const nearTrain=(p.x<e0.x+e0.w+44 && p.y>e0.y-44 && p.y<e0.y+e0.h+44);
    state._exposed = !(p.inside || p.hidden || nearTrain);

    const dark=Art.skyColors(state.dayT).dark;
    state.dayT += dt/CONFIG.time.dayLengthSec*0.5; while(state.dayT>=1){ state.dayT-=1; state.day++; state.stats.daysSurvived=state.day; }
    State.updateCrew(dt, dark>0.45);
    if (state.over) return;

    let mvx=Input.x, mvy=Input.y; const moving=(mvx||mvy);
    if (moving){ const m=Math.hypot(mvx,mvy)||1; p.dir.x=mvx/m; p.dir.y=mvy/m; if (Math.abs(p.dir.x)>0.05) p.faceX=p.dir.x>0?1:-1; }

    // 스태미나: Shift로 달리기(이동 중일 때만 소모), 그 외엔 느리게 회복
    if (p.stamina==null) p.stamina=C.staminaMax;
    if (p.stamina<=0) p.exhausted=true;                       // 다 닳으면 지침 상태
    else if (p.stamina>=C.sprintRecoverAt) p.exhausted=false; // 충분히 회복돼야 해제
    const busy = p.searchTarget || p.doorTarget || p.alarmTarget;
    const sprinting = Input.sprint && moving && !busy && !p.exhausted && p.stamina>0;
    if (sprinting) p.stamina=Math.max(0, p.stamina - C.sprintDrainPerSec*dt);
    else p.stamina=Math.min(C.staminaMax, p.stamina + C.staminaRegen*dt);
    p.moving = !!moving && !busy; p.running = sprinting;   // 걷기/뛰기 애니메이션용

    if (p.searchTarget){ const t=p.searchTarget; const tx=t.door?t.door.x:t.x, ty=t.door?t.door.y:t.y;
      if (moving && U.dist(p.x,p.y,tx,ty)>64) this._cancelSearch();
      else { p.searchT+=dt; if (p.searchT>=C.searchSec) this._finishSearch(); } }
    // 잠긴 문 부수기/따기(가만히 있어야 진행, 부수는 동안 큰 소리)
    if (p.doorTarget){ const b=p.doorTarget, dcx=b.x+b.w/2, dcy=b.y+b.h;
      if (moving && U.dist(p.x,p.y,dcx,dcy)>56) this._cancelDoor();
      else { p.doorT+=dt; p.breaking=!p.doorPick;
        if (p.doorT >= (p.doorNeed||C.doorBreakSec)) this._finishDoor(); } }
    else p.breaking=false;
    // 자동차 알람 설치(기계전문가) — 가만히 있어야 진행
    if (p.alarmTarget){ const c=p.alarmTarget;
      if (moving && U.dist(p.x,p.y,c.x,c.y)>56) this._cancelAlarm();
      else { p.alarmT+=dt; if (p.alarmT>=C.alarmInstallSec) this._finishAlarm(); } }
    if (!busy){ let sp=C.playerSpeed*((State.player()||{}).trait==='swift'?1.28:1); if (sprinting) sp*=C.sprintMul;
      p.x=U.clamp(p.x+mvx*sp*dt,14,sc.w-14); this._collide(p,'x');
      p.y=U.clamp(p.y+mvy*sp*dt,14,sc.h-14); this._collide(p,'y'); }

    // 소리: 달리기/공격/문 부수기는 좀비를 끌어들임(벽을 통과해 들림). 걷기는 작게.
    let noiseR=0; const noiseX=p.x, noiseY=p.y;
    if (p.breaking) noiseR=C.noiseBreak;
    else if (sprinting) noiseR=C.noiseRun;
    else if (p.moving) noiseR=C.noiseWalk;
    if (p.swingT>0.12) noiseR=Math.max(noiseR, C.noiseAttack);
    sc.noiseR=noiseR; sc.noiseX=noiseX; sc.noiseY=noiseY;

    // 좀비 AI: 평소엔 기차로 천천히 몰려듦 → 붙으면 공격 / 플레이어 감지 시 추격(유인 가능)
    const detect = p.hidden ? C.hiddenDetectRange : C.detectRange;
    const tc = { x: sc.trainEdge.x + sc.trainEdge.w/2, y: sc.trainEdge.y + sc.trainEdge.h/2 };
    const siege = sc.elapsed >= C.trainSiegeDelaySec;   // 유예 시간 후부터 기차로 몰려듦
    if (siege && !sc._siegeAnnounced){ sc._siegeAnnounced=true; UI.toast('🧟 좀비들이 기차로 몰려들기 시작합니다! 슬슬 떠날 준비를'); }
    // 자동차 알람: 작동 시간 경과 처리 → 울리는 차 목록
    let ringing=null;
    for (const c of sc.cars){ if (c.alarm==='ringing'){ c.alarmT-=dt; if (c.alarmT<=0){ c.alarm='installed'; } else { (ringing||(ringing=[])).push(c); } } }
    let attackers = 0, attackPower = 0;
    for (const z of sc.zombies){ z.wt-=dt; if (z.hitFlash) z.hitFlash=Math.max(0,z.hitFlash-dt); if (z.wt<=0){ z.wt=0.8+Math.random()*1.4; const a=Math.random()*6.28; z.wx=Math.cos(a); z.wy=Math.sin(a); }
      const d=Math.max(0.001,U.dist(z.x,z.y,p.x,p.y));
      // 시야: 거리 안 + 사이에 벽(건물)이 없을 때만 인지 (벽 뒤에 있으면 못 봄)
      const see = d<detect && this._canSee(z.x,z.y,p.x,p.y);
      if (!z.alerted){ if (see){ z.alerted=true; z.lastX=p.x; z.lastY=p.y; z.loseT=0; z.investigate=null; } }
      else { if (see){ z.lastX=p.x; z.lastY=p.y; z.loseT=0; } else z.loseT=(z.loseT||0)+dt;
        if (d>C.zombieLoseRange || z.loseT>C.zombieGiveUpSec) z.alerted=false; }
      // 청각: 시야 밖이라도 소리(달리기·공격·문 부수기)가 닿으면 그 지점으로 조사하러 옴(벽 무시)
      if (!z.alerted){
        if (noiseR>0 && d<noiseR){ z.investigate={x:noiseX,y:noiseY}; z.invT=C.investigateSec; }
        else if (z.invT>0){ z.invT-=dt; if (z.invT<=0) z.investigate=null; } }
      // 자동차 알람(작동 중): 매우 넓은 반경의 좀비를 차로 유인 — 추격/기차공격도 전환
      z.lured=false;
      if (ringing){ for (const c of ringing){ if (U.dist(z.x,z.y,c.x,c.y)<C.alarmRadius){ z.lured=true; z.alerted=false; z.loseT=0; z.investigate={x:c.x,y:c.y}; z.invT=Math.max(z.invT||0,1.2); break; } } }
      const dTrain = Math.max(0.001, U.dist(z.x,z.y,tc.x,tc.y));
      // 공격 상태 래치(히스테리시스). 유예 시간 전(=!siege)·추격·알람 유인 중엔 기차 공격 안 함
      if (z.alerted || !siege || z.lured) z.attacking=false;
      else if (!z.attacking && !z.lured && dTrain < C.trainAttackRange) z.attacking=true;
      else if (z.attacking && dTrain > C.trainAttackRange*1.5) z.attacking=false;
      z.atTrain = z.attacking;
      const ox=z.x, oy=z.y;   // 이동량/바라보는 방향(애니메이션용)
      if (z.alerted){ // 보이면 플레이어, 시야를 잃으면 마지막 목격 지점으로 갔다가 포기
        const tx=see?p.x:(z.lastX!=null?z.lastX:p.x), ty=see?p.y:(z.lastY!=null?z.lastY:p.y);
        const dd=Math.max(0.001,U.dist(z.x,z.y,tx,ty)), dx=(tx-z.x)/dd, dy=(ty-z.y)/dd;
        z.x=U.clamp(z.x+dx*C.zombieSpeed*z.speedMul*dt,8,sc.w-8); this._collide(z,'x',11);
        z.y=U.clamp(z.y+dy*C.zombieSpeed*z.speedMul*dt,8,sc.h-8); this._collide(z,'y',11);
        if (!see && dd<14) z.loseT=Math.max(z.loseT||0, C.zombieGiveUpSec);
      } else if (z.attacking){ // 기차에 자리잡고 공격 — 제자리(밖으로 떠나지 않음), 시각 흔들림은 렌더에서
        attackers++; attackPower+=z.dmgMul;
      } else if (z.investigate){ // 소리 조사: 들린 지점으로 이동 → 도착하면 그 자리에서 두리번거리며 수색(invT 소진까지)
        const tx=z.investigate.x, ty=z.investigate.y, dd=Math.max(0.001,U.dist(z.x,z.y,tx,ty));
        if (dd>=18){ const dx=(tx-z.x)/dd, dy=(ty-z.y)/dd, sp=C.zombieSpeed*z.speedMul*C.investigateSpeedMul;
          z.x=U.clamp(z.x+dx*sp*dt,8,sc.w-8); this._collide(z,'x',11);
          z.y=U.clamp(z.y+dy*sp*dt,8,sc.h-8); this._collide(z,'y',11); }
        // 도착(dd<18)하면 제자리에서 수색 — 위 청각 블록에서 invT가 0이 되면 해제(바로 포기하지 않음)
      } else if (siege){ // 유예 후: 기차로 서서히 이동
        const dx=(tc.x-z.x)/dTrain, dy=(tc.y-z.y)/dTrain;
        z.x=U.clamp(z.x+dx*C.zombieSpeed*z.speedMul*C.trainDriftMul*dt,8,sc.w-8); this._collide(z,'x',11);
        z.y=U.clamp(z.y+dy*C.zombieSpeed*z.speedMul*C.trainDriftMul*dt,8,sc.h-8); this._collide(z,'y',11);
      } else { // 유예 중: 그냥 배회(기차로 몰리지 않음)
        z.x=U.clamp(z.x+z.wx*C.zombieSpeed*z.speedMul*0.4*dt,8,sc.w-8); this._collide(z,'x',11);
        z.y=U.clamp(z.y+z.wy*C.zombieSpeed*z.speedMul*0.4*dt,8,sc.h-8); this._collide(z,'y',11);
      }
      { const ddx=z.x-ox, ddy=z.y-oy, mv=ddx*ddx+ddy*ddy; z.moving=mv>0.02; if (mv>0.0001){ z.hx=ddx; z.hy=ddy; } }
      if (d<24 && p.hurtT<=0 && this._canSee(p.x,p.y,z.x,z.y)){ p.hurtT=C.contactCooldown; p.hitFlash=0.25; const pl=State.player();  // 벽 너머로는 물지 못함
        const dm=pl.trait==='tough'?0.55:1;
        pl.hp=U.clamp(pl.hp-C.contactDamage*z.dmgMul*dm,0,CONFIG.personMax); pl.mental=U.clamp(pl.mental-3,0,CONFIG.personMax); pl.hurtFlash=CONFIG.explore.hurtFlashSec;
        if (!pl.infected && Math.random()<CONFIG.infection.hitChance){ pl.infected=true; UI.toast('🦠 감염되었습니다! 약(💊)으로 치료하세요'); }
        this._cancelSearch(); if (pl.hp<=0 && !state.over){ Game.gameOver('eaten'); return; } } }
    sc.attackers = attackers; sc.attackPower = attackPower;
    // 표시 스무딩(짧은 공백에도 점멸하지 않도록)
    if (attackers>0){ sc.attackHoldT=0.5; sc.attackersShown=attackers; sc.attackPowerShown=attackPower; } else sc.attackHoldT=Math.max(0,(sc.attackHoldT||0)-dt);

    // 닫힌 문 부수기: 플레이어가 안에 있고 경계한 좀비가 문에 붙으면 점차 파손 → 열림
    for (const b of sc.buildings){
      if (b.open){ b.break=0; continue; }
      if (p.inside!==b){ b.break=Math.max(0,(b.break||0)-dt*0.3); continue; }
      const dcx=b.x+b.w/2, dcy=b.y+b.h; let near=0;
      for (const z of sc.zombies){ if (z.alerted && U.dist(z.x,z.y,dcx,dcy)<40) near++; }
      if (near>0){ b.break=(b.break||0)+C.zombieDoorBreakPerSec*near*dt;
        if (b.break>=1){ b.open=true; b.locked=false; b.break=0; UI.toast('🧟 좀비가 문을 부수고 들어옵니다!'); } }
      else b.break=Math.max(0,(b.break||0)-dt*0.2);
    }

    this._updateFollowers(dt);

    // 좀비 웨이브 — 집결(siege) 시작 후 시간이 지날수록 스폰 수 계수가 1 → 최대 siegeSpawnMax(3)로 점진 증가
    if (sc.elapsed>sc._nextWave){ sc._nextWave+=C.waveIntervalSec;
      const siegeT=Math.max(0, sc.elapsed - C.trainSiegeDelaySec);
      const spawnMul=U.clamp(1 + siegeT/C.siegeSpawnRampSec*(C.siegeSpawnMax-1), 1, C.siegeSpawnMax);
      const n=Math.max(1, Math.round((1+sc.biome.danger+sc.threat*1.5)*spawnMul));
      let newType=null;
      for (let i=0;i<n;i++){ const e=Math.random(); const x=e<0.5?sc.w-20:Math.random()*sc.w, y=e<0.5?Math.random()*sc.h:sc.h-20;
        const z=this._mkZombie(x,y,new RNG((sc.elapsed*97+i)|0), sc.elapsed); sc.zombies.push(z);
        if (!sc.seenTypes.has(z.typeKey)){ sc.seenTypes.add(z.typeKey); if (z.typeKey!=='normal') newType=DATA.zombieTypes[z.typeKey]; } }
      if (newType) UI.toast(`⚠️ ${newType.name} 출현! 오래 정차할수록 더 강한 좀비가 몰려옵니다`);
      else UI.toast('🧟 좀비 무리가 몰려옵니다!'); }

    // 기차에 붙은 좀비 수만큼만 내구도 감소(처치/유인하면 멈춤)
    sc.threat+=CONFIG.stop.threatGrowthPerSec*dt;   // 웨이브 규모용
    if (attackers>0){ const before=state.res.durability; const dmul=State.effects().trainDefenseMul;
      state.res.durability=U.clamp(state.res.durability - attackPower*CONFIG.stop.durPerZombiePerSec*dmul*dt, 0, CONFIG.max.durability);
      sc.durLost+=before-state.res.durability;
      if (state.res.durability<=0){ const pl=State.player(); pl.hp=U.clamp(pl.hp-CONFIG.stop.durBreakHpPerSec*dt,0,CONFIG.personMax);
        if (pl.hp<=0 && !state.over){ Game.gameOver('overrun'); return; } } }

    // 카메라(2.5D)
    const halfH=(Game.view.h/2)/C.yScale;
    sc.cam.x=U.clamp(p.x, Game.view.w/2, Math.max(Game.view.w/2, sc.w-Game.view.w/2));
    sc.cam.y=U.clamp(p.y, halfH, Math.max(halfH, sc.h-halfH));

    if (Input.interactEdge){ Input.interactEdge=false; this._interact(); }   // E: 약탈·구출·농사·복귀
    if (Input.attackEdge){ Input.attackEdge=false; this._attack(); }          // Space: 공격
  },

  _resolveSeg(ent,axis,r,s){ if (ent.x+r>s.x && ent.x-r<s.x+s.w && ent.y+r>s.y && ent.y-r<s.y+s.h){
    if (axis==='x') ent.x=(ent.x<s.x+s.w/2)?s.x-r:s.x+s.w+r; else ent.y=(ent.y<s.y+s.h/2)?s.y-r:s.y+s.h+r; } },
  // 건물 벽 세그먼트와 충돌(열린 문틈으로 통과). 닫힌/잠긴 문은 막힘
  _collide(ent,axis,rad){ const r=rad||13, sc=state.explore;
    for (const b of sc.buildings){ const ws=b.walls; if (!ws) continue;
      for (const s of ws) this._resolveSeg(ent,axis,r,s);
      if (!b.open && b.doorWall) this._resolveSeg(ent,axis,r,b.doorWall); } },

  // 선분이 사각형(건물)을 가로지르는가 — Liang–Barsky 클리핑
  _segRect(x0,y0,x1,y1,rx,ry,rw,rh){ let t0=0,t1=1; const dx=x1-x0, dy=y1-y0;
    const p=[-dx,dx,-dy,dy], q=[x0-rx, rx+rw-x0, y0-ry, ry+rh-y0];
    for (let i=0;i<4;i++){ if (p[i]===0){ if (q[i]<0) return false; }
      else { const r=q[i]/p[i]; if (p[i]<0){ if (r>t1) return false; if (r>t0) t0=r; } else { if (r<t0) return false; if (r<t1) t1=r; } } }
    return true; },
  // 두 점 사이에 건물 벽이 가로막으면 false. 단 둘 다 같은 건물 안이면 그 건물은 막지 않음(같은 방 → 서로 보임/공격 가능)
  _canSee(ax,ay,bx,by){ const bs=state.explore.buildings; for (let i=0;i<bs.length;i++){ const b=bs[i];
    if (!this._segRect(ax,ay,bx,by,b.x,b.y,b.w,b.h)) continue;
    const aIn = ax>b.x && ax<b.x+b.w && ay>b.y && ay<b.y+b.h;
    const bIn = bx>b.x && bx<b.x+b.w && by>b.y && by<b.y+b.h;
    if (aIn && bIn) continue;   // 같은 건물 내부 → 이 건물은 시야를 막지 않음
    return false; }
    return true; },

  _interact(){ const sc=state.explore, p=sc.player;
    if (p.searchTarget){ this._cancelSearch(); return; }
    if (p.doorTarget){ this._cancelDoor(); return; }
    if (p.alarmTarget){ this._cancelAlarm(); return; }
    const e=sc.trainEdge; if (p.x<e.x+e.w+30 && p.y>e.y-30 && p.y<e.y+e.h+30){ this._trainStash(); return; }
    if (sc.survivor && U.dist(p.x,p.y,sc.survivor.x,sc.survivor.y)<40){
      if (State.freeCars()<=0){ UI.toast('🚪 빈 객차가 없습니다 — 칸을 증설하세요'); return; }
      Actions.recruit(sc.survivor.trait, sc.survivor.name); sc.survivor=null; return; }
    // 외부 농사 자리
    for (const fs of sc.farmSpots){ if (U.dist(p.x,p.y,fs.x,fs.y)<44){ this._farmSpot(fs); return; } }
    // 잠긴 건물 문: 부수기(소리↑) 또는 자물쇠 따기(제작전문가·열쇠공, 빠름·조용)
    for (const b of sc.buildings){ if (!b.locked) continue;
      if (U.dist(p.x,p.y,b.x+b.w/2,b.y+b.h)<38){ const C=CONFIG.explore;
        p.doorTarget=b; p.doorT=0; p.doorPick=State.canPickLocks(); const ls=State.hasActiveTrait('locksmith');
        p.doorNeed = p.doorPick ? (ls?C.doorPickFastSec:C.doorPickSec) : C.doorBreakSec;
        UI.toast(p.doorPick?`🔓 ${b.def.name} 문을 ${ls?'능숙하게 ':''}따는 중… (조용히)`:`🔨 ${b.def.name} 문을 부수는 중… (소리에 주의!)`);
        return; } }
    // 건물 내부 가구 약탈(가까운 가구 우선, 벽 너머는 불가) — 캐비넷/냉장고 등을 뒤져 인벤토리 열기
    let bestF=null, bestD=46;
    for (const b of sc.buildings){ if (b.locked) continue;
      for (const f of (b.furniture||[])){ if (this._looted(f)) continue;
        const d=U.dist(p.x,p.y,f.x,f.y); if (d<bestD && this._canSee(p.x,p.y,f.x,f.y)){ bestD=d; bestF=f; } } }
    if (bestF){ this._openContainer(bestF); return; }
    // 자동차: 약탈 → (기계전문가) 알람 설치 → 작동(유인)
    for (const c of sc.cars){ if (U.dist(p.x,p.y,c.x,c.y)>=40) continue;
      if (c.alarm==='ringing'){ UI.toast('🔔 알람이 이미 울리는 중입니다'); return; }
      if (c.alarm==='installed'){ c.alarm='ringing'; c.alarmT=CONFIG.explore.alarmRingSec;
        UI.toast('🔔 자동차 알람 작동! 넓은 반경의 좀비가 몰려옵니다 — 지금 멀어지세요'); State.save(); return; }
      if (!this._looted(c)){ this._openContainer(c); return; }
      if (State.hasActiveTrait('mechanic')){
        if (state.res.parts < CONFIG.explore.alarmParts){ UI.toast(`🛠️ 알람 설치에 부품 ${CONFIG.explore.alarmParts} 필요`); return; }
        p.alarmTarget=c; p.alarmT=0; UI.toast('🛠️ 자동차에 알람 설치 중…'); return; }
      return; }   // 차에 닿았지만 할 게 없음
    // 열린/닫힌 문 토글(잠금 해제된 문을 닫아 좀비를 막거나 다시 열기)
    for (const b of sc.buildings){ if (b.locked) continue;
      if (U.dist(p.x,p.y,b.x+b.w/2,b.y+b.h)<32){ b.open=!b.open;
        UI.toast(b.open?`🚪 ${b.def.name} 문을 열었습니다`:`🚪 ${b.def.name} 문을 닫았습니다 — 좀비는 부수기 전엔 못 들어옵니다`); return; } }
    // 상호작용 대상이 없으면 아무것도 안 함(공격은 클릭/⚔️)
  },

  // 다 뒤졌고 남은 게 없는 컨테이너
  _looted(c){ return c.searched && (!c.items || !c.items.length) && (!c.weapons || !c.weapons.length); },
  // 컨테이너(가구/차)와 상호작용 — 처음엔 뒤지는 모션(1~2s) 후, 이후엔 바로 약탈 인벤토리 열기
  _openContainer(c){ const p=state.explore.player;
    if (!c.searched){ p.searchTarget=c; p.searchT=0; }   // 뒤지는 모션 시작 → _finishSearch에서 열림
    else UI.openLoot(c); },

  // 기차 적재 — 휴대 자원을 비축으로 옮기고 장착(가방/옷) 관리
  _trainStash(){ UI.openTrainStash(); },

  _cancelDoor(){ const p=state.explore.player; p.doorTarget=null; p.doorT=0; p.breaking=false; },
  _cancelAlarm(){ const p=state.explore.player; p.alarmTarget=null; p.alarmT=0; },
  _finishAlarm(){ const sc=state.explore, p=sc.player, c=p.alarmTarget; if (!c) return;
    p.alarmTarget=null; p.alarmT=0;
    if (state.res.parts < CONFIG.explore.alarmParts){ UI.toast('🛠️ 부품이 부족합니다'); return; }
    state.res.parts -= CONFIG.explore.alarmParts; c.alarm='installed';
    UI.toast('🛠️ 알람 설치 완료 — 자동차에서 [E]로 작동시키면 좀비를 유인합니다'); State.save(); },
  _finishDoor(){ const sc=state.explore, p=sc.player, b=p.doorTarget; if (!b) return;
    const picked=p.doorPick; b.locked=false; b.open=true; p.doorTarget=null; p.doorT=0; p.breaking=false;
    UI.toast(picked?`🔓 ${b.def.name} 문을 열었습니다 — 조용히 진입`:`🔨 ${b.def.name} 문을 부쉈습니다! 큰 소리가 퍼졌습니다`);
    State.save(); },

  _farmSpot(fs){
    const eff=State.effects();
    if (!fs.planted){
      if (!eff.canBuildOuter){ UI.toast('🌾 외부 농사는 농사/가구/제작 전문가가 필요합니다'); return; }
      if (state.res.scrap<CONFIG.farm.plantScrap){ UI.toast(`🌾 파종에 재료 ${CONFIG.farm.plantScrap} 필요`); return; }
      state.res.scrap-=CONFIG.farm.plantScrap;
      const fm={ id:newId(), biome:state.explore.biomeKey, plantedKm:state.distanceKm,
        dueKm:state.distanceKm+CONFIG.farm.outer.growKm, fenced:false, alive:true, ripe:false, harvested:false };
      state.farms.push(fm); fs.planted=true; fs.farmId=fm.id;
      UI.toast(`🌾 외부 농장 파종! ${CONFIG.farm.outer.growKm}km 후 수확 — 맵에서 📍확인 후 정차`); UI.refresh(); State.save();
    } else if (!fs.fenced){
      if (state.res.scrap<CONFIG.farm.fenceScrap || state.res.parts<CONFIG.farm.fenceParts){ UI.toast(`🪵 울타리에 재료 ${CONFIG.farm.fenceScrap}·부품 ${CONFIG.farm.fenceParts} 필요`); return; }
      state.res.scrap-=CONFIG.farm.fenceScrap; state.res.parts-=CONFIG.farm.fenceParts; fs.fenced=true;
      const fm=state.farms.find(f=>f.id===fs.farmId); if (fm) fm.fenced=true;
      UI.toast('🪵 울타리 설치 — 수확 시기를 놓쳐도 한 번 버팁니다'); UI.refresh(); State.save();
    } else UI.toast('🌾 이미 파종+울타리 완료된 자리입니다');
  },

  // 화면 좌표(clientX/Y) → 월드 좌표로 변환해 조준 지점 저장(클릭/마우스)
  setAim(clientX, clientY){ const sc=state.explore; if (!sc || !Game.canvas) return;
    const r=Game.canvas.getBoundingClientRect();
    const w=Game.view.w, h=Game.view.h, ys=CONFIG.explore.yScale;
    const wx=(clientX-r.left) + (sc.cam.x - w/2);
    const wy=((clientY-r.top) - h/2)/ys + sc.cam.y;
    sc.aim={ x:wx, y:wy, t:CONFIG.explore.aimDecaySec }; },

  // 클릭한 방향으로 부채꼴(사거리·반각) 공격. 조준이 없으면 바라보는 방향
  _attack(){ const sc=state.explore, p=sc.player, C=CONFIG.explore; if (p.atkCd>0) return; p.atkCd=C.attackCooldown;
    if (p.searchTarget) this._cancelSearch();   // 공격하면 약탈 중단
    if (p.doorTarget) this._cancelDoor();
    const st=State.attackStats(); const range=st.range, dmg=st.dmg, half=st.angle*Math.PI/180, kb=22+dmg*5;
    let dx,dy;
    if (Input.attackAimed && sc.aim && sc.aim.t>0){ dx=sc.aim.x-p.x; dy=sc.aim.y-p.y; }
    else if (p.dir && (p.dir.x||p.dir.y)){ dx=p.dir.x; dy=p.dir.y; }
    else { dx=p.faceX||1; dy=0; }
    Input.attackAimed=false;
    const dl=Math.hypot(dx,dy)||1; dx/=dl; dy/=dl; const dirAng=Math.atan2(dy,dx);
    p.swingT=0.2; p.swingRange=range; p.swingDir=dirAng; p.swingHalf=half; p.faceX=dx>=0?1:-1;
    let hit=false;
    for (const z of sc.zombies){ const zdx=z.x-p.x, zdy=z.y-p.y, d=Math.hypot(zdx,zdy);
      if (d>range) continue;
      if (!this._canSee(p.x,p.y,z.x,z.y)) continue;   // 벽을 끼고 있으면 공격이 안 통함
      if (d>10){ let da=Math.atan2(zdy,zdx)-dirAng; da=Math.atan2(Math.sin(da),Math.cos(da)); if (Math.abs(da)>half) continue; }  // 근접(10px 내)은 각도 무시
      z.hp-=dmg; const nx=zdx/(d||1), ny=zdy/(d||1); z.x+=nx*kb; z.y+=ny*kb;
      z.alerted=true; z.hitFlash=0.2; hit=true; }
    const before=sc.zombies.length; sc.zombies=sc.zombies.filter(z=>z.hp>0); state.stats.kills+=before-sc.zombies.length;
    // 무기 내구도 소모(적중 시) → 0이면 파손
    if (hit && st.weapon){ st.weapon.dur-=1;
      if (st.weapon.dur<=0){ const nm=DATA.weapons[st.weapon.key].name;
        state.weapons=state.weapons.filter(w=>w.id!==st.weapon.id); state.weaponId=null;
        UI.toast(`💥 ${nm}이(가) 부서졌습니다 — 맨손`); State.save(); } } },

  // 동행 동료: 플레이어를 따라다니다 근처 좀비를 자동 공격. 피격은 해당 동료의 실제 체력·감염에 반영
  _updateFollowers(dt){
    const sc=state.explore; if (!sc.followers||!sc.followers.length) return;
    const p=sc.player, C=CONFIG.explore;
    sc.followers=sc.followers.filter(f=>State.crewById(f.crewId));   // 사망/하차한 동료 제거
    let idx=0;
    for (const f of sc.followers){
      const m=State.crewById(f.crewId);
      f.hurtT=Math.max(0,f.hurtT-dt); f.hitFlash=Math.max(0,f.hitFlash-dt); f.atkCd=Math.max(0,f.atkCd-dt); f.swingT=Math.max(0,f.swingT-dt);
      // 대형: 플레이어 뒤쪽으로 살짝 벌려 따라붙음
      const ang=idx*2.4, hx=p.x-p.dir.x*46+Math.cos(ang)*22, hy=p.y-p.dir.y*46+Math.sin(ang)*22;
      // 가장 가까운 좀비 탐색
      let zt=null, zd=1e9; for (const z of sc.zombies){ const d=U.dist(f.x,f.y,z.x,z.y); if (d<zd){ zd=d; zt=z; } }
      const engage = zt && zd<C.followerEngageRange;
      const tx=engage?zt.x:hx, ty=engage?zt.y:hy;
      const dd=Math.max(0.001,U.dist(f.x,f.y,tx,ty));
      const stopDist = engage ? C.followerAttackRange*0.8 : 9;
      const fmoving = dd>stopDist;
      if (fmoving){ const dx=(tx-f.x)/dd, dy=(ty-f.y)/dd; f.dir.x=dx; f.dir.y=dy;
        const sp=C.playerSpeed*C.followerSpeedMul;
        f.x=U.clamp(f.x+dx*sp*dt,14,sc.w-14); this._collide(f,'x');
        f.y=U.clamp(f.y+dy*sp*dt,14,sc.h-14); this._collide(f,'y'); }
      f.moving=fmoving; f.run=fmoving&&engage; if (Math.abs(f.dir.x)>0.05) f.faceX=f.dir.x>0?1:-1;   // 애니메이션 상태
      // 공격(쿨다운마다 가장 가까운 좀비 1마리)
      if (engage && zd<C.followerAttackRange && f.atkCd<=0){ f.atkCd=C.followerAttackCd; f.swingT=0.18;
        const dmg=m.trait==='brawler'?2:1; zt.hp-=dmg; zt.hitFlash=0.2; zt.alerted=true;
        const nx=(zt.x-f.x)/(zd||1), ny=(zt.y-f.y)/(zd||1); zt.x+=nx*16; zt.y+=ny*16; }
      // 피격 → 동료의 실제 체력/멘탈/감염에 반영(사망 처리는 State.updateCrew가 담당)
      if (zt && zd<22 && f.hurtT<=0){ f.hurtT=C.contactCooldown; f.hitFlash=0.25;
        const dm=m.trait==='tough'?0.55:1;
        m.hp=U.clamp(m.hp-C.contactDamage*zt.dmgMul*dm,0,CONFIG.personMax);
        m.mental=U.clamp(m.mental-3,0,CONFIG.personMax); m.hurtFlash=C.hurtFlashSec;
        if (!m.infected && Math.random()<CONFIG.infection.hitChance){ m.infected=true; UI.toast(`🦠 ${m.name}이(가) 감염되었습니다! 복귀 후 💊치료를`); } }
      idx++;
    }
    const before=sc.zombies.length; sc.zombies=sc.zombies.filter(z=>z.hp>0); state.stats.kills+=before-sc.zombies.length;
  },

  _cancelSearch(){ const p=state.explore.player; p.searchTarget=null; p.searchT=0; },

  _pickWeighted(weights, rng){ let total=0; for (const k in weights) total+=weights[k]; let r=rng.next()*total;
    for (const k in weights){ r-=weights[k]; if (r<=0) return k; } return Object.keys(weights)[0]; },

  // 뒤지는 모션 완료 → 컨테이너 내용물 생성 후 약탈 인벤토리 열기
  _finishSearch(){ const sc=state.explore, p=sc.player, t=p.searchTarget;
    p.searchTarget=null; p.searchT=0; state.stats.looted++;
    if (!t.searched){ t.items=this._genContainerItems(t); t.weapons=this._genContainerWeapons(t); t.searched=true; }
    UI.openLoot(t); State.save();
  },
  // 컨테이너 무기 드롭 — 낮은 확률로 1정, 내구도는 최대치의 20~60% 랜덤
  _genContainerWeapons(t){ const sc=state.explore, L=CONFIG.loot;
    const rng=new RNG((sc.elapsed*191+t.x*5+t.y*9+101)|0);
    const out=[];
    if (rng.chance(L.weaponChance)){ const keys=Object.keys(DATA.weapons); const k=rng.pick(keys); const d=DATA.weapons[k];
      const durMax=d.dur, dur=Math.max(1, Math.round(durMax*rng.range(L.weaponDurMin, L.weaponDurMax)));
      out.push({ key:k, dur, durMax }); }
    return out;
  },
  // 컨테이너 내용물(아이템 목록) 생성 — 성공 확률·가중치 + 가구별 가방/옷 드롭
  _genContainerItems(t){ const sc=state.explore, def=t.def||DATA.car, eff=State.effects();
    const success=(t.success!=null)?t.success:def.success;
    const weights=t.weights||def.weights;
    const rng=new RNG((sc.elapsed*53+t.x*3+t.y*7)|0);
    const avgMental=state.crew.reduce((a,m)=>a+m.mental,0)/state.crew.length;
    const mentalPen=avgMental<CONFIG.mental.lowThreshold?CONFIG.loot.mentalPenalty:0;
    const chance=U.clamp(success+eff.lootSuccessBonus-mentalPen,0.05,0.95);
    const items=[];
    if (rng.chance(chance)){
      const n=rng.int(1,3)+(rng.chance(0.3)?1:0);
      for (let i=0;i<n;i++){ const k=this._pickWeighted(weights, rng); const ik=DATA.resItem[k]; if (!ik) continue;
        const s=items.find(x=>x.key===ik); if (s) s.n++; else items.push({ key:ik, n:1 }); }
    }
    // 가구별 특수 드롭(가방/옷)
    if (def.gear && rng.chance(def.gearChance||0)){
      const pool = def.gear==='cloth'?DATA.clothKeys:DATA.bagKeys;
      const k=rng.pick(pool); items.push({ key:k, n:1 });
    }
    return items;
  },

  leave(){ const sc=state.explore; const g=State.stashResources();   // 복귀 시 휴대 자원 자동 적재
    const parts=Object.keys(g).map(k=>this._lbl(k,g[k]));
    state.mode='train'; state.stranded=state.res.fuel<=0; state.lastStopKm=state.distanceKm; UI.setExploreUI(false);
    UI.toast(`🚂 복귀 — 정차 중 내구도 ${Math.round(sc.durLost)} 손상${parts.length?' · 적재 '+parts.join(', '):''}`);
    state.explore=null; Train.enter(); State.save(); },
  _lbl(k,amt){ const m={food:'🍞식량',water:'💧물',fuel:'⛽연료',scrap:'🔩재료',parts:'⚙️부품',meds:'💊약'}; return `${m[k]||k} +${amt}`; },

  /* ---------------- 렌더 ---------------- */
  render(ctx, w, h) {
    const sc=state.explore; if (!sc) return; const C=CONFIG.explore;
    const P={ cx:sc.cam.x-w/2, cy:sc.cam.y, ys:C.yScale, oy:h/2 };
    // 위쪽 어둑한 배경(원경)
    ctx.fillStyle=Art._groundColor(sc.biomeKey,0.25); ctx.fillRect(0,0,w,h);
    Art.exGround(ctx, sc, P, w, h);

    // 소리 파동(달리기/공격/문 부수기 시 주변에 퍼지는 반경 표시)
    if (sc.noiseR>0) Art.exNoiseRing(ctx,P,sc.noiseX,sc.noiseY,sc.noiseR);
    // 작동 중인 자동차 알람: 매우 넓은 유인 반경 표시
    for (const c of sc.cars){ if (c.alarm==='ringing') Art.exNoiseRing(ctx,P,c.x,c.y,CONFIG.explore.alarmRadius); }

    // 조준 부채꼴(사거리·반경 안내) + 휘두름 이펙트 — 클릭 방향으로 부채꼴 공격
    { const p=sc.player, ast=State.attackStats(); const rr=ast.range, half=ast.angle*Math.PI/180;
      if (p.swingT>0){ const a=U.clamp(p.swingT/0.2,0,1);
        Art.exAimFan(ctx,P,p.x,p.y,p.swingDir||0,p.swingHalf||half,p.swingRange||rr, 0.30*a, true);
      } else { let ang=null; const fresh=!!(sc.aim&&sc.aim.t>0);
        if (fresh) ang=Math.atan2(sc.aim.y-p.y, sc.aim.x-p.x);
        else if (p.dir && (p.dir.x||p.dir.y)) ang=Math.atan2(p.dir.y,p.dir.x);
        if (ang!=null) Art.exAimFan(ctx,P,p.x,p.y,ang,half,rr, fresh?0.16:0.08, fresh); } }

    // 깊이 정렬용 드로 리스트
    const draws=[]; const insideB=sc.player.inside||null;
    draws.push({ y:sc.trainEdge.y+sc.trainEdge.h, fn:()=>Art.exTrainEdge(ctx,sc.trainEdge,P) });
    for (const b of sc.buildings){
      draws.push({ y:b.y-1, fn:()=>Art.exRoomFloor(ctx,b,P, b===insideB) });          // 바닥+벽(지붕 아래)
      draws.push({ y:b.y+b.h+1, fn:()=>Art.exBuilding(ctx,b,P, b===insideB) });        // 지붕/외관(진입 시 반투명)
      for (const f of (b.furniture||[])){ const ff=f;
        draws.push({ y:ff.y, fn:()=>Art.exFurniture(ctx,ff,P, !this._looted(ff), U.dist(sc.player.x,sc.player.y,ff.x,ff.y)<46) }); } }
    for (const c of sc.cars){ const cc=c; draws.push({ y:cc.y, fn:()=>Art.exCar(ctx,cc,P, !this._looted(cc)) }); }
    for (const fs of sc.farmSpots) draws.push({ y:fs.y, fn:()=>{ if (fs.planted) Art.exFarmPlot(ctx,{x:fs.x,y:fs.y,fenced:fs.fenced},P); else { const x=Art.sx(P,fs.x),gy=Art.sy(P,fs.y); ctx.fillStyle='#5a3f28'; ctx.fillRect(x-26,gy-8,52,14); ctx.font='11px sans-serif'; ctx.fillStyle='#d9c39b'; ctx.textAlign='center'; ctx.fillText('밭 자리',x,gy+4); } } });
    for (const hsp of sc.hides) draws.push({ y:hsp.y, fn:()=>Art.exHide(ctx,hsp,P, sc.player.hidden && U.dist(sc.player.x,sc.player.y,hsp.x,hsp.y)<hsp.r) });
    for (const z of sc.zombies) draws.push({ y:z.y, fn:()=>Art.exZombie(ctx,z,P,sc.elapsed) });
    if (sc.survivor) draws.push({ y:sc.survivor.y, fn:()=>Art.exSurvivor(ctx,sc.survivor,P,sc.elapsed) });
    for (const f of (sc.followers||[])) draws.push({ y:f.y, fn:()=>Art.exFollower(ctx,f,P,sc.elapsed,State.crewById(f.crewId)) });
    const p=sc.player;
    draws.push({ y:p.y, fn:()=>Art.exPerson(ctx,p,P,'#ffd34d',sc.elapsed) });
    draws.sort((a,b)=>a.y-b.y); for (const d of draws) d.fn();

    // 기차 공격 경고(스무딩)
    if (sc.attackers>0 || (sc.attackHoldT||0)>0){ const x=Art.sx(P,sc.trainEdge.x+sc.trainEdge.w/2), y=Art.sy(P,sc.trainEdge.y)-44;
      ctx.fillStyle='#ff5a4a'; ctx.font='bold 14px sans-serif'; ctx.textAlign='center'; ctx.fillText('⚠️ 공격받는 중', x, y); }

    // 검색 진행바
    if (p.searchTarget){ const t=p.searchTarget; const tx=t.door?t.door.x:t.x, ty=t.door?t.door.y:t.y;
      const x=Art.sx(P,tx), y=Art.sy(P,ty)-46, pct=p.searchT/C.searchSec;
      ctx.fillStyle='rgba(0,0,0,0.6)'; ctx.fillRect(x-26,y,52,8); ctx.fillStyle='#7ad17a'; ctx.fillRect(x-25,y+1,50*pct,6); }
    // 문 부수기/따기 진행바
    if (p.doorTarget){ const b=p.doorTarget; const x=Art.sx(P,b.x+b.w/2), y=Art.sy(P,b.y+b.h)-C.wallH-12;
      const need=p.doorNeed||C.doorBreakSec, pct=U.clamp(p.doorT/need,0,1);
      ctx.fillStyle='rgba(0,0,0,0.6)'; ctx.fillRect(x-32,y,64,9); ctx.fillStyle=p.doorPick?'#6bd0e0':'#e0a13a'; ctx.fillRect(x-31,y+1,62*pct,7);
      ctx.fillStyle='#fff'; ctx.font='bold 10px sans-serif'; ctx.textAlign='center'; ctx.fillText(p.doorPick?'🔓 여는 중…':'🔨 부수는 중…', x, y-4); }
    // 알람 설치 진행바
    if (p.alarmTarget){ const c=p.alarmTarget; const x=Art.sx(P,c.x), y=Art.sy(P,c.y)-34, pct=U.clamp(p.alarmT/C.alarmInstallSec,0,1);
      ctx.fillStyle='rgba(0,0,0,0.6)'; ctx.fillRect(x-32,y,64,9); ctx.fillStyle='#e0a13a'; ctx.fillRect(x-31,y+1,62*pct,7);
      ctx.fillStyle='#fff'; ctx.font='bold 10px sans-serif'; ctx.textAlign='center'; ctx.fillText('🛠️ 알람 설치 중…', x, y-4); }

    const sky=Art.skyColors(state.dayT); if (sky.dark>0){ ctx.fillStyle=`rgba(6,8,20,${sky.dark*0.5})`; ctx.fillRect(0,0,w,h); }
    const wk=State.weatherKind(); if (wk==='rain') Art.rain(ctx,w,h,state.weather.intensity, sc.elapsed); else if (wk==='heat') Art.heat(ctx,w,h,state.weather.intensity);
    this._minimap(ctx,w,h,sc);
    this._hud(ctx,w,h,sc);
  },

  // 미니맵(좌상단) — 전체 맵에서 플레이어·건물·좀비·기차 위치와 현재 화면 범위 표시
  _minimap(ctx,w,h,sc){
    const mw=120, mh=Math.max(56, Math.round(mw*sc.h/sc.w)), x0=10, y0=102;
    const sxm=wx=>x0+(wx/sc.w)*mw, sym=wy=>y0+(wy/sc.h)*mh;
    ctx.save();
    ctx.fillStyle='rgba(8,10,16,0.72)'; ctx.fillRect(x0-3,y0-3,mw+6,mh+6);
    ctx.strokeStyle='rgba(255,255,255,0.22)'; ctx.lineWidth=1; ctx.strokeRect(x0-3.5,y0-3.5,mw+7,mh+7);
    for (const b of sc.buildings){ ctx.fillStyle=b.locked?'rgba(168,96,80,0.95)':U.shade(b.def.color,0.05);
      ctx.fillRect(sxm(b.x),sym(b.y),Math.max(2,(b.w/sc.w)*mw),Math.max(2,(b.h/sc.h)*mh)); }
    ctx.fillStyle='#3fa35a'; for (const hsp of sc.hides) ctx.fillRect(sxm(hsp.x)-1,sym(hsp.y)-1,2,2);
    ctx.fillStyle='#9a7b4a'; for (const fs of sc.farmSpots) ctx.fillRect(sxm(fs.x)-1.5,sym(fs.y)-1.5,3,3);
    ctx.fillStyle='#cfe6ff'; for (const c of sc.cars) ctx.fillRect(sxm(c.x)-1,sym(c.y)-1,2,2);
    for (const z of sc.zombies){ ctx.fillStyle=z.alerted?'#ff5a4a':(z.investigate?'#ffae4a':'rgba(200,96,84,0.7)'); ctx.fillRect(sxm(z.x)-1,sym(z.y)-1,2,2); }
    ctx.fillStyle='#5fcdb6'; for (const f of (sc.followers||[])) ctx.fillRect(sxm(f.x)-1,sym(f.y)-1,2,2);
    ctx.fillStyle='#e0584a'; ctx.fillRect(sxm(sc.trainEdge.x),sym(sc.trainEdge.y+sc.trainEdge.h/2)-2,4,4);
    if (sc.survivor){ ctx.fillStyle='#ffd34d'; ctx.fillRect(sxm(sc.survivor.x)-1.5,sym(sc.survivor.y)-1.5,3,3); }
    ctx.fillStyle='#ffd34d'; ctx.beginPath(); ctx.arc(sxm(sc.player.x),sym(sc.player.y),2.6,0,7); ctx.fill();
    ctx.strokeStyle='#000'; ctx.lineWidth=0.8; ctx.stroke();
    // 현재 화면 범위
    const ys=CONFIG.explore.yScale, vx0=sc.cam.x-w/2, vy0=sc.cam.y-(h/2)/ys;
    ctx.strokeStyle='rgba(255,255,255,0.55)'; ctx.lineWidth=1;
    ctx.strokeRect(sxm(vx0),sym(vy0),(w/sc.w)*mw,((h/ys)/sc.h)*mh);
    ctx.fillStyle='rgba(255,255,255,0.45)'; ctx.font='8px sans-serif'; ctx.textAlign='left'; ctx.fillText('🗺️',x0+1,y0+9);
    ctx.restore();
  },

  _hud(ctx,w,h,sc){
    const C=CONFIG.explore;
    const showing = sc.attackers>0 || (sc.attackHoldT||0)>0;
    const cnt = sc.attackers>0 ? sc.attackers : (sc.attackersShown||0);
    const pwr = sc.attackers>0 ? sc.attackPower : (sc.attackPowerShown||0);
    ctx.fillStyle='rgba(0,0,0,0.5)'; ctx.fillRect(w/2-140,12,280,24);
    ctx.font='bold 13px sans-serif'; ctx.textAlign='center';
    const fol=(sc.followers&&sc.followers.length)?` · 🤝동행 ${sc.followers.length}`:'';
    if (showing && cnt>0){ const rate=(pwr*CONFIG.stop.durPerZombiePerSec*State.effects().trainDefenseMul).toFixed(1);
      ctx.fillStyle='#ff5a4a'; ctx.fillText(`🚂 기차 공격 중! 좀비 ${cnt}마리 (내구도 -${rate}/s)${fol}`, w/2, 29);
    } else { ctx.fillStyle='#9ad17a';
      const grace=Math.max(0, C.trainSiegeDelaySec - sc.elapsed);
      const tail = grace>0 ? ` · ⏳집결까지 ${Math.ceil(grace)}s` : '';
      ctx.fillText(`🚂 기차 안전 · 🧟 ${sc.zombies.length}마리${sc.player.hidden?' · 🫥 은신중':''}${fol}${tail}`, w/2, 29); }
    if (sc.msgT>0){ ctx.fillStyle=`rgba(255,255,255,${U.clamp(sc.msgT,0,1)})`; ctx.font='bold 16px sans-serif'; ctx.fillText(sc.msg,w/2,58); }
    // 무기/내구도 (좌상단)
    const ew=State.equippedWeapon();
    ctx.textAlign='left'; ctx.font='bold 12px sans-serif';
    const wl='⚔️ '+(ew?`${DATA.weapons[ew.key].name} ${ew.dur}/${ew.durMax}`:'맨손');
    const ww=ctx.measureText(wl).width+12;
    ctx.fillStyle='rgba(0,0,0,0.5)'; ctx.fillRect(10,52,ww,20);
    ctx.fillStyle=(ew&&ew.dur<=5)?'#ff8a6e':'#fff'; ctx.fillText(wl,16,66);
    // 날씨·체온·실내·휴대무게 (좌상단 아래)
    const pl=State.player(); const tp=pl?(pl.temp==null?37:pl.temp):37;
    const wk=State.weatherKind();
    const wic= wk==='rain'?'🌧️':(wk==='heat'?'🥵':(Art.skyColors(state.dayT).dark>0.5?'🌙':'☀️'));
    const shel=sc.player.inside?' 🏠':(sc.player.hidden?' 🌳':(state._exposed?'':' 🚂'));
    const tcol=tp<33?'#5aa8ff':(tp<35.5?'#6bd0e0':(tp>39?'#ff6a4a':(tp>37.8?'#ffae4a':'#9ad17a')));
    const cw=Math.round(State.invWeight()*10)/10, cap=State.invCapacity();
    const wcol=cw>=cap-0.05?'#ff6a4a':(cw>cap*0.85?'#ffae4a':'#bfe0c0');
    const s1=`${wic} 🌡️`, s2=` ${tp.toFixed(1)}°${shel}`, s3='  🎒 ', s4=`${cw}/${cap}`;
    ctx.fillStyle='rgba(0,0,0,0.5)'; ctx.fillRect(10,76,ctx.measureText(s1+s2+s3+s4).width+18,20);
    let cxp=16;
    ctx.fillStyle='#cfe0ea'; ctx.fillText(s1,cxp,90); cxp+=ctx.measureText(s1).width;
    ctx.fillStyle=tcol;     ctx.fillText(s2,cxp,90); cxp+=ctx.measureText(s2).width;
    ctx.fillStyle='#cfe0ea'; ctx.fillText(s3,cxp,90); cxp+=ctx.measureText(s3).width;
    ctx.fillStyle=wcol;     ctx.fillText(s4,cxp,90);
    // 스태미나(달리는 중/회복 중일 때만 표시)
    const st=sc.player.stamina!=null?sc.player.stamina:C.staminaMax;
    const ex=sc.player.exhausted;
    if (st < C.staminaMax-0.5){ const bw=160, bx=w/2-bw/2, by=h-50;
      ctx.fillStyle='rgba(0,0,0,0.5)'; ctx.fillRect(bx,by,bw,15);
      ctx.fillStyle = ex?'#d9534f':(st<25?'#e0a13a':'#56c8e0'); ctx.fillRect(bx+2,by+2,(bw-4)*U.clamp(st/C.staminaMax,0,1),11);
      ctx.fillStyle='#fff'; ctx.font='bold 10px sans-serif'; ctx.textAlign='center';
      ctx.fillText(ex?'😮‍💨 지쳐서 달릴 수 없음 — 회복 중':'🏃 스태미나',w/2,by+11); }
    ctx.fillStyle='rgba(255,255,255,0.5)'; ctx.font='12px sans-serif'; ctx.textAlign='center';
    ctx.fillText('[E] 가구 뒤지기(인벤토리)·🔒문열기/닫기·구출 · 🚂앞 [E] 적재 · 클릭 공격 · Shift 달리기(소리↑)', w/2, h-12);
  },
};
