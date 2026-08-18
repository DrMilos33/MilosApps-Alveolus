class_name ContextDetailController
extends Control

## Shared, non-modal context card for pointer hover and the explicit `ui_info`
## action. The controller never takes focus and never participates in layout.

signal detail_opened(source: Control, explicit: bool)
signal detail_closed

const CARD_MIN_WIDTH := 220.0
const TOOLTIP_MAX_WIDTH := 280.0
const DETAIL_MAX_WIDTH := 360.0
const VIEWPORT_MARGIN := 12.0
const SOURCE_GAP := 6.0

enum OpenMode {
	NONE,
	HOVER,
	EXPLICIT,
}

enum Placement {
	AUTO,
	ABOVE_CENTER,
}

var card: PanelContainer
var header: HBoxContainer
var icon: SimpleIcon
var title_label: Label
var body_label: Label
var meta_label: Label

var _registrations: Dictionary = {}
var _active_source_id := 0
var _mode := OpenMode.NONE
var _layout_generation := 0
var _current_payload: Dictionary = {}
var _hover_recovery_scheduled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 900
	_build_card()
	resized.connect(_on_controller_resized)


func register_source(
	source: Control,
	provider: Callable,
	hover_enabled: bool = true,
	anchor: Control = null,
	placement: int = Placement.AUTO
) -> void:
	if source == null or not is_instance_valid(source):
		push_warning("ContextDetailController.register_source requires a valid Control.")
		return
	if not provider.is_valid():
		push_warning("ContextDetailController.register_source requires a valid provider.")
		return

	var source_id := source.get_instance_id()
	if _registrations.has(source_id):
		var existing: Dictionary = _registrations[source_id]
		var was_hover_enabled := bool(existing.get("hover_enabled", true))
		var entered: Callable = existing.get("entered", Callable())
		var exited: Callable = existing.get("exited", Callable())
		if was_hover_enabled != hover_enabled:
			if hover_enabled:
				if entered.is_valid() and not source.mouse_entered.is_connected(entered):
					source.mouse_entered.connect(entered)
				if exited.is_valid() and not source.mouse_exited.is_connected(exited):
					source.mouse_exited.connect(exited)
			else:
				_disconnect_if_connected(source.mouse_entered, entered)
				_disconnect_if_connected(source.mouse_exited, exited)
		existing["provider"] = provider
		existing["hover_enabled"] = hover_enabled
		existing["anchor"] = weakref(anchor) if anchor != null and is_instance_valid(anchor) else null
		existing["placement"] = Placement.ABOVE_CENTER if placement == Placement.ABOVE_CENTER else Placement.AUTO
		_registrations[source_id] = existing
		if hover_enabled:
			_schedule_hover_recovery()
		return

	var entered := _on_source_mouse_entered.bind(source_id)
	var exited := _on_source_mouse_exited.bind(source_id)
	var visibility_changed := _on_source_visibility_changed.bind(source_id)
	var tree_exiting := _on_source_tree_exiting.bind(source_id)
	if hover_enabled:
		source.mouse_entered.connect(entered)
		source.mouse_exited.connect(exited)
	source.visibility_changed.connect(visibility_changed)
	source.tree_exiting.connect(tree_exiting, CONNECT_ONE_SHOT)
	_registrations[source_id] = {
		"source": weakref(source),
		"provider": provider,
		"entered": entered,
		"exited": exited,
		"visibility_changed": visibility_changed,
		"tree_exiting": tree_exiting,
		"hover_enabled": hover_enabled,
		"anchor": weakref(anchor) if anchor != null and is_instance_valid(anchor) else null,
		"placement": Placement.ABOVE_CENTER if placement == Placement.ABOVE_CENTER else Placement.AUTO,
	}
	if hover_enabled:
		_schedule_hover_recovery()


func unregister_source(source: Control) -> void:
	if source == null:
		return
	var source_id := source.get_instance_id()
	if not _registrations.has(source_id):
		return
	var registration: Dictionary = _registrations[source_id]
	if bool(registration.get("hover_enabled", true)):
		_disconnect_if_connected(source.mouse_entered, registration.get("entered", Callable()))
		_disconnect_if_connected(source.mouse_exited, registration.get("exited", Callable()))
	_disconnect_if_connected(source.visibility_changed, registration.get("visibility_changed", Callable()))
	_disconnect_if_connected(source.tree_exiting, registration.get("tree_exiting", Callable()))
	_registrations.erase(source_id)
	if _active_source_id == source_id:
		close_all()


