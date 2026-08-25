class_name PracticeScenarioDefinition
extends RefCounted

## Immutable practice-only run recipes.
##
## These definitions intentionally live outside the central content registry: local test
## runs neither unlock content nor participate in save/progression contracts.

enum RunType {
	SPAWN_TEST,
	OBSTACLE_TEST,
	BOSS_TEST,
	EVENT_TEST,
}

const SPAWN_TEST_ID := &"spawn_test"
const OBSTACLE_TEST_ID := &"obstacle_test"
const BOSS_TEST_ID := &"boss_test"

const SMALL_ENEMY_ID := &"pneumococcus"
const MEDIUM_ENEMY_ID := &"bacterial_cluster"
const SPAWN_BASELINE_CASE_ORDER := 6
const SPAWN_RAMP_SECONDS := 180.0
const SPAWN_RATE_MULTIPLIER := 1.10
const ONGOING_WEIGHTED_CAP := 145
const OBSTACLE_HEALTH_MULTIPLIER := 20.0


class ObstacleDefinition extends RefCounted:
	var _enemy_id: StringName
	var _visual_id: StringName
	var _position: Vector2
	var _health_multiplier: float
	var _movement_multiplier: float
	var _contact_damage_multiplier: float
	var _priority: int
	var _body_role: int
	var _obstacle_traversal: int


	func _init(
		enemy_id_value: StringName,
		visual_id_value: StringName,
		position_value: Vector2,
		health_multiplier_value: float,
		movement_multiplier_value: float,
		contact_damage_multiplier_value: float,
		priority_value: int,
		body_role_value: int,
		obstacle_traversal_value: int
	) -> void:
		_enemy_id = enemy_id_value
		_visual_id = visual_id_value
		_position = position_value
		_health_multiplier = maxf(health_multiplier_value, 0.001)
		_movement_multiplier = maxf(movement_multiplier_value, 0.0)
		_contact_damage_multiplier = maxf(contact_damage_multiplier_value, 0.0)
		_priority = priority_value
		_body_role = body_role_value
		_obstacle_traversal = obstacle_traversal_value


	func get_enemy_id() -> StringName:
		return _enemy_id


	func get_visual_id() -> StringName:
		return _visual_id


	func get_position() -> Vector2:
		return _position


	func get_health_multiplier() -> float:
		return _health_multiplier


	func get_movement_multiplier() -> float:
		return _movement_multiplier


	func get_contact_damage_multiplier() -> float:
		return _contact_damage_multiplier


	func get_priority() -> int:
		return _priority


	func get_body_role() -> int:
		return _body_role


	func get_obstacle_traversal() -> int:
		return _obstacle_traversal


	func duplicate_immutable() -> ObstacleDefinition:
		return ObstacleDefinition.new(
			_enemy_id,
			_visual_id,
			_position,
			_health_multiplier,
			_movement_multiplier,
			_contact_damage_multiplier,
			_priority,
			_body_role,
			_obstacle_traversal
		)


var _id: StringName
var _title: String
var _description: String
var _facts_text: String
var _run_type: int
var _small_enemy_id: StringName
var _medium_enemy_id: StringName
var _initial_small_count: int
var _initial_medium_count: int
var _ongoing_weighted_cap: int
var _endless: bool
var _spawn_baseline_case_order: int
var _spawn_ramp_seconds: float
var _spawn_rate_multiplier: float
var _waves_enabled: bool
var _requires_boss_profile: bool
var _obstacles: Array[ObstacleDefinition] = []
var _source_case_id: StringName = &""


func _init(
	id_value: StringName,
	title_value: String,
	description_value: String,
	facts_text_value: String,
	run_type_value: int,
	initial_small_count_value: int,
	initial_medium_count_value: int,
	ongoing_weighted_cap_value: int,
	endless_value: bool,
	spawn_baseline_case_order_value: int,
	spawn_ramp_seconds_value: float,
	spawn_rate_multiplier_value: float,
	waves_enabled_value: bool,
	requires_boss_profile_value: bool,
	obstacle_values: Array[ObstacleDefinition] = [],
	source_case_id_value: StringName = &""
) -> void:
	_id = id_value
	_title = title_value
	_description = description_value
	_facts_text = facts_text_value
	_run_type = run_type_value
	_small_enemy_id = SMALL_ENEMY_ID
	_medium_enemy_id = MEDIUM_ENEMY_ID
	_initial_small_count = maxi(0, initial_small_count_value)
	_initial_medium_count = maxi(0, initial_medium_count_value)
	_ongoing_weighted_cap = maxi(0, ongoing_weighted_cap_value)
	_endless = endless_value
	_spawn_baseline_case_order = maxi(0, spawn_baseline_case_order_value)
	_spawn_ramp_seconds = maxf(0.0, spawn_ramp_seconds_value)
	_spawn_rate_multiplier = maxf(0.0, spawn_rate_multiplier_value)
	_waves_enabled = waves_enabled_value
	_requires_boss_profile = requires_boss_profile_value
	_source_case_id = source_case_id_value
	for obstacle in obstacle_values:
		if obstacle != null:
			_obstacles.append(obstacle.duplicate_immutable())


func get_id() -> StringName:
	return _id


func get_title() -> String:
	return _title


func get_description() -> String:
	return _description


