---
name: skull-skill-design-pref
description: User's preference for how skull (class) skills should be designed by tier and theme
metadata:
  type: feedback
---

For SkulLike, higher-tier skulls (epic/legendary, and rare to a degree) must NOT reuse the same skill as low-tier skulls — especially generic defensive ones like `guard`/`bulwark` (방어 태세/강철 방벽). Each higher-tier class should get a distinctive, flashy, thematically-fitting skill. The user also wants skills to match the class fantasy (e.g. plague doctor = poison gas + contagion, not fire).

**Why:** The user repeatedly flagged epic skulls (기사 해골, 성기사) feeling cheap because their skill was identical to a common squire's, and wanted the skill to express the class identity.

**How to apply:** When adding/reviewing a skull, give epic+ tiers a unique `skill` key with its own case in `_doSkill` (lib/game/world.dart) + painter visual, rather than pointing at an existing low-tier skill. Examples implemented: pyromancer→`firestorm` (big fireball), plagueDoctor→`plague` (poison miasma + contagion-on-poison-death), knight→`swordwave` (piercing crescent), paladin→`swordfall` (sky greatsword AoE). See [[dot-status-death-clamp]].

**Passives are PER-SKULL, never grouped by class.** The user rejected a category-based passive design ("직업군별로 묶어버리면 이상해져"). Each skull has its own signature passive in `kPassives` (lib/game/skulls.dart): `PassiveInfo(name, PassiveKind, value)`, with `passiveDesc()` generating the UI text. Mechanics are wired in world.dart (`_passive` getter, `_passiveAtkMul`, `_critMul`, `_playerOnHit`, `_perkEvade`, armor in `_hurtPlayer`, regenIdle in `_step`, lifesteal at melee sites). Shown in HUD `_passiveRow()` and the skull offer panel. When adding a new skull, ALSO add a `kPassives` entry.
