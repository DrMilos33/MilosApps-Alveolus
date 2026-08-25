extends SceneTree

const CasePressurePlanScript := preload("res://scripts/data/case_pressure_plan.gd")
const CasePressureDirectorScript := preload("res://scripts/core/case_pressure_director.gd")

var assertions: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_default_schedules()
	_test_level_and_run_config_transfer()
	_test_exact_once_delivery()
	_test_target_capacity_consumes_blocked_slot()
	_test_intro_and_boss_cancel_remaining_plan()
	_test_reset_and_reconfigure()
	_test_movement_independent_timing_and_seed_output()
	_test_sector_exclusion_and_gate_orientation()
	_finish()


func _test_default_schedules() -> void:
	var fall_one := CasePressurePlanScript.default_for_case_order(1)
	_equal(
		fall_one.target_focus_times,
		PackedFloat32Array([60.0, 120.0]),
		"Fall 1 plant kleine Herde exakt bei 60/120 Sekunden"
	)
	_equal(fall_one.projectile_gate_times, PackedFloat32Array(), "Fall 1 plant keine Projektiltore")
	_equal(fall_one.max_active_targets, 1, "Fall 1 erlaubt höchstens einen aktiven Zielherd")
	_near(fall_one.target_movement_speed_multiplier, 66.0 / 42.0, "Fall 1 löst den mobilen Eventherd auf ganzzahliges Basistempo 66 auf")
	_near(fall_one.target_attack_speed_multiplier, 1.875, "Fall 1 erhöht die vorhandene Eventherd-Schussrate nochmals um 50 Prozent")
	_near(fall_one.target_projectile_width_multiplier, 1.5, "Fall 1 verbreitert nur die Eventherdprojektile um 50 Prozent")
	_near(fall_one.target_projectile_speed_multiplier, 1.95, "Fall 1 beschleunigt die bereits schnellen Eventherdprojektile nochmals um 30 Prozent")
	_near(fall_one.defense_burst_shooting_lock_seconds, -1.0, "Stoß beendet den Fall-1-Eventbeschuss dauerhaft")

	var fall_two := CasePressurePlanScript.default_for_case_order(2)
	_equal(
		fall_two.target_focus_times,
		PackedFloat32Array([25.0, 60.0, 95.0, 130.0]),
		"Fall 2 bewahrt Zielherde exakt bei 25/60/95/130 Sekunden"
	)
	_equal(fall_two.projectile_gate_times, PackedFloat32Array(), "Fall 2 plant keine Projektiltore")
	_equal(fall_two.max_active_targets, 2, "Fall 2 bewahrt höchstens zwei aktive Zielherde")
	_near(fall_two.target_movement_speed_multiplier, 2.0, "Fall 2 verdoppelt das Tempo des Eventschwarms")
	_true(not fall_two.target_projectiles_enabled, "Der Fall-2-Eventschwarm besitzt keinen Projektilvertrag")
	_equal(fall_two.target_visual_id, &"bacterial_swarm", "Fall 2 verwendet das zusammengesetzte Bakterienschwarm-Visual")
	_near(fall_two.target_visual_scale, 1.12, "Fall 2 vergrößert das zusammengesetzte Visual leicht")
	_near(fall_two.target_health_multiplier, 20.0 / 3.0, "Fall 2 löst das gemeinsame Eventleben auf exakt 1200 auf")
	_equal(fall_two.symbolic_health_bar_count, 1, "Fall 2 zeigt genau einen gemeinsamen Lebensbalken")
	_near(fall_two.treatment_line_damage_multiplier, 20.0, "Fetter lazer trifft den Fall-2-Schwarm bei voller Abdeckung zwanzigfach")
	_true(fall_two.treatment_line_coverage_scaled, "Fall 2 skaliert den Lazerbonus mit der abgedeckten Schwarmfläche")

	var fall_three := CasePressurePlanScript.default_for_case_order(3)
	_equal(
		fall_three.target_focus_times,
		PackedFloat32Array([22.5, 60.0, 97.5, 135.0]),
		"Fall 3 plant seinen Zwischenrhythmus exakt bei 22,5/60/97,5/135 Sekunden"
	)
	_equal(fall_three.projectile_gate_times, PackedFloat32Array(), "Fall 3 plant keine Projektiltore")
	_equal(fall_three.max_active_targets, 1, "Fall 3 erlaubt höchstens einen aktiven Zielherd")

	var fall_four := CasePressurePlanScript.default_for_case_order(4)
	_equal(
		fall_four.target_focus_times,
		PackedFloat32Array([20.0, 60.0, 100.0, 140.0]),
		"Fall 4 bewahrt Zielherde exakt bei 20/60/100/140 Sekunden"
	)
	_equal(fall_four.projectile_gate_times, PackedFloat32Array(), "Fall 4 plant keine Projektiltore")
	_equal(fall_four.max_active_targets, 1, "Fall 4 erlaubt höchstens einen aktiven Zielherd")

	var fall_five := CasePressurePlanScript.default_for_case_order(5)
	_equal(
		fall_five.target_focus_times,
		PackedFloat32Array([20.0, 60.0, 100.0, 140.0]),
		"Fall 5 plant Zielherde explizit bei 20/60/100/140 Sekunden"
	)
	_equal(
		fall_five.projectile_gate_times,
		PackedFloat32Array([65.0, 105.0]),
		"Fall 5 ergänzt Projektiltore exakt bei 65/105 Sekunden"
	)
	_equal(fall_five.max_active_targets, 1, "Fall 5 erlaubt höchstens einen aktiven Zielherd")

	var fall_six := CasePressurePlanScript.default_for_case_order(6)
	_equal(fall_six.target_focus_times, fall_four.target_focus_times, "Fall 6 bewahrt den Zielrhythmus des bisherigen Endfalls")
	_equal(
		fall_six.projectile_gate_times,
		PackedFloat32Array([45.0, 85.0, 125.0]),
		"Fall 6 bewahrt Projektiltore exakt bei 45/85/125 Sekunden"
	)
	_equal(fall_six.max_active_targets, 1, "Fall 6 erlaubt höchstens einen aktiven Zielherd")

	var intro := CasePressurePlanScript.default_for_case_order(0)
	_equal(intro.target_focus_times, PackedFloat32Array(), "Die Einführung erhält keinen Druckplan")
	_equal(intro.projectile_gate_times, PackedFloat32Array(), "Die Einführung erhält keine Projektiltore")
	_equal(intro.max_active_targets, 0, "Die Einführung erlaubt keine Druckziele")


