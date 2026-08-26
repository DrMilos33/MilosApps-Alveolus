class_name PlainRunPrompt
extends Control

## Containerless, presenter-driven text prompt for gameplay overlays.
##
## The parent chooses this control's rect, so the same view can occupy a
## centered intro band or the area immediately below the life bar. Blocking
## prompts own pointer and keyboard focus until their left-click
## acknowledgement is consumed; non-blocking announcements remain completely
## input-transparent.

signal left_click_acknowledged

const MODE_NORMAL := &"normal"
const MODE_CORAL := &"coral"

const MAXIMUM_TEXT_WIDTH := 720.0
const RUN_HUD_BAND_TOP := 52.0
const RUN_HUD_BAND_BOTTOM := 120.0
const MESSAGE_FONT_SIZE := 24

var _semantic_mode := MODE_NORMAL
var _confirmation_required := false
var _blocking_requested := false
var _input_owner := false
var _awaiting_left_click := false
var _return_focus: WeakRef
var _content_band_top := -1.0
var _content_band_bottom := -1.0

var _safe_area: MarginContainer
var _center: CenterContainer
var _content_stack: VBoxContainer
var _message_label: Label
var _mouse_hint_label: Label


func _init() -> void:
	name = "PlainRunPrompt"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	set_process(false)
	set_physics_process(false)
	set_meta(&"alveolus_component", &"plain_run_prompt")
	set_meta(&"semantic_mode", MODE_NORMAL)
	set_meta(&"blocking_input", false)
	set_meta(&"input_owner", false)
	set_meta(&"confirmation_required", false)
	set_meta(&"awaiting_left_click", false)
	_build_content()
	resized.connect(_refresh_layout)


## Applies display-ready presenter copy without changing visibility. The mouse
## hint is shown only while this content explicitly requires a left click.
func set_content(
	message_text: String,
	semantic_mode: StringName = MODE_NORMAL,
	requires_left_click: bool = false,
	mouse_hint_text: String = ""
) -> bool:
	var normalized_message := message_text.strip_edges()
	var normalized_mode := semantic_mode if semantic_mode in [MODE_NORMAL, MODE_CORAL] else MODE_NORMAL
	var normalized_hint := mouse_hint_text.strip_edges()
	var changed := (
		_message_label.text != normalized_message
		or _semantic_mode != normalized_mode
		or _confirmation_required != requires_left_click
		or _mouse_hint_label.text != normalized_hint
	)
	_semantic_mode = normalized_mode
	_confirmation_required = requires_left_click
	_message_label.text = normalized_message
	_message_label.visible = not normalized_message.is_empty()
	_message_label.modulate = AlveolusVisualTheme.CORAL if _semantic_mode == MODE_CORAL else AlveolusVisualTheme.IVORY
	_mouse_hint_label.text = normalized_hint
	_mouse_hint_label.visible = _confirmation_required and not normalized_hint.is_empty()
	_awaiting_left_click = _confirmation_required and visible
	set_meta(&"semantic_mode", _semantic_mode)
	set_meta(&"confirmation_required", _confirmation_required)
	set_meta(&"awaiting_left_click", _awaiting_left_click)
	set_meta(&"alveolus_accessible_name", normalized_message)
	set_meta(&"alveolus_accessible_description", normalized_hint if _mouse_hint_label.visible else "")
	if visible:
		var should_own_input := _blocking_requested or _confirmation_required
		if should_own_input and not _input_owner:
			_capture_return_focus()
		_apply_input_ownership(should_own_input)
		if should_own_input:
			grab_initial_focus.call_deferred()
		else:
			_restore_return_focus()
	return changed


## Presents the current content. Confirmation always implies a blocking layer;
## ordinary short-lived announcements may stay input-transparent.
func show_prompt(blocking: bool = false, request_focus: bool = true) -> void:
	_blocking_requested = blocking
	var owns_input := _blocking_requested or _confirmation_required
	if owns_input and not _input_owner:
		_capture_return_focus()
	visible = true
	_awaiting_left_click = _confirmation_required
	_apply_input_ownership(owns_input)
	set_meta(&"awaiting_left_click", _awaiting_left_click)
	if owns_input and request_focus:
		grab_initial_focus.call_deferred()


## Constrains only the copy to a vertical viewport band while the transparent
## prompt itself continues to cover the complete viewport for safe input
## ownership. Passing a non-positive band restores normal centering.
func set_content_band(top_offset: float, bottom_offset: float) -> void:
	_content_band_top = top_offset
	_content_band_bottom = bottom_offset
	_refresh_layout()


## Applies the single product reading zone shared by every intro and boss
## prompt. The full-rect control still owns blocking input when required.
func use_run_hud_band() -> void:
	set_content_band(RUN_HUD_BAND_TOP, RUN_HUD_BAND_BOTTOM)


## Hides the view and safely returns focus to the control that preceded a
## blocking prompt. Callers can suppress restoration while changing routes.
func hide_prompt(restore_focus: bool = true) -> void:
	visible = false
	_blocking_requested = false
	_awaiting_left_click = false
	_apply_input_ownership(false)
	set_meta(&"awaiting_left_click", false)
	_restore_return_focus(restore_focus)


