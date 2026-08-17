class_name AlveolusVisualTheme
extends Resource

## Central visual contract for every ALVEOLUS interface.
##
## Screens should consume the semantic type variations and spacing tokens below
## instead of defining local colours, radii or interaction states. The existing
## style factory methods remain public for gameplay HUD elements with dynamic accents.

const IVORY := Color("f7f1e7")
const IVORY_DEEP := Color("e9dfcf")
const PAPER_LIGHT := Color("fffaf1")
const SKY := Color("dcebf0")
const SKY_DEEP := Color("c9dfe5")
const PETROL := Color("123d46")
const PETROL_SOFT := Color("315d63")
const MUTED := Color("536c70")
const TEAL := Color("159b99")
const TURQUOISE := Color("2fc4c0")
const CORAL := Color("ef7766")
const COBALT := Color("3777c8")
const GOLD := Color("eab553")
# Gold remains a bright accent for fills and outlines. Text on paper uses this
# darker companion so normal-size copy reaches WCAG AA contrast on ivory.
const GOLD_INK := Color("886930")
const PETROL_DEEP := Color("0b2d34")
const PETROL_WASH := Color("173f47")
const FOCUS_RING := GOLD
const SHADOW := Color(0.055, 0.12, 0.14, 0.22)
const HAIRLINE := Color(0.071, 0.239, 0.275, 0.16)

const SCREEN_MARGIN := 24
const SCREEN_MARGIN_COMPACT := 16
const HEADER_HEIGHT := 76
const HEADER_HEIGHT_COMPACT := 60
const HEADER_CONTENT_GAP := 20
const HEADER_CONTENT_GAP_COMPACT := 12
const GRID_UNIT := 4
const SECTION_GAP := 20
const CONTENT_GAP := 12
const CONTROL_GAP := 8
const CARD_PADDING := 16

const TEXT_CAPTION := 14
const TEXT_BODY := 16
const TEXT_ACTION := 16
const TEXT_SECTION := 20
const TEXT_TITLE := 28
const TEXT_DISPLAY := 36

const BUTTON_HEIGHT_PRIMARY := 48
const BUTTON_HEIGHT_SECONDARY := 44
const TOUCH_TARGET_MINIMUM := 44
const CARD_RADIUS := 6
const CONTROL_RADIUS := 4
const MODAL_RADIUS := 6

enum SurfaceRole {
	PAGE_CANVAS,
	SECTION_GROUP,
	ACTION_CARD,
	DOCUMENT_INSET,
	MODAL_SHEET,
	HUD_VITAL,
	HUD_OBJECTIVE,
	HUD_ABILITY,
	HUD_ALERT,
	PAGE_HEADER,
	FORM_CONTROL,
	VALUE_ROW,
	TOOLTIP_CARD,
	DETAIL_CARD,
}

enum CornerTreatment {
	NONE,
	CONTROL_4,
	CARD_6,
	SIGNATURE_6,
}

const TYPE_PRIMARY_BUTTON := &"PrimaryButton"
const TYPE_SECONDARY_BUTTON := &"SecondaryButton"
const TYPE_DANGER_BUTTON := &"DangerButton"
const TYPE_QUIET_BUTTON := &"QuietButton"
const TYPE_NAVIGATION_BUTTON := &"NavigationButton"
const TYPE_TAB_BUTTON := &"TabButton"
const TYPE_SELECTED_TAB_BUTTON := &"SelectedTabButton"
const TYPE_SELECTION_CARD := &"SelectionCard"
const TYPE_SELECTED_CARD := &"SelectedCard"
const TYPE_CHOICE_ROW := &"ChoiceRow"
const TYPE_SELECTED_CHOICE_ROW := &"SelectedChoiceRow"
const TYPE_PANEL_CARD := &"PanelCard"
const TYPE_PANEL_ELEVATED := &"PanelElevated"
const TYPE_PANEL_INSET := &"PanelInset"
const TYPE_PANEL_MODAL := &"PanelModal"
const TYPE_PANEL_HEADER := &"PanelHeader"
const TYPE_BADGE := &"Badge"
const TYPE_PAGE_CANVAS := &"PageCanvas"
const TYPE_SECTION_GROUP := &"SectionGroup"
const TYPE_ACTION_CARD := &"ActionCard"
const TYPE_DOCUMENT_INSET := &"DocumentInset"
const TYPE_MODAL_SHEET := &"ModalSheet"
const TYPE_HUD_VITAL := &"HudVital"
const TYPE_HUD_OBJECTIVE := &"HudObjective"
const TYPE_HUD_ABILITY := &"HudAbility"
const TYPE_HUD_ALERT := &"HudAlert"
const TYPE_PAGE_HEADER := &"PageHeader"
const TYPE_FORM_CONTROL := &"FormControl"
const TYPE_VALUE_ROW := &"ValueRow"
const TYPE_TOOLTIP_CARD := &"TooltipCard"
const TYPE_DETAIL_CARD := &"DetailCard"
const TYPE_SEGMENTED_TAB := &"SegmentedTab"
const TYPE_SELECTED_SEGMENTED_TAB := &"SelectedSegmentedTab"
const TYPE_TOGGLE_ROW := &"ToggleRow"
const TYPE_OPTION_ROW := &"OptionRow"
const TYPE_SLIDER_ROW := &"SliderRow"
const TYPE_TITLE_LABEL := &"TitleLabel"
const TYPE_SECTION_LABEL := &"SectionLabel"
const TYPE_EYEBROW_LABEL := &"EyebrowLabel"
const TYPE_BODY_LABEL := &"BodyLabel"
const TYPE_MUTED_LABEL := &"MutedLabel"
const TYPE_VALUE_LABEL := &"ValueLabel"
const TYPE_HUD_LABEL := &"HudLabel"
const TYPE_HUD_MUTED_LABEL := &"HudMutedLabel"
const TYPE_HUD_VALUE_LABEL := &"HudValueLabel"

