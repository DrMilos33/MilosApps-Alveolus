class_name SimpleIcon
extends Control

const GLYPH_ARTBOARD := 52.0
const IMPORTED_GLYPH_EXTENT := 0.76
const DRAWN_KINDS: Array[StringName] = [
	&"back", &"play", &"story", &"lexicon", &"clock", &"boss", &"clinic", &"offline",
	&"passive_research", &"antibiotic", &"automatic_therapy", &"treatment", &"immune",
	&"neutrophil_orbit", &"support", &"supportive_oxygenation", &"practice", &"research",
	&"archive", &"levels", &"settings", &"stability_reserve", &"therapy_precision", &"treatment_precision", &"preanalysis",
	&"second_opinion", &"analysis", &"analysis_pickup", &"sample", &"sample_logistics",
	&"reaction", &"finding", &"finding_progress", &"plan", &"components", &"ability",
	&"passive", &"reserve", &"treatment_spread", &"treatment_pierce",
	&"ability_focus_field", &"ability_emergency_support", &"ability_defense_burst",
	&"ability_treatment_line", &"ability_protection_field", &"ability_sample_pull",
	&"unlock_spread_treatment", &"unlock_piercing_treatment", &"unlock_defense_burst",
	&"unlock_treatment_line", &"unlock_protection_field", &"unlock_sample_pull", &"quick_test",
	&"reserve_buffer", &"defense_readiness", &"deployment_routine",
	&"locked", &"check", &"remove", &"restart", &"diamond", &"circle", &"target",
]

static var _missing_warnings: Dictionary = {}

var kind: StringName = &"practice"
var accent: Color = Color("58dacb")
var framed: bool = false

func configure(icon_kind: StringName, color: Color, with_frame: bool = false) -> void:
	kind = icon_kind
	accent = color
	framed = with_frame
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_framed(enabled: bool) -> void:
	framed = enabled
	queue_redraw()

static func supports(icon_kind: StringName) -> bool:
	return VisualAssetCatalog.has_icon(icon_kind) or DRAWN_KINDS.has(icon_kind)

