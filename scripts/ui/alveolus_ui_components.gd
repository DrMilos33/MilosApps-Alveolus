class_name AlveolusUIComponents
extends RefCounted

## Semantic construction helpers for the ALVEOLUS dossier interface.
##
## Layout and behaviour live here; colours, typography and interaction states
## remain owned by AlveolusVisualTheme. Existing public helpers are retained as
## compatibility aliases for production screens.

const ACTION_PRIMARY := &"primary"
const ACTION_SECONDARY := &"secondary"
const ACTION_DANGER := &"danger"
const ACTION_QUIET := &"quiet"
const ACTION_NAVIGATION := &"navigation"
const ACTION_PLANNING_START := &"planning_start"

static func label(text_value: String, variation: StringName = AlveolusVisualTheme.TYPE_BODY_LABEL) -> Label:
	var control := Label.new()
	control.text = text_value
	control.theme_type_variation = variation
	control.autowrap_mode = TextServer.AUTOWRAP_OFF
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control

static func button(
	text_value: String,
	variation: StringName = AlveolusVisualTheme.TYPE_SECONDARY_BUTTON,
	icon_kind: StringName = &"",
	accent: Color = AlveolusVisualTheme.COBALT
) -> Button:
	return _build_action_button(text_value, variation, icon_kind, accent, _role_for_variation(variation))

static func action_button(
	text_value: String,
	role: StringName = ACTION_SECONDARY,
	icon_kind: StringName = &"",
	accent: Color = AlveolusVisualTheme.TEAL
) -> Button:
	return _build_action_button(text_value, _variation_for_role(role), icon_kind, accent, role)

## Explicit exception to the global teal-to-teal primary action. This is the
## only component API allowed to create the approved planning teal-to-warm-gold
## membrane.
static func planning_start_button(text_value: String = "Behandlung starten", icon_kind: StringName = &"play") -> Button:
	return _build_action_button(
		text_value,
		AlveolusVisualTheme.TYPE_PRIMARY_BUTTON,
		icon_kind,
		AlveolusVisualTheme.TURQUOISE,
		ACTION_PLANNING_START
	)

static func segmented_tab(text_value: String, selected: bool = false, group: ButtonGroup = null) -> Button:
	var control := Button.new()
	control.text = text_value
	control.toggle_mode = true
	control.button_group = group
	control.button_pressed = selected
	control.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB if selected else AlveolusVisualTheme.TYPE_SEGMENTED_TAB
	control.custom_minimum_size.y = AlveolusVisualTheme.TOUCH_TARGET_MINIMUM
	control.focus_mode = Control.FOCUS_ALL
	control.set_meta(&"disable_motion_scale", true)
	control.set_meta(&"alveolus_component", &"segmented_tab")
	control.set_meta(&"alveolus_accessible_name", text_value)
	control.toggled.connect(func(pressed_value: bool) -> void:
		control.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB if pressed_value else AlveolusVisualTheme.TYPE_SEGMENTED_TAB
	)
	return control

static func toggle_row(text_value: String, pressed: bool = false) -> CheckButton:
	var control := CheckButton.new()
	control.text = text_value
	control.theme_type_variation = AlveolusVisualTheme.TYPE_TOGGLE_ROW
	control.custom_minimum_size.y = AlveolusVisualTheme.TOUCH_TARGET_MINIMUM
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.focus_mode = Control.FOCUS_ALL
	control.set_meta(&"disable_motion_scale", true)
	control.set_pressed_no_signal(pressed)
	control.set_meta(&"alveolus_component", &"toggle_row")
	control.set_meta(&"alveolus_accessible_name", text_value)
	return control

static func option_row(text_value: String, entries: Array[String], selected: int = 0) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	var title := label(text_value, AlveolusVisualTheme.TYPE_BODY_LABEL)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title)
	var control := OptionButton.new()
	control.theme_type_variation = AlveolusVisualTheme.TYPE_OPTION_ROW
	control.custom_minimum_size = Vector2(176.0, AlveolusVisualTheme.TOUCH_TARGET_MINIMUM)
	control.focus_mode = Control.FOCUS_ALL
	control.set_meta(&"disable_motion_scale", true)
	for entry in entries:
		control.add_item(entry)
	if not entries.is_empty():
		control.select(clampi(selected, 0, entries.size() - 1))
	control.set_meta(&"alveolus_component", &"option_row")
	control.set_meta(&"alveolus_accessible_name", text_value)
	row.add_child(control)
	return {"row": row, "label": title, "control": control}

static func slider_row(
	text_value: String,
	minimum: float = 0.0,
	maximum: float = 100.0,
	value: float = 50.0,
	step: float = 1.0
) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	var title := label(text_value, AlveolusVisualTheme.TYPE_BODY_LABEL)
	title.custom_minimum_size.x = 132.0
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var control := HSlider.new()
	control.theme_type_variation = AlveolusVisualTheme.TYPE_SLIDER_ROW
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.value = clampf(value, minimum, maximum)
	control.custom_minimum_size = Vector2(160.0, AlveolusVisualTheme.TOUCH_TARGET_MINIMUM)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.focus_mode = Control.FOCUS_ALL
	control.set_meta(&"disable_motion_scale", true)
	control.set_meta(&"alveolus_component", &"slider_row")
	control.set_meta(&"alveolus_accessible_name", text_value)
	row.add_child(control)
	var value_label := label(_slider_value_text(control.value, step), AlveolusVisualTheme.TYPE_VALUE_LABEL)
	value_label.custom_minimum_size.x = 48.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	control.value_changed.connect(func(next_value: float) -> void:
		value_label.text = _slider_value_text(next_value, step)
	)
	return {"row": row, "label": title, "control": control, "value_label": value_label}

