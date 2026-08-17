class_name UIScreenRouter
extends RefCounted

signal route_changed(screen_id: StringName, modal_id: StringName)
signal focus_requested(target: Variant)

var _screens: Array[Dictionary] = []
var _modals: Array[Dictionary] = []
var last_focus_request: Variant = null


func reset(root_screen_id: StringName, default_focus: Variant = null) -> bool:
	if root_screen_id == &"":
		return false
	_screens = [_entry(root_screen_id, default_focus)]
	_modals.clear()
	_emit_route_and_focus()
	return true


func push_screen(
	screen_id: StringName,
	default_focus: Variant = null,
	current_focus: Variant = null
) -> bool:
	if screen_id == &"" or not _modals.is_empty():
		return false
	_remember_active_focus(current_focus)
	_screens.append(_entry(screen_id, default_focus, current_focus))
	_emit_route_and_focus()
	return true


func replace_screen(
	screen_id: StringName,
	default_focus: Variant = null,
	current_focus: Variant = null
) -> bool:
	if screen_id == &"" or not _modals.is_empty():
		return false
	if _screens.is_empty():
		return reset(screen_id, default_focus)
	_remember_active_focus(current_focus)
	_screens[_screens.size() - 1] = _entry(screen_id, default_focus)
	_emit_route_and_focus()
	return true


func open_modal(
	modal_id: StringName,
	default_focus: Variant = null,
	current_focus: Variant = null,
	request_focus_on_open: bool = true
) -> bool:
	if modal_id == &"" or _screens.is_empty():
		return false
	if not _modals.is_empty() and current_modal_id() == modal_id:
		return false
	_remember_active_focus(current_focus)
	_modals.append(_entry(modal_id, default_focus, current_focus, request_focus_on_open))
	_emit_route_and_focus(null, request_focus_on_open)
	return true


func open_context_detail(
	detail_id: StringName = &"context_detail",
	current_focus: Variant = null
) -> bool:
	return open_modal(detail_id, null, current_focus, false)


func close_modal(current_focus: Variant = null) -> bool:
	if _modals.is_empty():
		return false
	_remember_active_focus(current_focus)
	var closed_entry: Dictionary = _modals.pop_back()
	_emit_route_and_focus(_valid_entry_target(closed_entry, "trigger_focus"))
	return true


func back(current_focus: Variant = null) -> bool:
	if not _modals.is_empty():
		return close_modal(current_focus)
	if _screens.size() <= 1:
		return false
	_remember_active_focus(current_focus)
	var closed_entry: Dictionary = _screens.pop_back()
	_emit_route_and_focus(_valid_entry_target(closed_entry, "trigger_focus"))
	return true


func remember_focus(target: Variant) -> bool:
	if not _valid_focus_target(target) or (_screens.is_empty() and _modals.is_empty()):
		return false
	_remember_active_focus(target)
	return true


func set_default_focus(route_id: StringName, target: Variant) -> bool:
	if route_id == &"" or not _valid_focus_target(target):
		return false
	var route_ref := _find_route_ref(route_id)
	if route_ref.is_empty():
		return false
	var entry_data := _entry_at(route_ref)
	entry_data["default_focus"] = _focus_token(target)
	_set_entry_at(route_ref, entry_data)
	if _same_route_ref(route_ref, _active_focus_route_ref()):
		_emit_focus_request(target)
	return true


func current_screen_id() -> StringName:
	if _screens.is_empty():
		return &""
	return StringName(_screens[_screens.size() - 1].get("id", &""))


func current_modal_id() -> StringName:
	if _modals.is_empty():
		return &""
	return StringName(_modals[_modals.size() - 1].get("id", &""))


func current_input_owner_id() -> StringName:
	return current_modal_id() if not _modals.is_empty() else current_screen_id()


func current_focus_owner_id() -> StringName:
	var route_ref := _active_focus_route_ref()
	if route_ref.is_empty():
		return &""
	return StringName(_entry_at(route_ref).get("id", &""))


func is_input_owner(route_id: StringName) -> bool:
	return route_id != &"" and current_input_owner_id() == route_id


func is_focus_owner(route_id: StringName) -> bool:
	return route_id != &"" and current_focus_owner_id() == route_id


func can_go_back() -> bool:
	return not _modals.is_empty() or _screens.size() > 1


func screen_depth() -> int:
	return _screens.size()


func modal_depth() -> int:
	return _modals.size()


