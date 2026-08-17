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
		&"talent_points", &"mastery", &"contact_damage", &"cooldown", &"boss_phase",
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
	_check(TerminologyCatalog.definition(&"treatment_speed").gameplay_text.contains("verkürzt das Intervall"), "Behandlungstempo wird über das Intervall erklärt")
	_check(TerminologyCatalog.definition(&"support_path").gameplay_text.contains("keinen direkten Schaden"), "Atemhilfe wird ohne Gegnerschaden erklärt")

func _test_enemy_values_are_sourced() -> void:
	var provider := LexiconViewModelProvider.create_default()
	var entries := LexiconCatalog.entries_by_id()
	var enemies := ContentCatalog.enemy_definitions()
	for id in [&"pneumococcus", &"bacterial_cluster", &"minor_focus", &"infection_focus"]:
		var enemy: EnemyDefinition = enemies[id]
		var model := provider.make_view_model(entries[id], [id])
		_check(not model.locked, "%s ist nach Entdeckung lesbar" % id)
		_assert_numeric_row(model, &"health", enemy.max_health, enemy.id, &"max_health")
		_assert_numeric_row(model, &"speed", enemy.speed, enemy.id, &"speed")
		_assert_numeric_row(model, &"contact_damage", enemy.contact_damage, enemy.id, &"contact_damage")
		_assert_numeric_row(model, &"sample_value", enemy.analysis_value, enemy.id, &"analysis_value")
		_check(not model.gameplay_text.contains("GRUNDWERTE"), "%s dupliziert keine Zahlen im Beschreibungstext" % id)

func _test_character_values_are_sourced() -> void:
	var stats := PlayerStats.new()
	stats.therapy_damage = 31.5
	stats.therapy_cooldown = 0.67
	stats.therapy_range = 512.0
	stats.therapy_targets = 3
	stats.therapy_projectiles = 2
	stats.pickup_range = 222.0
	var provider := LexiconViewModelProvider.new({}, {}, stats)
	var entry: LexiconEntryDefinition = LexiconCatalog.entries_by_id()[&"character_stats"]
	var model := provider.make_view_model(entry)
	_assert_numeric_row(model, &"treatment_damage", stats.therapy_damage, &"player_stats", &"therapy_damage")
	_assert_numeric_row(model, &"treatment_interval", stats.therapy_cooldown, &"player_stats", &"therapy_cooldown")
	_assert_numeric_row(model, &"treatment_range", stats.therapy_range, &"player_stats", &"therapy_range")
	_assert_numeric_row(model, &"treatment_targets", stats.therapy_targets, &"player_stats", &"therapy_targets")
	_assert_numeric_row(model, &"treatment_projectiles", stats.therapy_projectiles, &"player_stats", &"therapy_projectiles")
	_assert_numeric_row(model, &"pickup_range", stats.pickup_range, &"player_stats", &"pickup_range")
	_assert_numeric_row(model, &"movement_speed", TherapyAvatar.MOVE_SPEED, &"therapy_avatar", &"MOVE_SPEED")

func _test_gameplay_values_are_sourced() -> void:
	var entries := LexiconCatalog.entries_by_id()
	var provider := LexiconViewModelProvider.create_default()
	var treatment: TreatmentDefinition = TreatmentDefinition.catalog()[&"treatment_precision"]
	var treatment_model := provider.make_view_model(entries[&"automatic_therapy"], [&"automatic_therapy"])
	_assert_numeric_row(treatment_model, &"damage", treatment.base_damage, treatment.id, &"base_damage")
	_assert_numeric_row(treatment_model, &"interval", treatment.base_interval, treatment.id, &"base_interval")
	_assert_numeric_row(treatment_model, &"range", treatment.base_range, treatment.id, &"base_range")

	var immune_stats := PlayerStats.new()
	immune_stats.immune_level = 1
	var immune_model := provider.make_view_model(entries[&"neutrophil_orbit"], [&"neutrophil_orbit"])
	_assert_numeric_row(immune_model, &"cells", immune_stats.immune_cell_count(), &"player_stats", &"immune_cell_count")
	_assert_numeric_row(immune_model, &"immune_interval", immune_stats.immune_interval(), &"player_stats", &"immune_interval")

	var support_stats := PlayerStats.new()
	support_stats.support_level = 1
	var support_model := provider.make_view_model(entries[&"supportive_oxygenation"], [&"supportive_oxygenation"])
	_assert_numeric_row(support_model, &"support_recovery", support_stats.support_recovery(), &"player_stats", &"support_recovery")
	_assert_numeric_row(support_model, &"support_interval", support_stats.support_interval(), &"player_stats", &"support_interval")

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

func _row(model: LexiconEntryViewModel, id: StringName) -> StatRowViewModel:
	for row in model.stat_rows:
		if row.id == id:
			return row
	return null

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
