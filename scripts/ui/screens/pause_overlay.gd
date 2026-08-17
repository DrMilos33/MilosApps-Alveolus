class_name PauseOverlay
extends Control

## Bio-Lumen pause overlay with an embedded character-values mode.
##
## The overlay renders immutable PauseOverlayViewModel data and emits intents.
## Routing, simulation pause and confirmation dialogs remain responsibilities
## of GameHUD/Game. Only the body viewport may scroll; title and the active
## return/continue action remain fixed and visible.

signal resume_requested
signal settings_requested
signal stats_requested
signal abort_requested
signal intro_skip_requested
signal back_requested

enum Mode {
	MENU,
	STATS,
}

const MENU_MAXIMUM_WIDTH := 620.0
const STATS_MAXIMUM_WIDTH := 820.0
const COMPACT_MENU_BREAKPOINT := 560.0
# Two compact value columns remain readable down to the 480 x 270 logical
# viewport used by 960 x 540 at 200 percent. Only genuinely narrow layouts
# collapse to one column.
const COMPACT_STATS_BREAKPOINT := 400.0
const MODAL_PADDING := 20
const COMPACT_MODAL_PADDING := 16
const STAT_LABEL_MINIMUM_WIDTH := 64.0
# At the two-column 480-px layout the caption and measured value share a
# stable text budget. Short values therefore leave more room for their label,
# while long values keep their full 56–120-px value column and trim only the
# caption (the row tooltip remains unabridged).
const COMPACT_STAT_TEXT_MINIMUM_WIDTH := 136.0
const COMPACT_STAT_LABEL_FLOOR := 16.0

var _view_model: PauseOverlayViewModel
var _mode := Mode.MENU
var _applied_revision := -1
var _applied_content_hash := ""

var _backdrop: ColorRect
var _safe_area: MarginContainer
var _center: CenterContainer
var _sheet: PanelContainer
var _sheet_margin: MarginContainer
var _sheet_stack: VBoxContainer
var _pause_header: VBoxContainer
var _doctor_balance: Control
var _title_label: Label
var _doctor_label: Label
var _body_scroll: ScrollContainer
var _scrollbar_inset: MarginContainer
var _body_stack: VBoxContainer
var _menu_body: VBoxContainer
var _menu_actions: GridContainer
var _menu_danger_row: HBoxContainer
var _stats_body: VBoxContainer
var _stats_grid: GridContainer
var _empty_stats_label: Label
var _footer_actions: HBoxContainer

var _resume_button: Button
var _settings_button: Button
var _stats_button: Button
var _abort_button: Button
var _intro_skip_button: Button
var _back_button: Button
var _stat_rows: Array[PanelContainer] = []


func _init() -> void:
	name = "PauseOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	set_process(false)
	set_physics_process(false)
	_build()
	resized.connect(_queue_responsive_layout)


func apply_view_model(view_model: PauseOverlayViewModel, mode: int = Mode.MENU) -> bool:
	if view_model == null or mode < Mode.MENU or mode > Mode.STATS:
		return false
	if _applied_revision >= 0 and view_model.revision() < _applied_revision:
		return false

	var content_changed := view_model.content_hash() != _applied_content_hash
	var mode_changed := mode != _mode
	var revision_changed := view_model.revision() != _applied_revision
	if not content_changed and not mode_changed and not revision_changed:
		return false

	_view_model = view_model
	_applied_revision = view_model.revision()
	_applied_content_hash = view_model.content_hash()
	if content_changed:
		_rebuild_stat_rows()
	AlveolusUIComponents.set_button_disabled(_stats_button, not view_model.has_stats())
	_intro_skip_button.visible = view_model.show_intro_skip()
	_apply_mode(mode)
	# A newer presenter revision with identical visible data is acknowledged but
	# intentionally causes no layout churn.
	return content_changed or mode_changed


func present(view_model: PauseOverlayViewModel, mode: int = Mode.MENU, request_focus: bool = true) -> bool:
	var changed := apply_view_model(view_model, mode)
	show()
	if request_focus:
		grab_initial_focus.call_deferred()
	return changed


func dismiss() -> void:
	hide()


func set_mode(mode: int, request_focus: bool = true) -> bool:
	if mode < Mode.MENU or mode > Mode.STATS or mode == _mode:
		return false
	_apply_mode(mode)
	if request_focus:
		grab_initial_focus.call_deferred()
	return true


