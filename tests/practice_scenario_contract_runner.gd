extends SceneTree

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var levels := ContentCatalog.level_definitions()
	var campaign_levels: Array[LevelDefinition] = []
	for level in levels:
		if not level.is_tutorial:
			campaign_levels.append(level)
	_check_base_scenarios(levels)
	_check_event_scenarios(levels, campaign_levels)
	_check_dynamic_boss_profiles(levels)
	_finish()


func _check_base_scenarios(levels: Array[LevelDefinition]) -> void:
	var scenarios := PracticeScenarioDefinition.catalog(levels)
	_check(scenarios.size() == 9, "Praxis enthält drei Basistests und sechs dynamische Eventtests")
	_check(scenarios[0].get_id() == &"spawn_test", "Spawn-Test bleibt erster Praxistest")
	_check(scenarios[1].get_id() == &"obstacle_test", "Hindernis-Test bleibt zweiter Praxistest")
	_check(scenarios[2].get_id() == &"boss_test", "Boss-Test bleibt dritter Praxistest")
	var spawn := PracticeScenarioDefinition.get_by_id(&"spawn_test", levels)
	_check(spawn != null and spawn.get_initial_small_count() == 12 and spawn.get_initial_medium_count() == 6, "Spawn-Test bewahrt seine Startfüllung")
	_check(spawn.are_waves_enabled() and spawn.is_endless() and spawn.get_ongoing_weighted_cap() == 145, "Spawn-Test bewahrt Wellen und Gewichtslimit")
	var obstacle := PracticeScenarioDefinition.get_by_id(&"obstacle_test", levels)
	_check(obstacle != null and obstacle.get_obstacle_count() == 3, "Hindernis-Test bewahrt drei Flusshindernisse")
	for index in range(obstacle.get_obstacle_count()):
		var definition := obstacle.get_obstacle_at(index)
		_check(definition.get_body_role() == EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE, "Praxishindernis %d bleibt ein stationäres Flusshindernis" % index)
		_check(is_equal_approx(definition.get_health_multiplier(), 20.0), "Praxishindernis %d bewahrt seine Lebensskalierung" % index)
	var boss := PracticeScenarioDefinition.get_by_id(&"boss_test", levels)
	_check(boss != null and boss.requires_boss_profile() and not boss.are_waves_enabled(), "Boss-Test verlangt ein Profil und deaktiviert Wellen")
	_check(PracticeScenarioDefinition.get_by_id(&"missing", levels) == null, "Unbekannte Praxisszenario-ID löst nicht auf")


func _check_event_scenarios(
	levels: Array[LevelDefinition],
	campaign_levels: Array[LevelDefinition]
) -> void:
	for level in campaign_levels:
		var scenario_id := StringName("event_test:%s" % String(level.id))
		var scenario := PracticeScenarioDefinition.get_by_id(scenario_id, levels)
		_check(scenario != null, "Fall %d besitzt einen Eventmonster-Praxistest" % level.order)
		if scenario == null:
			continue
		_check(scenario.get_run_type() == PracticeScenarioDefinition.RunType.EVENT_TEST, "Fall %d verwendet die Event-Test-Laufart" % level.order)
		_check(scenario.get_source_case_id() == level.id, "Fall %d Eventtest verweist auf den echten Quellfall" % level.order)
		_check(not scenario.are_waves_enabled() and not scenario.requires_boss_profile(), "Fall %d Eventtest isoliert das Eventmonster")
		_check(not scenario.get_title().is_empty() and scenario.get_facts_text().contains("Originalprofil"), "Fall %d Eventtest besitzt klare Präsentationsdaten" % level.order)


func _check_dynamic_boss_profiles(levels: Array[LevelDefinition]) -> void:
	var profiles := PracticeBossProfile.catalog(levels, ContentCatalog.enemy_definitions())
	_check(profiles.size() == levels.size() - 1, "Praxis leitet alle sechs Kampagnenfallbosse dynamisch ab")
	for level in levels:
		if level.is_tutorial:
			continue
		var profile_id := StringName("practice_boss:%s" % String(level.id))
		var profile := PracticeBossProfile.get_by_id(profile_id, levels, ContentCatalog.enemy_definitions())
		_check(profile != null, "Bossprofil wird aus %s abgeleitet" % level.id)
		if profile == null:
			continue
		_check(profile.get_source_case_id() == level.id and profile.get_enemy_id() == level.boss_enemy_id, "Bossprofil %s bewahrt Fall- und Gegner-ID" % level.id)
		_check(is_equal_approx(profile.get_health_multiplier(), level.boss_health_multiplier), "Bossprofil %s übernimmt das aktuelle Leben" % level.id)
		_check(is_equal_approx(profile.get_projectile_attack_speed_multiplier(), level.boss_projectile_attack_speed_multiplier), "Bossprofil %s übernimmt die aktuelle Schussrate" % level.id)
		_check(is_equal_approx(profile.get_projectile_speed_multiplier(), level.boss_projectile_speed_multiplier), "Bossprofil %s übernimmt das aktuelle Projektiltempo" % level.id)
		_check(is_equal_approx(profile.get_projectile_turn_time_variation(), level.boss_projectile_turn_time_variation), "Bossprofil %s übernimmt die aktuelle Richtungswechselvariation" % level.id)
		_check(profile.get_phase_minions() == level.boss_phase_minions, "Bossprofil %s übernimmt aktuelle Phasenadds" % level.id)
		var target := RunConfig.new()
		profile.apply_boss_contract(target)
		_check(is_equal_approx(target.boss_aura_screen_diameter_fraction, level.boss_aura_screen_diameter_fraction), "Bossprofil %s übernimmt den Auravertrag")
		_check(target.boss_projectiles_require_empty_aura == level.boss_projectiles_require_empty_aura, "Bossprofil %s übernimmt die Projektilbedingung")
		_check(is_equal_approx(target.boss_projectile_turn_time_variation, level.boss_projectile_turn_time_variation), "Bossprofil %s überträgt die Richtungswechselvariation in den Testlauf")
		_check(is_equal_approx(target.boss_add_projectile_attack_speed_multiplier, level.boss_add_projectile_attack_speed_multiplier), "Bossprofil %s übernimmt die Add-Schussrate")
		_check(profile.duplicate_immutable() != profile, "Bossprofil %s lässt sich isoliert duplizieren" % level.id)
	_check(PracticeBossProfile.get_by_id(&"missing", levels, ContentCatalog.enemy_definitions()) == null, "Unbekannte Bossprofil-ID löst nicht auf")


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_PRACTICE_SCENARIO_CONTRACT_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
