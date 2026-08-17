class_name ConfirmationOverlay
extends Control

## Shared Bio-Lumen confirmation layer for abort, restart and intro skip.
## Routing owns the modal stack and invokes handle_ui_cancel only for its top
## entry. The screen itself emits presentation intents and never mutates state.

signal confirm
signal cancel

const COMPACT_WIDTH := 600.0
const MODAL_MAXIMUM_WIDTH := 560.0

var _view_model: ConfirmationOverlayViewModel
var _applied_revision := -1
var _applied_content_hash := ""
var _compact_layout := false

var _safe_area: MarginContainer
var _scroll: ScrollContainer
var _center: CenterContainer
var _modal_host: VBoxContainer
var _modal: PanelContainer
var _title_label: Label
var _body_label: Label
var _action_grid: GridContainer
var _confirm_button: Button
var _cancel_button: Button


func _init() -> void:
	name = "ConfirmationOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	set_process(false)
	set_physics_process(false)
	_build_stage()
	resized.connect(_refresh_responsive_layout)


func apply_view_model(view_model: ConfirmationOverlayViewModel) -> bool:
	if view_model == null or view_model.revision() < _applied_revision:
		return false
	var content_changed := view_model.content_hash() != _applied_content_hash
	var revision_changed := view_model.revision() != _applied_revision
	if not content_changed and not revision_changed:
		return false
	_view_model = view_model.duplicate_immutable()
	_applied_revision = view_model.revision()
	_applied_content_hash = view_model.content_hash()
	if content_changed or _modal == null:
		_rebuild_modal()
	return content_changed


func apply(view_model: ConfirmationOverlayViewModel) -> bool:
	return apply_view_model(view_model)


func present(view_model: ConfirmationOverlayViewModel, request_focus: bool = true) -> bool:
	var changed := apply_view_model(view_model)
	show()
	if request_focus:
		grab_initial_focus.call_deferred()
	return changed


func dismiss() -> void:
	hide()


## The router passes true only for the uppermost modal. A cancel policy of
## "cancel" emits the safe intent; "consume" acknowledges without closing.
func handle_ui_cancel(is_top_layer: bool = true) -> bool:
	if not is_top_layer or _view_model == null or not is_inside_tree() or not is_visible_in_tree():
		return false
	if _view_model.cancel_policy() == ConfirmationOverlayViewModel.CANCEL_POLICY_CANCEL:
		cancel.emit()
	return true


func grab_initial_focus() -> bool:
	if _cancel_button == null or not is_inside_tree() or not is_visible_in_tree() or not _cancel_button.is_visible_in_tree():
		return false
	_cancel_button.grab_focus()
	_ensure_focus_visible.call_deferred(_cancel_button)
	return true


func applied_revision() -> int:
	return _applied_revision


func applied_content_hash() -> String:
	return _applied_content_hash


func view_model() -> ConfirmationOverlayViewModel:
	return _view_model.duplicate_immutable() if _view_model != null else null


func cancel_policy() -> StringName:
	return _view_model.cancel_policy() if _view_model != null else &""


func get_cancel_policy() -> StringName:
	return cancel_policy()


func default_focus_control() -> Control:
	return _cancel_button


func get_default_focus_control() -> Control:
	return default_focus_control()


func modal_sheet() -> PanelContainer:
	return _modal


func body_scroll() -> ScrollContainer:
	return _scroll


func action_grid() -> GridContainer:
	return _action_grid


func confirm_action() -> Button:
	return _confirm_button


func cancel_action() -> Button:
	return _cancel_button


func is_compact_layout() -> bool:
	return _compact_layout


func _build_stage() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "ModalBackdrop"
	backdrop.color = Color(AlveolusVisualTheme.PETROL_DEEP, 0.86)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.set_meta(&"alveolus_component", &"modal_backdrop")
	add_child(backdrop)

	_safe_area = MarginContainer.new()
	_safe_area.name = "SafeArea"
	_safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(_safe_area)

	_scroll = ScrollContainer.new()
	_scroll.name = "ConfirmationScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	_scroll.resized.connect(_refresh_responsive_layout)
	_safe_area.add_child(_scroll)

	_center = CenterContainer.new()
	_center.name = "ConfirmationCenter"
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_center)

	_modal_host = VBoxContainer.new()
	_modal_host.name = "ModalHost"
	_modal_host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_modal_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_center.add_child(_modal_host)


func _rebuild_modal() -> void:
	var accent := AlveolusVisualTheme.CORAL if _view_model.is_danger() else AlveolusVisualTheme.TEAL
	if _modal == null:
		_build_modal_controls(accent)
	_sync_modal_content(accent)
	_refresh_responsive_layout.call_deferred()


