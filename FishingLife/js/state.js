/* =========================================================================
   FishingLife - Game State + Save/Load (localStorage)
   ========================================================================= */
(function () {
  "use strict";
  const SAVE_KEY = "fishinglife_save_v1";

  function freshState() {
    return {
      version: 1,
      gold: 50,
      // calendar
      day: 1,
      season: "spring",
      time: "morning",       // morning -> day -> evening -> night
      weather: "sunny",
      // progression
      rodTier: 1,
      boatTier: 0,
      location: "pond",
      unlockedLocations: ["town", "pond", "river"],
      // gear / consumables
      currentBait: "worm",
      baits: { worm: 20 },              // baitId -> count
      materials: { worm: 5, bread: 3 }, // matId -> count
      // inventory of caught fish (each entry = a fish instance)
      inventory: [],   // {id, name, emoji, rarity, value, size, weight, season}
      // collection log: fishId -> {count, maxSize}
      caughtLog: {},
      // traps placed: {trapId, loc, placedTurn, contents:[fishInstance]}
      traps: [],
      ownedTraps: {},  // trapId -> count owned (not placed)
      digSlots: {},    // locId -> "day-time" slot last dug (worm digging cooldown)
      // house & aquarium
      hasHouse: false,
      aquariums: [],   // [{id, slots, fish:[fishInstance]}]
      // quests
      quests: [],          // active quests
      questBoard: [],      // available quests on the board
      questBoardAt: 0,     // timestamp the board was generated (for 30-min reset)
      questsDone: 0,
      questSeed: 1,
      // stats
      totalCaught: 0,
      totalEarned: 0,
      bestValue: 0,
      // settings / meta
      seenIntro: false,
    };
  }

  const State = {
    s: freshState(),

    reset() {
      this.s = freshState();
      this.save();
    },

    load() {
      try {
        const raw = localStorage.getItem(SAVE_KEY);
        if (!raw) return false;
        const parsed = JSON.parse(raw);
        // shallow merge over fresh to tolerate older saves
        this.s = Object.assign(freshState(), parsed);
        // migration: ensure the downtown is always reachable
        if (!this.s.unlockedLocations.includes("town")) this.s.unlockedLocations.unshift("town");
        return true;
      } catch (e) {
        console.warn("save load failed", e);
        return false;
      }
    },

    save() {
      try {
        localStorage.setItem(SAVE_KEY, JSON.stringify(this.s));
      } catch (e) {
        console.warn("save failed", e);
      }
    },

    // ---- helpers -------------------------------------------------------
    addGold(n) {
      this.s.gold += n;
      if (n > 0) this.s.totalEarned += n;
      this.save();
    },
    spend(n) {
      if (this.s.gold < n) return false;
      this.s.gold -= n;
      this.save();
      return true;
    },
    hasMaterials(recipe) {
      return Object.keys(recipe).every(k => (this.s.materials[k] || 0) >= recipe[k]);
    },
    consumeMaterials(recipe) {
      Object.keys(recipe).forEach(k => { this.s.materials[k] -= recipe[k]; });
    },
    addMaterial(id, n = 1) {
      this.s.materials[id] = (this.s.materials[id] || 0) + n;
    },
    addBait(id, n) {
      this.s.baits[id] = (this.s.baits[id] || 0) + n;
    },

    // record a caught fish instance into inventory + log
    recordCatch(fish) {
      this.s.inventory.push(fish);
      this.s.totalCaught += 1;
      const log = this.s.caughtLog[fish.id] || { count: 0, maxSize: 0 };
      log.count += 1;
      log.maxSize = Math.max(log.maxSize, fish.size);
      this.s.caughtLog[fish.id] = log;
      if (fish.value > this.s.bestValue) this.s.bestValue = fish.value;
      this.save();
    },
  };

  window.State = State;
})();