static func panel(variation: StringName = AlveolusVisualTheme.TYPE_SECTION_GROUP) -> PanelContainer:
	var control := PanelContainer.new()
	control.theme_type_variation = variation
	var role := _surface_role_for_variation(variation)
	if role >= 0:
		apply_surface_role(control, role, _default_accent_for_surface_role(role))
	return control

static func surface(role: int, accent: Color = AlveolusVisualTheme.TEAL) -> PanelContainer:
	var control := PanelContainer.new()
	apply_surface_role(control, role, accent)
	return control

## Applies a semantic Bio-Lumen surface to an existing Panel/PanelContainer.
## This is the compatibility bridge for absolute-positioned HUD panels that
## cannot yet become container-built controls without changing layout.
static func apply_surface_role(
	control: Control,
	role: int,
	accent: Color = AlveolusVisualTheme.TEAL,
	emphasized: bool = false
) -> Control:
	if control == null:
		return null
	control.theme_type_variation = _variation_for_surface_role(role)
	var surface_style := AlveolusVisualTheme.surface_role_style(role, accent)
	if emphasized:
		surface_style.set_border_width_all(maxi(2, surface_style.border_width_left))
		surface_style.shadow_color = Color(accent, 0.14)
		surface_style.shadow_size = maxi(surface_style.shadow_size, 3)
	control.add_theme_stylebox_override("panel", surface_style)
	control.set_meta(&"alveolus_surface_role", role)
	var membrane := _surface_membrane(role, accent)
	if not membrane.is_empty():
		BioLumenSurfaceFill.attach(
			control,
			membrane["left"],
			membrane["right"],
			membrane["radii"],
			membrane["energy"]
		)
	return control

static func page_shell(header: Control = null, content: Control = null, compact: bool = false) -> Dictionary:
	var shell := panel(AlveolusVisualTheme.TYPE_PAGE_CANVAS)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	shell.set_meta(&"alveolus_component", &"page_shell")
	var stack := VBoxContainer.new()
	stack.name = "PageStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	shell.add_child(stack)
	if header != null:
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.custom_minimum_size.y = maxf(
			header.custom_minimum_size.y,
			AlveolusVisualTheme.HEADER_HEIGHT_COMPACT if compact else AlveolusVisualTheme.HEADER_HEIGHT
		)
		stack.add_child(header)

	# The approved deployment screen establishes the page anatomy: its header
	# is a full-width top band, while only the document body observes the safe
	# area. Keeping the body margin as the public `safe_area` preserves the
	# existing responsive screen API without turning the header into a floating
	# card again.
	var safe_area := MarginContainer.new()
	safe_area.name = "PageBodySafeArea"
	safe_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	safe_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var screen_margin := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if compact else AlveolusVisualTheme.SCREEN_MARGIN
	safe_area.add_theme_constant_override("margin_left", screen_margin)
	safe_area.add_theme_constant_override(
		"margin_top",
		AlveolusVisualTheme.HEADER_CONTENT_GAP_COMPACT if compact else AlveolusVisualTheme.HEADER_CONTENT_GAP
	)
	safe_area.add_theme_constant_override("margin_right", screen_margin)
	safe_area.add_theme_constant_override("margin_bottom", screen_margin)
	stack.add_child(safe_area)
	if content != null:
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		safe_area.add_child(content)
	var parts := {"shell": shell, "safe_area": safe_area, "stack": stack, "header": header, "content": content}
	refresh_page_shell_layout(shell, compact)
	return parts

static func refresh_page_shell_layout(shell: Control, compact: bool) -> void:
	if shell == null:
		return
	var screen_margin := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if compact else AlveolusVisualTheme.SCREEN_MARGIN
	var safe_area := shell.find_child("PageBodySafeArea", true, false) as MarginContainer
	if safe_area != null:
		safe_area.add_theme_constant_override("margin_left", screen_margin)
		safe_area.add_theme_constant_override(
			"margin_top",
			AlveolusVisualTheme.HEADER_CONTENT_GAP_COMPACT if compact else AlveolusVisualTheme.HEADER_CONTENT_GAP
		)
		safe_area.add_theme_constant_override("margin_right", screen_margin)
		safe_area.add_theme_constant_override("margin_bottom", screen_margin)
	var stack := shell.find_child("PageStack", true, false) as VBoxContainer
	if stack != null:
		stack.add_theme_constant_override("separation", 0)
	var header: Control = null
	for candidate in shell.find_children("*", "Control", true, false):
		var control := candidate as Control
		if control != null and control.get_meta(&"alveolus_component", &"") == &"page_header":
			header = control
			break
	if header != null:
		header.custom_minimum_size.y = AlveolusVisualTheme.HEADER_HEIGHT_COMPACT if compact else AlveolusVisualTheme.HEADER_HEIGHT
	var inset := shell.find_child("PageHeaderInset", true, false) as MarginContainer
	if inset != null:
		inset.add_theme_constant_override("margin_left", screen_margin)
		inset.add_theme_constant_override("margin_right", screen_margin)

