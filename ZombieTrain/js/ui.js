/* =========================================================================
 * ui.js — HUD(상단 비축 + 항시 크루 패널) + 모달 패널 + 토스트
 * ========================================================================= */
const UI = {
  els: {},
  _current: null,           // 현재 열린 패널 재렌더용
  _live: false,             // 열린 채 실시간 갱신할 패널(농사/운행실)
  init() {
    const id=(x)=>document.getElementById(x);
    this.els={ app:id('app'),
      barFood:id('bar-food'), barWater:id('bar-water'), barFuel:id('bar-fuel'), barDur:id('bar-dur'),
      vFood:id('val-food'), vWater:id('val-water'), vFuel:id('val-fuel'), vDur:id('val-dur'),
      vScrap:id('val-scrap'), vParts:id('val-parts'), vMeds:id('val-meds'), vCars:id('val-cars'),
      vKm:id('val-km'), vDay:id('val-day'), vSpeed:id('val-speed'), vWeather:id('val-weather'),
      crewHud:id('crew-hud'),
      modal:id('modal'), modalTitle:id('modal-title'), modalBody:id('modal-body'),
      toasts:id('toasts'), nav:id('nav'), returnBtn:id('return-btn') };
    id('modal-close').onclick=()=>this.closeModal();
    this.els.modal.addEventListener('click',(e)=>{ if (e.target===this.els.modal) this.closeModal(); });
    this.els.returnBtn.onclick=()=>{ if (state.mode==='explore') Explore.leave(); };
    this._crewCollapsed = (()=>{ try{ return localStorage.getItem('zt.crewCollapsed')==='1'; }catch(e){ return false; } })();
    this._bindTips();
  },

  // 상단 자원 등에 마우스 호버 시 설명 툴팁
  _bindTips(){
    const tip=document.getElementById('tip'); this.els.tip=tip;
    const closest=(t)=> (t && t.closest) ? t.closest('[data-tip]') : null;
    document.addEventListener('pointerover',(e)=>{ const el=closest(e.target); if (el){ tip.textContent=el.getAttribute('data-tip'); tip.classList.remove('hidden'); } });
    document.addEventListener('pointerout',(e)=>{ if (closest(e.target)) tip.classList.add('hidden'); });
    document.addEventListener('pointermove',(e)=>{ if (tip.classList.contains('hidden')) return;
      const x=Math.min((window.innerWidth||800)-tip.offsetWidth-8, e.clientX+14);
      tip.style.left=Math.max(6,x)+'px'; tip.style.top=(e.clientY+18)+'px'; });
    // 터치/클릭 시 잠깐 표시
    document.addEventListener('pointerdown',(e)=>{ const el=closest(e.target); if (el){ tip.textContent=el.getAttribute('data-tip');
      tip.style.left=Math.max(6,Math.min((window.innerWidth||800)-tip.offsetWidth-8,e.clientX-40))+'px'; tip.style.top=(e.clientY+18)+'px';
      tip.classList.remove('hidden'); clearTimeout(this._tipT); this._tipT=setTimeout(()=>tip.classList.add('hidden'),2200); } });
  },

  // ---- HUD ----
  refresh() {
    if (!state) return; const r=state.res, M=CONFIG.max, e=this.els;
    const setBar=(bar,val,max)=>{ bar.style.width=(U.clamp(val/max,0,1)*100)+'%'; bar.classList.toggle('low', val/max<0.25); };
    setBar(e.barFood,r.food,M.food); setBar(e.barWater,r.water,M.water); setBar(e.barFuel,r.fuel,M.fuel); setBar(e.barDur,r.durability,M.durability);
    e.vFood.textContent=Math.round(r.food); e.vWater.textContent=Math.round(r.water); e.vFuel.textContent=Math.round(r.fuel); e.vDur.textContent=Math.round(r.durability);
    e.vScrap.textContent=r.scrap; e.vParts.textContent=r.parts; e.vMeds.textContent=r.meds;
    e.vCars.textContent=`${state.cars.filter(c=>c.companionId).length}/${state.cars.length}`;
    e.vKm.textContent=Math.floor(state.distanceKm); e.vDay.textContent=state.day;
    e.vSpeed.textContent=state.running?CONFIG.speeds[state.speedIdx].name:'정지';
    if (e.vWeather){ const wi=state.weather?state.weather.intensity:0;
      e.vWeather.textContent = wi>0.45?'폭우':(wi>0.04?'비':'맑음'); }
    this._renderCrew();
    if (this._live) this.rerenderPanel();   // 농사/운행실 등은 열어둔 채 실시간 갱신
  },

  _cc(icon,val){ const v=U.clamp(val,0,100); const hue=Math.round(v*1.2);
    return `<div class="cc-stat"><span class="cc-ic">${icon}</span><span class="cc-bar"><span class="cc-fill ${v<25?'low':''}" style="width:${v}%;background:hsl(${hue},62%,45%)"></span></span><b class="cc-num">${Math.round(v)}</b></div>`; },
  _tempColor(tp){ return tp<33?'#5aa8ff':(tp<35.5?'#6bd0e0':(tp>39.6?'#ff5a4a':(tp>38.6?'#ffae4a':'#7ad17a'))); },
  // 체온 행(30~40°를 막대로) — 추우면 파랑, 발열이면 주황/빨강
  _ccTemp(m){ const tp=(m.temp==null)?37:m.temp; const col=this._tempColor(tp);
    const w=U.clamp((tp-30)/10,0,1)*100;
    return `<div class="cc-stat cc-temp"><span class="cc-ic">🌡️</span><span class="cc-bar"><span class="cc-fill" style="width:${w}%;background:${col}"></span></span><b class="cc-num" style="color:${col}">${tp.toFixed(1)}°</b></div>`; },
  toggleCrewCollapse(){ this._crewCollapsed=!this._crewCollapsed;
    try{ localStorage.setItem('zt.crewCollapsed', this._crewCollapsed?'1':'0'); }catch(e){}
    this._renderCrew(); },
  _renderCrew(){
    const collapsed=this._crewCollapsed;
    const toggle=`<button class="crew-toggle" onclick="UI.toggleCrewCollapse()" data-tip="${collapsed?'동료 상태 펼치기(전체 스탯)':'동료 상태 접기(체력·감염만)'}">${collapsed?'▸ 동료 상태':'▾ 동료 상태'}</button>`;
    const legend = collapsed ? '' : `<div class="crew-legend">❤️체력 · 🍖포만 · 💧수분 · 🧠멘탈 · 🛡️면역 · 🌡️체온</div>`;
    const exploring = state.mode==='explore';   // 탐험 중엔 상태창을 반투명, 피격 동료만 불투명 강조
    const html = state.crew.map(m=>{ const t=DATA.traits[m.trait]; const busy=State.busy(m.id); const fol=State.isFollowing(m);
      const tp=(m.temp==null)?37:m.temp;
      const tempChip = (tp<35.5||tp>38.6) ? `<em class="tmp" style="color:${this._tempColor(tp)}">🌡️${tp.toFixed(0)}°</em>` : '';
      const head=`<div class="cc-head"><span>${t.icon}</span><b>${m.name}</b>${fol?'<em class="fol">🚶</em>':''}${tempChip}${m.infected?'<em class="inf">🦠'+Math.round(m.infection)+'%</em>':''}${busy?'<em class="busy">🌱</em>':''}</div>`;
      const cls=`crew-card ${m.isPlayer?'me':''} ${collapsed?'compact':''} ${exploring?'dim':''} ${exploring&&m.hurtFlash>0?'hurt':''}`;
      const tip=`${m.name} — ${t.icon} ${t.name}: ${t.desc}`;
      const bubble=(m._bubbleT>0 && m._bubble)?`<div class="cc-bubble">${m._bubble}</div>`:'';
      if (collapsed){
        return `<div class="${cls}" data-tip="${tip}">${bubble}${head}${this._cc('❤️',m.hp)}${m.infected?`<div class="cc-inf">🦠 ${Math.round(m.infection)}%${state.res.meds>0?` <button class="cc-cure" onclick="Actions.useMeds(${m.id})">💊</button>`:''}</div>`:''}</div>`;
      }
      return `<div class="${cls}" data-tip="${tip}">
        ${bubble}${head}
        ${this._cc('❤️',m.hp)}${this._cc('🍖',100-m.hunger)}${this._cc('💧',100-m.thirst)}${this._cc('🧠',m.mental)}${this._cc('🛡️',100-m.infection)}${this._ccTemp(m)}
        ${m.infected?`<div class="cc-inf">🦠 감염 진행 ${Math.round(m.infection)}%${state.res.meds>0?` <button class="cc-cure" onclick="Actions.useMeds(${m.id})">💊치료</button>`:''}</div>`:''}
      </div>`; }).join('');
    this.els.crewHud.innerHTML = `<div class="crew-bar">${toggle}</div>` + legend + html;
  },

  setExploreUI(on){ this.els.app.classList.toggle('exploring', on); },

  toast(msg){ const box=this.els.toasts; const t=U.el('div','toast',msg); box.appendChild(t);
    while (box.children.length>5) box.firstChild.remove();   // 최대 5개만 노출(초과 시 오래된 것 제거)
    setTimeout(()=>t.classList.add('show'),10); setTimeout(()=>{ t.classList.remove('show'); setTimeout(()=>t.remove(),300); },2600); },

  // ---- 모달 ----
  openModal(title,html){ this.els.modalTitle.innerHTML=title; this.els.modalBody.innerHTML=html; this.els.modal.classList.remove('hidden'); this._live=false; },
  closeModal(){ this.els.modal.classList.add('hidden'); this._current=null; this._live=false; this._lootOpen=false; this._lootContainer=null; },

  // ---- 인벤토리/약탈/적재 ----
  _itemInfo(d){ const rn={food:'식량',water:'물',fuel:'연료',scrap:'재료',parts:'부품',meds:'약'};
    if (d.kind==='res') return `${rn[d.res]} +${d.amount}`;
    if (d.kind==='bag') return `휴대 +${d.cap}`;
    return `보온 ${d.warmth}${d.rain?` · 비저항 ${Math.round(d.rain*100)}%`:''}`; },
  _weightBar(){ const cw=State.invWeight(), cap=State.invCapacity(), pct=U.clamp(cw/cap,0,1)*100;
    const col=cw>=cap-0.05?'#ff6a4a':(cw>cap*0.85?'#e0a13a':'#6bbf59');
    return `<div class="mbar"><span>무게</span><div class="mbar-track"><div class="mbar-fill" style="width:${pct}%;background:${col}"></div></div><b>${Math.round(cw*10)/10}/${cap}</b></div>`; },
  _lootRow(s, mode){ const d=DATA.items[s.key]; if (!d) return '';
    let btn='';
    if (mode==='loot') btn=`<button class="mini" onclick="Actions.lootTake('${s.key}')">담기</button>`;
    else { if (d.kind!=='res') btn+=`<button class="mini" onclick="Actions.equip('${s.key}')">장착</button>`;
      if (mode==='inv') btn+=`<button class="mini ghost" onclick="Actions.lootReturn('${s.key}')">내려놓기</button>`; }
    return `<div class="loot-item"><span class="li-ic">${d.icon}</span>
      <div class="li-t"><b>${d.name}</b> ×${s.n}<div class="muted">${this._itemInfo(d)} · ${d.weight}kg</div></div>
      <div class="li-b">${btn}</div></div>`; },
  _invHtml(inLoot){ const bag=State.equippedBag(), cloth=State.equippedCloth();
    let h=`<div class="equip-row"><span>🎒 가방</span><b>${bag?`${bag.icon} ${bag.name} (+${bag.cap})`:'없음'}</b>${bag?`<button class="mini ghost" onclick="Actions.unequip('bag')">해제</button>`:''}</div>`;
    h+=`<div class="equip-row"><span>🧥 옷</span><b>${cloth?`${cloth.icon} ${cloth.name} (보온 ${cloth.warmth})`:'없음'}</b>${cloth?`<button class="mini ghost" onclick="Actions.unequip('cloth')">해제</button>`:''}</div>`;
    h+= state.inventory.length ? state.inventory.map(s=>this._lootRow(s, inLoot?'inv':'invonly')).join('') : '<p class="muted">휴대품이 없습니다.</p>';
    return h; },

  _weaponRow(w, i){ const d=DATA.weapons[w.key];
    return `<div class="loot-item"><span class="li-ic">${d.icon}</span>
      <div class="li-t"><b>${d.name}</b> <small>무기</small><div class="muted">사거리 ${d.range} · 각도 ${d.angle}° · 공격력 ${d.dmg} · 내구 ${w.dur}/${w.durMax}</div></div>
      <div class="li-b"><button class="mini" onclick="Actions.lootTakeWeapon(${i})">담기</button></div></div>`; },
  openLoot(c){ this._lootOpen=true; this._lootContainer=c; this._current=()=>this.openLoot(c);
    const def=c.def||DATA.car, items=c.items||[], weps=c.weapons||[];
    const has=items.length||weps.length;
    const left = has ? items.map(s=>this._lootRow(s,'loot')).join('') + weps.map((w,i)=>this._weaponRow(w,i)).join('')
                     : '<p class="muted">텅 비어 있습니다.</p>';
    const html=`<div class="loot-wrap">
      <div class="loot-col"><div class="loot-head">📦 ${def.name||'수납'} ${has?`<button class="mini" onclick="Actions.lootTakeAll()">⬇️ 전부 담기</button>`:''}</div>
        <div class="loot-list">${left}</div></div>
      <div class="loot-col"><div class="loot-head">🎒 내 인벤토리</div>${this._weightBar()}
        <div class="loot-list">${this._invHtml(true)}</div></div>
    </div><p class="muted">가방이 가득 차면 🚂기차로 돌아가 <b>적재</b>하세요. 가방/옷은 <b>장착</b>으로 강화됩니다.</p>`;
    this.openModal(`${def.icon||'📦'} ${def.name||'수납공간'} 약탈`, html); },

  openTrainStash(){ this._lootOpen=true; this._current=()=>this.openTrainStash();
    const resItems=state.inventory.filter(s=>DATA.items[s.key]&&DATA.items[s.key].kind==='res');
    const summary = resItems.length ? resItems.map(s=>{const d=DATA.items[s.key]; return `${d.icon}${s.n}`;}).join(' ') : '없음';
    const html=`<p class="muted">탐험 중 휴대한 <b>자원</b>을 기차 비축으로 옮깁니다. 가방·옷은 그대로 휴대/장착됩니다.</p>
      ${this._weightBar()}
      <button class="big" ${resItems.length?'':'disabled'} onclick="Actions.stashAll()">📦 자원 전부 싣기 <small>${summary}</small></button>
      <hr><h3 class="sub">🎒 인벤토리 / 장착</h3>${this._invHtml(false)}
      <hr><button class="big danger" onclick="UI.closeModal();Explore.leave()">🚂 떠나기(복귀)</button>`;
    this.openModal('🚃 기차 적재', html); },
  // 액션 직후 현재 열린 패널을 다시 그려 즉시 반영
  rerenderPanel(){ if (this._current && !this.els.modal.classList.contains('hidden')) this._current(); },
  _bar(label,val,max,color){ const pct=U.clamp(val/max,0,1)*100;
    return `<div class="mbar"><span>${label}</span><div class="mbar-track"><div class="mbar-fill" style="width:${pct}%;background:${color}"></div></div><b>${Math.round(val)}/${max}</b></div>`; },

  openCab(){ this._current=()=>this.openCab();
    const speeds=CONFIG.speeds.map((s,i)=>`<button class="opt ${state.speedIdx===i&&(i===0?!state.running:state.running)?'active':''}" onclick="Actions.setSpeed(${i})">${s.name}${s.kmh?` <small>${s.kmh}km/h</small>`:''}</button>`).join('');
    const b=DATA.biomes[State.currentBiomeKey()];
    const target=state.stopTargetKm!=null?`<p class="ok">📍 정차 목표 ${Math.round(state.stopTargetKm)}km (${Math.max(0,Math.round(state.stopTargetKm-state.distanceKm))}km 후) <button class="mini ghost" onclick="Actions.clearStopTarget();UI.openCab()">해제</button></p>`:'';
    this.openModal('🎛️ 운행실', `
      ${this._bar('⛽ 연료',state.res.fuel,CONFIG.max.fuel,'#e0a13a')}
      <p class="muted">현재 지형: <b>${b.icon} ${b.name}</b> · 거리 ${Math.floor(state.distanceKm)}km<br>연료는 보통속도로 약 10분 주행 시 고갈됩니다.</p>
      <div class="optrow">${speeds}</div>
      ${target}
      <hr>
      <button class="big" onclick="UI.openMap()">🗺️ 노선 지도 (정차 목표·농장)</button>
      ${(()=>{ const r=Actions.reExploreRemain();
        return r>0 ? `<button class="big" disabled>🧭 탐험까지 ${Math.ceil(r)}km 더 이동</button><p class="muted">방금 정차한 지역입니다. 조금 더 달려 새 지역에서 탐험하세요.</p>`
                   : `<button class="big danger" onclick="Actions.goExplore()">🧭 지금 정차하여 탐험</button>`; })()}`);
    this._live=true;   // 연료·거리·정차목표·재탐험 카운트다운 실시간 갱신
  },

  openCar(idx){ this._current=()=>this.openCar(idx); const car=state.cars[idx]; const occ=car.companionId?State.crewById(car.companionId):null;
    if (occ){ const t=DATA.traits[occ.trait]; this.openModal(`${t.icon} ${occ.name}`, `
      <p class="cls">${t.name}</p><p class="muted">${t.desc}</p>
      ${this._crewStats(occ)}
      ${occ.infected?`<button class="big" onclick="Actions.useMeds(${occ.id});UI.openCar(${idx})">💊 치료 (약 ${state.res.meds})</button>`:''}
      ${State.busy(occ.id)?`<button class="big ghost" disabled>🌱 내부 농사 중 — 동행 불가</button>`
        :`<button class="big ${occ.following?'':'ghost'}" onclick="Actions.toggleFollow(${occ.id});UI.openCar(${idx})">${occ.following?'🚶 탐험 동행 ON (눌러서 해제)':'🏠 탐험 동행 OFF (눌러서 동행)'}</button>`}
      <button class="big ghost" onclick="if(Actions.dismiss(${occ.id}))UI.closeModal()">👋 내보내기</button>`);
    } else this.openModal('🚪 빈 객차', `<p class="muted">탐험에서 🆘 생존자를 구출하면 이 칸에 태울 수 있습니다.</p>`);
  },
  _crewStats(m){ const tp=(m.temp==null)?37:m.temp; return `<div class="statgrid">
    <div>❤️ 체력 <b>${Math.round(m.hp)}</b></div><div>🍖 포만 <b>${Math.round(100-m.hunger)}</b></div>
    <div>💧 수분 <b>${Math.round(100-m.thirst)}</b></div><div>🧠 멘탈 <b>${Math.round(m.mental)}</b></div>
    <div>🛡️ 면역 <b>${Math.round(100-m.infection)}</b></div><div>🌡️ 체온 <b style="color:${this._tempColor(tp)}">${tp.toFixed(1)}°</b></div></div>
    ${m.infected?`<p class="warn">🦠 감염 진행 ${Math.round(m.infection)}% — 방치하면 서서히 악화돼 100%에서 변이/사망. 약(💊)으로 치료하세요.</p>`:''}
    ${tp<35.5?`<p class="warn">🥶 저체온 ${tp.toFixed(1)}° — 비를 피해 실내·기차·은신처에서 몸을 녹이세요.</p>`:(tp>38.6?`<p class="warn">🤒 발열 ${tp.toFixed(1)}° — 감염이 진행 중일 수 있습니다.</p>`:'')}`; },

  openRoster(){ this._current=()=>this.openRoster();
    const rows=state.crew.map(m=>{ const t=DATA.traits[m.trait];
      return `<div class="rosterRow"><span class="ic">${t.icon}</span>
        <div><b>${m.name}</b> ${m.isPlayer?'<small>(당신)</small>':''} <small>${t.name}</small>
          <div class="muted">${t.desc}</div>${this._crewStats(m)}</div>
        <div class="rcol">
          ${m.infected?`<button class="mini" onclick="Actions.useMeds(${m.id});UI.openRoster()">💊 치료</button>`:''}
          ${!m.isPlayer?(State.busy(m.id)
            ?`<button class="mini ghost" disabled>🌱 작업중</button>`
            :`<button class="mini ${m.following?'':'ghost'}" onclick="Actions.toggleFollow(${m.id});UI.openRoster()">${m.following?'🚶 동행 ON':'🏠 대기'}</button>`):''}
          ${!m.isPlayer?`<button class="mini ghost" onclick="if(Actions.dismiss(${m.id}))UI.openRoster()">내보내기</button>`:''}
        </div></div>`; }).join('');
    this.openModal('🤝 탑승 인원', `<p class="muted">객차 ${state.cars.filter(c=>c.companionId).length}/${state.cars.length}칸 · 인원이 많을수록 식량·물 소모가 큽니다.</p>
      <p class="muted">🚶 <b>동행</b>을 켜면 다음 탐험에 함께 나가 좀비를 같이 상대합니다(피해·감염은 그 동료의 실제 체력에 반영, 기차 방어 보너스는 빠집니다).</p>${rows}`);
  },

  openRepair(){ this._current=()=>this.openRepair(); const need=CONFIG.max.durability-state.res.durability; const cost=Actions.repairCostFor(Math.ceil(need));
    const craft=state.crew.some(m=>!State.busy(m.id)&&m.trait==='crafting')?`<p class="ok">🔧 제작전문가: 수리 비용 할인 중</p>`:'';
    this.openModal('🔧 정비', `${this._bar('🛠️ 내구도',state.res.durability,CONFIG.max.durability,'#9aa7b5')}
      <p class="muted">완전 수리: 재료 ${cost.scrap}, 부품 ${cost.parts} · 보유 재료 ${state.res.scrap}, 부품 ${state.res.parts}</p>
      <p class="muted">칸이 많을수록 수리 비용↑ (현재 ×${U.round1(Actions.repairCarMul())}).</p>${craft}
      <button class="big" onclick="Actions.repair();UI.openRepair()">🔧 가능한 만큼 수리</button>`); },

  openAddCar(){ this._current=()=>this.openAddCar(); const c=Actions.addCarCost(); const can=state.res.scrap>=c.scrap&&state.res.parts>=c.parts;
    this.openModal('🚃 객차 증설', `<p class="muted">현재 ${state.cars.length}칸. 칸이 늘수록 수리·증설 비용이 가파르게 늘어납니다(5~6칸이 한계).</p>
      <p class="${can?'ok':'warn'}">증설 비용: 재료 ${c.scrap}, 부품 ${c.parts} · 보유 재료 ${state.res.scrap}, 부품 ${state.res.parts}</p>
      <button class="big" ${can?'':'disabled'} onclick="Actions.addCar();UI.openAddCar()">🚃 객차 추가</button>`); },

  openCraft(){ this._current=()=>this.openCraft();
    const C=CONFIG.explore, ew=State.equippedWeapon(), ed=ew?DATA.weapons[ew.key]:null, crafted=State.hasActiveTrait('crafting');
    const cur = ew ? `${ed.icon} ${ed.name} <b>${ew.dur}/${ew.durMax}</b> · 사거리 ${ed.range} · 각도 ${ed.angle||C.attackAngle}° · 공격력 ${ed.dmg}`
                   : `✊ 맨손 · 사거리 ${C.attackRange} · 각도 ${C.attackAngle}° · 공격력 1`;
    const curBar = ew ? this._bar('🗡️ 내구도', ew.dur, ew.durMax, '#d0a050') : '';
    const note = crafted ? `<p class="ok">🔧 제작전문가: 무기 내구도 +40% 적용 중</p>` : `<p class="muted">제작전문가가 있으면 무기 내구도가 +40% 됩니다. 무기는 부채꼴 <b>사거리(반지름)</b>와 <b>각도(휘두르는 폭)</b>를 넓혀줍니다.</p>`;
    const craft = Object.keys(DATA.weapons).map(k=>{ const d=DATA.weapons[k]; const can=state.res.scrap>=d.scrap&&state.res.parts>=d.parts;
      const dur=Math.round(d.dur*(crafted?1.4:1));
      return `<div class="rosterRow"><span class="ic">${d.icon}</span>
        <div><b>${d.name}</b> <small>사거리 ${d.range} · 각도 ${d.angle}° · 공격력 ${d.dmg} · 내구 ${dur}</small>
          <div class="muted">재료 ${d.scrap}, 부품 ${d.parts}</div></div>
        <div class="rcol"><button class="mini" ${can?'':'disabled'} onclick="Actions.craftWeapon('${k}')">제작</button></div></div>`; }).join('');
    const owned = state.weapons.length ? state.weapons.map(w=>{ const d=DATA.weapons[w.key]; const eq=w.id===state.weaponId;
      return `<div class="rosterRow"><span class="ic">${d.icon}</span>
        <div><b>${d.name}</b> <small>내구 ${w.dur}/${w.durMax}</small></div>
        <div class="rcol"><button class="mini ${eq?'':'ghost'}" onclick="Actions.equipWeapon(${eq?'null':w.id})">${eq?'해제(맨손)':'장착'}</button></div></div>`; }).join('')
      : `<p class="muted">보유한 무기가 없습니다.</p>`;
    this.openModal('⚔️ 무기 제작', `<p class="muted">현재 무기: ${cur}</p>${curBar}${note}<hr><h3 class="sub">제작 (사거리·공격력 ↑)</h3>${craft}<hr><h3 class="sub">보유 무기</h3>${owned}`);
  },

  openFarm(){ this._current=()=>this.openFarm();
    const f=state.innerFarm; let inner;
    if (!f.active){
      const opts=state.crew.map(m=>`<button class="opt" onclick="Actions.innerFarmStart(${m.id});UI.openFarm()">${DATA.traits[m.trait].icon} ${m.name}</button>`).join('');
      inner=`<p class="muted">내부 농사는 인원 1명을 점유해 그 사람의 특성 효과가 멈춥니다(응급용). 재료 ${CONFIG.farm.plantScrap} 소모, 약 ${CONFIG.farm.inner.growSec}초 후 식량 +${CONFIG.farm.inner.yield}.</p>
        <p class="muted">담당 배치:</p><div class="optrow">${opts}</div>`;
    } else { const m=State.crewById(f.workerId); const pct=f.ripe?100:Math.round(f.progressSec/CONFIG.farm.inner.growSec*100);
      inner=`<p class="ok">🌱 ${m?m.name:'담당'} 내부 농사 중 (${f.ripe?'수확 준비':'성장 '+pct+'%'})</p>
        ${this._bar('🌱 성장',f.ripe?CONFIG.farm.inner.growSec:f.progressSec,CONFIG.farm.inner.growSec,'#6bbf59')}
        ${f.ripe?`<button class="big" onclick="Actions.innerFarmHarvest();UI.openFarm()">🌱 수확</button>`:`<button class="big ghost" onclick="Actions.innerFarmStop();UI.openFarm()">중단</button>`}`; }
    const farms=state.farms.filter(x=>x.alive&&!x.harvested);
    const ext = farms.length ? farms.map(fm=>this._farmRow(fm)).join('') : `<p class="muted">외부 농장이 없습니다. 평야·강에서 탐험 중 '밭 자리'에 파종하세요(농사/가구/제작 전문가 필요).</p>`;
    this.openModal('🌱 농사', `<h3 class="sub">내부 농사</h3>${inner}<hr><h3 class="sub">외부 농장 (지도 핀)</h3>${ext}
      <button class="big ghost" onclick="UI.openMap()">🗺️ 지도에서 보기</button>`);
    this._live=true;   // 내부 농사 성장 % 실시간 갱신
  },
  _farmRow(fm){ const b=DATA.biomes[fm.biome]; const eta=Math.round(fm.dueKm-state.distanceKm);
    const status = fm.ripe ? (Math.abs(state.distanceKm-fm.dueKm)<=45||state.distanceKm>=fm.dueKm?'<span class="ok">🌾 수확 가능</span>':'<span class="ok">곧 도착</span>')
      : `🌱 성장중 (${Math.max(0,eta)}km 후)`;
    const harvestBtn = fm.ripe ? `<button class="mini" onclick="Actions.harvestFarm(${fm.id});UI.openFarm()">🌾 수확</button>` : '';
    return `<div class="rosterRow"><span class="ic">${b.icon}</span>
      <div><b>${b.name} 농장</b> <small>${Math.round(fm.dueKm)}km${fm.fenced?' · 🪵울타리':''}</small><div class="muted">${status}</div></div>
      <div class="rcol">${harvestBtn}<button class="mini ghost" onclick="Actions.setStopTarget(${fm.dueKm});UI.openFarm()">📍 목표</button></div></div>`; },

  openMap(){ this._current=()=>this.openMap();
    const seg=DATA.segmentKm; const curSeg=Math.floor(state.distanceKm/seg);
    let nodes='';
    for (let i=1;i<=6;i++){ const km=(curSeg+i)*seg; const b=DATA.biomes[State.biomeKeyAt(km)];
      nodes+=`<div class="rosterRow"><span class="ic">${b.icon}</span><div><b>${b.name}</b> <small>${Math.round(km)}km</small><div class="muted">${Math.round(km-state.distanceKm)}km 후 · ${b.canFarm?'🌾농사 가능':'정차 가능'}</div></div>
        <div class="rcol"><button class="mini ghost" onclick="Actions.setStopTarget(${km});UI.openMap()">📍 목표</button></div></div>`; }
    const farms=state.farms.filter(x=>x.alive&&!x.harvested);
    const pins=farms.length?farms.map(fm=>this._farmRow(fm)).join(''):`<p class="muted">표시된 농장 핀이 없습니다.</p>`;
    const target=state.stopTargetKm!=null?`<p class="ok">📍 현재 정차 목표: ${Math.round(state.stopTargetKm)}km (${Math.max(0,Math.round(state.stopTargetKm-state.distanceKm))}km 후) <button class="mini ghost" onclick="Actions.clearStopTarget();UI.openMap()">해제</button></p>`:`<p class="muted">정차 목표 미설정 — 노드/농장에 📍를 눌러 설정하면 도착 시 자동 정차합니다.</p>`;
    this.openModal('🗺️ 노선 지도', `<p class="muted">현재 위치 🚂 <b>${Math.floor(state.distanceKm)}km</b> · ${DATA.biomes[State.currentBiomeKey()].icon} ${DATA.biomes[State.currentBiomeKey()].name}</p>
      ${this._routeBar()}
      ${target}<hr><h3 class="sub">📍 외부 농장 핀</h3>${pins}<hr><h3 class="sub">다가오는 정차지</h3>${nodes}`);
  },

  // 노선 위 기차 현재 위치 시각화(바이옴 띠 + 기차/목표/농장 마커)
  _routeBar(){
    const seg=DATA.segmentKm, span=seg*9, startKm=Math.max(0, state.distanceKm-seg*1.5), endKm=startKm+span;
    const pct=km=>U.clamp((km-startKm)/span,0,1)*100;
    const col={ city:'#3a3f52', mountain:'#4a4f50', river:'#2f5f7a', station:'#444a5c', plains:'#4a6b32', wasteland:'#5a4a36' };
    let bands=''; const s0=Math.floor(startKm/seg), s1=Math.floor(endKm/seg);
    for (let s=s0;s<=s1;s++){ const k0=s*seg, bk=State.biomeKeyAt(k0), b=DATA.biomes[bk];
      const L=Math.max(0,pct(k0)), R=Math.min(100,pct((s+1)*seg)); if (R<=L) continue;
      bands+=`<div class="rm-seg" style="left:${L}%;width:${R-L}%;background:${col[bk]||'#333'}" title="${b.name} ${Math.round(k0)}km"><span>${b.icon}</span></div>`; }
    let marks=`<div class="rm-train" style="left:${pct(state.distanceKm)}%">🚂</div>`;
    if (state.stopTargetKm!=null && state.stopTargetKm>=startKm && state.stopTargetKm<=endKm) marks+=`<div class="rm-mark" style="left:${pct(state.stopTargetKm)}%" title="정차 목표">🎯</div>`;
    for (const fm of state.farms){ if (!fm.alive||fm.harvested) continue; if (fm.dueKm>=startKm&&fm.dueKm<=endKm) marks+=`<div class="rm-mark ${fm.ripe?'ripe':''}" style="left:${pct(fm.dueKm)}%" title="${DATA.biomes[fm.biome].name} 농장">📍</div>`; }
    return `<div class="routemap"><div class="rm-track">${bands}${marks}</div>
      <div class="rm-scale"><span>${Math.round(startKm)}km</span><span>${Math.round(endKm)}km</span></div></div>`;
  },

  openHelp(){ this._current=()=>this.openHelp(); this.openModal('❓ 도움말', `
    <p class="muted"><b>목표:</b> 무한 선로를 달리며 최대한 오래 생존하세요. 화면 우측 <b>크루 카드</b>가 각 인원의 ❤️체력·🍖포만·💧수분·🧠멘탈·🛡️면역을 항상 보여줍니다.</p>
    <ul class="help">
      <li>🍞식량/💧물: 비축분에서 자동 소비. 떨어지면 개인 배고픔·목마름이 올라 체력이 깎입니다.</li>
      <li>⛽연료: 주행 시 소모(보통속도 ~10분). 0이면 불모지에 멈춤.</li>
      <li>🛠️내구도: 정차(탐험) 중 좀비가 손상. 재료·부품으로 수리.</li>
      <li>🧭탐험: 천천히 이동하며 🌳은신처와 <b>건물 벽 뒤</b>(좀비 시야 차단)로 좀비를 피합니다. <b>Shift</b>로 달릴 수 있으나 스태미나를 씁니다.</li>
      <li>🏠약탈(좀보이드식): <b>건물 출입문으로 들어가</b> 🧊냉장고·🗄️캐비넷·📒책상·🧰서랍장·🛒진열장에 다가가 <b>[E]</b>로 뒤지면(1~2초) <b>약탈 인벤토리</b>가 열립니다 — 왼쪽=수납공간, 오른쪽=내 가방. 항목을 <b>담기</b>로 가져오세요(가구마다 물자 경향이 다름).</li>
      <li>🎒인벤토리·무게: 휴대에는 <b>무게 한도</b>가 있습니다. <b>가방</b>(👜👜🧳)을 주워 장착하면 한도가 늘고, <b>옷</b>(🧥)을 장착하면 보온됩니다(단 🥵폭염엔 두꺼운 옷이 더 덥습니다). 가방이 차면 🚂기차 앞에서 <b>[E]</b>로 <b>적재</b>해 자원을 비축으로 옮기고 무게를 비우세요(복귀 시 자동 적재).</li>
      <li>🔒잠긴 문: 건물은 <b>높은 확률로 잠겨</b> 있습니다. 문 앞 <b>[E]</b>로 <b>부수거나</b>(시간↑·<b>큰 소리</b>) <b>🔧제작전문가</b>가 있으면 <b>조용히·빠르게 따고</b> 들어갑니다. 들어간 뒤 <b>[E]로 문을 닫으면</b> 좀비는 <b>부수기 전까진 못 들어옵니다</b>(은신처).</li>
      <li>🔊소리: <b>달리기·공격·문 부수기</b>는 소리가 퍼지고, 좀비는 <b>시야에 없어도 소리가 들리면(❓) 그 지점으로 확인하러</b> 옵니다(벽도 통과). 조용히 걸으면 들킬 위험이 줄어듭니다. 벽을 사이에 두면 서로 공격할 수 없습니다.</li>
      <li>🌡️체온은 <b>서서히</b> 변합니다 — 🌧️비/밤=하강, 🥵폭염=상승, 실내·🚂기차·🌳은신처·옷으로 완화. 저체온·고온은 멘탈·체력에 악영향.</li>
      <li>🦠감염: 한 번에 죽지 않고 서서히 진행됩니다. 진행 중에는 상태창 옆에 <b>말풍선 경고</b>("몸이 으슬으슬 춥다" 등)가 가끔 떠 위험을 알립니다. 발열로 체온이 오르기도 하니 💊약으로 일찍 치료하세요(100%면 변이/사망).</li>
      <li>🚂탐험 중 좀비는 기차로 몰려가 공격합니다(정차 후 약 ${CONFIG.explore.trainSiegeDelaySec}초 뒤부터 — 그 전엔 배회하니 그동안 파밍). 처치하거나 가까이서 유인해 떼어내야 내구도가 보존됩니다.</li>
      <li>💀오래 정차할수록 강한 좀비(👟질주·거구(체력↑)·흉포(공격력↑))가 섞여 나옵니다 — 필요한 것만 챙기고 빨리 떠나세요.</li>
      <li>🚶동행: 🤝동료 패널에서 동료의 <b>동행</b>을 켜면 다음 탐험에 함께 나가 좀비를 자동으로 같이 공격합니다. 단, 그 동료도 다치고 감염될 수 있고(실제 체력에 반영) 기차에 남았을 때 주던 방어 보너스는 빠집니다. 오른쪽 동료 카드는 <b>▾/▸</b>로 접어 체력·감염만 볼 수 있습니다.</li>
      <li>⚔️공격: <b>마우스로 클릭한 지점</b>을 향해 <b>부채꼴</b>로 휘두릅니다(바닥에 사거리·반경 안내선 표시). 무기를 장착하면 부채꼴의 <b>반지름(사거리)</b>과 <b>각도</b>가 넓어집니다. 무기는 쓰면 닳고 0이면 부서집니다(제작전문가 보유 시 내구도 +40%).</li>
      <li>🌱농사: 응급은 내부(인원 점유), 평소엔 외부 평야에 파종+🪵울타리. 지도 핀으로 위치 확인 후 정차해 수확.</li>
      <li>🚉탐험 후에는 같은 자리 즉시 재약탈이 안 됩니다 — ${CONFIG.explore.reExploreKm}km 이상 더 달려야 다시 탐험 가능(불모지 갇힘은 예외).</li>
      <li>⚔️무기 줍기: 약탈 중 낮은 확률로 무기를 발견합니다(내구도는 최대치의 20~60%로 닳은 상태). 약탈창에서 <b>담기</b>로 챙기면 맨손일 땐 자동 장착됩니다.</li>
      <li>🛠️기계전문가 알람: 기계전문가가 있으면 자동차에서 <b>[E]</b>로 부품을 써 <b>알람을 설치</b>하고, 다시 <b>[E]</b>로 <b>작동</b>시킬 수 있습니다. 작동하면 <b>매우 넓은 반경</b>의 좀비(추격 중인 좀비 포함)가 그 차로 몰려갑니다 — 멀리 떨어진 차에 켜서 좀비를 따돌리세요.</li>
      <li>특성: 🧭생존·👟빠른걸음·💪강한공격·🧱튼튼함·🔑열쇠공(맨손 자물쇠 따기)·🌡️안정형체온(체온 변화 느림)·🧳짐꾼(휴대 한도↑)·🛠️기계전문가(자동차 알람) — 탐험형 / 🌾농사·🔧제작·🔬연구·🪑가구 — 기차 패시브. 시작 시 본인 특성을 선택, 동료는 다양하게 합류.</li>
      <li>🗺️지도에서 현재 기차 위치와 다가오는 지형·농장 핀을 한눈에 확인하세요.</li>
    </ul>
    <p class="muted"><b>조작</b> — 이동: ◀▶▲▼ / WASD · 달리기: Shift · <b>상호작용(가구 약탈·구출·농사·복귀): E</b> · <b>공격: 화면 클릭(클릭 지점으로 부채꼴)</b> 또는 ⚔️/Space(바라보는 방향). 기차 안에서는 가까운 칸에서 E로 상호작용합니다.</p>`); },

  showTraitSelect(){ this._current=()=>this.showTraitSelect();
    const opts=DATA.traitOrder.map(k=>{ const t=DATA.traits[k]; const tag=t.kind==='explore'?'<small class="tg">탐험형</small>':'<small class="tg pas">기차 패시브</small>';
      return `<button class="trait-opt" onclick="Actions.chooseTrait('${k}')"><span class="ic">${t.icon}</span><div><b>${t.name}</b> ${tag}<div class="muted">${t.desc}</div></div></button>`; }).join('');
    this.openModal('🚂 좀비 트레인 — 특성 선택', `<p class="muted">당신(차장)의 특성을 고르세요. 직접 탐험을 나가므로 탐험형 특성은 본인에게 큰 도움이 됩니다. (동료는 다양한 특성을 지닌 채 합류)</p><div class="traitlist">${opts}</div>`);
  },

  showGameOver(reason){ this._current=()=>this.showGameOver(reason); const msgs={ crew:'굶주림·탈수로 쓰러졌습니다', eaten:'좀비에게 당했습니다', overrun:'기차가 점령당했습니다', turned:'감염이 진행되어 변이했습니다' };
    const s=state.stats; this.openModal('💀 게임 오버', `<p class="warn">${msgs[reason]||'여정이 끝났습니다'}</p>
      <div class="result"><div>📅 생존 <b>${s.daysSurvived}</b>일</div><div>📏 이동 <b>${Math.floor(s.km)}</b>km</div>
      <div>🤝 동료 <b>${s.recruited}</b></div><div>🧟 처치 <b>${s.kills}</b></div><div>📦 약탈 <b>${s.looted}</b></div><div>🌾 수확 <b>${s.harvests}</b></div></div>
      <button class="big danger" onclick="Actions.newGame()">↺ 다시 시작</button>`); },
};
