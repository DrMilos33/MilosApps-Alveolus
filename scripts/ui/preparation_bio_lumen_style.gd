class_name PreparationBioLumenStyle
extends RefCounted

## Planning-only Bio-Lumen surface family matching the approved deployment mockup.
## Keeping it separate prevents this focused trial from reskinning unrelated screens.

const FRAME_LEFT_BG := Color("0b3b3d")
const FRAME_RIGHT_BG := Color("061f26")
const FRAME_FLAT_FALLBACK := Color("082d32")
const INSET_BG := Color("041d23")
const CARD_BORDER := Color("3e9290")
const FOCUS_TURQUOISE := Color("6fe7dc")
const LOCKED_BORDER := Color("718486")
const MOCKUP_GOLD := Color("f0bc57")

static func frame(accent: Color = Color("5ac5c1")) -> StyleBoxFlat:
	# StyleBoxFlat cannot render the approved #0d3b40 -> #07252c gradient.
	# Its midpoint is the stable fallback below; card gradients remain shader-backed.
	var style := _signature_base(FRAME_FLAT_FALLBACK, Color(accent, 0.40), 1, 17, 5)
	style.shadow_color = Color(AlveolusVisualTheme.PETROL_DEEP, 0.32)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 1.0)
	return style

static func loadout_rack() -> StyleBoxFlat:
	var style := _signature_base(Color("082c31"), Color(MOCKUP_GOLD, 0.46), 1, 17, 5)
	style.shadow_color = Color(AlveolusVisualTheme.PETROL_DEEP, 0.38)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0.0, 1.0)
	return style

static func instrument_bay() -> StyleBoxFlat:
	var style := _signature_base(FRAME_FLAT_FALLBACK, Color("5ac5c1", 0.52), 1, 17, 5)
	style.shadow_color = Color(AlveolusVisualTheme.PETROL_DEEP, 0.30)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 1.0)
	return style

static func dossier() -> StyleBoxFlat:
	var style := _signature_base(FRAME_FLAT_FALLBACK, Color("5ac5c1", 0.38), 1, 17, 5)
	style.shadow_size = 0
	return style

static func slot(state: StringName, selected: bool = false) -> StyleBoxFlat:
	var background := Color.TRANSPARENT
	var border := Color(CARD_BORDER, 0.92)
	var width := 1
	match state:
		&"hover":
			border = Color("55d9ce", 0.72)
		&"pressed":
			border = Color("55d9ce", 0.60)
		&"focus":
			# Selection stays gold in the normal layer; focus is an independent
			# turquoise overlay for keyboard and gamepad navigation.
			border = FOCUS_TURQUOISE
			width = 2
		&"disabled":
			border = Color(LOCKED_BORDER, 0.22)
	if selected and state not in [&"focus", &"disabled"]:
		border = MOCKUP_GOLD
		width = 2
	var style := _with_insets(_signature_base(background, border, width, 15, 5), 14.0, 8.0)
	return style

static func candidate(state: StringName, available: bool, assigned: bool = false) -> StyleBoxFlat:
	var background := Color.TRANSPARENT
	var border := Color(CARD_BORDER, 0.92)
	var width := 1
	if not available:
		border = Color(LOCKED_BORDER, 0.30 if assigned else 0.24)
	match state:
		&"hover":
			border = Color("55d9ce", 0.72) if available else Color(LOCKED_BORDER, 0.34)
		&"pressed":
			border = Color("55d9ce", 0.60) if available else Color(LOCKED_BORDER, 0.30)
		&"focus":
			# Locked and assigned cards remain inspectable, so their navigation
			# focus must be just as visible as an available card's focus.
			border = FOCUS_TURQUOISE
			width = 2
		&"disabled":
			border = Color(LOCKED_BORDER, 0.20)
	return _with_insets(_signature_base(background, border, width, 15, 5), 12.0, 8.0)

static func inspector() -> StyleBoxFlat:
	return _signature_base(Color(INSET_BG, 0.98), Color("5bbebc", 0.23), 1, 12, 4)

static func tooltip() -> StyleBoxFlat:
	var style := _with_insets(_signature_base(Color("03181e", 0.985), Color("5ccac4", 0.58), 1, 12, 4), 0.0, 0.0)
	style.shadow_color = Color("020d11", 0.72)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 4.0)
	return style

