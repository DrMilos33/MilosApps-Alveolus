class_name UIScreenHost
extends Control

## Mounts route Controls and applies a UIScreenRouter snapshot to the scene tree.
##
## UIScreenRouter remains the source of truth for navigation and focus return.
## This host owns only scene-tree placement, visibility, deterministic layer
## order and GUI-input isolation. It never grabs focus and has no process loop.

signal route_mounted(route_id: StringName, layer_kind: int)
signal route_unmounted(route_id: StringName)
signal route_state_applied(revision: int, input_owner_id: StringName)

enum LayerKind {
	SCREEN,
	MODAL,
	DETAIL,
}

enum InputPolicy {
	BLOCKING,
	PASSIVE,
}

const SCREEN_Z := 0
const OVERLAY_Z_BASE := 100

var _screen_layer: Control
var _modal_layer: Control
var _detail_layer: Control
var _routes: Dictionary = {}
var _route_by_instance_id: Dictionary = {}
var _route_state: Dictionary = {
	"screens": [],
	"modals": [],
}
var _has_applied_state := false
var _applied_revision := -1
var _input_owner_id: StringName = &""


func _init() -> void:
	name = "UIScreenHost"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process(false)
	set_physics_process(false)
	_build_layers()


func mount_screen(route_id: StringName, view: Control) -> bool:
	return mount_route(route_id, view, LayerKind.SCREEN, InputPolicy.BLOCKING)


func mount_modal(route_id: StringName, view: Control) -> bool:
	return mount_route(route_id, view, LayerKind.MODAL, InputPolicy.BLOCKING)


func mount_detail(route_id: StringName, view: Control) -> bool:
	return mount_route(route_id, view, LayerKind.DETAIL, InputPolicy.PASSIVE)


func mount_route(
	route_id: StringName,
	view: Control,
	layer_kind: int,
	input_policy: int = InputPolicy.BLOCKING
) -> bool:
	if route_id == &"" or view == null or not is_instance_valid(view):
		return false
	if view == self or view == _screen_layer or view == _modal_layer or view == _detail_layer:
		return false
	if layer_kind < LayerKind.SCREEN or layer_kind > LayerKind.DETAIL:
		return false
	if _routes.has(route_id):
		return false
	var instance_id := view.get_instance_id()
	if _route_by_instance_id.has(instance_id):
		return false

	# Detail cards are display-only. Their explicit open/close intent is consumed
	# by the router/controller, while the card itself never receives GUI input.
	if layer_kind == LayerKind.DETAIL:
		input_policy = InputPolicy.PASSIVE
	elif input_policy != InputPolicy.BLOCKING and input_policy != InputPolicy.PASSIVE:
		return false

	var target_layer := _layer_root_for(layer_kind)
	var previous_parent := view.get_parent()
	if previous_parent != target_layer:
		if previous_parent != null:
			view.reparent(target_layer, false)
		else:
			target_layer.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var tree_exiting_callback := _on_view_tree_exiting.bind(route_id, instance_id)
	view.tree_exiting.connect(tree_exiting_callback, CONNECT_ONE_SHOT)
	var entry := {
		"view": weakref(view),
		"instance_id": instance_id,
		"layer_kind": layer_kind,
		"input_policy": input_policy,
		"tree_exiting_callback": tree_exiting_callback,
		"original_visible": view.visible,
		"active_process_mode": view.process_mode,
		"original_z_index": view.z_index,
		"original_z_as_relative": view.z_as_relative,
		"host_visible": false,
		"input_enabled": true,
		"input_states": {},
	}
	_routes[route_id] = entry
	_route_by_instance_id[instance_id] = route_id
	_set_route_visible(entry, false)
	_set_route_input_enabled(entry, false)
	_apply_current_layout()
	route_mounted.emit(route_id, layer_kind)
	return true


## Detaches a mounted route. When free_view is false, ownership of the returned
## orphan Control transfers to the caller. Passing true queues it for deletion.
func unmount_route(route_id: StringName, free_view: bool = false) -> Control:
	var entry: Dictionary = _routes.get(route_id, {})
	if entry.is_empty():
		return null
	var view := _view_from_entry(entry)
	_routes.erase(route_id)
	_route_by_instance_id.erase(int(entry.get("instance_id", 0)))
	if view != null:
		_disconnect_tree_exiting(view, entry)
		_restore_route_input(entry)
		view.process_mode = int(entry.get("active_process_mode", Node.PROCESS_MODE_INHERIT))
		view.visible = bool(entry.get("original_visible", true))
		view.z_index = int(entry.get("original_z_index", 0))
		view.z_as_relative = bool(entry.get("original_z_as_relative", true))
		var parent := view.get_parent()
		if parent != null:
			parent.remove_child(view)
		if free_view:
			view.queue_free()
	_apply_current_layout()
	route_unmounted.emit(route_id)
	return view


