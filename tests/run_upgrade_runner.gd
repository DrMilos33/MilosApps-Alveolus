extends SceneTree

const GameScript := preload("res://scripts/game.gd")

var assertions := 0
var failures := 0

func _init() -> void:
	_test_catalog_contract()
	_test_prepared_pool_filtering()
	_test_treatment_preview_application()
	_test_active_preview_application()
	_test_upgrade_prerequisites()
	_test_proportional_damage_contract()
	_test_fall_three_mandatory_defense_cells()
	_test_rarity_family_contract()
	if failures == 0:
		print("ALVEOLUS_RUN_UPGRADES_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_RUN_UPGRADES_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)

func _test_catalog_contract() -> void:
	var definitions := ContentCatalog.upgrade_definitions()
	_assert_true(definitions.size() >= 17, "Catalog exposes the active treatment, ability and defense-cell skeleton")
	var ids: Dictionary = {}
	for definition in definitions:
		_assert_true(not ids.has(definition.id), "Upgrade IDs stay unique: %s" % definition.id)
		ids[definition.id] = true
		if not definition.modifiers.is_empty():
			_assert_true(not definition.preview_stat.is_empty(), "Run modifiers declare an exact preview stat: %s" % definition.id)
	_assert_true(ids.has(&"potency") and ids.has(&"rhythm"), "Legacy intro IDs remain present")
	_assert_true(ids.has(&"spread_density") and ids.has(&"pierce_depth"), "Alternative treatments receive dedicated upgrades")
	_assert_true(ids.has(&"burst_radius") and ids.has(&"line_effect"), "The two available active abilities receive only their intended upgrades")
	_assert_true(not ids.has(&"burst_effect"), "Stoß exposes no damage upgrade before its future talent unlock")
	_assert_true(not ids.has(&"penetration"), "Impuls range upgrade is removed from the active catalog")

func _test_prepared_pool_filtering() -> void:
	var prepared: Array[StringName] = [&"treatment_precision", &"ability_defense_burst", &"ability_treatment_line"]
	var tags: Array[StringName] = [&"treatment", &"precise", &"active", &"defense", &"line"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9817
	var selected := UpgradePoolBuilder.choose(ContentCatalog.upgrade_definitions(), {}, rng, prepared, tags, 20, [], true)
	_assert_true(selected.size() >= 8, "Prepared pool can supply a broad distinct choice set")
	var has_prepared_treatment := false
	var has_general_surprise := false
	for definition in selected:
		var compatible := definition.required_component_ids.is_empty()
		for requirement in definition.required_component_ids:
			compatible = compatible or prepared.has(requirement)
		_assert_true(compatible, "Pool never leaks an upgrade for an unprepared component: %s" % definition.id)
		has_prepared_treatment = has_prepared_treatment or (definition.path == UpgradeDefinition.Path.ANTIBIOTIC and definition.required_component_ids.has(&"treatment_precision"))
		has_general_surprise = has_general_surprise or definition.required_component_ids.is_empty()
	_assert_true(has_prepared_treatment, "Guaranteed card belongs to the prepared treatment")
	_assert_true(has_general_surprise, "General defense offers remain in the run pool")

func _test_treatment_preview_application() -> void:
	var definitions := ContentCatalog.upgrade_definitions()
	var precision: TreatmentDefinition = TreatmentDefinition.catalog()[&"treatment_precision"]
	var stats := PlayerStats.new()
	stats.configure_prepared_treatment(precision)
	var build := RunBuildState.from_treatment(precision)
	stats.bind_run_build(build, precision, [])
	var common := _find(definitions, &"precision_refinement")
	var magic := _find(definitions, &"treatment_damage_magic")
	var rare := _find(definitions, &"potency")
	var preview := stats.preview_upgrade(common)
	_assert_equal(preview.effect_text, "+3 Schaden", "Common treatment damage exposes the exact delta")
	_assert_equal(preview.before_after_text, "10 Schaden  >  13 Schaden", "Common treatment damage starts from the live value")
	_assert_true(stats.apply_upgrade(common), "Common treatment damage applies")
	preview = stats.preview_upgrade(magic)
	_assert_equal(preview.effect_text, "+5 Schaden", "Magic treatment damage exposes the exact delta")
	_assert_equal(preview.before_after_text, "13 Schaden  >  18 Schaden", "Magic treatment damage continues from the live value")
	_assert_true(stats.apply_upgrade(magic), "Magic treatment damage applies")
	preview = stats.preview_upgrade(rare)
	_assert_equal(preview.effect_text, "+7 Schaden", "Rare treatment damage exposes the exact delta")
	_assert_equal(preview.before_after_text, "18 Schaden  >  25 Schaden", "Rare treatment damage continues from the live value")
	_assert_true(stats.apply_upgrade(rare), "Rare treatment damage applies")
	_assert_near(build.value(RunBuildState.TREATMENT_DAMAGE, 0.0, precision.tags), 25.0, "Gameplay resolves the same accumulated treatment damage as the cards")
	_assert_equal(stats.upgrade_pick_count(common), 3, "Common, magic and rare share one cap-free family counter")
	_assert_true(stats.apply_upgrade(common), "Repeatable damage remains collectible beyond the former third rank")
	_assert_equal(stats.upgrade_pick_count(rare), 4, "Every rarity reads the same aggregated family index")

	var projectiles := _find(definitions, &"parallel_sites")
	for _pick in range(5):
		_assert_true(stats.apply_upgrade(projectiles), "Impuls projectile pick remains available below its hidden cap")
	_assert_true(not stats.apply_upgrade(projectiles), "Impuls projectile cap is enforced after five additions")
	_assert_near(build.value(RunBuildState.TREATMENT_PROJECTILES, 0.0, precision.tags), 6.0, "Impuls reaches one base plus five additional projectiles")
	_assert_true(not projectiles.show_cap and is_equal_approx(projectiles.repeat_weight_decay, 0.60), "Projectile cap stays hidden while repeat offers become rarer")

	var spread: TreatmentDefinition = TreatmentDefinition.catalog()[&"treatment_spread"]
	var spread_stats := PlayerStats.new()
	spread_stats.configure_prepared_treatment(spread)
	var spread_build := RunBuildState.from_treatment(spread)
	spread_stats.bind_run_build(spread_build, spread, [])
	var density := _find(definitions, &"spread_density")
	preview = spread_stats.preview_upgrade(density)
	_assert_equal(preview.effect_text, "+1 Durchdringung", "Spread-specific card names the penetration increase")
	_assert_equal(preview.before_after_text, "1  >  2 Treffer", "Spread preview starts at its actual one hit per ray")
	spread_stats.apply_upgrade(density)
	_assert_near(spread_build.value(RunBuildState.TREATMENT_PROJECTILES, 0.0, spread.tags), 3.0, "Spread keeps its three authored rays")
	_assert_near(spread_build.value(RunBuildState.TREATMENT_MAX_HITS, 0.0, spread.tags), 2.0, "Spread strategy receives one additional penetration")
	_assert_equal(density.rarity_role(), &"rare", "Spread penetration is a Rare upgrade")
	_assert_near(density.rarity_weight, 5.0, "Spread penetration uses the Rare offer weight")

func _test_active_preview_application() -> void:
	var definitions := ContentCatalog.upgrade_definitions()
	var precision: TreatmentDefinition = TreatmentDefinition.catalog()[&"treatment_precision"]
	var burst: AbilityDefinition = AbilityDefinition.catalog()[&"ability_defense_burst"]
	var stats := PlayerStats.new()
	stats.configure_prepared_treatment(precision)
	var build := RunBuildState.from_treatment(precision)
	stats.bind_run_build(build, precision, [burst])
	_assert_true(_find(definitions, &"burst_effect") == null, "Stoß cannot roll a damage card before the future talent exists")
	var radius := _find(definitions, &"burst_radius")
	var preview := stats.preview_upgrade(radius)
	_assert_equal(preview.effect_text, "+1", "Stoß currently exposes only its radius utility upgrade")
	_assert_true(stats.apply_upgrade(radius), "Stoß radius upgrade applies")
	_assert_near(build.value(RunBuildState.ABILITY_DAMAGE, 0.0, burst.tags), 0.0, "Stoß remains completely damage-free")
	var line: AbilityDefinition = AbilityDefinition.catalog()[&"ability_treatment_line"]
	stats.bind_run_build(build, precision, [burst, line])
	var line_effect := _find(definitions, &"line_effect")
	_assert_true(stats.apply_upgrade(line_effect), "Treatment-line damage upgrade applies")
	_assert_near(build.value(RunBuildState.ABILITY_DAMAGE, 30.0, line.tags), 39.0, "Treatment-line common upgrade resolves proportionally in the selected ability context")

func _test_upgrade_prerequisites() -> void:
	var definitions := ContentCatalog.upgrade_definitions()
	var prepared: Array[StringName] = [&"treatment_precision", &"ability_defense_burst", &"ability_treatment_line"]
	var tags: Array[StringName] = [&"treatment", &"precise", &"active", &"defense", &"line"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7401
	var before_unlock := UpgradePoolBuilder.choose(definitions, {}, rng, prepared, tags, 30, [], false, 2)
	_assert_true(_find(before_unlock, &"neutrophils") == null, "Defense cells stay out of Fall 1 and Fall 2")
	var fall_three := UpgradePoolBuilder.choose(definitions, {}, rng, prepared, tags, 30, [], false, 3)
	_assert_true(_find(fall_three, &"neutrophils") != null, "Defense cells enter the pool from Fall 3 onward")
	_assert_true(_find(before_unlock, &"phagocytosis") == null, "Defense-cell improvements wait for the cell unlock")
	var after_unlock := UpgradePoolBuilder.choose(definitions, {&"neutrophils": 1}, rng, prepared, tags, 30, [], false, 3)
	_assert_true(_find(after_unlock, &"phagocytosis") != null, "Defense-cell damage becomes available after selection")
	_assert_true(_find(after_unlock, &"defense_cell_radius") != null and _find(after_unlock, &"defense_cell_projectiles") != null, "Radius and projectile improvements become available after selection")


func _test_proportional_damage_contract() -> void:
	var definitions := ContentCatalog.upgrade_definitions()
	var expected := {
		&"precision_refinement": 3.0,
		&"treatment_damage_magic": 5.0,
		&"potency": 7.0,
		&"spread_damage_common": 2.0,
		&"spread_damage_magic": 3.0,
		&"spread_damage_rare": 4.0,
		&"pierce_damage_common": 3.0,
		&"pierce_damage_magic": 5.0,
		&"pierce_damage_rare": 6.0,
		&"phagocytosis": 2.0,
		&"defense_cell_damage_magic": 3.0,
		&"defense_cell_damage_rare": 4.0,
		&"line_effect": 9.0,
		&"line_effect_magic": 15.0,
		&"line_effect_rare": 21.0,
	}
	for id in expected:
		var definition := _find(definitions, id)
		_assert_true(definition != null, "Proportional damage variant exists: %s" % id)
		if definition != null:
			_assert_near(float(definition.modifiers[0].get("value", -1.0)), float(expected[id]), "Damage variant uses its integer proportional delta: %s" % id)


func _test_fall_three_mandatory_defense_cells() -> void:
	var game := GameScript.new()
	game.selected_level = ContentCatalog.level_definitions()[3]
	game.stats = PlayerStats.new()
	_assert_true(game._should_offer_mandatory_defense_cells(1), "Fall 3 first level-up is reserved for defense cells")
	var offers: Array[UpgradeDefinition] = game._mandatory_defense_cell_options()
	_assert_equal(offers.size(), 3, "Fall 3 produces exactly three defense-cell cards")
	var ids: Dictionary = {}
	for offer in offers:
		ids[offer.id] = true
		_assert_equal(offer.title, "Abwehrzellen", "Every mandatory card presents defense cells")
	_assert_equal(ids.size(), 3, "Mandatory cards have unique transient presentation IDs")
	_assert_equal(game._canonical_upgrade_definition(offers[0]).id, &"neutrophils", "Choosing any mandatory card applies the stable defense-cell upgrade")
	game.selected_level = ContentCatalog.level_definitions()[2]
	_assert_true(not game._should_offer_mandatory_defense_cells(1), "Fall 2 never receives the mandatory defense-cell offer")
	game.free()


func _test_rarity_family_contract() -> void:
	var definitions := ContentCatalog.upgrade_definitions()
	var prepared: Array[StringName] = [&"treatment_precision", &"ability_defense_burst", &"ability_treatment_line"]
	var tags: Array[StringName] = [&"treatment", &"precise", &"active", &"defense", &"line"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 58123
	var selected := UpgradePoolBuilder.choose(definitions, {}, rng, prepared, tags, 20)
	var seen_families: Dictionary = {}
	for definition in selected:
		var family_key := definition.resolved_family_key(&"treatment_precision")
		_assert_true(not seen_families.has(family_key), "One selection never repeats the same component and stat family: %s" % family_key)
		seen_families[family_key] = true
	var common := _find(definitions, &"precision_refinement")
	var magic := _find(definitions, &"treatment_damage_magic")
	var rare := _find(definitions, &"potency")
	var projectiles := _find(definitions, &"parallel_sites")
	_assert_equal(common.rarity_role(), &"common", "Damage +3 is Common")
	_assert_equal(magic.rarity_role(), &"magic", "Damage +5 is Magic")
	_assert_equal(rare.rarity_role(), &"rare", "Damage +7 is Rare")
	_assert_near(common.rarity_weight, 70.0, "Common rarity weight is 70")
	_assert_near(magic.rarity_weight, 25.0, "Magic rarity weight is 25")
	_assert_near(rare.rarity_weight, 5.0, "Rare rarity weight is 5")
	_assert_equal(projectiles.rarity_role(), &"rare", "Impuls +1 Projektil ist ein Rare-Upgrade")
	_assert_near(projectiles.rarity_weight, 5.0, "Das Projektilupgrade verwendet das Rare-Gewicht")
	_assert_true(
		UpgradePoolBuilder.rarity_frequency(UpgradeDefinition.Rarity.COMMON)
		> UpgradePoolBuilder.rarity_frequency(UpgradeDefinition.Rarity.MAGIC)
		and UpgradePoolBuilder.rarity_frequency(UpgradeDefinition.Rarity.MAGIC)
		> UpgradePoolBuilder.rarity_frequency(UpgradeDefinition.Rarity.RARE),
		"Bei gleicher Relevanz gilt immer Common häufiger als Magic häufiger als Rare"
	)
	var frequency_fixture: Array[UpgradeDefinition] = [
		UpgradeDefinition.create(&"frequency_common", "Common", "", UpgradeDefinition.Path.SUPPORT, 1, &"test", 1.0).configure_offer(&"frequency_common", UpgradeDefinition.Rarity.COMMON),
		UpgradeDefinition.create(&"frequency_magic", "Magic", "", UpgradeDefinition.Path.SUPPORT, 1, &"test", 1.0).configure_offer(&"frequency_magic", UpgradeDefinition.Rarity.MAGIC),
		UpgradeDefinition.create(&"frequency_rare", "Rare", "", UpgradeDefinition.Path.SUPPORT, 1, &"test", 1.0).configure_offer(&"frequency_rare", UpgradeDefinition.Rarity.RARE),
	]
	var frequency_counts := {&"frequency_common": 0, &"frequency_magic": 0, &"frequency_rare": 0}
	var frequency_rng := RandomNumberGenerator.new()
	frequency_rng.seed = 41_902
	for _roll in range(5000):
		var rolled := UpgradePoolBuilder.choose(frequency_fixture, {}, frequency_rng, [], [], 1)
		frequency_counts[rolled[0].id] = int(frequency_counts[rolled[0].id]) + 1
	_assert_true(
		int(frequency_counts[&"frequency_common"]) > int(frequency_counts[&"frequency_magic"])
		and int(frequency_counts[&"frequency_magic"]) > int(frequency_counts[&"frequency_rare"]),
		"Die echte Familienauswahl würfelt bei gleicher Relevanz Common häufiger als Magic häufiger als Rare"
	)
	_assert_equal(_find(definitions, &"mobility").resolved_family_key(), _find(definitions, &"mobility_rare").resolved_family_key(), "All Galopp rarities share one family")

func _find(definitions: Array[UpgradeDefinition], id: StringName) -> UpgradeDefinition:
	for definition in definitions:
		if definition.id == id:
			return definition
	return null

func _assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)

func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_assert_true(actual == expected, "%s (%s != %s)" % [message, str(actual), str(expected)])

func _assert_near(actual: float, expected: float, message: String) -> void:
	_assert_true(absf(actual - expected) <= 0.001, "%s (%.4f != %.4f)" % [message, actual, expected])
