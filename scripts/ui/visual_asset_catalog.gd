class_name VisualAssetCatalog
extends RefCounted

## All externally sourced visuals enter the game through this catalog. The
## campus and unit sprites intentionally use source assets rather than the old
## generated atlases so provenance stays explicit and replaceable.

const CAMPUS_ATLAS_PATH := "res://assets/art/visual_restart/campus_buildings_atlas.png"
const ALVEOLAR_TEXTURE_PATH := "res://assets/art/visual_restart/alveolar_tissue_day.png"
const ANALYSIS_SAMPLE_PATH := "res://assets/art/ui/analysis_sample.svg"
const DOCTOR_SHEET_PATH := "res://assets/vendor/medical_examiner_female/medical_examiner_female.png"
const GERMS_SHEET_PATH := "res://assets/vendor/chiligames_amoeba/amoeba.png"
const SKETCH_TOWN_ROOT := "res://assets/vendor/kenney_sketch_town/"
const SKETCH_TOWN_EXPANSION_ROOT := "res://assets/vendor/kenney_sketch_town_expansion/"

const ALPHA_THRESHOLD := 8
const SAFE_PADDING_RATIO := 0.08

const DOCTOR_WALK_ORIGIN := Vector2i(565, 1)
const DOCTOR_FRAME_STEP := Vector2i(32, 32)
const DOCTOR_FRAME_SIZE := Vector2i(30, 29)

const GERM_REGIONS := {
	&"pneumococcus": Rect2i(185, 15, 120, 110),
	&"bacterial_cluster": Rect2i(300, 10, 190, 145),
	&"infection_focus": Rect2i(480, 0, 240, 180),
	&"immune_cell": Rect2i(20, 136, 100, 90),
}

const GAMEPLAY_INTERFACE_VISUALS := {
	&"analysis_pickup": true,
	&"bacterial_swarm": true,
}

const DIRECT_GAMEPLAY_VISUAL_PATHS := {
	&"case_one_event_monster": "res://assets/art/event_monsters/case_one_event_monster.png",
}

const CAMPUS_TILE_PATHS := {
	&"grass": SKETCH_TOWN_ROOT + "grass_center_S.png",
	&"path_n": SKETCH_TOWN_ROOT + "grass_path_N.png",
	&"path_e": SKETCH_TOWN_ROOT + "grass_path_E.png",
	&"path_s": SKETCH_TOWN_ROOT + "grass_path_S.png",
	&"path_w": SKETCH_TOWN_ROOT + "grass_path_W.png",
	&"path_bend_n": SKETCH_TOWN_ROOT + "grass_pathBend_N.png",
	&"path_bend_e": SKETCH_TOWN_ROOT + "grass_pathBend_E.png",
	&"path_bend_s": SKETCH_TOWN_ROOT + "grass_pathBend_S.png",
	&"path_bend_w": SKETCH_TOWN_ROOT + "grass_pathBend_W.png",
	&"path_cross": SKETCH_TOWN_ROOT + "grass_pathCrossing_S.png",
	&"tree": SKETCH_TOWN_ROOT + "tree_single_S.png",
	&"trees": SKETCH_TOWN_ROOT + "tree_multiple_S.png",
	&"rocks": SKETCH_TOWN_ROOT + "rocks_grass_S.png",
	&"pine": SKETCH_TOWN_EXPANSION_ROOT + "tree_pine_S.png",
	&"pines": SKETCH_TOWN_EXPANSION_ROOT + "tree_pineLarge_S.png",
	&"well": SKETCH_TOWN_EXPANSION_ROOT + "well_S.png",
	&"fence": SKETCH_TOWN_EXPANSION_ROOT + "fence_wood_S.png",
	&"fence_corner": SKETCH_TOWN_EXPANSION_ROOT + "fence_woodCorner_S.png",
	&"garden": SKETCH_TOWN_EXPANSION_ROOT + "furrow_cropWheat_S.png",
}