## Applies the normalized subset produced by UIScreenRouter.route_snapshot().
## A non-negative revision must advance strictly. Duplicate or stale revisions
## are no-ops; unversioned calls remain content-idempotent.
func apply_route_state(snapshot: Dictionary, revision: int = -1) -> bool:
	var effective_revision := revision
	if effective_revision < 0 and snapshot.has("revision"):
		effective_revision = int(snapshot.get("revision", -1))
	if effective_revision >= 0 and _applied_revision >= 0 and effective_revision <= _applied_revision:
		return false

	var normalized := {
		"screens": _normalize_route_ids(snapshot.get("screens", [])),
		"modals": _normalize_route_ids(snapshot.get("modals", [])),
	}
	var state_changed := not _has_applied_state or not _same_route_state(_route_state, normalized)
	if effective_revision >= 0:
		_applied_revision = effective_revision
	if not state_changed:
		return false

	_route_state = normalized
	_has_applied_state = true
	_apply_current_layout()
	route_state_applied.emit(_applied_revision, _input_owner_id)
	return true


func has_route(route_id: StringName) -> bool:
	_prune_stale_routes()
	return _routes.has(route_id)


func route_view(route_id: StringName) -> Control:
	var entry: Dictionary = _routes.get(route_id, {})
	return _view_from_entry(entry)


func is_route_visible(route_id: StringName) -> bool:
	var entry: Dictionary = _routes.get(route_id, {})
	var view := _view_from_entry(entry)
	return view != null and bool(entry.get("host_visible", false)) and view.visible


func is_route_input_owner(route_id: StringName) -> bool:
	return route_id != &"" and route_id == _input_owner_id


func current_input_owner_id() -> StringName:
	return _input_owner_id


func mounted_route_count() -> int:
	_prune_stale_routes()
	return _routes.size()


func applied_revision() -> int:
	return _applied_revision


func current_route_state() -> Dictionary:
	return {
		"screens": (_route_state.get("screens", []) as Array).duplicate(),
		"modals": (_route_state.get("modals", []) as Array).duplicate(),
		"input_owner": _input_owner_id,
		"revision": _applied_revision,
	}


func screen_layer_root() -> Control:
	return _screen_layer


func modal_layer_root() -> Control:
	return _modal_layer


func detail_layer_root() -> Control:
	return _detail_layer


func _build_layers() -> void:
	_screen_layer = _layer_root("ScreenLayer")
	_modal_layer = _layer_root("ModalLayer")
	_detail_layer = _layer_root("DetailLayer")
	add_child(_screen_layer)
	add_child(_modal_layer)
	add_child(_detail_layer)


func _layer_root(layer_name: String) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.focus_mode = Control.FOCUS_NONE
	layer.z_index = 0
	return layer


func _layer_root_for(layer_kind: int) -> Control:
	match layer_kind:
		LayerKind.MODAL:
			return _modal_layer
		LayerKind.DETAIL:
			return _detail_layer
		_:
			return _screen_layer


func _apply_current_layout() -> void:
	_prune_stale_routes()
	var screen_ids: Array = _route_state.get("screens", [])
	var modal_ids: Array = _route_state.get("modals", [])
	var active_screen_id: StringName = &""
	if not screen_ids.is_empty():
		active_screen_id = StringName(screen_ids[screen_ids.size() - 1])

	var visible_routes: Dictionary = {}
	var active_screen_entry: Dictionary = _routes.get(active_screen_id, {})
	if int(active_screen_entry.get("layer_kind", -1)) == LayerKind.SCREEN:
		visible_routes[active_screen_id] = SCREEN_Z

	for index in range(modal_ids.size()):
		var overlay_id := StringName(modal_ids[index])
		var overlay_entry: Dictionary = _routes.get(overlay_id, {})
		var layer_kind := int(overlay_entry.get("layer_kind", -1))
		if layer_kind == LayerKind.MODAL or layer_kind == LayerKind.DETAIL:
			visible_routes[overlay_id] = OVERLAY_Z_BASE + index

	_input_owner_id = _resolve_input_owner(active_screen_id, modal_ids)
	var route_ids: Array = _routes.keys()
	for route_value in route_ids:
		var route_id := StringName(route_value)
		var entry: Dictionary = _routes.get(route_id, {})
		var view := _view_from_entry(entry)
		if view == null:
			continue
		var should_show := visible_routes.has(route_id)
		_set_route_visible(entry, should_show)
		_set_route_input_enabled(entry, should_show and route_id == _input_owner_id)
		view.z_as_relative = true
		view.z_index = int(visible_routes.get(route_id, _base_z_for_entry(entry)))


