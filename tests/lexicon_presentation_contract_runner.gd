extends SceneTree

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_structured_type_presentations()
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


func _test_units_and_retired_terms() -> void:
	for retired_id in [&"blood_damage", &"holy_damage", &"undead_damage"]:
		_true(not TerminologyCatalog.ENTRIES.has(retired_id), "%s ist aus der aktiven Terminologie entfernt" % String(retired_id))
		_true(TerminologyCatalog.definition(retired_id) == null, "%s erzeugt keine aktive Definition" % String(retired_id))
	_equal(TerminologyCatalog.definition(&"range").unit, "Stufe", "Reichweite verwendet ausschließlich die zentrale Stufeneinheit")
	var provider := LexiconViewModelProvider.create_default()
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
