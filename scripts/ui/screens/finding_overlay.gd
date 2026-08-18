class_name FindingOverlay
extends Control

## Bio-Lumen finding modal. It renders immutable presentation data, exposes
## shared context providers and emits typed intents without touching gameplay.

signal reaction_selected(id: StringName)
signal swap_toggled(enabled: bool)
signal outgoing_selected(id: StringName)
signal confirm(reaction_id: StringName, incoming_id: StringName, outgoing_id: StringName)
signal cancel

const FindingOverlayViewModelType := preload("res://scripts/ui/view_models/finding_overlay_view_model.gd")
const MODAL_MAXIMUM_WIDTH := 900.0
const COMPACT_WIDTH := 760.0
const COMPACT_HEIGHT := 500.0
const MODAL_PADDING := 20

var _view_model: FindingOverlayViewModelType
var _has_applied_model := false
var _applied_revision := -1
var _applied_content_hash := ""
var _applied_structure_hash := ""
var _compact_layout := false
var _layout_settle_pending := false

var _pending_reaction_id: StringName = &""
var _pending_swap_enabled := false
var _pending_outgoing_id: StringName = &""

var _safe_area: MarginContainer
var _center: CenterContainer
var _modal_host: VBoxContainer
var _modal: PanelContainer
var _title_label: Label
var _body_scroll: ScrollContainer
var _scrollbar_inset: MarginContainer
var _body_stack: VBoxContainer
var _copy_grid: GridContainer
var _effect_label: Label
var _reaction_grid: GridContainer
var _reaction_group: ButtonGroup
var _reaction_buttons: Dictionary = {}
var _reaction_order: Array[StringName] = []
var _reserve_panel: PanelContainer
var _swap_toggle: CheckButton
var _outgoing_option: OptionButton
var _outgoing_ids: Array[StringName] = []
var _validation_label: Label
var _action_grid: GridContainer
var _confirm_button: Button
var _info_sources: Dictionary = {}


func _init() -> void:
	name = "FindingOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	set_process(false)
	set_physics_process(false)
	_build_stage()
	resized.connect(_queue_responsive_layout)


func apply_view_model(view_model: FindingOverlayViewModelType) -> bool:
	if view_model == null:
		return false
	var next_revision := view_model.revision()
	if _has_applied_model and next_revision <= _applied_revision:
		return false
	if _has_applied_model and view_model.content_hash() == _applied_content_hash:
		_view_model = view_model.duplicate_immutable()
		_applied_revision = next_revision
		return false

	var return_focus_id := _focused_stable_id()
	var previous_scroll := _body_scroll.scroll_vertical if _body_scroll != null else 0
	var structure_changed := not _has_applied_model or view_model.structure_hash() != _applied_structure_hash
	_view_model = view_model.duplicate_immutable()
	_applied_revision = next_revision
	_applied_content_hash = view_model.content_hash()
	_applied_structure_hash = view_model.structure_hash()
	_has_applied_model = true
	_pending_reaction_id = _view_model.selected_reaction_id()
	var reserve := _view_model.reserve_swap()
	_pending_swap_enabled = reserve.swap_enabled()
	_pending_outgoing_id = reserve.selected_outgoing_id()
	if structure_changed:
		_rebuild_modal()
	else:
		_apply_dynamic_state()
	if _body_scroll != null:
		_body_scroll.set_deferred(&"scroll_vertical", previous_scroll)
	if return_focus_id != &"":
		_restore_focus.call_deferred(return_focus_id)
	return true


func apply(view_model: FindingOverlayViewModelType) -> bool:
	return apply_view_model(view_model)


func present(view_model: FindingOverlayViewModelType, request_focus: bool = true) -> bool:
	var changed := apply_view_model(view_model)
	show()
	if request_focus:
		grab_initial_focus.call_deferred()
	return changed


func dismiss() -> void:
	hide()


func handle_ui_cancel(is_top_layer: bool = true) -> bool:
	if not is_top_layer or not is_inside_tree() or not is_visible_in_tree():
		return false
	cancel.emit()
	return true


func grab_initial_focus() -> bool:
	var target := default_focus_control()
	if target == null or not is_inside_tree() or not is_visible_in_tree() or not target.is_visible_in_tree():
		return false
	target.grab_focus()
	_ensure_focus_visible.call_deferred(target)
	return true