## UIScreenRouter/GameHUD can call this for ui_cancel without installing a
## second input listener. Exactly one back intent is emitted in either mode.
func handle_ui_cancel() -> bool:
	if not is_inside_tree() or not is_visible_in_tree():
		return false
	back_requested.emit()
	return true


func grab_initial_focus() -> bool:
	var target := _resume_button if _mode == Mode.MENU else _back_button
	if not is_inside_tree() or not is_visible_in_tree() or target == null or not target.is_visible_in_tree():
		return false
	target.grab_focus()
	_ensure_focus_visible.call_deferred(target)
	return true


func current_mode() -> int:
	return _mode


func applied_revision() -> int:
	return _applied_revision


func applied_content_hash() -> String:
	return _applied_content_hash


func title_text() -> String:
	return _title_label.text


func modal_sheet() -> PanelContainer:
	return _sheet


func body_scroll() -> ScrollContainer:
	return _body_scroll


func menu_action_grid() -> GridContainer:
	return _menu_actions


func stats_grid() -> GridContainer:
	return _stats_grid


func stat_rows() -> Array[PanelContainer]:
	var result: Array[PanelContainer] = []
	result.assign(_stat_rows)
	return result


func resume_action() -> Button:
	return _resume_button


func settings_action() -> Button:
	return _settings_button


func stats_action() -> Button:
	return _stats_button


func abort_action() -> Button:
	return _abort_button


func intro_skip_action() -> Button:
	return _intro_skip_button


func back_action() -> Button:
	return _back_button


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "ModalBackdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(AlveolusVisualTheme.PETROL_DEEP, 0.82)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_meta(&"alveolus_component", &"modal_backdrop")
	add_child(_backdrop)

	_safe_area = MarginContainer.new()
	_safe_area.name = "SafeArea"
	_safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.add_child(_safe_area)

	_center = CenterContainer.new()
	_center.name = "PauseCenter"
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center.resized.connect(_queue_responsive_layout)
	_safe_area.add_child(_center)

	_body_scroll = ScrollContainer.new()
	_body_scroll.name = "PauseBodyScroll"
	_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.follow_focus = true
	_body_scroll.resized.connect(_queue_responsive_layout)

	_scrollbar_inset = MarginContainer.new()
	_scrollbar_inset.name = "ScrollbarSafeInset"
	_scrollbar_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.add_child(_scrollbar_inset)

	_body_stack = VBoxContainer.new()
	_body_stack.name = "BodyStack"
	_body_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_stack.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	_scrollbar_inset.add_child(_body_stack)

	_build_menu_body()
	_build_stats_body()

	_resume_button = AlveolusUIComponents.action_button(
		"Weiter",
		AlveolusUIComponents.ACTION_PRIMARY,
		&"play"
	)
	_resume_button.name = "Resume"
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())

	_back_button = AlveolusUIComponents.action_button(
		"Zurück",
		AlveolusUIComponents.ACTION_SECONDARY,
		&"back",
		AlveolusVisualTheme.COBALT
	)
	_back_button.name = "Back"
	_back_button.pressed.connect(func() -> void: back_requested.emit())

	var footer_buttons: Array[Control] = [_resume_button, _back_button]
	var sheet_parts := AlveolusUIComponents.modal_sheet(
		"",
		_body_scroll,
		footer_buttons,
		MODAL_PADDING,
		AlveolusVisualTheme.COBALT
	)
	_sheet = sheet_parts["panel"] as PanelContainer
	_sheet.name = "PauseSheet"
	_sheet_stack = sheet_parts["content"] as VBoxContainer
	_sheet_margin = _sheet_stack.get_parent() as MarginContainer
	_footer_actions = sheet_parts["actions"] as HBoxContainer

	_pause_header = VBoxContainer.new()
	_pause_header.name = "PauseHeader"
	_pause_header.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	var title_line := HBoxContainer.new()
	title_line.name = "PauseTitleLine"
	title_line.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	_doctor_balance = Control.new()
	_doctor_balance.name = "DoctorBalance"
	_doctor_balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_doctor_balance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_line.add_child(_doctor_balance)
	_title_label = AlveolusUIComponents.label("Pause", AlveolusVisualTheme.TYPE_TITLE_LABEL)
	_title_label.name = "Title"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_line.add_child(_title_label)
	_doctor_label = AlveolusUIComponents.label("Doctor Milos", AlveolusVisualTheme.TYPE_MUTED_LABEL)
	_doctor_label.name = "DoctorMeta"
	_doctor_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_line.add_child(_doctor_label)
	_sync_doctor_balance.call_deferred()
	_pause_header.add_child(title_line)
	_sheet_stack.add_child(_pause_header)
	_sheet_stack.move_child(_pause_header, 0)
	_center.add_child(_sheet)

	var all_buttons: Array[Button] = [
		_resume_button,
		_settings_button,
		_stats_button,
		_abort_button,
		_intro_skip_button,
		_back_button,
	]
	for button in all_buttons:
		button.focus_entered.connect(_ensure_focus_visible.bind(button))
	_apply_mode(Mode.MENU)