func get_facts_text() -> String:
	return _facts_text


func get_run_type() -> int:
	return _run_type


func get_small_enemy_id() -> StringName:
	return _small_enemy_id


func get_medium_enemy_id() -> StringName:
	return _medium_enemy_id


func get_initial_small_count() -> int:
	return _initial_small_count


func get_initial_medium_count() -> int:
	return _initial_medium_count


func get_ongoing_weighted_cap() -> int:
	return _ongoing_weighted_cap


func is_endless() -> bool:
	return _endless


func get_spawn_baseline_case_order() -> int:
	return _spawn_baseline_case_order


func get_spawn_ramp_seconds() -> float:
	return _spawn_ramp_seconds


func get_spawn_rate_multiplier() -> float:
	return _spawn_rate_multiplier


func are_waves_enabled() -> bool:
	return _waves_enabled


func requires_boss_profile() -> bool:
	return _requires_boss_profile


func get_source_case_id() -> StringName:
	return _source_case_id


func get_obstacles() -> Array[ObstacleDefinition]:
	var result: Array[ObstacleDefinition] = []
	for obstacle in _obstacles:
		result.append(obstacle.duplicate_immutable())
	return result


func get_obstacle_count() -> int:
	return _obstacles.size()


func get_obstacle_at(index: int) -> ObstacleDefinition:
	if index < 0 or index >= _obstacles.size():
		return null
	return _obstacles[index].duplicate_immutable()


func duplicate_immutable() -> PracticeScenarioDefinition:
	return PracticeScenarioDefinition.new(
		_id,
		_title,
		_description,
		_facts_text,
		_run_type,
		_initial_small_count,
		_initial_medium_count,
		_ongoing_weighted_cap,
		_endless,
		_spawn_baseline_case_order,
		_spawn_ramp_seconds,
		_spawn_rate_multiplier,
		_waves_enabled,
		_requires_boss_profile,
		_obstacles,
		_source_case_id
	)


static func catalog(level_definitions: Array[LevelDefinition] = []) -> Array[PracticeScenarioDefinition]:
	var result: Array[PracticeScenarioDefinition] = [
		PracticeScenarioDefinition.new(
			SPAWN_TEST_ID,
			"Spawn-Test",
			"Viele kleine und mittlere Gegner in freier Fläche",
			"12 klein · 6 mittel · endlos · Fall 6 × 1,10",
			RunType.SPAWN_TEST,
			12,
			6,
			ONGOING_WEIGHTED_CAP,
			true,
			SPAWN_BASELINE_CASE_ORDER,
			SPAWN_RAMP_SECONDS,
			SPAWN_RATE_MULTIPLIER,
			true,
			false
		),
		PracticeScenarioDefinition.new(
			OBSTACLE_TEST_ID,
			"Hindernis-Test",
			"Viele Gegner und drei feste Umlaufhindernisse",
			"8 klein · 4 mittel · 3 Hindernisse mit 20× Leben",
			RunType.OBSTACLE_TEST,
			8,
			4,
			ONGOING_WEIGHTED_CAP,
			true,
			SPAWN_BASELINE_CASE_ORDER,
			SPAWN_RAMP_SECONDS,
			SPAWN_RATE_MULTIPLIER,
			true,
			false,
			_obstacle_catalog()
		),
		PracticeScenarioDefinition.new(
			BOSS_TEST_ID,
			"Boss-Test",
			"Ein ausgewähltes Bossprofil ohne Begleitwellen",
			"Keine Wellen · Bossprofil separat wählen",
			RunType.BOSS_TEST,
			0,
			0,
			0,
			false,
			0,
			0.0,
			0.0,
			false,
			true
		),
	]
	var source_levels := ContentCatalog.level_definitions() if level_definitions.is_empty() else level_definitions
	for level in source_levels:
		if level == null or level.is_tutorial or level.case_pressure_plan == null or level.case_pressure_plan.target_focus_times.is_empty():
			continue
		result.append(PracticeScenarioDefinition.new(
			StringName("event_test:%s" % String(level.id)),
			"Event-Test · Fall %d" % level.order,
			"Aktuelles Eventmonster aus %s" % level.title,
			"1 Eventmonster · Originalprofil · keine Wellen",
			RunType.EVENT_TEST,
			0,
			0,
			0,
			false,
			level.order,
			0.0,
			0.0,
			false,
			false,
			[],
			level.id
		))
	return result


static func get_by_id(
	scenario_id: StringName,
	level_definitions: Array[LevelDefinition] = []
) -> PracticeScenarioDefinition:
	for scenario in catalog(level_definitions):
		if scenario.get_id() == scenario_id:
			return scenario
	return null


static func _obstacle_catalog() -> Array[ObstacleDefinition]:
	var result: Array[ObstacleDefinition] = []
	for position in [Vector2(-280.0, -140.0), Vector2(-280.0, 140.0), Vector2(260.0, 0.0)]:
		result.append(ObstacleDefinition.new(
			&"minor_focus",
			&"infection_focus",
			position,
			OBSTACLE_HEALTH_MULTIPLIER,
			0.0,
			0.0,
			EnemySpawnRequest.Priority.CRITICAL,
			EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE,
			EnemySpawnRequest.ObstacleTraversal.DEFAULT
		))
	return result