func default_focus_control() -> Control:
	var selected := reaction_action(_pending_reaction_id)
	if selected != null and not selected.disabled:
		return selected
	for reaction_id in _reaction_order:
		var button := _reaction_buttons.get(reaction_id) as Button
		if button != null and not button.disabled:
			return button
	return _confirm_button if _confirm_button != null and not _confirm_button.disabled else null


func get_default_focus_control() -> Control:
	return default_focus_control()


func applied_revision() -> int:
	return _applied_revision


func applied_content_hash() -> String:
	return _applied_content_hash


func applied_structure_hash() -> String:
	return _applied_structure_hash


func modal_sheet() -> PanelContainer:
	return _modal


func body_scroll() -> ScrollContainer:
	return _body_scroll


func copy_grid() -> GridContainer:
	return _copy_grid


func effect_label() -> Label:
	return _effect_label


func reaction_grid() -> GridContainer:
	return _reaction_grid


func action_grid() -> GridContainer:
	return _action_grid


func reaction_action(id: StringName) -> Button:
	return _reaction_buttons.get(id) as Button


func reserve_panel() -> PanelContainer:
	return _reserve_panel


func swap_action() -> CheckButton:
	return _swap_toggle


func outgoing_action() -> OptionButton:
	return _outgoing_option


func validation_label() -> Label:
	return _validation_label


func confirm_action() -> Button:
	return _confirm_button


func cancel_action() -> Button:
	return null


func selected_reaction_id() -> StringName:
	return _pending_reaction_id


func selected_outgoing_id() -> StringName:
	return _pending_outgoing_id


func is_swap_enabled() -> bool:
	return _pending_swap_enabled


func is_compact_layout() -> bool:
	return _compact_layout


## Records are directly consumable by ContextDetailController.register_source.
## Hover is the only automatic mode; focus alone remains silent.
func context_detail_registrations() -> Array[Dictionary]:
	_prune_info_sources()
	var result: Array[Dictionary] = []
	for entry_value in _info_sources.values():
		var entry := entry_value as Dictionary
		var source_ref := entry.get("source") as WeakRef
		var source: Control = source_ref.get_ref() as Control if source_ref != null else null
		if source == null or not is_instance_valid(source):
			continue
		result.append({
			"source": source,
			"provider": entry.get("provider", Callable()),
			"hover_enabled": true,
		})
	return result


func tooltip_provider_for(source: Control) -> Callable:
	return _info_provider_for(source)


func ui_info_provider_for(source: Control) -> Callable:
	return _info_provider_for(source)


func info_payload_for(source: Control) -> Dictionary:
	var provider := _info_provider_for(source)
	if not provider.is_valid():
		return {}
	var payload: Variant = provider.call()
	return (payload as Dictionary).duplicate(true) if payload is Dictionary else {}


func registered_info_source_count() -> int:
	_prune_info_sources()
	return _info_sources.size()


func _build_stage() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "ModalBackdrop"
	backdrop.color = Color(AlveolusVisualTheme.PETROL_DEEP, 0.88)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.set_meta(&"alveolus_component", &"modal_backdrop")
	add_child(backdrop)

	_safe_area = MarginContainer.new()
	_safe_area.name = "SafeArea"
	_safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(_safe_area)

	_center = CenterContainer.new()
	_center.name = "FindingCenter"
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center.resized.connect(_queue_responsive_layout)
	_safe_area.add_child(_center)

	_modal_host = VBoxContainer.new()
	_modal_host.name = "ModalHost"
	_modal_host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_modal_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_center.add_child(_modal_host)


