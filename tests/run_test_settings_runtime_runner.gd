extends SceneTree

## Focused runtime contract for the gameplay effects behind the test-values UI.
## The runner uses real production seams without starting a complete run.

const GAME_PATH := "res://scripts/game.gd"
const TEST_SETTINGS_PATH := "res://scripts/core/run_test_settings.gd"
const TEST_REPOSITORY_PATH := "res://scripts/core/run_test_settings_repository.gd"
const META_REPOSITORY_PATH := "res://scripts/core/meta_save_repository.gd"
const GameScript := preload(GAME_PATH)
const RunTestSettingsScript := preload(TEST_SETTINGS_PATH)
const RunTestSettingsRepositoryScript := preload(TEST_REPOSITORY_PATH)
const MetaSaveRepositoryScript := preload(META_REPOSITORY_PATH)


class ShieldProbe:
	extends AbilityController

	var absorb_calls := 0

	func absorb_pressure(amount: float) -> float:
		absorb_calls += 1
		return amount


class FeedbackProbe:
	extends TherapyAvatar

	var flash_calls := 0

	func show_damage_flash() -> void:
		flash_calls += 1


var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_immunity_precedes_damage_pipeline()
	await _test_enemy_damage_multiplier_and_statistics()
	_test_live_movement_multiplier()
	_test_repository_boundary()
	_finish()


func _test_immunity_precedes_damage_pipeline() -> void:
	var source := FileAccess.get_file_as_string(GAME_PATH)
	var body := _function_body(source, "func _apply_incoming_damage(")
	var immunity_index := body.find("run_test_settings.damage_immunity_enabled()")
	var grace_index := body.find("pressure_grace_timer > 0.0")
	var shield_index := body.find("ability_controller.absorb_pressure(amount)")
	var feedback_index := body.find("avatar.show_damage_flash()")
	_true(not body.is_empty(), "Game besitzt den fokussierten Schadenseingang")
	_true(immunity_index >= 0, "Schadenseingang besitzt das explizite Testimmunitäts-Gate")
	_true(
		immunity_index < grace_index and immunity_index < shield_index and immunity_index < feedback_index,
		"Testimmunität liegt vor Gnadenzeit, Schildverbrauch und Schadensfeedback"
	)
	_true(
		body.contains("if test_tools_available and run_test_settings.damage_immunity_enabled():"),
		"Immunität ist zusätzlich an die explizite Testtools-Verfügbarkeit gebunden"
	)

	var game := GameScript.new()
	var state := RunState.new()
	state.active = true
	state.max_stability = 100.0
	state.stability = 100.0
	var stability_events := [0]
	state.stability_changed.connect(func(_current: float, _maximum: float) -> void: stability_events[0] += 1)
	var shield_probe := ShieldProbe.new()
	var feedback_probe := FeedbackProbe.new()
	game.add_child(shield_probe)
	game.add_child(feedback_probe)
	game.state = state
	game.ability_controller = shield_probe
	game.avatar = feedback_probe
	game.test_tools_available = true
	game.run_test_settings = RunTestSettingsScript.new(true, 0, 100)
	game.pressure_grace_timer = 0.0
	game._apply_incoming_damage(25.0, null, null)
	_equal(state.stability, 100.0, "Aktive Testimmunität lässt Stabilität unverändert")
	_equal(stability_events[0], 0, "Aktive Testimmunität emittiert kein Stabilitätssignal")
	_equal(game.pressure_grace_timer, 0.0, "Aktive Testimmunität startet keine Gnadenzeit")
	_equal(shield_probe.absorb_calls, 0, "Aktive Testimmunität verbraucht keinen Schild")
	_equal(feedback_probe.flash_calls, 0, "Aktive Testimmunität erzeugt kein Schadensfeedback")
	game.free()


func _test_enemy_damage_multiplier_and_statistics() -> void:
	var game_source := FileAccess.get_file_as_string(GAME_PATH)
	_true(
		_function_body(game_source, "func _apply_live_test_settings(").contains(
			"enemy.set_incoming_player_damage_multiplier(damage_multiplier)"
		),
		"Live-Änderungen erreichen bereits aktive Gegner"
	)
	_true(
		_function_body(game_source, "func _spawn_enemy(").contains(
			"enemy.set_incoming_player_damage_multiplier(run_test_settings.outgoing_damage_multiplier())"
		),
		"Neu gespawnte Gegner übernehmen denselben Schadensmultiplikator"
	)
	var target := TherapyAvatar.new()
	var enemy := InfectionEnemy.new()
	get_root().add_child(target)
	get_root().add_child(enemy)
	await process_frame
	var definition := EnemyDefinition.create(
		&"test_multiplier_enemy",
		"Testkeim",
		100.0,
		0.0,
		0.0,
		0,
		18.0,
		Color.WHITE
	)
	enemy.configure(definition, target, null)
	enemy.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	_true(enemy.is_targetable(), "Testgegner ist nach dem echten Spawntelegraphen angreifbar")

	var game := GameScript.new()
	game.selected_level = LevelDefinition.new()
	game.run_damage_by_source.clear()
	var applied_events: Array[Array] = []
	enemy.damage_applied.connect(func(_enemy: InfectionEnemy, amount: float, source: StringName) -> void:
		applied_events.append([amount, source])
	)
	enemy.damage_applied.connect(Callable(game, "_on_enemy_damage_applied"))
	var settings: RunTestSettings = RunTestSettingsScript.new(false, 50, 100)
	enemy.set_incoming_player_damage_multiplier(settings.outgoing_damage_multiplier())
	enemy.take_damage(20.0, &"therapy")
	_equal(enemy.health, 70.0, "+50 Prozent werden auf den tatsächlich abgezogenen Gegnerschaden angewandt")
	_equal(applied_events, [[30.0, &"therapy"]], "damage_applied meldet den multiplizierten statt des Rohschadens")
	_equal(
		float(game.run_damage_by_source.get(&"treatment_precision", 0.0)),
		30.0,
		"Das Statistiksignal übernimmt den tatsächlich angewandten Schaden"
	)

	# Overkill must report only remaining health, never the multiplied request.
	enemy.take_damage(100.0, &"therapy")
	_equal(enemy.health, 0.0, "Multiplizierter Overkill besiegt den Gegner")
	_equal(applied_events[1], [70.0, &"therapy"], "Overkill-Signal ist auf das verbleibende Leben begrenzt")
	_equal(
		float(game.run_damage_by_source.get(&"treatment_precision", 0.0)),
		100.0,
		"Rundenstatistik summiert angewandten Schaden ohne Overkill"
	)
	game.free()
	enemy.queue_free()
	target.queue_free()
	await process_frame


