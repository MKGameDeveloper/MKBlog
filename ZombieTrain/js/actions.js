/* =========================================================================
 * actions.js — 고수준 게임 액션
 * ========================================================================= */
const Actions = {
  // ---- 운행 ----
  setSpeed(idx){ if (idx>0 && state.res.fuel<=0){ UI.toast('⛽ 연료가 없어 출발할 수 없습니다'); return; }
    state.speedIdx=idx; state.running=idx>0; this._after(); },
  depart(){ this.setSpeed(state.speedIdx>0?state.speedIdx:CONFIG.defaultSpeedIdx); },
  stopTrain(){ Train.stopTrain(); },
  // 마지막 정차 후 충분히 이동했는지(불모지 갇힘은 예외)
  reExploreRemain(){ if (state.stranded || state.lastStopKm==null) return 0;
    return Math.max(0, CONFIG.explore.reExploreKm - (state.distanceKm - state.lastStopKm)); },
  goExplore(){
    const remain=this.reExploreRemain();
    if (remain>0){ UI.toast(`🚉 방금 정차한 지역입니다 — ${Math.ceil(remain)}km 더 이동 후 탐험 가능`); return; }
    state.running=false; state.speedIdx=0; const biome=State.currentBiomeKey(); UI.closeModal(); Explore.enter(biome); },

  setStopTarget(km){ state.stopTargetKm=km; UI.toast(`📍 정차 목표 설정: ${Math.round(km)}km`); this._after(); },
  clearStopTarget(){ state.stopTargetKm=null; this._after(); },

  // ---- 수리 ----
  repairCarMul(){ return 1 + state.cars.length*CONFIG.repair.perCarMul; },
  repairCostPerDur(){ const m=this.repairCarMul()*State.effects().repairCostMul;
    return { scrap:CONFIG.repair.scrapPerDur*m, parts:CONFIG.repair.partsPerDur*m }; },
  repairCostFor(d){ const c=this.repairCostPerDur(); return { scrap:Math.ceil(d*c.scrap), parts:Math.ceil(d*c.parts) }; },
  repair(){ const need=CONFIG.max.durability-state.res.durability; if (need<=0.5){ UI.toast('🔧 내구도가 이미 최대입니다'); return; }
    const c=this.repairCostPerDur(); let d=need;
    if (state.res.scrap<c.scrap*d) d=Math.min(d,state.res.scrap/c.scrap);
    if (state.res.parts<c.parts*d) d=Math.min(d,state.res.parts/c.parts); d=Math.floor(d);
    if (d<=0){ UI.toast('🧰 재료/부품이 부족합니다'); return; }
    const cost=this.repairCostFor(d); state.res.scrap-=cost.scrap; state.res.parts-=cost.parts;
    state.res.durability=U.clamp(state.res.durability+d,0,CONFIG.max.durability);
    UI.toast(`🔧 내구도 +${d} (재료 ${cost.scrap}, 부품 ${cost.parts})`); this._after(); },

  // ---- 칸 증설 ----
  addCarCost(){ const n=state.cars.length, g=Math.pow(CONFIG.addCar.growth,n-CONFIG.start.cars);
    return { scrap:Math.round(CONFIG.addCar.baseScrap*g*State.effects().repairCostMul), parts:Math.round(CONFIG.addCar.baseParts*g*State.effects().repairCostMul) }; },
  addCar(){ const c=this.addCarCost(); if (state.res.scrap<c.scrap||state.res.parts<c.parts){ UI.toast(`🧱 재료 ${c.scrap}, 부품 ${c.parts} 필요`); return; }
    state.res.scrap-=c.scrap; state.res.parts-=c.parts; state.cars.push({ id:newId(), companionId:null }); state.stats.carsBuilt++;
    UI.toast(`🚃 객차 증설! (총 ${state.cars.length}칸)`); this._after(); },

  // ---- 동료 ----
  recruit(trait,name){ const car=state.cars.find(c=>!c.companionId); if (!car){ UI.toast('🚪 빈 객차가 없습니다'); return false; }
    const m=State.mkCrew(name,trait,false); m.carId=car.id; state.crew.push(m); car.companionId=m.id; state.stats.recruited++;
    const d=DATA.traits[trait]; UI.toast(`🤝 ${name}(${d.name}) 합류! — ${d.desc}`); this._after(); return true; },
  // 탐험 동행 토글(다음/현재 탐험에 따라나섬)
  toggleFollow(id){ const m=State.crewById(id); if (!m||m.isPlayer) return;
    if (State.busy(m.id)){ UI.toast('🌱 작업(내부 농사) 중인 동료는 동행할 수 없습니다'); return; }
    m.following=!m.following;
    UI.toast(m.following?`🚶 ${m.name} 동행 ON — 다음 탐험부터 함께 나갑니다`:`🏠 ${m.name} 동행 OFF — 기차에서 대기`); this._after(); },

  dismiss(id){ const m=State.crewById(id); if (!m||m.isPlayer) return false;
    if (!confirm(`정말 ${m.name}을(를) 내보낼까요? 되돌릴 수 없으며, 남은 동료의 멘탈에도 영향이 있습니다.`)) return false;
    const car=state.cars.find(c=>c.companionId===id); if (car) car.companionId=null;
    if (state.innerFarm.workerId===id){ state.innerFarm.active=false; state.innerFarm.workerId=null; }
    state.crew=state.crew.filter(x=>x.id!==id); UI.toast(`👋 ${m.name}을(를) 내보냈습니다`); this._after(); return true; },

  useMeds(id){ const m=State.crewById(id); if (!m){ return; } if (!m.infected){ UI.toast('치료가 필요 없습니다'); return; }
    if (state.res.meds<=0){ UI.toast('💊 약이 없습니다 — 약국에서 구하세요'); return; }
    state.res.meds--; m.infection=Math.max(0,m.infection-CONFIG.infection.medsCure);
    if (m.infection<=0){ m.infected=false; UI.toast(`💉 ${m.name} 감염 치료 완료`); } else UI.toast(`💉 ${m.name} 감염 ${Math.round(m.infection)}%로 완화`); this._after(); },

  // ---- 내부 농사(워커 1명 점유) ----
  innerFarmStart(workerId){ if (state.innerFarm.active){ UI.toast('🌱 이미 내부 농사 중입니다'); return; }
    const m=State.crewById(workerId); if (!m){ UI.toast('배치할 인원을 선택하세요'); return; }
    if (state.res.scrap<CONFIG.farm.plantScrap){ UI.toast(`🌱 파종에 재료 ${CONFIG.farm.plantScrap} 필요`); return; }
    state.res.scrap-=CONFIG.farm.plantScrap; state.innerFarm={ active:true, workerId, progressSec:0, ripe:false };
    UI.toast(`🌱 ${m.name} 내부 농사 시작 — 다른 특성 효과는 멈춥니다(응급용)`); this._after(); },
  innerFarmStop(){ state.innerFarm={ active:false, workerId:null, progressSec:0, ripe:false }; UI.toast('🌱 내부 농사 중단'); this._after(); },
  innerFarmHarvest(){ if (!state.innerFarm.ripe){ UI.toast('🌱 아직 자라지 않았습니다'); return; }
    const amt=Math.round(CONFIG.farm.inner.yield*State.effects().farmYieldMul);
    state.res.food=U.clamp(state.res.food+amt,0,CONFIG.max.food); state.innerFarm={ active:false, workerId:null, progressSec:0, ripe:false };
    state.stats.harvests++; UI.toast(`🌱 내부 수확! 식량 +${amt}`); this._after(); },

  // ---- 외부 농장 수확 ----
  harvestFarm(id){ const fm=state.farms.find(f=>f.id===id); if (!fm||!fm.alive){ UI.toast('수확할 수 없습니다'); return; }
    if (!fm.ripe){ UI.toast('🌾 아직 자라지 않았습니다'); return; }
    if (Math.abs(state.distanceKm-fm.dueKm)>45 && state.distanceKm<fm.dueKm){ UI.toast('🌾 아직 농장 위치에 도착하지 않았습니다 — 맵에서 정차 목표를 설정하세요'); return; }
    const amt=Math.round(CONFIG.farm.outer.yield*State.effects().farmYieldMul);
    state.res.food=U.clamp(state.res.food+amt,0,CONFIG.max.food); fm.harvested=true; fm.alive=false; state.stats.harvests++;
    UI.toast(`🌾 외부 농장 수확! 식량 +${amt}`); this._after(); },

  // 플레이어 특성 선택(시작 시)
  chooseTrait(k){ const p=State.player(); if (p && DATA.traits[k]) p.trait=k; Game._startBlock=false; UI.closeModal();
    UI.toast(`특성 선택: ${DATA.traits[k].icon} ${DATA.traits[k].name} — 새로운 여정 시작!`); this._after(); },

  // ---- 무기 ----
  craftWeapon(key){ const d=DATA.weapons[key]; if (!d) return;
    if (state.res.scrap<d.scrap || state.res.parts<d.parts){ UI.toast(`🔩 재료 ${d.scrap}, 부품 ${d.parts} 필요`); return; }
    state.res.scrap-=d.scrap; state.res.parts-=d.parts;
    const crafted = State.hasActiveTrait('crafting');
    const durMax = Math.round(d.dur * (crafted?1.4:1));   // 제작전문가 내구도 보정
    const w={ id:newId(), key, dur:durMax, durMax }; state.weapons.push(w); state.weaponId=w.id;
    UI.toast(`⚔️ ${d.name} 제작! (사거리 ${d.range}·공격력 ${d.dmg}·내구 ${durMax}${crafted?' 제작전문가 보정':''})`);
    this._after(); },
  equipWeapon(id){ state.weaponId=id; const w=State.equippedWeapon();
    UI.toast(w?`🗡️ ${DATA.weapons[w.key].name} 장착`:'✊ 맨손'); this._after(); },

  // ---- 약탈 인벤토리 / 적재 ----
  lootTake(key){ const c=UI._lootContainer; if (!c) return; const s=(c.items||[]).find(x=>x.key===key); if (!s) return;
    const took=State.invAdd(key, s.n);
    if (took<=0){ UI.toast('🎒 가방이 가득 찼습니다 — 기차에서 적재하세요'); return; }
    s.n-=took; if (s.n<=0) c.items=c.items.filter(x=>x!==s);
    this._after(); },
  lootTakeAll(){ const c=UI._lootContainer; if (!c) return; let any=false, full=false;
    for (const s of (c.items||[]).slice()){ const took=State.invAdd(s.key, s.n); if (took>0){ any=true; s.n-=took; } if (s.n>0) full=true; }
    c.items=(c.items||[]).filter(s=>s.n>0);
    if (c.weapons && c.weapons.length){ for (const w of c.weapons.slice()){ const inst={ id:newId(), key:w.key, dur:w.dur, durMax:w.durMax };
      state.weapons.push(inst); if (!state.weaponId) state.weaponId=inst.id; any=true; } c.weapons=[]; }
    if (full) UI.toast('🎒 가방이 가득 찼습니다 — 일부만 담았습니다');
    else if (!any) UI.toast('담을 것이 없습니다');
    this._after(); },
  lootTakeWeapon(i){ const c=UI._lootContainer; if (!c||!c.weapons) return; const w=c.weapons[i]; if (!w) return;
    const inst={ id:newId(), key:w.key, dur:w.dur, durMax:w.durMax }; state.weapons.push(inst);
    const equipped = !state.weaponId; if (equipped) state.weaponId=inst.id;   // 맨손이면 자동 장착
    c.weapons.splice(i,1);
    UI.toast(`⚔️ ${DATA.weapons[w.key].name} 획득 (내구 ${w.dur}/${w.durMax})${equipped?' · 장착':''}`); this._after(); },
  lootReturn(key){ const c=UI._lootContainer; if (!c) return; if (State.invRemove(key,1)<1) return;
    if (!c.items) c.items=[]; const s=c.items.find(x=>x.key===key); if (s) s.n++; else c.items.push({key,n:1});
    this._after(); },
  equip(key){ if (State.equipItem(key)) UI.toast(`${DATA.items[key].icon} ${DATA.items[key].name} 장착`); this._after(); },
  unequip(slot){ State.unequip(slot); this._after(); },
  stashAll(){ const g=State.stashResources(); const ks=Object.keys(g);
    if (!ks.length){ UI.toast('적재할 자원이 없습니다'); return; }
    UI.toast('📦 기차에 적재: '+ks.map(k=>Explore._lbl(k,g[k])).join(', ')); this._after(); },

  newGame(){ State.reset(); state.stranded=false; UI.setExploreUI(false); UI.closeModal(); Train.enter(); this._after(); Game._startBlock=true; UI.showTraitSelect(); },

  _after(){ UI.refresh(); UI.rerenderPanel(); State.save(); },
};