func _rebuild_modal() -> void:
	_info_sources.clear()
	_reaction_buttons.clear()
	_reaction_order.clear()
	_outgoing_ids.clear()
	for child in _modal_host.get_children():
		_modal_host.remove_child(child)
		child.queue_free()
	_reset_control_references()

	_body_scroll = ScrollContainer.new()
	_body_scroll.name = "FindingBodyScroll"
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.follow_focus = true
	_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.resized.connect(_queue_responsive_layout)

	_scrollbar_inset = MarginContainer.new()
	_scrollbar_inset.name = "ScrollbarSafeInset"
	_scrollbar_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.add_child(_scrollbar_inset)

	_body_stack = VBoxContainer.new()
	_body_stack.name = "FindingContent"
	_body_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_stack.add_theme_constant_override("separation", AlveolusVisualTheme.CONTENT_GAP)
	_scrollbar_inset.add_child(_body_stack)

	_build_effect_line()
	_build_reactions()
	_build_reserve_swap()
	_build_validation()
	_build_actions()

	var modal_actions: Array[Control] = [_action_grid]
	var sheet_parts := AlveolusUIComponents.modal_sheet(
		_view_model.display_title(),
		_body_scroll,
		modal_actions,
		MODAL_PADDING,
		AlveolusVisualTheme.GOLD
	)
	_modal = sheet_parts["panel"] as PanelContainer
	_modal.name = "FindingModal"
	_modal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_modal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_modal.custom_minimum_size.y = 0.0
	_modal.set_meta(&"finding_id", _view_model.finding_id())
	var sheet_stack := sheet_parts["content"] as VBoxContainer
	_title_label = sheet_stack.get_child(0) as Label if not _view_model.display_title().is_empty() else null
	if _title_label != null:
		_title_label.name = "FindingTitle"
	_modal_host.add_child(_modal)
	_apply_dynamic_state()
	_queue_responsive_layout()


func _reset_control_references() -> void:
	_modal = null
	_title_label = null
	_body_scroll = null
	_scrollbar_inset = null
	_body_stack = null
	_copy_grid = null
	_effect_label = null
	_reaction_grid = null
	_reaction_group = null
	_reserve_panel = null
	_swap_toggle = null
	_outgoing_option = null
	_validation_label = null
	_action_grid = null
	_confirm_button = null


func _build_effect_line() -> void:
	var effect_text := _view_model.mechanical_effect_text()
	if effect_text.is_empty():
		return
	_copy_grid = GridContainer.new()
	_copy_grid.name = "MechanicalEffectLine"
	_copy_grid.columns = 1
	_copy_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy_grid.set_meta(&"alveolus_component", &"finding_effect_line")
	_effect_label = AlveolusUIComponents.label(effect_text, AlveolusVisualTheme.TYPE_VALUE_LABEL)
	_effect_label.name = "MechanicalEffect"
	_effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_effect_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_effect_label.modulate = AlveolusVisualTheme.GOLD
	_effect_label.set_meta(&"alveolus_accessible_name", "Effekt: %s" % effect_text)
	_copy_grid.add_child(_effect_label)
	_body_stack.add_child(_copy_grid)


func _build_reactions() -> void:
	var reactions := _view_model.reactions()
	if reactions.is_empty():
		return
	_reaction_grid = GridContainer.new()
	_reaction_grid.name = "ReactionChoices"
	_reaction_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reaction_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_reaction_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_reaction_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)
	_body_stack.add_child(_reaction_grid)
	_reaction_group = ButtonGroup.new()
	for reaction in reactions:
		var selected := reaction.id() == _pending_reaction_id
		var button := AlveolusUIComponents.choice_row(reaction.title(), "", "", selected, not reaction.interactive())
		button.name = "Reaction_%s" % String(reaction.id())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		button.toggle_mode = true
		button.button_group = _reaction_group
		button.set_pressed_no_signal(selected)
		button.tooltip_text = ""
		button.set_meta(&"stable_focus_id", StringName("reaction.%s" % String(reaction.id())))
		button.set_meta(&"reaction_id", reaction.id())
		button.set_meta(&"compact_reaction", true)
		var accessible_name := reaction.title()
		if not reaction.accessible_summary().is_empty():
			accessible_name += ", %s" % reaction.accessible_summary()
		button.set_meta(&"alveolus_accessible_name", accessible_name)
		button.pressed.connect(_on_reaction_pressed.bind(reaction.id()))
		_reaction_grid.add_child(button)
		_reaction_buttons[reaction.id()] = button
		_reaction_order.append(reaction.id())
		_register_info_source(button, reaction.info())