func toggle_focused(focus_owner: Control) -> bool:
	var source_id := _registered_ancestor_id(focus_owner)
	if source_id == 0:
		return false
	if _mode == OpenMode.EXPLICIT and _active_source_id == source_id and card.visible:
		close_explicit()
		return true
	return _open(source_id, OpenMode.EXPLICIT)


func close_explicit() -> void:
	if _mode == OpenMode.EXPLICIT:
		_close_card()


func close_all() -> void:
	_close_card()


func is_open() -> bool:
	return card != null and card.visible


func is_explicit() -> bool:
	return is_open() and _mode == OpenMode.EXPLICIT


func active_source() -> Control:
	return _source_for_id(_active_source_id)


func current_payload() -> Dictionary:
	return _current_payload.duplicate()


func _build_card() -> void:
	card = AlveolusUIComponents.surface(
		AlveolusVisualTheme.SurfaceRole.TOOLTIP_CARD,
		AlveolusVisualTheme.TURQUOISE
	)
	card.name = "ContextDetailCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(CARD_MIN_WIDTH, 0.0)
	add_child(card)

	var stack := VBoxContainer.new()
	stack.name = "Content"
	stack.add_theme_constant_override("separation", AlveolusVisualTheme.GRID_UNIT)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(AlveolusUIComponents.margin(stack, 12))

	header = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", AlveolusVisualTheme.CONTROL_GAP)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(header)

	icon = SimpleIcon.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon)

	title_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_HUD_VALUE_LABEL)
	title_label.name = "Title"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title_label)

	body_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL)
	body_label.name = "Body"
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(body_label)

	meta_label = AlveolusUIComponents.label("", AlveolusVisualTheme.TYPE_HUD_MUTED_LABEL)
	meta_label.name = "Meta"
	meta_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(meta_label)

	_set_mouse_ignore_recursive(card)
	card.hide()


func _open(source_id: int, mode: int) -> bool:
	if card == null:
		return false
	var source := _source_for_id(source_id)
	if source == null or not source.is_inside_tree() or not source.is_visible_in_tree():
		if _active_source_id == source_id:
			_close_card()
		return false
	var registration: Dictionary = _registrations.get(source_id, {})
	var provider: Callable = registration.get("provider", Callable())
	if not provider.is_valid():
		_close_card()
		return false
	var provided: Variant = provider.call()
	if not provided is Dictionary:
		push_warning("ContextDetailController provider must return a Dictionary.")
		_close_card()
		return false
	var payload := provided as Dictionary
	_apply_payload(payload, mode)
	_active_source_id = source_id
	_mode = mode
	_current_payload = payload.duplicate()
	card.show()
	_layout_generation += 1
	_measure_and_place.call_deferred(source_id, _layout_generation, 0)
	detail_opened.emit(source, mode == OpenMode.EXPLICIT)
	return true


func _apply_payload(payload: Dictionary, mode: int) -> void:
	var accent_value: Variant = payload.get("accent", AlveolusVisualTheme.TURQUOISE)
	var accent: Color = accent_value if typeof(accent_value) == TYPE_COLOR else AlveolusVisualTheme.TURQUOISE
	var icon_value: Variant = payload.get("icon_kind", &"")
	var icon_kind := StringName(String(icon_value)) if icon_value != null else &""
	title_label.text = String(payload.get("title", "")).strip_edges()
	body_label.text = String(payload.get("body", "")).strip_edges()
	meta_label.text = String(payload.get("meta", "")).strip_edges()
	title_label.visible = not title_label.text.is_empty()
	body_label.visible = not body_label.text.is_empty()
	meta_label.visible = not meta_label.text.is_empty()
	icon.visible = not icon_kind.is_empty()
	header.visible = title_label.visible or icon.visible
	if icon.visible:
		icon.configure(icon_kind, accent)
	meta_label.add_theme_color_override("font_color", accent.lightened(0.18))
	var surface_role := AlveolusVisualTheme.SurfaceRole.DETAIL_CARD if mode == OpenMode.EXPLICIT else AlveolusVisualTheme.SurfaceRole.TOOLTIP_CARD
	AlveolusUIComponents.apply_surface_role(card, surface_role, accent)
	var surface_opacity := clampf(float(payload.get("surface_opacity", 1.0)), 0.35, 1.0)
	_set_surface_opacity(surface_opacity)


