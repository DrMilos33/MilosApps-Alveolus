extends SceneTree

const FIXED_DELTA := 1.0 / 60.0
const MAIN_LEVEL_IDS: Array[StringName] = [
	&"early_localized_focus", &"localized_focus", &"advancing_infection",
	&"spreading_infection", &"critical_infection", &"severe_pneumonia",
]

var assertions: int = 0
var failures: Array[String] = []
var maximum_wave_spawn_step_ms: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_and_config_contract()
	_test_timeout_clear_and_capacity_gates()
	_test_packet_balance_and_determinism()
	_test_clear_gate_preserves_density()
	_test_generation_safe_membership_and_bounded_drain()
	await _test_game_integration()
	_finish()


func _test_catalog_and_config_contract() -> void:
	var found_ids: Array[StringName] = []
	for level in ContentCatalog.level_definitions():
		if level.is_tutorial:
			continue
		found_ids.append(level.id)
		var config := RunConfig.from_level(level)
		_equal(config.regular_spawn_weight_cap, 145, "%s nutzt das zentrale Gewichtslimit" % String(level.id))
		_true(config.regular_spawns_enabled, "%s verwendet den Standardwellenpfad" % String(level.id))
		_true(config.regular_spawn_interval(1.0) < config.regular_spawn_interval(0.0), "%s verdichtet seine Paketgröße über die Fallzeit" % String(level.id))
		_near(config.regular_enemy_health_scale(), level.enemy_health_start, "%s hält Gegnerleben über die gesamte Runde auf dem Fallgrundwert" % String(level.id))
	_equal(found_ids, MAIN_LEVEL_IDS, "Exakt sechs Kampagnenfälle verwenden den zentralen Wellenvertrag")
	_near(StandardWaveDirector.MAXIMUM_WAIT_SECONDS, 4.5, "Eine Welle wartet höchstens 4,5 Sekunden")
	_near(StandardWaveDirector.MINIMUM_CLEAR_WAIT_SECONDS, 2.0, "Das frühe Clear-Gate besitzt zwei Sekunden Mindestabstand")
	_near(StandardWaveDirector.CLEAR_DEFEATED_FRACTION, 0.70, "Das frühe Gate benötigt 70 Prozent besiegtes Gewicht")
	_equal(StandardWaveDirector.MAX_MATERIALIZATIONS_PER_TICK, 4, "Ein Fixed Tick materialisiert höchstens vier Wellenkörper")
	_equal(StandardWaveDirector.MINIMUM_OPEN_WEIGHT, 4, "Unter vier freien Gewichtspunkten entsteht kein einzelner Nachzügler statt einer Welle")


func _test_timeout_clear_and_capacity_gates() -> void:
	var handles := PackedInt64Array()
	var weights := PackedInt32Array()
	for index in range(5):
		handles.append(EntityHandle.make(index, 1))
		weights.append(2)

	var clear_director := StandardWaveDirector.new().configure(101)
	clear_director.begin_initial_wave(handles, weights)
	for index in range(4):
		_true(clear_director.retire(handles[index]), "Aktuelles Wellenmitglied %d kann ausgetragen werden" % index)
	_false(clear_director.advance_clock(1.99), "70 Prozent Abbau umgehen den Mindestabstand nicht")
	_true(clear_director.advance_clock(0.01), "80 Prozent Abbau öffnen nach exakt zwei Sekunden")

	var timeout_director := StandardWaveDirector.new().configure(102)
	timeout_director.begin_initial_wave(handles, weights)
	_false(timeout_director.advance_clock(4.49), "Eine intakte Welle öffnet vor dem Timeout keine Folgewelle")
	_true(timeout_director.advance_clock(0.01), "Eine intakte Welle öffnet nach exakt 4,5 Sekunden")

	var blocked_director := StandardWaveDirector.new().configure(103)
	blocked_director.begin_initial_wave(handles, weights)
	_false(blocked_director.advance_clock(20.0, true), "Kapazitätsdruck friert die Wellenzeit ohne Schuld ein")
	_near(float(blocked_director.snapshot()["seconds_until_forced_wave"]), 4.5, "Kapazitätsdruck sammelt keinen Timer-Rückstau")
	_false(blocked_director.advance_clock(4.49), "Nach Freigabe läuft nur neue Simulationszeit")
	_true(blocked_director.advance_clock(0.01), "Nach Freigabe endet der normale Timeout exakt")
	var no_dribble := StandardWaveDirector.new().configure(104)
	_equal(no_dribble.open_wave(RunConfig.new(), 0.0, 3, false), 0, "Drei freie Gewichtspunkte erzeugen keine Dribbelwelle")