const HEADING_FONT_PATH := "res://assets/fonts/BricolageGrotesque-Variable.ttf"
const BODY_FONT_PATH := "res://assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf"

static var _heading_font: Font
static var _body_font: Font

static func heading_font() -> Font:
	if _heading_font == null:
		_heading_font = load(HEADING_FONT_PATH) as Font
	return _heading_font

static func body_font() -> Font:
	if _body_font == null:
		_body_font = load(BODY_FONT_PATH) as Font
	return _body_font

static func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = body_font()
	theme.default_font_size = TEXT_BODY

	theme.set_font("font", "Button", heading_font())
	theme.set_font_size("font_size", "Button", TEXT_ACTION)
	theme.set_color("font_color", "Button", IVORY)
	theme.set_color("font_hover_color", "Button", PAPER_LIGHT)
	theme.set_color("font_pressed_color", "Button", IVORY)
	theme.set_color("font_focus_color", "Button", PAPER_LIGHT)
	theme.set_color("font_hover_pressed_color", "Button", IVORY)
	theme.set_color("font_disabled_color", "Button", Color(SKY_DEEP, 0.54))
	theme.set_constant("outline_size", "Button", 0)
	_configure_button_variant(theme, &"Button", TEAL, false, false, BUTTON_HEIGHT_SECONDARY)

	theme.set_font("font", "Label", body_font())
	theme.set_font_size("font_size", "Label", TEXT_BODY)
	theme.set_color("font_color", "Label", IVORY)
	theme.set_constant("outline_size", "Label", 0)

	theme.set_font("font", "LineEdit", body_font())
	theme.set_font_size("font_size", "LineEdit", TEXT_BODY)
	theme.set_color("font_color", "LineEdit", IVORY)
	theme.set_color("font_placeholder_color", "LineEdit", SKY_DEEP)
	theme.set_color("font_uneditable_color", "LineEdit", Color(SKY_DEEP, 0.62))
	theme.set_stylebox("normal", "LineEdit", input_style(&"normal"))
	theme.set_stylebox("focus", "LineEdit", input_style(&"focus"))
	theme.set_stylebox("read_only", "LineEdit", input_style(&"disabled"))

	theme.set_font("font", "RichTextLabel", body_font())
	theme.set_font_size("normal_font_size", "RichTextLabel", TEXT_BODY)
	theme.set_color("default_color", "RichTextLabel", IVORY)

	# Unclassified panels remain quiet section surfaces. Raised white cards must be
	# requested explicitly through ACTION_CARD or MODAL_SHEET.
	theme.set_stylebox("panel", "Panel", surface_role_style(SurfaceRole.SECTION_GROUP))
	theme.set_stylebox("panel", "PanelContainer", surface_role_style(SurfaceRole.SECTION_GROUP))
	theme.set_stylebox("panel", "TooltipPanel", surface_role_style(SurfaceRole.TOOLTIP_CARD, TURQUOISE, CornerTreatment.CONTROL_4))
	theme.set_font("font", "TooltipLabel", body_font())
	theme.set_font_size("font_size", "TooltipLabel", TEXT_CAPTION)
	theme.set_color("font_color", "TooltipLabel", IVORY)

	theme.set_stylebox("background", "ProgressBar", bar_style(Color(PETROL_DEEP, 0.78), 6, true))
	theme.set_stylebox("fill", "ProgressBar", bar_style(TEAL, 6))
	theme.set_font("font", "ProgressBar", heading_font())
	theme.set_font_size("font_size", "ProgressBar", TEXT_CAPTION)
	theme.set_color("font_color", "ProgressBar", IVORY)

	_configure_scrollbars(theme)
	_configure_variations(theme)
	return theme

