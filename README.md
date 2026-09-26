# Dragonsweeper (Godot clone)

Play the web build: https://saturn4er.github.io/SweepTheDragon/

A faithful reimplementation of Daniel Benmergui's [Dragonsweeper](https://danielben.itch.io/dragonsweeper)
in Godot 4.7 with GDScript. One project exports to Web, macOS, Windows, Linux, Android and iOS.

Jorge must defeat the dragon at the centre of a 13x10 dungeon. Numbers are the sum of the monster
levels around a tile. Attacking a monster costs hearts equal to its level; collecting it grants xp.
Level up to refill hearts and grow. Every monster has a pattern worth learning.

## Layout

- `core/` engine-free rules: `Board`, `Tile`, `Player`, `Catalog`, `Generator`, `Game`, `Stamps`.
  No nodes, no textures. Deterministic from a seed.
- `scenes/` presentation: `main.gd` wires a `Game` to `BoardView`, `Hud`, `Monsternomicon`,
  `WinScreen` and `FxLayer`, and turns `GameEvent`s into sound and effects.
- `autoload/` `Settings` (user://settings.cfg) and `Audio` (sfx variants, music).
- `assets/` sprites, fonts and audio. See `assets/CREDITS.md`.
- `tests/` GUT suites for the core. `tools/` art generator and dev harness.
- `docs/superpowers/specs/` the design document.

## Run

Godot 4.7.2 is expected at `/Applications/Godot.app` on macOS; adjust the path otherwise.

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --path . --editor          # open in the editor
$GODOT --path .                   # play
```

## Test

```sh
$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
```

## Screenshots and scripted runs

The dev harness drives the game from command-line args, useful for checking states quickly:

```sh
$GODOT --path . -- --shot=/tmp/shot.png --seed=2024 --press=10,4 --press=3,3 --press=hero --press=book
```

## Continuous deployment

Every push to `main` runs `.github/workflows/deploy.yml`: it downloads Godot 4.7.2 and the web export
template (cached between runs), runs the GUT tests, exports the Web preset and publishes it to
GitHub Pages.

## Export

Presets live in `export_presets.cfg`. Install the 4.7.2 export templates first (Editor > Manage
Export Templates, or copy them to the Godot templates directory).

```sh
$GODOT --headless --path . --export-release Web export/web/index.html
$GODOT --headless --path . --export-release macOS export/macos/Dragonsweeper.zip
$GODOT --headless --path . --export-release Windows export/windows/Dragonsweeper.exe
$GODOT --headless --path . --export-release Linux export/linux/Dragonsweeper.x86_64
$GODOT --headless --path . --export-release Android export/android/Dragonsweeper.apk
$GODOT --headless --path . --export-release iOS export/ios/Dragonsweeper.xcodeproj
```

- Web is exported without thread support so it runs on plain static hosting (itch.io, GitHub
  Pages) without cross-origin isolation headers. Serve `export/web/` with any static server.
- Android needs the Android SDK, a Java 17 runtime and a debug keystore configured in the Godot
  editor settings.
- iOS needs your Apple Team ID in the preset (`application/app_store_team_id` in
  `export_presets.cfg`) before the export runs; it produces an Xcode project to sign and build.
- Mobile locks to landscape. Marks are set with a long press on touch, right click or shift-click
  on desktop.

## Debug keys

- `X` or `F9` toggles x-ray: every tile is drawn revealed (mimics unmasked) without changing the game,
  with a stats line: damage left, hp budget, medikits, wasted hp.
- `Z` or `F8` while x-ray is on undoes the last press or level up, even after dying or winning.
- `R` restarts, `F11` toggles fullscreen, `Escape` closes the book.

## Regenerating the UI art

Tiles, hearts, gems, marks and panels are drawn by `tools/gen_ui_art.gd`; bombs, the mine and rat kings and the scrolls by `tools/gen_icons.gd`:

```sh
$GODOT --headless --path . -s tools/gen_ui_art.gd
```

## Names and licence

"Dragonsweeper" and "Jorge" are used as working names in homage to the original. Nothing from the
original game's art or text is included. Publishing under that name would need the original
author's permission. Third-party asset licences are listed in `assets/CREDITS.md`.
