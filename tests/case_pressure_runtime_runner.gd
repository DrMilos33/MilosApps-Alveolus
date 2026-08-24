extends SceneTree

## Runtime contract for the authored case-pressure layer. The test exercises
## the real Game helpers but keeps physics paused so no ambient wave or input
## timing can affect the deterministic target and gate slices.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const GameScript := preload("res://scripts/game.gd")

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_static_pressure_limits()
	_test_pure_salvo_and_gate_seams()
	await _test_live_target_and_gate_contract()
	await _test_case_one_event_target_profile()
	await _test_case_two_target_remains_mobile()
	_finish()


func _test_static_pressure_limits() -> void:
	_equal(GameScript.CASE_PRESSURE_TARGET_ACTIVE_SECONDS, 20.0, "Zielherde bleiben zwanzig Sekunden aktiv")
	_equal(GameScript.CASE_PRESSURE_WARNING_SECONDS, 1.5, "Zielherde und Tore verwenden die 1,5-Sekunden-Warnung")
	_equal(GameScript.CASE_PRESSURE_FAN_ANGLES.size(), 5, "Eine Zielherdsalve besitzt exakt fünf Projektile")
	_equal(GameScript.CASE_PRESSURE_GATE_SPACING, 52.0, "Projektiltore behalten höchstens 52 Weltpunkte Reihenabstand")
	_equal(GameScript.CASE_PRESSURE_GATE_SAFE_GAP, 156.0, "Projektiltore behalten die sichere Lücke von mindestens 156 Weltpunkten")
	_equal(GameScript.CASE_PRESSURE_GATE_MAX_PROJECTILES, 24, "Ein Projektiltor bleibt auf 24 Projektile begrenzt")
	_equal(GameScript.PRESSURE_PROJECTILE_RESERVE, 48, "Falldruck reserviert 48 Projektilplätze")
	_equal(
		GameScript.REGULAR_PROJECTILE_LIMIT + GameScript.PRESSURE_PROJECTILE_RESERVE,
		GameScript.MAX_ACTIVE_PROJECTILES,
		"Reguläre Projektilgrenze und Falldruckreserve teilen die Gesamtkapazität exakt auf"
	)
	var levels := ContentCatalog.level_definitions()
	var order_five := _level_by_id(levels, &"critical_infection")
	var order_six := _level_by_id(levels, &"severe_pneumonia")
	_true(order_five != null and order_five.order == 5 and order_five.case_pressure_targets_stationary, "Fall 5 aktiviert stationäre Druckziele absichtlich")
	_true(order_six != null and order_six.order == 6 and order_six.case_pressure_targets_stationary, "Fall 6 aktiviert stationäre Druckziele absichtlich")
	_equal(order_five.case_pressure_plan.projectile_gate_times.size(), 2, "Fall 5 besitzt genau zwei projektierte Tore")
	_equal(order_six.case_pressure_plan.projectile_gate_times.size(), 3, "Fall 6 besitzt genau drei projektierte Tore")


func _test_pure_salvo_and_gate_seams() -> void:
	var pure_game := GameScript.new()
	_equal(pure_game._case_pressure_salvo_quota(100.0, 100.0), 4, "Volle Restgesundheit erhält vier Salven")
	_equal(pure_game._case_pressure_salvo_quota(75.0, 100.0), 3, "Drei verbleibende Viertel erhalten drei Salven")
	_equal(pure_game._case_pressure_salvo_quota(50.0, 100.0), 2, "Halbe Restgesundheit erhält zwei Salven")
	_equal(pure_game._case_pressure_salvo_quota(25.0, 100.0), 1, "Ein verbleibendes Viertel erhält eine Salve")
	_equal(pure_game._case_pressure_salvo_quota(0.0, 100.0), 0, "Ein leerer Herd erhält keine Salve")
	_equal(pure_game._case_pressure_salvo_quota(10.0, 0.0), 0, "Ungültige Maximalgesundheit erzeugt keine Salve")

	var lanes := pure_game._case_pressure_gate_lane_coordinates(-186.0, 186.0, 0.0)
	_true(not lanes.is_empty(), "Der reine Gate-Seam liefert Bahnen")
	_true(lanes.size() <= GameScript.CASE_PRESSURE_GATE_MAX_PROJECTILES, "Der reine Gate-Seam begrenzt auf 24 Projektile")
	var lower_lane := -INF
	var upper_lane := INF
	for lane in lanes:
		if lane <= 0.0:
			lower_lane = maxf(lower_lane, lane)
		else:
			upper_lane = minf(upper_lane, lane)
	_true(upper_lane - lower_lane >= GameScript.CASE_PRESSURE_GATE_SAFE_GAP, "Der reine Gate-Seam hält die sichere Lücke ein")
	var capped_lanes := pure_game._case_pressure_gate_lane_coordinates(-2000.0, 2000.0, 0.0)
	_equal(capped_lanes.size(), GameScript.CASE_PRESSURE_GATE_MAX_PROJECTILES, "Breite Tore werden deterministisch auf 24 Bahnen gekürzt")
	pure_game.free()


