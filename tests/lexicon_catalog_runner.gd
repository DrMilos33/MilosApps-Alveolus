extends SceneTree

var assertions := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_categories_and_terms()
	_test_enemy_values_are_sourced()
	_test_character_values_are_sourced()
	_test_gameplay_values_are_sourced()
	_test_discovery_locks_and_visuals()
	if failures.is_empty():
		print("ALVEOLUS_LEXICON_CATALOG_OK assertions=%d" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _test_categories_and_terms() -> void:
	_check(LexiconCatalog.CATEGORY_ORDER == [&"monsters", &"character", &"gameplay", &"terms"], "Kategorien besitzen die vereinbarte Reihenfolge")
	var by_id := LexiconCatalog.entries_by_id()
	_check(by_id.size() == LexiconCatalog.entries().size(), "Jeder Lexikoneintrag besitzt eine eindeutige ID")
	for category in LexiconCatalog.CATEGORY_ORDER:
		_check(not LexiconCatalog.entries_for_category(category).is_empty(), "%s ist nicht leer" % LexiconCatalog.category_name(category))
	var required_terms := [
		&"patient_stability", &"analysis", &"level", &"effect", &"treatment_speed", &"interval",
		&"range", &"targets", &"projectiles", &"penetration", &"immune_path", &"support_path",
		&"shield", &"finding", &"finding_progress", &"case_trait", &"basic_treatment",
		&"active_ability", &"passive_module", &"reserve", &"capacity", &"research",
		&"talent_points", &"mastery", &"enemy_damage", &"defense", &"life_regeneration",
		&"resistance", &"fire_damage", &"water_damage", &"earth_damage", &"wind_damage",
		&"cooldown", &"boss_phase",
	]
	for id in required_terms:
		var term := TerminologyCatalog.definition(id)
		_check(term != null, "Begriff %s ist definiert" % id)
		if term != null:
			_check(not term.summary.is_empty() and not term.gameplay_text.is_empty(), "Begriff %s erklärt Bedeutung und Spielwirkung" % id)
			if id == &"reserve":
				_check(not by_id.has(&"term_reserve"), "Der kompatible Reservebegriff bleibt verborgen, solange der Planplatz ruht")
			else:
				_check(by_id.has(StringName("term_%s" % id)), "Begriff %s erscheint im Lexikon" % id)
	for term in TerminologyCatalog.all():
		_check(SimpleIcon.supports(term.visual_id), "Der produktive verwandte Begriff %s besitzt eine registrierte zentrale Glyphe" % term.id)
	_check(TerminologyCatalog.definition(&"treatment_speed").gameplay_text.contains("höherer Attack Speed"), "Attack Speed wird als sichtbare Rate erklärt")
	_check(TerminologyCatalog.definition(&"support_path").gameplay_text.contains("keinen direkten Schaden"), "Regeneration wird ohne Gegnerschaden erklärt")
	_check(TerminologyCatalog.simple(&"patient_stability") == "Leben", "Leben ersetzt Zustand")
	_check(TerminologyCatalog.simple(&"effect") == "Schaden", "Schaden ersetzt Wirkung")
	_check(TerminologyCatalog.simple(&"support_path") == "Regeneration", "Regeneration ersetzt Atemhilfe")
	_check(TerminologyCatalog.simple(&"shield") == "Schild", "Schild ersetzt Schutz")
	_check(TerminologyCatalog.definition(&"contact_damage") == null, "Kontaktschaden ist kein sichtbarer Lexikonbegriff")

func _test_enemy_values_are_sourced() -> void:
	var provider := LexiconViewModelProvider.create_default()
	var entries := LexiconCatalog.entries_by_id()
	var enemies := ContentCatalog.enemy_definitions()
	for id in [&"pneumococcus", &"bacterial_cluster", &"minor_focus", &"localized_boss", &"infection_focus"]:
		var enemy: EnemyDefinition = enemies[id]
		var model := provider.make_view_model(entries[id], [id])
		_check(not model.locked, "%s ist nach Entdeckung lesbar" % id)
		_assert_numeric_row(model, &"health", enemy.max_health, enemy.id, &"max_health")
		_assert_numeric_row(model, &"speed", enemy.speed, enemy.id, &"speed")
		_assert_numeric_row(model, &"damage", enemy.base_damage, enemy.id, &"base_damage")
		_assert_text_row(model, &"damage_types", enemy.id, &"damage_profile")
		_assert_text_row(model, &"resistances", enemy.id, &"resistance_profile")
		_assert_numeric_row(model, &"sample_value", enemy.analysis_value, enemy.id, &"analysis_value")
		_check(not model.gameplay_text.contains("GRUNDWERTE"), "%s dupliziert keine Zahlen im Beschreibungstext" % id)

	var rebound_enemies := enemies.duplicate()
	var rebound_enemy: EnemyDefinition = (enemies[&"pneumococcus"] as EnemyDefinition).duplicate(true) as EnemyDefinition
	rebound_enemy.damage_profile = DamageProfile.from_components(&"lexicon_binding_damage", {&"fire": 0.25, &"wind": 0.75})
	rebound_enemy.resistance_profile = ResistanceProfile.from_components(&"lexicon_binding_resistance", {&"water": 30.0, &"fire": -20.0})
	rebound_enemies[&"pneumococcus"] = rebound_enemy
	var rebound_provider := LexiconViewModelProvider.new(rebound_enemies)
	var rebound_model := rebound_provider.make_view_model(entries[&"pneumococcus"], [&"pneumococcus"])
	var damage_types_row := _row(rebound_model, &"damage_types")
	var resistances_row := _row(rebound_model, &"resistances")
	_check(damage_types_row != null and damage_types_row.source_field == &"damage_profile", "Kompatibler Schadenstyptext dokumentiert weiterhin ausschließlich seine Quelldefinition")
	_check(resistances_row != null and resistances_row.source_field == &"resistance_profile", "Kompatibler Resistenztext dokumentiert weiterhin ausschließlich seine Quelldefinition")
	var type_presentations := rebound_model.type_presentations()
	_check(type_presentations.size() == 8, "Das Lexikon liefert vier Schadensanteile und vier effektive Resistenzen als strukturierte DTOs")
	for index in range(4):
		_check(type_presentations[index].type_id == DamageTypeCatalog.ALL_IDS[index], "Schadensanteile folgen der festen Reihenfolge Feuer, Wasser, Erde, Wind")
		_check(type_presentations[index + 4].type_id == DamageTypeCatalog.ALL_IDS[index], "Resistenzen folgen der festen Reihenfolge Feuer, Wasser, Erde, Wind")
		_check(type_presentations[index].icon_id == StringName("damage_%s" % DamageTypeCatalog.ALL_IDS[index]), "Jeder Schadensanteil besitzt eine zentrale Iconrolle")
		_check(not type_presentations[index].display_name.is_empty() and not type_presentations[index].formatted_value.is_empty(), "Jeder Schadensanteil liefert Name und fertig formatierten Wert")
	_check(type_presentations[4].formatted_value == "-20 %" and type_presentations[4].meaning == "Verwundbarkeit", "Negative Feuerresistenz wird als fertige Verwundbarkeit präsentiert")
	_check(type_presentations[5].meaning == "Minderung", "Positive Wasserresistenz wird bereits als effektive Minderung präsentiert")

func _test_character_values_are_sourced() -> void:
	var stats := PlayerStats.new()
	stats.therapy_damage = 31.5
	stats.therapy_cooldown = 0.67
	stats.therapy_range = 512.0
	stats.therapy_targets = 3
	stats.therapy_projectiles = 2
	stats.pickup_range = 222.0
	stats.max_stability_bonus = 17.0
	stats.defense = 4.5
	stats.life_regeneration_per_second = 1.25
	var provider := LexiconViewModelProvider.new({}, {}, stats)
	var entry: LexiconEntryDefinition = LexiconCatalog.entries_by_id()[&"character_stats"]
	var model := provider.make_view_model(entry)
	_assert_numeric_row(model, &"treatment_damage", stats.therapy_damage, &"player_stats", &"therapy_damage")
	_assert_text_row(model, &"treatment_interval", &"player_stats", &"therapy_cooldown")
	_check(String(_row(model, &"treatment_interval").value) == "1,49/s", "Attack Speed wird als fertige Rate statt als Intervallzahl präsentiert")
	_assert_numeric_row(model, &"treatment_range", CombatDistanceScale.stage_from_world(stats.therapy_range), &"player_stats", &"therapy_range_stage")
	_assert_numeric_row(model, &"treatment_targets", stats.therapy_targets, &"player_stats", &"therapy_targets")
	_assert_numeric_row(model, &"treatment_projectiles", stats.therapy_projectiles, &"player_stats", &"therapy_projectiles")
	_assert_numeric_row(model, &"pickup_range", CombatDistanceScale.stage_from_world(stats.pickup_range), &"player_stats", &"pickup_range_stage")
	_assert_numeric_row(model, &"max_life", PlayerStats.BASE_MAX_HEALTH + stats.max_stability_bonus, &"player_stats", &"max_stability_bonus")
	_assert_numeric_row(model, &"defense", MitigationCurve.defense_effective_percent(stats.defense), &"player_stats", &"defense")
	_assert_numeric_row(model, &"life_regeneration", stats.life_regeneration_per_second, &"player_stats", &"life_regeneration_per_second")
	_assert_text_row(model, &"resistances", &"player_stats", &"resistances")
	_assert_numeric_row(model, &"movement_speed", stats.movement_speed, &"player_stats", &"movement_speed")
	_check(model.medical_name.is_empty(), "Doctor Milos zeigt keinen Therapieavatar-Untertitel")
	_check(model.summary == "Der beste Doctor mit Bandana.", "Doctor Milos verwendet die gewünschte Beschreibung")

func _test_gameplay_values_are_sourced() -> void:
	var entries := LexiconCatalog.entries_by_id()
	var provider := LexiconViewModelProvider.create_default()
	var treatment: TreatmentDefinition = TreatmentDefinition.catalog()[&"treatment_precision"]
	var treatment_model := provider.make_view_model(entries[&"automatic_therapy"], [&"automatic_therapy"])
	_assert_numeric_row(treatment_model, &"damage", treatment.base_damage, treatment.id, &"base_damage")
	_assert_text_row(treatment_model, &"interval", treatment.id, &"base_interval")
	_check(String(_row(treatment_model, &"interval").value) == "1,04/s", "Die langsamere Grundbehandlung liefert ihre fertig formatierte Rate")
	_assert_numeric_row(treatment_model, &"range", treatment.base_range_stage(), treatment.id, &"base_range_stage")

	var immune_stats := PlayerStats.new()
	immune_stats.immune_level = 1
	var immune_model := provider.make_view_model(entries[&"neutrophil_orbit"], [&"neutrophil_orbit"])
	_assert_numeric_row(immune_model, &"cells", immune_stats.immune_cell_count(), &"player_stats", &"immune_cell_count")
	_assert_text_row(immune_model, &"immune_interval", &"player_stats", &"immune_interval")
	_check(String(_row(immune_model, &"immune_interval").value) == "5/s", "Abwehrzellen liefern ihren halbierten fertig formatierten Attack Speed")

	var regeneration_stats := PlayerStats.new()
	regeneration_stats.life_regeneration_per_second = 2.75
	var regeneration_provider := LexiconViewModelProvider.new({}, {}, regeneration_stats)
	var regeneration_entry: LexiconEntryDefinition = entries[&"supportive_oxygenation"]
	var regeneration_model := regeneration_provider.make_view_model(regeneration_entry, [])
	_check(regeneration_entry.unlocked_by_default and not regeneration_model.locked, "Regeneration ist von Anfang an lesbar")
	_assert_numeric_row(regeneration_model, &"life_regeneration", regeneration_stats.life_regeneration_per_second, &"player_stats", &"life_regeneration_per_second")
	_check(_row(regeneration_model, &"support_recovery") == null and _row(regeneration_model, &"support_interval") == null, "Regeneration verwendet keine alten Supportwerte")
	_check(regeneration_model.medical_name == "Lebensregeneration", "Regeneration besitzt keinen alten Supportnamen")

func _test_discovery_locks_and_visuals() -> void:
	var provider := LexiconViewModelProvider.create_default()
	for entry in LexiconCatalog.entries():
		_check(not entry.visual_id.is_empty(), "%s besitzt eine Illustration ID" % entry.id)
		var locked_model := provider.make_view_model(entry, [])
		if entry.unlocked_by_default or entry.discovery_id.is_empty():
			_check(not locked_model.locked, "%s ist standardmäßig lesbar" % entry.id)
		else:
			_check(locked_model.locked, "%s bleibt vor der Entdeckung verborgen" % entry.id)
			_check(locked_model.stat_rows.is_empty(), "%s verrät gesperrt keine Werte" % entry.id)
			var seen_model := provider.make_view_model(entry, [entry.discovery_id])
			_check(not seen_model.locked, "%s wird mit Discovery ID freigeschaltet" % entry.id)

func _assert_numeric_row(model: LexiconEntryViewModel, id: StringName, expected: float, source_id: StringName, source_field: StringName) -> void:
	var row := _row(model, id)
	_check(row != null, "%s enthält Wert %s" % [model.id, id])
	if row == null:
		return
	_check(is_equal_approx(float(row.value), expected), "%s.%s entspricht der Quelldefinition" % [model.id, id])
	_check(row.source_id == source_id and row.source_field == source_field, "%s.%s dokumentiert seine Wertquelle" % [model.id, id])

func _assert_text_row(model: LexiconEntryViewModel, id: StringName, source_id: StringName, source_field: StringName) -> void:
	var row := _row(model, id)
	_check(row != null, "%s enthält Wert %s" % [model.id, id])
	if row == null:
		return
	_check(not String(row.value).is_empty(), "%s.%s besitzt einen lesbaren Datenwert" % [model.id, id])
	_check(row.source_id == source_id and row.source_field == source_field, "%s.%s dokumentiert seine Wertquelle" % [model.id, id])

func _row(model: LexiconEntryViewModel, id: StringName) -> StatRowViewModel:
	for row in model.stat_rows:
		if row.id == id:
			return row
	return null

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