func _build_reserve_swap() -> void:
	var reserve := _view_model.reserve_swap()
	if not reserve.is_visible():
		return
	_reserve_panel = AlveolusUIComponents.surface(
		AlveolusVisualTheme.SurfaceRole.DOCUMENT_INSET,
		AlveolusVisualTheme.COBALT
	)
	_reserve_panel.name = "ReserveSwap"
	_reserve_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reserve_panel.set_meta(&"dormant_compatible", true)
	_body_stack.add_child(_reserve_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	_reserve_panel.add_child(AlveolusUIComponents.margin(stack, 10))
	var reserve_title := "Reserve: %s" % reserve.incoming_title() if not reserve.incoming_title().is_empty() else "Reservewechsel"
	var heading := AlveolusUIComponents.label(reserve_title, AlveolusVisualTheme.TYPE_EYEBROW_LABEL)
	stack.add_child(heading)

	_swap_toggle = AlveolusUIComponents.toggle_row("Reserve einwechseln", _pending_swap_enabled)
	_swap_toggle.name = "SwapToggle"
	_swap_toggle.disabled = not reserve.can_swap()
	_swap_toggle.set_meta(&"stable_focus_id", &"reserve.toggle")
	_swap_toggle.toggled.connect(_on_swap_toggled)
	stack.add_child(_swap_toggle)

	var option_titles: Array[String] = []
	var selected_index := 0
	var options := reserve.outgoing_options()
	for index in range(options.size()):
		var option := options[index]
		option_titles.append(option.title())
		_outgoing_ids.append(option.id())
		if option.id() == _pending_outgoing_id:
			selected_index = index
	if not option_titles.is_empty():
		var option_parts := AlveolusUIComponents.option_row("Tauscht gegen", option_titles, selected_index)
		var option_row := option_parts["row"] as HBoxContainer
		option_row.name = "OutgoingRow"
		_outgoing_option = option_parts["control"] as OptionButton
		_outgoing_option.name = "OutgoingOption"
		_outgoing_option.disabled = not _pending_swap_enabled or not reserve.can_swap()
		_outgoing_option.set_meta(&"stable_focus_id", &"reserve.outgoing")
		_outgoing_option.item_selected.connect(_on_outgoing_selected)
		stack.add_child(option_row)


func _build_validation() -> void:
	_validation_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_MUTED_LABEL)
	_validation_label.name = "Validation"
	_validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_validation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_stack.add_child(_validation_label)


func _build_actions() -> void:
	_action_grid = GridContainer.new()
	_action_grid.name = "FindingActions"
	_action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_grid.add_theme_constant_override("h_separation", AlveolusVisualTheme.CONTROL_GAP)
	_action_grid.add_theme_constant_override("v_separation", AlveolusVisualTheme.CONTROL_GAP)

	_confirm_button = AlveolusUIComponents.action_button(
		"Reaktion anwenden",
		AlveolusUIComponents.ACTION_PRIMARY,
		&"check"
	)
	_confirm_button.name = "ConfirmButton"
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_button.set_meta(&"stable_focus_id", &"confirm")
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_action_grid.add_child(_confirm_button)


func _apply_dynamic_state() -> void:
	_refresh_reaction_states()
	var reserve := _view_model.reserve_swap()
	if _swap_toggle != null:
		_swap_toggle.set_pressed_no_signal(_pending_swap_enabled)
		_swap_toggle.disabled = not reserve.can_swap()
	if _outgoing_option != null:
		var outgoing_index := reserve.outgoing_index(_pending_outgoing_id)
		if outgoing_index >= 0:
			_outgoing_option.select(outgoing_index)
		_outgoing_option.disabled = not _pending_swap_enabled or not reserve.can_swap()
	_validation_label.text = _view_model.validation_text()
	_validation_label.visible = not _validation_label.text.is_empty()
	_validation_label.add_theme_color_override(
		"font_color",
		AlveolusVisualTheme.TEAL if _view_model.validation_valid() else AlveolusVisualTheme.CORAL
	)
	_update_confirm_state()
	_update_focus_trap()
	_queue_responsive_layout()


func _refresh_reaction_states() -> void:
	for id in _reaction_order:
		var button := _reaction_buttons[id] as Button
		if button == null:
			continue
		var selected := id == _pending_reaction_id
		button.set_pressed_no_signal(selected)
		button.theme_type_variation = AlveolusVisualTheme.TYPE_SELECTED_CHOICE_ROW if selected else AlveolusVisualTheme.TYPE_CHOICE_ROW


func _update_confirm_state() -> void:
	var ready := _pending_reaction_id != &"" and _view_model.validation_valid()
	if _pending_swap_enabled:
		ready = ready and _pending_outgoing_id != &""
	AlveolusUIComponents.set_button_disabled(_confirm_button, not ready)


