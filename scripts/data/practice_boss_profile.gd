class_name PracticeBossProfile
extends RefCounted

## Immutable practice-only snapshot of one authored level boss.
## Profiles are derived from LevelDefinition instead of maintaining a second
## boss catalog, so later case additions and retunes appear automatically.

var _id: StringName
var _title: String
var _description: String
var _source_case_id: StringName
var _visual_id: StringName
var _source_config: RunConfig


func _init(
	source_level: LevelDefinition = null,
	boss_display_name: String = "",
	boss_visual_id: StringName = &""
) -> void:
	if source_level == null:
		return
	_source_case_id = source_level.id
	_id = StringName("practice_boss:%s" % String(source_level.id))
	var prefix := "Einführung" if source_level.is_tutorial else "Fall %d" % source_level.order
	var resolved_name := boss_display_name if not boss_display_name.is_empty() else String(source_level.boss_enemy_id).replace("_", " ").capitalize()
	_title = "%s · %s" % [prefix, resolved_name]
	_description = "Aktuelles Bossprofil aus %s." % source_level.title
	_visual_id = boss_visual_id if boss_visual_id != &"" else source_level.boss_enemy_id
	_source_config = RunConfig.from_level(source_level)


func get_id() -> StringName:
	return _id


func get_title() -> String:
	return _title


func get_description() -> String:
	return _description


func get_source_case_id() -> StringName:
	return _source_case_id


func get_enemy_id() -> StringName:
	return _source_config.boss_enemy_id if _source_config != null else &""


func get_visual_id() -> StringName:
	return _visual_id


func get_health_multiplier() -> float:
	return _source_config.boss_health_multiplier if _source_config != null else 1.0


func get_enemy_speed_multiplier() -> float:
	return _source_config.enemy_speed_multiplier if _source_config != null else 1.0


func get_boss_speed_multiplier() -> float:
	return _source_config.boss_speed_multiplier if _source_config != null else 1.0


func get_effective_speed_multiplier() -> float:
	return get_enemy_speed_multiplier() * get_boss_speed_multiplier()


func get_contact_damage_multiplier() -> float:
	return _source_config.contact_damage_multiplier if _source_config != null else 1.0


func is_ranged_enabled() -> bool:
	return _source_config != null and _source_config.boss_ranged_enabled


func get_projectile_damage_multiplier() -> float:
	return _source_config.boss_projectile_damage_multiplier if _source_config != null else 1.0


func get_wave_amplitude() -> float:
	return _source_config.boss_wave_amplitude if _source_config != null else 44.0


func get_phase_minions() -> PackedInt32Array:
	return _source_config.boss_phase_minions.duplicate() if _source_config != null else PackedInt32Array()


func get_boss_count() -> int:
	return _source_config.boss_count if _source_config != null else 1


func get_projectile_attack_speed_multiplier() -> float:
	return _source_config.boss_projectile_attack_speed_multiplier if _source_config != null else 1.0


func get_reinforcement_interval() -> float:
	return _source_config.boss_reinforcement_interval if _source_config != null else 0.0


func get_reinforcement_count() -> int:
	return _source_config.boss_reinforcement_count if _source_config != null else 0


func get_reinforcement_minimum_phase() -> int:
	return _source_config.boss_reinforcement_minimum_phase if _source_config != null else 0


func get_add_defense_burst_shooting_lock_seconds() -> float:
	return _source_config.boss_add_defense_burst_shooting_lock_seconds if _source_config != null else EnemyDefinition.DEFAULT_NON_BOSS_SHOOTING_LOCK_SECONDS


func get_projectile_speed_multiplier() -> float:
	return _source_config.boss_projectile_speed_multiplier if _source_config != null else 1.0


func get_projectile_turn_time_variation() -> float:
	return _source_config.boss_projectile_turn_time_variation if _source_config != null else 0.0


func get_phase_health_thresholds() -> PackedFloat32Array:
	return _source_config.boss_phase_health_thresholds.duplicate() if _source_config != null else PackedFloat32Array()


func apply_boss_contract(target: RunConfig) -> void:
	if target == null or _source_config == null:
		return
	target.boss_enemy_id = _source_config.boss_enemy_id
	target.boss_health_multiplier = _source_config.boss_health_multiplier
	target.enemy_speed_multiplier = _source_config.enemy_speed_multiplier
	target.boss_speed_multiplier = _source_config.boss_speed_multiplier
	target.contact_damage_multiplier = _source_config.contact_damage_multiplier
	target.boss_ranged_enabled = _source_config.boss_ranged_enabled
	target.boss_projectile_damage_multiplier = _source_config.boss_projectile_damage_multiplier
	target.boss_projectile_attack_speed_multiplier = _source_config.boss_projectile_attack_speed_multiplier
	target.boss_projectile_speed_multiplier = _source_config.boss_projectile_speed_multiplier
	target.boss_projectile_turn_time_variation = _source_config.boss_projectile_turn_time_variation
	target.boss_projectiles_require_empty_aura = _source_config.boss_projectiles_require_empty_aura
	target.boss_wave_amplitude = _source_config.boss_wave_amplitude
	target.boss_phase_minions = _source_config.boss_phase_minions.duplicate()
	target.boss_phase_health_thresholds = _source_config.boss_phase_health_thresholds.duplicate()
	target.boss_aura_screen_diameter_fraction = _source_config.boss_aura_screen_diameter_fraction
	target.boss_aura_speed_multiplier = _source_config.boss_aura_speed_multiplier
	target.boss_aura_damage_multiplier = _source_config.boss_aura_damage_multiplier
	target.boss_reinforcement_interval = _source_config.boss_reinforcement_interval
	target.boss_reinforcement_count = _source_config.boss_reinforcement_count
	target.boss_reinforcement_minimum_phase = _source_config.boss_reinforcement_minimum_phase
	target.boss_add_defense_burst_shooting_lock_seconds = _source_config.boss_add_defense_burst_shooting_lock_seconds
	target.boss_add_projectile_attack_speed_multiplier = _source_config.boss_add_projectile_attack_speed_multiplier
	target.boss_count = _source_config.boss_count


func duplicate_immutable() -> PracticeBossProfile:
	var copy := PracticeBossProfile.new()
	copy._id = _id
	copy._title = _title
	copy._description = _description
	copy._source_case_id = _source_case_id
	copy._visual_id = _visual_id
	copy._source_config = _source_config.duplicate(true) as RunConfig if _source_config != null else null
	return copy


static func catalog(
	level_definitions: Array[LevelDefinition] = [],
	enemy_catalog: Dictionary = {}
) -> Array[PracticeBossProfile]:
	var source_levels := ContentCatalog.level_definitions() if level_definitions.is_empty() else level_definitions
	var enemies := ContentCatalog.enemy_definitions() if enemy_catalog.is_empty() else enemy_catalog
	var result: Array[PracticeBossProfile] = []
	for level in source_levels:
		if level == null or not level.automatic_boss_enabled or level.boss_enemy_id == &"":
			continue
		var enemy := enemies.get(level.boss_enemy_id) as EnemyDefinition
		result.append(PracticeBossProfile.new(
			level,
			enemy.display_name if enemy != null else "",
			enemy.visual_id if enemy != null else level.boss_enemy_id
		))
	return result


static func get_by_id(
	profile_id: StringName,
	level_definitions: Array[LevelDefinition] = [],
	enemy_catalog: Dictionary = {}
) -> PracticeBossProfile:
	for profile in catalog(level_definitions, enemy_catalog):
		if profile.get_id() == profile_id:
			return profile
	return null