func _test_packet_balance_and_determinism() -> void:
	var first_config := RunConfig.from_level(_level_by_id(&"early_localized_focus"))
	var first_a := StandardWaveDirector.new().configure(2201)
	var first_b := StandardWaveDirector.new().configure(2201)
	_true(first_a.advance_clock(4.5), "Das frühe Vergleichspaket sammelt exakt einen Timeout")
	_true(first_b.advance_clock(4.5), "Der Same-Seed-Vergleich sammelt denselben Timeout")
	var first_count_a := first_a.open_wave(first_config, 0.0, 145, false)
	var first_count_b := first_b.open_wave(first_config, 0.0, 145, false)
	_equal(first_count_a, 4, "Fall 1 beginnt mit einem kompakten Viererpaket")
	_equal(first_count_b, first_count_a, "Gleicher Seed erzeugt dieselbe frühe Paketgröße")
	_equal(_intent_signature(first_a.take_spawn_intents(64)), _intent_signature(first_b.take_spawn_intents(64)), "Gleicher Seed erzeugt dieselbe frühe Gegnerfolge")

	var late_config := RunConfig.from_level(_level_by_id(&"severe_pneumonia"))
	var late_a := StandardWaveDirector.new().configure(6606)
	var late_b := StandardWaveDirector.new().configure(6606)
	_true(late_a.advance_clock(4.5), "Das späte Vergleichspaket sammelt exakt einen Timeout")
	_true(late_b.advance_clock(4.5), "Das späte Same-Seed-Paket sammelt denselben Timeout")
	var late_count_a := late_a.open_wave(late_config, 1.0, 145, true)
	var late_count_b := late_b.open_wave(late_config, 1.0, 145, true)
	_true(late_count_a >= 37 and late_count_a <= 46, "Fall 6 endet in einem großen, aber begrenzten Paket (%d)" % late_count_a)
	_equal(late_count_b, late_count_a, "Spätes Paket bewahrt seine Same-Seed-Größe")
	var late_intents_a := late_a.take_spawn_intents(64)
	var late_intents_b := late_b.take_spawn_intents(64)
	for intent in late_intents_a:
		_near(intent.health_scale, late_config.enemy_health_start, "Auch ein spätes Fall-6-Wellenmitglied behält das Basisleben")
	_equal(_intent_signature(late_intents_a), _intent_signature(late_intents_b), "Spätes Paket bewahrt Gegnerarten und Gewichte")
	_true(_intent_weight(late_intents_a) <= 145, "Ein Paket überschreitet niemals das spielbare Gewichtslimit")

	var boosted_config := RunConfig.from_level(_level_by_id(&"severe_pneumonia"))
	boosted_config.spawn_rate_multiplier = 1.10
	var boosted := StandardWaveDirector.new().configure(6606)
	_true(boosted.advance_clock(4.5), "Das Spawnratenmerkmal verwendet denselben Paketzeitraum")
	var boosted_count := boosted.open_wave(boosted_config, 1.0, 145, true)
	_true(boosted_count > late_count_a, "+10 Prozent Monsterspawn vergrößert das Paket statt den Timer exponentiell zu skalieren")


