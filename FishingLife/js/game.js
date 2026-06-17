/* =========================================================================
   FishingLife - Game coordinator: world clock, catches, traps, quests, init
   ========================================================================= */
(function () {
  "use strict";

  const TIME_ORDER = ["morning", "day", "evening", "night"];
  const DAYS_PER_SEASON = 7;

  const WEATHER_TABLE = {
    spring: [["sunny", 45], ["cloudy", 30], ["rain", 25]],
    summer: [["sunny", 55], ["cloudy", 20], ["rain", 25]],
    fall:   [["sunny", 40], ["cloudy", 35], ["rain", 25]],
    winter: [["sunny", 35], ["cloudy", 25], ["snow", 40]],
  };

  const QUEST_RESET_MS = 30 * 60 * 1000;   // board refreshes every 30 minutes (real time)
  const AUTO_TIME_MS = 10 * 60 * 1000;     // real time for one period to pass (아침→낮 등)
  const AUTO_RETRY_MS = 20 * 1000;         // if busy (낚시/메뉴), retry shortly instead

  const Game = {
    QUEST_RESET_MS,
    _timeTimer: null,
    _lastTimeAt: 0,    // wall-clock ms of the last time-of-day advance
    init() {
      const loaded = State.load();
      World.init(document.getElementById("scene"));
      UI.init();
      // generate the board if empty, otherwise honour the saved 30-min timer
      if (!State.s.questBoard || !State.s.questBoard.length) this.genQuestBoard();
      else this.maybeResetQuestBoard();
      this.syncSeason();
      UI.refreshAll();

      if (!loaded || !State.s.seenIntro) {
        State.s.seenIntro = true; State.save();
        setTimeout(() => {
          UI.toast("🎣 낚시생활에 오신 걸 환영해요! 방향키(또는 화면 버튼)로 캐릭터를 움직이세요.", "good");
        }, 400);
        setTimeout(() => {
          UI.toast("💡 물가로 가서 Space로 낚싯대를 던져요! 입질이 오면 Space로 챔질, 끌어올릴 땐 Space를 꾹! (모든 낚시는 Space) 🪧이동표지·🗺️지도로 🏙️도심지에 가면 🏪상점·🏢부동산이 있어요.", "info");
        }, 3400);
      } else {
        UI.toast(`다시 오신 걸 환영해요! (${DATA.SEASON_LABEL[State.s.season]} ${State.s.day}일차)`, "info");
      }

      // header buttons
      const dz = document.getElementById("danger-reset");
      if (dz) dz.addEventListener("click", () => {
        if (confirm("정말 처음부터 다시 시작할까요? 모든 진행이 사라져요.")) {
          State.reset(); location.reload();
        }
      });

      // time flows on its own (~10 min per period); the ⏭️ button skips ahead
      this._lastTimeAt = Date.now();
      this.scheduleAutoTime();
    },

    // ---- automatic time-of-day flow ------------------------------------
    _setTimeTimer(ms) {
      if (this._timeTimer) clearTimeout(this._timeTimer);
      this._timeTimer = setTimeout(() => this.autoTick(), ms);
    },
    scheduleAutoTime() { this._setTimeTimer(AUTO_TIME_MS); },

    // fired ~every 10 min: let the day advance on its own, but never interrupt
    // an active catch or an open menu — wait a bit and try again instead.
    autoTick() {
      const busy = window.World && (World.mode === "fishing" || World.isModalOpen());
      if (busy) { this._setTimeTimer(AUTO_RETRY_MS); return; }
      this.advanceTime();   // advanceTime() reschedules the next auto tick
    },

    // ⏭️ button: skip ahead by however much real time has actually elapsed
    // since the last advance (10 min = one period), at least one period.
    skipTime() {
      const elapsed = Date.now() - (this._lastTimeAt || Date.now());
      let steps = Math.floor(elapsed / AUTO_TIME_MS);
      steps = Math.max(1, Math.min(8, steps));   // at least 1, cap runaway skips
      for (let i = 0; i < steps; i++) this.advanceTime();
    },

    // ---- on catch ------------------------------------------------------
    onCatch(inst, fishDef) {
      const isNew = !State.s.caughtLog[inst.id];
      State.recordCatch(inst);
      UI.showCatch(inst, isNew);
      UI.refreshTopbar();

      // material drops
      this.rollMaterialDrop(inst);

      // quest progress nudge
      const q = State.s.quests.find(qq => qq.fishId === inst.id);
      if (q) {
        const have = UI.countFish(q.fishId);
        if (have <= q.count) UI.toast(`📜 의뢰 진행: ${q.fishName} ${have}/${q.count}`, "info");
        else UI.toast(`📜 ${q.fishName} 충분히 모았어요! 의뢰 게시판에서 납품하세요.`, "good");
      }
    },

    rollMaterialDrop(inst) {
      if (inst.junk) {
        if (inst.id === "treasure") { State.addMaterial("pearl", 1); UI.toast("💰 보물상자에서 ⚪진주를 발견!", "good"); State.save(); }
        return;
      }
      const loc = State.s.location;
      const drops = [];
      if (Math.random() < 0.30) { State.addMaterial("fishmeal", 1); drops.push("🍣생선살"); }
      if (loc === "cave" && Math.random() < 0.30) { State.addMaterial("glowmoss", 1); drops.push("🟢발광이끼"); }
      if ((loc === "sea" || loc === "moon") && Math.random() < 0.06) { State.addMaterial("pearl", 1); drops.push("⚪진주"); }
      if (drops.length) { State.save(); UI.toast(`재료 획득: ${drops.join(" ")}`, "info"); }
    },

    // ---- world clock ---------------------------------------------------
    advanceTime() {
      const s = State.s;
      const idx = TIME_ORDER.indexOf(s.time);
      if (idx === TIME_ORDER.length - 1) {
        // new day
        s.time = "morning";
        s.day += 1;
        this.syncSeason();
        s.weather = this.rollWeather();
        UI.toast(`☀️ ${s.day}일차 아침이 밝았어요 · ${DATA.SEASON_LABEL[s.season]} · ${DATA.WEATHER_LABEL[s.weather]}`, "info");
      } else {
        s.time = TIME_ORDER[idx + 1];
        // small chance weather shifts during the day
        if (Math.random() < 0.25) s.weather = this.rollWeather();
        UI.toast(`🕐 ${DATA.TIME_LABEL[s.time]}이(가) 되었어요.`, "info");
      }
      this.fillTraps();
      // any active fishing ends when time passes
      if (World.mode === "fishing") { Fishing.cancel(); World.exitFishing(); }
      // moon beach closes if it's no longer night
      if (s.location === "moon" && s.time !== "night") {
        s.location = "sea";
        World.enterLocation("sea");
        UI.toast("🌙 달빛 해변이 사라져 바다로 돌아왔어요.", "warn");
      }
      State.save();
      UI.refreshAll();
      if (UI.currentPanel) UI.rerender();
      // stamp this advance & restart the 10-min countdown for the next period
      this._lastTimeAt = Date.now();
      this.scheduleAutoTime();
    },

    syncSeason() {
      const idx = Math.floor((State.s.day - 1) / DAYS_PER_SEASON) % 4;
      State.s.season = DATA.SEASONS[idx];
    },

    rollWeather() {
      const table = WEATHER_TABLE[State.s.season];
      const total = table.reduce((a, b) => a + b[1], 0);
      let r = Math.random() * total;
      for (const [w, wt] of table) { r -= wt; if (r <= 0) return w; }
      return "sunny";
    },

    // ---- traps ---------------------------------------------------------
    fillTraps() {
      State.s.traps.forEach(t => {
        const def = DATA.TRAPS.find(d => d.id === t.trapId);
        let added = 0;
        while (t.contents.length < def.capacity && added < 2 && Math.random() < 0.65) {
          const f = this.pickTrapFish(t.loc);
          if (f) { t.contents.push(Fishing.makeInstance(f)); added++; }
          else break;
        }
      });
    },

    pickTrapFish(locId) {
      // traps catch what lives there; bias to common, no rod/season gating, fewer legendaries
      const list = DATA.FISH.filter(f => f.loc.includes(locId) && f.rarity !== "legendary");
      if (!list.length) return null;
      const weighted = list.map(f => {
        let w = DATA.RARITY[f.rarity].weight;
        if (f.rarity === "epic") w *= 0.3;
        if (f.junk) w *= 0.8;
        return { f, w };
      });
      const total = weighted.reduce((a, b) => a + b.w, 0);
      let r = Math.random() * total;
      for (const it of weighted) { r -= it.w; if (r <= 0) return it.f; }
      return list[0];
    },

    // ---- quests --------------------------------------------------------
    genQuestBoard() {
      State.s.questBoard = [this.genQuest(), this.genQuest(), this.genQuest()];
      State.s.questBoardAt = Date.now();
      State.save();
    },

    // ms remaining until the board may reset (0 = ready now)
    questResetRemaining() {
      const elapsed = Date.now() - (State.s.questBoardAt || 0);
      return Math.max(0, QUEST_RESET_MS - elapsed);
    },

    // auto-reset the board when 30 minutes have passed; returns true if reset
    maybeResetQuestBoard() {
      if (this.questResetRemaining() <= 0) { this.genQuestBoard(); return true; }
      return false;
    },

    // player-triggered refresh (only allowed once the timer is up)
    tryRefreshBoard() {
      if (this.maybeResetQuestBoard()) { UI.toast("📜 새로운 의뢰가 게시되었어요!", "good"); return true; }
      const m = Math.ceil(this.questResetRemaining() / 60000);
      UI.toast(`아직 새 의뢰가 없어요. 약 ${m}분 뒤에 갱신돼요.`, "info");
      return false;
    },

    genQuest() {
      const s = State.s;
      // candidate fish: live in an unlocked location, catchable with current rod, not junk, not legendary
      const cands = DATA.FISH.filter(f =>
        !f.junk && f.rarity !== "legendary" &&
        f.loc.some(l => s.unlockedLocations.includes(l)) &&
        (!f.minRod || s.rodTier >= f.minRod)
      );
      const f = cands[Math.floor(Math.random() * cands.length)] || DATA.fishById("carp");
      const rarityCount = { common: [3, 6], uncommon: [2, 4], rare: [2, 3], epic: [1, 2] };
      const [lo, hi] = rarityCount[f.rarity] || [2, 4];
      const count = lo + Math.floor(Math.random() * (hi - lo + 1));
      const mult = 1.6 + Math.random() * 0.7;
      const reward = Math.round(f.value * count * mult / 5) * 5;
      const giver = DATA.QUEST_GIVERS[Math.floor(Math.random() * DATA.QUEST_GIVERS.length)];
      const matReward = Math.random() < 0.3 ? ["herb", "shrimp", "bread"][Math.floor(Math.random() * 3)] : null;
      return {
        id: "q" + (s.questSeed++),
        giver: giver.name, giverEmoji: giver.emoji,
        fishId: f.id, fishName: f.name, emoji: f.emoji,
        count, reward, matReward,
      };
    },
  };

  window.Game = Game;
  window.addEventListener("DOMContentLoaded", () => Game.init());
})();