func _test_level_and_run_config_transfer() -> void:
	var levels := ContentCatalog.level_definitions()
	_equal(levels.size(), 7, "Der Katalog enthält Einführung und sechs Hauptfälle")
	for order in range(levels.size()):
		var level := levels[order] as LevelDefinition
		var expected := CasePressurePlanScript.default_for_case_order(order)
		_true(level != null and level.case_pressure_plan != null, "Fall %d besitzt einen expliziten Druckplan" % order)
		if level == null or level.case_pressure_plan == null:
			continue
		_equal(level.case_pressure_plan.target_focus_times, expected.target_focus_times, "Fall %d übernimmt die Zielherdtermine" % order)
		_equal(level.case_pressure_plan.projectile_gate_times, expected.projectile_gate_times, "Fall %d übernimmt die Projektiltortermine" % order)
		_equal(level.case_pressure_plan.max_active_targets, expected.max_active_targets, "Fall %d übernimmt den Zielherddeckel" % order)
		_near(level.case_pressure_plan.target_movement_speed_multiplier, expected.target_movement_speed_multiplier, "Fall %d übernimmt das Zielherdtempo" % order)
		_near(level.case_pressure_plan.target_attack_speed_multiplier, expected.target_attack_speed_multiplier, "Fall %d übernimmt die Zielherd-Schussrate" % order)
		_near(level.case_pressure_plan.target_projectile_width_multiplier, expected.target_projectile_width_multiplier, "Fall %d übernimmt die Zielherd-Projektilbreite" % order)

	var source := levels[6] as LevelDefinition
	var config := RunConfig.from_level(source)
	var quick_config := RunConfig.from_level(source, true)
	_true(config.case_pressure_plan != null, "RunConfig übernimmt den Fall-6-Druckplan")
	_true(config.case_pressure_plan != source.case_pressure_plan, "RunConfig besitzt keinen Alias auf den Katalogplan")
	_true(quick_config.case_pressure_plan != null, "Quick-Run behält den Druckplan")
	if quick_config.case_pressure_plan != null:
		_equal(quick_config.case_pressure_plan.target_focus_times, config.case_pressure_plan.target_focus_times, "Quick-Run verändert die Zielherdtermine nicht")
		_equal(quick_config.case_pressure_plan.projectile_gate_times, config.case_pressure_plan.projectile_gate_times, "Quick-Run verändert die Projektiltortermine nicht")
	if config.case_pressure_plan != null and source.case_pressure_plan != null:
		var configured_times := config.case_pressure_plan.target_focus_times.duplicate()
		source.case_pressure_plan.target_focus_times[0] = 999.0
		_equal(config.case_pressure_plan.target_focus_times, configured_times, "Eine spätere Katalogmutation verändert den laufenden Plan nicht")


