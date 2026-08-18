extends SceneTree

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_distance_and_body_catalogs()
	_test_balance_and_movement_plumbing()
	_test_reward_preview()
	_test_stat_sections_and_headings()
	if failures.is_empty():
		print("ALVEOLUS_FEEDBACK_ARCHITECTURE_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	push_error("ALVEOLUS_FEEDBACK_ARCHITECTURE_FAILED failures=%d assertions=%d" % [failures.size(), assertions])
	quit(1)


func _test_distance_and_body_catalogs() -> void:
	_equal(CombatDistanceScale.stage_from_world(480.0), 16, "480 Weltpunkte entsprechen exakt Reichweitenstufe 16")
	_near(CombatDistanceScale.world_from_stage(7), 210.0, "Stufe sieben löst zentral auf 210 Weltpunkte auf")
	_near(CombatDistanceScale.quantize_world(574.0), 570.0, "Weltwerte werden auf die nächste zentrale Stufe quantisiert")
	var build := RunBuildState.new({RunBuildState.TREATMENT_RANGE: 480.0})
	var modifier := ModifierDefinition.create(&"range_test", RunBuildState.TREATMENT_RANGE, ModifierDefinition.Operation.MULTIPLY, 1.20)
	_true(build.add_modifier(modifier), "Reichweitenmodifikator wird angenommen")
	_near(build.value(RunBuildState.TREATMENT_RANGE), 570.0, "Alle Reichweitenmodifikatoren werden vor genau einer Stufenquantisierung aufgelöst")
	var enemies := ContentCatalog.enemy_definitions()
	_near(BodySizeCatalog.maximum_radius(enemies), 72.0, "Maximaler Körperradius kommt aus dem Katalog")
	_equal(enemies[&"minor_focus"].body_size_class, BodySizeCatalog.SizeClass.LARGE, "Körpergrößenklassen bleiben getrennt von Distanzstufen")
	_equal(BodySizeCatalog.class_for_radius(TherapyAvatar.BODY_RADIUS), BodySizeCatalog.SizeClass.MEDIUM, "Der Avatar nutzt denselben separaten Größenklassenvertrag")


func _test_balance_and_movement_plumbing() -> void:
	var treatments := TreatmentDefinition.catalog()
	_near(treatments[&"treatment_precision"].base_damage, 16.0, "Präzise Grundbehandlung besitzt 16 Schaden")
	_near(treatments[&"treatment_spread"].base_damage, 7.0, "Streubehandlung besitzt 7 Schaden")
	_near(treatments[&"treatment_pierce"].base_interval, 1.65, "Durchdringende Behandlung besitzt 1,65 Sekunden Intervall")
	var abilities := AbilityDefinition.catalog()
	_near(float(abilities[&"ability_defense_burst"].parameters["damage"]), 38.0, "Abwehrstoß besitzt 38 Schaden")
	_near(float(abilities[&"ability_treatment_line"].parameters["damage"]), 50.0, "Behandlungslinie besitzt 50 Schaden")
	var enemies := ContentCatalog.enemy_definitions()
	_near(enemies[&"pneumococcus"].speed, 66.0, "Bakterium besitzt Tempo 66")
	_near(enemies[&"bacterial_cluster"].speed, 50.0, "Bakteriengruppe besitzt Tempo 50")
	_near(enemies[&"minor_focus"].speed, 24.0, "Kleiner Herd besitzt Tempo 24")
	_near(enemies[&"infection_focus"].speed, 34.0, "Boss besitzt Tempo 34")
	var stats := PlayerStats.new()
	stats.configure_prepared_treatment(treatments[&"treatment_precision"])
	stats.apply_meta_progression({&"movement_training": 3})
	_near(stats.movement_speed, 338.0 * 1.09, "Bewegungsforschung addiert drei Prozent je Rang auf Basis 338")
	var build := RunBuildState.from_treatment(treatments[&"treatment_precision"])
	stats.bind_run_build(build, treatments[&"treatment_precision"])
	var mobility := _upgrade(&"mobility")
	for rank in range(3):
		_true(stats.apply_upgrade(mobility), "Mobilitätsausbau Rang %d wird angewandt" % (rank + 1))
	_near(stats.movement_speed, 338.0 * 1.09 * pow(1.05, 3), "Mobilitätsausbau multipliziert den aufgelösten Bewegungsstat je Rang")
	_equal(PlayerStats.BASE_MOVEMENT_SPEED, 338.0, "Doctor-Basisbewegung ist zentral 338")
	_equal(TherapyAvatar.MOVE_SPEED, PlayerStats.BASE_MOVEMENT_SPEED, "Avatar-Fallback ist an die zentrale Doctor-Basis gekoppelt")
	_equal(treatments[&"treatment_precision"].display_name, "Impuls", "Die stabile Behandlungs-ID erhält den sichtbaren Namen Impuls")
	_equal(ContentCatalog.loadout_module_definitions()[&"treatment_precision"].title, "Impuls", "Einsatzplanung verwendet denselben sichtbaren Namen")


func _test_reward_preview() -> void:
	var meta := MetaProgressionState.new(func() -> int: return 1_700_000_000)
	meta.reset_defaults(1_700_000_000)
	var preview := MetaProgressionState.calculate_run_reward(false, 367.0, 6, 47, 1.35)
	_equal(meta.research_points, 0, "Belohnungsvorschau mutiert keine Forschungspunkte")
	_equal(meta.lifetime_runs, 0, "Belohnungsvorschau mutiert keine Runstatistik")
	var awarded := meta.award_run(false, 367.0, 6, 47, 1.35)
	_equal(awarded, preview, "Niederlagenvorschau und tatsächliche Auszahlung sind identisch")
	_equal(meta.research_points, preview, "award_run bucht exakt den vorgerechneten Wert")
	_equal(meta.lifetime_runs, 1, "Nur award_run registriert einen Run")


func _test_stat_sections_and_headings() -> void:
	var treatment: TreatmentDefinition = TreatmentDefinition.catalog()[&"treatment_precision"]
	var abilities := AbilityDefinition.catalog()
	var prepared: Array[AbilityDefinition] = [abilities[&"ability_defense_burst"], abilities[&"ability_treatment_line"]]
	var stats := PlayerStats.new()
	stats.configure_prepared_treatment(treatment)
	stats.bind_run_build(RunBuildState.from_treatment(treatment), treatment, prepared)
	var sections := stats.stat_sections(82.0, 100.0, 7.0, 12.0)
	_equal(sections.size(), 4, "Allgemein, Behandlung und zwei Fähigkeiten ergeben vier Sektionen")
	_equal(sections[0].id(), &"general", "Allgemeine Sektion besitzt eine stabile ID")
	_equal(sections[1].id(), &"treatment:treatment_precision", "Behandlungssektion ist content-stabil statt positionsabhängig")
	_equal(sections[2].id(), &"ability:0:ability_defense_burst", "Q-Sektion besitzt Slot und stabile Content-ID")
	_equal(sections[3].id(), &"ability:1:ability_treatment_line", "E-Sektion besitzt Slot und stabile Content-ID")
	var serialized := str(sections[1].rows()) + str(sections[2].rows()) + str(sections[3].rows())
	_true(serialized.findn("px") < 0 and serialized.findn("pixel") < 0, "ViewModel-Daten exponieren keine Pixel- oder px-Einheit")
	_true(serialized.contains("16") and not serialized.contains("Stufe 16"), "Behandlungsreichweite liefert UI-seitig nur die Stufenzahl")
	var potency := _upgrade(&"potency")
	_equal(potency.heading_component_id(treatment.id), treatment.id, "Allgemeines Behandlungsupgrade folgt dynamisch der vorbereiteten Behandlung")
	_equal(potency.resolved_component_name(treatment), "Impuls", "UI erhält nur den aufgelösten Komponentennamen")
	var mobility := _upgrade(&"mobility")
	_equal(mobility.resolved_component_name(treatment), "Bewegung", "Allgemeiner Bewegungsausbau benennt seine Komponente stabil")


func _upgrade(id: StringName) -> UpgradeDefinition:
	for definition in ContentCatalog.upgrade_definitions():
		if definition.id == id:
			return definition
	return null


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s (erwartet %s, erhalten %s)" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, message: String, epsilon: float = 0.001) -> void:
	_true(absf(actual - expected) <= epsilon, "%s (erwartet %.4f, erhalten %.4f)" % [message, expected, actual])