func _draw() -> void:
	var center := size * 0.5
	var minimum_extent := minf(size.x, size.y)
	if framed:
		_draw_medallion(center, minimum_extent * 0.44)

	var imported := VisualAssetCatalog.icon(kind)
	if imported != null:
		var icon_size := Vector2.ONE * minimum_extent * IMPORTED_GLYPH_EXTENT
		draw_texture_rect(imported, Rect2(center - icon_size * 0.5, icon_size), false, accent)
		return

	draw_set_transform(center, 0.0, Vector2.ONE * (minimum_extent / GLYPH_ARTBOARD))
	match kind:
		&"back":
			draw_line(Vector2(14, -16), Vector2(-4, 0), accent, 3.0, true)
			draw_line(Vector2(-4, 0), Vector2(14, 16), accent, 3.0, true)
			draw_line(Vector2(-3, 0), Vector2(19, 0), accent, 3.0, true)
		&"play":
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -17), Vector2(17, 0), Vector2(-10, 17)]), accent)
		&"story", &"lexicon":
			_draw_book()
		&"clock":
			_draw_clock()
		&"diamond":
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -13), Vector2(13, 0), Vector2(0, 13), Vector2(-13, 0)
			]), accent)
		&"circle":
			draw_circle(Vector2.ZERO, 8.0, accent)
		&"boss":
			_draw_boss()
		&"clinic":
			draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 28, accent, 2.5, true)
			_draw_cross(Vector2.ZERO)
		&"offline":
			draw_arc(Vector2(-4, -2), 14.0, PI * 0.18, PI * 1.72, 22, accent, 2.5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(9, -13), Vector2(18, -12), Vector2(14, -4)]), accent)
		&"passive_research":
			_draw_flask(Vector2(-6, 0))
			_draw_clock(Vector2(11, -7), 8.0)
			_draw_spark(Vector2(18, 10), 3.0)
		&"antibiotic", &"automatic_therapy", &"treatment":
			_draw_treatment_capsule()
		&"immune", &"neutrophil_orbit":
			_draw_immune()
		&"support", &"supportive_oxygenation":
			_draw_support()
		&"practice":
			_draw_practice()
		&"research":
			_draw_flask()
		&"archive", &"levels":
			_draw_archive()
		&"settings":
			_draw_settings()
		&"stability_reserve":
			_draw_shield()
			_draw_cross(Vector2.ZERO, 0.72)
		&"therapy_precision", &"treatment_precision", &"target":
			_draw_target()
		&"analysis", &"analysis_pickup", &"sample":
			_draw_sample_vial()
		&"sample_logistics":
			_draw_sample_vial()
			_draw_inward_arrows()
		&"preanalysis", &"finding":
			_draw_finding(false)
		&"finding_progress":
			_draw_finding(true)
		&"second_opinion", &"reaction":
			_draw_reaction()
		&"plan":
			_draw_plan()
		&"components":
			_draw_components()
		&"ability":
			_draw_ability()
		&"passive":
			_draw_passive()
		&"reserve":
			_draw_reserve()
		&"treatment_spread", &"unlock_spread_treatment":
			_draw_treatment_spread()
		&"treatment_pierce", &"unlock_piercing_treatment":
			_draw_treatment_pierce()
		&"ability_focus_field":
			_draw_target()
			draw_arc(Vector2.ZERO, 21.0, -PI * 0.30, PI * 0.30, 10, Color(accent, 0.58), 2.0, true)
		&"ability_emergency_support":
			_draw_shield()
			_draw_cross(Vector2.ZERO, 0.68)
		&"ability_defense_burst", &"unlock_defense_burst":
			_draw_ability_burst()
		&"ability_treatment_line", &"unlock_treatment_line":
			_draw_treatment_line()
		&"ability_protection_field", &"unlock_protection_field":
			_draw_shield()
			draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 28, Color(accent, 0.58), 2.0, true)
		&"ability_sample_pull", &"unlock_sample_pull":
			_draw_sample_vial()
			_draw_inward_arrows()
		&"quick_test":
			_draw_finding(true)
			_draw_spark(Vector2(15, -15), 3.5)
		&"reserve_buffer":
			_draw_shield()
			_draw_spark(Vector2(15, -14), 3.5)
		&"defense_readiness":
			_draw_immune()
			_draw_spark(Vector2(15, -15), 3.5)
		&"deployment_routine":
			_draw_clock()
			_draw_spark(Vector2(16, -15), 3.5)
		&"locked":
			_draw_lock()
		&"check":
			draw_line(Vector2(-17, 1), Vector2(-5, 13), accent, 4.0, true)
			draw_line(Vector2(-5, 13), Vector2(18, -14), accent, 4.0, true)
		&"remove":
			draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 30, accent, 2.4, true)
			draw_line(Vector2(-10, 0), Vector2(10, 0), accent, 3.2, true)
		&"restart":
			draw_arc(Vector2.ZERO, 17.0, -PI * 0.15, PI * 1.45, 28, accent, 2.8, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-17, -11), Vector2(-20, 1), Vector2(-8, -2)]), accent)
		_:
			_draw_missing()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_medallion(center: Vector2, radius: float) -> void:
	draw_circle(center + Vector2(0.0, 2.0), radius, Color(AlveolusVisualTheme.PETROL, 0.14))
	draw_circle(center, radius, AlveolusVisualTheme.IVORY)
	draw_arc(center, radius - 0.8, 0.0, TAU, 36, Color(accent, 0.54), 1.6, true)

func _draw_book() -> void:
	draw_polyline(PackedVector2Array([Vector2(-19, -14), Vector2(-3, -9), Vector2(-3, 16), Vector2(-19, 10), Vector2(-19, -14)]), accent, 2.5, true)
	draw_polyline(PackedVector2Array([Vector2(19, -14), Vector2(3, -9), Vector2(3, 16), Vector2(19, 10), Vector2(19, -14)]), accent, 2.5, true)
	draw_line(Vector2(0, -8), Vector2(0, 17), Color(accent, 0.70), 2.0, true)