const CAMPUS_BUILDING_LAYERS := {
	&"practice": [
		[SKETCH_TOWN_ROOT + "building_doorWindowsBeige_S.png", 110],
		[SKETCH_TOWN_ROOT + "roof_churchBeige_S.png", 0],
	],
	&"research": [
		[SKETCH_TOWN_ROOT + "building_doorWindows_S.png", 110],
		[SKETCH_TOWN_ROOT + "roof_pointPurple_S.png", 0],
	],
	&"levels": [
		[SKETCH_TOWN_ROOT + "building_windowsBeige_S.png", 110],
		[SKETCH_TOWN_ROOT + "roof_roundedBrown_S.png", 0],
	],
	&"lexicon": [
		[SKETCH_TOWN_ROOT + "building_windows_S.png", 110],
		[SKETCH_TOWN_ROOT + "roof_churchPurple_S.png", 0],
	],
	&"settings": [
		[SKETCH_TOWN_ROOT + "structure_low_S.png", 110],
		[SKETCH_TOWN_ROOT + "roof_pointGreen_S.png", 0],
	],
}

const ICON_PATHS := {
	&"back": "res://assets/vendor/kenney_game_icons/arrowLeft.png",
	&"settings": "res://assets/vendor/kenney_game_icons/gear.png",
	&"pause": "res://assets/vendor/kenney_game_icons/pause.png",
	&"close": "res://assets/vendor/kenney_game_icons/cross.png",
	&"locked": "res://assets/vendor/kenney_game_icons/locked.png",
	&"information": "res://assets/vendor/kenney_game_icons/information.png",
	&"therapy_precision": "res://assets/vendor/kenney_game_icons/target.png",
	&"check": "res://assets/vendor/kenney_game_icons/checkmark.png",
	&"plus": "res://assets/vendor/kenney_game_icons/plus.png",
	&"home": "res://assets/vendor/kenney_game_icons/home.png",
	&"exit": "res://assets/vendor/kenney_game_icons/exit.png",
	&"return": "res://assets/vendor/kenney_game_icons/return.png",
	&"star": "res://assets/vendor/kenney_game_icons/star.png",
}

const PARTICLE_PATHS := {
	&"soft": "res://assets/vendor/kenney_particles/circle_03.png",
	&"glow": "res://assets/vendor/kenney_particles/light_02.png",
	&"spark": "res://assets/vendor/kenney_particles/spark_06.png",
	&"star": "res://assets/vendor/kenney_particles/star_06.png",
	&"trace": "res://assets/vendor/kenney_particles/trace_02.png",
}

static var _cache: Dictionary = {}

static func alveolar_texture() -> Texture2D:
	return _load_texture(ALVEOLAR_TEXTURE_PATH)

static func campus_tile(id: StringName) -> Texture2D:
	var path := String(CAMPUS_TILE_PATHS.get(id, ""))
	return _load_texture(path) if not path.is_empty() else null

static func campus_building(id: StringName) -> Texture2D:
	var layers: Array = CAMPUS_BUILDING_LAYERS.get(id, CAMPUS_BUILDING_LAYERS[&"practice"])
	return _composite_vertical_stack("campus:%s" % id, layers)

static func gameplay_sprite(id: StringName) -> Texture2D:
	if not has_gameplay_visual(id):
		return null
	if id == &"doctor":
		return doctor_frame(Vector2.DOWN, 0, false)
	if id == &"bacterial_swarm":
		return _bacterial_swarm_texture()
	if DIRECT_GAMEPLAY_VISUAL_PATHS.has(id):
		return _normalized_texture(String(DIRECT_GAMEPLAY_VISUAL_PATHS[id]), true)
	if GERM_REGIONS.has(id):
		return _cropped_texture_region(GERMS_SHEET_PATH, GERM_REGIONS[id], true)
	return _normalized_texture(ANALYSIS_SAMPLE_PATH, true)

static func has_gameplay_visual(id: StringName) -> bool:
	return not id.is_empty() and (
		id == &"doctor"
		or GERM_REGIONS.has(id)
		or GAMEPLAY_INTERFACE_VISUALS.has(id)
		or DIRECT_GAMEPLAY_VISUAL_PATHS.has(id)
	)

static func doctor_frame(direction: Vector2, frame: int, moving: bool = true) -> Texture2D:
	var row := _doctor_direction_row(direction)
	var safe_frame := posmod(frame, 4) if moving else 0
	var origin := DOCTOR_WALK_ORIGIN + Vector2i(safe_frame * DOCTOR_FRAME_STEP.x, row * DOCTOR_FRAME_STEP.y)
	# The source cells are 32 px apart, while the visible frame is exactly
	# 30 x 29 px. Keep that authored crop exact and only center it on a 30 px
	# square; generic icon safety padding would reintroduce a bloated frame.
	return _exact_square_texture_region(DOCTOR_SHEET_PATH, Rect2i(origin, DOCTOR_FRAME_SIZE))

