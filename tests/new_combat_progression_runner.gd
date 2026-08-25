extends SceneTree

var assertions := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_research_catalog_contract()
	_test_global_research_is_idempotent()
	_test_experience_fraction_is_carried()
	_test_ranked_talent_contract_and_reset()
	_test_defense_cells_use_geometry_and_per_cell_cooldowns()
	if failures == 0:
		print("ALVEOLUS_NEW_COMBAT_PROGRESSION_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_NEW_COMBAT_PROGRESSION_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)


func _test_research_catalog_contract() -> void:
	var expected_ids: Array[StringName] = [
		&"stability_reserve",
		&"therapy_precision",
		&"experience_gain",
		&"defense_training",
		&"life_regeneration",
		&"unlock_spread_treatment",
		&"unlock_piercing_treatment",
		&"movement_training",
		&"unlock_defense_burst",
		&"unlock_treatment_line",
	]
	var definitions := ContentCatalog.research_definitions()
	_equal(definitions.size(), expected_ids.size(), "Es gibt exakt zehn aktive Forschungen")
	var seen_ids: Dictionary = {}
	for index in range(definitions.size()):
		var definition: ResearchDefinition = definitions[index]
		var expected_id := expected_ids[index] if index < expected_ids.size() else &""
		_equal(definition.id, expected_id, "Die aktive Forschungsliste besitzt stabile IDs und Reihenfolge")
		_true(not seen_ids.has(definition.id), "Jede aktive Forschung kommt genau einmal vor")
		seen_ids[definition.id] = true

	var expected_effects := {
		&"stability_reserve": [&"max_health", 3.0, 3],
		&"therapy_precision": [&"damage_multiplier", 0.02, 3],
		&"experience_gain": [&"experience_multiplier", 0.05, 3],
		&"defense_training": [&"defense", 2.0, 3],
		&"life_regeneration": [&"life_regeneration", 0.25, 3],
		&"movement_training": [&"movement_speed_multiplier", 0.03, 3],
		&"unlock_spread_treatment": [&"unlock", 1.0, 1],
		&"unlock_piercing_treatment": [&"unlock", 1.0, 1],
		&"unlock_defense_burst": [&"unlock", 1.0, 1],
		&"unlock_treatment_line": [&"unlock", 1.0, 1],
	}
	for definition in definitions:
		_true(expected_effects.has(definition.id), "Jede aktive Forschungs-ID besitzt einen geprüften Effektvertrag")
		if not expected_effects.has(definition.id):
			continue
		var expectation: Array = expected_effects[definition.id]
		_equal(definition.effect, expectation[0], "Jede Forschung besitzt den vorgesehenen globalen Effekt")
		_near(definition.magnitude, float(expectation[1]), "Jede Forschung besitzt die vorgesehene Stärke")
		_equal(definition.max_level, int(expectation[2]), "Jede Forschung besitzt die vorgesehene Ranggrenze")

	var modules := ContentCatalog.loadout_module_definitions()
	for id in modules:
		var module: LoadoutModuleDefinition = modules[id]
		_true(module.kind != LoadoutModuleDefinition.Kind.PASSIVE, "Die Einsatzplanung enthält keine Passivmodule")


func _test_global_research_is_idempotent() -> void:
	var ranks := {
		&"stability_reserve": 3,
		&"therapy_precision": 3,
		&"experience_gain": 3,
		&"defense_training": 3,
		&"life_regeneration": 3,
		&"movement_training": 3,
	}
	var treatments := TreatmentDefinition.catalog()
	for treatment_id in [&"treatment_precision", &"treatment_spread", &"treatment_pierce"]:
		var treatment: TreatmentDefinition = treatments[treatment_id]
		var stats := PlayerStats.new()
		stats.configure_prepared_treatment(treatment)
		stats.apply_meta_progression(ranks)
		var expected_damage := float(roundi(treatment.base_damage * 1.06))
		_near(PlayerStats.BASE_MAX_HEALTH + stats.max_stability_bonus, 59.0, "Lebensforschung gilt global")
		_near(stats.therapy_damage, expected_damage, "Schadensforschung gilt für jede Grundbehandlung")
		_near(stats.experience_gain_multiplier, 1.15, "Erfahrungsforschung gilt global")
		_near(stats.defense, 6.0, "Defensivforschung gilt global")
		_near(stats.life_regeneration_per_second, 0.75, "Regenerationsforschung gilt global")
		_near(stats.movement_speed, 186.0, "Galoppforschung gilt global und bleibt ganzzahlig")

		stats.apply_meta_progression(ranks)
		_near(stats.therapy_damage, expected_damage, "Wiederholtes Anwenden vervielfacht den Grundschaden nicht")
		_near(stats.max_stability_bonus, 9.0, "Wiederholtes Anwenden vervielfacht Leben nicht")
		_near(stats.experience_gain_multiplier, 1.15, "Wiederholtes Anwenden vervielfacht Erfahrung nicht")
		_near(stats.defense, 6.0, "Wiederholtes Anwenden vervielfacht Defensive nicht")
		_near(stats.life_regeneration_per_second, 0.75, "Wiederholtes Anwenden vervielfacht Regeneration nicht")
		_near(stats.movement_speed, 186.0, "Wiederholtes Anwenden vervielfacht Galopp nicht")

		stats.apply_meta_progression({})
		_near(stats.therapy_damage, treatment.base_damage, "Ein Forschungsreset stellt den Behandlungsschaden wieder her")
		_near(stats.max_stability_bonus, 0.0, "Ein Forschungsreset stellt das Basisleben wieder her")
		_near(stats.experience_gain_multiplier, 1.0, "Ein Forschungsreset stellt den Erfahrungsfaktor wieder her")
		_near(stats.defense, PlayerStats.BASE_DEFENSE, "Ein Forschungsreset stellt die Basisdefensive wieder her")
		_near(stats.life_regeneration_per_second, PlayerStats.BASE_LIFE_REGENERATION, "Ein Forschungsreset stellt die Basisregeneration wieder her")
		_near(stats.movement_speed, PlayerStats.BASE_MOVEMENT_SPEED, "Ein Forschungsreset stellt die Basisbewegung wieder her")

	var default_stats := PlayerStats.new()
	default_stats.apply_meta_progression(ranks)
	var damage_after_first_apply := default_stats.therapy_damage
	default_stats.apply_meta_progression(ranks)
	_near(default_stats.therapy_damage, damage_after_first_apply, "Forschung bleibt auch vor einer expliziten Behandlungskonfiguration idempotent")


func _test_experience_fraction_is_carried() -> void:
	var stats := PlayerStats.new()
	stats.apply_meta_progression({&"experience_gain": 3})
	var state := RunState.new()
	state.active = true
	state.analysis_target = 1000
	state.set_analysis_gain_multiplier(stats.experience_gain_multiplier)
	state.add_analysis(1)
	_equal(state.analysis, 1, "Ein einzelner Probenpunkt bleibt ganzzahlig")
	_near(state.analysis_gain_carry, 0.15, "Der Bruchteil der Erfahrung wird aufgehoben")
	for _index in range(19):
		state.add_analysis(1)
	_equal(state.analysis, 23, "Zwanzig einzelne Proben verlieren bei +15 Prozent keinen Erfahrungsanteil")
	_near(state.analysis_gain_carry, 0.0, "Vollständig aufgelaufene Erfahrung hinterlässt keinen Rest")


func _test_ranked_talent_contract_and_reset() -> void:
	var expected_max_ranks := {
		&"treatment_damage_training": 1,
		&"manual_treatment_aim": 1,
		&"spread_shotgun": 1,
		&"piercing_persistence": 2,
	}
	var definitions := TalentDefinition.definitions()
	_equal(definitions.size(), expected_max_ranks.size(), "Der Behandlungstalentbaum enthält exakt vier Talente")
	_equal(TalentDefinition.total_cost(), 5, "Der vollständige Talentbaum kostet fünf Rangpunkte")
	for definition in definitions:
		_true(expected_max_ranks.has(definition.id), "Der Talentbaum enthält keine entfernten Talent-IDs")
		if not expected_max_ranks.has(definition.id):
			continue
		_equal(definition.max_rank, int(expected_max_ranks[definition.id]), "Jedes Talent besitzt seine vorgesehene Ranggrenze")

	var meta := MetaProgressionState.new(func() -> int: return 0)
	meta.reset_defaults(0)
	meta.set_unlimited_test_progression(true)
	_true(not meta.purchase_talent_rank(&"spread_shotgun"), "Das Schrotwirkungstalent kann seine Voraussetzung nicht überspringen")
	_true(meta.purchase_talent_rank(&"treatment_damage_training"), "Die Behandlungsgrundlage kann gekauft werden")
	_true(meta.purchase_talent_rank(&"manual_treatment_aim"), "Die manuelle Zielsteuerung kann unter der Grundlage gekauft werden")
	_true(meta.purchase_talent_rank(&"spread_shotgun"), "Schrotwirkung kann nach der Grundlage gekauft werden")
	_true(not meta.purchase_talent_rank(&"spread_shotgun"), "Schrotwirkung bleibt auf einen Rang gedeckelt")
	for _rank in range(2):
		_true(meta.purchase_talent_rank(&"piercing_persistence"), "Beide Laserdauerränge können gekauft werden")
	_true(not meta.purchase_talent_rank(&"piercing_persistence"), "Die Laserdauer bleibt bei zwei Rängen gedeckelt")
	_true(not TalentDefinition.catalog().has(&"piercing_return"), "Der rückkehrende Laser bleibt aus dem aktiven Katalog entfernt")
	_equal(meta.talent_points_spent(), 5, "Alle Talentränge werden einzeln berechnet")

	meta.clear_talents()
	_equal(meta.talent_points_spent(), 0, "Der Talentreset gibt alle Rangpunkte frei")
	_true(meta.talent_ranks.is_empty(), "Der Talentreset entfernt alle vier Talente")
	for talent_id in expected_max_ranks:
		_equal(meta.talent_rank(talent_id), 0, "Nach dem Reset besitzt kein Talent einen Rest-Rang")
	meta.clear_talents()
	_true(meta.talent_ranks.is_empty(), "Ein wiederholter Talentreset bleibt idempotent")


func _test_defense_cells_use_geometry_and_per_cell_cooldowns() -> void:
	var topology := ArenaTopology.new(Rect2(0.0, 0.0, 400.0, 400.0))
	var avatar := Node2D.new()
	avatar.global_position = Vector2(200.0, 200.0)
	get_root().add_child(avatar)
	var first := EntityHandle.make(0, 1)
	var second := EntityHandle.make(1, 1)
	var handles := PackedInt64Array([first, second])
	var positions := {
		first: Vector2(20.0, 20.0),
		second: Vector2(20.0, 20.0),
	}
	var query := CombatQuery.new().configure(
		topology,
		func(handle: int) -> Vector2: return positions.get(handle, Vector2.ZERO),
		func(_handle: int) -> float: return 2.0,
		func(_handle: int) -> bool: return true,
		Callable(),
		64.0,
		2.0
	)
	var world := DefenseCellWorld.new().configure(topology, avatar, query)
	world.configure_stats(2, 80.0, 6.0, 12.0, 0.01)
	_equal(world.count, 2, "Die Abwehrwelt übernimmt die echte Zellenzahl")
	_near(world.hit_interval, 0.1, "Das Trefferintervall wird auf mindestens 0,1 Sekunden begrenzt")
	_near(topology.distance(avatar.global_position, world.cell_position(0)), 80.0, "Die erste Zelle liegt auf ihrem echten Orbit")
	_near(topology.distance(world.cell_position(0), world.cell_position(1)), 160.0, "Zwei Zellen liegen geometrisch gegenüber")

	var hit_counts := {first: 0, second: 0}
	var hit_damages: Array[float] = []
	world.enemy_hit.connect(func(handle: int, damage: float) -> void:
		hit_counts[handle] = int(hit_counts.get(handle, 0)) + 1
		hit_damages.append(damage)
	)
	query.rebuild(handles)
	world.step_fixed(0.0)
	_equal(hit_damages.size(), 0, "Abwehrzellen treffen keine Gegner außerhalb ihrer Geometrie")

	positions[first] = _future_cell_position(world, avatar, topology, 0, 0.0)
	query.rebuild(handles)
	world.step_fixed(0.0)
	_equal(hit_counts[first], 1, "Eine echte Überlappung löst genau einen Treffer aus")
	_equal(hit_counts[second], 0, "Ein entfernter Gegner wird nicht als Nebeneffekt getroffen")
	_near(hit_damages[0] if not hit_damages.is_empty() else -1.0, 12.0, "Die Abwehrwelt meldet den konfigurierten Schaden")

	positions[second] = _future_cell_position(world, avatar, topology, 1, 0.0)
	query.rebuild(handles)
	world.step_fixed(0.0)
	_equal(hit_counts[first], 1, "Die erste Zelle respektiert ihren eigenen Cooldown")
	_equal(hit_counts[second], 1, "Eine zweite Zelle kann währenddessen unabhängig treffen")

	_place_handles_on_future_cells(world, avatar, topology, positions, first, second, 0.099)
	query.rebuild(handles)
	world.step_fixed(0.099)
	_equal(hit_damages.size(), 2, "Vor Ablauf von 0,1 Sekunden entsteht kein weiterer Treffer")
	_place_handles_on_future_cells(world, avatar, topology, positions, first, second, 0.0011)
	query.rebuild(handles)
	world.step_fixed(0.0011)
	_equal(hit_counts[first], 2, "Die erste Zelle darf nach 0,1 Sekunden erneut treffen")
	_equal(hit_counts[second], 2, "Die zweite Zelle besitzt denselben unabhängigen Cooldown")

	world.clear()
	world.configure_stats(1, CombatDistanceScale.world_from_stage(4), DefenseCellWorld.DEFAULT_HIT_RADIUS, 12.0, 0.1)
	var hits_before_radius_check := hit_damages.size()
	positions[first] = avatar.global_position
	positions[second] = Vector2(-200.0, -200.0)
	query.rebuild(handles)
	world.step_fixed(0.0)
	_equal(hit_damages.size(), hits_before_radius_check, "Ein Gegner innerhalb des Orbitradius, aber außerhalb der sichtbaren Zellhitbox, wird nicht getroffen")
	positions[first] = world.cell_position(0)
	query.rebuild(handles)
	world.step_fixed(0.0)
	_equal(hit_damages.size(), hits_before_radius_check + 1, "Ein Gegner an der sichtbaren Zelle wird innerhalb der kleinen festen Hitbox getroffen")
	_near(world.orbit_radius, 120.0, "Radiusstufe 4 steuert ausschließlich den Zellenorbit")
	_near(world.hit_radius, 15.0, "Die physische Zellenhitbox bleibt an der sichtbaren Zellgröße gekoppelt")
	avatar.free()


func _place_handles_on_future_cells(
	world: DefenseCellWorld,
	avatar: Node2D,
	topology: ArenaTopology,
	positions: Dictionary,
	first: int,
	second: int,
	delta: float
) -> void:
	positions[first] = _future_cell_position(world, avatar, topology, 0, delta)
	positions[second] = _future_cell_position(world, avatar, topology, 1, delta)


func _future_cell_position(
	world: DefenseCellWorld,
	avatar: Node2D,
	topology: ArenaTopology,
	index: int,
	delta: float
) -> Vector2:
	var next_angle := fmod(world.angle + maxf(delta, 0.0) * DefenseCellWorld.ORBIT_SPEED, TAU)
	var cell_angle := next_angle + TAU * float(posmod(index, world.count)) / float(world.count)
	return topology.wrap_position(avatar.global_position + Vector2.from_angle(cell_angle) * world.orbit_radius)


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual == expected:
		return
	failures += 1
	printerr("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	assertions += 1
	if absf(actual - expected) <= tolerance:
		return
	failures += 1
	printerr("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])
