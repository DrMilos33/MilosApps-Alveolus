class_name AbilityRuntime
extends RefCounted

signal cooldown_changed(remaining: float, total: float)
signal became_ready

var definition: AbilityDefinition
var cooldown_remaining: float = 0.0
var cooldown_total: float = 0.0

func _init(ability: AbilityDefinition = null) -> void:
	definition = ability

func is_ready() -> bool:
	return definition != null and cooldown_remaining <= 0.0

func start_cooldown(multiplier: float = 1.0) -> void:
	if definition == null:
		return
	cooldown_total = maxf(0.1, definition.cooldown * maxf(0.1, multiplier))
	cooldown_remaining = cooldown_total
	cooldown_changed.emit(cooldown_remaining, cooldown_total)

func tick(delta: float) -> void:
	if cooldown_remaining <= 0.0 or delta <= 0.0:
		return
	var was_active := cooldown_remaining > 0.0
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	cooldown_changed.emit(cooldown_remaining, cooldown_total)
	if was_active and cooldown_remaining <= 0.0:
		became_ready.emit()

func reduce(seconds: float) -> void:
	if seconds <= 0.0 or cooldown_remaining <= 0.0:
		return
	var was_active := cooldown_remaining > 0.0
	cooldown_remaining = maxf(0.0, cooldown_remaining - seconds)
	cooldown_changed.emit(cooldown_remaining, cooldown_total)
	if was_active and cooldown_remaining <= 0.0:
		became_ready.emit()

func scale_remaining(multiplier: float) -> void:
	if cooldown_remaining <= 0.0:
		return
	cooldown_remaining = maxf(0.0, cooldown_remaining * maxf(multiplier, 0.0))
	cooldown_changed.emit(cooldown_remaining, cooldown_total)
	if cooldown_remaining <= 0.0:
		became_ready.emit()

func reset() -> void:
	var was_active := cooldown_remaining > 0.0
	cooldown_remaining = 0.0
	cooldown_changed.emit(0.0, cooldown_total)
	if was_active:
		became_ready.emit()

func state() -> Dictionary:
	return {
		"id": definition.id if definition != null else &"",
		"ready": is_ready(),
		"remaining": cooldown_remaining,
		"total": cooldown_total if cooldown_total > 0.0 else (definition.cooldown if definition != null else 0.0),
	}