func _draw_clock(offset: Vector2 = Vector2.ZERO, radius: float = 17.0) -> void:
	draw_arc(offset, radius, 0.0, TAU, 28, accent, 2.5, true)
	draw_line(offset, offset + Vector2(0, -radius * 0.58), accent, 2.5, true)
	draw_line(offset, offset + Vector2(radius * 0.52, radius * 0.30), accent, 2.5, true)

func _draw_boss() -> void:
	draw_circle(Vector2.ZERO, 13.0, Color(accent, 0.18))
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, accent, 2.5, true)
	for index in range(6):
		draw_circle(Vector2.from_angle(TAU * index / 6.0) * 18.0, 3.5, accent)

func _draw_flask(offset: Vector2 = Vector2.ZERO) -> void:
	draw_line(offset + Vector2(-7, -17), offset + Vector2(-7, 3), accent, 2.7, true)
	draw_line(offset + Vector2(7, -17), offset + Vector2(7, 3), accent, 2.7, true)
	draw_line(offset + Vector2(-7, -17), offset + Vector2(7, -17), accent, 2.7, true)
	var flask := PackedVector2Array([offset + Vector2(-7, 2), offset + Vector2(-14, 17), offset + Vector2(14, 17), offset + Vector2(7, 2)])
	draw_colored_polygon(flask, Color(accent, 0.24))
	draw_polyline(PackedVector2Array([flask[0], flask[1], flask[2], flask[3]]), accent, 2.2, true)

func _draw_treatment_capsule() -> void:
	draw_line(Vector2(-14, 14), Vector2(14, -14), accent, 10.0, true)
	draw_line(Vector2(-4, 4), Vector2(4, 4), Color(AlveolusVisualTheme.PETROL, 0.78), 2.0, true)
	draw_line(Vector2(-21, 15), Vector2(-16, 10), Color(accent, 0.45), 2.0, true)
	draw_line(Vector2(-17, 19), Vector2(-12, 14), Color(accent, 0.45), 2.0, true)

func _draw_immune() -> void:
	draw_circle(Vector2.ZERO, 11.0, Color(accent, 0.25))
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 28, accent, 2.5, true)
	for index in range(5):
		draw_circle(Vector2.from_angle(TAU * index / 5.0) * 18.0, 3.0, accent)

func _draw_support() -> void:
	draw_arc(Vector2(-8, 5), 9.0, 0.0, TAU, 20, accent, 2.5, true)
	draw_arc(Vector2(7, -7), 12.0, 0.0, TAU, 20, accent, 2.5, true)
	draw_arc(Vector2(14, 13), 5.5, 0.0, TAU, 16, accent, 2.0, true)

func _draw_practice() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -5), Vector2(0, -18), Vector2(18, -5)]), Color(accent, 0.25))
	draw_rect(Rect2(-15, -5, 30, 22), Color(accent, 0.12), true)
	draw_rect(Rect2(-15, -5, 30, 22), accent, false, 2.0)
	_draw_cross(Vector2.ZERO)

func _draw_archive() -> void:
	for y in [-12.0, 0.0, 12.0]:
		draw_circle(Vector2(-14, y), 3.0, accent)
		draw_line(Vector2(-6, y), Vector2(16, y), accent, 2.0, true)

func _draw_settings() -> void:
	draw_circle(Vector2.ZERO, 14.0, Color(accent, 0.20))
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, accent, 3.0, true)
	draw_circle(Vector2.ZERO, 5.0, accent)