func _resolve_input_owner(active_screen_id: StringName, modal_ids: Array) -> StringName:
	for index in range(modal_ids.size() - 1, -1, -1):
		var route_id := StringName(modal_ids[index])
		var entry: Dictionary = _routes.get(route_id, {})
		if entry.is_empty():
			# An unmounted overlay is treated as blocking during the transition so
			# input can never fall through to an older screen accidentally.
			return &""
		if int(entry.get("input_policy", InputPolicy.BLOCKING)) == InputPolicy.BLOCKING:
			return route_id
	var screen_entry: Dictionary = _routes.get(active_screen_id, {})
	if (
		int(screen_entry.get("layer_kind", -1)) == LayerKind.SCREEN
		and int(screen_entry.get("input_policy", InputPolicy.BLOCKING)) == InputPolicy.BLOCKING
	):
		return active_screen_id
	return &""


func _base_z_for_entry(entry: Dictionary) -> int:
	return SCREEN_Z if int(entry.get("layer_kind", LayerKind.SCREEN)) == LayerKind.SCREEN else OVERLAY_Z_BASE


func _set_route_visible(entry: Dictionary, should_show: bool) -> void:
	var view := _view_from_entry(entry)
	if view == null:
		return
	var was_host_visible := bool(entry.get("host_visible", false))
	if should_show:
		if not was_host_visible:
			view.process_mode = int(entry.get("active_process_mode", Node.PROCESS_MODE_INHERIT))
		view.show()
		entry["host_visible"] = true
		return
	if was_host_visible:
		entry["active_process_mode"] = view.process_mode
	view.hide()
	view.process_mode = Node.PROCESS_MODE_DISABLED
	entry["host_visible"] = false


func _set_route_input_enabled(entry: Dictionary, enabled: bool) -> void:
	var view := _view_from_entry(entry)
	if view == null:
		return
	if enabled:
		if not bool(entry.get("input_enabled", false)):
			_restore_route_input(entry)
		entry["input_enabled"] = true
		return
	_disable_control_tree(view, entry)
	entry["input_enabled"] = false


func _disable_control_tree(node: Node, entry: Dictionary) -> void:
	var states: Dictionary = entry.get("input_states", {})
	if node is Control:
		var control := node as Control
		var instance_id := control.get_instance_id()
		if not states.has(instance_id):
			states[instance_id] = {
				"control": weakref(control),
				"mouse_filter": control.mouse_filter,
				"focus_mode": control.focus_mode,
			}
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_disable_control_tree(child, entry)
	entry["input_states"] = states


func _restore_route_input(entry: Dictionary) -> void:
	var states: Dictionary = entry.get("input_states", {})
	for state_value in states.values():
		var state: Dictionary = state_value
		var token: Variant = state.get("control")
		var target: Variant = (token as WeakRef).get_ref() if token is WeakRef else null
		if target is Control and is_instance_valid(target) and not (target as Control).is_queued_for_deletion():
			var control := target as Control
			control.mouse_filter = int(state.get("mouse_filter", Control.MOUSE_FILTER_STOP))
			control.focus_mode = int(state.get("focus_mode", Control.FOCUS_NONE))
	states.clear()
	entry["input_states"] = states


func _normalize_route_ids(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not value is Array:
		return result
	var values := value as Array
	var seen: Dictionary = {}
	for item in values:
		var route_id := StringName(String(item))
		if route_id == &"" or seen.has(route_id):
			continue
		seen[route_id] = true
		result.append(route_id)
	return result


func _same_route_state(left: Dictionary, right: Dictionary) -> bool:
	return left.get("screens", []) == right.get("screens", []) \
		and left.get("modals", []) == right.get("modals", [])


func _view_from_entry(entry: Dictionary) -> Control:
	if entry.is_empty():
		return null
	var token: Variant = entry.get("view")
	var target: Variant = (token as WeakRef).get_ref() if token is WeakRef else null
	if not target is Control or not is_instance_valid(target):
		return null
	var control := target as Control
	if control.is_queued_for_deletion():
		return null
	return control


func _prune_stale_routes() -> void:
	var stale_ids: Array[StringName] = []
	for route_value in _routes.keys():
		var route_id := StringName(route_value)
		var entry: Dictionary = _routes.get(route_id, {})
		if _view_from_entry(entry) == null:
			stale_ids.append(route_id)
	for route_id in stale_ids:
		var entry: Dictionary = _routes.get(route_id, {})
		_route_by_instance_id.erase(int(entry.get("instance_id", 0)))
		_routes.erase(route_id)
		if _input_owner_id == route_id:
			_input_owner_id = &""


func _on_view_tree_exiting(route_id: StringName, instance_id: int) -> void:
	var entry: Dictionary = _routes.get(route_id, {})
	if entry.is_empty() or int(entry.get("instance_id", 0)) != instance_id:
		return
	_routes.erase(route_id)
	_route_by_instance_id.erase(instance_id)
	if _input_owner_id == route_id:
		_input_owner_id = &""
	_apply_current_layout()
	route_unmounted.emit(route_id)


func _disconnect_tree_exiting(view: Control, entry: Dictionary) -> void:
	var callback: Callable = entry.get("tree_exiting_callback", Callable())
	if callback.is_valid() and view.tree_exiting.is_connected(callback):
		view.tree_exiting.disconnect(callback)
