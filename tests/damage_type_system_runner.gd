extends SceneTree

var assertions: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_type_catalog()
	_test_compiled_profiles()
	_test_damage_resolution()
	_test_combat_definition_profiles()
	_test_catalog_validation()
	_test_ranked_talent_catalog()
	if failures.is_empty():
		print("ALVEOLUS_DAMAGE_TYPE_SYSTEM_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	push_error("ALVEOLUS_DAMAGE_TYPE_SYSTEM_FAILED failures=%d assertions=%d" % [failures.size(), assertions])
	quit(1)


func _test_type_catalog() -> void:
	var definitions := DamageTypeCatalog.definitions()
	_equal(definitions.size(), 4, "Der Katalog enthält exakt vier aktive Schadenstypen")
	_equal(DamageTypeCatalog.ALL_IDS, [&"fire", &"water", &"earth", &"wind"], "Die aktiven Typ-IDs besitzen die feste Reihenfolge")
	for type_index in range(DamageTypeCatalog.count()):
		var id := DamageTypeCatalog.id_at(type_index)
		_true(DamageTypeCatalog.is_valid_id(id), "%s ist eine gültige Typ-ID" % String(id))
		_equal(DamageTypeCatalog.index_of(id), type_index, "%s roundtript über den festen Index" % String(id))
	for retired_id in DamageTypeCatalog.RETIRED_LEGACY_IDS:
		_true(not DamageTypeCatalog.is_valid_id(retired_id), "%s bleibt außerhalb des aktiven Katalogs" % String(retired_id))
	_equal(DamageTypeCatalog.canonicalize_legacy_authoring_id(&"blood"), &"fire", "Legacy-Blut wird nur im expliziten Importpfad canonicalisiert")


func _test_compiled_profiles() -> void:
	var mixed := DamageProfile.from_components(&"mixed", {&"earth": 3.0, &"fire": 2.0})
	_true(mixed.is_valid(), "Ein gemischtes Profil wird gültig vorkompiliert")
	_equal(mixed.weights.size(), 4, "Das Schadensprofil besitzt exakt vier gepackte Werte")
	_near(mixed.weight_for_type(&"earth"), 0.6, "Komponenten werden normalisiert")
	_near(mixed.weight_for_type(&"fire"), 0.4, "Die zweite Komponente bleibt anteilig erhalten")
	_equal(mixed.dominant_type_id(), &"earth", "Der dominante Schadenstyp ist deterministisch")
	var neutral := ResistanceProfile.neutral(&"player_base")
	_true(neutral.is_valid() and neutral.is_neutral(), "Standardresistenzen sind vollständig und null")
	_equal(neutral.ratings.size(), 4, "Das Resistenzprofil besitzt exakt vier gepackte Ratings")
	_equal(neutral.multipliers.size(), 4, "Effektive Multiplikatoren werden einmalig vorkompiliert")
	var unknown := DamageProfile.single(&"unknown", &"plasma")
	_true(not unknown.is_valid(), "Unbekannte neue Schadenstypen schlagen die Profilvalidation fehl")
	var unknown_resistance := ResistanceProfile.from_components(&"unknown_resistance", {&"plasma": 10.0})
	_true(not unknown_resistance.is_valid(), "Unbekannte neue Resistenztypen schlagen die Profilvalidation fehl")
	var legacy := DamageProfile.from_legacy_authoring_components(&"legacy", {&"blood": 1.0})
	_true(legacy.is_valid(), "Der explizite Legacy-Authoring-Pfad bleibt migrierbar")
	_near(legacy.weight_for_type(&"fire"), 1.0, "Legacy-Blut canonicalisiert explizit auf Feuer")


func _test_damage_resolution() -> void:
	var fire := DamageProfile.single(&"fire_test", &"fire")
	_near(CombatDamageResolver.resolve(100.0, fire), 100.0, "Nullresistenz verändert den Schaden nicht")
	var resistant := ResistanceProfile.from_components(&"resistant", {&"fire": 25.0})
	_near(CombatDamageResolver.resolve(100.0, fire, resistant), 81.25, "Positive Typresistenz folgt der 75-Prozent-Kurve")
	var vulnerable := ResistanceProfile.from_components(&"vulnerable", {&"fire": -20.0})
	_near(CombatDamageResolver.resolve(100.0, fire, vulnerable), 120.0, "Negative Resistenz erhöht den Schaden")
	_near(CombatDamageResolver.resolve(100.0, fire, null, 100.0), 100.0 * MitigationCurve.defense_multiplier(100.0), "Defense folgt nach Resistenz der 90-Prozent-Kurve")
	var mixed := DamageProfile.from_components(&"mixed_test", {&"earth": 0.60, &"fire": 0.40})
	var mixed_resistance := ResistanceProfile.from_components(&"mixed_resistance", {&"earth": 20.0, &"fire": -15.0})
	var expected_mixed := 100.0 * (0.60 * MitigationCurve.resistance_multiplier(20.0) + 0.40 * MitigationCurve.resistance_multiplier(-15.0))
	_near(CombatDamageResolver.resolve(100.0, mixed, mixed_resistance), expected_mixed, "Gemischter Schaden löst jeden Anteil getrennt auf")
	_near(CombatDamageResolver.resolve(100.0, mixed, mixed_resistance, 100.0), expected_mixed * MitigationCurve.defense_multiplier(100.0), "Defense wird nach der gemischten Typresistenz angewendet")
	_near(CombatDamageResolver.resolve(100.0, null, null, 100.0), 100.0 * MitigationCurve.defense_multiplier(100.0), "Ein Profilloser Schaden behält neutrale Typwirkung")


func _test_combat_definition_profiles() -> void:
	var treatments := TreatmentDefinition.catalog()
	_equal(treatments[&"treatment_precision"].damage_profile.dominant_type_id(), &"water", "Präziser Impuls verursacht Wasserschaden")
	_equal(treatments[&"treatment_spread"].damage_profile.dominant_type_id(), &"fire", "Streuimpuls verursacht Feuerschaden")
	_equal(treatments[&"treatment_pierce"].damage_profile.dominant_type_id(), &"wind", "Durchdringender Impuls verursacht Windschaden")
	var abilities := AbilityDefinition.catalog()
	_equal(abilities[&"ability_defense_burst"].damage_profile.dominant_type_id(), &"earth", "Abwehrstoß verursacht Erdschaden")
	_equal(abilities[&"ability_treatment_line"].damage_profile.dominant_type_id(), &"water", "Behandlungslinie verursacht Wasserschaden")
	for id in [&"ability_focus_field", &"ability_emergency_support", &"ability_protection_field", &"ability_sample_pull"]:
		_true(abilities[id].damage_profile == null, "%s deklariert als nicht schädigende Fähigkeit kein Scheinprofil" % String(id))
	var bacterium := EnemyDefinition.create(&"pneumococcus", "Bakterium", 22.0, 83.0, 2.2, 1, 18.0, Color.WHITE)
	_equal(bacterium.damage_profile.dominant_type_id(), &"fire", "Bakterium verursacht Feuerschaden")
	_near(bacterium.resistance_profile.rating_for_type(&"water"), 10.0, "Bakterium besitzt sein Resistenzrating")
	var cluster := EnemyDefinition.create(&"bacterial_cluster", "Gruppe", 74.0, 50.0, 5.0, 4, 30.0, Color.WHITE)
	_near(cluster.damage_profile.weight_for_type(&"earth"), 0.60, "Bakteriengruppe besitzt gemischten Erdschaden")
	_near(cluster.damage_profile.weight_for_type(&"fire"), 0.40, "Bakteriengruppe besitzt gemischten Feuerschaden")
	var focus := EnemyDefinition.create(&"infection_focus", "Herd", 2200.0, 34.0, 9.0, 30, 72.0, Color.WHITE, true)
	_near(focus.resistance_profile.rating_for_type(&"water"), -15.0, "Infektionsherd ist gegen Wasser verwundbar")
	_near(focus.base_damage, focus.contact_damage, "Der Legacy-Alias spiegelt während der Runtime-Migration den Basisschaden")


func _test_ranked_talent_catalog() -> void:
	var talents := TalentDefinition.catalog()
	_equal(talents.size(), 4, "Der aktive Talentkatalog enthält nur den neuen Einzelbaum")
	for retired_id in [&"organization_1", &"rapid_evaluation", &"alternating_rhythm", &"emergency_window"]:
		_true(not talents.has(retired_id), "%s ist aus dem aktiven Katalog entfernt" % String(retired_id))
	_equal(talents[&"spread_shotgun"].max_rank, 1, "Schrotwirkung ist ein einzelnes Freischalttalent")
	_equal(talents[&"piercing_persistence"].max_rank, 2, "Laserpersistenz besitzt zwei Ränge")
	_near(talents[&"piercing_persistence"].magnitude, 0.5, "Laserpersistenz gewährt 0,5 Sekunden pro Rang")
	_true(not talents.has(&"piercing_return"), "Rückkehr ist aus dem aktiven Katalog entfernt und bleibt reserviert")
	_equal(talents[&"treatment_damage_training"].max_rank, 1, "Die Behandlungsgrundlage ist ein Einzelrang")
	_near(talents[&"treatment_damage_training"].magnitude, 2.0, "Die Behandlungsgrundlage gewährt zwei Prozentpunkte")
	_equal(talents[&"manual_treatment_aim"].max_rank, 1, "Mausziel ist ein Einzelrang")
	_equal(talents[&"spread_shotgun"].cost_for_rank(0), 1, "Talentkosten sind über die kompatible API abrufbar")
	_equal(TalentDefinition.total_cost(), 5, "Der vollständige neue Baum kostet fünf Punkte")


func _test_catalog_validation() -> void:
	_equal(ContentCatalog.validate_combat_profiles(), PackedStringArray(), "Der Produktionskatalog enthält nur gültige aktive Profile")
	var enemies := ContentCatalog.enemy_definitions()
	var invalid: EnemyDefinition = (enemies[&"pneumococcus"] as EnemyDefinition).duplicate(true) as EnemyDefinition
	invalid.damage_profile = DamageProfile.single(&"invalid_authoring", &"plasma")
	enemies[&"pneumococcus"] = invalid
	_true(not ContentCatalog.validate_combat_profiles(enemies).is_empty(), "Unbekannte neue Typen schlagen die Katalogvalidation fehl")


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s (erwartet %s, erhalten %s)" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, message: String, epsilon: float = 0.001) -> void:
	_true(absf(actual - expected) <= epsilon, "%s (erwartet %.4f, erhalten %.4f)" % [message, expected, actual])
