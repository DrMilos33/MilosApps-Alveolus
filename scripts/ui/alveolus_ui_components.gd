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

static func segmented_tab(text_value: String, selected: bool = false, group: ButtonGroup = null) -> Button:
	var control := Button.new()
	control.text = text_value
	control.toggle_mode = true
	control.button_group = group
	control.button_pressed = selected
	control.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTED_SEGMENTED_TAB if selected else AlveolusVisualTheme.TYPE_SEGMENTED_TAB
	control.custom_minimum_size.y = AlveolusVisualTheme.TOUCH_TARGET_MINIMUM
	control.focus_mode = Control.FOCUS_ALL
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
	row.add_child(title)
	var control := OptionButton.new()
	control.theme_type_variation = AlveolusVisualTheme.TYPE_OPTION_ROW
	control.custom_minimum_size = Vector2(176.0, AlveolusVisualTheme.TOUCH_TARGET_MINIMUM)
	control.focus_mode = Control.FOCUS_ALL
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
	return control

static func surface(role: int, accent: Color = AlveolusVisualTheme.TEAL) -> PanelContainer:
	var control := PanelContainer.new()
	control.theme_type_variation = _variation_for_surface_role(role)
	if accent != AlveolusVisualTheme.TEAL:
		control.add_theme_stylebox_override("panel", AlveolusVisualTheme.surface_role_style(role, accent))
	control.set_meta(&"alveolus_surface_role", role)
	return control

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

static func stat_row(name_text: String, value_text: String, highlighted: bool = false) -> PanelContainer:
	var row_panel := panel(AlveolusVisualTheme.TYPE_ACTION_CARD if highlighted else AlveolusVisualTheme.TYPE_DOCUMENT_INSET)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	var name_label := label(name_text, AlveolusVisualTheme.TYPE_BODY_LABEL)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_label)
	var value_label := label(value_text, AlveolusVisualTheme.TYPE_VALUE_LABEL)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	row_panel.add_child(margin(row, 8))
	return row_panel

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
	return _choice_control(title, description, meta, selected, disabled, 88.0, &"choice_card")

static func selection_card(
	title: String,
	description: String,
	meta: String = "",
	selected: bool = false,
	disabled: bool = false
) -> Button:
	return choice_card(title, description, meta, selected, disabled)

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

static func progress(value: float, maximum: float = 100.0, show_percentage: bool = false) -> ProgressBar:
	var control := ProgressBar.new()
	control.min_value = 0.0
	control.max_value = maximum
	control.value = clampf(value, 0.0, maximum)
	control.show_percentage = show_percentage
	control.custom_minimum_size.y = 12.0
	return control

static func vertical_rule() -> VSeparator:
	var separator := VSeparator.new()
	separator.add_theme_color_override("separator_color", AlveolusVisualTheme.HAIRLINE)
	return separator

static func _build_action_button(
	text_value: String,
	variation: StringName,
	icon_kind: StringName,
	accent: Color,
	role: StringName
) -> Button:
	var control: Button
	if icon_kind.is_empty():
		control = Button.new()
		control.text = text_value
	else:
		var icon_button := IconTextButton.new()
		icon_button.configure(text_value, icon_kind, accent, 22.0, 8)
		icon_button.set_content_on_light(role == ACTION_PRIMARY)
		control = icon_button
	control.theme_type_variation = variation
	control.custom_minimum_size.y = maxf(
		control.custom_minimum_size.y,
		AlveolusVisualTheme.BUTTON_HEIGHT_PRIMARY if role == ACTION_PRIMARY else AlveolusVisualTheme.TOUCH_TARGET_MINIMUM
	)
	control.focus_mode = Control.FOCUS_ALL
	control.set_meta(&"alveolus_component", &"action_button")
	control.set_meta(&"alveolus_action_role", role)
	control.set_meta(&"alveolus_accessible_name", text_value)
	control.set_meta(&"ui_sound_cue", _sound_cue_for(role, icon_kind))
	if role == ACTION_PRIMARY:
		BioLumenButtonFill.attach(control, accent)
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
	return AlveolusVisualTheme.TYPE_SECONDARY_BUTTON

static func _role_for_variation(variation: StringName) -> StringName:
	match variation:
		AlveolusVisualTheme.TYPE_PRIMARY_BUTTON:
			return ACTION_PRIMARY
		AlveolusVisualTheme.TYPE_DANGER_BUTTON:
			return ACTION_DANGER
		AlveolusVisualTheme.TYPE_QUIET_BUTTON:
			return ACTION_QUIET
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
	return AlveolusVisualTheme.TYPE_SECTION_GROUP

static func _sound_cue_for(role: StringName, icon_kind: StringName) -> StringName:
	if role == ACTION_PRIMARY:
		return &"confirm"
	if role == ACTION_NAVIGATION or icon_kind == &"back":
		return &"back"
	return &"press"

static func _slider_value_text(value: float, step: float) -> String:
	return "%d" % roundi(value) if step >= 1.0 else "%.1f" % value
