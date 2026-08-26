extends SceneTree

const GameScript := preload("res://scripts/game.gd")

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
	_test_impulse_splash_runtime()
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
	var definitions := TalentDefinition.definitions()
	_equal(talents.size(), 26, "Talentbaumrevision 6 enthält alle drei Bäume samt Platzhaltern")
	_equal(definitions.size(), talents.size(), "Definitionen und Katalog besitzen dieselbe vollständige Knotenmenge")
	var tree_ids: Dictionary = {}
	var unimplemented_placeholders := 0
	for definition in definitions:
		tree_ids[definition.tree_id] = true
		if not definition.implemented:
			unimplemented_placeholders += 1
			_equal(definition.effect_id, &"placeholder", "%s ist ausschließlich als Platzhalter markiert" % String(definition.id))
	_equal(tree_ids.size(), 3, "Revision 6 besitzt exakt drei Talentbäume")
	for tree_id in [&"upgrades", &"active", &"treatment"]:
		_true(tree_ids.has(tree_id), "%s ist als eigener Talentbaum vorhanden" % String(tree_id))
	_equal(unimplemented_placeholders, 17, "Alle noch wirkungslosen Folgeknoten bleiben explizite Platzhalter")
	for retired_id in [&"organization_1", &"rapid_evaluation", &"alternating_rhythm", &"emergency_window"]:
		_true(not talents.has(retired_id), "%s ist aus dem aktiven Katalog entfernt" % String(retired_id))
	for stable_id in [&"treatment_damage_training", &"manual_treatment_aim", &"spread_shotgun", &"piercing_persistence"]:
		_true(talents.has(stable_id), "%s bleibt als stabile ID aus Revision 5 erhalten" % String(stable_id))

	var treatment_root: TalentDefinition = talents[&"treatment_damage_training"]
	_equal(treatment_root.max_rank, 3, "Die Behandlungsgrundlage besitzt drei Ränge")
	_near(treatment_root.magnitude, 0.20, "Jeder Rang erhöht den Behandlungsbasisschaden um 20 Prozent")
	for rank_index in range(3):
		_equal(treatment_root.cost_for_rank(rank_index), 1, "Jeder Behandlungsgrundlagenrang kostet einen Punkt")
	var rarity_root: TalentDefinition = talents[&"upgrade_rarity_training"]
	_equal(rarity_root.max_rank, 3, "Das Seltenheitstalent besitzt drei Ränge")
	_near(rarity_root.magnitude, 0.05, "Jeder Seltenheitsrang gewährt fünf Prozent relative Gewichtung")
	for rank_index in range(3):
		_equal(rarity_root.cost_for_rank(rank_index), 1, "Jeder Seltenheitsrang kostet einen Punkt")

	var treatment_lanes := {
		&"manual_treatment_aim": 0,
		&"spread_shotgun": 1,
		&"piercing_persistence": 2,
		&"impulse_splash": 3,
	}
	for id in treatment_lanes:
		var branch: TalentDefinition = talents[id]
		_equal(branch.tree_id, &"treatment", "%s gehört zum Behandlungsbaum" % String(id))
		_equal(branch.tree_tier, 1, "%s beginnt direkt unter der Behandlungsgrundlage" % String(id))
		_equal(branch.tree_lane, int(treatment_lanes[id]), "%s belegt seine stabile Behandlungslane" % String(id))
		_equal(branch.required_ids, PackedStringArray(["treatment_damage_training"]), "%s verlangt die Behandlungsgrundlage" % String(id))
	_near(talents[&"impulse_splash"].magnitude, 0.10, "Die Impulsexplosion übernimmt zehn Prozent Trefferschaden")

	var active_gateway: TalentDefinition = talents[&"active_foundation_placeholder"]
	_true(active_gateway.implemented, "Das Platzhalter-Wurzeltalent des Aktivbaums bleibt als Gateway kaufbar")
	_equal(active_gateway.effect_id, &"placeholder", "Das aktive Gateway verspricht noch keinen Kampfeffekt")
	var burst_talent: TalentDefinition = talents[&"defense_burst_damage"]
	_equal(burst_talent.required_ids, PackedStringArray(["active_foundation_placeholder"]), "Stoßschaden verlangt das aktive Gateway")
	_near(burst_talent.magnitude, 20.0, "Das Stoßtalent stellt 20 Basisschaden bereit")
	var upgrades: Dictionary = {}
	for definition in ContentCatalog.upgrade_definitions():
		upgrades[definition.id] = definition
	for upgrade_id in [&"burst_effect", &"burst_effect_magic", &"burst_effect_rare"]:
		_true(upgrades.has(upgrade_id), "%s bleibt als stabile Stoßschaden-Upgrade-ID erhalten" % String(upgrade_id))
		if upgrades.has(upgrade_id):
			var upgrade: UpgradeDefinition = upgrades[upgrade_id]
			_equal(upgrade.required_talent_ids, [&"defense_burst_damage"], "%s wird erst durch das Stoßtalent freigeschaltet" % String(upgrade_id))

	_equal(talents[&"spread_shotgun"].max_rank, 1, "Schrotwirkung ist ein einzelnes Freischalttalent")
	_equal(talents[&"piercing_persistence"].max_rank, 2, "Laserpersistenz besitzt zwei Ränge")
	_near(talents[&"piercing_persistence"].magnitude, 0.5, "Laserpersistenz gewährt 0,5 Sekunden pro Rang")
	_true(not talents.has(&"piercing_return"), "Rückkehr ist aus dem aktiven Katalog entfernt und bleibt reserviert")
	_equal(talents[&"manual_treatment_aim"].max_rank, 1, "Mausziel ist ein Einzelrang")
	_equal(talents[&"spread_shotgun"].cost_for_rank(0), 1, "Talentkosten sind über die kompatible API abrufbar")