func _test_clear_gate_preserves_density() -> void:
	var config := RunConfig.new()
	config.initial_spawn_interval = 1.0
	config.final_spawn_interval = 1.0
	config.spawn_rate_multiplier = 1.0
	config.spawn_cadence_delay = 0.0
	var timeout_total := _simulate_fixed_interval_density(config, 4.5, false, 20)
	var cleared_total := _simulate_fixed_interval_density(config, 2.0, true, 45)
	_true(abs(timeout_total - 99) <= 1, "Der Timeoutpfad erhöht die bestehende Dichte nur moderat um zehn Prozent (%d)" % timeout_total)
	_true(abs(cleared_total - timeout_total) <= 1, "Frühes Leeren verschiebt Pakete, vervielfacht aber nicht Gegner/EXP (%d / %d)" % [cleared_total, timeout_total])


func _simulate_fixed_interval_density(
	config: RunConfig,
	gate_seconds: float,
	clear_each_wave: bool,
	wave_count: int
) -> int:
	var director := StandardWaveDirector.new().configure(8800 + wave_count)
	var initial_handle := EntityHandle.make(0, 1)
	director.begin_initial_wave(PackedInt64Array([initial_handle]), PackedInt32Array([1]))
	if clear_each_wave:
		director.retire(initial_handle)
	var total := 0
	var next_slot := 1
	for _wave_index in range(wave_count):
		_true(director.advance_clock(gate_seconds), "Der Dichtevergleich öffnet sein erwartetes Gate")
		director.open_wave(config, 0.0, 145, false)
		var intents := director.take_spawn_intents(64)
		total += intents.size()
		if not clear_each_wave:
			continue
		for intent in intents:
			var handle := EntityHandle.make(next_slot, 1)
			next_slot += 1
			_true(director.commit_spawn(intent, handle), "Dichtevergleich registriert jedes aktuelle Wellenmitglied")
			_true(director.retire(handle), "Dichtevergleich trägt jedes besiegte Wellenmitglied aus")
	return total