func _draw_shield() -> void:
	var shield := PackedVector2Array([Vector2(0, -19), Vector2(16, -11), Vector2(13, 9), Vector2(0, 19), Vector2(-13, 9), Vector2(-16, -11)])
	draw_colored_polygon(shield, Color(accent, 0.18))
	draw_polyline(PackedVector2Array([shield[0], shield[1], shield[2], shield[3], shield[4], shield[5], shield[0]]), accent, 2.2, true)

func _draw_lock() -> void:
	draw_arc(Vector2(0, -7), 10.0, PI, TAU, 20, accent, 2.8, true)
	draw_rect(Rect2(-14, -4, 28, 22), Color(accent, 0.18), true)
	draw_rect(Rect2(-14, -4, 28, 22), accent, false, 2.4)
	draw_circle(Vector2(0, 6), 2.8, accent)

func _draw_target() -> void:
	for radius in [17.0, 10.0, 3.5]:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, accent, 2.0, true)
	draw_line(Vector2(-21, 0), Vector2(21, 0), Color(accent, 0.55), 1.0)
	draw_line(Vector2(0, -21), Vector2(0, 21), Color(accent, 0.55), 1.0)

func _draw_sample_vial() -> void:
	draw_rect(Rect2(-10, -18, 20, 7), Color(accent, 0.32), true)
	draw_rect(Rect2(-10, -18, 20, 7), accent, false, 2.2)
	var vial := PackedVector2Array([Vector2(-7, -11), Vector2(-7, 11), Vector2(-4, 17), Vector2(4, 17), Vector2(7, 11), Vector2(7, -11)])
	draw_colored_polygon(vial, Color(accent, 0.13))
	draw_polyline(PackedVector2Array([vial[0], vial[1], vial[2], vial[3], vial[4], vial[5]]), accent, 2.3, true)
	draw_rect(Rect2(-5, 5, 10, 8), Color(accent, 0.58), true)
	draw_circle(Vector2(0, 9), 2.4, accent.lightened(0.18))

func _draw_inward_arrows() -> void:
	for direction in [-1.0, 1.0]:
		var start := Vector2(21.0 * direction, 0)
		var end := Vector2(12.0 * direction, 0)
		draw_line(start, end, accent, 2.0, true)
		draw_line(end, end + Vector2(4.0 * direction, -4), accent, 2.0, true)
		draw_line(end, end + Vector2(4.0 * direction, 4), accent, 2.0, true)

func _draw_finding(show_progress: bool) -> void:
	draw_arc(Vector2(-4, -4), 11.0, 0.0, TAU, 24, accent, 2.8, true)
	draw_circle(Vector2(-4, -4), 3.2, Color(accent, 0.55))
	draw_line(Vector2(4, 4), Vector2(17, 17), accent, 3.5, true)
	if show_progress:
		draw_arc(Vector2(-4, -4), 17.0, -PI * 0.5, PI * 0.80, 18, Color(accent, 0.68), 2.2, true)

func _draw_reaction() -> void:
	draw_line(Vector2(-19, 0), Vector2(-4, 0), accent, 3.0, true)
	draw_circle(Vector2(-4, 0), 3.5, accent)
	draw_line(Vector2(-1, -2), Vector2(14, -15), accent, 3.0, true)
	draw_line(Vector2(-1, 2), Vector2(14, 15), accent, 3.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(12, -19), Vector2(21, -14), Vector2(12, -9)]), accent)
	draw_colored_polygon(PackedVector2Array([Vector2(12, 9), Vector2(21, 14), Vector2(12, 19)]), Color(accent, 0.55))

func _draw_plan() -> void:
	draw_rect(Rect2(-15, -18, 30, 36), Color(accent, 0.12), true)
	draw_rect(Rect2(-15, -18, 30, 36), accent, false, 2.2)
	for y in [-9.0, 0.0, 9.0]:
		draw_circle(Vector2(-8, y), 2.0, accent)
		draw_line(Vector2(-3, y), Vector2(9, y), accent, 2.0, true)

