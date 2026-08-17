class_name StoryScreen
extends Control

## Bio-Lumen story/prologue screen.
##
## This module renders only StoryScreenViewModel data and emits user intents.
## It knows nothing about saves, progression, flow state or content catalogs;
## GameHUD remains the compatibility facade that owns those decisions.

signal next_requested(step_index: int)
signal skip_requested
signal back_requested(step_index: int)

const MAXIMUM_SHEET_WIDTH := 620.0
const STACKED_ACTION_BREAKPOINT := 540.0

var _view_model: StoryScreenViewModel
var _step_index := -1
var _applied_revision := -1
var _applied_content_hash := ""

var _page_canvas: PanelContainer
var _scroll: ScrollContainer
var _center: CenterContainer
var _sheet: PanelContainer
var _sheet_stack: VBoxContainer
var _progress_label: Label
var _title_label: Label
var _body_label: Label
var _action_grid: GridContainer
var _back_button: Button
var _skip_button: Button
var _next_button: Button


func _init() -> void:
	name = "StoryScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	set_process(false)
	set_physics_process(false)
	_build()
	resized.connect(_queue_responsive_layout)


## Applies immutable presentation data. Repeated or stale revisions do not
## rebuild the screen; a changed content hash still refreshes a reused revision.
func apply_view_model(view_model: StoryScreenViewModel, step_index: int = 0) -> bool:
	if view_model == null or view_model.is_empty():
		return false
	if _applied_revision >= 0 and view_model.revision() < _applied_revision:
		return false

	var safe_index := clampi(step_index, 0, view_model.step_count() - 1)
	var same_content := (
		view_model.revision() == _applied_revision
		and view_model.content_hash() == _applied_content_hash
	)
	if same_content and safe_index == _step_index:
		return false

	_view_model = view_model
	_applied_revision = view_model.revision()
	_applied_content_hash = view_model.content_hash()
	_step_index = safe_index
	_render_step()
	return true


## Convenience entry point for the future GameHUD adapter.
func present(view_model: StoryScreenViewModel, step_index: int = 0, request_focus: bool = true) -> bool:
	var changed := apply_view_model(view_model, step_index)
	show()
	if request_focus:
		grab_initial_focus.call_deferred()
	return changed


func dismiss() -> void:
	hide()


func set_step_index(step_index: int) -> bool:
	if _view_model == null or step_index < 0 or step_index >= _view_model.step_count():
		return false
	if step_index == _step_index:
		return false
	_step_index = step_index
	_render_step()
	return true


func grab_initial_focus() -> bool:
	if not is_inside_tree() or not is_visible_in_tree() or _next_button == null or not _next_button.is_visible_in_tree():
		return false
	_next_button.grab_focus()
	_ensure_focus_visible.call_deferred(_next_button)
	return true


func current_step_index() -> int:
	return _step_index


func applied_revision() -> int:
	return _applied_revision


func applied_content_hash() -> String:
	return _applied_content_hash


func focus_anchor() -> Control:
	return _next_button


func page_canvas() -> PanelContainer:
	return _page_canvas


func story_sheet() -> PanelContainer:
	return _sheet


func focus_scroll() -> ScrollContainer:
	return _scroll


func progress_label() -> Label:
	return _progress_label


func title_label() -> Label:
	return _title_label


func body_label() -> Label:
	return _body_label


func back_action() -> Button:
	return _back_button


func skip_action() -> Button:
	return _skip_button


func next_action() -> Button:
	return _next_button


func _build() -> void:
	_scroll = ScrollContainer.new()
	_scroll.name = "StoryScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	_scroll.resized.connect(_queue_responsive_layout)

	_center = CenterContainer.new()
	_center.name = "StoryCenter"
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_center)

	var body := VBoxContainer.new()
	body.name = "StoryBody"
	body.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_progress_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
	_progress_label.name = "Progress"
	body.add_child(_progress_label)

	_title_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_TITLE_LABEL)
	_title_label.name = "Title"
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_title_label)

	_body_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_BODY_LABEL)
	_body_label.name = "Body"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_body_label)

	_action_grid = GridContainer.new()
	_action_grid.name = "Actions"
	_action_grid.columns = 3
	_action_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_action_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	body.add_child(_action_grid)

	_back_button = AlveolusUIComponents.action_button("Zurück", AlveolusUIComponents.ACTION_QUIET)
	_back_button.name = "Back"
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_button.pressed.connect(_on_back_pressed)
	_action_grid.add_child(_back_button)

	_skip_button = AlveolusUIComponents.action_button("Überspringen", AlveolusUIComponents.ACTION_QUIET)
	_skip_button.name = "Skip"
	_skip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skip_button.pressed.connect(func() -> void: skip_requested.emit())
	_action_grid.add_child(_skip_button)

	_next_button = AlveolusUIComponents.action_button("Weiter", AlveolusUIComponents.ACTION_PRIMARY)
	_next_button.name = "Next"
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_button.pressed.connect(func() -> void: next_requested.emit(_step_index))
	_action_grid.add_child(_next_button)

	var actions: Array[Button] = [_back_button, _skip_button, _next_button]
	for action in actions:
		action.focus_entered.connect(_ensure_focus_visible.bind(action))

	var sheet_parts := AlveolusUIComponents.modal_sheet("", body)
	_sheet = sheet_parts["panel"] as PanelContainer
	_sheet.name = "StorySheet"
	_sheet_stack = sheet_parts["content"] as VBoxContainer
	_center.add_child(_sheet)

	var shell_parts := AlveolusUIComponents.page_shell(null, _scroll)
	_page_canvas = shell_parts["shell"] as PanelContainer
	_page_canvas.name = "PageCanvas"
	add_child(_page_canvas)
	_queue_responsive_layout()