static func page_header(
	title_text: String,
	eyebrow_text: String = "",
	action: Control = null,
	icon_kind: StringName = &""
) -> Dictionary:
	var header := surface(AlveolusVisualTheme.SurfaceRole.PAGE_HEADER)
	header.name = "PageHeaderSurface"
	header.set_meta(&"alveolus_component", &"page_header")
	var row := HBoxContainer.new()
	row.name = "PageHeaderRow"
	row.add_theme_constant_override("separation", AlveolusVisualTheme.SECTION_GAP)
	var resolved_icon := icon_kind if icon_kind != &"" else _page_icon_kind(title_text)
	var medallion := surface(AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET, AlveolusVisualTheme.TEAL)
	medallion.name = "PageMedallion"
	medallion.custom_minimum_size = Vector2(44.0, 44.0)
	medallion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(medallion)
	var page_icon := SimpleIcon.new()
	page_icon.name = "PageIcon"
	page_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	page_icon.configure(resolved_icon, AlveolusVisualTheme.TEAL)
	medallion.add_child(page_icon)
	var heading := VBoxContainer.new()
	heading.name = "PageHeading"
	heading.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	# The title block is one centered unit, matching the approved planning
	# header. Keeping this in the shared primitive prevents every page from
	# independently drifting toward the upper edge of the header band.
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not eyebrow_text.is_empty():
		heading.add_child(label(eyebrow_text, AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL))
	var title := label(title_text, AlveolusVisualTheme.TYPE_TITLE_LABEL)
	title.name = "PageTitle"
	# A page title must be allowed to yield horizontal space to navigation
	# actions at high UI scales. Without an overrun policy its intrinsic text
	# width expands the HBox beyond the viewport (notably "Einstellungen" and
	# the two-action Fallarchiv header at 200 percent).
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(title)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	if action != null:
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(action)
	var inset := MarginContainer.new()
	inset.name = "PageHeaderInset"
	inset.add_theme_constant_override("margin_left", AlveolusVisualTheme.SCREEN_MARGIN)
	inset.add_theme_constant_override("margin_right", AlveolusVisualTheme.SCREEN_MARGIN)
	inset.add_child(row)
	header.add_child(inset)
	return {
		"panel": header,
		"row": row,
		"heading": heading,
		"title": title,
		"action": action,
		"medallion": medallion,
		"icon": page_icon,
		"inset": inset,
	}

static func form_control_row(text_value: String, control: Control) -> Dictionary:
	var row_panel := panel(AlveolusVisualTheme.TYPE_FORM_CONTROL)
	row_panel.set_meta(&"alveolus_component", &"form_control_row")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	var title := label(text_value, AlveolusVisualTheme.TYPE_BODY_LABEL)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title)
	control.focus_mode = Control.FOCUS_ALL
	control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, AlveolusVisualTheme.TOUCH_TARGET_MINIMUM)
	row.add_child(control)
	row_panel.add_child(margin(row, 10))
	return {"panel": row_panel, "row": row, "label": title, "control": control}

static func modal_sheet(
	title_text: String,
	body: Control = null,
	actions: Array[Control] = [],
	padding: int = 20,
	accent: Color = AlveolusVisualTheme.TEAL
) -> Dictionary:
	var sheet := surface(AlveolusVisualTheme.SurfaceRole.MODAL_SHEET, accent)
	sheet.set_meta(&"alveolus_component", &"modal_sheet")
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	if not title_text.is_empty():
		stack.add_child(label(title_text, AlveolusVisualTheme.TYPE_TITLE_LABEL))
	if body != null:
		stack.add_child(body)
	var action_row: HBoxContainer = null
	if not actions.is_empty():
		action_row = HBoxContainer.new()
		action_row.alignment = BoxContainer.ALIGNMENT_END
		action_row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
		for action in actions:
			action_row.add_child(action)
		stack.add_child(action_row)
	sheet.add_child(margin(stack, padding))
	return {"panel": sheet, "content": stack, "actions": action_row}

static func tooltip_card(title_text: String, body_text: String, meta_text: String = "", accent: Color = AlveolusVisualTheme.TURQUOISE) -> Dictionary:
	return _information_card(&"tooltip_card", AlveolusVisualTheme.TYPE_TOOLTIP_CARD, title_text, body_text, meta_text, accent, 288.0, 10)

static func detail_card(title_text: String, body_text: String, meta_text: String = "", accent: Color = AlveolusVisualTheme.COBALT) -> Dictionary:
	return _information_card(&"detail_card", AlveolusVisualTheme.TYPE_DETAIL_CARD, title_text, body_text, meta_text, accent, 360.0, 12)

static func margin(content: Control, amount: int = AlveolusVisualTheme.CARD_PADDING) -> MarginContainer:
	var control := MarginContainer.new()
	control.add_theme_constant_override("margin_left", amount)
	control.add_theme_constant_override("margin_top", amount)
	control.add_theme_constant_override("margin_right", amount)
	control.add_theme_constant_override("margin_bottom", amount)
	control.add_child(content)
	return control

static func section_header(eyebrow: String, title: String, description: String = "", on_dark: bool = false) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	if not eyebrow.is_empty():
		content.add_child(label(
			eyebrow,
			AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL if on_dark else AlveolusVisualTheme.TYPE_EYEBROW_LABEL
		))
	content.add_child(label(
		title,
		AlveolusVisualTheme.TYPE_HUD_VALUE_LABEL if on_dark else AlveolusVisualTheme.TYPE_SECTION_LABEL
	))
	if not description.is_empty():
		var description_label := label(
			description,
			AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL if on_dark else AlveolusVisualTheme.TYPE_MUTED_LABEL
		)
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(description_label)
	return content

static func value_row(name_text: String, value_text: String, highlighted: bool = false) -> PanelContainer:
	var row_panel := surface(
		AlveolusVisualTheme.SurfaceRole.VALUE_ROW,
		AlveolusVisualTheme.TURQUOISE if highlighted else AlveolusVisualTheme.TEAL
	)
	row_panel.set_meta(&"alveolus_component", &"value_row")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	var name_label := label(name_text, AlveolusVisualTheme.TYPE_BODY_LABEL)
	name_label.name = "ValueName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_label)
	var value_label := label(value_text, AlveolusVisualTheme.TYPE_VALUE_LABEL)
	value_label.name = "Value"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	row_panel.add_child(margin(row, 8))
	return row_panel