func _exit_tree() -> void:
	_blocking_requested = false
	_awaiting_left_click = false
	_apply_input_ownership(false)
	_restore_return_focus()


func _restore_return_focus(restore_focus: bool = true) -> void:
	var return_control: Control = null
	if _return_focus != null:
		return_control = _return_focus.get_ref() as Control
	_return_focus = null
	if (
		restore_focus
		and return_control != null
		and is_instance_valid(return_control)
		and return_control.is_inside_tree()
		and return_control.is_visible_in_tree()
		and return_control.focus_mode != Control.FOCUS_NONE
	):
		return_control.grab_focus.call_deferred()


func _capture_return_focus() -> void:
	if not is_inside_tree():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and focus_owner != self and not is_ancestor_of(focus_owner):
		_return_focus = weakref(focus_owner)


## Awaitable presenter-facing boundary. It resumes only for the currently
## armed confirmation and never maps keyboard or gamepad accept to a click.
func wait_for_left_click() -> void:
	if not _awaiting_left_click:
		return
	await left_click_acknowledged


## Signal access for presenters that prefer `await prompt.left_click_signal()`.
func left_click_signal() -> Signal:
	return left_click_acknowledged


## Blocking prompts consume cancel at the top layer without advancing. Intro
## continuation remains left-click-only.
func handle_ui_cancel(is_top_layer: bool = true) -> bool:
	return is_top_layer and visible and _input_owner


func grab_initial_focus() -> bool:
	if not visible or not _input_owner or not is_inside_tree():
		return false
	grab_focus()
	return true


func default_focus_control() -> Control:
	return self if _input_owner else null


func message_label() -> Label:
	return _message_label


func mouse_hint_label() -> Label:
	return _mouse_hint_label


func content_stack() -> VBoxContainer:
	return _content_stack


func semantic_mode() -> StringName:
	return _semantic_mode


func confirmation_required() -> bool:
	return _confirmation_required


func owns_input() -> bool:
	return _input_owner


func is_awaiting_left_click() -> bool:
	return _awaiting_left_click


func _gui_input(event: InputEvent) -> void:
	if not _input_owner:
		return
	# A blocking prompt owns all GUI input so hidden HUD actions cannot react.
	# Only a fresh left-button press advances confirmation content.
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		accept_event()
		if (
			mouse_event.button_index == MOUSE_BUTTON_LEFT
			and mouse_event.pressed
			and _awaiting_left_click
		):
			_awaiting_left_click = false
			set_meta(&"awaiting_left_click", false)
			left_click_acknowledged.emit()
		return
	if event is InputEventKey or event is InputEventJoypadButton:
		accept_event()


func _build_content() -> void:
	_safe_area = MarginContainer.new()
	_safe_area.name = "PromptSafeArea"
	_safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe_area)

	_center = CenterContainer.new()
	_center.name = "PromptCenter"
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe_area.add_child(_center)

	_content_stack = VBoxContainer.new()
	_content_stack.name = "PromptCopy"
	_content_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_content_stack.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	_content_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_stack.set_meta(&"alveolus_component", &"plain_run_prompt_copy")
	_center.add_child(_content_stack)

	_message_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_HUD_VALUE_LABEL)
	_message_label.name = "PromptMessage"
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.modulate = AlveolusVisualTheme.IVORY
	_message_label.add_theme_font_size_override("font_size", MESSAGE_FONT_SIZE)
	_content_stack.add_child(_message_label)

	_mouse_hint_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL)
	_mouse_hint_label.name = "MouseHint"
	_mouse_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mouse_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mouse_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mouse_hint_label.visible = false
	_content_stack.add_child(_mouse_hint_label)
	_refresh_layout.call_deferred()


func _refresh_layout() -> void:
	if _safe_area == null or _content_stack == null:
		return
	var compact := size.x > 1.0 and size.x < 600.0
	var margin := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if compact else AlveolusVisualTheme.SCREEN_MARGIN
	_safe_area.add_theme_constant_override("margin_left", margin)
	_safe_area.add_theme_constant_override("margin_right", margin)
	var uses_content_band := (
		_content_band_top >= 0.0
		and _content_band_bottom > _content_band_top
		and size.y > _content_band_bottom
	)
	_safe_area.add_theme_constant_override(
		"margin_top",
		roundi(_content_band_top) if uses_content_band else margin
	)
	_safe_area.add_theme_constant_override(
		"margin_bottom",
		roundi(size.y - _content_band_bottom) if uses_content_band else margin
	)
	var available_width := maxf(0.0, size.x - float(margin * 2))
	_content_stack.custom_minimum_size.x = minf(MAXIMUM_TEXT_WIDTH, available_width)


func _apply_input_ownership(owns_input_value: bool) -> void:
	_input_owner = owns_input_value
	mouse_filter = Control.MOUSE_FILTER_STOP if _input_owner else Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL if _input_owner else Control.FOCUS_NONE
	set_meta(&"blocking_input", _input_owner)
	set_meta(&"input_owner", _input_owner)