func _measure_and_place(source_id: int, generation: int, phase: int) -> void:
	if generation != _layout_generation or source_id != _active_source_id or not card.visible:
		return
	var source := _source_for_id(source_id)
	if source == null or not source.is_inside_tree() or not source.is_visible_in_tree():
		_close_card()
		return
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	var available_width := maxf(1.0, viewport_size.x - VIEWPORT_MARGIN * 2.0)
	var maximum_width := DETAIL_MAX_WIDTH if _mode == OpenMode.EXPLICIT else TOOLTIP_MAX_WIDTH
	var requested_width := float(_current_payload.get("maximum_width", 0.0))
	if requested_width > 0.0:
		maximum_width = minf(maximum_width, requested_width)
	var width := minf(maximum_width, available_width)
	if available_width >= CARD_MIN_WIDTH:
		width = maxf(width, CARD_MIN_WIDTH)
	card.custom_minimum_size = Vector2(width, 0.0)
	card.size = Vector2(width, 0.0)
	card.reset_size()
	if phase == 0:
		# Container minimum sizes settle after one layout frame. Measuring again in
		# the same deferred queue can observe the previous unconstrained wrap width.
		get_tree().process_frame.connect(
			_measure_and_place.bind(source_id, generation, 1),
			CONNECT_ONE_SHOT
		)
		return
	var card_height := ceilf(card.get_combined_minimum_size().y)
	card.size = Vector2(width, card_height)
	var registration: Dictionary = _registrations.get(source_id, {})
	var placement := int(registration.get("placement", Placement.AUTO))
	var anchor := _anchor_for_registration(source_id, source)
	card.position = _contained_position(_source_rect_in_controller(anchor), card.size, viewport_size, placement)


func _contained_position(
	source_rect: Rect2,
	card_size: Vector2,
	viewport_size: Vector2,
	placement: int = Placement.AUTO
) -> Vector2:
	var bounds := Rect2(
		Vector2(VIEWPORT_MARGIN, VIEWPORT_MARGIN),
		Vector2(
			maxf(0.0, viewport_size.x - VIEWPORT_MARGIN * 2.0),
			maxf(0.0, viewport_size.y - VIEWPORT_MARGIN * 2.0)
		)
	)
	var candidates: Array[Vector2] = []
	if placement == Placement.ABOVE_CENTER:
		var centered_x := source_rect.get_center().x - card_size.x * 0.5
		candidates.append(Vector2(centered_x, source_rect.position.y - card_size.y - SOURCE_GAP))
		candidates.append(Vector2(centered_x, source_rect.end.y + SOURCE_GAP))
	candidates.append_array([
		Vector2(source_rect.end.x + SOURCE_GAP, source_rect.position.y),
		Vector2(source_rect.position.x - card_size.x - SOURCE_GAP, source_rect.position.y),
		Vector2(source_rect.position.x, source_rect.end.y + SOURCE_GAP),
		Vector2(source_rect.position.x, source_rect.position.y - card_size.y - SOURCE_GAP),
	])
	for candidate in candidates:
		if bounds.encloses(Rect2(candidate, card_size)):
			return candidate
	var maximum := bounds.end - card_size
	maximum.x = maxf(maximum.x, bounds.position.x)
	maximum.y = maxf(maximum.y, bounds.position.y)
	return Vector2(
		clampf(candidates[0].x, bounds.position.x, maximum.x),
		clampf(candidates[0].y, bounds.position.y, maximum.y)
	)


func _anchor_for_registration(source_id: int, fallback: Control) -> Control:
	var registration: Dictionary = _registrations.get(source_id, {})
	var anchor_ref := registration.get("anchor") as WeakRef
	if anchor_ref == null:
		return fallback
	var anchor_value: Variant = anchor_ref.get_ref()
	var anchor := anchor_value as Control if anchor_value != null and is_instance_valid(anchor_value) else null
	if anchor == null or not anchor.is_inside_tree() or not anchor.is_visible_in_tree():
		return fallback
	return anchor


func _set_surface_opacity(opacity: float) -> void:
	var color := Color(1.0, 1.0, 1.0, opacity)
	card.self_modulate = color
	var membrane := card.get_node_or_null("BioLumenSurface") as CanvasItem
	if membrane != null:
		# The shared membrane shader writes its own alpha. Hide that decorative
		# layer for translucent fact cards so only the centrally themed panel body
		# is faded; regular context cards restore it on their next payload.
		membrane.visible = opacity >= 0.999