func route_snapshot() -> Dictionary:
	var screen_ids: Array[StringName] = []
	for entry_data in _screens:
		screen_ids.append(StringName(entry_data.get("id", &"")))
	var modal_ids: Array[StringName] = []
	for entry_data in _modals:
		modal_ids.append(StringName(entry_data.get("id", &"")))
	return {
		"screens": screen_ids,
		"modals": modal_ids,
		"input_owner": current_input_owner_id(),
		"focus_owner": current_focus_owner_id(),
	}


func _entry(
	route_id: StringName,
	default_focus: Variant,
	trigger_focus: Variant = null,
	requests_focus: bool = true
) -> Dictionary:
	return {
		"id": route_id,
		"default_focus": _focus_token(default_focus) if _valid_focus_target(default_focus) else null,
		"last_focus": null,
		"trigger_focus": _focus_token(trigger_focus) if _valid_focus_target(trigger_focus) else null,
		"requests_focus": requests_focus,
	}


func _remember_active_focus(target: Variant) -> void:
	if not _valid_focus_target(target):
		return
	var route_ref := _active_focus_route_ref()
	if route_ref.is_empty():
		return
	var entry_data := _entry_at(route_ref)
	entry_data["last_focus"] = _focus_token(target)
	_set_entry_at(route_ref, entry_data)


func _emit_route_and_focus(preferred_target: Variant = null, request_focus: bool = true) -> void:
	route_changed.emit(current_screen_id(), current_modal_id())
	if not request_focus:
		return
	var target: Variant = preferred_target
	if not _valid_focus_target(target):
		target = _active_focus_target()
	_emit_focus_request(target)


func _emit_focus_request(target: Variant) -> void:
	last_focus_request = target if _valid_focus_target(target) else null
	if last_focus_request != null:
		focus_requested.emit(last_focus_request)


func _active_focus_target() -> Variant:
	var route_ref := _active_focus_route_ref()
	if route_ref.is_empty():
		return null
	var entry_data := _entry_at(route_ref)
	var previous: Variant = _valid_entry_target(entry_data, "last_focus")
	if previous != null:
		return previous
	return _valid_entry_target(entry_data, "default_focus")


func _active_focus_route_ref() -> Dictionary:
	for modal_index in range(_modals.size() - 1, -1, -1):
		if bool(_modals[modal_index].get("requests_focus", true)):
			return {"stack": &"modal", "index": modal_index}
	if not _screens.is_empty():
		return {"stack": &"screen", "index": _screens.size() - 1}
	return {}


func _find_route_ref(route_id: StringName) -> Dictionary:
	for modal_index in range(_modals.size() - 1, -1, -1):
		if StringName(_modals[modal_index].get("id", &"")) == route_id:
			return {"stack": &"modal", "index": modal_index}
	for screen_index in range(_screens.size() - 1, -1, -1):
		if StringName(_screens[screen_index].get("id", &"")) == route_id:
			return {"stack": &"screen", "index": screen_index}
	return {}


func _entry_at(route_ref: Dictionary) -> Dictionary:
	var index := int(route_ref.get("index", -1))
	if route_ref.get("stack", &"") == &"modal":
		return _modals[index]
	return _screens[index]


func _set_entry_at(route_ref: Dictionary, entry_data: Dictionary) -> void:
	var index := int(route_ref.get("index", -1))
	if route_ref.get("stack", &"") == &"modal":
		_modals[index] = entry_data
	else:
		_screens[index] = entry_data


func _same_route_ref(left: Dictionary, right: Dictionary) -> bool:
	return (
		not left.is_empty()
		and not right.is_empty()
		and left.get("stack", &"") == right.get("stack", &"")
		and int(left.get("index", -1)) == int(right.get("index", -1))
	)


func _valid_entry_target(entry_data: Dictionary, key: String) -> Variant:
	return _resolve_focus_token(entry_data.get(key))


func _valid_focus_target(target: Variant) -> bool:
	return _resolve_focus_token(target) != null


func _focus_token(target: Variant) -> Variant:
	if typeof(target) == TYPE_OBJECT:
		return weakref(target)
	return target


func _resolve_focus_token(token: Variant) -> Variant:
	if typeof(token) == TYPE_OBJECT and not is_instance_valid(token):
		return null
	var target: Variant = token
	if token is WeakRef:
		target = (token as WeakRef).get_ref()
	if target == null:
		return null
	if typeof(target) == TYPE_OBJECT:
		if not is_instance_valid(target):
			return null
		if target is Node and target.is_queued_for_deletion():
			return null
	return target