func _test_exact_once_delivery() -> void:
	var director := CasePressureDirectorScript.new().configure(
		CasePressurePlanScript.default_for_case_order(2),
		317_021
	)
	var signal_times := PackedFloat32Array()
	director.event_due.connect(func(
		_kind: int,
		scheduled_time: float,
		_spawn_sector: int,
		_gate_orientation: int
	) -> void:
		signal_times.append(scheduled_time)
	)
	_equal(director.advance(24.999, 0, false, false).size(), 0, "Vor Sekunde 25 ist noch kein Ziel fällig")
	var events: Array[Dictionary] = []
	for elapsed in [25.0, 25.0, 59.999, 60.0, 95.0, 130.0, 130.0, 240.0]:
		events.append_array(director.advance(elapsed, 0, false, false))
	_equal(_event_times(events), PackedFloat32Array([25.0, 60.0, 95.0, 130.0]), "Jeder erhaltene Fall-2-Termin wird exakt einmal geliefert")
	_equal(signal_times, PackedFloat32Array([25.0, 60.0, 95.0, 130.0]), "Das Signal wird für dieselben Ereignisse exakt einmal emittiert")
	_equal(director.pending_event_count(), 0, "Nach dem letzten Termin bleibt kein Druckereignis offen")
	for event in events:
		_equal(int(event[&"kind"]), CasePressureDirectorScript.EventKind.TARGET_FOCUS, "Fall 2 liefert ausschließlich Zielherde")


func _test_target_capacity_consumes_blocked_slot() -> void:
	var director := CasePressureDirectorScript.new().configure(
		CasePressurePlanScript.default_for_case_order(2),
		19
	)
	_equal(director.advance(25.0, 2, false, false).size(), 0, "Ein voller Zielherddeckel unterdrückt den fälligen Termin")
	var next_due: Array[Dictionary] = director.advance(60.0, 0, false, false)
	_equal(_event_times(next_due), PackedFloat32Array([60.0]), "Ein unterdrückter Termin wird nicht verspätet nachgeholt")
	_equal(director.advance(60.0, 0, false, false).size(), 0, "Auch der nächste Termin wird nicht doppelt geliefert")


func _test_intro_and_boss_cancel_remaining_plan() -> void:
	var plan := CasePressurePlanScript.default_for_case_order(6)
	var intro_director := CasePressureDirectorScript.new().configure(plan, 77)
	_equal(intro_director.advance(20.0, 0, true, false).size(), 0, "Introstatus unterdrückt einen fälligen Zieldruck")
	_true(intro_director.is_cancelled(), "Introstatus storniert den verbleibenden Plan")
	_equal(intro_director.advance(200.0, 0, false, false).size(), 0, "Ein Introplan kann später keinen Rückstau freigeben")
	intro_director.reset()
	_equal(_event_times(intro_director.advance(20.0, 0, false, false)), PackedFloat32Array([20.0]), "Reset aktiviert denselben Plan neu")

	var boss_director := CasePressureDirectorScript.new().configure(plan, 77)
	_equal(_event_times(boss_director.advance(20.0, 0, false, false)), PackedFloat32Array([20.0]), "Vor dem Boss bleibt der erste Zieltermin aktiv")
	_equal(boss_director.advance(45.0, 0, false, true).size(), 0, "Bossstatus unterdrückt das fällige Projektiltor")
	_true(boss_director.is_cancelled(), "Bossstatus storniert den verbleibenden Druckplan")
	_equal(boss_director.advance(200.0, 0, false, false).size(), 0, "Nach Bossbeginn wird kein Drucktermin nachgeholt")


func _test_reset_and_reconfigure() -> void:
	var director := CasePressureDirectorScript.new().configure(
		CasePressurePlanScript.default_for_case_order(2),
		1_337
	)
	var first_delivery: Array[Dictionary] = director.advance(25.0, 0, false, false)
	director.reset()
	var reset_delivery: Array[Dictionary] = director.advance(25.0, 0, false, false)
	_equal(_event_signatures(reset_delivery), _event_signatures(first_delivery), "Reset reproduziert denselben ersten Termin samt Seed-Geometrie")

	director.cancel()
	director.configure(CasePressurePlanScript.default_for_case_order(6), 8_181)
	var reconfigured: Array[Dictionary] = director.advance(45.0, 0, false, false)
	_equal(_event_times(reconfigured), PackedFloat32Array([20.0, 45.0]), "Configure ersetzt den alten Plan und hebt eine vorherige Stornierung auf")
	if reconfigured.size() == 2:
		_equal(int(reconfigured[1][&"kind"]), CasePressureDirectorScript.EventKind.PROJECTILE_GATE, "Der neu konfigurierte Fall-6-Termin behält seinen Tortyp")


