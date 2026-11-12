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
| E | Pick up log / stack log / drop log |
| V | Switch first ↔ third person |
| H | Show / hide controls |
| Esc | Free the mouse (click to resume) |

## Project layout

```
scenes/       Godot scenes (main world, player, tree, log, log stack, HUD)
scripts/
  core/         input bindings
  world/        world setup and terrain generation
  player/       player movement, camera, axe, carrying
  gathering/    trees, logs, log stack
  progression/  skill points and levels
  ui/           the HUD
  fx/           small visual effects
materials/    colours and surfaces (editable in Godot's Inspector)
docs/         design notes
```