static func gameplay_batch_texture(id: StringName) -> Texture2D:
	if not has_gameplay_visual(id):
		return null
	if id == &"bacterial_swarm":
		return _bacterial_swarm_texture()
	if DIRECT_GAMEPLAY_VISUAL_PATHS.has(id):
		return _normalized_texture(String(DIRECT_GAMEPLAY_VISUAL_PATHS[id]), true)
	if GERM_REGIONS.has(id):
		return _cropped_texture_region(GERMS_SHEET_PATH, GERM_REGIONS[id], true)
	if id == &"doctor":
		return doctor_frame(Vector2.DOWN, 0, false)
	return _normalized_texture(ANALYSIS_SAMPLE_PATH, true)

static func icon(id: StringName) -> Texture2D:
	var path := String(ICON_PATHS.get(id, ""))
	return _normalized_texture(path, true) if not path.is_empty() else null

static func has_icon(id: StringName) -> bool:
	return ICON_PATHS.has(id)

static func particle(id: StringName) -> Texture2D:
	var path := String(PARTICLE_PATHS.get(id, ""))
	return _load_texture(path) if not path.is_empty() else null

static func _doctor_direction_row(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 0 if direction.x >= 0.0 else 1
	return 3 if direction.y >= 0.0 else 2

static func _composite_vertical_stack(key: String, layers: Array) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var canvas := Image.create(256, 462, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	for layer in layers:
		var texture := _load_texture(String(layer[0]))
		if texture == null:
			continue
		var image := texture.get_image()
		if image == null or image.is_empty():
			continue
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		canvas.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(0, int(layer[1])))
	var used := canvas.get_used_rect()
	if used.size == Vector2i.ZERO:
		return null
	used = used.grow(4).intersection(Rect2i(Vector2i.ZERO, canvas.get_size()))
	var texture := ImageTexture.create_from_image(canvas.get_region(used))
	_cache[key] = texture
	return texture

static func _atlas_region(path: String, grid: Vector2i, index: int) -> AtlasTexture:
	var key := "%s:%d:%d:%d" % [path, grid.x, grid.y, index]
	if _cache.has(key):
		return _cache[key]
	var atlas := _load_texture(path)
	if atlas == null:
		return null
	var cell := Vector2i(atlas.get_width() / grid.x, atlas.get_height() / grid.y)
	var region := AtlasTexture.new()
	region.atlas = atlas
	region.region = Rect2i(Vector2i(index % grid.x, index / grid.x) * cell, cell)
	region.filter_clip = true
	_cache[key] = region
	return region

static func _cropped_atlas_region(path: String, grid: Vector2i, index: int) -> Texture2D:
	var atlas := _load_texture(path)
	if atlas == null:
		return null
	var cell := Vector2i(atlas.get_width() / grid.x, atlas.get_height() / grid.y)
	return _cropped_texture_region(path, Rect2i(Vector2i(index % grid.x, index / grid.x) * cell, cell), false)

static func _cropped_texture_region(path: String, source_rect: Rect2i, pad_square: bool) -> Texture2D:
	var key := "%s:visible:%d:%d:%d:%d:%s" % [path, source_rect.position.x, source_rect.position.y, source_rect.size.x, source_rect.size.y, pad_square]
	if _cache.has(key):
		return _cache[key]
	var atlas := _load_texture(path)
	if atlas == null:
		return null
	var image := atlas.get_image()
	if image == null or image.is_empty():
		return null
	var cropped := image.get_region(source_rect)
	var normalized := _normalize_visible_image(cropped, pad_square)
	var texture := ImageTexture.create_from_image(normalized)
	_cache[key] = texture
	return texture

static func _exact_square_texture_region(path: String, source_rect: Rect2i) -> Texture2D:
	var key := "%s:exact-square:%d:%d:%d:%d" % [path, source_rect.position.x, source_rect.position.y, source_rect.size.x, source_rect.size.y]
	if _cache.has(key):
		return _cache[key]
	var atlas := _load_texture(path)
	if atlas == null:
		return null
	var image := atlas.get_image()
	if image == null or image.is_empty():
		return null
	var content := image.get_region(source_rect)
	if content.get_format() != Image.FORMAT_RGBA8:
		content.convert(Image.FORMAT_RGBA8)
	var edge := maxi(content.get_width(), content.get_height())
	var canvas := Image.create(edge, edge, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var offset := Vector2i((edge - content.get_width()) / 2, (edge - content.get_height()) / 2)
	canvas.blend_rect(content, Rect2i(Vector2i.ZERO, content.get_size()), offset)
	var texture := ImageTexture.create_from_image(canvas)
	_cache[key] = texture
	return texture


## One shared-health event body composed from the existing documented
## pneumococcus sprite. This stays presentation-only: no child entities, nodes
## or additional simulation loops are created for the visible swarm.
static func _bacterial_swarm_texture() -> Texture2D:
	const CACHE_KEY := "gameplay:bacterial_swarm"
	if _cache.has(CACHE_KEY):
		return _cache[CACHE_KEY]
	var source_texture := _cropped_texture_region(GERMS_SHEET_PATH, GERM_REGIONS[&"pneumococcus"], true)
	if source_texture == null:
		return null
	var source := source_texture.get_image()
	if source == null or source.is_empty():
		return null
	if source.get_format() != Image.FORMAT_RGBA8:
		source.convert(Image.FORMAT_RGBA8)
	var canvas := Image.create(256, 224, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var placements := [
		[Vector2i(91, 2), 68], [Vector2i(139, 18), 62],
		[Vector2i(45, 34), 72], [Vector2i(96, 48), 70], [Vector2i(158, 54), 66],
		[Vector2i(20, 91), 67], [Vector2i(71, 99), 72], [Vector2i(129, 104), 69], [Vector2i(178, 104), 61],
		[Vector2i(50, 151), 65], [Vector2i(108, 151), 70], [Vector2i(161, 150), 62],
	]
	for placement in placements:
		var image := source.duplicate()
		var edge := int(placement[1])
		image.resize(edge, edge, Image.INTERPOLATE_LANCZOS)
		canvas.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), placement[0])
	var texture := ImageTexture.create_from_image(_normalize_visible_image(canvas, true))
	_cache[CACHE_KEY] = texture
	return texture

static func _normalized_texture(path: String, pad_square: bool) -> Texture2D:
	var key := "%s:normalized:%s" % [path, pad_square]
	if _cache.has(key):
		return _cache[key]
	var source := _load_texture(path)
	if source == null:
		return null
	var image := source.get_image()
	if image == null or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(_normalize_visible_image(image, pad_square))
	_cache[key] = texture
	return texture

static func _normalize_visible_image(source: Image, pad_square: bool = true) -> Image:
	var working := source.duplicate()
	if working.get_format() != Image.FORMAT_RGBA8:
		working.convert(Image.FORMAT_RGBA8)
	var visible := _alpha_bounds(working, ALPHA_THRESHOLD)
	if visible.size == Vector2i.ZERO:
		return working
	# Crop to the visible body first. Growing this rectangle at an atlas edge can
	# add padding on only one side and was the cause of visibly off-centre icons.
	# The square target canvas below provides the symmetric safety padding.
	var content: Image = working.get_region(visible)
	if content.get_format() != Image.FORMAT_RGBA8:
		content.convert(Image.FORMAT_RGBA8)

	var target_size: Vector2i = content.get_size()
	if pad_square:
		var content_edge := maxi(target_size.x, target_size.y)
		var padded_edge := ceili(float(content_edge) / (1.0 - SAFE_PADDING_RATIO * 2.0))
		target_size = Vector2i.ONE * maxi(content_edge, padded_edge)
	else:
		target_size.x = ceili(float(target_size.x) / (1.0 - SAFE_PADDING_RATIO * 2.0))
		target_size.y = ceili(float(target_size.y) / (1.0 - SAFE_PADDING_RATIO * 2.0))

	var canvas := Image.create(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	var offset := Vector2i(
		(target_size.x - content.get_width()) / 2,
		(target_size.y - content.get_height()) / 2
	)
	canvas.blend_rect(content, Rect2i(Vector2i.ZERO, content.get_size()), offset)
	return canvas

static func _alpha_bounds(image: Image, threshold: int = ALPHA_THRESHOLD) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	var alpha_cutoff := float(clampi(threshold, 0, 255)) / 255.0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= alpha_cutoff:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)

static func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if not _cache.has(path):
		_cache[path] = load(path) as Texture2D
	return _cache[path]