static func dossier_value_row(
	name_text: String,
	value_text: String,
	icon_kind: StringName = &"",
	accent: Color = AlveolusVisualTheme.TEAL
) -> PanelContainer:
	var row_panel := panel(AlveolusVisualTheme.TYPE_DOSSIER_VALUE_ROW)
	row_panel.set_meta(&"alveolus_component", &"dossier_value_row")
	var row := HBoxContainer.new()
	row.name = "DossierValueContent"
	row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	if icon_kind != &"":
		var icon := SimpleIcon.new()
		icon.name = "ValueIcon"
		icon.custom_minimum_size = Vector2(18.0, 18.0)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.configure(icon_kind, accent)
		row.add_child(icon)
	var name_label := label(name_text, AlveolusVisualTheme.TYPE_BODY_LABEL)
	name_label.name = "ValueName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	var value_label := label(value_text, AlveolusVisualTheme.TYPE_VALUE_LABEL)
	value_label.name = "Value"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", accent.lightened(0.16))
	row.add_child(value_label)
	row_panel.add_child(margin(row, 8))
	return row_panel

static func stat_row(name_text: String, value_text: String, highlighted: bool = false) -> PanelContainer:
	return value_row(name_text, value_text, highlighted)

## Structured, non-interactive damage presentation. Callers pass a display-ready
## value (for example "+10 %" or "0 %"); this component never receives raw
## ratings and never evaluates combat formulas. The semantic type role owns the
## colour and glyph so screens do not need per-ID branches.
static func damage_type_row(
	damage_type_id: StringName,
	name_text: String,
	formatted_value: String,
	meaning_text: String = "",
	indicator_text: String = ""
) -> Dictionary:
	return _damage_type_presentation(
		damage_type_id,
		name_text,
		formatted_value,
		meaning_text,
		indicator_text,
		false
	)

static func damage_type_chip(
	damage_type_id: StringName,
	name_text: String,
	formatted_value: String,
	meaning_text: String = "",
	indicator_text: String = ""
) -> Dictionary:
	return _damage_type_presentation(
		damage_type_id,
		name_text,
		formatted_value,
		meaning_text,
		indicator_text,
		true
	)