func _test_live_target_and_gate_contract() -> void:
	var game := MAIN_SCENE.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	game.persistence_enabled = false
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game.selected_level = _level_by_id(game.levels, &"severe_pneumonia")
	_true(game.selected_level != null and game.selected_level.order == 6, "Live-Drucktest verwendet den erhaltenen Order-6-Anker")
	game.start_run()
	game.set_physics_process(false)

	_spawn_and_assert_gate(game)
	_spawn_and_assert_target(game)
	_assert_intro_and_boss_exclusion(game)

	game.queue_free()
	await process_frame


func _test_case_two_target_remains_mobile() -> void:
	var game := MAIN_SCENE.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.persistence_enabled = false
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game.selected_level = _level_by_id(game.levels, &"localized_focus")
	_true(game.selected_level != null and game.selected_level.order == 2, "Mobiler Druckzieltest verwendet den erhaltenen Order-2-Anker")
	game.start_run()
	game.set_physics_process(false)
	game._spawn_case_pressure_target({&"spawn_sector": 2})
	_equal(game.case_pressure_target_states.size(), 1, "Fall 2 erzeugt genau einen beweglichen kleinen Herd")
	if not game.case_pressure_target_states.is_empty():
		var handle := int(game.case_pressure_target_states.keys()[0])
		var target := game.enemy_world.resolve(handle) as InfectionEnemy
		_true(is_instance_valid(target), "Der Fall-2-Herd besitzt einen gültigen Handle")
		if is_instance_valid(target):
			var runtime: Dictionary = game.case_pressure_target_states[handle]
			_equal(StringName(runtime.get(&"behavior", &"")), &"ambient_focus", "Fall 2 behält den beweglichen Herdvertrag")
			_true(not target.is_static_flow_obstacle(), "Der kleine Fall-2-Herd wird kein stationäres Hindernis")
			_equal(target.body_role, EnemySpawnRequest.BodyRole.MOBILE, "Fall 2 behält die normale mobile Körperrolle")
			_true(target.speed_multiplier > 0.0, "Der Fall-2-Herd behält seine normale Bewegung")
			_near(target.projectile_attack_speed_multiplier, 1.0, "Der Fall-2-Herd übernimmt nicht die schnellere Fall-1-Kadenz")
			_near(target.projectile_width_multiplier, 1.0, "Der Fall-2-Herd übernimmt nicht die breiteren Fall-1-Projektile")
			_equal(game.enemy_attack_director.role_for(handle), EnemyAttackDirector.Role.MINOR_FOCUS, "Der bewegliche Fall-2-Herd schießt unverändert")
	game.queue_free()
	await process_frame


