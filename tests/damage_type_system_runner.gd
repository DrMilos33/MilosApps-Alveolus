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
	_equal(definitions.size(), 7, "Der Katalog enthält exakt sieben Schadenstypen")
	_equal(DamageTypeCatalog.ALL_IDS, [&"fire", &"water", &"earth", &"wind", &"blood", &"holy", &"undead"], "Die stabilen Typ-IDs besitzen die feste Reihenfolge")
	for type_index in range(DamageTypeCatalog.count()):
		var id := DamageTypeCatalog.id_at(type_index)
		_true(DamageTypeCatalog.is_valid_id(id), "%s ist eine gültige Typ-ID" % String(id))
		_equal(DamageTypeCatalog.index_of(id), type_index, "%s roundtript über den festen Index" % String(id))


func _test_compiled_profiles() -> void:
	var mixed := DamageProfile.from_components(&"mixed", {&"earth": 3.0, &"blood": 2.0})
	_true(mixed.is_valid(), "Ein gemischtes Profil wird gültig vorkompiliert")
	_equal(mixed.weights.size(), 7, "Das Schadensprofil besitzt exakt sieben gepackte Werte")
	_near(mixed.weight_for_type(&"earth"), 0.6, "Komponenten werden normalisiert")
	_near(mixed.weight_for_type(&"blood"), 0.4, "Die zweite Komponente bleibt anteilig erhalten")
	_equal(mixed.dominant_type_id(), &"earth", "Der dominante Schadenstyp ist deterministisch")
	var neutral := ResistanceProfile.neutral(&"player_base")
	_true(neutral.is_valid() and neutral.is_neutral(), "Standardresistenzen sind vollständig und null")
	_equal(neutral.values.size(), 7, "Das Resistenzprofil besitzt exakt sieben gepackte Werte")


func _test_damage_resolution() -> void:
	var fire := DamageProfile.single(&"fire_test", &"fire")
	_near(CombatDamageResolver.resolve(100.0, fire), 100.0, "Nullresistenz verändert den Schaden nicht")
	var resistant := ResistanceProfile.from_components(&"resistant", {&"fire": 0.25})
	_near(CombatDamageResolver.resolve(100.0, fire, resistant), 75.0, "Typresistenz wird zuerst angewendet")
	var vulnerable := ResistanceProfile.from_components(&"vulnerable", {&"fire": -0.20})
	_near(CombatDamageResolver.resolve(100.0, fire, vulnerable), 120.0, "Negative Resistenz erhöht den Schaden")
	_near(CombatDamageResolver.resolve(100.0, fire, null, 100.0), 50.0, "100 Defense halbiert nach der festgelegten Formel")
	var mixed := DamageProfile.from_components(&"mixed_test", {&"earth": 0.60, &"blood": 0.40})
	var mixed_resistance := ResistanceProfile.from_components(&"mixed_resistance", {&"earth": 0.20, &"blood": 0.50})
	_near(CombatDamageResolver.resolve(100.0, mixed, mixed_resistance), 68.0, "Gemischter Schaden löst jeden Anteil getrennt auf")
	_near(CombatDamageResolver.resolve(100.0, mixed, mixed_resistance, 100.0), 34.0, "Defense wird nach der gemischten Typresistenz angewendet")
	_near(CombatDamageResolver.resolve(100.0, null, null, 100.0), 50.0, "Ein Legacy-Schaden ohne Profil behält neutrale Typwirkung")


func _test_combat_definition_profiles() -> void:
	var treatments := TreatmentDefinition.catalog()
	_equal(treatments[&"treatment_precision"].damage_profile.dominant_type_id(), &"water", "Präziser Impuls verursacht Wasserschaden")
	_equal(treatments[&"treatment_spread"].damage_profile.dominant_type_id(), &"fire", "Streuimpuls verursacht Feuerschaden")
	_equal(treatments[&"treatment_pierce"].damage_profile.dominant_type_id(), &"wind", "Durchdringender Impuls verursacht Windschaden")
	var abilities := AbilityDefinition.catalog()
	_equal(abilities[&"ability_defense_burst"].damage_profile.dominant_type_id(), &"earth", "Abwehrstoß verursacht Erdschaden")
	_equal(abilities[&"ability_treatment_line"].damage_profile.dominant_type_id(), &"holy", "Behandlungslinie verursacht Holy-Schaden")
	for id in [&"ability_focus_field", &"ability_emergency_support", &"ability_protection_field", &"ability_sample_pull"]:
		_true(abilities[id].damage_profile == null, "%s deklariert als nicht schädigende Fähigkeit kein Scheinprofil" % String(id))
	var bacterium := EnemyDefinition.create(&"pneumococcus", "Bakterium", 22.0, 92.0, 2.2, 1, 18.0, Color.WHITE)
	_equal(bacterium.damage_profile.dominant_type_id(), &"blood", "Bakterium verursacht Blutschaden")
	_near(bacterium.resistance_profile.resistance_for_type(&"water"), 0.10, "Bakterium besitzt seine Datenresistenz")
	var cluster := EnemyDefinition.create(&"bacterial_cluster", "Gruppe", 74.0, 55.0, 5.0, 4, 30.0, Color.WHITE)
	_near(cluster.damage_profile.weight_for_type(&"earth"), 0.60, "Bakteriengruppe besitzt gemischten Erdschaden")
	_near(cluster.damage_profile.weight_for_type(&"blood"), 0.40, "Bakteriengruppe besitzt gemischten Blutschaden")
	var focus := EnemyDefinition.create(&"infection_focus", "Herd", 2200.0, 34.0, 9.0, 30, 72.0, Color.WHITE, true)
	_near(focus.resistance_profile.resistance_for_type(&"holy"), -0.15, "Infektionsherd ist gegen Holy verwundbar")
	_near(focus.base_damage, focus.contact_damage, "Der Legacy-Alias spiegelt während der Runtime-Migration den Basisschaden")


func _test_ranked_talent_catalog() -> void:
	var talents := TalentDefinition.catalog()
	_equal(talents.size(), 4, "Der aktive Talentkatalog enthält nur den neuen Einzelbaum")
	for retired_id in [&"organization_1", &"rapid_evaluation", &"alternating_rhythm", &"emergency_window"]:
		_true(not talents.has(retired_id), "%s ist aus dem aktiven Katalog entfernt" % String(retired_id))
	_equal(talents[&"spread_penetration"].max_rank, 3, "Streudurchdringung besitzt drei Ränge")
	_equal(talents[&"piercing_persistence"].max_rank, 2, "Laserpersistenz besitzt zwei Ränge")
	_near(talents[&"piercing_persistence"].magnitude, 0.5, "Laserpersistenz gewährt 0,5 Sekunden pro Rang")
	_equal(talents[&"piercing_return"].max_rank, 1, "Rückkehr ist ein Einzelrang")
	_equal(talents[&"manual_treatment_aim"].max_rank, 1, "Mausziel ist ein Einzelrang")
	_equal(talents[&"spread_penetration"].cost_for_rank(2), 1, "Rangkosten sind über die kompatible API abrufbar")
	_equal(TalentDefinition.total_cost(), 7, "Der vollständige neue Baum kostet sieben Punkte")


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s (erwartet %s, erhalten %s)" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, message: String, epsilon: float = 0.001) -> void:
	_true(absf(actual - expected) <= epsilon, "%s (erwartet %.4f, erhalten %.4f)" % [message, expected, actual])
