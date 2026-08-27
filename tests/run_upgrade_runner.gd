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
	_test_talent_prerequisites()
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
	_assert_true(ids.has(&"burst_radius") and ids.has(&"line_effect"), "The two available active abilities receive their utility upgrades")
	_assert_true(ids.has(&"burst_effect") and ids.has(&"burst_effect_magic") and ids.has(&"burst_effect_rare"), "Stoß damage rarities exist behind the talent gate")
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
		_assert_true(not [&"burst_effect", &"burst_effect_magic", &"burst_effect_rare"].has(definition.id), "Stoß damage stays hidden without its talent")
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

	var piercing: TreatmentDefinition = TreatmentDefinition.catalog()[&"treatment_pierce"]
	var researched_piercing_stats := PlayerStats.new()
	researched_piercing_stats.configure_prepared_treatment(piercing)
	researched_piercing_stats.apply_meta_progression({&"therapy_precision": 3})
	var researched_piercing_build := RunBuildState.from_treatment(piercing)
	researched_piercing_stats.bind_run_build(researched_piercing_build, piercing, [])
	var piercing_common := _find(definitions, &"pierce_damage_common")
	preview = researched_piercing_stats.preview_upgrade(piercing_common)
	_assert_equal(preview.effect_text, "+3 Schaden", "Rank-3-Forschung lässt den Common-Kartenwert absolut")
	_assert_equal(preview.before_after_text, "10 Schaden  >  14 Schaden", "Vorschau löst (9 + 3) × 1,15 erst am Ende zu 14 auf")
	_assert_true(researched_piercing_stats.apply_upgrade(piercing_common), "Common-Ausbau gilt unter permanenter Forschung")
	_assert_near(researched_piercing_stats.therapy_damage, 14.0, "Gameplay entspricht der nicht vorgerundeten Forschungsformel")

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
	var burst_effect := _find(definitions, &"burst_effect")
	_assert_true(burst_effect != null and burst_effect.required_talent_ids.has(&"defense_burst_damage"), "Stoß damage cards require the active talent")
	var radius := _find(definitions, &"burst_radius")
	var preview := stats.preview_upgrade(radius)
	_assert_equal(preview.effect_text, "+1", "Stoß currently exposes only its radius utility upgrade")
	_assert_true(stats.apply_upgrade(radius), "Stoß radius upgrade applies")
	_assert_near(build.value(RunBuildState.ABILITY_DAMAGE, 0.0, burst.tags), 0.0, "Stoß remains completely damage-free")
	build.add_modifier_dictionary(&"talent_defense_burst_damage", 0, {
		"stat_id": RunBuildState.ABILITY_DAMAGE,
		"operation": &"add",
		"value": 20.0,
		"required_tags": PackedStringArray(["active", "defense", "area"]),
	})
	preview = stats.preview_upgrade(burst_effect)
	_assert_equal(preview.effect_text, "+6 Schaden", "Stoß Common scales proportionally from its talent base")
	_assert_equal(preview.before_after_text, "20 Schaden  >  26 Schaden", "Stoß preview starts from the talented 20 damage")
	_assert_true(stats.apply_upgrade(burst_effect), "Talent-gated Stoß damage applies additively")
	_assert_near(build.value(RunBuildState.ABILITY_DAMAGE, 0.0, burst.tags), 26.0, "Stoß resolves talent base plus its absolute run upgrade")
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


