extends SceneTree

const FIXED_DELTA := 1.0 / 60.0
const LEGACY_DELAY := 0.0
const LEVEL_IDS: Array[StringName] = [
	&"intro",
	&"early_localized_focus",
	&"localized_focus",
	&"advancing_infection",
	&"spreading_infection",
	&"critical_infection",
	&"severe_pneumonia",
]
const MAIN_LEVEL_IDS: Array[StringName] = [
	&"early_localized_focus",
	&"localized_focus",
	&"advancing_infection",
	&"spreading_infection",
	&"critical_infection",
	&"severe_pneumonia",
]

var assertions: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_default_and_override_contract()
	_test_delay_curve_shape()
	_test_main_case_totals_and_rng()
	_test_quick_run_total()
	_test_pause_and_backpressure_clock()
	await _test_game_integration()
	_finish()


func _test_default_and_override_contract() -> void:
	var levels := ContentCatalog.level_definitions()
	_equal(levels.size(), LEVEL_IDS.size(), "Der Katalog enthält Intro plus sechs Hauptfälle")
	for level_index in range(levels.size()):
		var level := levels[level_index] as LevelDefinition
		_equal(level.id, LEVEL_IDS[level_index], "Katalogplatz %d besitzt die erwartete stabile Fall-ID" % level_index)
		_near(
			level.spawn_cadence_delay,
			LevelDefinition.DEFAULT_SPAWN_CADENCE_DELAY,
			"%s erbt die zentrale Standardkadenz" % String(level.id)
		)
		var config := RunConfig.from_level(level)
		_near(config.spawn_cadence_delay, level.spawn_cadence_delay, "%s überträgt die Kadenz in RunConfig" % String(level.id))
		_equal(config.initial_small_enemy_count, level.initial_small_enemy_count, "%s überträgt die Zahl kleiner Startgegner" % String(level.id))
		_equal(config.initial_cluster_enemy_count, level.initial_cluster_enemy_count, "%s überträgt die Zahl gruppierter Startgegner" % String(level.id))

	var explicit_legacy := LevelDefinition.create(
		&"legacy_spawn_override", 9, "Legacy", "", false,
		-1.0, 180.0, 50.0, 0.8, 0.2, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0,
		1.0, PackedInt32Array(), 1.0, "", "", ""
	).configure_spawn_cadence(0.0)
	_near(RunConfig.from_level(explicit_legacy).spawn_cadence_delay, 0.0, "Ein Fall kann die neue Standardkadenz ausdrücklich überschreiben")


func _test_delay_curve_shape() -> void:
	var delay := LevelDefinition.DEFAULT_SPAWN_CADENCE_DELAY
	_near(RunConfig.delayed_spawn_progress(0.0, delay), 0.0, "Die Kadenz beginnt am bestehenden Nullpunkt")
	_near(RunConfig.delayed_spawn_progress(1.0, delay), 1.0, "Die Kadenz erreicht am Bosshorizont exakt den bestehenden Endpunkt")
	_true(RunConfig.delayed_spawn_progress(0.25, delay) < 0.25, "Das erste Viertel läuft langsamer als die alte Spawnuhr")
	_true(RunConfig.delayed_spawn_progress(0.50, delay) < 0.50, "Auch zur Halbzeit liegt die neue Spawnuhr noch hinter der alten")
	var previous_delta := 0.0
	for sample in range(1, 10):
		var current := float(sample) / 10.0
		var current_clock := RunConfig.delayed_spawn_progress(current, delay)
		var previous_clock := RunConfig.delayed_spawn_progress(current - 0.01, delay)
		var clock_delta := current_clock - previous_clock
		_true(clock_delta > previous_delta, "Die Spawnuhr beschleunigt bei Probe %d monoton" % sample)
		previous_delta = clock_delta


