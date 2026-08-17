class_name LoadoutChangeResult
extends RefCounted

const APPLIED: StringName = &"applied"
const ALREADY_EQUIPPED: StringName = &"already_equipped"
const NO_CHANGE: StringName = &"no_change"
const REQUIRES_REPLACEMENT: StringName = &"requires_replacement"
const INVALID: StringName = &"invalid"

var status: StringName = INVALID
var applied: bool = false
var component_id: StringName = &""
var target_slot: StringName = &""
var secondary_slot: StringName = &""
var displaced_component_id: StringName = &""
var focus_slot: StringName = &""
var replacement_slots: Array[StringName] = []
var errors: PackedStringArray = PackedStringArray()
var capacity_before: int = 0
var capacity_after: int = 0
var capacity_delta: int = 0
var snapshot: Dictionary = {}
var validation: LoadoutValidationResult


func needs_replacement() -> bool:
	return status == REQUIRES_REPLACEMENT


func is_noop() -> bool:
	return status == ALREADY_EQUIPPED or status == NO_CHANGE


func first_error() -> String:
	return "" if errors.is_empty() else errors[0]


func capacity_change_text() -> String:
	return "%d → %d Kapazität" % [capacity_before, capacity_after]