static func _configure_variations(theme: Theme) -> void:
	_register_button_variation(theme, TYPE_PRIMARY_BUTTON, TEAL, true, false, BUTTON_HEIGHT_PRIMARY)
	_register_button_variation(theme, TYPE_SECONDARY_BUTTON, COBALT, false, false, BUTTON_HEIGHT_SECONDARY)
	_register_button_variation(theme, TYPE_DANGER_BUTTON, CORAL, false, true, BUTTON_HEIGHT_SECONDARY)
	_register_button_variation(theme, TYPE_QUIET_BUTTON, MUTED, false, false, BUTTON_HEIGHT_SECONDARY)
	_register_button_variation(theme, TYPE_NAVIGATION_BUTTON, TEAL, false, false, BUTTON_HEIGHT_SECONDARY)
	theme.set_font("font", TYPE_NAVIGATION_BUTTON, body_font())
	_register_button_variation(theme, TYPE_SELECTION_CARD, COBALT, false, false, 88, false, true)
	_register_button_variation(theme, TYPE_SELECTED_CARD, TEAL, false, false, 88, true, true)
	_register_button_variation(theme, TYPE_CHOICE_ROW, COBALT, false, false, 64, false, true)
	_register_button_variation(theme, TYPE_SELECTED_CHOICE_ROW, TEAL, false, false, 64, true, true)
	_register_segmented_tab_variation(theme, TYPE_SEGMENTED_TAB, false)
	_register_segmented_tab_variation(theme, TYPE_SELECTED_SEGMENTED_TAB, true)
	_register_segmented_tab_variation(theme, TYPE_TAB_BUTTON, false)
	_register_segmented_tab_variation(theme, TYPE_SELECTED_TAB_BUTTON, true)
	_register_row_control_variations(theme)

	_register_panel_variation(theme, TYPE_PAGE_CANVAS, surface_role_style(SurfaceRole.PAGE_CANVAS))
	_register_panel_variation(theme, TYPE_SECTION_GROUP, surface_role_style(SurfaceRole.SECTION_GROUP))
	_register_panel_variation(theme, TYPE_ACTION_CARD, surface_role_style(SurfaceRole.ACTION_CARD))
	_register_panel_variation(theme, TYPE_DOCUMENT_INSET, surface_role_style(SurfaceRole.DOCUMENT_INSET))
	_register_panel_variation(theme, TYPE_MODAL_SHEET, surface_role_style(SurfaceRole.MODAL_SHEET))
	_register_panel_variation(theme, TYPE_HUD_VITAL, surface_role_style(SurfaceRole.HUD_VITAL, TEAL))
	_register_panel_variation(theme, TYPE_HUD_OBJECTIVE, surface_role_style(SurfaceRole.HUD_OBJECTIVE, COBALT))
	_register_panel_variation(theme, TYPE_HUD_ABILITY, surface_role_style(SurfaceRole.HUD_ABILITY, TURQUOISE))
	_register_panel_variation(theme, TYPE_HUD_ALERT, surface_role_style(SurfaceRole.HUD_ALERT, CORAL))
	_register_panel_variation(theme, TYPE_PAGE_HEADER, surface_role_style(SurfaceRole.PAGE_HEADER))
	_register_panel_variation(theme, TYPE_FORM_CONTROL, surface_role_style(SurfaceRole.FORM_CONTROL, COBALT))
	_register_panel_variation(theme, TYPE_VALUE_ROW, surface_role_style(SurfaceRole.VALUE_ROW))
	_register_panel_variation(theme, TYPE_TOOLTIP_CARD, surface_role_style(SurfaceRole.TOOLTIP_CARD, TURQUOISE))
	_register_panel_variation(theme, TYPE_DETAIL_CARD, surface_role_style(SurfaceRole.DETAIL_CARD, COBALT))

	# Compatibility aliases retain their public names while following the new
	# semantic surface hierarchy.
	_register_panel_variation(theme, TYPE_PANEL_CARD, surface_role_style(SurfaceRole.ACTION_CARD))
	_register_panel_variation(theme, TYPE_PANEL_ELEVATED, surface_role_style(SurfaceRole.ACTION_CARD))
	_register_panel_variation(theme, TYPE_PANEL_INSET, surface_role_style(SurfaceRole.DOCUMENT_INSET))
	_register_panel_variation(theme, TYPE_PANEL_MODAL, surface_role_style(SurfaceRole.MODAL_SHEET, COBALT))
	_register_panel_variation(theme, TYPE_PANEL_HEADER, surface_role_style(SurfaceRole.SECTION_GROUP))
	_register_panel_variation(theme, TYPE_BADGE, surface_role_style(SurfaceRole.DOCUMENT_INSET, COBALT, CornerTreatment.CONTROL_4))

	_register_label_variation(theme, TYPE_TITLE_LABEL, heading_font(), TEXT_TITLE, IVORY)
	_register_label_variation(theme, TYPE_SECTION_LABEL, heading_font(), TEXT_SECTION, IVORY)
	_register_label_variation(theme, TYPE_EYEBROW_LABEL, heading_font(), TEXT_CAPTION, TURQUOISE)
	_register_label_variation(theme, TYPE_BODY_LABEL, body_font(), TEXT_BODY, IVORY)
	_register_label_variation(theme, TYPE_MUTED_LABEL, body_font(), TEXT_CAPTION, SKY_DEEP)
	_register_label_variation(theme, TYPE_VALUE_LABEL, heading_font(), TEXT_BODY, IVORY)
	_register_label_variation(theme, TYPE_HUD_LABEL, body_font(), TEXT_BODY, IVORY)
	_register_label_variation(theme, TYPE_HUD_MUTED_LABEL, body_font(), TEXT_CAPTION, SKY_DEEP)
	_register_label_variation(theme, TYPE_HUD_VALUE_LABEL, heading_font(), TEXT_SECTION, PAPER_LIGHT)

