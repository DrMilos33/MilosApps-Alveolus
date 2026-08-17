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
	_screens.append(_entry(screen_id, default_focus))
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
	current_focus: Variant = null
) -> bool:
	if modal_id == &"" or _screens.is_empty():
		return false
	if not _modals.is_empty() and current_modal_id() == modal_id:
		return false
	_remember_active_focus(current_focus)
	_modals.append(_entry(modal_id, default_focus))
	_emit_route_and_focus()
	return true


func close_modal(current_focus: Variant = null) -> bool:
	if _modals.is_empty():
		return false
	_remember_active_focus(current_focus)
	_modals.pop_back()
	_emit_route_and_focus()
	return true


func back(current_focus: Variant = null) -> bool:
	if not _modals.is_empty():
		return close_modal(current_focus)
	if _screens.size() <= 1:
		return false
	_remember_active_focus(current_focus)
	_screens.pop_back()
	_emit_route_and_focus()
	return true


func remember_focus(target: Variant) -> bool:
	if not _valid_focus_target(target) or (_screens.is_empty() and _modals.is_empty()):
		return false
	_remember_active_focus(target)
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


func is_input_owner(route_id: StringName) -> bool:
	return route_id != &"" and current_input_owner_id() == route_id


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
	}


func _entry(route_id: StringName, default_focus: Variant) -> Dictionary:
	return {
		"id": route_id,
		"default_focus": default_focus,
		"last_focus": null,
	}


func _remember_active_focus(target: Variant) -> void:
	if not _valid_focus_target(target):
		return
	if not _modals.is_empty():
		var modal_index := _modals.size() - 1
		var modal_entry: Dictionary = _modals[modal_index]
		modal_entry["last_focus"] = target
		_modals[modal_index] = modal_entry
		return
	if not _screens.is_empty():
		var screen_index := _screens.size() - 1
		var screen_entry: Dictionary = _screens[screen_index]
		screen_entry["last_focus"] = target
		_screens[screen_index] = screen_entry


func _emit_route_and_focus() -> void:
	route_changed.emit(current_screen_id(), current_modal_id())
	var target: Variant = _active_focus_target()
	last_focus_request = target
	if _valid_focus_target(target):
		focus_requested.emit(target)


func _active_focus_target() -> Variant:
	var entry_data: Dictionary
	if not _modals.is_empty():
		entry_data = _modals[_modals.size() - 1]
	elif not _screens.is_empty():
		entry_data = _screens[_screens.size() - 1]
	else:
		return null
	var previous: Variant = entry_data.get("last_focus")
	if _valid_focus_target(previous):
		return previous
	var fallback: Variant = entry_data.get("default_focus")
	return fallback if _valid_focus_target(fallback) else null


func _valid_focus_target(target: Variant) -> bool:
	if target == null:
		return false
	if target is Object:
		if not is_instance_valid(target):
			return false
		if target is Node and target.is_queued_for_deletion():
			return false
	return true
