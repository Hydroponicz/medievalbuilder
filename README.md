# Medieval Builder

A first/third-person medieval building game. You start small and do everything by hand.
The work you put into a resource slowly grows into a living, automated industry,
so your wood keeps coming in while you build grand structures.

See [docs/DESIGN.md](docs/DESIGN.md) for the vision, the core loop and the roadmap.

## Getting the project onto your PC

You only need to do this once. After that, updating is one click.

### Recommended: GitHub Desktop

1. Install **GitHub Desktop**: https://desktop.github.com and sign in with your GitHub account.
2. **File → Clone repository**, pick `medievalbuilder`, and choose a folder on your PC (for example `Documents/GameDev`).
3. Check the **Current branch** dropdown at the top. Pick the branch with the latest work (it's named in each update).
4. Whenever new work is pushed, click **Fetch origin** and then **Pull origin** to get it.

### Alternative: download a ZIP

On the repository page on GitHub, click the green **Code** button, then **Download ZIP**, and unzip it.
You'll need to download it again for every update, so GitHub Desktop is easier long-term.

### Opening it in Godot

1. Open Godot (version **4.3 or newer**).
2. In the Project Manager, click **Import**.
3. Browse to the folder you cloned and select the `project.godot` file. Then click **Import & Edit**.
   On newer Godot versions this button may just say **Import**.
4. The first import takes a few seconds. Then press **F5** (or the ▶ button, top-right) to play.

If Godot asks to upgrade or convert the project to a newer version, say yes.

## Controls

| Key | Action |
| --- | --- |
| W A S D | Move |
| Shift | Sprint (not while carrying) |
| Space | Jump |
| Mouse | Look |
| Left click (hold) | Swing axe / chop |
| E | Pick up log / take log from stack / stack log / add log to supplies / drop log |
| V | Switch first ↔ third person |
| K | Forestry upgrades |
| B | Build mode on / off |
| Tab | Bird's-eye view (also turns on build mode) |
| H | Show / hide controls |
| Esc | Pause menu (Resume, Save Game, New World, Save & Quit) |

### In build mode

| Key | Action |
| --- | --- |
| Left click (hold) | Place block (or supply pile) |
| Right click (hold) | Remove block. Right click a supply pile to pack it up. |
| 1 / 2 / 3 / 4 | Rough log block / supply pile / plank block / chopping block (3 and 4 need the Chopping block upgrade) |
| R | Cycle build shape: Single, Line, Wall, Floor |
| Ctrl + mouse wheel | Wall height |

With Line, Wall or Floor: click and drag from start to end, then release to build the whole shape.
Right-drag removes in the same shape. Press the other mouse button mid-drag to cancel.

In bird's-eye view: **WASD** or **middle-mouse drag** pans, **Shift + middle-mouse drag** rotates and tilts,
**Q / E** rotate, the **mouse wheel** zooms towards the cursor, and the mouse aims.

## How building works

1. Chop trees. Delivering a fresh log to the log stack *or* a supply pile earns Forestry points.
2. In build mode, press **2** and place a **supply pile** where you want to build.
3. Carry logs to the supply pile (E), either straight from the forest or taken from the log stack (E with empty hands).
   Each log becomes **10 blocks** of build supplies.
4. Press **1** and build. Blocks within 12 m of a supply pile use its supplies.
   Removing a block puts its wood back on the pile.

## Upgrades

Every Forestry level gives you an **unlock point**. Press **K** to choose what to unlock, in any order.
Then make it with wood:

- **Tools** (Shoulder strap, Sharpened axe) are made at the log stack from logs in storage.
  Stand at the log stack, press K, and click **Make**.
- **Structures** (Chopping block) are built in build mode from a nearby supply pile.

The **chopping block** splits logs into planks: put a log on it (E), swing your axe at it, and a plank
bundle pops out. Carry it to a supply pile: one bundle = **20 plank blocks**.

## Saving

The game loads your world automatically when it starts. It saves every minute, when you close the window,
and when you pick **Save Game** or **Save & Quit** in the Esc menu.

Stopping the game from the Godot editor (the ■ button or F8) does **not** save. Only the autosave from the last minute is kept.

To start over, open the Esc menu and choose **New World**. Click it twice to confirm.

The save file is at `%APPDATA%\Godot\app_userdata\Medieval Builder\savegame.json` on Windows.

## Project layout

```
scenes/       Godot scenes (main world, player, tree, log, log stack, HUD)
scripts/
  core/         input bindings, saving and loading
  world/        world setup and terrain generation
  player/       player movement, camera, axe, carrying
  gathering/    trees, logs, log stack
  building/     blocks, supply piles, build mode, bird's-eye camera
  progression/  skill points and levels
  ui/           the HUD
  fx/           small visual effects
materials/    colours and surfaces (editable in Godot's Inspector)
docs/         design notes
```