func _draw_components() -> void:
	for point in [Vector2(0, -13), Vector2(-13, 10), Vector2(13, 10)]:
		draw_circle(point, 7.0, Color(accent, 0.18))
		draw_arc(point, 7.0, 0.0, TAU, 18, accent, 2.0, true)
	for endpoint in [Vector2(0, -6), Vector2(-7, 6), Vector2(7, 6)]:
		draw_line(Vector2.ZERO, endpoint, Color(accent, 0.62), 2.0, true)

func _draw_ability() -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var radius := 19.0 if index % 2 == 0 else 8.0
		points.append(Vector2.from_angle(TAU * index / 16.0) * radius)
	draw_colored_polygon(points, Color(accent, 0.24))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, accent, 2.0, true)

func _draw_passive() -> void:
	draw_arc(Vector2(-8, 0), 10.0, -PI * 0.75, PI * 0.75, 18, accent, 2.5, true)
	draw_arc(Vector2(8, 0), 10.0, PI * 0.25, PI * 1.75, 18, accent, 2.5, true)
	draw_circle(Vector2.ZERO, 3.0, Color(accent, 0.38))

func _draw_reserve() -> void:
	draw_rect(Rect2(-17, -12, 34, 27), Color(accent, 0.13), true)
	draw_rect(Rect2(-17, -12, 34, 27), accent, false, 2.3)
	draw_line(Vector2(-17, -3), Vector2(17, -3), accent, 2.0, true)
	draw_rect(Rect2(-5, -17, 10, 9), Color(accent, 0.30), true)
	draw_rect(Rect2(-5, -17, 10, 9), accent, false, 2.0)

func _draw_treatment_spread() -> void:
	for end in [Vector2(18, -13), Vector2(21, 0), Vector2(18, 13)]:
		draw_line(Vector2(-15, 0), end, accent, 3.0, true)
		draw_circle(end, 3.2, Color(accent, 0.72))
	draw_circle(Vector2(-15, 0), 5.0, Color(accent, 0.26))

func _draw_treatment_pierce() -> void:
	draw_line(Vector2(-20, 0), Vector2(17, 0), accent, 3.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(13, -6), Vector2(22, 0), Vector2(13, 6)]), accent)
	for x in [-10.0, 3.0]:
		draw_arc(Vector2(x, 0), 6.0, 0.0, TAU, 16, Color(accent, 0.70), 2.0, true)

func _draw_ability_burst() -> void:
	draw_circle(Vector2.ZERO, 8.0, Color(accent, 0.30))
	for index in range(8):
		var direction := Vector2.from_angle(TAU * index / 8.0)
		draw_line(direction * 10.0, direction * 21.0, accent, 2.8, true)

func _draw_treatment_line() -> void:
	draw_line(Vector2(-21, 8), Vector2(14, -8), accent, 4.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(10, -13), Vector2(22, -12), Vector2(15, -2)]), accent)
	draw_line(Vector2(-19, 14), Vector2(16, -2), Color(accent, 0.35), 2.0, true)

func _draw_spark(center: Vector2, radius: float) -> void:
	draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), accent, 1.8, true)
	draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), accent, 1.8, true)

func _draw_missing() -> void:
	if not _missing_warnings.has(kind):
		_missing_warnings[kind] = true
		push_warning("SimpleIcon has no registered glyph for '%s'." % kind)
	draw_rect(Rect2(-15, -15, 30, 30), Color(accent, 0.10), true)
	draw_rect(Rect2(-15, -15, 30, 30), accent, false, 2.0)
	draw_line(Vector2(-10, -10), Vector2(10, 10), accent, 2.5, true)
	draw_line(Vector2(10, -10), Vector2(-10, 10), accent, 2.5, true)

func _draw_cross(offset: Vector2, scale_factor: float = 1.0) -> void:
	draw_rect(Rect2(offset + Vector2(-3, -11) * scale_factor, Vector2(6, 22) * scale_factor), accent, true)
	draw_rect(Rect2(offset + Vector2(-11, -3) * scale_factor, Vector2(22, 6) * scale_factor), accent, true)
