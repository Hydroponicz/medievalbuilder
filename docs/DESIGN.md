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
| Building | 0.5 m voxel blocks for player structures (Enshrouded-style) |
| Block cost | 1 log = 10 rough log blocks. Resources must be hauled to a supply pile at the build site. |
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
- [ ] **Phase 2: Feel pass.**
  - [x] Simpler point popups ("+1 Forestry")
  - [x] Saving and loading: autosave, save on quit, Esc pause menu, New World
  - [ ] Sounds (chop, fall, footsteps, ambience). Postponed for now.
- [ ] **Phase 3: Building basics.** (built, in testing)
  - 0.5 m voxel blocks on a world grid. First block type: rough log block.
  - 1 log = 10 blocks. Logs must be hauled by hand: log stack, then supply pile, then build.
  - Supply piles can be placed anywhere and power building within 12 m.
  - Build mode (B) with a ghost preview. Bird's-eye planning camera (Tab).
  - Build shapes (R): Single, Line, Wall, Floor. Drag to build or remove whole shapes.
  - Bird's-eye: middle-drag pan, Shift + middle-drag rotate/tilt, zoom towards cursor.
  - Forestry points come from delivering fresh logs anywhere (log stack or supply pile).
  - Carrying supports several logs, but starts at 1. Carrying more is a Forestry upgrade.
- [ ] **Phase 4: First unlock.** Spend Forestry levels on Tier 1 (shelter + chopping block).
- [ ] **Phase 5: Weather.** Rain, and a reason to keep logs covered.
- [ ] **Phase 6: First worker.** The woodcutter's hut.
- Later: farming line, mill, stone/mining line, and more.

## Ideas for Forestry upgrades (to design in Phase 4)

**Decided:** carrying more logs at once is an upgrade (start at 1, e.g. strap = 2, then 3, then wheelbarrow/cart).

Other pains from building that upgrades could relieve:
the log stack is far from the build site (extra stacks, a worker who hauls); chopping speed (better axes);
trees running out (replanting); better-looking blocks (planks and beams from a chopping block or sawpit).

## Open questions

- Should trees regrow on their own, or only once you unlock replanting?
- Do workers need food and housing (which would tie into the farming line)?
- Should the axe be crafted at the very start (sticks + stone), or given to the player?
- How punishing should log rot be when logs are left in the rain?
