/* =========================================================================
   FishingLife - UI layer: topbar, action button, modal panels, toasts
   ========================================================================= */
(function () {
  "use strict";

  const $ = (sel) => document.querySelector(sel);
  const el = (id) => document.getElementById(id);

  const UI = {
    init() {
      // (action button + movement are handled by World)

      // bottom nav
      document.querySelectorAll("[data-panel]").forEach(b => {
        b.addEventListener("click", () => this.openPanel(b.dataset.panel));
      });

      // time button — skip ahead by the real time elapsed (10 min = one period)
      el("time-btn").addEventListener("click", () => Game.skipTime());

      // bait quick-select
      el("bait-chip").addEventListener("click", () => this.openPanel("bait"));

      // modal close
      el("modal-close").addEventListener("click", () => this.closePanel());
      el("modal").addEventListener("click", (e) => { if (e.target === el("modal")) this.closePanel(); });
      // delegated actions inside modal
      el("modal-body").addEventListener("click", (e) => this.handleModalClick(e));

      this.refreshAll();
    },

    // ---- toasts --------------------------------------------------------
    toast(msg, type = "info") {
      const wrap = el("toasts");
      const t = document.createElement("div");
      t.className = `toast toast-${type}`;
      t.innerHTML = msg;
      wrap.appendChild(t);
      // keep at most 5 on screen — drop the oldest when they pile up
      while (wrap.children.length > 5) wrap.removeChild(wrap.firstChild);
      setTimeout(() => { t.classList.add("show"); }, 10);
      setTimeout(() => { t.classList.remove("show"); setTimeout(() => t.remove(), 300); }, 2600);
    },

    // ---- topbar / action ----------------------------------------------
    refreshAll() {
      this.refreshTopbar();
      this.refreshAction();
    },

    refreshTopbar() {
      const s = State.s;
      el("gold").textContent = s.gold.toLocaleString();
      el("day").textContent = s.day;
      el("season").textContent = DATA.SEASON_LABEL[s.season];
      el("weather").textContent = DATA.WEATHER_LABEL[s.weather];
      el("time").textContent = DATA.TIME_LABEL[s.time];
      const loc = DATA.locById(s.location);
      el("loc-chip").textContent = `${loc.emoji} ${loc.name}`;
      const rod = DATA.rodByTier(s.rodTier);
      const bait = DATA.BAITS[s.currentBait];
      const baitCount = s.baits[s.currentBait] || 0;
      el("rod-chip").textContent = `${rod.emoji} ${rod.name}`;
      el("bait-chip").innerHTML = `${bait.emoji} ${bait.name} <b>x${baitCount}</b>`;
    },

    refreshAction() {
      if (window.World) World._btnKey = "", World.updateActionButton();
    },

    pulseAction() {
      const btn = el("action-btn");
      btn.classList.remove("pulse"); void btn.offsetWidth; btn.classList.add("pulse");
    },

    // ---- catch result card --------------------------------------------
    showCatch(inst, isNew) {
      const r = DATA.RARITY[inst.rarity];
      const card = el("catch-card");
      card.style.setProperty("--rcol", r.color);
      el("catch-emoji").innerHTML = window.FishArt ? `<img src="${FishArt.dataURL(inst.id, 150, 110)}" alt="">` : inst.emoji;
      el("catch-name").textContent = inst.name;
      el("catch-meta").innerHTML =
        `<span style="color:${r.color}">${r.label}</span> · ${inst.size}cm · 💰${inst.value}` +
        (isNew ? ` · <span class="new-tag">NEW!</span>` : "") +
        (inst.junk ? ` · <span class="junk-tag">잡동사니</span>` : "");
      card.classList.remove("hidden", "pop"); void card.offsetWidth; card.classList.add("pop");
      clearTimeout(this._catchTimer);
      this._catchTimer = setTimeout(() => card.classList.add("hidden"), 2400);
    },

    // ---- modal panels --------------------------------------------------
    openPanel(id) {
      this.currentPanel = id;
      const map = {
        inventory: ["🎒 가방", this.panelInventory],
        shop:      ["🏪 상점", this.panelShop],
        estate:    ["🏢 부동산", this.panelEstate],
        craft:     ["⚗️ 미끼 제작", this.panelCraft],
        bait:      ["🪱 미끼 선택", this.panelBait],
        quests:    ["📜 의뢰 게시판", this.panelQuests],
        traps:     ["🪤 통발", this.panelTraps],
        house:     ["🏡 나의 집", this.panelHouse],
        map:       ["🗺️ 지도", this.panelMap],
        log:       ["📖 물고기 도감", this.panelLog],
      };
      const [title, fn] = map[id];
      el("modal-title").textContent = title;
      el("modal-gold").textContent = "💰 " + State.s.gold.toLocaleString();
      el("modal-body").innerHTML = fn.call(this);
      el("modal").classList.remove("hidden");
      this.stopPanelTimer();
      if (id === "quests") this.startQuestTimer();
    },

    closePanel() { el("modal").classList.add("hidden"); this.currentPanel = null; this.stopPanelTimer(); },

    fmtMMSS(ms) { const s = Math.ceil(ms / 1000); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); },
    stopPanelTimer() { if (this._panelTimer) { clearInterval(this._panelTimer); this._panelTimer = null; } },
    startQuestTimer() {
      this._panelTimer = setInterval(() => {
        if (this.currentPanel !== "quests") { this.stopPanelTimer(); return; }
        if (window.Game && Game.maybeResetQuestBoard()) { this.rerender(); return; } // re-renders with new board
        const t = el("quest-timer");
        if (t && window.Game) t.textContent = "⏳ 갱신까지 " + this.fmtMMSS(Game.questResetRemaining());
      }, 1000);
    },

    rerender() { if (this.currentPanel) this.openPanel(this.currentPanel); this.refreshTopbar(); },

    // ===== INVENTORY ====================================================
    panelInventory() {
      const inv = State.s.inventory;
      if (!inv.length) return `<p class="empty">가방이 비었어요. 물고기를 잡아보세요! 🎣</p>`;
      // group by id
      const groups = {};
      inv.forEach((f) => {
        if (!groups[f.id]) groups[f.id] = { f, count: 0, total: 0, max: 0 };
        const g = groups[f.id];
        g.count++; g.total += f.value; g.max = Math.max(g.max, f.size);
      });
      const totalVal = inv.reduce((a, b) => a + b.value, 0);

      let rows = Object.values(groups).sort((a, b) => b.f.value - a.f.value).map(g => {
        const r = DATA.RARITY[g.f.rarity];
        return `<div class="row">
          <div class="row-main">
            ${FishArt.img(g.f.id)}
            <div>
              <div class="row-title">${g.f.name} <span class="badge" style="background:${r.color}22;color:${r.color}">${r.label}</span></div>
              <div class="row-sub">x${g.count} · 최대 ${g.max}cm · 💰${g.total}</div>
            </div>
          </div>
          <div class="row-actions">
            <button class="btn sm ghost" data-act="display" data-id="${g.f.id}">전시</button>
          </div>
        </div>`;
      }).join("");

      return `<div class="bar">
          <div>총 가치 <b>💰${totalVal}</b></div>
          <div class="spacer"></div>
        </div>
        <div class="info-box">물고기는 🏙️ 도심지의 🏪 상점에 가서 팔 수 있어요. (가방에서는 아쿠아리움에 ‘전시’만 가능)</div>
        <div class="list">${rows}</div>`;
    },

    // ===== BAIT SELECT ==================================================
    panelBait() {
      const s = State.s;
      const owned = Object.keys(s.baits).filter(k => s.baits[k] > 0);
      if (!owned.length) return `<p class="empty">미끼가 없어요. 상점에서 구입하거나 제작하세요.</p>`;
      const rows = owned.map(k => {
        const b = DATA.BAITS[k];
        const sel = s.currentBait === k ? "selected" : "";
        return `<div class="row ${sel}">
          <div class="row-main"><span class="big-emoji">${b.emoji}</span>
            <div><div class="row-title">${b.name} <b>x${s.baits[k]}</b></div>
            <div class="row-sub">${b.desc} · 유인력 ${b.power}x</div></div></div>
          <div class="row-actions">
            ${s.currentBait === k ? `<span class="tag-on">사용중</span>` : `<button class="btn sm primary" data-act="use-bait" data-id="${k}">사용</button>`}
          </div></div>`;
      }).join("");
      return `<div class="info-box">유인력이 높은 미끼일수록 입질이 빠르고, <b>희귀·상위 어종이 물 확률</b>도 올라가요.</div><div class="list">${rows}</div>`;
    },

    // ===== SHOP =========================================================
    panelShop() {
      const tabs = ["sell", "rods", "boats", "bait", "traps"];
      const labels = { sell: "💰 판매", rods: "🎣 낚싯대", boats: "⛵ 배", bait: "🪱 미끼/재료", traps: "🪤 통발" };
      const cur = this.shopTab || "sell";
      this.shopTab = cur;
      const tabBar = tabs.map(t =>
        `<button class="tab ${t === cur ? "active" : ""}" data-act="shop-tab" data-id="${t}">${labels[t]}</button>`).join("");
      let body = "";
      if (cur === "sell") return `<div class="tabs">${tabBar}</div>${this.shopSell()}`;
      else if (cur === "rods") body = this.shopRods();
      else if (cur === "boats") body = this.shopBoats();
      else if (cur === "bait") body = this.shopBait();
      else if (cur === "traps") body = this.shopTraps();
      return `<div class="tabs">${tabBar}</div><div class="list">${body}</div>`;
    },

    // sell your catch (only available at the shop)
    shopSell() {
      const inv = State.s.inventory;
      if (!inv.length) return `<p class="empty">팔 물고기가 없어요. 낚시를 다녀오세요! 🎣</p>`;
      const groups = {};
      inv.forEach(f => {
        if (!groups[f.id]) groups[f.id] = { f, count: 0, total: 0, max: 0 };
        const g = groups[f.id]; g.count++; g.total += f.value; g.max = Math.max(g.max, f.size);
      });
      const totalVal = inv.reduce((a, b) => a + b.value, 0);
      const junkVal = inv.filter(f => f.junk).reduce((a, b) => a + b.value, 0);
      const rows = Object.values(groups).sort((a, b) => b.f.value - a.f.value).map(g => {
        const r = DATA.RARITY[g.f.rarity];
        return `<div class="row">
          <div class="row-main">${FishArt.img(g.f.id)}
            <div><div class="row-title">${g.f.name} <span class="badge" style="background:${r.color}22;color:${r.color}">${r.label}</span></div>
            <div class="row-sub">x${g.count} · 최대 ${g.max}cm · 💰${g.total}</div></div></div>
          <div class="row-actions">
            <button class="btn sm" data-act="sell-one" data-id="${g.f.id}">1마리</button>
            <button class="btn sm primary" data-act="sell-id" data-id="${g.f.id}">모두</button>
          </div></div>`;
      }).join("");
      return `<div class="bar"><div>총 가치 <b>💰${totalVal}</b></div><div class="spacer"></div>
          ${junkVal ? `<button class="btn sm" data-act="sell-junk">잡동사니 (💰${junkVal})</button>` : ""}
          <button class="btn sm primary" data-act="sell-all">전부 팔기</button></div>
        <div class="list">${rows}</div>`;
    },

    shopRods() {
      return DATA.RODS.map(r => {
        const owned = State.s.rodTier >= r.tier;
        const using = State.s.rodTier === r.tier;
        const canBuy = State.s.rodTier === r.tier - 1;
        return this.shopRow(r.emoji, r.name, `${r.desc} · 찌 크기·속도 ${r.power}x`, r.cost,
          owned ? (using ? "장착중" : "보유") : (canBuy ? "buy" : "lock"),
          "buy-rod", r.tier);
      }).join("");
    },
    shopBoats() {
      return DATA.BOATS.filter(b => b.tier > 0).map(b => {
        const owned = State.s.boatTier >= b.tier;
        const using = State.s.boatTier === b.tier;
        const canBuy = State.s.boatTier === b.tier - 1;
        return this.shopRow(b.emoji, b.name, b.desc, b.cost,
          owned ? (using ? "사용중" : "보유") : (canBuy ? "buy" : "lock"),
          "buy-boat", b.tier);
      }).join("");
    },
    shopBait() {
      let out = `<div class="sub-h">미끼</div>`;
      out += this.shopRow("🪱", "지렁이 미끼", "가장 기본적인 미끼 (10개 묶음)", 40, "buy", "buy-worm", 1);
      out += `<div class="sub-h">재료 (제작용)</div>`;
      Object.values(DATA.MATERIALS).filter(m => m.buy > 0).forEach(m => {
        out += this.shopRow(m.emoji, m.name, `현재 보유 x${State.s.materials[m.id] || 0}`, m.buy, "buy", "buy-mat", m.id);
      });
      return out;
    },
    shopTraps() {
      return DATA.TRAPS.map(t => {
        const owned = State.s.ownedTraps[t.id] || 0;
        return this.shopRow(t.emoji, t.name, `${t.desc} · 용량 ${t.capacity} · 보유 ${owned}개`, t.cost, "buy", "buy-trap", t.id);
      }).join("");
    },
    // ===== REAL ESTATE (부동산) =========================================
    panelEstate() {
      let out = `<div class="info-box">🏢 부동산 — 집을 사면 도심지에 내 집이 생기고, 아쿠아리움을 지어 잡은 물고기를 키울 수 있어요.</div>`;
      if (!State.s.hasHouse) {
        out += this.shopRow(DATA.HOUSE.emoji, DATA.HOUSE.name, DATA.HOUSE.desc, DATA.HOUSE.cost, "buy", "buy-house", 1);
      } else {
        out += `<div class="info-box">🏡 집을 소유하고 있어요. 아쿠아리움을 구입해 물고기를 키워보세요!</div>`;
        DATA.AQUARIUMS.forEach(a => {
          const owned = State.s.aquariums.some(x => x.id === a.id);
          out += this.shopRow(a.emoji, a.name, `${a.desc} · 칸 ${a.slots}`, a.cost, owned ? "보유" : "buy", "buy-aq", a.id);
        });
      }
      return `<div class="list">${out}</div>`;
    },

    shopRow(emoji, name, desc, cost, status, act, id) {
      let right;
      if (status === "buy") right = `<button class="btn sm primary" data-act="${act}" data-id="${id}">💰${cost.toLocaleString()}</button>`;
      else if (status === "lock") right = `<span class="tag-lock">🔒 이전 등급 필요</span>`;
      else right = `<span class="tag-on">${status}</span>`;
      return `<div class="row">
        <div class="row-main"><span class="big-emoji">${emoji}</span>
          <div><div class="row-title">${name}</div><div class="row-sub">${desc}</div></div></div>
        <div class="row-actions">${right}</div></div>`;
    },

    // ===== CRAFT ========================================================
    panelCraft() {
      const craftable = Object.values(DATA.BAITS).filter(b => b.recipe);
      const rows = craftable.map(b => {
        const free = Object.keys(b.recipe).length === 0;
        const parts = free
          ? `<span class="mat" style="color:var(--accent-2)">🆓 재료 없이 무료 제작</span>`
          : Object.keys(b.recipe).map(k => {
              const m = DATA.MATERIALS[k];
              const have = State.s.materials[k] || 0;
              const ok = have >= b.recipe[k];
              return `<span class="mat ${ok ? "" : "bad"}">${m.emoji}${m.name} ${have}/${b.recipe[k]}</span>`;
            }).join(" ");
        const can = State.hasMaterials(b.recipe);
        return `<div class="row">
          <div class="row-main"><span class="big-emoji">${b.emoji}</span>
            <div><div class="row-title">${b.name} <span class="row-sub">(보유 x${State.s.baits[b.id] || 0})</span></div>
            <div class="row-sub">${b.desc} · 유인력 ${b.power}x · 한번에 ${b.batch}개</div>
            <div class="mats">${parts}</div></div></div>
          <div class="row-actions">
            <button class="btn sm primary" data-act="craft" data-id="${b.id}" ${can ? "" : "disabled"}>제작</button>
          </div></div>`;
      }).join("");
      return `<div class="info-box">🍂 <b>막미끼</b>는 재료 없이 무료로 만들 수 있어요(효과는 약함). 돈·미끼가 없을 때 비상용으로! 좋은 미끼일수록 희귀어가 잘 물려요. 재료는 상점·낚시·통발로 얻어요.</div><div class="list">${rows}</div>`;
    },

    // ===== QUESTS =======================================================
    panelQuests() {
      const s = State.s;
      let active = s.quests.map(q => {
        const have = this.countFish(q.fishId);
        const ok = have >= q.count;
        return `<div class="row">
          <div class="row-main"><span class="big-emoji">${q.giverEmoji}</span>
            <div><div class="row-title">${q.giver}</div>
            <div class="row-sub">${FishArt.img(q.fishId, "fish-mini")} <b>${q.fishName}</b> ${q.count}마리 납품 (${have}/${q.count})</div>
            <div class="row-sub">${this.fishHabitat(q.fishId)}</div>
            <div class="row-sub">보상 💰${q.reward.toLocaleString()}${q.matReward ? ` + ${DATA.MATERIALS[q.matReward].emoji}${DATA.MATERIALS[q.matReward].name}x2` : ""}</div></div></div>
          <div class="row-actions">
            <button class="btn sm primary" data-act="deliver" data-id="${q.id}" ${ok ? "" : "disabled"}>납품</button>
            <button class="btn sm ghost" data-act="abandon" data-id="${q.id}">포기</button>
          </div></div>`;
      }).join("");
      if (!s.quests.length) active = `<p class="empty">진행중인 의뢰가 없어요.</p>`;

      const board = (s.questBoard || []).map((q, i) => {
        return `<div class="row">
          <div class="row-main"><span class="big-emoji">${q.giverEmoji}</span>
            <div><div class="row-title">${q.giver}</div>
            <div class="row-sub">${FishArt.img(q.fishId, "fish-mini")} ${q.fishName} ${q.count}마리 → 💰${q.reward.toLocaleString()}</div>
            <div class="row-sub">${this.fishHabitat(q.fishId)}</div></div></div>
          <div class="row-actions"><button class="btn sm" data-act="accept" data-id="${i}">수락</button></div></div>`;
      }).join("");

      const rem = window.Game ? Game.questResetRemaining() : 0;
      const ready = rem <= 0;
      const refreshCtrl = ready
        ? `<button class="btn sm primary" data-act="refresh-board">🔄 새 의뢰 받기</button>`
        : `<span class="quest-timer" id="quest-timer">⏳ 갱신까지 ${this.fmtMMSS(rem)}</span>`;

      return `<div class="sub-h">진행중 (${s.quests.length}/4) · 완료 ${s.questsDone}건</div>
        <div class="list">${active}</div>
        <div class="bar"><div class="sub-h" style="margin:0">의뢰 게시판</div><div class="spacer"></div>${refreshCtrl}</div>
        <div class="info-box">의뢰 게시판은 <b>30분마다</b> 새로운 의뢰로 갱신돼요.</div>
        <div class="list">${board || `<p class="empty">곧 새 의뢰가 게시돼요.</p>`}</div>`;
    },

    // ===== TRAPS ========================================================
    panelTraps() {
      const s = State.s;
      const placed = s.traps.map((t, i) => {
        const def = DATA.TRAPS.find(d => d.id === t.trapId);
        const loc = DATA.locById(t.loc);
        const contents = t.contents.map(c => c.emoji).join(" ") || "비어있음";
        return `<div class="row">
          <div class="row-main"><span class="big-emoji">🪤</span>
            <div><div class="row-title">${def.name} <span class="row-sub">@ ${loc.emoji}${loc.name}</span></div>
            <div class="row-sub">담긴 물고기 (${t.contents.length}/${def.capacity}): ${contents}</div></div></div>
          <div class="row-actions"><button class="btn sm primary" data-act="collect-trap" data-id="${i}">수거</button></div></div>`;
      }).join("");

      const ownedRows = Object.keys(s.ownedTraps).filter(k => s.ownedTraps[k] > 0).map(k => {
        const def = DATA.TRAPS.find(d => d.id === k);
        return `<div class="row">
          <div class="row-main"><span class="big-emoji">${def.emoji}</span>
            <div><div class="row-title">${def.name} <b>x${s.ownedTraps[k]}</b></div>
            <div class="row-sub">현재 위치(${DATA.locById(s.location).name})에 설치</div></div></div>
          <div class="row-actions"><button class="btn sm" data-act="place-trap" data-id="${k}">설치</button></div></div>`;
      }).join("");

      return `<div class="info-box">통발을 물에 설치하면 시간이 지날수록 물고기가 들어와요. ‘시간 보내기’를 누르며 기다린 뒤 수거하세요.</div>
        <div class="sub-h">설치된 통발</div>
        <div class="list">${placed || `<p class="empty">설치된 통발이 없어요.</p>`}</div>
        <div class="sub-h">보유 통발</div>
        <div class="list">${ownedRows || `<p class="empty">상점에서 통발을 구입하세요.</p>`}</div>`;
    },

    // ===== HOUSE / AQUARIUM ============================================
    panelHouse() {
      const s = State.s;
      if (!s.hasHouse) return `<p class="empty">아직 집이 없어요. 상점 → 부동산에서 집을 구입하세요. 🏡</p>`;
      if (!s.aquariums.length) return `<div class="info-box">🏡 ${DATA.HOUSE.name}에 오신 걸 환영해요!</div><p class="empty">상점에서 아쿠아리움을 구입해 물고기를 전시하세요.</p>`;

      return s.aquariums.map((aq, ai) => {
        const def = DATA.AQUARIUMS.find(a => a.id === aq.id);
        const tank = aq.fish.map((f, fi) => {
          const r = DATA.RARITY[f.rarity];
          return `<div class="tank-fish" title="${f.name} ${f.size}cm" style="border-color:${r.color}">
            ${FishArt.img(f.id, "tank-img")}
            <button class="mini-x" data-act="aq-remove" data-id="${ai}" data-idx="${fi}">✕</button></div>`;
        }).join("");
        const empties = Array.from({ length: def.slots - aq.fish.length }, () => `<div class="tank-fish empty">＋</div>`).join("");
        return `<div class="aquarium">
          <div class="aq-head">${def.emoji} ${def.name} <span class="row-sub">(${aq.fish.length}/${def.slots})</span></div>
          <div class="tank">${tank}${empties}</div>
        </div>`;
      }).join("") + `<div class="info-box">가방에서 물고기를 ‘전시’하면 여기로 옮겨져요. 전시된 물고기는 팔 수 없어요.</div>`;
    },

    // ===== MAP / TRAVEL ================================================
    panelMap() {
      const s = State.s;
      const rows = DATA.LOCATIONS.map(loc => {
        const unlocked = s.unlockedLocations.includes(loc.id);
        const here = s.location === loc.id;
        const boatOk = s.boatTier >= loc.needsBoat;
        const isNight = s.time === "night";
        const moonOk = loc.id !== "moon" || isNight;
        let right;
        if (here) right = `<span class="tag-on">현재 위치</span>`;
        else if (unlocked) {
          if (!boatOk) right = `<span class="tag-lock">🔒 배 등급 필요</span>`;
          else if (!moonOk) right = `<span class="tag-lock">🌙 밤에만</span>`;
          else right = `<button class="btn sm primary" data-act="travel" data-id="${loc.id}">이동</button>`;
        } else {
          right = `<button class="btn sm" data-act="unlock" data-id="${loc.id}" ${s.gold >= loc.unlockCost && boatOk ? "" : "disabled"}>해금 💰${loc.unlockCost.toLocaleString()}</button>`;
        }
        return `<div class="row ${here ? "selected" : ""}">
          <div class="row-main"><span class="big-emoji">${loc.emoji}</span>
            <div><div class="row-title">${loc.name}</div><div class="row-sub">${loc.desc}${loc.needsBoat ? ` · 배 ${loc.needsBoat}등급+` : ""}</div></div></div>
          <div class="row-actions">${right}</div></div>`;
      }).join("");
      return `<div class="info-box">환경마다 잡히는 물고기가 달라요. 계절·날씨·시간대도 영향을 줘요!</div><div class="list">${rows}</div>`;
    },

    // ===== COLLECTION LOG ==============================================
    panelLog() {
      const total = DATA.FISH.filter(f => !f.junk).length;
      const got = DATA.FISH.filter(f => !f.junk && State.s.caughtLog[f.id]).length;
      const rows = DATA.FISH.filter(f => !f.junk).map(f => {
        const log = State.s.caughtLog[f.id];
        const r = DATA.RARITY[f.rarity];
        if (!log) return `<div class="dex unknown"><span>❔</span><div class="dex-name">？？？</div></div>`;
        return `<div class="dex" style="border-color:${r.color}">
          ${FishArt.img(f.id, "fish-img dex-img")}
          <div class="dex-name">${f.name}</div>
          <div class="dex-sub" style="color:${r.color}">${r.label}</div>
          <div class="dex-sub">최대 ${log.maxSize}cm · x${log.count}</div></div>`;
      }).join("");
      return `<div class="info-box">📖 도감 완성도 <b>${got}/${total}</b></div><div class="dex-grid">${rows}</div>`;
    },

    // ---- helpers -------------------------------------------------------
    countFish(id) { return State.s.inventory.filter(f => f.id === id).length; },

    // where a fish can be caught: region(s) + any season/weather/time conditions.
    // Revealed only once you've caught the fish at least once; otherwise "???".
    fishHabitat(id) {
      const f = DATA.fishById(id);
      if (!f) return "";
      if (!State.s.caughtLog[id]) return `📍 <span style="opacity:.7">??? (아직 잡아본 적 없음)</span>`;
      const locs = f.loc.map(l => DATA.locById(l)).filter(Boolean).map(l => `${l.emoji}${l.name}`).join(", ");
      const cond = [];
      if (f.seasons && f.seasons.length) cond.push(f.seasons.map(s => DATA.SEASON_LABEL[s]).join("/"));
      if (f.weathers && f.weathers.length) cond.push(f.weathers.map(w => DATA.WEATHER_LABEL[w]).join("/"));
      if (f.times && f.times.length) cond.push(f.times.map(t => DATA.TIME_LABEL[t]).join("/"));
      return `📍 ${locs}` + (cond.length ? ` <span style="opacity:.8">· ${cond.join(" · ")}</span>` : "");
    },

    // ===== MODAL CLICK ROUTER ==========================================
    handleModalClick(e) {
      const btn = e.target.closest("[data-act]");
      if (!btn) return;
      const act = btn.dataset.act, id = btn.dataset.id, idx = btn.dataset.idx;
      const A = Actions;
      const handlers = {
        "sell-one": () => A.sellOne(id),
        "sell-id": () => A.sellId(id),
        "sell-junk": () => A.sellJunk(),
        "sell-all": () => A.sellAll(),
        "display": () => A.display(id),
        "use-bait": () => A.useBait(id),
        "shop-tab": () => { this.shopTab = id; this.rerender(); },
        "buy-rod": () => A.buyRod(+id),
        "buy-boat": () => A.buyBoat(+id),
        "buy-worm": () => A.buyWorm(),
        "buy-mat": () => A.buyMat(id),
        "buy-trap": () => A.buyTrap(id),
        "buy-house": () => A.buyHouse(),
        "buy-aq": () => A.buyAquarium(id),
        "craft": () => A.craft(id),
        "accept": () => A.acceptQuest(+id),
        "deliver": () => A.deliverQuest(id),
        "abandon": () => A.abandonQuest(id),
        "refresh-board": () => { Game.tryRefreshBoard(); this.rerender(); },
        "place-trap": () => A.placeTrap(id),
        "collect-trap": () => A.collectTrap(+id),
        "aq-remove": () => A.aquariumRemove(+id, +idx),
        "travel": () => A.travel(id),
        "unlock": () => A.unlock(id),
      };
      if (handlers[act]) { handlers[act](); }
    },
  };

  window.UI = UI;
})();
