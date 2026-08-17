class_name MedicalLexiconIllustration
extends Control

const ARTBOARD_DIAMETER := 66.0
const SAFE_MARGIN := 4.0

var entry_id: StringName = &""
var accent: Color = Color("58dacb")
var locked: bool = false

func configure(id: StringName, color: Color) -> void:
	entry_id = id
	accent = color
	queue_redraw()

func set_locked(value: bool) -> void:
	locked = value
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var available_diameter := maxf(1.0, minf(size.x, size.y) - SAFE_MARGIN * 2.0)
	var visual_scale := minf(1.0, available_diameter / ARTBOARD_DIAMETER)
	draw_set_transform(center, 0.0, Vector2.ONE * visual_scale)
	var local_center := Vector2.ZERO
	var color := Color(accent, 0.18) if locked else accent
	var soft := Color(color, 0.14 if not locked else 0.05)
	draw_circle(local_center + Vector2(0.0, 3.0), 33.0, Color(AlveolusVisualTheme.PETROL_DEEP, 0.42))
	draw_circle(local_center, 33.0, Color(AlveolusVisualTheme.PETROL_DEEP, 0.90))
	draw_arc(local_center, 32.0, 0.0, TAU, 40, Color(accent, 0.48), 1.5, true)
	draw_circle(local_center, 29.0, soft)
	var sprite := _sprite_for_entry()
	if sprite != null:
		var sprite_color := Color(0.42, 0.47, 0.48, 0.32) if locked else Color.WHITE
		_draw_visible_texture_centered(sprite, local_center, Vector2.ONE * 56.0, sprite_color)
		_draw_lock_mark(local_center)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var icon := _icon_for_entry()
	if icon != null:
		draw_texture_rect(icon, Rect2(local_center - Vector2.ONE * 17.0, Vector2.ONE * 34.0), false, color)
		_draw_lock_mark(local_center)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	match entry_id:
		&"pneumococcus":
			_draw_pneumococcus(local_center, color)
		&"bacterial_cluster":
			for offset in [Vector2(-14, -8), Vector2(11, -12), Vector2(-9, 12), Vector2(15, 10)]:
				draw_circle(local_center + offset, 10.0, color)
		&"infection_focus":
			draw_circle(local_center, 22.0, color)
			for index in range(8):
				draw_circle(local_center + Vector2.from_angle(TAU * index / 8.0) * 18.0, 5.5, color.lightened(0.15))
		&"analysis_pickup":
			var diamond := PackedVector2Array([local_center + Vector2(0, -22), local_center + Vector2(18, 0), local_center + Vector2(0, 22), local_center + Vector2(-18, 0)])
			draw_colored_polygon(diamond, color)
			draw_circle(local_center, 5.0, Color("eaf7ff", color.a))
		&"patient_stability":
			draw_rect(Rect2(local_center - Vector2(7, 24), Vector2(14, 48)), color, true)
			draw_rect(Rect2(local_center - Vector2(24, 7), Vector2(48, 14)), color, true)
		&"automatic_therapy":
			# A clearly moving treatment capsule instead of the unrelated target icon.
			draw_line(local_center + Vector2(-27, -9), local_center + Vector2(-17, -9), Color(color, color.a * 0.45), 2.0, true)
			draw_line(local_center + Vector2(-29, 0), local_center + Vector2(-15, 0), Color(color, color.a * 0.70), 3.0, true)
			draw_line(local_center + Vector2(-27, 9), local_center + Vector2(-17, 9), Color(color, color.a * 0.45), 2.0, true)
			draw_set_transform(center + Vector2(5, 0) * visual_scale, -0.42, Vector2.ONE * visual_scale)
			draw_rect(Rect2(-18, -8, 36, 16), Color(color, color.a * 0.18), true)
			draw_arc(Vector2(-18, 0), 8.0, PI * 0.5, PI * 1.5, 14, color, 3.0, true)
			draw_arc(Vector2(18, 0), 8.0, -PI * 0.5, PI * 0.5, 14, color, 3.0, true)
			draw_line(Vector2(0, -8), Vector2(0, 8), color, 2.0, true)
			draw_set_transform(center, 0.0, Vector2.ONE * visual_scale)
		&"neutrophil_orbit":
			draw_circle(local_center, 8.0, color)
			draw_arc(local_center, 25.0, 0.0, TAU, 28, Color(color, color.a * 0.65), 2.0, true)
			draw_circle(local_center + Vector2(25, 0), 7.0, color)
			draw_circle(local_center - Vector2(25, 0), 7.0, color)
		&"supportive_oxygenation":
			for data in [[Vector2(-13, 10), 10.0], [Vector2(7, -10), 13.0], [Vector2(18, 15), 7.0]]:
				draw_arc(local_center + data[0], data[1], 0.0, TAU, 20, color, 3.0, true)
		&"boss_phases":
			for radius in [9.0, 18.0, 27.0]:
				draw_arc(local_center, radius, -PI * 0.70, PI * 0.45, 18, color, 4.0, true)
		&"research_reward":
			draw_line(local_center + Vector2(-8, -24), local_center + Vector2(-8, 2), color, 4.0, true)
			draw_line(local_center + Vector2(8, -24), local_center + Vector2(8, 2), color, 4.0, true)
			var flask := PackedVector2Array([local_center + Vector2(-8, 0), local_center + Vector2(-23, 24), local_center + Vector2(23, 24), local_center + Vector2(8, 0)])
			draw_colored_polygon(flask, Color(color, color.a * 0.72))
		_:
			draw_circle(local_center, 20.0, color)
	_draw_lock_mark(local_center)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _sprite_for_entry() -> Texture2D:
	match entry_id:
		&"pneumococcus":
			return VisualAssetCatalog.gameplay_sprite(&"pneumococcus")
		&"bacterial_cluster":
			return VisualAssetCatalog.gameplay_sprite(&"bacterial_cluster")
		&"infection_focus", &"boss_phases":
			return VisualAssetCatalog.gameplay_sprite(&"infection_focus")
		&"analysis_pickup":
			return VisualAssetCatalog.gameplay_sprite(&"analysis_pickup")
		&"neutrophil_orbit":
			return VisualAssetCatalog.gameplay_sprite(&"immune_cell")
		&"character_stats":
			return VisualAssetCatalog.gameplay_sprite(&"doctor")
	return null

