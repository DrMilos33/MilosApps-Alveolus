extends SceneTree

var assertions := 0
var failures := 0

func _init() -> void:
	_test_catalog_contract()
	_test_prepared_pool_filtering()
	_test_treatment_preview_application()
	_test_active_preview_application()
	_test_upgrade_prerequisites()
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
	_assert_true(ids.has(&"burst_effect") and ids.has(&"line_effect"), "The two available active abilities receive dedicated upgrades")

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
	var potency := _find(definitions, &"potency")
	var preview := stats.preview_upgrade(potency)
	_assert_equal(preview.effect_text, "+7 Schaden", "Prepared treatment preview shows the exact delta")
	_assert_equal(preview.before_after_text, "16 Schaden  >  23 Schaden", "Prepared treatment preview shows exact before/after values")
	_assert_true(stats.apply_upgrade(potency), "Prepared treatment modifier applies")
	_assert_near(build.value(RunBuildState.TREATMENT_DAMAGE, 0.0, precision.tags), 23.0, "Treatment controller sees the previewed damage")
	_assert_true(stats.apply_upgrade(potency), "Repeated upgrade level stacks")
	_assert_near(build.value(RunBuildState.TREATMENT_DAMAGE, 0.0, precision.tags), 30.0, "Repeated levels add once without rebasing resolved stats")

	var spread: TreatmentDefinition = TreatmentDefinition.catalog()[&"treatment_spread"]
	var spread_stats := PlayerStats.new()
	spread_stats.configure_prepared_treatment(spread)
	var spread_build := RunBuildState.from_treatment(spread)
	spread_stats.bind_run_build(spread_build, spread, [])
	var density := _find(definitions, &"spread_density")
	preview = spread_stats.preview_upgrade(density)
	_assert_equal(preview.effect_text, "+1 Projektil", "Spread-specific card names the projectile increase")
	_assert_equal(preview.before_after_text, "3  >  4 Projektile", "Spread preview starts at its actual three projectiles")
	spread_stats.apply_upgrade(density)
	_assert_near(spread_build.value(RunBuildState.TREATMENT_PROJECTILES, 0.0, spread.tags), 4.0, "Spread strategy receives four projectiles")

func _test_active_preview_application() -> void:
	var definitions := ContentCatalog.upgrade_definitions()
	var precision: TreatmentDefinition = TreatmentDefinition.catalog()[&"treatment_precision"]
	var burst: AbilityDefinition = AbilityDefinition.catalog()[&"ability_defense_burst"]
	var stats := PlayerStats.new()
	stats.configure_prepared_treatment(precision)
	var build := RunBuildState.from_treatment(precision)
	stats.bind_run_build(build, precision, [burst])
	var effect := _find(definitions, &"burst_effect")
	var preview := stats.preview_upgrade(effect)
	_assert_equal(preview.effect_text, "+12 Schaden", "Active card shows the exact effect delta")
	_assert_equal(preview.before_after_text, "38 Schaden  >  50 Schaden", "Active preview uses the selected ability base value")
	stats.apply_upgrade(effect)
	_assert_near(build.value(RunBuildState.ABILITY_DAMAGE, 38.0, burst.tags), 50.0, "Ability controller resolves the same value as the card")
	var line: AbilityDefinition = AbilityDefinition.catalog()[&"ability_treatment_line"]
	stats.bind_run_build(build, precision, [burst, line])
	var line_effect := _find(definitions, &"line_effect")
	_assert_true(stats.apply_upgrade(line_effect), "Treatment-line damage upgrade applies")
	_assert_near(build.value(RunBuildState.ABILITY_DAMAGE, 50.0, line.tags), 66.0, "Treatment-line upgrade resolves in the selected ability context")

func _test_upgrade_prerequisites() -> void:
	var definitions := ContentCatalog.upgrade_definitions()
	var prepared: Array[StringName] = [&"treatment_precision", &"ability_defense_burst", &"ability_treatment_line"]
	var tags: Array[StringName] = [&"treatment", &"precise", &"active", &"defense", &"line"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7401
	var before_unlock := UpgradePoolBuilder.choose(definitions, {}, rng, prepared, tags, 30)
	_assert_true(_find(before_unlock, &"neutrophils") != null, "Defense cells can enter the run pool")
	_assert_true(_find(before_unlock, &"phagocytosis") == null, "Defense-cell improvements wait for the cell unlock")
	var after_unlock := UpgradePoolBuilder.choose(definitions, {&"neutrophils": 1}, rng, prepared, tags, 30)
	_assert_true(_find(after_unlock, &"phagocytosis") != null, "Defense-cell damage becomes available after selection")
	_assert_true(_find(after_unlock, &"defense_cell_radius") != null and _find(after_unlock, &"defense_cell_projectiles") != null, "Radius and projectile improvements become available after selection")

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
