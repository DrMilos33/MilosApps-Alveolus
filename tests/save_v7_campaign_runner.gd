extends SceneTree

var failures := 0
var assertions := 0


func _init() -> void:
	_test_catalog_contract()
	_test_v6_unlock_mapping()
	_test_v7_roundtrip_and_retired_income()
	if failures == 0:
		print("SAVE_V7_CAMPAIGN_OK assertions=%d" % assertions)
		quit(0)
	else:
		print("SAVE_V7_CAMPAIGN_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)


func _test_catalog_contract() -> void:
	var levels := ContentCatalog.level_definitions()
	_equal(levels.size(), 7, "Intro plus exakt sechs Kampagnenfälle")
	var expected_ids: Array[StringName] = [
		&"intro", &"early_localized_focus", &"localized_focus",
		&"advancing_infection", &"spreading_infection",
		&"critical_infection", &"severe_pneumonia",
	]
	for index in range(expected_ids.size()):
		_equal(levels[index].id, expected_ids[index], "Stabile ID an Katalogposition %d" % index)
		_equal(levels[index].order, index, "Lückenlose Reihenfolge %d" % index)
	_equal(_level_snapshot(levels[2]), {
		"boss_time": 300.0, "ramp": 300.0, "spawn": [1.03375, 0.23375], "health": [1.15, 1.70], "speed": 1.08,
		"contact": 1.25, "clusters": [0.10, 0.28], "boss_health": 1.0,
		"boss_speed": 1.0, "boss_id": &"localized_boss", "boss_ranged": true,
		"projectile": 1.0, "amplitude": 44.0, "adds": PackedInt32Array([3]),
		"reward": 1.0,
	}, "Fall-2-Anker bewahrt seine stabile Balance und ergänzt den neuen Projektilboss")
	_equal(_level_snapshot(levels[4]), {
		"boss_time": 300.0, "ramp": 300.0, "spawn": [0.780, 0.165], "health": [1.35, 2.05], "speed": 1.16,
		"contact": 1.45, "clusters": [0.18, 0.38], "boss_health": 0.75,
		"boss_speed": 1.35, "boss_id": &"infection_focus", "boss_ranged": true,
		"projectile": 2.5, "amplitude": 115.0, "adds": PackedInt32Array([4, 4]),
		"reward": 1.35,
	}, "Fall-4-Anker bleibt ein Golden Snapshot des bisherigen Falls 2")
	_equal(_level_snapshot(levels[6]), {
		"boss_time": 300.0, "ramp": 300.0, "spawn": [0.660, 0.135], "health": [1.55, 2.40], "speed": 1.24,
		"contact": 1.65, "clusters": [0.25, 0.48], "boss_health": 1.35,
		"boss_speed": 1.0, "boss_id": &"infection_focus", "boss_ranged": false,
		"projectile": 1.0, "amplitude": 44.0, "adds": PackedInt32Array([6, 8]),
		"reward": 1.70,
	}, "Fall-6-Anker bleibt ein Golden Snapshot des bisherigen Falls 3")
	_equal(levels[1].initial_small_enemy_count, 1, "Neuer Fall 1 startet mit einem Gegner")
	_true(levels[4].case_pressure_targets_stationary and levels[5].case_pressure_targets_stationary and levels[6].case_pressure_targets_stationary, "Späte Fälle markieren Zielherde datengetrieben stationär")
	_true(not levels[1].case_pressure_targets_stationary and not levels[2].case_pressure_targets_stationary and not levels[3].case_pressure_targets_stationary, "Frühe Zielherde bleiben beweglich")


func _test_v6_unlock_mapping() -> void:
	for old_order in range(4):
		var state := MetaProgressionState.new(func() -> int: return 123456)
		var data := _v6_fixture(old_order)
		_true(state.load_dict(data), "V6-Freischaltungsstand %d migriert" % old_order)
		_equal(state.highest_unlocked_level, old_order * 2, "V6-Anker %d wird auf neue Ordnung abgebildet" % old_order)
		_equal(
			LoadoutAvailabilityPolicy.first_case_complete(state),
			old_order >= 1,
			"V6-Anker %d bewahrt die abgeleitete Fall-1-Verfügbarkeit" % old_order
		)
		_equal(state.research_points, 321, "Beanspruchte Forschung bleibt erhalten")
		_equal(state.rank(&"therapy_precision"), 2, "Forschungsränge bleiben erhalten")
		_equal(state.get_level_record(&"localized_focus").victories, 1, "Stabile Levelrekorde bleiben erhalten")
		_equal(state.get_or_create_case_seed(&"localized_focus"), 424242, "Stabile Fallseeds bleiben erhalten")
		_equal(state.active_job_id, &"", "Nicht beanspruchte Klinikarbeit wird verworfen")
		_equal(state.claimable_research(), 0, "Nicht beanspruchte Offlinezeit wird verworfen")


func _test_v7_roundtrip_and_retired_income() -> void:
	var source := MetaProgressionState.new(func() -> int: return 400000)
	source.reset_defaults(400000)
	source.highest_unlocked_level = 5
	source.research_points = 77
	source.research_ranks[&"movement_training"] = 2
	source.level_case_seeds[&"critical_infection"] = 9191
	source.get_level_record(&"critical_infection").register_result(true, 170.0, 8, 88)
	var encoded := source.to_dict()
	_equal(int(encoded.get("version", 0)), 7, "Neue Spielstände schreiben Save v7")
	_true(not encoded.has("passive_seconds") and not encoded.has("active_job_id"), "V7 serialisiert keine Offline- oder Klinikwerte")
	var restored := MetaProgressionState.new(func() -> int: return 500000)
	_true(restored.load_dict(encoded), "V7-Roundtrip lädt")
	_equal(restored.highest_unlocked_level, 5, "V7-Reihenfolge bleibt unverändert")
	_equal(restored.get_or_create_case_seed(&"critical_infection"), 9191, "Neue Fallseeds überleben den Roundtrip")
	_equal(restored.get_level_record(&"critical_infection").best_defeats, 88, "Neue Fallrekorde überleben den Roundtrip")
	restored.accrue_time(999999)
	_equal(restored.claimable_research(), 0, "Zeitablauf erzeugt auch nach Roundtrip keine Forschung")


func _level_snapshot(level: LevelDefinition) -> Dictionary:
	return {
		"boss_time": level.boss_spawn_seconds,
		"ramp": level.spawn_ramp_seconds,
		"spawn": [level.initial_spawn_interval, level.final_spawn_interval],
		"health": [level.enemy_health_start, level.enemy_health_end],
		"speed": level.enemy_speed_multiplier,
		"contact": level.contact_damage_multiplier,
		"clusters": [level.cluster_chance_start, level.cluster_chance_end],
		"boss_health": level.boss_health_multiplier,
		"boss_speed": level.boss_speed_multiplier,
		"boss_id": level.boss_enemy_id,
		"boss_ranged": level.boss_ranged_enabled,
		"projectile": level.boss_projectile_damage_multiplier,
		"amplitude": level.boss_wave_amplitude,
		"adds": level.boss_phase_minions,
		"reward": level.reward_multiplier,
	}


func _v6_fixture(unlocked_order: int) -> Dictionary:
	return {
		"version": 6,
		"research_points": 321,
		"passive_seconds": 28800.0,
		"last_seen_unix": 100,
		"active_job_id": "short_review",
		"job_started_at": 100,
		"job_finishes_at": 999999,
		"research_ranks": {"therapy_precision": 2},
		"lifetime_runs": 9,
		"prologue_seen": true,
		"highest_unlocked_level": unlocked_order,
		"level_records": {"localized_focus": {"attempts": 1, "victories": 1, "best_time": 170.0}},
		"intro_skipped": false,
		"seen_discovery_ids": ["pneumococcus"],
		"tutorial_status": {},
		"show_run_stats": true,
		"talent_ranks": {},
		"bonus_talent_points": 0,
		"selected_talent_ids": [],
		"talent_tree_revision": MetaProgressionState.TALENT_TREE_REVISION,
		"talent_tree_refund_pending": false,
		"completed_mastery_ids": [],
		"prepared_loadouts": {},
		"level_case_seeds": {"localized_focus": 424242},
		"case_seed_nonce": 1,
		"ui_settings": {},
	}


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	print("FAIL: %s" % message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual == expected:
		return
	failures += 1
	print("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])
