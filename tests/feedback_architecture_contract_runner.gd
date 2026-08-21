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
	_test_presentation_apis()
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
	_near(treatments[&"treatment_precision"].base_damage, 13.0, "Impuls besitzt ganzzahligen Basisschaden")
	_near(treatments[&"treatment_precision"].base_interval, 0.965, "Impuls besitzt den um fünfzehn Prozent verlangsamten Attack Speed")
	_near(treatments[&"treatment_spread"].base_damage, 5.0, "Streubehandlung besitzt 5 Schaden")
	_near(treatments[&"treatment_pierce"].base_damage, 9.0, "Durchdringende Behandlung besitzt 9 Schaden")
	_near(treatments[&"treatment_pierce"].base_interval, 1.65, "Durchdringende Behandlung besitzt 1,65 Sekunden Intervall")
	var abilities := AbilityDefinition.catalog()
	_near(float(abilities[&"ability_defense_burst"].parameters["damage"]), 0.0, "Stoß beginnt ohne Schaden")
	_near(float(abilities[&"ability_defense_burst"].parameters["knockback"]), 120.0, "Abwehrstoß besitzt den stärkeren Rückstoß")
	_near(float(abilities[&"ability_treatment_line"].parameters["damage"]), 30.0, "Behandlungslinie besitzt 30 Schaden")
	var enemies := ContentCatalog.enemy_definitions()
	_near(enemies[&"pneumococcus"].speed, 45.0, "Bakterium besitzt Geschwindigkeit 45")
	_near(enemies[&"bacterial_cluster"].speed, 45.0, "Bakteriengruppe besitzt Geschwindigkeit 45")
	_near(enemies[&"minor_focus"].speed, 20.0, "Kleiner Herd besitzt Geschwindigkeit 20")
	_near(enemies[&"infection_focus"].speed, 30.0, "Boss besitzt Geschwindigkeit 30")
	var stats := PlayerStats.new()
	stats.configure_prepared_treatment(treatments[&"treatment_precision"])
	stats.apply_meta_progression({&"movement_training": 3})
	_near(stats.movement_speed, 196.0, "Galoppforschung löst auf einen ganzzahligen Wert auf")
	var build := RunBuildState.from_treatment(treatments[&"treatment_precision"])
	stats.bind_run_build(build, treatments[&"treatment_precision"])
	var mobility := _upgrade(&"mobility")
	for rank in range(3):
		_true(stats.apply_upgrade(mobility), "Mobilitätsausbau Rang %d wird angewandt" % (rank + 1))
	_near(stats.movement_speed, 205.0, "Common-Galoppausbau addiert je Wahl drei und bleibt ganzzahlig")
	_equal(PlayerStats.BASE_MOVEMENT_SPEED, 180.0, "Doctor-Basisgeschwindigkeit ist zentral 180")
	_equal(TherapyAvatar.MOVE_SPEED, PlayerStats.BASE_MOVEMENT_SPEED, "Avatar-Fallback ist an die zentrale Doctor-Basis gekoppelt")
	_equal(TherapyProjectile.DEFAULT_SPEED, 576.0, "Impuls-Projektile verwenden die um zwanzig Prozent reduzierte Geschwindigkeit")
	_equal(treatments[&"treatment_precision"].display_name, "Impuls", "Die stabile Behandlungs-ID erhält den sichtbaren Namen Impuls")
	_equal(ContentCatalog.loadout_module_definitions()[&"treatment_precision"].title, "Impuls", "Einsatzplanung verwendet denselben sichtbaren Namen")


func _test_reward_preview() -> void:
	var meta := MetaProgressionState.new(func() -> int: return 1_700_000_000)
	meta.reset_defaults(1_700_000_000)
	var preview := MetaProgressionState.calculate_run_reward(false, 367.0, 6, 47, 1.35)
	_equal(preview, 44, "Globale Forschungssteigerung skaliert die bestehende Niederlagenformel")
	_equal(MetaProgressionState.calculate_run_reward(false, 367.0, 6, 47, 1.35, 1), 55, "Ein besiegter Boss multipliziert die Endbelohnung")
	_equal(MetaProgressionState.calculate_run_reward(false, 367.0, 6, 47, 1.35, 2), 66, "Zwei Bosse liefern den additiven Bossmultiplikator")
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
	_true(stats.apply_upgrade(_upgrade(&"precision_refinement")), "Common-Behandlungsschaden wird auf den Live-Build angewandt")
	_true(stats.apply_upgrade(_upgrade(&"treatment_damage_magic")), "Magic-Behandlungsschaden wird auf denselben Live-Build angewandt")
	_true(stats.apply_upgrade(_upgrade(&"potency")), "Rare-Behandlungsschaden wird auf denselben Live-Build angewandt")
	_true(stats.apply_upgrade(_upgrade(&"line_effect")), "Der ausgerüstete Lazer wird auf demselben Live-Build ausgebaut")
	var live_sections := stats.stat_sections(82.0, 100.0, 7.0, 12.0)
	_equal(_section_value(live_sections, &"treatment:treatment_precision", &"damage"), "28", "Pausenwerte zeigen den akkumulierten Common-, Magic- und Rare-Impulsschaden")
	_equal(_section_value(live_sections, &"ability:0:ability_defense_burst", &"damage"), "0", "Stoß bleibt in den aktuellen Charakterwerten ausdrücklich schadensfrei")
	_equal(_section_value(live_sections, &"ability:1:ability_treatment_line", &"damage"), "33", "Pausenwerte zeigen den aktuellen Lazerwert nach Run-Ausbau")
	var potency := _upgrade(&"potency")
	_equal(potency.heading_component_id(treatment.id), treatment.id, "Allgemeines Behandlungsupgrade folgt dynamisch der vorbereiteten Behandlung")
	_equal(potency.resolved_component_name(treatment), "Impuls", "UI erhält nur den aufgelösten Komponentennamen")
	var mobility := _upgrade(&"mobility")
	_equal(mobility.resolved_component_name(treatment), "Galopp", "Allgemeiner Galoppausbau benennt seine Komponente stabil")
	_true(stats.apply_upgrade(_upgrade(&"neutrophils")), "Abwehrzellen können im Run erworben werden")
	var acquired_sections := stats.stat_sections(82.0, 100.0, 7.0, 12.0)
	_equal(acquired_sections.size(), 5, "Eine im Run erworbene Fähigkeit erscheint sofort als eigene Charakterwertsektion")
	_equal(acquired_sections[4].id(), &"ability:run:defense_cells", "Erworbene Abwehrzellen besitzen eine stabile dynamische Sektions-ID")
	_true(str(acquired_sections[4].rows()).contains("5/s"), "Abwehrzellen zeigen den halbierten Attack Speed")


