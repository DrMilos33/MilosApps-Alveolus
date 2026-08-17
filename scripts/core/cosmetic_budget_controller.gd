class_name CosmeticBudgetController
extends Node

signal quality_changed(previous: Quality, current: Quality)

enum Quality {
	FULL,
	REDUCED,
	MINIMAL,
}

enum EffectPriority {
	DECORATIVE,
	COMBAT,
	CRITICAL,
}

const FULL_TO_REDUCED_FPS := 55.0
const REDUCED_TO_MINIMAL_FPS := 45.0
const RECOVERY_FPS := 58.0
const DEGRADE_SECONDS := 2.0
const RECOVER_SECONDS := 5.0

var quality: Quality = Quality.FULL
var automatic_enabled: bool = true
var auto_sample: bool = true
var observed_fps: float = 60.0

var _degrade_time: float = 0.0
var _recovery_time: float = 0.0

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(automatic: bool = true, automatically_sample: bool = true) -> CosmeticBudgetController:
	automatic_enabled = automatic
	auto_sample = automatically_sample
	set_process(auto_sample)
	return self

func _process(delta: float) -> void:
	if auto_sample and delta > 0.0:
		sample_observed_fps(1.0 / delta, delta)

func sample_observed_fps(fps: float, duration: float) -> Quality:
	observed_fps = maxf(fps, 0.0)
	if not automatic_enabled or duration <= 0.0:
		return quality
	var degrade_threshold := FULL_TO_REDUCED_FPS if quality == Quality.FULL else REDUCED_TO_MINIMAL_FPS
	if quality != Quality.MINIMAL and observed_fps < degrade_threshold:
		_degrade_time += duration
	else:
		_degrade_time = maxf(0.0, _degrade_time - duration * 0.5)
	if quality != Quality.FULL and observed_fps >= RECOVERY_FPS:
		_recovery_time += duration
	else:
		_recovery_time = maxf(0.0, _recovery_time - duration * 0.5)
	if _degrade_time + 0.000001 >= DEGRADE_SECONDS:
		_degrade_time = 0.0
		_recovery_time = 0.0
		set_quality(quality + 1)
	elif _recovery_time + 0.000001 >= RECOVER_SECONDS:
		_degrade_time = 0.0
		_recovery_time = 0.0
		set_quality(quality - 1)
	return quality

func set_quality(next: Quality) -> void:
	var resolved: Quality = clampi(int(next), int(Quality.FULL), int(Quality.MINIMAL))
	if resolved == quality:
		return
	var previous: Quality = quality
	quality = resolved
	quality_changed.emit(previous, quality)

func reset_quality() -> void:
	_degrade_time = 0.0
	_recovery_time = 0.0
	set_quality(Quality.FULL)

func quality_name() -> String:
	match quality:
		Quality.REDUCED:
			return "REDUCED"
		Quality.MINIMAL:
			return "MINIMAL"
	return "FULL"

func particle_multiplier(priority: EffectPriority = EffectPriority.DECORATIVE) -> float:
	if priority == EffectPriority.CRITICAL:
		return 1.0
	match quality:
		Quality.REDUCED:
			return 0.72 if priority == EffectPriority.COMBAT else 0.55
		Quality.MINIMAL:
			return 0.50 if priority == EffectPriority.COMBAT else 0.20
	return 1.0

func particle_count(base_count: int, priority: EffectPriority = EffectPriority.DECORATIVE) -> int:
	if base_count <= 0:
		return 0
	return maxi(1, roundi(float(base_count) * particle_multiplier(priority)))

func visual_limit(priority: EffectPriority = EffectPriority.DECORATIVE, full_limit: int = CombatCapacity.DEFAULT_FEEDBACK_VISUALS) -> int:
	if priority == EffectPriority.CRITICAL:
		return maxi(full_limit, 0)
	match quality:
		Quality.REDUCED:
			return roundi(float(full_limit) * (0.80 if priority == EffectPriority.COMBAT else 0.60))
		Quality.MINIMAL:
			return roundi(float(full_limit) * (0.60 if priority == EffectPriority.COMBAT else 0.25))
	return maxi(full_limit, 0)

func allows_effect(priority: EffectPriority, active_count: int, full_limit: int = CombatCapacity.DEFAULT_FEEDBACK_VISUALS) -> bool:
	return priority == EffectPriority.CRITICAL or active_count < visual_limit(priority, full_limit)

func pickup_trails_enabled() -> bool:
	return quality == Quality.FULL

func secondary_glow_enabled() -> bool:
	return quality != Quality.MINIMAL

func decorative_pulse_rate() -> float:
	match quality:
		Quality.REDUCED:
			return 0.5
		Quality.MINIMAL:
			return 0.0
	return 1.0
