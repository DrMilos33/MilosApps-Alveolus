# First-party art

## Fall 1 event monster

- File: `event_monsters/case_one_event_monster.png`
- Purpose: presentation-only sprite for the mobile Fall 1 event monster
- Original artwork: hand-drawn and supplied directly by the user on 2026-08-26
- Processing: the built-in OpenAI image-editing tool removed the white canvas, stray border marks and edge matte, preserving the creature design and delivering genuine transparent RGBA pixels
- Runtime scope: visual ID `case_one_event_monster`; the stable gameplay identity remains `minor_focus`, so ordinary small infection foci and later cases retain their existing art

## Bright visual restart (legacy development history)

- Directory: `visual_restart/`
- Files: `campus_day_ground.png`, `campus_buildings_atlas.png`, `gameplay_sprites_atlas.png`, `alveolar_tissue_day.png`
- Purpose: the approved bright daytime art direction reference and the current lung environment
- Created specifically for ALVEOLUS with the built-in OpenAI image-generation tool
- The two atlases use stable grid regions through `VisualAssetCatalog`; chroma-key plates were converted to transparency before import
- Campus building atlas: retained for comparison only; runtime buildings now come from Kenney Sketch Town.
- Gameplay atlas: only the small sample pickup remains in use; doctor, enemies and immune cells now come from documented third-party sprite sheets.

Generation direction:

> Bright friendly illustrated medical research campus in daylight, warm ivory and sky blue surfaces, tactile painted 2D forms, deep petrol shadows, turquoise, coral, cobalt and honey-gold accents. Calm garden paths, plants and readable small buildings. No text, labels, UI or outlines.

> Cohesive ALVEOLUS gameplay sprite sheet with a friendly human doctor, green paired bacterium, bacterial cluster, violet infection focus, gold immune cell and blue sample pickup. Plastically shaded 2D illustration, clean silhouettes, fixed atlas grid, transparent-background delivery after chroma removal.

> Organic but calm alveolar tissue landscape in rose and violet, softly modelled membranes and capillaries, low contrast behind gameplay, seamless enough for a wrapping arena, no grid and no hard rectangular boundary.

## Campus evening diorama v2

- File: `campus_evening_v2.png`
- Purpose: fixed 16:9 background for the clickable ALVEOLUS campus
- Created for this project with the built-in OpenAI image-generation tool
- Input reference: the previously approved ALVEOLUS campus mockup

Final prompt:

> Turn the approved ALVEOLUS campus mockup into a clean UI-free evening campus diorama. Preserve the polished dark isometric 3D illustration style, landscaping density, warm windows, paths, lanterns, trees, shrubs, flowers, water edge and calm medical-campus mood. Remove every label, logo, status, tooltip, UI panel, text element, pointer and selection outline. Show five clearly separated buildings connected by paths: a welcoming medical practice upper-left, a modern research laboratory upper-right, a case archive/library lower-left, a distinct medical lexicon/gallery in the lower-middle with an integrated open-book or image-gallery emblem, and a small settings pavilion lower-right. Keep quiet sky space in the upper corners. Wide 16:9 orthographic composition; no characters, text, letters, numbers, UI, labels, hover outlines or watermarks.

## Layered campus scene

- Directory: `campus_layers/`
- Files: `campus_ground.png`, `practice.png`, `research.png`, `archive.png`, `lexicon.png`, `settings.png`
- Purpose: flexible Godot composition with one landscape plate and five independently positioned, interactive building sprites
- Created for this project with the built-in OpenAI image-generation tool, using `campus_evening_v2.png` as the visual reference
- Building sprites were generated on a solid chroma-key plate, converted to alpha, tightly cropped and resized for the 1280x720 design canvas
- Runtime outlines sample the alpha channel of the same sprite that is rendered, so the hover silhouette cannot diverge from the building artwork

The landscape prompt removed all architecture from the reference and reconstructed empty connected plots while preserving paths, water, vegetation and evening lighting. Each building prompt then reconstructed exactly one complete architectural unit at the same isometric viewing angle, excluding ground, vegetation, labels and UI.

The evening diorama, layered scene and generated bright campus are retained as development history. Runtime now assembles the campus from Kenney Sketch Town and its free expansion.
