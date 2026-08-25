class_name PracticeBossProfile
extends RefCounted

## Immutable, practice-only snapshot of one production boss configuration.
##
## The catalog deliberately does not depend on the central content registry. Its values are
## complete enough for the integration layer to build the existing boss spawn
## request without resolving a patient case or touching progression state.

const INTRO_BOSS_ID := &"intro_boss"
const BACTERIAL_CORE_ID := &"bacterial_core"
const DIAMOND_INFECTION_FOCUS_ID := &"diamond_infection_focus"
const STANDARD_INFECTION_FOCUS_ID := &"standard_infection_focus"

var _id: StringName
var _title: String
var _description: String
var _source_case_id: StringName
var _enemy_id: StringName
var _visual_id: StringName
var _health_multiplier: float
var _enemy_speed_multiplier: float
var _boss_speed_multiplier: float
var _contact_damage_multiplier: float
var _ranged_enabled: bool
var _projectile_damage_multiplier: float
var _wave_amplitude: float
var _phase_minions: PackedInt32Array
var _boss_count: int
var _projectile_attack_speed_multiplier: float
var _reinforcement_interval: float
var _reinforcement_count: int
var _reinforcement_minimum_phase: int
var _add_defense_burst_shooting_lock_seconds: float


func _init(
	id_value: StringName,
	title_value: String,
	description_value: String,
	source_case_id_value: StringName,
	enemy_id_value: StringName,
	visual_id_value: StringName,
	health_multiplier_value: float,
	enemy_speed_multiplier_value: float,
	boss_speed_multiplier_value: float,
	contact_damage_multiplier_value: float,
	ranged_enabled_value: bool,
	projectile_damage_multiplier_value: float,
	wave_amplitude_value: float,
	phase_minions_value: PackedInt32Array,
	boss_count_value: int = 1,
	projectile_attack_speed_multiplier_value: float = 1.0,
	reinforcement_interval_value: float = 0.0,
	reinforcement_count_value: int = 0,
	reinforcement_minimum_phase_value: int = 0,
	add_defense_burst_shooting_lock_seconds_value: float = EnemyDefinition.DEFAULT_NON_BOSS_SHOOTING_LOCK_SECONDS
) -> void:
	_id = id_value
	_title = title_value
	_description = description_value
	_source_case_id = source_case_id_value
	_enemy_id = enemy_id_value
	_visual_id = visual_id_value
	_health_multiplier = maxf(health_multiplier_value, 0.001)
	_enemy_speed_multiplier = maxf(enemy_speed_multiplier_value, 0.0)
	_boss_speed_multiplier = maxf(boss_speed_multiplier_value, 0.0)
	_contact_damage_multiplier = maxf(contact_damage_multiplier_value, 0.0)
	_ranged_enabled = ranged_enabled_value
	_projectile_damage_multiplier = maxf(projectile_damage_multiplier_value, 0.0)
	_wave_amplitude = maxf(wave_amplitude_value, 0.0)
	_phase_minions = phase_minions_value.duplicate()
	_boss_count = maxi(1, boss_count_value)
	_projectile_attack_speed_multiplier = maxf(projectile_attack_speed_multiplier_value, 0.01)
	_reinforcement_interval = maxf(reinforcement_interval_value, 0.0)
	_reinforcement_count = maxi(reinforcement_count_value, 0)
	_reinforcement_minimum_phase = clampi(reinforcement_minimum_phase_value, 0, 2)
	_add_defense_burst_shooting_lock_seconds = add_defense_burst_shooting_lock_seconds_value


func get_id() -> StringName:
	return _id


func get_title() -> String:
	return _title


func get_description() -> String:
	return _description


func get_source_case_id() -> StringName:
	return _source_case_id


func get_enemy_id() -> StringName:
	return _enemy_id


func get_visual_id() -> StringName:
	return _visual_id


func get_health_multiplier() -> float:
	return _health_multiplier


