# Design notes

A living document. Decisions get recorded here as we make them.

## The pitch

In most sandbox games, automation is a lifeless machine you build *instead* of doing the work.
Here, **doing the work by hand is how automation grows**. Chop enough wood and your little
woodpile turns into a real lumberyard: sheds, a sawpit, woodcutters and carts. It all lives and
works in the world. Your wood keeps coming in from day one, and you're freed up to build
grand structures or start the next industry.

## Pillars

1. **Earned automation.** Every automated step is one the player has done by hand first.
2. **It grows in place.** Upgrades physically change the site the player built. They aren't abstract menu stats.
3. **Medieval, not industrial.** Workers, carts, oxen and water wheels instead of belts and power.
4. **One repeating loop.** Every resource line follows the same pattern, so each new line reuses proven systems.
5. **Slow and polished.** We add one system at a time and make it feel good before moving on.

## Core loop (per resource line)

```
Do it by hand  ->  earn progression points  ->  level up  ->  unlock next tier  ->  automate  ->  free time
     ^                                                                                              |
     +---------------------------------------- build / start the next line <------------------------+
```

Resource lines feed each other. For example: wheat field -> granary -> mill (its own line) -> bakery.

## Decisions so far

| Topic | Decision |
| --- | --- |
| Engine | Godot 4 (4.3+), GDScript |
| Terrain | Smooth, rolling and natural. **Not** blocky. |
| Building | Voxel/block building for player structures (Enshrouded-style). Planned, not built yet. |
| Cameras | First person, third person, and a bird's-eye camera for planning big builds (comes with building). |
| Players | Single-player only |
| Goal | Open-ended sandbox |
| Progression | Points are tracked **per skill line** (Forestry, Farming, ...) |
| Art | Simple placeholder shapes for now. Real art comes later. |

## Forestry line: draft tiers

This is a sketch to discuss, not a commitment.

| Tier | Name | What the player does / gets |
| --- | --- | --- |
| 0 | By hand | Axe, chop trees, carry logs, stack them. **Phase 1, built.** |
| 1 | Woodpile shelter | Build a shed so stacked logs stay dry. Chopping block to split logs. |
| 2 | Woodworking | Sawhorse / sawpit: logs become planks and beams (better building blocks). |
| 3 | Woodcutter's hut | First worker: chops nearby trees and hauls logs to your stack. |
| 4 | Lumberyard | Several workers, replanting, a cart, larger storage. |
| 5 | Sawmill | Water-powered saw. Planks and beams arrive steadily. |

## Roadmap

Each phase gets built, played and polished before the next starts.

- [x] **Phase 1: Chopping by hand.** Smooth terrain, forest, first/third person, axe swing, felling,
  logs, carrying, log stack, Forestry points and levels, HUD.
- [ ] **Phase 2: Feel pass.** Playtest Phase 1 and fix what feels off. Add sounds (chop, fall, footsteps)
  and saving/loading.
- [ ] **Phase 3: Building basics.** Place and remove simple wood blocks using stored logs. Bird's-eye planning camera.
- [ ] **Phase 4: First unlock.** Spend Forestry levels on Tier 1 (shelter + chopping block).
- [ ] **Phase 5: Weather.** Rain, and a reason to keep logs covered.
- [ ] **Phase 6: First worker.** The woodcutter's hut.
- Later: farming line, mill, stone/mining line, and more.

## Open questions

- Should trees regrow on their own, or only once you unlock replanting?
- Do workers need food and housing (which would tie into the farming line)?
- Should the axe be crafted at the very start (sticks + stone), or given to the player?
- How punishing should log rot be when logs are left in the rain?
