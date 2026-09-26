# Dragonsweeper clone: design

Faithful reimplementation of Daniel Benmergui's Dragonsweeper (v1.1.18 rules) in Godot 4.7 with
GDScript, targeting Web, macOS, Windows, Linux, Android and iOS from one project. No art or text
from the original is copied. "Dragonsweeper" and "Jorge" are working names held in constants.

## Architecture

- `core/`: engine-free rules. Plain `RefCounted` classes with `class_name`. No nodes, textures or
  audio. Deterministic given a seed.
- `scenes/`: presentation. Replays events emitted by the core into sprites, tweens and sounds.
- `autoload/`: `Settings` (ConfigFile at `user://settings.cfg`) and `Audio` (SFX variants, music).
- `assets/`: sprites, fonts, audio, `CREDITS.md`.
- `tests/`: GUT suites over `core/` run headless.

## Core model

Grid 13x10. Tile fields: `pos`, `kind`, `level`, `xp`, `revealed`, `defeated`, `mark` (0..16),
`wall_hp`, `wall_max_hp`, `contains` (kind or NONE), `role` (romeo, juliet, guard1..4,
gargoyle1..4, orb_with_healing), `mimicking`, `minotaur_chest` (Vector2i or (-1,-1)), `fixed`.

Distances are Euclidean, matching the source: 8-neighbours `< 2`, adjacency incl. diagonals
`< 1.5`, orthogonal-only `== 1`, gazer mask `<= 2`, orb radius `< 2.1`.

Attack number of a tile = sum of `level` over its 8 neighbours where level > 0. Defeated but
uncollected monsters still count. Disarmed mines have level 0. Tiles within distance 2 of an
undefeated gazer display `?` instead of a number.

### Catalog

| kind | level | xp | count | notes |
|---|---|---|---|---|
| rat | 1 | 1 | 13 | faces the rat king |
| bat | 2 | 2 | 12 | |
| skeleton | 3 | 3 | 10 | |
| gargoyle | 4 | 4 | 8 | 4 pairs, orthogonally adjacent twins facing each other |
| slime | 5 | 5 | 8 | |
| rat king | 5 | 5 | 1 | drops reveal-rats scroll |
| gazer | 5 | 5 | 2 | masks numbers within distance 2; book shows `?` count |
| minotaur | 6 | 6 | 5 | adjacent to exactly one chest, faces it; startled when chest opened |
| guardian | 7 | 7 | 4 | one per quadrant |
| big slime | 8 | 8 | 5 | adjacent to the wizard |
| giant | 9 | 9 | 2 | romeo (x<=5) and juliet (x>=7), same row, mirrored; drop medikit |
| mine king | 10 | 10 | 1 | corner; drops disarm scroll |
| mimic | 11 | 11 | 1 | looks like a chest until attacked |
| dragon | 13 | 13 | 1 | revealed at (6,4); drops crown |
| wizard | 1 | 1 | 1 | edge, not corner; drops reveal-slimes scroll |
| gnome | 0 | 9 | 1 | dodges to the hidden empty tile nearest a medikit |
| dragon egg | 0 | 3 | 1 | adjacent to dragon; leaving it alive earns a stamp |
| mine | 100 | 3 | 9 | |
| wall | - | - | 6 | 3 hp, each hit costs 1 hp, refused at hp 1; contains treasure(1) |
| chest | - | - | 3+2 | contains treasure(5) x3, medikit x2 |
| medikit | - | - | 5 | heals to full, "wrong" if already full |
| orb | - | - | 1 | revealed at start; reveals radius 2.1 |
| orb scroll | - | - | 1 | reveals 3x3 around a random hidden tile, preferring one adjacent to a hidden mine |

Player: level 1, max hp 6 (heart index 0 is never drawn, so 5 hearts show), hp = max hp.
XP to next level by level: `[0, 4, 5, 7, 9, 9, 10, 12, 12, 12, 15, 18, 21, 21, 25]`, clamped at
the last entry. Level up: subtract cost, level += 1, if new level is odd and max hp < 19 then
max hp += 1 (even levels show a half heart), hp = max hp.

