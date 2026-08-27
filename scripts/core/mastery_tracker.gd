class_name MasteryTracker
extends RefCounted

var level_id: StringName = &""
var expected_boss_time: float = -1.0
var boss_spawned_at: float = -1.0
var boss_defeated_at: float = -1.0
var ability_uses: Dictionary = {0: 0, 1: 0}
var minimum_stability_ratio: float = 1.0
var final_stability_ratio: float = 1.0
var stability_observed: bool = false

func begin_run(case_level_id: StringName, boss_time: float = -1.0) -> void:
	level_id = case_level_id
	expected_boss_time = boss_time
	boss_spawned_at = -1.0
	boss_defeated_at = -1.0
	ability_uses = {0: 0, 1: 0}
	minimum_stability_ratio = 1.0
	final_stability_ratio = 1.0
	stability_observed = false

func record_boss_spawned(elapsed: float) -> void:
	if boss_spawned_at < 0.0:
		boss_spawned_at = maxf(0.0, elapsed)

func record_boss_defeated(elapsed: float) -> void:
	if boss_defeated_at < 0.0:
		boss_defeated_at = maxf(0.0, elapsed)

func record_ability_used(slot: int) -> void:
	if slot < 0 or slot > 1:
		return
	ability_uses[slot] = int(ability_uses.get(slot, 0)) + 1

func record_stability(current: float, maximum: float) -> void:
	if maximum <= 0.0:
		return
	stability_observed = true
	final_stability_ratio = clampf(current / maximum, 0.0, 1.0)
	minimum_stability_ratio = minf(minimum_stability_ratio, final_stability_ratio)

func completed_candidates(success: bool) -> Array[StringName]:
	var completed: Array[StringName] = []
	if not success:
		return completed
	for definition in MasteryObjectiveDefinition.definitions():
		if definition.level_id != level_id:
			continue
		if _condition_met(definition):
			completed.append(definition.id)
	return completed

func _condition_met(definition: MasteryObjectiveDefinition) -> bool:
	match definition.condition:
		&"victory":
			return true
		&"final_stability_ratio":
			return stability_observed and final_stability_ratio >= definition.threshold
		&"ability_uses_each":
			return int(ability_uses.get(0, 0)) >= int(definition.threshold) and int(ability_uses.get(1, 0)) >= int(definition.threshold)
		&"boss_defeat_window":
			return boss_spawned_at >= 0.0 and boss_defeated_at >= boss_spawned_at and boss_defeated_at - boss_spawned_at <= definition.threshold
		&"minimum_stability_ratio":
			return stability_observed and minimum_stability_ratio >= definition.threshold
	return false