func _icon_for_entry() -> Texture2D:
	match entry_id:
		&"patient_stability":
			return VisualAssetCatalog.icon(&"plus")
		&"research_reward":
			return VisualAssetCatalog.icon(&"star")
	return null

func _draw_visible_texture_centered(texture: Texture2D, center: Vector2, maximum_size: Vector2, tint: Color) -> void:
	var layout := centered_texture_layout(texture, center, maximum_size)
	if layout.is_empty():
		draw_texture_rect(texture, Rect2(center - maximum_size * 0.5, maximum_size), false, tint)
		return
	draw_texture_rect_region(texture, layout["target"], layout["source"], tint)

func centered_texture_layout(texture: Texture2D, center: Vector2, maximum_size: Vector2) -> Dictionary:
	if texture == null:
		return {}
	var image := texture.get_image()
	if image == null or image.is_empty():
		return {}
	var used := image.get_used_rect()
	if used.size == Vector2i.ZERO:
		return {}
	var source_size := Vector2(used.size)
	var scale_factor := minf(maximum_size.x / source_size.x, maximum_size.y / source_size.y)
	var target_size := source_size * scale_factor
	return {
		"source": Rect2(Vector2(used.position), source_size),
		"target": Rect2(center - target_size * 0.5, target_size),
	}

func _draw_lock_mark(center: Vector2) -> void:
	if locked:
		draw_line(center + Vector2(-20, -20), center + Vector2(20, 20), Color("789096"), 3.0, true)
		draw_line(center + Vector2(20, -20), center + Vector2(-20, 20), Color("789096"), 3.0, true)

func _draw_pneumococcus(center: Vector2, color: Color) -> void:
	draw_circle(center + Vector2(-10, 0), 14.0, color)
	draw_circle(center + Vector2(10, 0), 14.0, color.darkened(0.10))
	draw_arc(center, 27.0, 0.0, TAU, 24, Color(color.lightened(0.22), color.a * 0.65), 2.0, true)