### Turn resolver

`Game.press(pos) -> Array[GameEvent]`. Order of checks mirrors the source:

1. Gnome (any reveal state): if a hidden empty tile exists, gnome moves to the one nearest any
   medikit (keeping the target's mark), the pressed tile becomes empty. Emit GnomeJumped.
2. Revealed tile by kind:
   - crown: finish game, compute stamps, status WinScreen.
   - reveal-slimes / reveal-rats scroll: reveal all matching monsters, tile becomes empty.
   - disarm scroll: every undefeated mine gets defeated=true, level=0; tile becomes empty;
     `mines_disarmed=true`; emit MinesDisarmed (with revealed mine positions and affected
     revealed empty neighbours for FX).
   - orb scroll: candidates = hidden tiles, shuffled; pick = last candidate adjacent (<1.5) to a
     hidden mine, else first candidate; reveal all hidden tiles within <1.5 of pick; tile empty.
   - treasure: grant xp, tile empty.
   - wall: if hp == 1 emit Refused; else hp -= 1, wall_hp -= 1; at 0 the tile becomes its
     `contains` (revealed) and emits WallDown, else WallHit.
   - chest: tile becomes its `contains`, stays revealed. Emit ChestOpened.
   - orb: tile empty; reveal all hidden tiles within <2.1. Emit Revealed for each.
   - medikit: hp = max hp (emit Healed) or Refused if full; tile empty.
   - monster, mimicking and hidden: nothing.
   - monster, not defeated: unmask mimic; hp -= level; if hp > 0 defeated = true; count rats;
     emit Attacked(kind, damage, defeated).
   - monster, defeated: grant xp; transform: dragon -> crown, rat king -> reveal-rats,
     wizard -> reveal-slimes, giant -> medikit, mine king -> disarm, else empty. Emit Collected.
3. Hidden tile: revealed = true (no flood fill). Emit Revealed.
4. Aftermath: if hp <= 0 then hp = 0, status Dead, unmask all mimics, emit Died(cause). If hp
   fell to 1 and a level up is not available emit Alarm. If xp crossed the threshold emit
   CanLevelUp. Track `last_pressed` for the death message and for keeping its tile raised.

Death messages by kind as in the source; romeo/juliet override the giant message.

Other calls: `set_mark(pos, mark)`, `level_up()`, `hero_pressed()` (level up, restart when dead,
else emit HeroTapped), `restart(seed)`.

Stamps on win: CLEAR (no non-empty tiles left besides dragon/crown), LOVERS (both giants alive),
EGG (egg alive), PACIFIST (no rats killed). Merged into persistent stamps.

### Generator

Six layers, in order. Each layer: put its actors on the first empty tiles, then optimise: for 4
passes, shuffle the tile order, and for each layer actor try swapping with every non-fixed tile,
keeping the best swap where happiness does not decrease. Then fix the layer's actors.

1. dragon, wizard
2. big slime x5
3. mine king
4. giant romeo, giant juliet
5. rat king, wall x6 (treasure 1), minotaur x5, guardian x4 (guard1..4), gargoyle x8 (pairs
   gargoyle1..4), gazer x2, mine x9, medikit x5, chest x3 (treasure 5), chest x2 (medikit),
   orb x1 (revealed, orb_with_healing), dragon egg
6. rat x13, bat x12, skeleton x10, slime x8, mimic, gnome, orb scroll

Happiness terms (sum over tiles):

- dragon egg adjacent (<1.5) to dragon: +9000
- gnome adjacent (<1.5) to a medikit: +10000
- guardian in its quadrant (guard1 x<6,y<4; guard2 x>6,y<4; guard3 x>6,y>4; guard4 x<6,y>4): +2500
- giant: romeo x<=5 or juliet x>=7: +1000; same row as the other giant and |x-6| equal: +10000
- big slime adjacent (<1.5) to wizard: +1000
- wizard on edge and not corner: +10000
- mine king in corner: +10000
- dragon at (6,4): +10000
- minotaur: exactly one chest with distance < 2 and different column, and no other minotaur
  within < 2 of that chest: +10000
- gargoyle with its twin at distance <= 1: +1000
- orb: within 2 tiles of the edge: -10000; each forbidden kind within < 2.1 (dragon, gazer,
  chest, orb scroll, rat king, mine, dragon egg, big slime, mimic): -2000; walls within radius
  beyond two: -2000 each; exactly one medikit and at least one wall within radius: +2000
- medikit: -1000 per other medikit within < 3.5
- chest: -1000 per other chest within < 3
- wall: exactly one wall at distance <= 1, none at distance in (1, 1.5), and fewer than two of
  the pair on the edge: +2000

Every term is local within radius 3.5 except the giant pair, so a swap only needs to re-evaluate
terms of tiles within 3.5 of the two swapped positions plus both giants. The implementation uses
that to stay under one second per board in GDScript.

Post generation: dragon revealed; minotaurs record the adjacent chest (< 1.5); gargoyles record
facing direction toward the twin; walls get hp 3; wall and chest positions are remembered for
floor decals after they are gone.

All randomness comes from one `RandomNumberGenerator` seeded per game.

## Presentation

Logical size 390x340: board 13x30 by 10x30 on top, HUD 390x41 below. Stretch mode viewport,
aspect keep, nearest filtering. Mobile locks to landscape.

- `Main`: owns `Game`, drives status (generating frame, playing, dead, win screen), routes events.
- `BoardView`: 130 `TileView` children. Input: left click to press; right click or shift-click
  opens the mark menu on desktop; on touch, holding 0.33 s opens it with a growing ring. Dead
  state shows the whole board with the killing tile kept raised.
- `TileView`: button background (raised, pressed, collected variants with decorative frames),
  floor decal, icon, number label, monster level badge, xp badge, mark.
- `MarkMenu`: 4x4 grid of 24 px buttons: 1..12, three icon marks, clear (only when marked).
  Clamped inside the board, closes on outside click.
- `Hud`: hero button (idle, empowered, low hp, dead, leveling, stabbing, tapped), "Jorge"
  label, 19 heart slots skipping index 0 grouped by five with a wrap after 16, xp gems grouped by
  five that spin when a level is ready, excess xp marker, book button bouncing until first read,
  death message with "< restart".
- `Monsternomicon`: page 0 hints, sound and music toggles, monster counts in two columns of ten
  including scroll counts; page 1 stamps and credits.
- `WinScreen`: illustration, our own four-line text (two variants), score and max, time, stamps.
- `FxLayer`: one-shot sprite animations (reveal, hit, explosion, gnome jump, number change,
  dragon death) and camera shake.

## Assets

- Kenney Tiny Dungeon (CC0): hero, wizard, chest, open chest, mimic chest, bat, slime, potions.
- DawnLike (CC-BY 4.0, credit DawnBringer and DragonDePlatino): rat, rat king, skeleton,
  gargoyle, minotaur, guardian, giants, big slime, dragon, egg, gazer, gnome, mine king.
- Drawn by us: 30 px tile buttons, hearts, xp gems, marks, scrolls, mine, orb, treasure, crown,
  HUD and book panels, FX frames.
- Kenney Fonts (CC0), Kenney Interface/Impact/RPG audio (CC0), Kenney music jingles (CC0).
- Attribution in `assets/CREDITS.md` and on the book's second page.

## Persistence

`Settings` autoload: sound, music, nomicon_read, stamps. ConfigFile in `user://`.

## Exports

Presets: Web (thread support off), macOS universal, Windows x86_64, Linux x86_64, Android
(landscape), iOS (landscape). Web and macOS are verified locally. Store signing out of scope.

## Testing

GUT headless over `core/`: player progression to the cap; distances, neighbours, numbers and
gazer masking; generator counts, invariants (the source's own checks) across many seeds,
determinism and time budget; every resolver branch; stamps; settings round trip.
