extends SceneTree

var assertions: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_level_deadline_contract()
	_test_config_deadline_contract()
	_test_endless_run_state()
	_test_finite_run_state()
	_finish()


func _test_level_deadline_contract() -> void:
	var endless := _level(-1.0, 180.0)
	_false(endless.has_deadline(), "Ein negativer Sentinel kennzeichnet einen Fall ohne Deadline")
	_equal(endless.duration_text(), "Ohne Zeitlimit", "Ein endloser Fall benennt das fehlende Zeitlimit ausdrücklich")

	var zero_sentinel := _level(0.0, 180.0)
	_false(zero_sentinel.has_deadline(), "Auch null ist ein gültiger Kein-Deadline-Sentinel")
	_equal(zero_sentinel.duration_text(), "Ohne Zeitlimit", "Der Null-Sentinel wird nicht als Dauer 0:00 dargestellt")

	var finite := _level(181.0, 180.0)
	_true(finite.has_deadline(), "Eine positive Gesamtdauer aktiviert die Deadline")
	_equal(finite.duration_text(), "3:01 Min.", "Positive Falldauern behalten die bestehende Zeitdarstellung")

	var tutorial := _level(0.0, 0.0)
	tutorial.is_tutorial = true
	_equal(tutorial.duration_text(), "∞", "Das Intro zeigt sein fehlendes Zeitlimit als Unendlichkeitszeichen")


func _test_config_deadline_contract() -> void:
	var endless_config := RunConfig.from_level(_level(-1.0, 180.0))
	_false(endless_config.has_deadline(), "RunConfig übernimmt den endlosen Sentinel")
	_near(endless_config.final_deadline_seconds, -1.0, "RunConfig bewahrt den Sentinel unverändert")

	var quick_config := RunConfig.from_level(_level(-1.0, 180.0), true)
	_true(quick_config.has_deadline(), "Ein Quick-Run behält trotz endlosem Inhaltsfall seine Testdeadline")
	_near(quick_config.run_duration_seconds, 12.0, "Quick-Run behält seinen kurzen Bosszeitpunkt")
	_near(quick_config.final_deadline_seconds, 22.0, "Quick-Run behält seine 22-Sekunden-Deadline")


func _test_endless_run_state() -> void:
	var config := RunConfig.from_level(_level(-1.0, 180.0))
	var state := RunState.new()
	var boss_events := [0]
	var finish_events := [0]
	state.boss_due.connect(func() -> void: boss_events[0] += 1)
	state.run_finished.connect(func(_success: bool, _reason: String) -> void: finish_events[0] += 1)
	state.reset(config)

	state.tick(179.0)
	_equal(boss_events[0], 0, "Der Boss erscheint nicht vor Sekunde 180")
	state.tick(1.0)
	_equal(boss_events[0], 1, "Der Boss erscheint bei Sekunde 180 genau einmal")
	state.tick(100000.0)
	_equal(boss_events[0], 1, "Ein endloser Fall löst den Boss nicht erneut aus")
	_equal(finish_events[0], 0, "Ein endloser Fall endet nicht durch verstrichene Zeit")
	_true(state.active, "Ein endloser Fall bleibt bis zu einem Gameplay-Ergebnis aktiv")


func _test_finite_run_state() -> void:
	var config := RunConfig.from_level(_level(181.0, 180.0))
	var state := RunState.new()
	var boss_events := [0]
	var result := {"count": 0, "success": true, "reason": ""}
	state.boss_due.connect(func() -> void: boss_events[0] += 1)
	state.run_finished.connect(func(success: bool, reason: String) -> void:
		result["count"] = int(result["count"]) + 1
		result["success"] = success
		result["reason"] = reason
	)
	state.reset(config)
	state.tick(180.0)
	_equal(boss_events[0], 1, "Ein begrenzter Fall verwendet weiterhin seinen Bosszeitpunkt")
	_true(state.active, "Der begrenzte Fall bleibt bis zur positiven Deadline aktiv")
	state.tick(1.0)
	_equal(result["count"], 1, "Eine positive Deadline beendet den Fall weiterhin")
	_false(bool(result["success"]), "Der Deadline-Ablauf bleibt eine Niederlage")
	_true(String(result["reason"]).contains("abgelaufen"), "Der bestehende Deadline-Grund bleibt erhalten")


func _level(deadline: float, boss_time: float) -> LevelDefinition:
	var definition := LevelDefinition.new()
	definition.id = &"deadline_contract"
	definition.title = "Deadline-Vertrag"
	definition.total_seconds = deadline
	definition.boss_spawn_seconds = boss_time
	definition.initial_stability = 100.0
	definition.initial_spawn_interval = 1.0
	definition.final_spawn_interval = 0.5
	definition.enemy_health_start = 1.0
	definition.enemy_health_end = 1.0
	definition.enemy_speed_multiplier = 1.0
	definition.contact_damage_multiplier = 1.0
	definition.boss_health_multiplier = 1.0
	return definition


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
		print("ALVEOLUS_ENDLESS_CASE_CONTRACT_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	push_error("ALVEOLUS_ENDLESS_CASE_CONTRACT_FAILED failures=%d assertions=%d" % [failures.size(), assertions])
	quit(1)