func _source_rect_in_controller(source: Control) -> Rect2:
	var inverse := get_global_transform().affine_inverse()
	var source_transform := source.get_global_transform()
	var top_left := inverse * (source_transform * Vector2.ZERO)
	var bottom_right := inverse * (source_transform * source.size)
	return Rect2(top_left, bottom_right - top_left).abs()


func _on_source_mouse_entered(source_id: int) -> void:
	if _mode == OpenMode.EXPLICIT:
		return
	_open(source_id, OpenMode.HOVER)


func _schedule_hover_recovery() -> void:
	# Rebuilt lists replace the Control below a stationary pointer. Godot does
	# not guarantee a second mouse_entered signal for that replacement, so the
	# shared tooltip would otherwise disappear until the mouse moves again.
	if _hover_recovery_scheduled or not is_inside_tree():
		return
	_hover_recovery_scheduled = true
	_begin_hover_recovery.call_deferred()


func _begin_hover_recovery() -> void:
	if not is_inside_tree():
		_hover_recovery_scheduled = false
		return
	get_tree().process_frame.connect(_recover_hover_under_pointer, CONNECT_ONE_SHOT)


func _recover_hover_under_pointer() -> void:
	_hover_recovery_scheduled = false
	if _mode == OpenMode.EXPLICIT or not is_inside_tree():
		return
	var hovered := get_viewport().gui_get_hovered_control()
	var hovered_source_id := _registered_ancestor_id(hovered)
	if hovered_source_id != 0:
		var registration: Dictionary = _registrations.get(hovered_source_id, {})
		if bool(registration.get("hover_enabled", false)):
			_open(hovered_source_id, OpenMode.HOVER)
			return
	_recover_hover_at(get_local_mouse_position())


func _recover_hover_at(local_pointer: Vector2) -> bool:
	if _mode == OpenMode.EXPLICIT:
		return false
	for source_id_value in _registrations:
		var source_id := int(source_id_value)
		var registration: Dictionary = _registrations[source_id]
		if not bool(registration.get("hover_enabled", false)):
			continue
		var source := _source_for_id(source_id)
		if source == null or not source.is_inside_tree() or not source.is_visible_in_tree():
			continue
		if _source_rect_in_controller(source).has_point(local_pointer):
			return _open(source_id, OpenMode.HOVER)
	return false


func _on_source_mouse_exited(source_id: int) -> void:
	if _mode == OpenMode.HOVER and _active_source_id == source_id:
		_close_hover_if_pointer_left.call_deferred(source_id)


func _close_hover_if_pointer_left(source_id: int) -> void:
	if _mode != OpenMode.HOVER or _active_source_id != source_id:
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if _control_belongs_to_source(hovered, source_id):
		return
	_close_card()


func _on_source_visibility_changed(source_id: int) -> void:
	if _active_source_id != source_id:
		return
	var source := _source_for_id(source_id)
	if source == null or not source.is_visible_in_tree():
		_close_card()


func _on_source_tree_exiting(source_id: int) -> void:
	_registrations.erase(source_id)
	if _active_source_id == source_id:
		_close_card()


func _on_controller_resized() -> void:
	if not is_open():
		return
	_layout_generation += 1
	_measure_and_place.call_deferred(_active_source_id, _layout_generation, 0)


func _registered_ancestor_id(control: Control) -> int:
	var current: Node = control
	while current != null:
		if current is Control:
			var current_id := current.get_instance_id()
			if _registrations.has(current_id):
				return current_id
		current = current.get_parent()
	return 0


func _control_belongs_to_source(control: Control, source_id: int) -> bool:
	var current: Node = control
	while current != null:
		if current is Control and current.get_instance_id() == source_id:
			return true
		current = current.get_parent()
	return false


func _source_for_id(source_id: int) -> Control:
	if source_id == 0 or not _registrations.has(source_id):
		return null
	var registration: Dictionary = _registrations[source_id]
	var source_ref: WeakRef = registration.get("source") as WeakRef
	if source_ref == null:
		return null
	var source: Variant = source_ref.get_ref()
	return source as Control if source != null and is_instance_valid(source) else null


func _close_card() -> void:
	_layout_generation += 1
	var was_open := is_open()
	_active_source_id = 0
	_mode = OpenMode.NONE
	_current_payload.clear()
	if card != null:
		card.hide()
	if was_open:
		detail_closed.emit()


func _disconnect_if_connected(signal_value: Signal, callback: Callable) -> void:
	if callback.is_valid() and signal_value.is_connected(callback):
		signal_value.disconnect(callback)


func _set_mouse_ignore_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore_recursive(child)
