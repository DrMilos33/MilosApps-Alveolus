class_name RunState
extends RefCounted

signal stability_changed(current: float, maximum: float)
signal analysis_changed(current: int, target: int, level: int)
signal level_up_requested(level: int)
signal boss_due
signal run_finished(success: bool, reason: String)

var config: RunConfig
var stability: float
var max_stability: float
var analysis: int = 0
var analysis_target: int = 5
var level: int = 0
var elapsed: float = 0.0
var active: bool = false
var level_up_pending: bool = false
var boss_spawned: bool = false
var boss_defeated: bool = false
var analysis_gain_multiplier: float = 1.0
var analysis_gain_carry: float = 0.0

func reset(run_config: RunConfig, initial_analysis: int = 0, stability_bonus: float = 0.0) -> void:
	config = run_config
	max_stability = config.initial_stability + maxf(0.0, stability_bonus)
	stability = max_stability
	analysis = maxi(0, initial_analysis)
	analysis_target = 5
	level = 0
	elapsed = 0.0
	active = true
	level_up_pending = false
	boss_spawned = false
	boss_defeated = false
	analysis_gain_carry = 0.0
	stability_changed.emit(stability, max_stability)
	analysis_changed.emit(analysis, analysis_target, level)

func tick(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	if config.event_driven_intro:
		return
	if not boss_spawned and elapsed >= config.run_duration_seconds:
		boss_spawned = true
		boss_due.emit()
	if config.has_deadline() and elapsed >= config.final_deadline_seconds and not boss_defeated:
		finish(false, "Die Behandlungszeit ist abgelaufen.")

func change_stability(amount: float) -> void:
	if not active:
		return
	stability = clampf(stability + amount, 0.0, max_stability)
	stability_changed.emit(stability, max_stability)
	if is_zero_approx(stability):
		finish(false, "Das Leben ist erschöpft.")

func increase_max_stability(amount: float) -> void:
	if amount <= 0.0:
		return
	max_stability += amount
	stability = minf(max_stability, stability + amount)
	stability_changed.emit(stability, max_stability)

func adjust_max_stability(amount: float, restore_added_capacity: bool = true) -> void:
	if is_zero_approx(amount):
		return
	var previous_maximum := max_stability
	max_stability = maxf(1.0, max_stability + amount)
	if amount > 0.0 and restore_added_capacity:
		stability = minf(max_stability, stability + (max_stability - previous_maximum))
	else:
		stability = minf(stability, max_stability)
	stability_changed.emit(stability, max_stability)

func add_analysis(amount: int) -> void:
	if not active or amount <= 0:
		return
	var scaled := float(amount) * maxf(analysis_gain_multiplier, 0.0) + analysis_gain_carry
	var awarded := floori(scaled + 0.000001)
	analysis_gain_carry = scaled - float(awarded)
	if awarded <= 0:
		return
	analysis += awarded
	analysis_changed.emit(analysis, analysis_target, level)
	_request_level_if_ready()

func set_analysis_gain_multiplier(value: float) -> void:
	analysis_gain_multiplier = maxf(value, 0.0)


func set_analysis_target(value: int) -> void:
	analysis_target = maxi(1, value)
	analysis_changed.emit(analysis, analysis_target, level)
	_request_level_if_ready()

func resolve_level_up() -> void:
	level_up_pending = false
	_request_level_if_ready()

func mark_boss_defeated() -> void:
	if not active:
		return
	boss_defeated = true
	finish(true, "Der Infektionsherd ist kontrolliert.")

func trigger_event_boss() -> void:
	if not active or boss_spawned:
		return
	boss_spawned = true
	boss_due.emit()

func finish(success: bool, reason: String) -> void:
	if not active:
		return
	active = false
	run_finished.emit(success, reason)

func cancel() -> void:
	active = false
	level_up_pending = false

func _request_level_if_ready() -> void:
	if level_up_pending or analysis < analysis_target:
		return
	analysis -= analysis_target
	level += 1
	analysis_target = int(round(6.0 + pow(float(level), 1.35) * 3.2))
	level_up_pending = true
	analysis_changed.emit(analysis, analysis_target, level)
	level_up_requested.emit(level)