func _test_main_case_totals_and_rng() -> void:
	for level in ContentCatalog.level_definitions():
		if level.id not in MAIN_LEVEL_IDS:
			continue
		for rate_index in range(2):
			var config := RunConfig.from_level(level)
			config.spawn_rate_multiplier = 1.0 if rate_index == 0 else 1.10
			var legacy := _simulate_standard_waves(config, LEGACY_DELAY)
			var delayed := _simulate_standard_waves(config, config.spawn_cadence_delay)
			var expected := _expected_standard_slots(level.id, rate_index)
			_equal(int(legacy["slots"]), expected, "%s behält die bekannte Referenzzahl bei Rate %.2f" % [String(level.id), config.spawn_rate_multiplier])
			_equal(int(delayed["slots"]), int(legacy["slots"]), "%s behält exakt dieselbe Zahl Standardwellen" % String(level.id))
			_equal(int(delayed["bodies"]), int(legacy["bodies"]), "%s behält mit gleichem Seed exakt dieselbe Gegnerzahl" % String(level.id))
			_equal(delayed["types"], legacy["types"], "%s behält Gegnerfolge und Inhalts-RNG" % String(level.id))
			_equal(int(delayed["late_slots"]), int(legacy["late_slots"]), "%s behält die Zahl batchfähiger Wellen" % String(level.id))
			_true(float(delayed["first_time"]) > float(legacy["first_time"]), "%s beginnt sichtbar langsamer" % String(level.id))
			_true(float(delayed["last_time"]) < config.run_duration_seconds, "%s emittiert die letzte Standardwelle vor dem Boss-Tick" % String(level.id))
			var old_quarters: PackedInt32Array = legacy["quarters"]
			var new_quarters: PackedInt32Array = delayed["quarters"]
			_true(new_quarters[0] < old_quarters[0], "%s besitzt im ersten Viertel weniger Standardwellen" % String(level.id))
			_true(new_quarters[0] + new_quarters[1] < old_quarters[0] + old_quarters[1], "%s besitzt bis zur Halbzeit weniger Standardwellen" % String(level.id))
			_true(new_quarters[3] > old_quarters[3], "%s holt die unveränderte Gesamtzahl im letzten Viertel auf" % String(level.id))
			_true(new_quarters[0] < new_quarters[1] and new_quarters[1] < new_quarters[2] and new_quarters[2] < new_quarters[3], "%s beschleunigt über alle vier Viertel" % String(level.id))


func _test_quick_run_total() -> void:
	var level := ContentCatalog.level_definitions()[1]
	var config := RunConfig.from_level(level, true)
	var legacy := _simulate_standard_waves(config, LEGACY_DELAY)
	var delayed := _simulate_standard_waves(config, config.spawn_cadence_delay)
	_equal(int(delayed["slots"]), int(legacy["slots"]), "Auch der lokale Quick-Run behält seine Standardwellenzahl")
	_equal(int(delayed["bodies"]), int(legacy["bodies"]), "Auch der Quick-Run behält seine Gegnerzahl für denselben Seed")
	_true(float(delayed["first_time"]) > float(legacy["first_time"]), "Der Quick-Run verwendet ebenfalls den ruhigeren Start")


func _test_pause_and_backpressure_clock() -> void:
	var config := RunConfig.from_level(ContentCatalog.level_definitions()[2])
	_near(config.regular_spawn_clock_delta(45.0, 0.0), 0.0, "Eine Pause verbraucht keine Spawnzeit")
	var one_tick := config.regular_spawn_clock_delta(120.0, FIXED_DELTA)
	_true(one_tick > 0.0 and one_tick < 0.1, "Nach Kapazitätsblockade wird nur der aktuelle Tick und kein Rückstau abgezogen")
	_near(config.regular_spawn_progress(config.run_duration_seconds), 1.0, "Der virtuelle Spawnfortschritt endet exakt am Bosshorizont")


func _test_game_integration() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game := packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.persistence_enabled = false
	game.meta.reset_defaults()
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game.quick_run = true
	game.selected_level = game.levels[1]
	game.start_run()
	game.set_physics_process(false)
	game.treatment_controller.enabled = false
	game.ability_controller.clear()
	game.config.contact_damage_multiplier = 0.0
	game.state.max_stability = 1000000.0
	game.state.stability = game.state.max_stability
	var expected := _simulate_standard_waves(game.config, game.config.spawn_cadence_delay)
	var initial_enemy_count: int = int(game.config.initial_small_enemy_count) + int(game.config.initial_cluster_enemy_count)
	var pre_boss_ticks := roundi(game.config.run_duration_seconds / FIXED_DELTA) - 1
	for _tick in range(pre_boss_ticks):
		game.run_session.step_fixed(FIXED_DELTA)
	_false(game.state.boss_spawned, "Die letzte Standardwelle liegt noch vor dem Quick-Run-Bosstick")
	_equal(game.enemies.size(), initial_enemy_count + int(expected["bodies"]), "Die echte Game-Schleife emittiert die datengetriebenen Startgegner plus exakt geplante Standardgegner")
	var actual_types := PackedStringArray()
	for enemy_index in range(initial_enemy_count, game.enemies.size()):
		var enemy: InfectionEnemy = game.enemies[enemy_index]
		actual_types.append("cluster" if enemy.definition != null and enemy.definition.id == &"bacterial_cluster" else "small")
	_equal(actual_types, expected["types"], "Die echte Game-Schleife bewahrt die geplante Same-Seed-Gegnerfolge")
	game.run_session.step_fixed(FIXED_DELTA)
	_true(game.state.boss_spawned, "Der Boss erscheint weiterhin exakt am Quick-Run-Horizont")
	_equal(game.enemies.size(), initial_enemy_count + 1 + int(expected["bodies"]), "Der Bosstick fügt nur den Boss und keine verspätete Standardwelle hinzu")
	game.queue_free()
	await process_frame