func _on_reaction_pressed(id: StringName) -> void:
	var button := reaction_action(id)
	if button == null or button.disabled:
		return
	_pending_reaction_id = id
	_refresh_reaction_states()
	_update_confirm_state()
	_update_focus_trap()
	reaction_selected.emit(id)


func _on_swap_toggled(enabled: bool) -> void:
	var reserve := _view_model.reserve_swap()
	_pending_swap_enabled = enabled and reserve.can_swap()
	if _pending_swap_enabled and _pending_outgoing_id == &"":
		var options := reserve.outgoing_options()
		if not options.is_empty():
			_pending_outgoing_id = options[0].id()
	if _outgoing_option != null:
		_outgoing_option.disabled = not _pending_swap_enabled
	_update_confirm_state()
	_update_focus_trap()
	swap_toggled.emit(_pending_swap_enabled)


func _on_outgoing_selected(index: int) -> void:
	if index < 0 or index >= _outgoing_ids.size():
		return
	_pending_outgoing_id = _outgoing_ids[index]
	_update_confirm_state()
	outgoing_selected.emit(_pending_outgoing_id)


func _on_confirm_pressed() -> void:
	if _confirm_button.disabled or _pending_reaction_id == &"":
		return
	var reserve := _view_model.reserve_swap()
	var incoming := reserve.incoming_id() if _pending_swap_enabled else &""
	var outgoing := _pending_outgoing_id if _pending_swap_enabled else &""
	confirm.emit(_pending_reaction_id, incoming, outgoing)


func _update_focus_trap() -> void:
	var controls: Array[Control] = []
	for reaction_id in _reaction_order:
		var reaction_button := _reaction_buttons.get(reaction_id) as Button
		if reaction_button != null and reaction_button.visible and not reaction_button.disabled:
			controls.append(reaction_button)
	if _swap_toggle != null and _swap_toggle.visible and not _swap_toggle.disabled:
		controls.append(_swap_toggle)
	if _outgoing_option != null and _outgoing_option.visible and not _outgoing_option.disabled:
		controls.append(_outgoing_option)
	if _confirm_button != null and not _confirm_button.disabled:
		controls.append(_confirm_button)
	if controls.is_empty():
		return
	for index in range(controls.size()):
		var control := controls[index]
		var previous := controls[posmod(index - 1, controls.size())]
		var following := controls[(index + 1) % controls.size()]
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(following)
		control.focus_neighbor_left = control.get_path_to(previous)
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_neighbor_right = control.get_path_to(following)
		control.focus_neighbor_bottom = control.get_path_to(following)


func _focused_stable_id() -> StringName:
	if not is_inside_tree():
		return &""
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null or not is_ancestor_of(focus_owner):
		return &""
	return StringName(focus_owner.get_meta(&"stable_focus_id", &""))


func _restore_focus(stable_id: StringName) -> void:
	var target := _control_for_stable_id(stable_id)
	var target_disabled := target is BaseButton and (target as BaseButton).disabled
	if target != null and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE and not target_disabled:
		target.grab_focus()
		_ensure_focus_visible(target)


func _control_for_stable_id(stable_id: StringName) -> Control:
	if String(stable_id).begins_with("reaction."):
		return reaction_action(StringName(String(stable_id).trim_prefix("reaction.")))
	match stable_id:
		&"reserve.toggle":
			return _swap_toggle
		&"reserve.outgoing":
			return _outgoing_option
		&"confirm":
			return _confirm_button
	return null


func _ensure_focus_visible(control: Control) -> void:
	if _body_scroll != null and control != null and _body_scroll.is_ancestor_of(control):
		_body_scroll.ensure_control_visible(control)


func _register_info_source(source: Control, info: FindingOverlayViewModel.InfoViewModel) -> void:
	if source == null or info == null:
		return
	var source_id := source.get_instance_id()
	_info_sources[source_id] = {
		"source": weakref(source),
		"provider": _info_payload.bind(info.duplicate_immutable()),
	}


func _info_payload(info: FindingOverlayViewModel.InfoViewModel) -> Dictionary:
	var payload := info.body_only_payload()
	var accent: Color = payload.get("accent", Color.TRANSPARENT)
	if accent.a <= 0.0:
		payload["accent"] = AlveolusVisualTheme.GOLD
	return payload.duplicate(true)


