<div align="center">

# Deus Ex: Reimagined UI

**A ground-up interface overhaul for the original Deus Ex (2000)**

Menus, HUD, inventory, augmentations, dialogue and every in-game screen, rebuilt with a modern layout while keeping the game's own logic underneath.

`BETA` · build 72 · vanilla Deus Ex · Windows

</div>

---

> [!NOTE]
> This is a beta for friends and testers. It is stable enough to play through, but expect rough edges. If something breaks, see [Reporting a bug](#reporting-a-bug) at the bottom.

## What it changes

| Area | What you get |
| --- | --- |
| **Menus** | New main menu, pause menu, settings, load and save screens, and key binding (click a row, then press a key). |
| **HUD** | A redesigned heads-up display with a body monitor, bioelectric bar, compass, hotbar, ammo readout and compact pickup and goal notices on the side of the screen. |
| **In-game screens** | Inventory (with item rotation and drag-and-drop), Health, Augmentations, Skills and a combined Journal for goals, notes, images and conversations. Q and E cycle between them. |
| **Dialogue** | Cleaner conversation text and replies, with optional cinematic black bars. Escape pauses a conversation and Enter or Space skips a line. |
| **Devices** | Keypads, computers, ATMs, med bots, repair bots and the book and datacube reader are all restyled. |
| **Death screen** | A proper death screen with clickable buttons for loading the last save, loading a game or quitting to the main menu. |

### Two looks to choose from

Open **Settings › Interface › UI Style** to switch the whole interface at once.

- **Sleek** is the clean, minimal look based on the concept art.
- **Vanilla+** keeps the original game's mechanical frames and textures and wraps them around the new layout, for players who want the 2000 feel with modern usability.

Colours follow the HUD and menu themes you pick in Settings, and the size of the HUD, hotbar, subtitles and in-game screens can each be adjusted with a slider.

## Installing (for players)

### You will need

1. **Deus Ex: Game of the Year Edition** from Steam or GOG.
2. **Kentie's DeusExe launcher.** Steam's own `DeusEx.exe` relaunches itself through Steam and drops the mod's settings, so a DRM-free exe is required. Install it with Vortex or by hand from [Kentie's site](https://kentie.net/article/dxguide/) (GOG copies already work without it).
3. Windows 10 or 11.

### Steps

1. Download the latest `ReimaginedUI-beta-*.zip` from the [Releases](../../releases) page.
2. Extract it straight into your Deus Ex folder, so the `System` and `Mods` folders merge with the ones already there. On Steam that folder is usually
   `C:\Program Files (x86)\Steam\steamapps\common\Deus Ex`
3. Start the game with **`System\Play_ReimaginedUI_Vanilla.cmd`**. A desktop shortcut to that file works well.

Your normal `DeusEx.exe` still launches the untouched original game, and both share the same save folder.

> [!TIP]
> The included settings file defaults to Direct3D 9 at 1920×1080. If your screen differs, change the resolution in **Settings › Display** on first launch.

### Uninstalling

Delete `System\Play_ReimaginedUI_Vanilla.cmd`, `System\RINative.dll` and the `Mods\ReimaginedUI` folder. Nothing else in the game is modified. The launcher marks `DeusEx.exe` as DPI-aware in your Windows user settings so the window isn't stretched on high-DPI laptops; that setting is harmless and can be left in place.

## Controls worth knowing

| Key | Action |
| --- | --- |
| `0`–`9` | Hotbar slots. The nano key ring lives in slot 0. |
| Mouse wheel | Steps through every hotbar slot in order. Landing on an empty slot puts away whatever you are holding. |
| `F` | Interact |
| `Q` / `E` | Cycle between the in-game screens once one is open |
| `Esc` in a conversation | Pause (the conversation waits exactly where it was) |
| `Enter` / `Space` in a conversation | Skip to the next line |
| `Ctrl` + `F10` | Debug overlay, if you are reporting a bug |

## Settings › Interface at a glance

| Option | What it does |
| --- | --- |
| UI Style | Sleek or Vanilla+ for the whole interface |
| Menus, In-game screens, Dialogue, HUD | Switch any part back to the original game's look |
| Screen, HUD, Hotbar and Subtitle size | Separate sliders for in-game screens, HUD, hotbar and subtitles |
| Conversation Bars | Restore the original black cinematic bars during conversations |
| Textures | Use the upscaled (HD) interface textures or the originals |

## Known issues

- The **Modern** style shown in early mockups is not built yet.
- Toggling fullscreen from inside the game can crash some third-party DirectX 12 renderers. Change it in the ini file instead if that happens.
- The game cannot draw anything during a level load, so the loading screen is a single still frame.

## Building from source

The mod is plain UnrealScript plus a small native plugin for pixel-exact text.

```
Mods\ReimaginedUI\
├─ Source\ReimaginedUI\Classes\   shared screens, HUD and menus (edit here)
├─ Source\ReimaginedUI\Textures\  8-bit PCX textures imported at build time
├─ Source\Base_Vanilla\Classes\   adapter classes for the original game
├─ Source\Base_AE\Classes\        adapter classes for GMDX: Augmented Edition
├─ Source\RINative\               script side of the native plugin
├─ Native\Src\                    C/C++ source of RINative.dll
├─ System\                        build and launcher ini files
└─ Install\System\                launcher scripts that go in the game's System folder
```

1. Clone this repository into `<Deus Ex>\Mods\ReimaginedUI`.
2. Run **`Build_Vanilla.cmd`** to compile for the original game, or **`Build_ReimaginedUI.cmd`** for GMDX: Augmented Edition 1.2. The output lands in `System\Vanilla\ReimaginedUI.u` or `System\ReimaginedUI.u`, and the build number shows on the main menu.
3. Copy the launcher from `Install\System` into the game's `System` folder and play.

The build log is written next to the scripts (`build_ri_vanilla.log`). `Build_Quick_And_Play_Vanilla.cmd` builds and launches in one step.

<details>
<summary><b>UnrealScript gotchas that have broken builds before</b></summary>

- Names are case-insensitive, so a local `bw` clashes with a member `BW`.
- No bare `{ }` blocks, no `bool` arrays, and no `break` inside an `if` inside a `switch`.
- Every local must be declared before the first statement, and functions take at most 16 parameters.
- `==` binds tighter than `$`, so parenthesise string joins in comparisons.
- Casting a value to its own type is a compile error.
- Windows shown during the engine's `WindowReady` pass break `initCount`; handlers there should only set a flag.

</details>

## Reporting a bug

Open an issue (or message me) with what you were doing, a screenshot, and the log file at
`Mods\ReimaginedUI\System\Vanilla\ReimaginedUI.log`.

## Credits

- **Interface concept:** Tanit Mesa, *Deus Ex 2000: Reimagined (UX/UI)* on ArtStation. The layout and look of this mod follow her concept art and mockups.
- **Fonts:** Michroma and Exo 2, both under the SIL Open Font License.
- **Launcher:** Kentie's DeusExe.
- **GMDX: Augmented Edition** by Sarge and the GMDX team, the first base this mod was built on.
- **Deus Ex** by Ion Storm and Eidos Interactive. Original game art and textures belong to their owners.

## License

The mod's own code is released under the [MIT License](LICENSE). Game assets and third-party art keep their original licenses.