func _test_presentation_apis() -> void:
	var research_by_id: Dictionary = {}
	for definition in ContentCatalog.research_definitions():
		research_by_id[definition.id] = definition
	var expected_totals := {
		&"stability_reserve": "+9 Leben",
		&"therapy_precision": "+6 % Schaden",
		&"experience_gain": "+15 % Erfahrung",
		&"defense_training": "+6 Verteidigung",
		&"life_regeneration": "+0,75/s",
		&"movement_training": "+9 % Galopp",
		&"unlock_spread_treatment": "Freigeschaltet",
		&"unlock_piercing_treatment": "Freigeschaltet",
	}
	for id in expected_totals:
		var definition := research_by_id[id] as ResearchDefinition
		_equal(definition.total_effect_text(definition.max_level), expected_totals[id], "Forschung %s liefert die fertige Gesamtwirkung" % String(id))
	_equal((research_by_id[&"stability_reserve"] as ResearchDefinition).total_value_for_rank(3), 9.0, "Forschungswert wird zentral über den Rang aufgelöst")

	var treatment := TreatmentDefinition.catalog()[&"treatment_precision"] as TreatmentDefinition
	_equal(_upgrade(&"potency").resolved_icon_id(treatment), &"treatment_precision", "Allgemeines Behandlungsupgrade erbt die vorbereitete Komponenten-ID")
	_equal(_upgrade(&"burst_radius").resolved_icon_id(treatment), &"ability_defense_burst", "Stoß-Radiusupgrade liefert direkt die stabile Ability-ID")
	_equal(_upgrade(&"phagocytosis").resolved_icon_id(treatment), &"neutrophil_orbit", "Abwehrzellenupgrade liefert das zentrale Neutrophilen-Icon")
	_equal(_upgrade(&"mobility").resolved_icon_id(treatment), &"movement_training", "Geschwindigkeitsupgrade liefert das zentrale Forschungs-Icon")
	_equal(CombatRateScale.formatted_per_second(0.82), "1,22/s", "Interne Behandlung 0,82 s wird zentral als sichtbare Rate formatiert")
	_equal(CombatRateScale.formatted_per_second(0.2), "5/s", "Abwehrzellen-Basisfrequenz wird als halbierter Attack Speed präsentiert")
	var defense_stats := PlayerStats.new()
	var defense_preview := defense_stats.preview_upgrade(_upgrade(&"neutrophils"))
	_true(defense_preview.after_value.contains("Radius 4"), "Abwehrzellen-Vorschau liefert den zentralen Radius 4")
	var spread := TreatmentDefinition.catalog()[&"treatment_spread"] as TreatmentDefinition
	var spread_stats := PlayerStats.new()
	spread_stats.configure_prepared_treatment(spread)
	_equal(spread_stats.preview_upgrade(_upgrade(&"potency")).presentation_icon_id, &"treatment_spread", "Preview-Icon folgt auch bei allgemeinen Upgrades der vorbereiteten Behandlung")

	var research_reward := RewardPresentation.research(12)
	_equal(research_reward.stable_id(), &"research", "Forschungsbelohnung besitzt eine stabile DTO-ID")
	_equal(research_reward.icon_id(), &"research", "Forschungsbelohnung besitzt die zentrale Icon-ID")
	_equal(research_reward.value(), "+12", "Forschungsbelohnung trennt den reinen Wert von der Beschriftung")
	_equal(research_reward.accessibility_text(), "Forschung: +12", "Forschungsbelohnung liefert fertige Accessibility-Copy")
	var experience_reward := RewardPresentation.experience(9)
	_equal(experience_reward.value(), "+9", "Erfahrungsbelohnung liefert ebenfalls nur den reinen Wert")
	_equal(experience_reward.icon_id(), &"analysis_pickup", "Erfahrungsbelohnung bewahrt die stabile interne Icon-ID")


func _upgrade(id: StringName) -> UpgradeDefinition:
	for definition in ContentCatalog.upgrade_definitions():
		if definition.id == id:
			return definition
	return null


func _section_value(sections: Array[StatSectionViewModel], section_id: StringName, row_id: StringName) -> String:
	for section in sections:
		if section == null or section.id() != section_id:
			continue
		for row in section.rows():
			if StringName(row.get("id", &"")) == row_id:
				return String(row.get("value", ""))
	return ""


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s (erwartet %s, erhalten %s)" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, message: String, epsilon: float = 0.001) -> void:
	_true(absf(actual - expected) <= epsilon, "%s (erwartet %.4f, erhalten %.4f)" % [message, expected, actual])