func _test_impulse_splash_runtime() -> void:
	var topology := ArenaTopology.new(Rect2(-300.0, -300.0, 600.0, 600.0), ArenaTopology.BoundaryMode.BOUNDED)
	var world := EnemyWorld.new().configure_enemy_world(CombatCapacity.new().configure(8, 8, 2, 4, 4, 4))
	var definition := EnemyDefinition.create(&"splash_fixture", "Testkeim", 100.0, 0.0, 0.0, 0, 12.0, Color.WHITE)
	var primary := InfectionEnemy.new()
	var nearby := InfectionEnemy.new()
	var outside := InfectionEnemy.new()
	get_root().add_child(primary)
	get_root().add_child(nearby)
	get_root().add_child(outside)
	primary.global_position = Vector2.ZERO
	nearby.global_position = Vector2(40.0, 0.0)
	outside.global_position = Vector2(150.0, 0.0)
	for enemy in [primary, nearby, outside]:
		enemy.configure(definition, null, topology)
		enemy.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
		_true(enemy.is_targetable(), "Impulsexplosion verwendet materialisierte, generationensichere Ziele")
		_true(EntityHandle.is_valid(world.register_enemy(enemy)), "Impulsexplosionsziel erhält ein gültiges EnemyWorld-Handle")
	var query := CombatQuery.new().configure(
		topology,
		func(handle: int) -> Vector2: return (world.resolve(handle) as InfectionEnemy).global_position,
		func(handle: int) -> float: return (world.resolve(handle) as InfectionEnemy).definition.radius,
		func(handle: int) -> bool: return world.resolve(handle) != null and (world.resolve(handle) as InfectionEnemy).is_targetable(),
		world.resolve
	)
	query.rebuild(world.handles())
	var game := GameScript.new()
	game.enemy_world = world
	game.combat_query = query
	game._combat_query_dirty = false
	game.active_run_context = RunContext.create(&"splash_fixture", 7, null, {&"impulse_splash": 1})
	game.selected_level = LevelDefinition.new()
	for enemy in [primary, nearby, outside]:
		enemy.damage_applied.connect(Callable(game, "_on_enemy_damage_applied"))
	game._apply_treatment_hit(primary, 20.0, &"treatment_precision")
	_near(primary.health, 80.0, "Der direkte Impulstreffer behält seinen vollständigen Schaden")
	_near(nearby.health, 98.0, "Die kleine Explosion verursacht exakt zehn Prozent auf nahe Gegner")
	_near(outside.health, 100.0, "Gegner außerhalb des Explosionsradius bleiben unverändert")
	_near(float(game.run_damage_by_source.get(&"treatment_precision", 0.0)), 22.0, "Direkt- und Explosionsschaden laufen in derselben Impulsstatistik zusammen")
	world.clear()
	game.free()
	primary.free()
	nearby.free()
	outside.free()


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