func _build_menu_body() -> void:
	_menu_body = VBoxContainer.new()
	_menu_body.name = "MenuBody"
	_menu_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_body.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	_body_stack.add_child(_menu_body)

	_menu_actions = GridContainer.new()
	_menu_actions.name = "PauseActions"
	_menu_actions.columns = 3
	_menu_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_actions.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_menu_actions.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	_menu_body.add_child(_menu_actions)

	# At compact sizes the danger action moves into this dedicated full-width
	# row. This keeps the two routine actions side by side and all three menu
	# intents visible above the fixed Continue footer at 480 x 270 logical.
	_menu_danger_row = HBoxContainer.new()
	_menu_danger_row.name = "DangerRow"
	_menu_danger_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_danger_row.hide()
	_menu_body.add_child(_menu_danger_row)

	_settings_button = AlveolusUIComponents.action_button(
		"Einstellungen",
		AlveolusUIComponents.ACTION_SECONDARY,
		&"settings",
		AlveolusVisualTheme.COBALT
	)
	_settings_button.name = "Settings"
	_settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_button.pressed.connect(func() -> void: settings_requested.emit())
	_menu_actions.add_child(_settings_button)

	_stats_button = AlveolusUIComponents.action_button(
		"Charakterwerte",
		AlveolusUIComponents.ACTION_SECONDARY,
		&"information",
		AlveolusVisualTheme.TEAL
	)
	_stats_button.name = "Stats"
	_stats_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_button.pressed.connect(func() -> void: stats_requested.emit())
	_menu_actions.add_child(_stats_button)

	_abort_button = AlveolusUIComponents.action_button(
		"Runde abbrechen",
		AlveolusUIComponents.ACTION_DANGER,
		&"exit",
		AlveolusVisualTheme.CORAL
	)
	_abort_button.name = "Abort"
	_abort_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_abort_button.pressed.connect(func() -> void: abort_requested.emit())
	_menu_actions.add_child(_abort_button)

	_intro_skip_button = AlveolusUIComponents.action_button(
		"Einführung überspringen",
		AlveolusUIComponents.ACTION_QUIET,
		&"story",
		AlveolusVisualTheme.GOLD
	)
	_intro_skip_button.name = "IntroSkip"
	_intro_skip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_intro_skip_button.hide()
	_intro_skip_button.pressed.connect(func() -> void: intro_skip_requested.emit())
	_menu_actions.add_child(_intro_skip_button)


func _build_stats_body() -> void:
	_stats_body = VBoxContainer.new()
	_stats_body.name = "StatsBody"
	_stats_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_body.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	_body_stack.add_child(_stats_body)

	_empty_stats_label = AlveolusUIComponents.label(
		"Noch keine Rundenwerte verfügbar.",
		AlveolusVisualTheme.TYPE_MUTED_LABEL
	)
	_empty_stats_label.name = "EmptyStats"
	_empty_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_body.add_child(_empty_stats_label)

	_stats_grid = GridContainer.new()
	_stats_grid.name = "StatColumns"
	_stats_grid.columns = 2
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTENT_GAP)
	_stats_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.GRID_UNIT)
	_stats_body.add_child(_stats_grid)