func _test_generation_safe_membership_and_bounded_drain() -> void:
	var director := StandardWaveDirector.new().configure(707)
	var old_handle := EntityHandle.make(7, 1)
	director.begin_initial_wave(PackedInt64Array([old_handle]), PackedInt32Array([2]))
	_false(director.retire(EntityHandle.make(7, 2)), "Eine neue Generation kann kein altes Wellenmitglied austragen")
	_equal(int(director.snapshot()["current_alive_weight"]), 2, "Generationswechsel lässt das alte Gewicht unangetastet")
	_true(director.retire(old_handle), "Der exakte alte Handle kann ausgetragen werden")
	_equal(int(director.snapshot()["current_alive_weight"]), 0, "Der exakte Handle reduziert das lebende Gewicht")

	var config := RunConfig.from_level(_level_by_id(&"severe_pneumonia"))
	_true(director.advance_clock(4.5), "Der Drain-Test sammelt vor dem Öffnen einen Paketzeitraum")
	var count := director.open_wave(config, 1.0, 145, true)
	var drained := 0
	while director.has_pending_intents():
		var tick_intents := director.take_spawn_intents()
		_true(tick_intents.size() <= 4, "Jeder Drain bleibt auf vier Materialisierungen begrenzt")
		drained += tick_intents.size()
	_equal(drained, count, "Der begrenzte Drain verliert keinen Wellenkörper")
	director.force_next_wave()
	_true(director.advance_clock(0.0), "Ein fokussierter Test kann die nächste Welle explizit öffnen")
	director.cancel()
	_false(director.advance_clock(20.0), "Boss- oder Laufende storniert den Standardwellenpfad vollständig")


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

	var initial_count: int = game.enemies.size()
	var previous_count := initial_count
	var first_growth_time := -1.0
	var largest_tick_growth := 0
	for _tick in range(360):
		game.run_session.step_fixed(FIXED_DELTA)
		var growth: int = game.enemies.size() - previous_count
		if growth > 0 and first_growth_time < 0.0:
			first_growth_time = game.state.elapsed
		largest_tick_growth = maxi(largest_tick_growth, growth)
		previous_count = game.enemies.size()
	_true(first_growth_time >= 4.49 and first_growth_time <= 4.55, "Die echte erste Folgewelle erscheint am 4,5-s-Timeout (%.3f)" % first_growth_time)
	_true(game.enemies.size() > initial_count + 4, "Die echte Game-Schleife materialisiert ein erkennbares Paket")
	_true(largest_tick_growth <= StandardWaveDirector.MAX_MATERIALIZATIONS_PER_TICK, "Auch die echte Game-Schleife bleibt bei höchstens vier Körpern pro Tick")
	_true(int(game.standard_wave_director.snapshot()["wave_ordinal"]) == 1, "Die echte Game-Schleife führt genau die erste Folgewelle")

	game.standard_wave_director.configure(game.config.random_seed + 1)
	game.standard_wave_director.begin_initial_wave(PackedInt64Array(), PackedInt32Array())
	game.standard_wave_director.force_next_wave()
	game.state.elapsed = game.config.spawn_ramp_seconds
	for _tick in range(20):
		var started_usec := Time.get_ticks_usec()
		game._spawn_step(FIXED_DELTA)
		maximum_wave_spawn_step_ms = maxf(
			maximum_wave_spawn_step_ms,
			float(Time.get_ticks_usec() - started_usec) / 1000.0
		)
		if not game.standard_wave_director.has_pending_intents():
			break
	game.config.enemy_health_start = 1.05
	game.config.enemy_health_end = 9.0
	game.state.elapsed = game.config.run_duration_seconds
	var base_definition := game.enemy_definitions[&"pneumococcus"] as EnemyDefinition
	var base_health: float = base_definition.max_health
	var implicit: InfectionEnemy = game._spawn_enemy(&"pneumococcus", Vector2(420.0, 0.0), -1.0, false, false)
	_true(implicit != null, "Der fokussierte Lauf erzeugt einen impliziten späten Gegner")
	if implicit != null:
		_near(implicit.max_health, base_health * 1.05, "Ein impliziter Spawn verwendet spät weiterhin nur das Fallbasisleben")
	var count_before_adds: int = game.enemies.size()
	game._apply_minions_requested(Vector2(-420.0, 0.0), 1)
	_true(game.enemies.size() == count_before_adds + 1, "Der fokussierte Lauf erzeugt genau einen geskripteten Add")
	if game.enemies.size() > count_before_adds:
		var add: InfectionEnemy = game.enemies.back()
		_near(add.max_health, base_health * 1.05, "Ein später Boss- oder Event-Add verwendet ebenfalls nur das Fallbasisleben")
	var explicit: InfectionEnemy = game._spawn_enemy(&"pneumococcus", Vector2(0.0, 420.0), 1.7, false, false)
	_true(explicit != null, "Der fokussierte Lauf erzeugt einen explizit skalierten Gegner")
	if explicit != null:
		_near(explicit.max_health, base_health * 1.7, "Ein ausdrücklicher Spawnfaktor behält Vorrang vor dem konstanten Fallbasisleben")
	# Informational only: headless wall time is not a performance acceptance gate.
	game.queue_free()
	await process_frame


func _intent_signature(intents: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for intent in intents:
		result.append("%s:%d:%.4f" % [String(intent.enemy_id), int(intent.weight), float(intent.health_scale)])
	return result


func _intent_weight(intents: Array) -> int:
	var result := 0
	for intent in intents:
		result += int(intent.weight)
	return result


func _level_by_id(level_id: StringName) -> LevelDefinition:
	for level in ContentCatalog.level_definitions():
		if level.id == level_id:
			return level
	return null


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
		print("ALVEOLUS_ENEMY_SPAWN_CADENCE_OK assertions=%d max_wave_spawn_step_ms=%.3f" % [assertions, maximum_wave_spawn_step_ms])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	push_error("ALVEOLUS_ENEMY_SPAWN_CADENCE_FAILED failures=%d assertions=%d" % [failures.size(), assertions])
	quit(1)