func _test_case_one_event_target_profile() -> void:
	var game := MAIN_SCENE.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.persistence_enabled = false
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game.selected_level = _level_by_id(game.levels, &"early_localized_focus")
	_true(game.selected_level != null and game.selected_level.order == 1, "Eventherdtest verwendet Fall 1")
	game.start_run()
	game.set_physics_process(false)
	game._spawn_case_pressure_target({&"spawn_sector": 3})
	_equal(game.case_pressure_target_states.size(), 1, "Fall 1 erzeugt genau einen mobilen Eventherd")
	if not game.case_pressure_target_states.is_empty():
		var handle := int(game.case_pressure_target_states.keys()[0])
		var target := game.enemy_world.resolve(handle) as InfectionEnemy
		_true(is_instance_valid(target), "Der Fall-1-Eventherd besitzt einen gültigen Handle")
		if is_instance_valid(target):
			_near(
				target.definition.speed * target.speed_multiplier,
				46.0 * game.config.enemy_speed_multiplier,
				"Der Fall-1-Eventherd besitzt nach diesem Patch ganzzahliges Basistempo 46"
			)
			_near(target.projectile_attack_speed_multiplier, 1.25, "Der Fall-1-Eventherd schießt 25 Prozent schneller")
			_near(target.resolved_projectile_interval(), 2.08, "25 Prozent mehr Schussrate ergeben linear 2,08 Sekunden Intervall")
			_near(target.projectile_width_multiplier, 1.5, "Der Fall-1-Eventherd veröffentlicht 50 Prozent breitere Projektile")
			target.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
			var projectiles_before: int = game.projectiles.size()
			game.enemy_attack_director.step_fixed(0.899)
			_equal(game.projectiles.size(), projectiles_before, "Der unveränderte erste Telegraph feuert nicht vor 0,9 Sekunden")
			game.enemy_attack_director.step_fixed(0.002)
			_equal(game.projectiles.size(), projectiles_before + 1, "Nach dem ersten Telegraphen entsteht genau ein Eventherdprojektil")
			if game.projectiles.size() > projectiles_before:
				var projectile := game.projectiles[-1] as TherapyProjectile
				_near(projectile.hostile_width_multiplier, 1.5, "Das echte Eventherdprojektil übernimmt die breitere Darstellung und Trefferfläche")
			game.enemy_attack_director.step_fixed(2.078)
			_equal(game.projectiles.size(), projectiles_before + 1, "Die lineare Kadenz feuert nicht vor Ablauf von 2,08 Sekunden erneut")
			game.enemy_attack_director.step_fixed(0.002)
			_equal(game.projectiles.size(), projectiles_before + 2, "Der Eventherd feuert nach 2,08 Sekunden erneut")
	game.queue_free()
	await process_frame


func _spawn_and_assert_gate(game) -> void:
	var gate_id := 91
	var safe_position := Vector2.ZERO
	game._spawn_case_pressure_gate({
		&"gate_id": gate_id,
		&"orientation": 0,
		&"positive_direction": true,
		&"visible_rect": Rect2(-200.0, -160.0, 400.0, 320.0),
		&"safe_position": safe_position,
	})

	var gate_projectiles: Array = []
	var lanes: Array[float] = []
	for projectile in game.projectiles:
		if int(game.pressure_gate_id_by_projectile.get(projectile, -1)) != gate_id:
			continue
		gate_projectiles.append(projectile)
		lanes.append(projectile.global_position.y)
	_true(not gate_projectiles.is_empty(), "Ein Fall-6-Tor erzeugt echte feindliche Projektile")
	_true(gate_projectiles.size() <= GameScript.CASE_PRESSURE_GATE_MAX_PROJECTILES, "Das echte Tor überschreitet den 24-Projektildeckel nicht")
	_equal(int(game.pressure_gate_projectile_counts.get(gate_id, 0)), gate_projectiles.size(), "Gate-Telemetrie zählt alle erzeugten Reihenprojektile")

	lanes.sort()
	for index in range(1, lanes.size()):
		if lanes[index - 1] <= safe_position.y and lanes[index] > safe_position.y:
			continue
		_true(lanes[index] - lanes[index - 1] <= GameScript.CASE_PRESSURE_GATE_SPACING + 0.001, "Benachbarte Torbahnen bleiben höchstens 52 Weltpunkte entfernt")
	var lower_lane := -INF
	var upper_lane := INF
	for lane in lanes:
		if lane <= safe_position.y:
			lower_lane = maxf(lower_lane, lane)
		else:
			upper_lane = minf(upper_lane, lane)
	_true(upper_lane - lower_lane >= GameScript.CASE_PRESSURE_GATE_SAFE_GAP, "Die reale Torlücke bleibt mindestens 156 Weltpunkte breit")

	var profile := (game.enemy_definitions[&"minor_focus"] as EnemyDefinition).damage_profile
	var stability_before: float = float(game.state.stability)
	game._on_hostile_projectile_hit(gate_projectiles[0], GameScript.CASE_PRESSURE_PROJECTILE_DAMAGE, profile)
	var stability_after_first_hit: float = float(game.state.stability)
	_true(stability_after_first_hit < stability_before, "Der erste Treffer eines Tores verursacht Schaden")
	game.pressure_grace_timer = 0.0
	game._on_hostile_projectile_hit(gate_projectiles[-1], GameScript.CASE_PRESSURE_PROJECTILE_DAMAGE, profile)
	_equal(game.state.stability, stability_after_first_hit, "Ein Tor kann trotz zurückgesetzter Schadenspause nur einmal treffen")