func _simulate_standard_waves(config: RunConfig, delay: float) -> Dictionary:
	var elapsed := 0.0
	var accumulator := config.initial_spawn_interval
	var slots := 0
	var bodies := 0
	var late_slots := 0
	var first_time := -1.0
	var last_time := -1.0
	var quarters := PackedInt32Array([0, 0, 0, 0])
	var types := PackedStringArray()
	var random := RandomNumberGenerator.new()
	random.seed = config.random_seed
	# Game erzeugt zuerst alle kleinen, dann alle gruppierten Startgegner. Jede
	# Platzierung verbraucht genau einen Kompatibilitätszug aus der Content-RNG,
	# bevor die erste zeitgesteuerte Welle ihren Batch-/Typzug ausführt.
	for _index in range(config.initial_small_enemy_count):
		random.randf_range(0.0, TAU)
	for _index in range(config.initial_cluster_enemy_count):
		random.randf_range(0.0, TAU)
	while true:
		var previous_elapsed := elapsed
		elapsed += FIXED_DELTA
		# RunState emits the boss before Game reaches its spawn phase on this tick.
		if elapsed >= config.run_duration_seconds:
			break
		var previous_progress := RunConfig.delayed_spawn_progress(previous_elapsed / config.run_duration_seconds, delay)
		var progress := RunConfig.delayed_spawn_progress(elapsed / config.run_duration_seconds, delay)
		accumulator -= (progress - previous_progress) * config.run_duration_seconds
		if accumulator > 0.0:
			continue
		if first_time < 0.0:
			first_time = elapsed
		last_time = elapsed
		slots += 1
		quarters[mini(floori(elapsed / config.run_duration_seconds * 4.0), 3)] += 1
		var batch := 1
		if progress > 0.58:
			late_slots += 1
			if random.randf() < 0.22:
				batch = 2
		bodies += batch
		var cluster_chance := lerpf(config.cluster_chance_start, config.cluster_chance_end, progress)
		for _body_index in range(batch):
			types.append("cluster" if random.randf() < cluster_chance else "small")
			# Standard placement consumes distance plus the compatibility angle
			# from the content RNG; spatial choices themselves use spawn_rng.
			random.randf_range(500.0, 620.0)
			random.randf_range(0.0, TAU)
		var curved_progress := pow(progress, RunConfig.SPAWN_INTERVAL_CURVE_EXPONENT)
		var interval := lerpf(config.initial_spawn_interval, config.final_spawn_interval, curved_progress)
		accumulator += interval / maxf(config.spawn_rate_multiplier, 0.01)
	return {
		"slots": slots,
		"bodies": bodies,
		"late_slots": late_slots,
		"first_time": first_time,
		"last_time": last_time,
		"quarters": quarters,
		"types": types,
	}


func _expected_standard_slots(level_id: StringName, rate_index: int) -> int:
	match level_id:
		&"early_localized_focus":
			return 522 if rate_index == 0 else 574
		&"localized_focus":
			return 592 if rate_index == 0 else 651
		&"advancing_infection":
			return 682 if rate_index == 0 else 750
		&"spreading_infection":
			return 807 if rate_index == 0 else 887
		&"critical_infection":
			return 879 if rate_index == 0 else 967
		&"severe_pneumonia":
			return 967 if rate_index == 0 else 1063
		_:
			return -1


func _true(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)


func _false(value: bool, message: String) -> void:
	_true(not value, message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual != expected:
		failures.append("%s (erwartet %s, erhalten %s)" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, message: String) -> void:
	assertions += 1
	if not is_equal_approx(actual, expected):
		failures.append("%s (erwartet %s, erhalten %s)" % [message, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_ENEMY_SPAWN_CADENCE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	push_error("ALVEOLUS_ENEMY_SPAWN_CADENCE_FAILED failures=%d assertions=%d" % [failures.size(), assertions])
	quit(1)
