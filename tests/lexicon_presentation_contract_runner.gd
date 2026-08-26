extends SceneTree

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_structured_type_presentations()
	_test_related_term_presentations()
	_test_character_stat_sections()
	_test_units_and_retired_terms()
	if failures.is_empty():
		print("ALVEOLUS_LEXICON_PRESENTATION_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	push_error("ALVEOLUS_LEXICON_PRESENTATION_FAILED failures=%d assertions=%d" % [failures.size(), assertions])
	quit(1)


func _test_structured_type_presentations() -> void:
	var enemies := ContentCatalog.enemy_definitions()
	var custom: EnemyDefinition = enemies[&"bacterial_cluster"].duplicate(true) as EnemyDefinition
	custom.damage_profile = DamageProfile.from_components(&"presentation_damage", {&"earth": 0.60, &"fire": 0.40})
	custom.resistance_profile = ResistanceProfile.from_components(&"presentation_resistance", {&"earth": 20.0, &"fire": -15.0})
	enemies[&"bacterial_cluster"] = custom
	var provider := LexiconViewModelProvider.new(enemies)
	var entry: LexiconEntryDefinition = LexiconCatalog.entries_by_id()[&"bacterial_cluster"]
	var model := provider.make_view_model(entry, [&"bacterial_cluster"])
	var items := model.type_presentations()
	_equal(items.size(), 8, "Vier Schadensanteile und vier effektive Resistenzen werden strukturiert geliefert")
	for index in range(4):
		_equal(items[index].type_id, DamageTypeCatalog.ALL_IDS[index], "Schadensanteil %d folgt der festen Typreihenfolge" % index)
		_equal(items[index].semantic_role, &"damage_share", "Schadensanteil %d besitzt eine semantische Rolle" % index)
		_equal(items[index + 4].type_id, DamageTypeCatalog.ALL_IDS[index], "Resistenz %d folgt der festen Typreihenfolge" % index)
		_equal(items[index + 4].semantic_role, &"resistance_effective", "Resistenz %d besitzt eine semantische Rolle" % index)
	_near(items[0].percent, 40.0, "Feueranteil wird presentation-ready in Prozent geliefert")
	_near(items[2].percent, 60.0, "Erdanteil wird presentation-ready in Prozent geliefert")
	_near(items[4].percent, -15.0, "Negative Resistenz bleibt lineare Verwundbarkeit")
	_equal(items[4].value_role, &"vulnerability", "Negative Resistenz ist semantisch als Verwundbarkeit markiert")
	_equal(items[4].formatted_value, "-15 %", "Verwundbarkeit ist bereits UI-fertig formatiert")
	_equal(items[4].meaning, "Verwundbarkeit", "Verwundbarkeit liefert die ausgeschriebene Bedeutung")
	_equal(items[4].indicator, &"vulnerability", "Verwundbarkeit liefert den semantischen Indikator")
	_equal(items[4].icon_id, &"damage_fire", "Resistenz nutzt die zentrale Schadenstyp-Iconrolle")
	_near(items[6].percent, MitigationCurve.resistance_effective_percent(20.0), "Positive Resistenz ist bereits über die Core-Kurve aufgelöst")
	_equal(items[6].value_role, &"mitigation", "Positive Resistenz ist semantisch als Minderung markiert")
	_equal(items[6].meaning, "Minderung", "Minderung liefert die ausgeschriebene Bedeutung")
	items.pop_back()
	_equal(model.type_presentations().size(), 8, "Der ViewModel-Getter liefert ein defensiv kopiertes Array")


func _test_related_term_presentations() -> void:
	var provider := LexiconViewModelProvider.create_default()
	var entry: LexiconEntryDefinition = LexiconCatalog.entries_by_id()[&"automatic_therapy"]
	var model := provider.make_view_model(entry, [&"automatic_therapy"])
	var related := model.related_term_presentations()
	_equal(related.size(), 3, "Verwandte Begriffe werden als strukturierte Production-DTOs geliefert")
	_equal(related[0].id, &"basic_treatment", "Related-Term-DTO bewahrt die stabile Terminologie-ID")
	_equal(related[0].display_name, TerminologyCatalog.definition(&"basic_treatment").display_name, "Related-Term-DTO liefert den ausgeschriebenen Namen")
	_equal(related[0].explanation, TerminologyCatalog.definition(&"basic_treatment").summary, "Related-Term-DTO liefert die zentrale Kurzerklärung")
	_equal(related[0].meaning, related[0].explanation, "Tooltip und ui_info teilen dieselbe Bedeutungsquelle")
	_equal(related[0].icon_id, TerminologyCatalog.definition(&"basic_treatment").visual_id, "Related-Term-DTO liefert die zentrale semantische Icon-ID")
	_equal(model.related_names.size(), related.size(), "Die bestehende Namensfassade bleibt kompatibel")
	var first_item := related[0]
	related.pop_back()
	var second_read := model.related_term_presentations()
	_equal(second_read.size(), 3, "Related-Term-Getter liefert ein defensiv kopiertes Array")
	_true(second_read[0] != first_item, "Related-Term-Getter kopiert auch die immutable DTO-Instanzen defensiv")


func _test_character_stat_sections() -> void:
	var provider := LexiconViewModelProvider.create_default()
	var entry: LexiconEntryDefinition = LexiconCatalog.entries_by_id()[&"character_stats"]
	var model := provider.make_view_model(entry)
	var sections := model.stat_section_presentations()
	_equal(sections.size(), 3, "Charakterwerte liefern genau drei präsentationsfertige Gruppen")
	_equal(sections[0].id, &"defense", "Verteidigung steht zuerst")
	_equal(sections[1].id, &"attack", "Angriff steht an zweiter Stelle")
	_equal(sections[2].id, &"other", "Sonstiges steht zuletzt")
	var grouped_ids: Array[StringName] = []
	for section in sections:
		for row in section.rows():
			grouped_ids.append(row.id)
	_equal(grouped_ids.size(), model.stat_rows.size(), "Die Gruppierung behält jede bestehende Charakterwertzeile")
	for row in model.stat_rows:
		_true(grouped_ids.has(row.id), "Die Gruppierung bewahrt den Charakterwert %s" % row.id)
	var first_section := sections[0]
	var first_rows := first_section.rows()
	var original_label := first_rows[0].label
	first_rows[0].label = "Manipuliert"
	sections.pop_back()
	var second_read := model.stat_section_presentations()
	_equal(second_read.size(), 3, "Charakterwertgruppen liefern ein defensiv kopiertes Array")
	_true(second_read[0] != first_section, "Charakterwertgruppen kopieren auch die Sektions-DTOs defensiv")
	_true(second_read[0].rows()[0] != first_rows[0], "Charakterwertgruppen kopieren verschachtelte Wertzeilen defensiv")
	_equal(second_read[0].rows()[0].label, original_label, "Mutationen eines Consumers verändern spätere Charakterwert-Reads nicht")


func _test_units_and_retired_terms() -> void:
	for retired_id in [&"blood_damage", &"holy_damage", &"undead_damage"]:
		_true(not TerminologyCatalog.ENTRIES.has(retired_id), "%s ist aus der aktiven Terminologie entfernt" % String(retired_id))
		_true(TerminologyCatalog.definition(retired_id) == null, "%s erzeugt keine aktive Definition" % String(retired_id))
	_equal(TerminologyCatalog.definition(&"range").unit, "Stufe", "Reichweite verwendet ausschließlich die zentrale Stufeneinheit")
	var provider := LexiconViewModelProvider.create_default()
	var treatment_entry: LexiconEntryDefinition = LexiconCatalog.entries_by_id()[&"automatic_therapy"]
	var treatment_model := provider.make_view_model(treatment_entry, [&"automatic_therapy"])
	var range_row: StatRowViewModel
	for row in treatment_model.stat_rows:
		if row.id == &"range":
			range_row = row
			break
	_true(range_row != null, "Behandlungslexikon liefert eine zentrale Reichweitenzeile")
	_equal(range_row.formatted_value() if range_row != null else "", "16", "UI-facing Reichweite enthält nur die Stufenzahl")
	for entry in LexiconCatalog.entries():
		var seen := [entry.discovery_id] if not entry.discovery_id.is_empty() else []
		var model := provider.make_view_model(entry, seen)
		for row in model.stat_rows:
			var rendered := "%s %s" % [row.formatted_value(), row.description]
			_true(rendered.findn("px") < 0 and rendered.findn("pixel") < 0 and rendered.findn("weltpunkt") < 0, "%s/%s exponiert keine technische Distanzeinheit" % [entry.id, row.id])


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s (erwartet %s, erhalten %s)" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, message: String, epsilon: float = 0.001) -> void:
	_true(absf(actual - expected) <= epsilon, "%s (erwartet %.4f, erhalten %.4f)" % [message, expected, actual])