func _spawn_and_assert_target(game) -> void:
	game._spawn_case_pressure_target({&"spawn_sector": 4})
	_equal(game.case_pressure_target_states.size(), 1, "Der Falldruck erzeugt genau einen Zielherd")
	var handle := int(game.case_pressure_target_states.keys()[0])
	var target := game.enemy_world.resolve(handle) as InfectionEnemy
	_true(is_instance_valid(target), "Der Zielherd besitzt einen auflösbaren EnemyWorld-Handle")
	if not is_instance_valid(target):
		return
	var runtime: Dictionary = game.case_pressure_target_states[handle]
	_equal(target.definition.id, &"minor_focus", "Der Falldruck verwendet den kleinen Herd als Ziel")
	_equal(StringName(runtime.get(&"behavior", &"")), &"stationary_fan", "Fall 6 markiert den Zielherd als stationären Fächer")
	_equal(StringName(runtime.get(&"phase", &"")), &"active", "Der Zielherd beginnt in der aktiven Lebensphase")
	_equal(float(runtime.get(&"remaining", 0.0)), GameScript.CASE_PRESSURE_TARGET_ACTIVE_SECONDS, "Der Zielherd erhält seine vollen 20 Sekunden")
	_equal(int(runtime.get(&"reward_points", 0)), 7, "Der Zielherd führt nur seine sieben zusätzlichen Belohnungspunkte getrennt")
	_equal(target.speed_multiplier, 0.0, "Der stationäre Zielherd erhält keine Bewegungsmultiplikation")
	_true(target.is_static_flow_obstacle(), "Fall-6-Zielherde veröffentlichen ihre stationäre Hindernisrolle")
	_equal(target.body_role, EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE, "Die Zielherdrolle erreicht InfectionEnemy unverändert")
	_equal(target.obstacle_traversal, EnemySpawnRequest.ObstacleTraversal.DEFAULT, "Zielherde verwenden die normale Nichtboss-Umlaufregel")
	_true(not bool(game.enemy_world.bulk_member_state(handle).get("active", true)), "Stationäre Zielherde sind keine Pulkmitglieder")
	_equal(game.enemy_attack_director.role_for(handle), EnemyAttackDirector.Role.MINOR_FOCUS, "Der stationäre Zielherd schießt in seinen ersten 20 Sekunden normal")

	target.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	_true(target.is_targetable(), "Der Zielherd wird nach seinem normalen Spawntelegraphen angreifbar")
	game._step_case_pressure_targets(0.0)
	game._step_case_pressure_targets(GameScript.CASE_PRESSURE_TARGET_ACTIVE_SECONDS)
	runtime = game.case_pressure_target_states[handle]
	_equal(StringName(runtime.get(&"phase", &"")), &"warning", "Nach 20 Sekunden beginnt die Zielherd-Warnung")
	_equal(float(runtime.get(&"remaining", 0.0)), GameScript.CASE_PRESSURE_WARNING_SECONDS, "Die Zielherd-Warnung dauert exakt 1,5 Sekunden")
	_equal(game.enemy_attack_director.role_for(handle), EnemyAttackDirector.Role.NONE, "Mit Beginn der Warnung endet der normale Zielherdangriff")
	game._step_case_pressure_targets(GameScript.CASE_PRESSURE_WARNING_SECONDS)
	runtime = game.case_pressure_target_states[handle]
	_equal(StringName(runtime.get(&"phase", &"")), &"finale", "Nach der Warnung beginnt das Fächerfinale")

	var projectile_count_before: int = game.projectiles.size()
	for _salvo in range(4):
		game._step_case_pressure_targets(GameScript.CASE_PRESSURE_SALVO_INTERVAL + 0.01)
	runtime = game.case_pressure_target_states[handle]
	_equal(int(runtime.get(&"salvos_emitted", 0)), 4, "Volle Zielherdgesundheit erzeugt höchstens vier Salven nach den verbleibenden Vierteln")
	_equal(game.projectiles.size() - projectile_count_before, 20, "Vier Fünfer-Salven erzeugen exakt zwanzig Projektile")
	_true(bool(runtime.get(&"pending_expiration", false)), "Nach der vierten Salve wird der Zielherd sicher zur Freigabe vorgemerkt")

	var defeats_before: int = int(game.defeats)
	game._on_enemy_defeated(target, target.definition.analysis_value, false)
	_equal(game.defeats, defeats_before + 1, "Ein besiegter Zielherd bleibt genau ein sichtbarer Defeat")
	_equal(game.case_pressure_reward_defeat_points, 7, "Der Zielherdbonus bleibt als sieben zusätzliche Reward-Defeats getrennt gezählt")
	_equal(game.defeats + game.case_pressure_reward_defeat_points, defeats_before + 8, "Sichtbarer Defeat und Zusatzpunkte ergeben intern insgesamt acht Belohnungspunkte")
	_assert_remaining_health_quarters(game)


