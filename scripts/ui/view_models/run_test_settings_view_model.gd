class_name RunTestSettingsViewModel
extends RefCounted

## Immutable UI boundary for optional test controls. The explicit availability
## flag is supplied by the integrator; UI code never infers debug/release state.

const OUTGOING_DAMAGE_BONUS_MIN := 0
const OUTGOING_DAMAGE_BONUS_MAX := 300
const OUTGOING_DAMAGE_BONUS_STEP := 10
const MOVEMENT_SPEED_MIN := 50
const MOVEMENT_SPEED_MAX := 200
const MOVEMENT_SPEED_STEP := 5

var _available: bool
var _damage_immunity: bool
var _outgoing_damage_bonus_percent: int
var _movement_speed_percent: int


func _init(
	available_value: bool = false,
	damage_immunity_value: bool = false,
	outgoing_damage_bonus_percent_value: int = 0,
	movement_speed_percent_value: int = 100
) -> void:
	_available = available_value
	_damage_immunity = damage_immunity_value
	_outgoing_damage_bonus_percent = clampi(
		snappedi(outgoing_damage_bonus_percent_value, OUTGOING_DAMAGE_BONUS_STEP),
		OUTGOING_DAMAGE_BONUS_MIN,
		OUTGOING_DAMAGE_BONUS_MAX
	)
	_movement_speed_percent = clampi(
		snappedi(movement_speed_percent_value, MOVEMENT_SPEED_STEP),
		MOVEMENT_SPEED_MIN,
		MOVEMENT_SPEED_MAX
	)


func is_available() -> bool:
	return _available


func damage_immunity_enabled() -> bool:
	return _damage_immunity


func outgoing_damage_bonus_percent() -> int:
	return _outgoing_damage_bonus_percent


func movement_speed_percent() -> int:
	return _movement_speed_percent


func duplicate_immutable() -> RunTestSettingsViewModel:
	return RunTestSettingsViewModel.new(
		_available,
		_damage_immunity,
		_outgoing_damage_bonus_percent,
		_movement_speed_percent
	)


func append_signature(parts: PackedStringArray) -> void:
	parts.append("1" if _available else "0")
	if not _available:
		return
	parts.append("1" if _damage_immunity else "0")
	parts.append(str(_outgoing_damage_bonus_percent))
	parts.append(str(_movement_speed_percent))