func _render_step() -> void:
	if _view_model == null:
		return
	var step := _view_model.step_at(_step_index)
	if step == null:
		return
	_progress_label.text = "Schritt %d von %d" % [_step_index + 1, _view_model.step_count()]
	_title_label.text = step.title()
	_body_label.text = step.body()
	_next_button.text = step.next_label()
	_next_button.set_meta(&"alveolus_accessible_name", step.next_label())
	_skip_button.text = _view_model.skip_label()
	_skip_button.set_meta(&"alveolus_accessible_name", _view_model.skip_label())
	var hidden_action_had_focus := (
		(_skip_button.has_focus() and not _view_model.allow_skip())
		or (_back_button.has_focus() and (not _view_model.allow_back() or _step_index <= 0))
	)
	_skip_button.visible = _view_model.allow_skip()
	_back_button.visible = _view_model.allow_back() and _step_index > 0
	_update_focus_neighbours()
	_queue_responsive_layout()
	if hidden_action_had_focus:
		grab_initial_focus.call_deferred()


func _update_focus_neighbours() -> void:
	var visible_actions: Array[Button] = []
	var all_actions: Array[Button] = [_back_button, _skip_button, _next_button]
	for action in all_actions:
		if action.visible:
			visible_actions.append(action)
	for index in range(visible_actions.size()):
		var action := visible_actions[index]
		var previous := visible_actions[posmod(index - 1, visible_actions.size())]
		var following := visible_actions[(index + 1) % visible_actions.size()]
		action.focus_neighbor_left = action.get_path_to(previous)
		action.focus_neighbor_top = action.get_path_to(previous)
		action.focus_neighbor_right = action.get_path_to(following)
		action.focus_neighbor_bottom = action.get_path_to(following)


func _on_back_pressed() -> void:
	back_requested.emit(_step_index)


func _ensure_focus_visible(control: Control) -> void:
	if _scroll != null and control != null and control.is_visible_in_tree():
		_scroll.ensure_control_visible(control)


func _queue_responsive_layout() -> void:
	_update_responsive_layout.call_deferred()


func _update_responsive_layout() -> void:
	if _scroll == null or _center == null or _sheet == null or _action_grid == null:
		return
	# Derive the logical viewport from this screen, not from the scroll child.
	# A previous smaller UI scale can leave the scroll content with a large
	# minimum size for one layout frame; feeding that size back into the center
	# would permanently keep the prologue wider than the new viewport.
	var safe_margin := float(AlveolusVisualTheme.SCREEN_MARGIN)
	var available := Vector2(
		maxf(0.0, size.x - safe_margin * 2.0),
		maxf(0.0, size.y - safe_margin * 2.0)
	)
	if available.x <= 0.0 or available.y <= 0.0:
		return
	_center.custom_minimum_size = available
	# Reserve the themed scrollbar's footprint even before AUTO makes it visible;
	# otherwise the compact 200-percent layout can cover the card's right edge.
	var scrollbar_width := maxf(
		float(AlveolusVisualTheme.CONTROL_GAP),
		_scroll.get_v_scroll_bar().get_combined_minimum_size().x
	)
	var sheet_width := minf(MAXIMUM_SHEET_WIDTH, maxf(0.0, available.x - scrollbar_width))
	_sheet.custom_minimum_size.x = floorf(sheet_width)
	var visible_action_count := int(_back_button.visible) + int(_skip_button.visible) + int(_next_button.visible)
	_action_grid.columns = 1 if sheet_width < STACKED_ACTION_BREAKPOINT else maxi(1, visible_action_count)