func _info_provider_for(source: Control) -> Callable:
	if source == null:
		return Callable()
	var entry := _info_sources.get(source.get_instance_id(), {}) as Dictionary
	return entry.get("provider", Callable()) as Callable


func _prune_info_sources() -> void:
	var stale_ids: Array[int] = []
	for source_id_value in _info_sources:
		var source_id := int(source_id_value)
		var entry := _info_sources[source_id] as Dictionary
		var source_ref := entry.get("source") as WeakRef
		var source: Variant = source_ref.get_ref() if source_ref != null else null
		if source == null or not is_instance_valid(source):
			stale_ids.append(source_id)
	for source_id in stale_ids:
		_info_sources.erase(source_id)


func _queue_responsive_layout() -> void:
	_refresh_responsive_layout.call_deferred()


func _refresh_responsive_layout() -> void:
	if _center == null or _modal == null or _body_scroll == null:
		return
	_compact_layout = size.x < COMPACT_WIDTH or size.y < COMPACT_HEIGHT
	var outer_margin := AlveolusVisualTheme.SCREEN_MARGIN_COMPACT if _compact_layout else AlveolusVisualTheme.SCREEN_MARGIN
	for side in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		_safe_area.add_theme_constant_override(side, outer_margin)
	var available := Vector2(
		maxf(0.0, size.x - outer_margin * 2.0),
		maxf(0.0, size.y - outer_margin * 2.0)
	)
	if available.x <= 0.0 or available.y <= 0.0:
		return

	var sheet_width := minf(MODAL_MAXIMUM_WIDTH, available.x)
	_modal.custom_minimum_size.x = floorf(sheet_width)
	_modal.custom_minimum_size.y = 0.0
	var reaction_columns := 1 if _compact_layout else 3
	var action_columns := 1
	var columns_changed := false
	if _copy_grid != null:
		columns_changed = columns_changed or _copy_grid.columns != 1
		_copy_grid.columns = 1
	if _reaction_grid != null:
		columns_changed = columns_changed or _reaction_grid.columns != reaction_columns
		_reaction_grid.columns = reaction_columns
	if _action_grid != null:
		columns_changed = columns_changed or _action_grid.columns != action_columns
		_action_grid.columns = action_columns
	var order_changed := _apply_responsive_body_order()
	if columns_changed or order_changed:
		_queue_layout_after_container_sort()
		return

	_body_scroll.custom_minimum_size.y = 0.0
	var body_height := _scrollbar_inset.get_combined_minimum_size().y
	var title_height := _title_label.get_combined_minimum_size().y if _title_label != null else 0.0
	var action_height := _action_grid.get_combined_minimum_size().y
	var chrome_height := (
		float(MODAL_PADDING * 2)
		+ title_height
		+ action_height
		+ float(AlveolusVisualTheme.CONTENT_GAP * 2)
	)
	var maximum_body_height := maxf(0.0, available.y - chrome_height)
	var visible_body_height := minf(body_height, maximum_body_height)
	_body_scroll.custom_minimum_size.y = ceilf(visible_body_height)
	var requires_scroll := body_height > visible_body_height + 1.0
	_body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if requires_scroll else ScrollContainer.SCROLL_MODE_DISABLED
	var scrollbar_inset := ceili(_body_scroll.get_v_scroll_bar().get_combined_minimum_size().x) if requires_scroll else 0
	_scrollbar_inset.add_theme_constant_override("margin_right", scrollbar_inset)
	if not requires_scroll:
		_body_scroll.scroll_vertical = 0


func _apply_responsive_body_order() -> bool:
	if _body_stack == null:
		return false
	# The fact line is the compact replacement for the removed medical/gameplay
	# cards, so it always remains the first piece of finding content.
	var leading_controls: Array[Control] = [_copy_grid, _reaction_grid]
	var next_index := 0
	var changed := false
	for control in leading_controls:
		if control == null or control.get_parent() != _body_stack:
			continue
		if control.get_index() != next_index:
			_body_stack.move_child(control, next_index)
			changed = true
		next_index += 1
	return changed


func _queue_layout_after_container_sort() -> void:
	if _layout_settle_pending or not is_inside_tree():
		return
	_layout_settle_pending = true
	get_tree().process_frame.connect(_settle_responsive_layout, CONNECT_ONE_SHOT)


func _settle_responsive_layout() -> void:
	_layout_settle_pending = false
	_refresh_responsive_layout()
