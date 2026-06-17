---
name: dot-status-death-clamp
description: DoT status effects (poison/burn/bleed) must clamp HP to 0 and mark entity dead
metadata:
  type: project
---

In lib/game/world.dart `_updateStatuses`, all damage-over-time statuses (poison, burn, bleed) subtract from `hp` directly (not via `Entity.damage`). They must each clamp `hp` to 0 and set `dead = true` when `hp <= 0`. Previously `bleed` lacked this, so DoT could drive HP negative while the entity (including the player) stayed alive. Fixed by merging poison/burn/bleed into one case with the death clamp. Player death is detected via `player.dead` in `_step` (world.dart ~line 438).