func _assert_remaining_health_quarters(game) -> void:
	game._spawn_case_pressure_target({&"spawn_sector": 7})
	var handle := int(game.case_pressure_target_states.keys()[0])
	var target := game.enemy_world.resolve(handle) as InfectionEnemy
	_true(is_instance_valid(target), "Ein zweiter Zielherd kann für den Vierteltest aufgelöst werden")
	if not is_instance_valid(target):
		return
	target.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	target.health = target.max_health * 0.5
	var runtime: Dictionary = game.case_pressure_target_states[handle]
	runtime[&"phase"] = &"finale"
	runtime[&"remaining"] = 0.0
	runtime[&"locked_heading"] = Vector2.RIGHT
	runtime[&"just_spawned"] = false
	game.case_pressure_target_states[handle] = runtime
	var projectile_count_before: int = game.projectiles.size()
	for _salvo in range(2):
		game._step_case_pressure_targets(GameScript.CASE_PRESSURE_SALVO_INTERVAL + 0.01)
	runtime = game.case_pressure_target_states[handle]
	_equal(int(runtime.get(&"salvos_emitted", 0)), 2, "Halbe Restgesundheit erzeugt nur die zwei verbleibenden Viertelsalven")
	_equal(game.projectiles.size() - projectile_count_before, 10, "Zwei verbleibende Viertel ergeben exakt zwei Fünfer-Salven")


func _assert_intro_and_boss_exclusion(game) -> void:
	var target_count_before: int = game.case_pressure_target_states.size()
	var gate_count_before: int = game.case_pressure_pending_gates.size()
	game.selected_level = game.levels[0]
	game.case_pressure_director.configure(game.config.case_pressure_plan, game.config.random_seed, GameScript.WAVE_SPAWN_SECTOR_COUNT)
	game.state.elapsed = 200.0
	game.state.boss_spawned = false
	game._case_pressure_step(0.1)
	_equal(game.case_pressure_target_states.size(), target_count_before, "Die Einführung erzeugt keine Zielherde")
	_equal(game.case_pressure_pending_gates.size(), gate_count_before, "Die Einführung erzeugt keine Projektiltore")

	game.selected_level = _level_by_id(game.levels, &"severe_pneumonia")
	game.case_pressure_director.configure(game.config.case_pressure_plan, game.config.random_seed, GameScript.WAVE_SPAWN_SECTOR_COUNT)
	game.state.boss_spawned = true
	game._case_pressure_step(200.0)
	_equal(game.case_pressure_target_states.size(), target_count_before, "Ein aktiver Boss unterdrückt neue Zielherde")
	_equal(game.case_pressure_pending_gates.size(), gate_count_before, "Ein aktiver Boss unterdrückt neue Projektiltore")


func _level_by_id(levels: Array[LevelDefinition], id: StringName) -> LevelDefinition:
	for level in levels:
		if level.id == id:
			return level
	return null


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	_true(absf(actual - expected) <= tolerance, "%s (expected=%.4f actual=%.4f)" % [message, expected, actual])


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_CASE_PRESSURE_RUNTIME_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	push_error("ALVEOLUS_CASE_PRESSURE_RUNTIME_FAILED failures=%d assertions=%d" % [failures.size(), assertions])
	quit(1)
