/* =========================================================================
   FishingLife - Actions: all the button-driven economy/inventory logic.
   Each returns after updating State + UI.
   ========================================================================= */
(function () {
  "use strict";

  const ok = (m) => UI.toast(m, "good");
  const no = (m) => UI.toast(m, "warn");

  const Actions = {
    // ---- selling -------------------------------------------------------
    sellOne(id) {
      const i = State.s.inventory.findIndex(f => f.id === id);
      if (i < 0) return;
      const f = State.s.inventory.splice(i, 1)[0];
      State.addGold(f.value);
      ok(`${f.emoji} ${f.name} 판매 +💰${f.value}`);
      UI.rerender();
    },
    sellId(id) {
      const keep = [], sold = [];
      State.s.inventory.forEach(f => (f.id === id ? sold : keep).push(f));
      if (!sold.length) return;
      const sum = sold.reduce((a, b) => a + b.value, 0);
      State.s.inventory = keep;
      State.addGold(sum);
      ok(`${sold[0].emoji} ${sold[0].name} ${sold.length}마리 판매 +💰${sum}`);
      UI.rerender();
    },
    sellJunk() {
      const keep = [], sold = [];
      State.s.inventory.forEach(f => (f.junk ? sold : keep).push(f));
      if (!sold.length) return;
      const sum = sold.reduce((a, b) => a + b.value, 0);
      State.s.inventory = keep; State.addGold(sum);
      ok(`잡동사니 ${sold.length}개 판매 +💰${sum}`);
      UI.rerender();
    },
    sellAll() {
      if (!State.s.inventory.length) return;
      const sum = State.s.inventory.reduce((a, b) => a + b.value, 0);
      const n = State.s.inventory.length;
      State.s.inventory = []; State.addGold(sum);
      ok(`${n}마리 판매 +💰${sum}`);
      UI.rerender();
    },

    // ---- aquarium ------------------------------------------------------
    display(id) {
      const s = State.s;
      if (!s.hasHouse || !s.aquariums.length) return no("아쿠아리움이 필요해요. 집과 어항을 먼저 구입하세요!");
      // find an aquarium with space
      const aq = s.aquariums.find(a => {
        const def = DATA.AQUARIUMS.find(d => d.id === a.id);
        return a.fish.length < def.slots;
      });
      if (!aq) return no("아쿠아리움이 가득 찼어요!");
      const i = s.inventory.findIndex(f => f.id === id);
      if (i < 0) return;
      const f = s.inventory.splice(i, 1)[0];
      aq.fish.push(f);
      State.save();
      ok(`${f.emoji} ${f.name}을(를) 아쿠아리움에 전시했어요!`);
      UI.rerender();
    },
    aquariumRemove(ai, idx) {
      const aq = State.s.aquariums[ai];
      if (!aq) return;
      const f = aq.fish.splice(idx, 1)[0];
      State.s.inventory.push(f);
      State.save();
      UI.toast(`${f.emoji} ${f.name}을(를) 가방으로 옮겼어요`, "info");
      UI.rerender();
    },

    // ---- worm digging (free bait, once per time slot per location) -----
    digWorms() {
      const s = State.s;
      const slot = s.day + "-" + s.time;
      s.digSlots = s.digSlots || {};
      if (s.digSlots[s.location] === slot) {
        return no("이곳은 이미 다 팠어요. ‘시간 보내기’ 후 다시 캘 수 있어요 🪱");
      }
      const n = 1 + Math.floor(Math.random() * 2); // 1~2
      State.addBait("worm", n);
      s.digSlots[s.location] = slot;
      State.save();
      ok(`🪱 흙을 파서 지렁이 ${n}마리를 얻었어요!`);
      UI.refreshTopbar();
    },

    // ---- bait ----------------------------------------------------------
    useBait(id) {
      State.s.currentBait = id;
      State.save();
      ok(`${DATA.BAITS[id].emoji} ${DATA.BAITS[id].name} 장착!`);
      UI.rerender(); UI.refreshTopbar();
    },

    // ---- shop ----------------------------------------------------------
    buyRod(tier) {
      const r = DATA.rodByTier(tier);
      if (State.s.rodTier >= tier) return;
      if (State.s.rodTier !== tier - 1) return no("이전 등급 낚싯대가 필요해요.");
      if (!State.spend(r.cost)) return no("골드가 부족해요.");
      State.s.rodTier = tier; State.save();
      ok(`${r.emoji} ${r.name} 구입!`);
      UI.rerender();
    },
    buyBoat(tier) {
      const b = DATA.boatByTier(tier);
      if (State.s.boatTier >= tier) return;
      if (State.s.boatTier !== tier - 1) return no("이전 등급 배가 필요해요.");
      if (!State.spend(b.cost)) return no("골드가 부족해요.");
      State.s.boatTier = tier; State.save();
      ok(`${b.emoji} ${b.name} 구입! 새로운 지역으로 떠나보세요.`);
      UI.rerender();
    },
    buyWorm() {
      if (!State.spend(40)) return no("골드가 부족해요.");
      State.addBait("worm", 10); State.save();
      ok("🪱 지렁이 미끼 10개 구입!");
      UI.rerender();
    },
    buyMat(id) {
      const m = DATA.MATERIALS[id];
      if (!State.spend(m.buy)) return no("골드가 부족해요.");
      State.addMaterial(id, 1); State.save();
      ok(`${m.emoji} ${m.name} 구입!`);
      UI.rerender();
    },
    buyTrap(id) {
      const t = DATA.TRAPS.find(d => d.id === id);
      if (!State.spend(t.cost)) return no("골드가 부족해요.");
      State.s.ownedTraps[id] = (State.s.ownedTraps[id] || 0) + 1;
      State.save();
      ok(`${t.emoji} ${t.name} 구입! 통발 메뉴에서 설치하세요.`);
      UI.rerender();
    },
    buyHouse() {
      if (State.s.hasHouse) return;
      if (!State.spend(DATA.HOUSE.cost)) return no("골드가 부족해요.");
      State.s.hasHouse = true; State.save();
      ok(`🏡 ${DATA.HOUSE.name} 구입! 이제 아쿠아리움을 지을 수 있어요.`);
      UI.rerender();
    },
    buyAquarium(id) {
      if (State.s.aquariums.some(a => a.id === id)) return;
      const a = DATA.AQUARIUMS.find(d => d.id === id);
      if (!State.spend(a.cost)) return no("골드가 부족해요.");
      State.s.aquariums.push({ id: a.id, fish: [] });
      State.save();
      ok(`${a.emoji} ${a.name} 설치! 집에서 물고기를 전시하세요.`);
      UI.rerender();
    },

    // ---- crafting ------------------------------------------------------
    craft(id) {
      const b = DATA.BAITS[id];
      if (!b.recipe) return;
      if (!State.hasMaterials(b.recipe)) return no("재료가 부족해요.");
      State.consumeMaterials(b.recipe);
      State.addBait(id, b.batch);
      State.save();
      ok(`${b.emoji} ${b.name} ${b.batch}개 제작 완료!`);
      UI.rerender();
    },

    // ---- quests --------------------------------------------------------
    acceptQuest(boardIdx) {
      if (State.s.quests.length >= 4) return no("진행중인 의뢰가 너무 많아요 (최대 4).");
      const q = (State.s.questBoard || [])[boardIdx];
      if (!q) return;
      State.s.quests.push(q);
      State.s.questBoard.splice(boardIdx, 1);
      State.save();
      ok(`📜 의뢰 수락: ${q.fishName} ${q.count}마리`);
      UI.rerender();
    },
    deliverQuest(id) {
      const qi = State.s.quests.findIndex(q => q.id === id);
      if (qi < 0) return;
      const q = State.s.quests[qi];
      const have = UI.countFish(q.fishId);
      if (have < q.count) return no("물고기가 부족해요.");
      // remove the required fish (cheapest first to be kind)
      let removed = 0;
      State.s.inventory.sort((a, b) => a.value - b.value);
      State.s.inventory = State.s.inventory.filter(f => {
        if (f.id === q.fishId && removed < q.count) { removed++; return false; }
        return true;
      });
      State.s.quests.splice(qi, 1);
      State.s.questsDone++;
      State.addGold(q.reward);
      if (q.matReward) State.addMaterial(q.matReward, 2);
      State.save();
      ok(`✅ 의뢰 완료! +💰${q.reward}${q.matReward ? ` +${DATA.MATERIALS[q.matReward].emoji}x2` : ""}`);
      UI.rerender();
    },
    abandonQuest(id) {
      State.s.quests = State.s.quests.filter(q => q.id !== id);
      State.save();
      UI.toast("의뢰를 포기했어요.", "info");
      UI.rerender();
    },

    // ---- traps ---------------------------------------------------------
    placeTrap(id) {
      if ((State.s.ownedTraps[id] || 0) <= 0) return;
      const hasFish = DATA.FISH.some(f => f.loc.includes(State.s.location));
      if (!hasFish) return no("여기엔 물고기가 없어요. 낚시터에서 설치하세요 🪤");
      State.s.ownedTraps[id]--;
      State.s.traps.push({ trapId: id, loc: State.s.location, contents: [] });
      State.save();
      ok(`🪤 ${DATA.locById(State.s.location).name}에 통발을 설치했어요.`);
      UI.rerender();
    },
    collectTrap(i) {
      const t = State.s.traps[i];
      if (!t) return;
      if (!t.contents.length) {
        // pick up empty trap back into inventory
        State.s.ownedTraps[t.trapId] = (State.s.ownedTraps[t.trapId] || 0) + 1;
        State.s.traps.splice(i, 1);
        State.save();
        UI.toast("빈 통발을 회수했어요.", "info");
        UI.rerender();
        return;
      }
      const caught = t.contents;
      caught.forEach(f => State.recordCatch(f));
      const names = caught.map(f => f.emoji).join("");
      // collected trap returns to inventory
      State.s.ownedTraps[t.trapId] = (State.s.ownedTraps[t.trapId] || 0) + 1;
      State.s.traps.splice(i, 1);
      State.save();
      ok(`🪤 통발 수거! ${names} (${caught.length}마리)`);
      UI.rerender();
    },

    // ---- travel --------------------------------------------------------
    travel(id) {
      const loc = DATA.locById(id);
      if (!State.s.unlockedLocations.includes(id)) return;
      if (State.s.boatTier < loc.needsBoat) return no("더 좋은 배가 필요해요.");
      if (id === "moon" && State.s.time !== "night") return no("달빛 해변은 밤에만 열려요.");
      State.s.location = id; State.save();
      ok(`${loc.emoji} ${loc.name}(으)로 이동!`);
      window.World && World.enterLocation(id);
      UI.closePanel(); UI.refreshAll();
    },
    unlock(id) {
      const loc = DATA.locById(id);
      if (State.s.unlockedLocations.includes(id)) return;
      if (State.s.boatTier < loc.needsBoat) return no("먼저 배가 필요해요.");
      if (!State.spend(loc.unlockCost)) return no("골드가 부족해요.");
      State.s.unlockedLocations.push(id); State.save();
      ok(`🗺️ ${loc.name} 해금!`);
      UI.rerender();
    },
  };

  window.Actions = Actions;
})();
