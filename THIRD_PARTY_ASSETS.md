# Third-party assets

Only the third-party files listed below are shipped with ALVEOLUS. Other visuals are first-party project artwork or drawn at runtime in Godot.

The runtime campus is assembled from the Kenney Sketch Town packs listed below. Earlier generated campus artwork remains only as development history and is documented separately in `assets/art/README.md`.

## Kenney Sketch Town

- Source: https://kenney.nl/assets/sketch-town
- Pack version: 1.0
- License: CC0 1.0 Universal
- Runtime use: isometric grass, paths, modular buildings, roofs, trees and rocks
- Imported files: only the PNG tiles referenced by `VisualAssetCatalog`
- Local license copy: `assets/vendor/kenney_sketch_town/LICENSE.txt`

## Kenney Sketch Town Expansion

- Source: https://kenney.nl/assets/sketch-town-expansion
- Pack version: 1.0
- License: CC0 1.0 Universal
- Runtime use: pines, garden, fences and well
- Imported files: only the PNG tiles referenced by `VisualAssetCatalog`
- Local license copy: `assets/vendor/kenney_sketch_town_expansion/LICENSE.txt`

## Medical Examiner (female)

- Author: Chasersgaming
- Source: https://opengameart.org/content/medical-examiner-female
- License: CC0 1.0 Universal
- Imported file: `medical_examiner_female.png` (upstream `lablady_spritesheet_BOXED.png`)
- Runtime use: player doctor and ambient campus staff; four directional walk cycles are cropped from the source sheet at runtime
- Local license note: `assets/vendor/medical_examiner_female/LICENSE.txt`

## Random Germs/Amoeba Sprites

- Author: ChiliGames
- Source: https://opengameart.org/content/random-germsamoeba-sprites
- Upstream archive: `amoeba.zip`
- Offered licenses: CC-BY-SA 3.0 and CC0; ALVEOLUS uses the CC0 option
- Imported file: `amoeba.png`
- Runtime use: bacterium, bacterial group, infection focus and immune-cell base sprites; source regions are cropped and padded at runtime
- Local license note: `assets/vendor/chiligames_amoeba/LICENSE.txt`

## Kenney Game Icons

- Source: https://kenney.nl/assets/game-icons
- Download mirror used: https://opengameart.org/content/game-icons
- License: CC0 1.0 Universal
- Imported files: `arrowLeft.png`, `checkmark.png`, `cross.png`, `exit.png`, `gear.png`, `home.png`, `information.png`, `locked.png`, `pause.png`, `plus.png`, `return.png`, `star.png`, `target.png`
- Imported variant: `White/2x`
- Local license copy: `assets/vendor/kenney_game_icons/license.txt`

## Kenney Particle Pack for Godot

- Source: https://godotengine.org/asset-library/asset/784
- Repository: https://github.com/Calinou/kenney-particle-pack
- License: CC0 1.0 Universal
- Imported files: `circle_03.png`, `light_02.png`, `spark_06.png`, `star_06.png`, `trace_02.png`
- Local license copy: `assets/vendor/kenney_particles/LICENSE.txt`

## Kenney Interface Sounds

- Source: https://kenney.nl/assets/interface-sounds
- Pack version: 1.0, released 2020-02-11
- License: CC0 1.0 Universal
- Runtime use: semantic menu feedback through `UISoundService`
- Imported files and cue mapping:
  - `select_003.wav`: focus change
  - `click_003.wav`: ordinary press
  - `confirmation_002.wav`: confirm
  - `back_003.wav`: back
  - `error_006.wav`: invalid action
  - `open_003.wav`: dialog open
  - `maximize_003.wav`: reward and ability ready
  - `confirmation_004.wav`: run start
- Local license copy: `assets/vendor/kenney_interface_sounds/LICENSE.txt`

## Kenney Input Prompts

- Source: https://kenney.nl/assets/input-prompts
- Pack version: 1.5A, released 2026-07-11
- License: CC0 1.0 Universal
- Runtime use: optically centered prompts for the standard keyboard and Xbox-style bindings; freely remapped inputs keep a readable text fallback
- Imported files: `keyboard_q.png`, `keyboard_e.png`, `keyboard_escape.png`, `keyboard_enter.png`, `keyboard_space.png`, `xbox_lb.png`, `xbox_rb.png`, `xbox_button_a.png`, `xbox_button_b.png`, `xbox_button_menu.png`
- Imported variants: `Keyboard & Mouse/Default` and `Xbox Series/Default`
- Local license copy: `assets/vendor/kenney_input_prompts/LICENSE.txt`

## Bricolage Grotesque

- Source: https://fonts.google.com/specimen/Bricolage+Grotesque
- Repository: https://github.com/google/fonts/tree/main/ofl/bricolagegrotesque
- License: SIL Open Font License 1.1
- Imported file: `assets/fonts/BricolageGrotesque-Variable.ttf`
- Local license copy: `assets/fonts/BricolageGrotesque-OFL.txt`

## Atkinson Hyperlegible Next

- Source: https://fonts.google.com/specimen/Atkinson+Hyperlegible+Next
- Repository: https://github.com/google/fonts/tree/main/ofl/atkinsonhyperlegiblenext
- License: SIL Open Font License 1.1
- Imported file: `assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf`
- Local license copy: `assets/fonts/AtkinsonHyperlegibleNext-OFL.txt`

## Kenney Isometric Tiles Buildings

- Source: https://kenney.nl/assets/isometric-tiles-buildings
- Pack version: 1.0
- License: CC0 1.0 Universal
- Imported files: `practice.png`, `research.png`, `archive.png`, `settings.png`
- Original files: `buildingTiles_001.png`, `buildingTiles_116.png`, `buildingTiles_113.png`, `buildingTiles_028.png`
- Local license copy: `assets/vendor/kenney_isometric_buildings/LICENSE.txt`

## Kenney Isometric Tiles Landscape

- Source: https://kenney.nl/assets/isometric-tiles-landscape
- Pack version: 1.0
- License: CC0 1.0 Universal
- Imported files: `grass_plain.png`, `grass_slope_a.png`, `grass_slope_b.png`
- Original files: `landscapeTiles_015.png`, `landscapeTiles_028.png`, `landscapeTiles_029.png`
- Local license copy: `assets/vendor/kenney_isometric_landscape/LICENSE.txt`

## Screaming Brain Studios Seamless Abstract Pack

- Source: https://opengameart.org/content/seamless-abstract-pack
- Upstream page: https://screamingbrainstudios.itch.io/seamless-abstract-pack
- Pack release: 2022-01-17, 256×256 edition
- License: CC0 1.0 Universal
- Imported file: `alveolar_base.png`
- Original file: `Texture_256x256_31.png`
- Local license copy: `assets/vendor/screaming_brain_seamless_abstract/LICENSE.txt`

## Technical reference only

The Godot 4 Isometric Game Demo (https://godotengine.org/asset-library/asset/2718, MIT) was consulted for isometric scene ordering. No files from the demo are included.

FreeGameUI and Kenney Monster Builder were evaluated during art direction. No unchanged files from either pack are included. The legacy generated campus and gameplay atlases are retained as development history but no longer provide buildings, enemies or characters at runtime.