func _rebuild_stat_rows() -> void:
	for child in _stats_grid.get_children():
		_stats_grid.remove_child(child)
		child.queue_free()
	_stat_rows.clear()
	if _view_model == null:
		_empty_stats_label.show()
		_stats_grid.hide()
		return
	_empty_stats_label.visible = not _view_model.has_stats()
	_stats_grid.visible = _view_model.has_stats()
	for stat in _view_model.stats():
		var row_panel := AlveolusUIComponents.value_row(stat.label(), stat.formatted_value())
		row_panel.name = "StatRow_%s" % String(stat.id())
		row_panel.custom_minimum_size.y = 36.0
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.set_meta(&"stat_id", stat.id())
		row_panel.set_meta(&"stat_group", stat.group())
		row_panel.set_meta(&"stat_accent_role", stat.accent_role())
		row_panel.tooltip_text = "%s: %s" % [stat.label(), stat.formatted_value()]
		var inset := row_panel.get_child(0) as MarginContainer
		var line := inset.get_child(0) as HBoxContainer
		var marker := SimpleIcon.new()
		marker.name = "StatIcon"
		marker.custom_minimum_size = Vector2(18.0, 18.0)
		marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		marker.configure(stat.icon_id(), _accent_color(stat.accent_role()))
		line.add_child(marker)
		line.move_child(marker, 0)
		var caption := line.get_child(1) as Label
		caption.name = "StatLabel"
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.custom_minimum_size.x = STAT_LABEL_MINIMUM_WIDTH
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var value := line.get_child(2) as Label
		value.name = "StatValue"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_stats_grid.add_child(row_panel)
		# Measure only after the row is attached so the label resolves the
		# actual Bio-Lumen font and size inherited from the overlay theme.
		value.custom_minimum_size.x = _measured_stat_value_width(value)
		_stat_rows.append(row_panel)
	_queue_responsive_layout()


func _apply_mode(mode: int) -> void:
	_mode = mode
	var menu_visible := mode == Mode.MENU
	_title_label.text = "Pause" if menu_visible else "Charakterwerte"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if menu_visible else HORIZONTAL_ALIGNMENT_LEFT
	_doctor_balance.visible = menu_visible
	_doctor_label.visible = menu_visible
	_menu_body.visible = menu_visible
	_stats_body.visible = not menu_visible
	_resume_button.visible = menu_visible
	_back_button.visible = not menu_visible
	_update_focus_trap()
	_queue_responsive_layout()


func _update_focus_trap() -> void:
	var visible_actions: Array[Button] = []
	if _mode == Mode.MENU:
		var menu_buttons: Array[Button] = [_settings_button, _stats_button, _intro_skip_button, _abort_button, _resume_button]
		for button in menu_buttons:
			if not button.disabled and button.visible:
				visible_actions.append(button)
	else:
		visible_actions.append(_back_button)
	for index in range(visible_actions.size()):
		var action := visible_actions[index]
		var previous := visible_actions[posmod(index - 1, visible_actions.size())]
		var following := visible_actions[(index + 1) % visible_actions.size()]
		action.focus_neighbor_left = action.get_path_to(previous)
		action.focus_neighbor_top = action.get_path_to(previous)
		action.focus_neighbor_right = action.get_path_to(following)
		action.focus_neighbor_bottom = action.get_path_to(following)


func _ensure_focus_visible(control: Control) -> void:
	if _body_scroll != null and control != null and _body_scroll.is_ancestor_of(control):
		_body_scroll.ensure_control_visible(control)


func _queue_responsive_layout() -> void:
	_update_responsive_layout.call_deferred()