func _build_modal_controls(accent: Color) -> void:
	_body_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_MUTED_LABEL)
	_body_label.name = "ConfirmationText"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_action_grid = GridContainer.new()
	_action_grid.name = "ConfirmationActions"
	_action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_action_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)

	_cancel_button = AlveolusUIComponents.action_button(
		_view_model.cancel_label(),
		AlveolusUIComponents.ACTION_SECONDARY,
		&"back",
		AlveolusVisualTheme.COBALT
	)
	_cancel_button.name = "CancelButton"
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_button.pressed.connect(func() -> void: cancel.emit())
	_action_grid.add_child(_cancel_button)

	var confirm_role := AlveolusUIComponents.ACTION_DANGER if _view_model.is_danger() else AlveolusUIComponents.ACTION_PRIMARY
	_confirm_button = AlveolusUIComponents.action_button(
		_view_model.confirm_label(),
		confirm_role,
		&"remove" if _view_model.is_danger() else &"check",
		accent
	)
	_confirm_button.name = "ConfirmButton"
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_button.pressed.connect(func() -> void: confirm.emit())
	_action_grid.add_child(_confirm_button)
	_link_focus_cycle()

	var modal_actions: Array[Control] = [_action_grid]
	# Always create stable title/body controls. Hiding an empty label removes it
	# from layout without freeing a live layout subtree during a content swap.
	var sheet := AlveolusUIComponents.modal_sheet(" ", _body_label, modal_actions, 20, accent)
	_modal = sheet["panel"] as PanelContainer
	_modal.name = "ConfirmationModal"
	_modal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_modal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_modal.custom_minimum_size.y = 0.0
	var content := sheet["content"] as VBoxContainer
	_title_label = content.get_child(0) as Label
	_title_label.name = "ConfirmationTitle"
	_modal_host.add_child(_modal)


func _sync_modal_content(accent: Color) -> void:
	_title_label.text = _view_model.title()
	_title_label.visible = not _title_label.text.is_empty()
	_body_label.text = _view_model.short_text()
	_body_label.visible = not _body_label.text.is_empty()
	_set_action_caption(_cancel_button, _view_model.cancel_label())
	_set_action_caption(_confirm_button, _view_model.confirm_label())

	var confirm_role := AlveolusUIComponents.ACTION_DANGER if _view_model.is_danger() else AlveolusUIComponents.ACTION_PRIMARY
	var confirm_icon := &"remove" if _view_model.is_danger() else &"check"
	if _confirm_button is IconTextButton:
		var icon_button := _confirm_button as IconTextButton
		icon_button.accent = accent
		icon_button.icon_view.configure(confirm_icon, accent, icon_button.icon_view.framed)
	AlveolusUIComponents.apply_action_role(_confirm_button, confirm_role, accent)
	AlveolusUIComponents.apply_surface_role(_modal, AlveolusVisualTheme.SurfaceRole.MODAL_SHEET, accent)
	_modal.set_meta(&"confirmation_danger", _view_model.is_danger())
	_modal.set_meta(&"cancel_policy", _view_model.cancel_policy())


func _set_action_caption(button: Button, caption_text: String) -> void:
	if button is IconTextButton:
		(button as IconTextButton).set_caption(caption_text)
	else:
		button.text = caption_text
	button.set_meta(&"alveolus_accessible_name", caption_text)


func _link_focus_cycle() -> void:
	_cancel_button.focus_previous = _cancel_button.get_path_to(_confirm_button)
	_cancel_button.focus_next = _cancel_button.get_path_to(_confirm_button)
	_cancel_button.focus_neighbor_left = _cancel_button.get_path_to(_confirm_button)
	_cancel_button.focus_neighbor_top = _cancel_button.get_path_to(_confirm_button)
	_cancel_button.focus_neighbor_right = _cancel_button.get_path_to(_confirm_button)
	_cancel_button.focus_neighbor_bottom = _cancel_button.get_path_to(_confirm_button)
	_confirm_button.focus_previous = _confirm_button.get_path_to(_cancel_button)
	_confirm_button.focus_next = _confirm_button.get_path_to(_cancel_button)
	_confirm_button.focus_neighbor_left = _confirm_button.get_path_to(_cancel_button)
	_confirm_button.focus_neighbor_top = _confirm_button.get_path_to(_cancel_button)
	_confirm_button.focus_neighbor_right = _confirm_button.get_path_to(_cancel_button)
	_confirm_button.focus_neighbor_bottom = _confirm_button.get_path_to(_cancel_button)


func _ensure_focus_visible(control: Control) -> void:
	if control != null and control.is_visible_in_tree():
		_scroll.ensure_control_visible(control)


func _refresh_responsive_layout() -> void:
	if _safe_area == null:
		return
	var logical_width := size.x
	if logical_width <= 1.0 and get_viewport() != null:
		logical_width = get_viewport().get_visible_rect().size.x
	_compact_layout = logical_width < COMPACT_WIDTH
	var margin := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if _compact_layout else AlveolusVisualTheme.SCREEN_MARGIN
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_safe_area.add_theme_constant_override(side, margin)
	# A ScrollContainer owns its horizontal extent. Mirroring its live width back
	# into the child creates a feedback loop as soon as the vertical scrollbar
	# appears in compact layouts. Only the vertical centering floor is required.
	_center.custom_minimum_size.y = _scroll.size.y
	if _modal != null:
		var available_width := maxf(0.0, logical_width - float(margin * 2))
		_modal.custom_minimum_size.x = minf(MODAL_MAXIMUM_WIDTH, available_width)
		_modal.custom_minimum_size.y = 0.0
	if _action_grid != null:
		# A 480 logical-pixel viewport still has ample room for two 44px actions.
		# Keeping them side by side avoids a marginal full-height scrollbar in
		# short confirmations such as "Einführung überspringen?".
		var action_width := maxf(0.0, logical_width - float(margin * 2) - 40.0)
		_action_grid.columns = 2 if action_width >= 360.0 else 1