func _test_live_movement_multiplier() -> void:
	var base_speed := 304.0
	var build := RunBuildState.new({RunBuildState.MOVEMENT_SPEED: base_speed})
	var stats := PlayerStats.new()
	stats.run_build_state = build
	stats.movement_speed = base_speed
	var game := GameScript.new()
	game.test_tools_available = true
	game.run_test_settings = RunTestSettingsScript.new(false, 0, 125)
	game.build_state = build
	game.stats = stats

	game._apply_live_test_settings()
	_equal(stats.movement_speed, 380.0, "125 Prozent Galopp werden über RunBuildState ganzzahlig aufgelöst")
	_true(is_equal_approx(stats.movement_speed, float(roundi(stats.movement_speed))), "Galopp bleibt ein ganzzahliger Laufzeitwert")
	_equal(_debug_movement_modifier_count(build), 1, "Erste Live-Anwendung besitzt genau einen Debug-Modifikator")

	game.run_test_settings.set_movement_speed_percent(150)
	game._apply_live_test_settings()
	_equal(stats.movement_speed, 456.0, "Live-Wechsel ersetzt 125 durch 150 Prozent")
	_equal(_debug_movement_modifier_count(build), 1, "Live-Wechsel ersetzt die Quelle statt sie zu stapeln")
	game._apply_live_test_settings()
	_equal(stats.movement_speed, 456.0, "Wiederholtes Anwenden desselben Werts ist nicht kumulativ")
	_equal(_debug_movement_modifier_count(build), 1, "Idempotentes Reapply behält genau einen Modifikator")

	game.run_test_settings.set_movement_speed_percent(50)
	game._apply_live_test_settings()
	_equal(stats.movement_speed, 152.0, "Live-Wechsel nach unten wird weiterhin vom unveränderten Basiswert berechnet")
	_equal(build.base_value(RunBuildState.MOVEMENT_SPEED), base_speed, "Testwerte verändern niemals die Galopp-Basis")
	game.free()


func _debug_movement_modifier_count(build: RunBuildState) -> int:
	var count := 0
	for modifier in build.modifiers_for(RunBuildState.MOVEMENT_SPEED):
		if modifier.source_id == &"debug_test_values":
			count += 1
	return count


func _test_repository_boundary() -> void:
	var test_source := FileAccess.get_file_as_string(TEST_REPOSITORY_PATH)
	var meta_source := FileAccess.get_file_as_string(META_REPOSITORY_PATH)
	_equal(
		RunTestSettingsRepositoryScript.DEFAULT_PATH,
		"user://alveolus_test_tools.cfg",
		"Testwerte besitzen ihre eigene ConfigFile"
	)
	_true(
		RunTestSettingsRepositoryScript.DEFAULT_PATH != MetaSaveRepositoryScript.DEFAULT_PATH,
		"Testwerte- und Meta-Persistenz verwenden verschiedene Dateien"
	)
	_true(test_source.contains("ConfigFile.new()"), "Testwerte-Repository bleibt eine eigenständige ConfigFile-Ablage")
	_true(not test_source.contains("MetaSaveRepository"), "Testwerte-Repository kennt den Meta-Save nicht")
	_true(not meta_source.contains("alveolus_test_tools"), "Meta-Repository kennt die Testtools-Datei nicht")
	for key in ["damage_immunity", "outgoing_damage_bonus_percent", "movement_speed_percent"]:
		_true(not meta_source.contains(key), "Meta-Save enthält keinen Testwertschlüssel %s" % key)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var finish := source.find("\nfunc ", start + signature.length())
	if finish < 0:
		finish = source.length()
	return source.substr(start, finish - start)


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("RUN_TEST_SETTINGS_RUNTIME_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("RUN_TEST_SETTINGS_RUNTIME_FAILED assertions=%d failures=%d" % [assertions, failures.size()])
	quit(1)