static func _register_button_variation(
	theme: Theme,
	variation: StringName,
	accent: Color,
	primary: bool,
	danger: bool,
	minimum_height: int,
	selected: bool = false,
	card: bool = false
) -> void:
	theme.set_type_variation(variation, &"Button")
	_configure_button_variant(theme, variation, accent, primary, danger, minimum_height, selected, card)
	if primary:
		for color_name in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color"]:
			theme.set_color(color_name, variation, PETROL)

static func _configure_button_variant(
	theme: Theme,
	theme_type: StringName,
	accent: Color,
	primary: bool,
	danger: bool,
	minimum_height: int,
	selected: bool = false,
	card: bool = false
) -> void:
	var normal_state := &"selected" if selected else &"normal"
	for color_name in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color"]:
		if not theme.has_color(color_name, theme_type):
			theme.set_color(color_name, theme_type, IVORY)
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		var visual_state: StringName = normal_state if state == &"normal" else (&"hover_selected" if state == &"hover_pressed" and selected else state)
		var style := case_card_style(accent, visual_state) if card else button_style(accent, visual_state, primary, danger)
		style.content_margin_left = 18.0
		style.content_margin_right = 18.0
		style.content_margin_top = maxf(style.content_margin_top, float(minimum_height - TEXT_ACTION) * 0.5)
		style.content_margin_bottom = maxf(style.content_margin_bottom, float(minimum_height - TEXT_ACTION) * 0.5)
		theme.set_stylebox(state, theme_type, style)

static func _register_segmented_tab_variation(theme: Theme, variation: StringName, selected: bool) -> void:
	theme.set_type_variation(variation, &"Button")
	theme.set_font("font", variation, heading_font())
	theme.set_font_size("font_size", variation, TEXT_ACTION)
	# Selected tabs stay dark enough for ivory text. A bright teal fill with
	# petrol copy lost legibility on several displays and looked disconnected
	# from the otherwise dark dossier language.
	var text_color := IVORY if selected else SKY_DEEP
	for color_name in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		theme.set_color(color_name, variation, text_color)
	theme.set_color("font_hover_pressed_color", variation, text_color)
	theme.set_color("font_disabled_color", variation, Color(MUTED, 0.78))
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		var visual_state: StringName = &"hover" if state == &"hover_pressed" else state
		var style := segmented_tab_style(visual_state, selected)
		style.content_margin_left = 16.0
		style.content_margin_right = 16.0
		style.content_margin_top = 12.0
		style.content_margin_bottom = 12.0
		theme.set_stylebox(state, variation, style)