func _test_movement_independent_timing_and_seed_output() -> void:
	var plan := CasePressurePlanScript.default_for_case_order(6)
	var still_director := CasePressureDirectorScript.new().configure(plan, 2_026_082_4)
	var moving_director := CasePressureDirectorScript.new().configure(plan, 2_026_082_4)
	var still_events: Array[Dictionary] = []
	var moving_events: Array[Dictionary] = []
	var elapsed_samples := PackedFloat32Array([0.0, 7.0, 20.0, 44.0, 45.0, 84.0, 85.0, 124.0, 125.0, 200.0])
	var player_position := Vector2.ZERO
	for sample_index in range(elapsed_samples.size()):
		var elapsed := float(elapsed_samples[sample_index])
		still_events.append_array(still_director.advance(elapsed, 0, false, false))
		player_position += Vector2(31.0 + sample_index, -17.0 + sample_index * 0.5)
		# Player position is intentionally not an input to the scheduler API.
		moving_events.append_array(moving_director.advance(elapsed, 0, false, false))
	_true(player_position.length_squared() > 0.0, "Die Vergleichsspur enthält tatsächliche Spielerbewegung")
	_equal(_event_signatures(moving_events), _event_signatures(still_events), "Spielerbewegung verändert weder Termine noch Seed-Ausgaben")
	_equal(
		_event_times(moving_events),
		PackedFloat32Array([20.0, 45.0, 60.0, 85.0, 100.0, 125.0, 140.0]),
		"Auch grobe Ticks geben die authored Termine statt Tickzeiten zurück"
	)

	var advance_argument_count := -1
	for method in moving_director.get_method_list():
		if String(method.get("name", "")) == "advance":
			advance_argument_count = (method.get("args", []) as Array).size()
			break
	_equal(advance_argument_count, 4, "advance akzeptiert nur Zeit, Zielzahl, Intro- und Bossstatus")


func _test_sector_exclusion_and_gate_orientation() -> void:
	var director := CasePressureDirectorScript.new().configure(
		CasePressurePlanScript.default_for_case_order(6),
		941_107,
		12
	)
	var events: Array[Dictionary] = director.advance(200.0, 0, false, false)
	var previous_sector := -1
	var gate_count := 0
	for event in events:
		var sector := int(event[&"spawn_sector"])
		_true(sector >= 0 and sector < 12, "Jedes Druckereignis besitzt einen gültigen Spawnsektor")
		if previous_sector >= 0:
			var direct_distance := absi(sector - previous_sector)
			var circular_distance := mini(direct_distance, 12 - direct_distance)
			_true(circular_distance > 1, "Der nächste Spawn meidet den letzten Sektor und beide Nachbarn")
		previous_sector = sector
		if int(event[&"kind"]) == CasePressureDirectorScript.EventKind.PROJECTILE_GATE:
			gate_count += 1
			var orientation := int(event[&"gate_orientation"])
			_true(orientation >= 0 and orientation < 12, "Ein Projektiltor besitzt eine deterministische gültige Orientierung")
		else:
			_equal(int(event[&"gate_orientation"]), CasePressureDirectorScript.NO_GATE_ORIENTATION, "Ein Zielherd erfindet keine Tororientierung")
	_equal(gate_count, 3, "Fall 6 liefert exakt drei Projektiltore")

	var replay := CasePressureDirectorScript.new().configure(
		CasePressurePlanScript.default_for_case_order(6),
		941_107,
		12
	)
	_equal(_event_signatures(replay.advance(200.0, 0, false, false)), _event_signatures(events), "Gleicher Runseed reproduziert Sektoren und Tororientierungen exakt")


func _event_times(events: Array[Dictionary]) -> PackedFloat32Array:
	var times := PackedFloat32Array()
	for event in events:
		times.append(float(event[&"scheduled_time"]))
	return times


func _event_signatures(events: Array[Dictionary]) -> PackedStringArray:
	var signatures := PackedStringArray()
	for event in events:
		signatures.append("%d|%.3f|%d|%d" % [
			int(event[&"kind"]),
			float(event[&"scheduled_time"]),
			int(event[&"spawn_sector"]),
			int(event[&"gate_orientation"]),
		])
	return signatures


func _true(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual != expected:
		failures.append("%s (erwartet %s, erhalten %s)" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, message: String) -> void:
	assertions += 1
	if not is_equal_approx(actual, expected):
		failures.append("%s (erwartet %.4f, erhalten %.4f)" % [message, expected, actual])


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_CASE_PRESSURE_DIRECTOR_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	push_error("ALVEOLUS_CASE_PRESSURE_DIRECTOR_FAILED failures=%d assertions=%d" % [failures.size(), assertions])
	quit(1)