func _update_responsive_layout() -> void:
	if _center == null or _sheet == null or _body_scroll == null:
		return
	var compact := size.x < 640.0 or size.y < 400.0
	var outer_margin := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if compact else AlveolusVisualTheme.SCREEN_MARGIN
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_safe_area.add_theme_constant_override(side, outer_margin)
	# Derive the responsive budget from the actual logical viewport. Reading the
	# CenterContainer here creates a circular minimum-size dependency: a wide
	# two-column child can temporarily enlarge the center and prevent the compact
	# breakpoint from ever being reached.
	var available := Vector2(
		maxf(0.0, size.x - outer_margin * 2.0),
		maxf(0.0, size.y - outer_margin * 2.0)
	)
	if available.x <= 0.0 or available.y <= 0.0:
		return
	_sync_doctor_balance()

	var maximum_width := MENU_MAXIMUM_WIDTH if _mode == Mode.MENU else STATS_MAXIMUM_WIDTH
	var sheet_width := minf(maximum_width, available.x)
	_sheet.custom_minimum_size.x = floorf(sheet_width)
	var sheet_padding := COMPACT_MODAL_PADDING if compact else MODAL_PADDING
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_sheet_margin.add_theme_constant_override(side, sheet_padding)
	var compact_menu := sheet_width < COMPACT_MENU_BREAKPOINT
	_menu_actions.columns = 2 if compact_menu else 3
	_set_compact_menu_layout(compact_menu)
	_stats_grid.columns = 1 if sheet_width < COMPACT_STATS_BREAKPOINT else 2
	_set_compact_stat_label_width(compact_menu)

	_body_scroll.custom_minimum_size.y = 0.0
	var active_body: Control = _menu_body if _mode == Mode.MENU else _stats_body
	var body_height := active_body.get_combined_minimum_size().y
	var active_footer := _resume_button if _mode == Mode.MENU else _back_button
	var chrome_height := (
		float(sheet_padding * 2)
		+ _pause_header.get_combined_minimum_size().y
		+ active_footer.get_combined_minimum_size().y
		+ float(AlveolusVisualTheme.CONTENT_GAP * 2)
	)
	var maximum_body_height := maxf(0.0, available.y - chrome_height)
	var visible_body_height := minf(body_height, maximum_body_height)
	_body_scroll.custom_minimum_size.y = ceilf(visible_body_height)
	var requires_scroll := body_height > visible_body_height + 1.0
	_body_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO if requires_scroll
		else ScrollContainer.SCROLL_MODE_DISABLED
	)
	var scrollbar_inset := ceili(_body_scroll.get_v_scroll_bar().get_combined_minimum_size().x) if requires_scroll else 0
	_scrollbar_inset.add_theme_constant_override("margin_right", scrollbar_inset)
	if not requires_scroll:
		_body_scroll.scroll_vertical = 0


func _sync_doctor_balance() -> void:
	if _doctor_balance == null or _doctor_label == null:
		return
	# Equal left and right side widths keep "Pause" geometrically centered even
	# though the Doctor metadata remains aligned at the right edge.
	_doctor_balance.custom_minimum_size.x = _doctor_label.get_combined_minimum_size().x


func _set_compact_menu_layout(compact: bool) -> void:
	if compact:
		if _abort_button.get_parent() != _menu_danger_row:
			_abort_button.reparent(_menu_danger_row)
			_update_focus_trap()
		_menu_danger_row.show()
		return
	if _abort_button.get_parent() != _menu_actions:
		_abort_button.reparent(_menu_actions)
		# Settings, stats and abort retain the established desktop order. The
		# optional intro action follows them when it is enabled.
		_menu_actions.move_child(_abort_button, 2)
		_update_focus_trap()
	_menu_danger_row.hide()


func _measured_stat_value_width(value: Label) -> float:
	var font := value.get_theme_font("font")
	var font_size := value.get_theme_font_size("font_size")
	var text_width := font.get_string_size(
		value.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x
	# The bounded value column preserves as much room as possible for the
	# caption while keeping full values readable. The row tooltip remains the
	# unabridged fallback for exceptionally long localized values.
	return clampf(ceilf(text_width + 8.0), 56.0, 120.0)


func _set_compact_stat_label_width(compact: bool) -> void:
	for row in _stat_rows:
		var caption := row.find_child("StatLabel", true, false) as Label
		var value := row.find_child("StatValue", true, false) as Label
		if caption == null:
			continue
		caption.custom_minimum_size.x = (
			maxf(COMPACT_STAT_LABEL_FLOOR, COMPACT_STAT_TEXT_MINIMUM_WIDTH - value.custom_minimum_size.x)
			if compact and value != null
			else STAT_LABEL_MINIMUM_WIDTH
		)


func _accent_color(role: StringName) -> Color:
	match role:
		&"teal":
			return AlveolusVisualTheme.TEAL
		&"turquoise":
			return AlveolusVisualTheme.TURQUOISE
		&"cobalt":
			return AlveolusVisualTheme.COBALT
		&"coral":
			return AlveolusVisualTheme.CORAL
	return AlveolusVisualTheme.GOLD