static func _register_row_control_variations(theme: Theme) -> void:
	for entry in [
		[TYPE_TOGGLE_ROW, &"CheckButton"],
		[TYPE_OPTION_ROW, &"OptionButton"],
	]:
		var variation: StringName = entry[0]
		var base_type: StringName = entry[1]
		theme.set_type_variation(variation, base_type)
		theme.set_font("font", variation, body_font())
		theme.set_font_size("font_size", variation, TEXT_BODY)
		theme.set_color("font_color", variation, IVORY)
		theme.set_color("font_hover_color", variation, PAPER_LIGHT)
		theme.set_color("font_pressed_color", variation, IVORY)
		theme.set_color("font_focus_color", variation, PAPER_LIGHT)
		theme.set_color("font_hover_pressed_color", variation, PAPER_LIGHT)
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
			var style := button_style(COBALT, &"hover" if state == &"hover_pressed" else state)
			style.content_margin_left = 12.0
			style.content_margin_right = 12.0
			style.content_margin_top = 12.0
			style.content_margin_bottom = 12.0
			theme.set_stylebox(state, variation, style)
	theme.set_type_variation(TYPE_SLIDER_ROW, &"HSlider")
	var slider_track := bar_style(Color(SKY_DEEP, 0.30), 3, true)
	slider_track.content_margin_top = 3.0
	slider_track.content_margin_bottom = 3.0
	var slider_fill := bar_style(TEAL, 3)
	slider_fill.content_margin_top = 3.0
	slider_fill.content_margin_bottom = 3.0
	var slider_fill_highlight := bar_style(TURQUOISE, 3)
	slider_fill_highlight.content_margin_top = 3.0
	slider_fill_highlight.content_margin_bottom = 3.0
	theme.set_stylebox("slider", TYPE_SLIDER_ROW, slider_track)
	theme.set_stylebox("grabber_area", TYPE_SLIDER_ROW, slider_fill)
	theme.set_stylebox("grabber_area_highlight", TYPE_SLIDER_ROW, slider_fill_highlight)
	var slider_focus := surface_role_style(SurfaceRole.DOCUMENT_INSET, FOCUS_RING, CornerTreatment.CONTROL_4)
	slider_focus.bg_color = Color.TRANSPARENT
	slider_focus.border_color = FOCUS_RING
	slider_focus.set_border_width_all(3)
	theme.set_stylebox("focus", TYPE_SLIDER_ROW, slider_focus)

static func _register_panel_variation(theme: Theme, variation: StringName, style: StyleBox) -> void:
	theme.set_type_variation(variation, &"PanelContainer")
	theme.set_stylebox("panel", variation, style)

