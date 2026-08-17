class_name PlanningSnapshot
extends RefCounted

## UI-only state for the sequential deployment planner.
##
## Save data and stable content IDs remain in PreparedLoadout/LoadoutDraft. This
## object records only the currently visible editing step and focus return.

enum Mode {
	BROWSE,
	COMPONENT_PICK,
	REPLACE_CONFIRM,
	RESERVE_PICK,
}

var mode: Mode = Mode.BROWSE
var selected_slot_id: StringName = &""
var current_component_id: StringName = &""
var candidate_component_id: StringName = &""
var capacity_before: int = 0
var capacity_after: int = 0
var validation_message: String = ""
var focus_return_id: StringName = &""
var current_title: String = ""
var candidate_title: String = ""
var candidate_description: String = ""
var candidate_cost: int = 0


func browse(return_focus: StringName = &"") -> void:
	mode = Mode.BROWSE
	selected_slot_id = &""
	current_component_id = &""
	candidate_component_id = &""
	capacity_before = 0
	capacity_after = 0
	validation_message = ""
	focus_return_id = return_focus
	current_title = ""
	candidate_title = ""
	candidate_description = ""
	candidate_cost = 0


func begin_component_pick(slot_id: StringName, current_id: StringName) -> void:
	mode = Mode.COMPONENT_PICK
	selected_slot_id = slot_id
	current_component_id = current_id
	candidate_component_id = &""
	focus_return_id = slot_id
	candidate_title = ""
	candidate_description = ""
	candidate_cost = 0


func begin_reserve_pick(current_id: StringName) -> void:
	mode = Mode.RESERVE_PICK
	selected_slot_id = LoadoutSlotId.RESERVE
	current_component_id = current_id
	candidate_component_id = &""
	focus_return_id = LoadoutSlotId.RESERVE
	candidate_title = ""
	candidate_description = ""
	candidate_cost = 0


func begin_replace(
	slot_id: StringName,
	current_id: StringName,
	candidate_id: StringName,
	before: int,
	after: int,
	old_title: String,
	new_title: String,
	description: String,
	cost: int
) -> void:
	mode = Mode.REPLACE_CONFIRM
	selected_slot_id = slot_id
	current_component_id = current_id
	candidate_component_id = candidate_id
	capacity_before = before
	capacity_after = after
	focus_return_id = candidate_id
	current_title = old_title
	candidate_title = new_title
	candidate_description = description
	candidate_cost = cost


func capacity_change_text(limit: int) -> String:
	if capacity_before == capacity_after:
		return "Kapazität %d / %d · unverändert" % [capacity_before, limit]
	var sign_text := "+%d" % (capacity_after - capacity_before) if capacity_after > capacity_before else str(capacity_after - capacity_before)
	return "Kapazität %d / %d → %d / %d · %s" % [capacity_before, limit, capacity_after, limit, sign_text]