static func semantic_copy_section(
	title_text: String,
	body_text: String,
	icon_kind: StringName,
	accent: Color
) -> Dictionary:
	var section := surface(AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET, accent)
	section.set_meta(&"alveolus_component", &"semantic_copy_section")
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	section.add_child(margin(stack, 10))
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	stack.add_child(heading)
	var icon := SimpleIcon.new()
	icon.custom_minimum_size = Vector2(22.0, 22.0)
	icon.configure(icon_kind, accent)
	heading.add_child(icon)
	var title := label(title_text, AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
	title.add_theme_color_override("font_color", accent.lightened(0.18))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(title)
	var body := label(body_text, AlveolusVisualTheme.TYPE_MUTED_LABEL)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(body)
	return {"panel": section, "title": title, "body": body, "icon": icon}

static func choice_row(
	title: String,
	description: String = "",
	meta: String = "",
	selected: bool = false,
	disabled: bool = false
) -> Button:
	return _choice_control(title, description, meta, selected, disabled, 64.0, &"choice_row")

static func choice_card(
	title: String,
	description: String,
	meta: String = "",
	selected: bool = false,
	disabled: bool = false
) -> Button:
	return _choice_control(
		title,
		description,
		meta,
		selected,
		disabled,
		float(AlveolusVisualTheme.SELECTION_CARD_HEIGHT),
		&"choice_card"
	)

static func selection_card(
	title: String,
	description: String,
	meta: String = "",
	selected: bool = false,
	disabled: bool = false
) -> Button:
	return choice_card(title, description, meta, selected, disabled)

## Structured research content is attached by the owning screen; this carrier
## centralizes the compact geometry and every native button state.
static func compact_research(selected: bool = false, disabled: bool = false) -> Button:
	return _choice_control(
		"",
		"",
		"",
		selected,
		disabled,
		AlveolusVisualTheme.COMPACT_RESEARCH_HEIGHT,
		&"compact_research"
	)

## Icon-only talent carrier. Titles and effects belong to the shared detail
## provider, never to the persistent node surface.
static func talent_node(selected: bool = false, disabled: bool = false) -> Button:
	var control := _choice_control(
		"",
		"",
		"",
		selected,
		disabled,
		AlveolusVisualTheme.TALENT_NODE_SIZE,
		&"talent_node"
	)
	control.custom_minimum_size.x = AlveolusVisualTheme.TALENT_NODE_SIZE
	return control

static func badge(text_value: String, accent: Color = AlveolusVisualTheme.COBALT) -> PanelContainer:
	var badge_panel := panel(AlveolusVisualTheme.TYPE_BADGE)
	badge_panel.add_theme_stylebox_override("panel", AlveolusVisualTheme.surface_role_style(
		AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET,
		accent,
		AlveolusVisualTheme.CornerTreatment.CONTROL_4
	))
	var text_label := label(text_value, AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
	text_label.add_theme_color_override("font_color", accent.lightened(0.20))
	badge_panel.add_child(margin(text_label, 8))
	return badge_panel


## Compact semantic marker for dense selection surfaces. The glyph and accent
## carry the visible distinction while callers retain the written meaning in
## their accessible name and presenter metadata.
static func icon_badge(
	icon_id: StringName,
	accent: Color = AlveolusVisualTheme.COBALT,
	icon_size: float = 20.0
) -> PanelContainer:
	var badge_panel := panel(AlveolusVisualTheme.TYPE_BADGE)
	badge_panel.add_theme_stylebox_override("panel", AlveolusVisualTheme.surface_role_style(
		AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET,
		accent,
		AlveolusVisualTheme.CornerTreatment.CONTROL_4
	))
	badge_panel.custom_minimum_size = Vector2(icon_size + 12.0, icon_size + 12.0)
	var icon := SimpleIcon.new()
	icon.name = "BadgeIcon"
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.configure(icon_id, accent)
	badge_panel.add_child(margin(icon, 6))
	return badge_panel

static func progress(value: float, maximum: float = 100.0, show_percentage: bool = false) -> ProgressBar:
	var control := ProgressBar.new()
	control.min_value = 0.0
	control.max_value = maximum
	control.value = clampf(value, 0.0, maximum)
	control.show_percentage = show_percentage
	control.custom_minimum_size.y = 12.0
	return control

static func apply_progress_accent(control: ProgressBar, accent: Color) -> ProgressBar:
	if control == null:
		return null
	if control.get_meta(&"alveolus_progress_accent", Color.TRANSPARENT) == accent:
		return control
	control.add_theme_stylebox_override("fill", AlveolusVisualTheme.bar_style(accent, 6))
	control.set_meta(&"alveolus_progress_accent", accent)
	return control


## Applies the shared translucent cooldown-track treatment used by occupied
## run abilities. The dark carrier keeps glyphs readable over bright tissue,
## while the coloured fill remains clearly distinct from a full HUD card.
static func apply_hud_cooldown_track(control: ProgressBar, accent: Color) -> ProgressBar:
	if control == null:
		return null
	if control.get_meta(&"alveolus_hud_cooldown_accent", Color.TRANSPARENT) == accent:
		return control
	var background := AlveolusVisualTheme.bar_style(Color(AlveolusVisualTheme.PETROL_DEEP.darkened(0.12), 0.72), 7, true)
	background.border_color = Color(accent.lightened(0.24), 0.92)
	background.set_border_width_all(1)
	control.add_theme_stylebox_override("background", background)
	control.add_theme_stylebox_override("fill", AlveolusVisualTheme.bar_style(Color(accent.darkened(0.08), 0.36), 7, true))
	control.set_meta(&"alveolus_hud_cooldown_accent", accent)
	return control

static func vertical_rule() -> VSeparator:
	var separator := VSeparator.new()
	separator.add_theme_color_override("separator_color", AlveolusVisualTheme.HAIRLINE)
	return separator

static func refresh_button_state(button_control: BaseButton) -> void:
	if button_control == null:
		return
	if button_control.has_method(&"refresh_state"):
		button_control.call(&"refresh_state")
	var fill := button_control.get_node_or_null("BioLumenFill") as BioLumenButtonFill
	if fill != null:
		fill.refresh_state()
	var planning_fill := button_control.get_node_or_null("PreparationBioLumenFill") as PreparationBioLumenFill
	if planning_fill != null:
		planning_fill.refresh_state()
	var surface_fill := button_control.get_node_or_null("MembraneFill") as PreparationBioLumenSurfaceFill
	if surface_fill != null:
		surface_fill.refresh_state()

static func set_button_disabled(button_control: BaseButton, disabled: bool) -> void:
	if button_control == null:
		return
	button_control.disabled = disabled
	refresh_button_state(button_control)

## Applies one semantic action role to an existing button. Screen code may
## still own text, signals and layout width, while every visible state remains
## sourced from the shared theme/component family.
static func apply_action_role(
	button_control: Button,
	role: StringName = ACTION_SECONDARY,
	accent: Color = AlveolusVisualTheme.TEAL
) -> Button:
	if button_control == null:
		return null
	var resolved_accent := AlveolusVisualTheme.TEAL if role == ACTION_PRIMARY else accent
	button_control.theme_type_variation = _variation_for_role(role)
	button_control.custom_minimum_size.y = maxf(
		button_control.custom_minimum_size.y,
		AlveolusVisualTheme.BUTTON_HEIGHT_PRIMARY if role in [ACTION_PRIMARY, ACTION_PLANNING_START] else AlveolusVisualTheme.TOUCH_TARGET_MINIMUM
	)
	button_control.focus_mode = Control.FOCUS_ALL
	button_control.scale = Vector2.ONE
	button_control.set_meta(&"disable_motion_scale", true)
	button_control.set_meta(&"alveolus_component", &"action_button")
	button_control.set_meta(&"alveolus_action_role", role)
	var accessible_name := button_control.text
	if button_control is IconTextButton and (button_control as IconTextButton).caption != null:
		accessible_name = (button_control as IconTextButton).caption.text
	button_control.set_meta(&"alveolus_accessible_name", accessible_name)
	var icon_kind := &""
	if button_control is IconTextButton:
		var icon_button := button_control as IconTextButton
		if icon_button.icon_view != null:
			icon_kind = icon_button.icon_view.kind
			icon_button.accent = resolved_accent
			icon_button.icon_view.configure(icon_kind, resolved_accent, icon_button.icon_view.framed)
		icon_button.set_content_on_light(role in [ACTION_PRIMARY, ACTION_PLANNING_START])
	button_control.set_meta(&"ui_sound_cue", _sound_cue_for(role, icon_kind))

	var global_fill := button_control.get_node_or_null("BioLumenFill") as BioLumenButtonFill
	var planning_fill := button_control.get_node_or_null("PreparationBioLumenFill") as PreparationBioLumenFill
	var navigation_fill := button_control.get_node_or_null("MembraneFill") as PreparationBioLumenSurfaceFill
	if role == ACTION_PRIMARY:
		global_fill = BioLumenButtonFill.attach(button_control, resolved_accent)
		global_fill.show()
		if planning_fill != null:
			planning_fill.hide()
		if navigation_fill != null:
			navigation_fill.hide()
	elif role == ACTION_PLANNING_START:
		planning_fill = PreparationBioLumenFill.attach(button_control, AlveolusVisualTheme.TURQUOISE, AlveolusVisualTheme.GOLD)
		planning_fill.show()
		if global_fill != null:
			global_fill.hide()
		if navigation_fill != null:
			navigation_fill.hide()
	elif role == ACTION_NAVIGATION:
		navigation_fill = PreparationBioLumenSurfaceFill.attach(
			button_control,
			PreparationBioLumenSurfaceFill.NORMAL_LEFT,
			PreparationBioLumenSurfaceFill.NORMAL_RIGHT,
			11.0,
			3.0
		)
		navigation_fill.show()
		if global_fill != null:
			global_fill.hide()
		if planning_fill != null:
			planning_fill.hide()
	else:
		if global_fill != null:
			global_fill.hide()
		if planning_fill != null:
			planning_fill.hide()
		if navigation_fill != null:
			navigation_fill.hide()
	refresh_button_state(button_control)
	return button_control

static func _information_card(
	component_name: StringName,
	variation: StringName,
	title_text: String,
	body_text: String,
	meta_text: String,
	accent: Color,
	maximum_width: float,
	padding: int
) -> Dictionary:
	var card := panel(variation)
	# The positioning controller supplies an actual width only when wrapping is
	# needed. A hard minimum would reintroduce the empty tooltip slabs the visual
	# contract explicitly forbids.
	card.custom_minimum_size.x = 0.0
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.set_meta(&"alveolus_component", component_name)
	card.set_meta(&"alveolus_maximum_width", maximum_width)
	if accent != AlveolusVisualTheme.TEAL:
		var role := AlveolusVisualTheme.SurfaceRole.TOOLTIP_CARD if variation == AlveolusVisualTheme.TYPE_TOOLTIP_CARD else AlveolusVisualTheme.SurfaceRole.DETAIL_CARD
		card.add_theme_stylebox_override("panel", AlveolusVisualTheme.surface_role_style(role, accent))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	var title := label(title_text, AlveolusVisualTheme.TYPE_VALUE_LABEL)
	stack.add_child(title)
	var body := label(body_text, AlveolusVisualTheme.TYPE_MUTED_LABEL)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(body)
	var meta_label: Label = null
	if not meta_text.is_empty():
		meta_label = label(meta_text, AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
		meta_label.add_theme_color_override("font_color", accent.lightened(0.12))
		stack.add_child(meta_label)
	card.add_child(margin(stack, padding))
	return {"panel": card, "content": stack, "title": title, "body": body, "meta": meta_label}

static func _damage_type_presentation(
	damage_type_id: StringName,
	name_text: String,
	formatted_value: String,
	meaning_text: String,
	indicator_text: String,
	compact: bool
) -> Dictionary:
	var accent := AlveolusVisualTheme.damage_type_accent(damage_type_id)
	var icon_kind := AlveolusVisualTheme.damage_type_icon_kind(damage_type_id)
	var resolved_name := name_text if not name_text.is_empty() else AlveolusVisualTheme.damage_type_display_name(damage_type_id)
	var resolved_value := formatted_value if not formatted_value.is_empty() else "—"
	var component_name := &"damage_type_chip" if compact else &"damage_type_row"
	var control := PanelContainer.new()
	control.name = "%s_%s" % ["DamageTypeChip" if compact else "DamageTypeRow", damage_type_id]
	control.theme_type_variation = AlveolusVisualTheme.TYPE_DAMAGE_TYPE_CHIP if compact else AlveolusVisualTheme.TYPE_DAMAGE_TYPE_ROW
	control.custom_minimum_size.y = 44.0 if compact else 52.0
	control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if compact else Control.SIZE_EXPAND_FILL
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.set_meta(&"alveolus_component", component_name)
	control.set_meta(&"damage_type_id", damage_type_id)
	control.set_meta(&"damage_type_accent", accent)
	control.set_meta(&"damage_type_icon_kind", icon_kind)
	control.set_meta(&"damage_type_value_is_formatted", true)
	var accessible_value := "%s%s" % [indicator_text, resolved_value]
	var accessible_name := "%s, %s" % [resolved_name, accessible_value]
	if not meaning_text.is_empty():
		accessible_name += ", %s" % meaning_text
	control.set_meta(&"alveolus_accessible_name", accessible_name)

	var row := HBoxContainer.new()
	row.name = "DamageTypeContent"
	row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	var icon := SimpleIcon.new()
	icon.name = "DamageTypeIcon"
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.configure(icon_kind, accent)
	row.add_child(icon)

	var identity := VBoxContainer.new()
	identity.name = "DamageTypeIdentity"
	identity.add_theme_constant_override("separation", 0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := label(resolved_name, AlveolusVisualTheme.TYPE_BODY_LABEL)
	name_label.name = "DamageTypeName"
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity.add_child(name_label)
	var meaning_label: Label = null
	if not meaning_text.is_empty():
		meaning_label = label(meaning_text, AlveolusVisualTheme.TYPE_MUTED_LABEL)
		meaning_label.name = "DamageTypeMeaning"
		meaning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		identity.add_child(meaning_label)
	row.add_child(identity)

	var value_group := HBoxContainer.new()
	value_group.name = "DamageTypeValueGroup"
	value_group.alignment = BoxContainer.ALIGNMENT_END
	value_group.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	value_group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var indicator_label: Label = null
	if not indicator_text.is_empty():
		indicator_label = label(indicator_text, AlveolusVisualTheme.TYPE_VALUE_LABEL)
		indicator_label.name = "DamageTypeIndicator"
		indicator_label.add_theme_color_override("font_color", accent)
		value_group.add_child(indicator_label)
	var value_label := label(resolved_value, AlveolusVisualTheme.TYPE_VALUE_LABEL)
	value_label.name = "DamageTypeValue"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", accent)
	value_group.add_child(value_label)
	row.add_child(value_group)
	control.add_child(margin(row, 8))
	return {
		"panel": control,
		"row": row,
		"icon": icon,
		"name": name_label,
		"meaning": meaning_label,
		"indicator": indicator_label,
		"value": value_label,
	}

static func _build_action_button(
	text_value: String,
	variation: StringName,
	icon_kind: StringName,
	accent: Color,
	role: StringName
) -> Button:
	var resolved_accent := AlveolusVisualTheme.TEAL if role == ACTION_PRIMARY else accent
	var control: Button
	if icon_kind.is_empty():
		control = Button.new()
		control.text = text_value
	else:
		var icon_button := IconTextButton.new()
		icon_button.configure(text_value, icon_kind, resolved_accent, 19.0 if role == ACTION_NAVIGATION else 22.0, 8)
		icon_button.set_content_on_light(role in [ACTION_PRIMARY, ACTION_PLANNING_START])
		control = icon_button
	control.theme_type_variation = variation
	apply_action_role(control, role, resolved_accent)
	return control

static func _choice_control(
	title: String,
	description: String,
	meta: String,
	selected: bool,
	disabled: bool,
	minimum_height: float,
	component_name: StringName
) -> Button:
	var control := Button.new()
	match component_name:
		&"choice_row":
			control.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTED_CHOICE_ROW if selected else AlveolusVisualTheme.TYPE_CHOICE_ROW
		&"compact_research":
			control.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTED_COMPACT_RESEARCH if selected else AlveolusVisualTheme.TYPE_COMPACT_RESEARCH
		&"talent_node":
			control.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTED_TALENT_NODE if selected else AlveolusVisualTheme.TYPE_TALENT_NODE
		_:
			control.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTED_CARD if selected else AlveolusVisualTheme.TYPE_SELECTION_CARD
	control.text = title if description.is_empty() else "%s\n%s" % [title, description]
	if not meta.is_empty():
		control.text += "\n%s" % meta
	control.alignment = HORIZONTAL_ALIGNMENT_LEFT
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	control.custom_minimum_size.y = minimum_height
	control.disabled = disabled
	control.focus_mode = Control.FOCUS_ALL
	control.scale = Vector2.ONE
	control.set_meta(&"disable_motion_scale", true)
	control.set_meta(&"alveolus_component", component_name)
	control.set_meta(&"alveolus_accessible_name", title)
	return control

static func _variation_for_role(role: StringName) -> StringName:
	match role:
		ACTION_PRIMARY:
			return AlveolusVisualTheme.TYPE_PRIMARY_BUTTON
		ACTION_DANGER:
			return AlveolusVisualTheme.TYPE_DANGER_BUTTON
		ACTION_QUIET:
			return AlveolusVisualTheme.TYPE_QUIET_BUTTON
		ACTION_NAVIGATION:
			return AlveolusVisualTheme.TYPE_NAVIGATION_BUTTON
		ACTION_PLANNING_START:
			return AlveolusVisualTheme.TYPE_PRIMARY_BUTTON
	return AlveolusVisualTheme.TYPE_SECONDARY_BUTTON

static func _role_for_variation(variation: StringName) -> StringName:
	match variation:
		AlveolusVisualTheme.TYPE_PRIMARY_BUTTON:
			return ACTION_PRIMARY
		AlveolusVisualTheme.TYPE_DANGER_BUTTON:
			return ACTION_DANGER
		AlveolusVisualTheme.TYPE_QUIET_BUTTON:
			return ACTION_QUIET
		AlveolusVisualTheme.TYPE_NAVIGATION_BUTTON:
			return ACTION_NAVIGATION
	return ACTION_SECONDARY

static func _variation_for_surface_role(role: int) -> StringName:
	match role:
		AlveolusVisualTheme.SurfaceRole.PAGE_CANVAS:
			return AlveolusVisualTheme.TYPE_PAGE_CANVAS
		AlveolusVisualTheme.SurfaceRole.ACTION_CARD:
			return AlveolusVisualTheme.TYPE_ACTION_CARD
		AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET:
			return AlveolusVisualTheme.TYPE_DOCUMENT_INSET
		AlveolusVisualTheme.SurfaceRole.MODAL_SHEET:
			return AlveolusVisualTheme.TYPE_MODAL_SHEET
		AlveolusVisualTheme.SurfaceRole.HUD_VITAL:
			return AlveolusVisualTheme.TYPE_HUD_VITAL
		AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE:
			return AlveolusVisualTheme.TYPE_HUD_OBJECTIVE
		AlveolusVisualTheme.SurfaceRole.HUD_ABILITY:
			return AlveolusVisualTheme.TYPE_HUD_ABILITY
		AlveolusVisualTheme.SurfaceRole.HUD_ALERT:
			return AlveolusVisualTheme.TYPE_HUD_ALERT
		AlveolusVisualTheme.SurfaceRole.PAGE_HEADER:
			return AlveolusVisualTheme.TYPE_PAGE_HEADER
		AlveolusVisualTheme.SurfaceRole.FORM_CONTROL:
			return AlveolusVisualTheme.TYPE_FORM_CONTROL
		AlveolusVisualTheme.SurfaceRole.VALUE_ROW:
			return AlveolusVisualTheme.TYPE_VALUE_ROW
		AlveolusVisualTheme.SurfaceRole.TOOLTIP_CARD:
			return AlveolusVisualTheme.TYPE_TOOLTIP_CARD
		AlveolusVisualTheme.SurfaceRole.DETAIL_CARD:
			return AlveolusVisualTheme.TYPE_DETAIL_CARD
	return AlveolusVisualTheme.TYPE_SECTION_GROUP

static func _surface_role_for_variation(variation: StringName) -> int:
	match variation:
		AlveolusVisualTheme.TYPE_PAGE_CANVAS:
			return AlveolusVisualTheme.SurfaceRole.PAGE_CANVAS
		AlveolusVisualTheme.TYPE_SECTION_GROUP:
			return AlveolusVisualTheme.SurfaceRole.SECTION_GROUP
		AlveolusVisualTheme.TYPE_ACTION_CARD:
			return AlveolusVisualTheme.SurfaceRole.ACTION_CARD
		AlveolusVisualTheme.TYPE_DOCUMENT_INSET:
			return AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET
		AlveolusVisualTheme.TYPE_MODAL_SHEET:
			return AlveolusVisualTheme.SurfaceRole.MODAL_SHEET
		AlveolusVisualTheme.TYPE_HUD_VITAL:
			return AlveolusVisualTheme.SurfaceRole.HUD_VITAL
		AlveolusVisualTheme.TYPE_HUD_OBJECTIVE:
			return AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE
		AlveolusVisualTheme.TYPE_HUD_ABILITY:
			return AlveolusVisualTheme.SurfaceRole.HUD_ABILITY
		AlveolusVisualTheme.TYPE_HUD_ALERT:
			return AlveolusVisualTheme.SurfaceRole.HUD_ALERT
		AlveolusVisualTheme.TYPE_PAGE_HEADER:
			return AlveolusVisualTheme.SurfaceRole.PAGE_HEADER
		AlveolusVisualTheme.TYPE_FORM_CONTROL:
			return AlveolusVisualTheme.SurfaceRole.FORM_CONTROL
		AlveolusVisualTheme.TYPE_VALUE_ROW:
			return AlveolusVisualTheme.SurfaceRole.VALUE_ROW
		AlveolusVisualTheme.TYPE_TOOLTIP_CARD:
			return AlveolusVisualTheme.SurfaceRole.TOOLTIP_CARD
		AlveolusVisualTheme.TYPE_DETAIL_CARD:
			return AlveolusVisualTheme.SurfaceRole.DETAIL_CARD
	return -1

static func _default_accent_for_surface_role(role: int) -> Color:
	match role:
		AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE:
			return AlveolusVisualTheme.COBALT
		AlveolusVisualTheme.SurfaceRole.HUD_ABILITY:
			return AlveolusVisualTheme.TURQUOISE
		AlveolusVisualTheme.SurfaceRole.HUD_ALERT:
			return AlveolusVisualTheme.CORAL
		AlveolusVisualTheme.SurfaceRole.DETAIL_CARD:
			return AlveolusVisualTheme.COBALT
	return AlveolusVisualTheme.TEAL


static func _surface_membrane(role: int, accent: Color) -> Dictionary:
	var left := Color.TRANSPARENT
	var right := Color.TRANSPARENT
	var radii := Vector4(6.0, 6.0, 6.0, 6.0)
	var energy := 1.0
	match role:
		AlveolusVisualTheme.SurfaceRole.SECTION_GROUP:
			left = Color("0d3b40").lerp(accent, 0.08)
			right = Color("061f26")
			radii = Vector4.ZERO
			energy = 0.96
		AlveolusVisualTheme.SurfaceRole.ACTION_CARD:
			left = Color("145052").lerp(accent, 0.08)
			right = Color("082b31")
		AlveolusVisualTheme.SurfaceRole.MODAL_SHEET:
			left = Color("103f45").lerp(accent, 0.06)
			right = Color("061f27")
			radii = Vector4(6.0, 0.0, 6.0, 6.0)
		AlveolusVisualTheme.SurfaceRole.PAGE_HEADER:
			left = Color("0d3b40")
			right = Color("061e25")
			radii = Vector4.ZERO
			energy = 0.94
		AlveolusVisualTheme.SurfaceRole.HUD_VITAL:
			left = Color("124a4b").lerp(accent, 0.10)
			right = Color("061f26")
			radii = Vector4(4.0, 4.0, 4.0, 4.0)
		AlveolusVisualTheme.SurfaceRole.HUD_OBJECTIVE:
			left = Color("123f48").lerp(accent, 0.08)
			right = Color("071f28")
			radii = Vector4(4.0, 4.0, 4.0, 4.0)
		AlveolusVisualTheme.SurfaceRole.HUD_ABILITY:
			left = Color("10484b").lerp(accent, 0.10)
			right = Color("061f26")
		AlveolusVisualTheme.SurfaceRole.HUD_ALERT:
			left = Color("153e42").lerp(accent, 0.10)
			right = Color("071f27")
		AlveolusVisualTheme.SurfaceRole.TOOLTIP_CARD:
			left = Color("0b353a").lerp(accent, 0.06)
			right = Color("061e25")
			radii = Vector4(4.0, 4.0, 4.0, 4.0)
		AlveolusVisualTheme.SurfaceRole.DETAIL_CARD:
			left = Color("0f4447").lerp(accent, 0.06)
			right = Color("07242b")
		_:
			return {}
	return {"left": left, "right": right, "radii": radii, "energy": energy}

static func _sound_cue_for(role: StringName, icon_kind: StringName) -> StringName:
	if role in [ACTION_PRIMARY, ACTION_PLANNING_START]:
		return &"confirm"
	if role == ACTION_NAVIGATION or icon_kind == &"back":
		return &"back"
	return &"press"

static func _page_icon_kind(title_text: String) -> StringName:
	match title_text.to_upper():
		"PRAXIS":
			return &"practice"
		"FORSCHUNG", "TALENTE":
			return &"research"
		"FALLARCHIV":
			return &"archive"
		"LEXIKON":
			return &"lexicon"
		"EINSTELLUNGEN":
			return &"settings"
		"EINSATZPLANUNG":
			return &"plan"
	return &"information"

static func _slider_value_text(value: float, step: float) -> String:
	return "%d" % roundi(value) if step >= 1.0 else "%.1f" % value