static func _register_label_variation(theme: Theme, variation: StringName, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(variation, &"Label")
	theme.set_font("font", variation, font)
	theme.set_font_size("font_size", variation, size)
	theme.set_color("font_color", variation, color)

static func _configure_scrollbars(theme: Theme) -> void:
	for type_name in [&"HScrollBar", &"VScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color(PETROL, 0.18)
		track.set_corner_radius_all(CONTROL_RADIUS)
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = Color(TEAL, 0.86)
		grabber.set_corner_radius_all(CONTROL_RADIUS)
		if type_name == &"VScrollBar":
			track.content_margin_left = 6.0
			track.content_margin_right = 6.0
			grabber.content_margin_left = 6.0
			grabber.content_margin_right = 6.0
		else:
			track.content_margin_top = 6.0
			track.content_margin_bottom = 6.0
			grabber.content_margin_top = 6.0
			grabber.content_margin_bottom = 6.0
		var grabber_hover := grabber.duplicate() as StyleBoxFlat
		grabber_hover.bg_color = TURQUOISE
		theme.set_stylebox("scroll", type_name, track)
		theme.set_stylebox("scroll_focus", type_name, track)
		theme.set_stylebox("grabber", type_name, grabber)
		theme.set_stylebox("grabber_highlight", type_name, grabber_hover)
		theme.set_stylebox("grabber_pressed", type_name, grabber_hover)
		theme.set_constant("minimum_grab_length", type_name, 36)

static func surface_role_style(
	role: int,
	accent: Color = TEAL,
	corner_treatment: int = -1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var default_corner := CornerTreatment.NONE
	var border_width := 0
	match role:
		SurfaceRole.PAGE_CANVAS:
			style.bg_color = PETROL_DEEP
			style.border_color = Color.TRANSPARENT
		SurfaceRole.SECTION_GROUP:
			style.bg_color = Color(SKY, 0.10)
			style.border_color = Color(SKY_DEEP, 0.18)
			border_width = 1
		SurfaceRole.ACTION_CARD:
			style.bg_color = Color(PETROL_WASH, 0.94)
			style.border_color = Color(accent, 0.46)
			style.shadow_color = Color(PETROL_DEEP, 0.18)
			style.shadow_size = 3
			style.shadow_offset = Vector2(0.0, 2.0)
			border_width = 1
			default_corner = CornerTreatment.CARD_6
		SurfaceRole.DOCUMENT_INSET:
			style.bg_color = Color(PETROL_DEEP, 0.72)
			style.border_color = Color(accent, 0.34)
			border_width = 1
			default_corner = CornerTreatment.CONTROL_4
		SurfaceRole.MODAL_SHEET:
			style.bg_color = Color(PETROL_WASH, 0.98)
			style.border_color = Color(accent, 0.52)
			style.shadow_color = Color(PETROL_DEEP, 0.34)
			style.shadow_size = 12
			style.shadow_offset = Vector2(0.0, 6.0)
			border_width = 1
			default_corner = CornerTreatment.SIGNATURE_6
		SurfaceRole.HUD_VITAL:
			style.bg_color = Color(PETROL_DEEP, 0.88)
			style.border_color = Color(accent, 0.58)
			border_width = 1
			default_corner = CornerTreatment.CONTROL_4
		SurfaceRole.HUD_OBJECTIVE:
			style.bg_color = Color(PETROL_WASH, 0.84)
			style.border_color = Color(accent, 0.52)
			border_width = 1
			default_corner = CornerTreatment.CONTROL_4
		SurfaceRole.HUD_ABILITY:
			style.bg_color = Color(PETROL_DEEP, 0.82)
			style.border_color = Color(accent, 0.60)
			border_width = 1
			default_corner = CornerTreatment.CARD_6
		SurfaceRole.HUD_ALERT:
			style.bg_color = Color(PETROL_DEEP, 0.94)
			style.border_color = Color(accent, 0.82)
			style.shadow_color = Color(accent, 0.18)
			style.shadow_size = 4
			style.shadow_offset = Vector2.ZERO
			border_width = 2
			default_corner = CornerTreatment.CARD_6
		SurfaceRole.PAGE_HEADER:
			style.bg_color = Color(PETROL_WASH, 0.96)
			style.border_color = Color(TURQUOISE, 0.34)
			border_width = 1
			style.shadow_color = Color(PETROL_DEEP, 0.18)
			style.shadow_size = 4
			style.shadow_offset = Vector2(0.0, 2.0)
			default_corner = CornerTreatment.NONE
		SurfaceRole.FORM_CONTROL:
			style.bg_color = Color(PETROL_DEEP, 0.88)
			style.border_color = Color(accent, 0.42)
			border_width = 1
			default_corner = CornerTreatment.CONTROL_4
		SurfaceRole.VALUE_ROW:
			style.bg_color = Color(PETROL_DEEP, 0.62)
			style.border_color = Color(SKY_DEEP, 0.20)
			border_width = 1
			default_corner = CornerTreatment.CONTROL_4
		SurfaceRole.TOOLTIP_CARD:
			style.bg_color = Color("061e25")
			style.border_color = Color(accent, 0.66)
			style.shadow_color = Color(PETROL_DEEP, 0.34)
			style.shadow_size = 8
			style.shadow_offset = Vector2(0.0, 4.0)
			border_width = 1
			default_corner = CornerTreatment.CONTROL_4
		SurfaceRole.DETAIL_CARD:
			style.bg_color = Color(PETROL_WASH, 0.98)
			style.border_color = Color(accent, 0.58)
			style.shadow_color = Color(PETROL_DEEP, 0.24)
			style.shadow_size = 6
			style.shadow_offset = Vector2(0.0, 3.0)
			border_width = 1
			default_corner = CornerTreatment.CARD_6
		_:
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color.TRANSPARENT
	style.set_border_width_all(border_width)
	if role == SurfaceRole.PAGE_HEADER:
		style.border_width_left = 0
		style.border_width_top = 0
		style.border_width_right = 0
		style.border_width_bottom = 1
		style.shadow_size = 0
		style.shadow_offset = Vector2.ZERO
	style.corner_detail = 8
	style.anti_aliasing = true
	apply_corner_treatment(style, default_corner if corner_treatment < 0 else corner_treatment)
	return style

static func apply_corner_treatment(style: StyleBoxFlat, treatment: int) -> StyleBoxFlat:
	if style == null:
		return style
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_right = 0
	style.corner_radius_bottom_left = 0
	match treatment:
		CornerTreatment.CONTROL_4:
			style.set_corner_radius_all(4)
		CornerTreatment.CARD_6:
			style.set_corner_radius_all(6)
		CornerTreatment.SIGNATURE_6:
			# The asymmetric dossier signature is always a fixed six design pixels.
			# Large section groups never receive it implicitly.
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 0
			style.corner_radius_bottom_right = 6
			style.corner_radius_bottom_left = 0
	return style

static func segmented_tab_style(state: StringName, selected: bool = false) -> StyleBoxFlat:
	var style := surface_role_style(
		SurfaceRole.DOCUMENT_INSET if selected else SurfaceRole.HUD_OBJECTIVE,
		TEAL,
		CornerTreatment.CONTROL_4
	)
	style.shadow_size = 0
	if selected:
		style.bg_color = PETROL_WASH.lerp(TEAL, 0.34)
		style.border_color = TURQUOISE
		style.border_width_bottom = 3
	else:
		style.bg_color = Color(PETROL_DEEP, 0.86)
		style.border_color = Color(SKY_DEEP, 0.28)
	match state:
		&"hover":
			style.border_color = TURQUOISE
			style.bg_color = PETROL_WASH.lerp(TEAL, 0.44) if selected else Color(PETROL_WASH, 0.94)
		&"pressed":
			style.bg_color = PETROL_WASH.lerp(TEAL, 0.26) if selected else PETROL_DEEP
		&"focus":
			style.border_color = GOLD
			style.set_border_width_all(3)
		&"disabled":
			style.bg_color = Color(PETROL_WASH, 0.42)
			style.border_color = Color(MUTED, 0.24)
	return style

static func panel_style(background: Color, accent: Color, border_width: int = 1, radius: int = CARD_RADIUS, elevated: bool = true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = resolve_surface(background, accent)
	style.border_color = Color(accent, clampf(maxf(accent.a, 0.26), 0.26, 0.66))
	style.set_border_width_all(maxi(border_width, 0))
	style.set_corner_radius_all(radius)
	style.corner_detail = 10
	style.anti_aliasing = true
	if elevated:
		style.shadow_color = SHADOW
		style.shadow_size = 7
		style.shadow_offset = Vector2(0.0, 3.0)
	return style

static func surface_style(background: Color, accent: Color = TEAL, elevation: StringName = &"card") -> StyleBoxFlat:
	var radius := CARD_RADIUS
	var border_width := 1
	var elevated := true
	var shadow_size := 4
	var shadow_alpha := 0.14
	match elevation:
		&"flat":
			radius = CONTROL_RADIUS
			elevated = false
			shadow_size = 0
		&"inset":
			radius = CONTROL_RADIUS
			elevated = false
			shadow_size = 0
		&"elevated":
			shadow_size = 8
			shadow_alpha = 0.18
		&"modal":
			radius = MODAL_RADIUS
			border_width = 2
			shadow_size = 14
			shadow_alpha = 0.24
		&"header":
			radius = 0
			shadow_size = 5
			shadow_alpha = 0.12
		&"badge":
			radius = CONTROL_RADIUS
			elevated = false
			shadow_size = 0
	var style := panel_style(background, Color(accent, 0.42), border_width, radius, elevated)
	style.border_color = Color(accent, 0.22 if elevation != &"modal" else 0.42)
	style.shadow_size = shadow_size
	style.shadow_color = Color(PETROL, shadow_alpha)
	style.shadow_offset = Vector2(0.0, 3.0 if elevation != &"modal" else 6.0)
	return style

static func with_content_insets(style: StyleBoxFlat, horizontal: float, vertical: float) -> StyleBoxFlat:
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style

static func button_style(accent: Color, state: StringName, primary: bool = false, danger: bool = false) -> StyleBoxFlat:
	var active_accent := CORAL if danger else accent
	var background := PETROL_WASH
	var border := Color(active_accent, 0.46)
	var shadow_size := 3
	var shadow_offset := Vector2(0.0, 2.0)
	match state:
		&"normal":
			background = Color(active_accent, 0.08) if primary else Color(PETROL_WASH, 0.96)
		&"selected":
			background = PETROL_WASH.lerp(active_accent, 0.28)
			border = active_accent
			shadow_size = 5
		&"hover", &"hover_pressed", &"hover_selected":
			background = Color(active_accent, 0.11) if primary else PETROL_SOFT.lerp(active_accent, 0.14)
			border = active_accent
			shadow_size = 6
		&"pressed":
			background = Color(active_accent, 0.06) if primary else PETROL_DEEP.lerp(active_accent, 0.18)
			border = active_accent.darkened(0.10)
			shadow_size = 1
			shadow_offset = Vector2(0.0, 1.0)
		&"focus":
			background = Color(active_accent, 0.08) if primary else Color.TRANSPARENT
			border = FOCUS_RING
			shadow_size = 0
		&"disabled":
			background = Color(PETROL_WASH, 0.16 if primary else 0.40)
			border = Color(SKY_DEEP, 0.16)
			shadow_size = 0
	var style := panel_style(background, border, 3 if state == &"focus" else 1, CONTROL_RADIUS, shadow_size > 0)
	style.border_color = border
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_offset
	# The approved planning controls established the Bio-Lumen signature: one
	# calm rounded side and one tighter instrument edge. Keep that geometry in
	# the central factory so every semantic button role inherits it.
	var large_radius := 18 if primary else (11 if danger else 12)
	var small_radius := 5 if primary else 4
	style.corner_radius_top_left = large_radius
	style.corner_radius_top_right = small_radius
	style.corner_radius_bottom_right = large_radius
	style.corner_radius_bottom_left = small_radius
	# Local state overrides replace the complete StyleBox, including its content
	# margins. Keep the safe area in the factory so no direct-text button can
	# silently lose padding when a caller recolors or refreshes it.
	return with_content_insets(style, 18.0, 16.0 if primary else 14.0)

static func case_card_style(accent: Color, state: StringName) -> StyleBoxFlat:
	var background := Color(PETROL_WASH.lerp(accent, 0.035), 0.94)
	var border := Color(accent, 0.38)
	var shadow_size := 0
	var shadow_offset := Vector2(0.0, 2.0)
	match state:
		&"selected":
			background = PETROL_WASH.lerp(accent, 0.24)
			border = accent
			shadow_size = 5
		&"hover", &"hover_pressed":
			background = PETROL_SOFT.lerp(accent, 0.12)
			border = Color(accent, 0.72)
			shadow_size = 6
		&"hover_selected":
			background = PETROL_WASH.lerp(accent, 0.30)
			border = accent.lightened(0.12)
			shadow_size = 6
		&"pressed":
			background = PETROL_DEEP.lerp(accent, 0.18)
			border = Color(accent, 0.82)
			shadow_size = 1
			shadow_offset = Vector2(0.0, 1.0)
		&"focus":
			# The focus StyleBox is painted over the normal/selected surface. It must
			# therefore be transparent so the gold ring never erases selection,
			# branch identity or the locked membrane underneath it.
			background = Color.TRANSPARENT
			border = FOCUS_RING
			shadow_size = 0
		&"disabled":
			background = Color(PETROL_WASH, 0.36)
			border = Color(SKY_DEEP, 0.14)
			shadow_size = 0
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3 if state == &"focus" else 1)
	style.set_corner_radius_all(CARD_RADIUS)
	style.corner_detail = 12
	style.anti_aliasing = true
	style.shadow_color = Color(PETROL, 0.15)
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_offset
	# Direct-text selection cards must never rely on callers to recreate their
	# inner safe area after a state/style refresh.
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style

static func input_style(state: StringName) -> StyleBoxFlat:
	var style := surface_role_style(SurfaceRole.FORM_CONTROL, COBALT, CornerTreatment.CONTROL_4)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	match state:
		&"focus":
			style.border_color = FOCUS_RING
			style.set_border_width_all(3)
		&"disabled":
			style.bg_color = Color(PETROL_WASH, 0.42)
			style.border_color = Color(MUTED, 0.20)
	return style

static func bar_style(color: Color, radius: int = 5, background: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	if not background:
		style.border_color = color.lightened(0.22)
		style.set_border_width(SIDE_TOP, 1)
	return style

static func resolve_surface(background: Color, accent: Color = TEAL) -> Color:
	# Surface role, not luminance, decides whether a panel is light or dark.
	# Keeping the requested colour also makes legacy callers that explicitly ask
	# for petrol HUD chrome behave as authored.
	var _unused_accent := accent
	return background
