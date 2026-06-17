/* =========================================================================
 * state.js — 게임 상태 + 개인별 크루 시뮬 + 특성효과 + 저장/로드
 * ========================================================================= */
let state = null;
let _idSeq = 1;
const newId = () => _idSeq++;

const State = {
  mkCrew(name, trait, isPlayer) {
    return { id: newId(), name, trait, isPlayer: !!isPlayer, following: false,
      hp: 100, hunger: 10, thirst: 10, mental: 80, infection: 0, infected: false, carId: null,
      temp: CONFIG.temp.normal, _warnT: 4 + Math.random()*6, _bubble: '', _bubbleT: 0 };
  },

  // 게임마다 다른 노선 — 최소 15~20개 지역을 순회, 지하철역은 일정 간격으로 주기 배치
  _genRoute() {
    const pool = ['city','city','plains','plains','mountain','river','wasteland'];
    const every = 4 + Math.floor(Math.random()*3);              // 역 주기: 4~6 구간마다
    const kMin = Math.ceil(15/every), kMax = Math.floor(20/every);
    const k = kMin + Math.floor(Math.random()*(kMax-kMin+1));
    const len = every * k;                                      // 총 지역 수 15~20
    const route = [];
    for (let i=0;i<len;i++){
      if (i % every === every-1){ route.push('station'); continue; }   // 지하철역 주기 배치
      let b; do { b = pool[Math.floor(Math.random()*pool.length)]; } while (b===route[route.length-1]);
      route.push(b);                                            // 직전 지역과 겹치지 않게
    }
    return route;
  },

  fresh() {
    _idSeq = 1;
    const s = CONFIG.start;
    const cars = [];
    for (let i = 0; i < s.cars; i++) cars.push({ id: newId(), companionId: null });
    const player = this.mkCrew('당신', U.pick(DATA.traitOrder), true);
    return {
      mode: 'train', running: false, speedIdx: CONFIG.defaultSpeedIdx,
      seed: Math.floor(Math.random()*0x7fffffff),   // 마을/지형 배치용 게임 시드
      route: this._genRoute(),                       // 게임마다 랜덤한 노선
      distanceKm: 0, day: 1, dayT: 0.15,
      res: { food: s.food, water: s.water, fuel: s.fuel, durability: s.durability,
             scrap: s.scrap, parts: s.parts, meds: s.meds },
      crew: [player], cars,
      weather: { kind: 'clear', intensity: 0, target: 0, t: 18 + Math.random()*40 },  // 날씨(전역): clear/rain/heat
      _exposed: false,            // 현재 플레이어/동행이 비·추위에 노출됐는지(탐험 중 갱신)
      inventory: [],              // 탐험 중 휴대 물품 [{key,n}]
      equip: { bag: null, cloth: null },   // 장착(가방/옷)
      innerFarm: { active: false, workerId: null, progressSec: 0, ripe: false },
      weapons: [], weaponId: null,   // 제작한 무기 인벤토리 + 장착(null=맨손)
      farms: [],                 // 외부 농장 핀
      stopTargetKm: null,        // 정차 목표(맵)
      lastStopKm: null,          // 마지막 정차(탐험 복귀) 지점 — 재탐험 거리 제한용
      stats: { km: 0, kills: 0, daysSurvived: 1, recruited: 0, looted: 0, carsBuilt: 0, harvests: 0 },
      explore: null, stranded: false, over: false,
    };
  },

  // ---- 조회 ----
  companions() { return state.crew.filter(m => !m.isPlayer); },
  // 동행: 동료가 '동행' 설정 + 다른 작업(내부농사)에 점유되지 않은 상태
  isFollowing(m) { return !!m && !m.isPlayer && !!m.following && !this.busy(m.id); },
  followers() { return state.crew.filter(m => this.isFollowing(m)); },
  player() { return state.crew.find(m => m.isPlayer); },
  crewCount() { return state.crew.length; },
  freeCars() { return state.cars.filter(c => !c.companionId).length; },
  crewById(id) { return state.crew.find(m => m.id === id) || null; },
  busy(id) { return state.innerFarm.active && state.innerFarm.workerId === id; },
  hasActiveTrait(key) { return state.crew.some(m => !this.busy(m.id) && m.trait === key); },

  // ---- 무기 ----
  equippedWeapon() { return state.weapons.find(w => w.id === state.weaponId) || null; },
  attackStats() {
    const C = CONFIG.explore, w = this.equippedWeapon(), def = w ? DATA.weapons[w.key] : null;
    let range = def ? def.range : C.attackRange, dmg = def ? def.dmg : 1;
    let angle = def ? (def.angle || C.attackAngle) : C.attackAngle;   // 부채꼴 반각(도)
    const pl = this.player();
    if (pl && pl.trait === 'brawler') { dmg += 1; range *= 1.15; angle += 10; }   // 강한 공격력 특성 가산
    return { range, dmg, angle, weapon: w };
  },

  // ---- 인벤토리(탐험 휴대) ----
  equippedBag() { const k = state.equip && state.equip.bag; return k ? DATA.items[k] : null; },
  equippedCloth() { const k = state.equip && state.equip.cloth; return k ? DATA.items[k] : null; },
  // 자물쇠 따기 가능(제작전문가의 공구 또는 열쇠공의 솜씨), 열쇠공이면 더 빠름
  canPickLocks() { return this.hasActiveTrait('crafting') || this.hasActiveTrait('locksmith'); },
  invCapacity() { const b = this.equippedBag();
    return CONFIG.inv.baseCap + (b ? b.cap : 0) + (this.hasActiveTrait('porter') ? CONFIG.inv.porterBonus : 0); },
  invWeight() { return state.inventory.reduce((a, s) => a + (DATA.items[s.key] ? DATA.items[s.key].weight * s.n : 0), 0); },
  invSpace() { return Math.max(0, this.invCapacity() - this.invWeight()); },
  invCount(key) { const s = state.inventory.find(x => x.key === key); return s ? s.n : 0; },
  // 무게 한도 내에서 가능한 만큼 담기 → 실제 담은 수량 반환
  invAdd(key, n) {
    const def = DATA.items[key]; if (!def) return 0;
    let take = n;
    if (def.weight > 0) take = Math.min(n, Math.floor((this.invSpace() + 1e-6) / def.weight));
    take = Math.max(0, take);
    if (take <= 0) return 0;
    const s = state.inventory.find(x => x.key === key);
    if (s) s.n += take; else state.inventory.push({ key, n: take });
    return take;
  },
  invRemove(key, n) {
    const s = state.inventory.find(x => x.key === key); if (!s) return 0;
    const rem = Math.min(s.n, n); s.n -= rem;
    if (s.n <= 0) state.inventory = state.inventory.filter(x => x !== s);
    return rem;
  },
  // 가방/옷 장착(인벤토리에서 슬롯으로, 기존 장착품은 인벤토리로 되돌림)
  equipItem(key) {
    const def = DATA.items[key]; if (!def || (def.kind !== 'bag' && def.kind !== 'cloth')) return false;
    if (this.invCount(key) <= 0) return false;
    const slot = def.kind === 'bag' ? 'bag' : 'cloth';
    this.invRemove(key, 1);
    const prev = state.equip[slot];
    state.equip[slot] = key;
    if (prev) state.inventory.push({ key: prev, n: 1 });   // 되돌림(무게 무관 — 즉시 보유)
    return true;
  },
  unequip(slot) { const k = state.equip[slot]; if (!k) return; state.equip[slot] = null; state.inventory.push({ key: k, n: 1 }); },
  // 휴대한 자원 아이템을 비축(res)으로 적재 — 적재한 항목 요약 반환
  stashResources() {
    const gained = {};
    state.inventory = state.inventory.filter(s => {
      const def = DATA.items[s.key];
      if (def && def.kind === 'res') {
        const amt = def.amount * s.n;
        if (CONFIG.max[def.res] != null) state.res[def.res] = U.clamp((state.res[def.res] || 0) + amt, 0, CONFIG.max[def.res]);
        else state.res[def.res] = (state.res[def.res] || 0) + amt;
        gained[def.res] = (gained[def.res] || 0) + amt;
        return false;   // 인벤토리에서 제거
      }
      return true;       // 가방/옷 등은 유지
    });
    return gained;
  },

  // 현재/특정 거리의 바이옴
  biomeKeyAt(km) {
    const seq = (state && state.route && state.route.length) ? state.route : DATA.biomeSequence;
    let i = Math.floor(km / DATA.segmentKm) % seq.length;
    if (i < 0) i += seq.length;
    return seq[i];
  },
  currentBiomeKey() { return state.stranded ? 'wasteland' : this.biomeKeyAt(state.distanceKm); },
  // 탐험에 동행해 기차 밖에 나가 있는 동료(기차 방어 보너스 제외용)
  _outExploring(m) { return state.mode === 'explore' && this.isFollowing(m); },

  // 특성 효과 합산(내부농사로 바쁜 인원 제외)
  effects() {
    const e = { lootSuccessBonus: 0, farmYieldMul: 1, farmSpeedMul: 1,
      repairCostMul: 1, durRegenPerSec: 0, infectionResistMul: 1, fuelEffMul: 1,
      mentalRecoverBonus: 0, canBuildOuter: false, trainDefenseMul: 1 };
    for (const m of state.crew) {
      if (this.busy(m.id)) continue;
      switch (m.trait) {
        case 'survival':  e.lootSuccessBonus = Math.max(e.lootSuccessBonus, CONFIG.loot.survivalBonus); break;
        case 'farming':   e.farmYieldMul *= 1.6; e.farmSpeedMul *= 1.4; e.canBuildOuter = true; break;
        case 'crafting':  e.repairCostMul *= 0.8; e.durRegenPerSec += 0.4; e.canBuildOuter = true; break;
        case 'research':  e.infectionResistMul *= CONFIG.infection.researchResist; e.fuelEffMul *= 0.82; break;
        case 'furniture': e.mentalRecoverBonus += CONFIG.mental.furnitureBonus; e.farmYieldMul *= 1.1; e.canBuildOuter = true; break;
        // 탐험형 특성: 동료가 기차에 남아 있을 때만 기차 방어에 기여(탐험에 동행하면 빠짐)
        case 'brawler':   if (!m.isPlayer && !this._outExploring(m)) e.trainDefenseMul *= 0.85; break;
        case 'tough':     if (!m.isPlayer && !this._outExploring(m)) e.trainDefenseMul *= 0.90; break;
        case 'swift':     if (!m.isPlayer && !this._outExploring(m)) e.trainDefenseMul *= 0.95; break;
      }
    }
    return e;
  },

  // ---- 날씨(전역): 맑음 ↔ 비 ↔ 폭염 ----
  tickWeather(dt) {
    const W = CONFIG.weather, w = state.weather; if (!w) return;
    if (w.raining !== undefined && w.kind === undefined) w.kind = w.raining ? 'rain' : 'clear';   // 구버전 호환
    w.t -= dt;
    if (w.t <= 0) {   // 다음 날씨로 전환
      if (w.kind !== 'clear') { w.kind = 'clear'; w.target = 0; w.t = W.minClearSec + Math.random()*(W.maxClearSec-W.minClearSec); }
      else { const r = Math.random();
        if (r < W.rainChance) { w.kind = 'rain'; w.target = 0.45 + Math.random()*0.55; w.t = W.minRainSec + Math.random()*(W.maxRainSec-W.minRainSec); }
        else if (r < W.rainChance + W.heatChance) { w.kind = 'heat'; w.target = 0.5 + Math.random()*0.5; w.t = W.minHeatSec + Math.random()*(W.maxHeatSec-W.minHeatSec); }
        else { w.target = 0; w.t = W.minClearSec*0.6 + Math.random()*W.maxClearSec*0.4; } }
    }
    const beforeKind = w._shown || 'clear';
    w.intensity = (w.intensity < w.target) ? Math.min(w.target, w.intensity + W.rampPerSec*dt)
                                           : Math.max(w.target, w.intensity - W.rampPerSec*dt);
    const nowKind = w.intensity > 0.04 ? w.kind : 'clear';
    if (nowKind !== beforeKind) {
      if (nowKind === 'rain') UI.toast('🌧️ 비가 내립니다 — 비를 맞으면 체온이 떨어집니다(옷·실내로 보온)');
      else if (nowKind === 'heat') UI.toast('🥵 폭염이 시작됩니다 — 더위로 체온이 오릅니다(두꺼운 옷은 오히려 위험)');
      else UI.toast('⛅ 날이 갰습니다');
      w._shown = nowKind;
    }
  },
  weatherKind() { const w = state.weather; if (!w) return 'clear'; return w.intensity > 0.04 ? (w.kind || 'clear') : 'clear'; },

  // 감염·체온 상태에 따른 경고 말풍선 문구(없으면 null)
  _warnMsg(m) {
    const W = CONFIG.temp;
    if (m.temp <= W.coldHpBelow) return U.pick(['이가 덜덜 떨린다…','손발이 곱는다…','너무 추워… 위험해']);
    if (m.infected) {
      const inf = m.infection;
      if (inf >= 95) return '더는… 못 버티겠어…';
      if (inf >= 75) return U.pick(['정신이 혼미하다…','눈앞이 흐릿하다…','갈증이 가시질 않아']);
      if (inf >= 50) return U.pick(['속이 메스껍다…','상처가 욱신거린다','식은땀이 흐른다']);
      if (inf >= 25) return U.pick(['열이 나는 것 같다','관절이 쑤신다','오한이 든다']);
      return U.pick(['몸이 으슬으슬 춥다','어쩐지 어지럽다…']);
    }
    if (m.temp < W.coldWarnBelow) return U.pick(['몸이 으슬으슬 춥다','비에 젖어 춥다…','따뜻한 곳이 필요해']);
    if (m.temp > W.feverWarnAbove) return U.pick(['너무 덥다…','열이 펄펄 끓는다','어질어질하다']);
    return null;
  },

  /* ---- 개인별 크루 시뮬 (기차/탐험 공용) ---- */
  updateCrew(dt, night) {
    const r = state.res, eff = this.effects(), N = CONFIG.needs, MN = CONFIG.mental, INF = CONFIG.infection, W = CONFIG.temp;
    const recover = MN.recoverPerSec + eff.mentalRecoverBonus;
    const weather = state.weather || { intensity: 0 };
    const exposedNow = !!state._exposed;   // 플레이어/동행이 실외(비·추위)에 노출됐는지
    const deaths = [];
    for (const m of state.crew) {
      // 비·추위 노출은 탐험에 나가 있는 인원(본인·동행)에게만 적용 — 기차에 남은 동료는 보호됨
      const exposed = exposedNow && state.mode === 'explore' && (m.isPlayer || this.isFollowing(m));
      if (m.hurtFlash) m.hurtFlash = Math.max(0, m.hurtFlash - dt);   // 피격 강조 타이머(탐험 상태창 강조)
      // 배고픔/식량
      if (r.food > 0 && m.hunger > 1) { m.hunger = Math.max(0, m.hunger - N.hungerRecover*dt); r.food = Math.max(0, r.food - N.foodPerCrewSec*dt); }
      else m.hunger = Math.min(100, m.hunger + N.hungerRise*dt);
      // 목마름/물
      if (r.water > 0 && m.thirst > 1) { m.thirst = Math.max(0, m.thirst - N.thirstRecover*dt); r.water = Math.max(0, r.water - N.waterPerCrewSec*dt); }
      else m.thirst = Math.min(100, m.thirst + N.thirstRise*dt);
      // 감염 진행
      if (m.infected) m.infection = Math.min(100, m.infection + INF.risePerSec*eff.infectionResistMul*dt);

      // 체온: 비/밤=하강, 폭염=상승. 옷(본인)으로 완화, 감염은 발열. 변화는 서서히.
      if (m.temp == null) m.temp = W.normal;
      const kind = (weather.intensity > 0.05) ? (weather.kind || 'clear') : 'clear';
      const cloth = m.isPlayer ? this.equippedCloth() : null;   // 옷은 본인(차장)에게 적용
      const warmth = cloth ? (cloth.warmth || 0) : 0;
      let target = W.normal;
      if (exposed) {
        if (kind === 'rain') { const resist = cloth && cloth.rain ? cloth.rain : 0; target -= W.rainChill*weather.intensity*(1-resist); }
        else if (kind === 'heat') target += W.heatRise*weather.intensity + warmth*W.clothHeatFactor;   // 폭염+옷 = 더 더움
        if (night && kind !== 'heat') target -= W.nightChill;
      }
      if (target < W.normal && warmth > 0) target = Math.min(W.normal, target + warmth);   // 보온: 추위 상쇄
      if (m.infected) target += W.feverMax*(m.infection/100);
      const goingHot = target > m.temp;
      let rate = goingHot ? (kind === 'heat' && exposed ? W.heatRate : W.shelterWarmRate)
                          : (exposed ? W.coolRate : W.warmRate);
      if (m.trait === 'steady') rate *= W.steadyMul;   // 안정형 체온: 변화가 느림
      m.temp = goingHot ? Math.min(target, m.temp + rate*dt) : Math.max(target, m.temp - rate*dt);
      m.temp = U.clamp(m.temp, W.min, W.max);
      let tempMd = 0, tempHpd = 0;
      if (m.temp < W.coldWarnBelow) tempMd += W.mentalPenaltyCold;
      if (m.temp <= W.coldHpBelow) tempHpd += W.hpDrainCold;
      if (m.temp >= W.feverHpAbove) { tempHpd += W.hpDrainFever; tempMd += W.mentalPenaltyCold; }

      // 멘탈
      let md = MN.decayPerSec + tempMd;
      if (m.hunger > 70 || m.thirst > 70) md += MN.needPenalty;
      if (m.infected) md += MN.infectPenalty;
      if (night) md += MN.nightPenalty;
      if (m.hunger < 50 && m.thirst < 50) md -= recover;
      m.mental = U.clamp(m.mental - md*dt, 0, 100);
      // 체력
      let hpd = tempHpd;
      if (m.hunger >= 100 || m.thirst >= 100) hpd += N.starveHpPerSec;
      if (m.infection >= INF.drainAbove) hpd += INF.hpDrainPerSec;
      if (m.mental <= 0) hpd += 0.3;
      if (hpd > 0) m.hp = U.clamp(m.hp - hpd*dt, 0, 100);
      else if (m.hunger < 50 && m.thirst < 50 && m.infection < 5) m.hp = U.clamp(m.hp + N.hpRecoverPerSec*dt, 0, 100);
      if (m.infection >= INF.turnAt) m.hp = 0;

      // 경고 말풍선(가끔) — 감염 진행/저체온/발열을 상태창 옆에 알림
      if (m._bubbleT > 0) m._bubbleT -= dt;
      m._warnT = (m._warnT == null) ? (3 + Math.random()*6) : m._warnT - dt;
      if (m._warnT <= 0) {
        m._warnT = INF.warnIntervalMin + Math.random()*(INF.warnIntervalMax - INF.warnIntervalMin);
        const msg = this._warnMsg(m);
        if (msg) { m._bubble = msg; m._bubbleT = 3.4; }
      }

      if (m.hp <= 0) deaths.push(m);
    }
    for (const d of deaths) this._die(d);
  },

  _die(m) {
    if (m.hp > 0) return;
    if (m.isPlayer) { if (!state.over) Game.gameOver(m.infection >= CONFIG.infection.turnAt ? 'turned' : 'crew'); return; }
    // 동료 사망: 칸 비우고 제거, 전원 멘탈 타격
    const car = state.cars.find(c => c.companionId === m.id); if (car) car.companionId = null;
    if (state.innerFarm.workerId === m.id) { state.innerFarm.active = false; state.innerFarm.workerId = null; }
    state.crew = state.crew.filter(x => x.id !== m.id);
    for (const o of state.crew) o.mental = U.clamp(o.mental - CONFIG.mental.deathHit, 0, 100);
    UI.toast(`💀 ${m.name} 사망 — 남은 동료의 멘탈이 흔들립니다`);
  },

  // ---- 저장/로드 ----
  save() {
    try {
      const copy = JSON.parse(JSON.stringify(state)); copy.explore = null; copy._idSeq = _idSeq;
      localStorage.setItem(CONFIG.save.key, JSON.stringify(copy));
    } catch (e) {}
  },
  load() {
    try {
      const raw = localStorage.getItem(CONFIG.save.key); if (!raw) return false;
      const data = JSON.parse(raw); _idSeq = data._idSeq || 1; delete data._idSeq;
      data.mode = 'train'; data.explore = null;
      // 구버전 호환 최소 방어
      if (!data.crew || !data.res || data.res.water == null) return false;
      if (!data.weapons) data.weapons = [];           // 구버전 세이브 호환
      if (data.weaponId === undefined) data.weaponId = null;
      if (data.lastStopKm === undefined) data.lastStopKm = null;
      if (data.seed == null) data.seed = Math.floor(Math.random()*0x7fffffff);   // 구버전: 시드/노선 보강
      if (!data.route || !data.route.length) data.route = this._genRoute();
      if (!data.weather) data.weather = { kind:'clear', intensity:0, target:0, t:60 };   // 날씨/체온 보강
      if (data.weather.kind == null) data.weather.kind = data.weather.raining ? 'rain' : 'clear';
      data._exposed = false;
      if (!Array.isArray(data.inventory)) data.inventory = [];     // 인벤토리/장착 보강
      if (!data.equip) data.equip = { bag:null, cloth:null };
      for (const m of data.crew) { if (m.temp == null) m.temp = CONFIG.temp.normal; if (m._warnT == null) m._warnT = 4 + Math.random()*6; if (m._bubbleT == null) m._bubbleT = 0; }
      state = data; return true;
    } catch (e) { return false; }
  },
  reset() { try { localStorage.removeItem(CONFIG.save.key); } catch (e) {} state = State.fresh(); },
};
