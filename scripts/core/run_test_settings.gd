class_name RunTestSettings
extends RefCounted

## Mutable, test-only runtime values. Persistence and build availability stay
## outside this object so it can never become part of the regular save state.

signal changed
signal damage_immunity_changed(enabled: bool)
signal outgoing_damage_bonus_percent_changed(percent: int)
signal movement_speed_percent_changed(percent: int)
signal defaults_restored

const DEFAULT_DAMAGE_IMMUNITY := false
const DEFAULT_OUTGOING_DAMAGE_BONUS_PERCENT := 0
const DEFAULT_MOVEMENT_SPEED_PERCENT := 100

const OUTGOING_DAMAGE_BONUS_MIN := 0
const OUTGOING_DAMAGE_BONUS_MAX := 300
const OUTGOING_DAMAGE_BONUS_STEP := 10
const MOVEMENT_SPEED_MIN := 50
const MOVEMENT_SPEED_MAX := 200
const MOVEMENT_SPEED_STEP := 5

var _damage_immunity := DEFAULT_DAMAGE_IMMUNITY
var _outgoing_damage_bonus_percent := DEFAULT_OUTGOING_DAMAGE_BONUS_PERCENT
var _movement_speed_percent := DEFAULT_MOVEMENT_SPEED_PERCENT


func _init(
	damage_immunity_value: bool = DEFAULT_DAMAGE_IMMUNITY,
	outgoing_damage_bonus_percent_value: int = DEFAULT_OUTGOING_DAMAGE_BONUS_PERCENT,
	movement_speed_percent_value: int = DEFAULT_MOVEMENT_SPEED_PERCENT
) -> void:
	_damage_immunity = damage_immunity_value
	_outgoing_damage_bonus_percent = normalize_outgoing_damage_bonus_percent(
		outgoing_damage_bonus_percent_value
	)
	_movement_speed_percent = normalize_movement_speed_percent(movement_speed_percent_value)


func damage_immunity_enabled() -> bool:
	return _damage_immunity


func outgoing_damage_bonus_percent() -> int:
	return _outgoing_damage_bonus_percent


func movement_speed_percent() -> int:
	return _movement_speed_percent


func outgoing_damage_multiplier() -> float:
	return 1.0 + float(_outgoing_damage_bonus_percent) / 100.0


func movement_speed_multiplier() -> float:
	return float(_movement_speed_percent) / 100.0


func set_damage_immunity(enabled: bool) -> bool:
	if enabled == _damage_immunity:
		return false
	_damage_immunity = enabled
	damage_immunity_changed.emit(enabled)
	changed.emit()
	return true


func set_outgoing_damage_bonus_percent(percent: int) -> bool:
	var normalized := normalize_outgoing_damage_bonus_percent(percent)
	if normalized == _outgoing_damage_bonus_percent:
		return false
	_outgoing_damage_bonus_percent = normalized
	outgoing_damage_bonus_percent_changed.emit(normalized)
	changed.emit()
	return true


func set_movement_speed_percent(percent: int) -> bool:
	var normalized := normalize_movement_speed_percent(percent)
	if normalized == _movement_speed_percent:
		return false
	_movement_speed_percent = normalized
	movement_speed_percent_changed.emit(normalized)
	changed.emit()
	return true


func reset_defaults() -> bool:
	var immunity_changed := _damage_immunity != DEFAULT_DAMAGE_IMMUNITY
	var damage_changed := _outgoing_damage_bonus_percent != DEFAULT_OUTGOING_DAMAGE_BONUS_PERCENT
	var movement_changed := _movement_speed_percent != DEFAULT_MOVEMENT_SPEED_PERCENT
	if not immunity_changed and not damage_changed and not movement_changed:
		return false
	_damage_immunity = DEFAULT_DAMAGE_IMMUNITY
	_outgoing_damage_bonus_percent = DEFAULT_OUTGOING_DAMAGE_BONUS_PERCENT
	_movement_speed_percent = DEFAULT_MOVEMENT_SPEED_PERCENT
	if immunity_changed:
		damage_immunity_changed.emit(_damage_immunity)
	if damage_changed:
		outgoing_damage_bonus_percent_changed.emit(_outgoing_damage_bonus_percent)
	if movement_changed:
		movement_speed_percent_changed.emit(_movement_speed_percent)
	defaults_restored.emit()
	changed.emit()
	return true


func duplicate_settings() -> RunTestSettings:
	return RunTestSettings.new(
		_damage_immunity,
		_outgoing_damage_bonus_percent,
		_movement_speed_percent
	)


static func normalize_outgoing_damage_bonus_percent(percent: int) -> int:
	return clampi(
		snappedi(percent, OUTGOING_DAMAGE_BONUS_STEP),
		OUTGOING_DAMAGE_BONUS_MIN,
		OUTGOING_DAMAGE_BONUS_MAX
	)


static func normalize_movement_speed_percent(percent: int) -> int:
	return clampi(
		snappedi(percent, MOVEMENT_SPEED_STEP),
		MOVEMENT_SPEED_MIN,
		MOVEMENT_SPEED_MAX
	)