func _test_talent_prerequisites() -> void:
	var always_available := UpgradeDefinition.create(
		&"talent_fixture_common",
		"Always available",
		"",
		UpgradeDefinition.Path.SUPPORT,
		1,
		&"test",
		1.0
	).configure_offer(&"talent_fixture_common", UpgradeDefinition.Rarity.COMMON, false, true, 70.0)
	var talent_gated := UpgradeDefinition.create(
		&"talent_fixture_rare",
		"Talent gated",
		"",
		UpgradeDefinition.Path.SUPPORT,
		1,
		&"test",
		1.0
	).configure_offer(&"talent_fixture_rare", UpgradeDefinition.Rarity.RARE, false, true, 5.0).require_talents([
		&"talent_fixture_root",
		&"talent_fixture_branch",
	])
	var fixture: Array[UpgradeDefinition] = [always_available, talent_gated]
	var rng := RandomNumberGenerator.new()
	rng.seed = 31_337
	var locked := UpgradePoolBuilder.choose(
		fixture,
		{},
		rng,
		[],
		[],
		2,
		[always_available.id],
		false,
		-1,
		{&"talent_fixture_root": 1},
		1.05
	)
	_assert_equal(locked.size(), 1, "Every required talent must be skilled, including after the exclusion retry")
	_assert_true(_find(locked, always_available.id) != null, "The fallback still offers its ungated family")
	_assert_true(_find(locked, talent_gated.id) == null, "Talent-gated upgrades stay filtered while one prerequisite is missing")
	var unlocked := UpgradePoolBuilder.choose(
		fixture,
		{},
		rng,
		[],
		[],
		2,
		[always_available.id],
		false,
		-1,
		{&"talent_fixture_root": 1, &"talent_fixture_branch": 1},
		1.05
	)
	_assert_equal(unlocked.size(), 2, "All skilled talent requirements survive the exclusion retry")
	_assert_true(_find(unlocked, talent_gated.id) != null, "The gated upgrade enters the pool once every required talent is skilled")


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
		&"burst_effect": 6.0,
		&"burst_effect_magic": 10.0,
		&"burst_effect_rare": 14.0,
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
	game.meta = MetaProgressionState.new()
	game.stats = PlayerStats.new()
	_assert_true(game._should_offer_mandatory_defense_cells(1), "Fall 3 first level-up is reserved for defense cells before the first victory")
	var offers: Array[UpgradeDefinition] = game._mandatory_defense_cell_options()
	_assert_equal(offers.size(), 3, "Fall 3 produces exactly three defense-cell cards")
	var ids: Dictionary = {}
	for offer in offers:
		ids[offer.id] = true
		_assert_equal(offer.title, "Abwehrzellen", "Every mandatory card presents defense cells")
	_assert_equal(ids.size(), 3, "Mandatory cards have unique transient presentation IDs")
	_assert_equal(game._canonical_upgrade_definition(offers[0]).id, &"neutrophils", "Choosing any mandatory card applies the stable defense-cell upgrade")
	game.meta.register_level_result(game.selected_level, false, 60.0, 1, 0)
	_assert_true(game._should_offer_mandatory_defense_cells(1), "A failed Fall 3 attempt keeps the first-level guarantee")
	game.meta.register_level_result(game.selected_level, true, 300.0, 4, 120)
	_assert_true(not game._should_offer_mandatory_defense_cells(1), "The first Fall 3 victory permanently removes the first-level guarantee")
	game.active_run_context = RunContext.create(game.selected_level.id, 17, null, {&"defense_cells_first": 1})
	_assert_true(game._should_offer_mandatory_defense_cells(1), "Das Talent garantiert Abwehrzellen auch nach dem Onboarding-Sieg")
	game.selected_level = ContentCatalog.level_definitions()[4]
	_assert_true(game._should_offer_mandatory_defense_cells(1), "Das Talent gilt ab Fall 3 auch in späteren Fällen")
	game.active_run_context = null
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
	_assert_near(
		UpgradePoolBuilder.adjusted_rarity_weight(70.0, UpgradeDefinition.Rarity.COMMON),
		70.0,
		"The deterministic base helper keeps Common at 70"
	)
	_assert_near(
		UpgradePoolBuilder.adjusted_rarity_weight(25.0, UpgradeDefinition.Rarity.MAGIC),
		25.0,
		"The deterministic base helper keeps Magic at 25"
	)
	_assert_near(
		UpgradePoolBuilder.adjusted_rarity_weight(5.0, UpgradeDefinition.Rarity.RARE),
		5.0,
		"The deterministic base helper keeps Rare at 5"
	)
	var rank_one_factor := UpgradePoolBuilder.relative_higher_rarity_weight_factor(1.05)
	_assert_near(rank_one_factor, 1.072993, "A relative five-percent chance increase is converted to exact draw odds")
	_assert_near(
		UpgradePoolBuilder.adjusted_rarity_weight(70.0, UpgradeDefinition.Rarity.COMMON, rank_one_factor),
		70.0,
		"The exact relative chance conversion leaves Common weight unchanged"
	)
	_assert_near(
		UpgradePoolBuilder.adjusted_rarity_weight(25.0, UpgradeDefinition.Rarity.MAGIC, rank_one_factor),
		26.824818,
		"Rank one raises Magic enough for an exact relative five-percent probability increase"
	)
	_assert_near(
		UpgradePoolBuilder.adjusted_rarity_weight(5.0, UpgradeDefinition.Rarity.RARE, rank_one_factor),
		5.364964,
		"Rank one preserves the Magic-to-Rare ratio while raising both higher tiers"
	)
	var rank_one_total := 70.0 + 30.0 * rank_one_factor
	_assert_near(30.0 * rank_one_factor / rank_one_total, 0.315, "Rank one moves the combined Magic-or-Rare chance from 30 to exactly 31.5 percent")
	var rank_three_multiplier := pow(1.05, 3.0)
	var rank_three_factor := UpgradePoolBuilder.relative_higher_rarity_weight_factor(rank_three_multiplier)
	var rank_three_total := 70.0 + 30.0 * rank_three_factor
	_assert_near(30.0 * rank_three_factor / rank_three_total, 0.30 * rank_three_multiplier, "Three ranks compound the relative chance multiplicatively")
	_assert_near(
		UpgradePoolBuilder.rarity_frequency(UpgradeDefinition.Rarity.MAGIC, rank_one_factor),
		(25.0 / 70.0) * rank_one_factor,
		"A singleton Magic family receives the same odds factor"
	)
	_assert_near(
		UpgradePoolBuilder.rarity_frequency(UpgradeDefinition.Rarity.COMMON, rank_one_factor),
		1.0,
		"A singleton Common family remains unchanged"
	)
	_assert_near(
		UpgradePoolBuilder.rarity_frequency(UpgradeDefinition.Rarity.RARE, rank_one_factor),
		(5.0 / 70.0) * rank_one_factor,
		"A singleton Rare family receives the same odds factor"
	)
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