func get_enemy_speed_multiplier() -> float:
	return _enemy_speed_multiplier


func get_boss_speed_multiplier() -> float:
	return _boss_speed_multiplier


func get_effective_speed_multiplier() -> float:
	return _enemy_speed_multiplier * _boss_speed_multiplier


func get_contact_damage_multiplier() -> float:
	return _contact_damage_multiplier


func is_ranged_enabled() -> bool:
	return _ranged_enabled


func get_projectile_damage_multiplier() -> float:
	return _projectile_damage_multiplier


func get_wave_amplitude() -> float:
	return _wave_amplitude


func get_phase_minions() -> PackedInt32Array:
	return _phase_minions.duplicate()


func get_boss_count() -> int:
	return _boss_count


func get_projectile_attack_speed_multiplier() -> float:
	return _projectile_attack_speed_multiplier


func get_reinforcement_interval() -> float:
	return _reinforcement_interval


func get_reinforcement_count() -> int:
	return _reinforcement_count


func get_reinforcement_minimum_phase() -> int:
	return _reinforcement_minimum_phase


func get_add_defense_burst_shooting_lock_seconds() -> float:
	return _add_defense_burst_shooting_lock_seconds


func duplicate_immutable() -> PracticeBossProfile:
	return PracticeBossProfile.new(
		_id,
		_title,
		_description,
		_source_case_id,
		_enemy_id,
		_visual_id,
		_health_multiplier,
		_enemy_speed_multiplier,
		_boss_speed_multiplier,
		_contact_damage_multiplier,
		_ranged_enabled,
		_projectile_damage_multiplier,
		_wave_amplitude,
		_phase_minions,
		_boss_count,
		_projectile_attack_speed_multiplier,
		_reinforcement_interval,
		_reinforcement_count,
		_reinforcement_minimum_phase,
		_add_defense_burst_shooting_lock_seconds
	)


static func catalog() -> Array[PracticeBossProfile]:
	return [
		PracticeBossProfile.new(
			INTRO_BOSS_ID,
			"Intro-Boss",
			"Kleiner Intro-Infektionsherd mit Fernangriff",
			&"intro",
			&"intro_focus",
			&"infection_focus",
			0.09,
			0.80,
			1.0,
			0.50,
			true,
			1.0,
			44.0,
			PackedInt32Array()
		),
		PracticeBossProfile.new(
			BACTERIAL_CORE_ID,
			"Bakterienkern",
			"Fernkampf-Boss mit Doppelkurven und regelmäßiger Verstärkung",
			&"localized_focus",
			&"localized_boss",
			&"infection_focus",
			1.0,
			1.08,
			1.0,
			1.25,
			true,
			1.0,
			44.0,
			PackedInt32Array([3]),
			1,
			1.8,
			15.0,
			4,
			0,
			-1.0
		),
		PracticeBossProfile.new(
			DIAMOND_INFECTION_FOCUS_ID,
			"Infektionsherd · Raute",
			"Schneller Fernkampf-Boss mit zwei Vierer-Phasen",
			&"spreading_infection",
			&"infection_focus",
			&"infection_focus",
			0.75,
			1.16,
			1.35,
			1.45,
			true,
			2.5,
			115.0,
			PackedInt32Array([4, 4])
		),
		PracticeBossProfile.new(
			STANDARD_INFECTION_FOCUS_ID,
			"Infektionsherd · Standard",
			"Robuster Nahkampf-Boss mit Sechser- und Achter-Phase",
			&"severe_pneumonia",
			&"infection_focus",
			&"infection_focus",
			1.35,
			1.24,
			1.0,
			1.65,
			false,
			1.0,
			44.0,
			PackedInt32Array([6, 8])
		),
	]


static func get_by_id(profile_id: StringName) -> PracticeBossProfile:
	for profile in catalog():
		if profile.get_id() == profile_id:
			return profile
	return null