static func navigation(state: StringName) -> StyleBoxFlat:
	var background := Color.TRANSPARENT
	var border := Color(CARD_BORDER, 0.46)
	var width := 1
	match state:
		&"hover":
			border = Color("66ded5", 0.84)
		&"pressed":
			border = Color("4ab8b3", 0.72)
		&"focus":
			border = FOCUS_TURQUOISE
			width = 2
		&"disabled":
			border = Color(LOCKED_BORDER, 0.20)
	return _with_insets(_signature_base(background, border, width, 12, 4), 18.0, 10.0)

static func remove_action(state: StringName) -> StyleBoxFlat:
	var background := Color("321f24", 0.72)
	var border := Color("ef7766", 0.58)
	var width := 1
	match state:
		&"hover":
			background = Color("4a292d", 0.88)
			border = Color("ff8b7a", 0.92)
		&"pressed":
			background = Color("27191e", 0.90)
		&"focus":
			border = FOCUS_TURQUOISE
			width = 2
		&"disabled":
			background = Color("1d2024", 0.45)
			border = Color(LOCKED_BORDER, 0.18)
	return _with_insets(_signature_base(background, border, width, 11, 4), 14.0, 8.0)

static func inline_remove_action(state: StringName) -> StyleBoxFlat:
	# Header action: intentionally lighter than a full button. It occupies a
	# stable reserved slot and communicates interaction through a quiet surface
	# change instead of a permanent frame.
	var background := Color.TRANSPARENT
	match state:
		&"hover":
			background = Color("ef7766", 0.12)
		&"pressed":
			background = Color("ef7766", 0.20)
		&"focus":
			background = Color("51d6cb", 0.13)
		&"disabled":
			background = Color.TRANSPARENT
	return _with_insets(_signature_base(background, Color.TRANSPARENT, 0, 7, 3), 4.0, 2.0)

static func chip(accent: Color) -> StyleBoxFlat:
	var style := _signature_base(Color("041d23", 0.72), Color(accent, 0.24), 1, 12, 4)
	return _with_insets(style, 8.0, 5.0)

static func capacity_chip(available: bool, quiet: bool = false) -> StyleBoxFlat:
	var background := Color("061c22", 0.88)
	var border := Color(MOCKUP_GOLD, 0.54)
	if quiet:
		border = Color(LOCKED_BORDER, 0.28)
	elif not available:
		background = Color("061b20", 0.58)
		border = Color(LOCKED_BORDER, 0.22)
	return _with_insets(_signature_base(background, border, 1, 10, 4), 8.0, 4.0)

static func primary(state: StringName) -> StyleBoxFlat:
	var border := Color("5ce0d4")
	var width := 1
	match state:
		&"hover":
			border = Color("75e8de")
			width = 2
		&"pressed":
			border = Color("50c9c0")
		&"focus":
			border = FOCUS_TURQUOISE
			width = 2
		&"disabled":
			border = Color(AlveolusVisualTheme.MUTED, 0.28)
	var style := _signature_base(Color.TRANSPARENT, border, width, 18, 5)
	return _with_insets(style, 18.0, 12.0)

static func round_button(state: StringName) -> StyleBoxFlat:
	var background := Color(INSET_BG, 0.96)
	var border := Color(AlveolusVisualTheme.MUTED, 0.30)
	var width := 1
	match state:
		&"hover":
			background = FRAME_LEFT_BG
			border = AlveolusVisualTheme.TURQUOISE
		&"pressed":
			background = FRAME_RIGHT_BG
		&"focus":
			background = Color.TRANSPARENT
			border = FOCUS_TURQUOISE
			width = 2
		&"disabled":
			background = Color(INSET_BG, 0.34)
			border = Color(AlveolusVisualTheme.MUTED, 0.16)
	return _base(background, border, width, 22)

static func _signature_base(background: Color, border: Color, width: int, large_radius: int, small_radius: int) -> StyleBoxFlat:
	var style := _base(background, border, width, large_radius)
	style.corner_radius_top_left = large_radius
	style.corner_radius_top_right = small_radius
	style.corner_radius_bottom_right = large_radius
	style.corner_radius_bottom_left = small_radius
	return style

static func _base(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.corner_detail = 16
	style.anti_aliasing = true
	return style

static func _with_insets(style: StyleBoxFlat, horizontal: float, vertical: float) -> StyleBoxFlat:
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style
