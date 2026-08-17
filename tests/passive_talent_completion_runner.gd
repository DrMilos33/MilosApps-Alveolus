extends SceneTree

var assertions := 0
var failures: Array[String] = []

const PASSIVE_IDS: Array[StringName] = [
	&"stability_reserve", &"therapy_precision", &"sample_logistics",
	&"preanalysis", &"second_opinion", &"quick_test", &"reserve_buffer",
	&"defense_readiness", &"deployment_routine",
]

const TALENT_IDS: Array[StringName] = [
	&"organization_1", &"organization_2", &"hold_card", &"guided_choice",
	&"early_classification", &"rapid_evaluation", &"broader_perspective",
	&"immediate_measure", &"alternating_rhythm", &"linked_deployment",
	&"finding_readiness", &"emergency_window",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_catalogs()
	_test_all_passive_baselines()
	_test_reserve_buffer_synergy()
	_test_talent_selection_and_capacity()
	await _test_game_talent_rules()

	if failures.is_empty():
		print("ALVEOLUS_PASSIVE_TALENT_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	printerr("ALVEOLUS_PASSIVE_TALENT_FAILED failures=%d assertions=%d" % [failures.size(), assertions])
	quit(1)

func _test_catalogs() -> void:
	var modules := ContentCatalog.loadout_module_definitions()
	var passive_count := 0
	for id in PASSIVE_IDS:
		_check(modules.has(id), "Passivkatalog enthält %s" % id)
		if modules.has(id):
			var definition: LoadoutModuleDefinition = modules[id]
			_check(definition.kind == LoadoutModuleDefinition.Kind.PASSIVE, "%s ist als Passivmodul typisiert" % id)
			_check(not definition.description.is_empty(), "%s besitzt eine verständliche Wirkungserklärung" % id)
	for definition in modules.values():
		if definition is LoadoutModuleDefinition and definition.kind == LoadoutModuleDefinition.Kind.PASSIVE:
			passive_count += 1
	_equal(passive_count, PASSIVE_IDS.size(), "Genau neun Passivmodule sind katalogisiert")

	var talents := TalentDefinition.catalog()
	_equal(talents.size(), TALENT_IDS.size(), "Genau zwölf Talente sind katalogisiert")
	for id in TALENT_IDS:
		_check(talents.has(id), "Talentkatalog enthält %s" % id)
		if talents.has(id):
			var definition: TalentDefinition = talents[id]
			_check(definition.cost > 0, "%s besitzt positive Talentkosten" % id)
			_check(not definition.effect_id.is_empty(), "%s besitzt eine stabile Effekt-ID" % id)
			_check(definition.tree_tier in [0, 1, 2] and definition.tree_lane in [0, 1, 2], "%s besitzt gültige Baumkoordinaten" % id)
	_check("50 %" in String(talents[&"immediate_measure"].description) and "10 Sekunden" in String(talents[&"immediate_measure"].description), "Sofortmaßnahme nennt exakt Stärke und Dauer")
	_check(talents[&"organization_2"].required_ids == PackedStringArray(["organization_1"]), "Der Planungsast verlangt Organisation I vor Organisation II")
	_check(talents[&"hold_card"].required_ids == PackedStringArray(["organization_2"]) and talents[&"guided_choice"].required_ids == PackedStringArray(["organization_2"]), "Der Planungsast verzweigt nach Organisation II in zwei Endknoten")
	_check(talents[&"broader_perspective"].required_ids == PackedStringArray(["rapid_evaluation"]) and talents[&"immediate_measure"].required_ids == PackedStringArray(["rapid_evaluation"]), "Der Diagnoseast verzweigt nach Schnellauswertung in zwei Endknoten")
	_check(talents[&"finding_readiness"].required_ids == PackedStringArray(["linked_deployment"]) and talents[&"emergency_window"].required_ids == PackedStringArray(["linked_deployment"]), "Der Einsatzast verzweigt nach Gekoppeltem Einsatz in zwei Endknoten")
	var category_counts := {
		TalentDefinition.Category.PLANNING: 0,
		TalentDefinition.Category.DIAGNOSIS: 0,
		TalentDefinition.Category.DEPLOYMENT: 0,
	}
	for definition_value in talents.values():
		var definition := definition_value as TalentDefinition
		category_counts[definition.category] = int(category_counts.get(definition.category, 0)) + 1
	_equal(category_counts[TalentDefinition.Category.PLANNING], 4, "Planung bildet einen vollständigen Vierknotenast")
	_equal(category_counts[TalentDefinition.Category.DIAGNOSIS], 4, "Diagnose bildet einen vollständigen Vierknotenast")
	_equal(category_counts[TalentDefinition.Category.DEPLOYMENT], 4, "Einsatz bildet einen vollständigen Vierknotenast")

func _test_all_passive_baselines() -> void:
	var stats := PlayerStats.new()
	var treatment: TreatmentDefinition = TreatmentDefinition.catalog()[&"treatment_precision"]
	stats.configure_prepared_treatment(treatment)
	var ranks := {
		&"stability_reserve": 2,
		&"therapy_precision": 2,
		&"sample_logistics": 2,
		&"preanalysis": 1,
		&"second_opinion": 1,
		&"quick_test": 1,
		&"reserve_buffer": 1,
		&"defense_readiness": 1,
		&"deployment_routine": 1,
	}
	stats.apply_prepared_progression(ranks, PASSIVE_IDS)
	_near(stats.max_stability_bonus, 6.0, "Startreserve addiert zwei mal drei Zustand")
	_near(stats.therapy_damage, treatment.base_damage * 1.04, "Ruhige Hand erhöht die Grundwirkung exakt um vier Prozent")
	_near(stats.pickup_range, 185.0 * 1.10, "Probenmagnet erhöht den Aufnahmeradius exakt um zehn Prozent")
	_check(stats.has_prepared_passive(&"preanalysis"), "Startprobe bleibt als vorbereiteter Run-Hook erhalten")
	_check(stats.has_prepared_passive(&"second_opinion"), "Zweitmeinung bleibt als vorbereiteter Run-Hook erhalten")
	_near(stats.finding_progress_multiplier, 1.20, "Schnelltest erhöht Befundfortschritt exakt um zwanzig Prozent")
	_near(stats.overheal_shield_cap, 12.0, "Reservepuffer besitzt exakt zwölf Schutz Kapazität")
	_equal(stats.immune_cell_count(), 2, "Abwehrbereitschaft startet mit zwei Abwehrzellen")
	_near(stats.ability_cooldown_multiplier, 0.92, "Einsatzroutine verkürzt aktive Abklingzeiten exakt um acht Prozent")

	# Applying or removing the same plan more than once is a regression-prone
	# path used by previews and reserve swaps. It must be perfectly idempotent.
	stats.apply_prepared_progression(ranks, PASSIVE_IDS)
	_near(stats.therapy_damage, treatment.base_damage * 1.04, "Doppeltes Anwenden vervielfacht Ruhige Hand nicht")
	_near(stats.pickup_range, 185.0 * 1.10, "Doppeltes Anwenden vervielfacht Probenmagnet nicht")
	_equal(stats.prepared_passive_ids.size(), PASSIVE_IDS.size(), "Doppeltes Anwenden erzeugt keine Passivduplikate")
	stats.apply_prepared_progression(ranks, [])
	_near(stats.max_stability_bonus, 0.0, "Entfernen stellt den Zustandsbonus wieder her")
	_near(stats.therapy_damage, treatment.base_damage, "Entfernen stellt die Grundwirkung wieder her")
	_near(stats.pickup_range, 185.0, "Entfernen stellt den Probenradius wieder her")
	_near(stats.finding_progress_multiplier, 1.0, "Entfernen stellt den Befundfaktor wieder her")
	_near(stats.overheal_shield_cap, 0.0, "Entfernen deaktiviert den Reservepuffer")
	_equal(stats.immune_cell_count(), 0, "Entfernen deaktiviert die Startabwehr")
	_near(stats.ability_cooldown_multiplier, 1.0, "Entfernen stellt die aktive Abklingzeit wieder her")
	stats.apply_prepared_progression(ranks, [])
	_near(stats.therapy_damage, treatment.base_damage, "Doppeltes Entfernen unterschreitet die Baseline nicht")

	# Rank changes outside a live run must not alter the inverse operation.
	stats.apply_prepared_progression(ranks, [&"therapy_precision"])
	var changed_ranks := ranks.duplicate()
	changed_ranks[&"therapy_precision"] = 3
	stats.apply_prepared_progression(changed_ranks, [])
	_near(stats.therapy_damage, treatment.base_damage, "Entfernen verwendet den tatsächlich ausgerüsteten Forschungsrang")

func _test_reserve_buffer_synergy() -> void:
	var stats := PlayerStats.new()
	stats.apply_prepared_passive(&"reserve_buffer", {&"reserve_buffer": 1}, true)
	_near(stats.support_recovery(), 0.0, "Reservepuffer erzeugt ohne Atemhilfe keine Regeneration und keinen eigenen Schutz")
	stats.support_level = 1
	_near(stats.support_recovery(), 4.0, "Atemhilfe liefert die Baseline für den Reservepuffer")

	var controller := AbilityController.new()
	controller.grant_shield_capped(3.0, stats.overheal_shield_cap)
	controller.grant_shield_capped(4.0, stats.overheal_shield_cap)
	controller.grant_shield_capped(5.0, stats.overheal_shield_cap)
	_near(controller.shield, 12.0, "Mehrere kleine Atemhilfeüberläufe bauen Schutz bis zwölf auf")
	_near(controller.shield_maximum, 12.0, "Reservepuffer meldet eine stabile Schutzkapazität von zwölf")
	controller.grant_shield_capped(8.0, stats.overheal_shield_cap)
	_near(controller.shield, 12.0, "Reservepuffer überschreitet sein Limit nicht")
	controller.absorb_pressure(7.0)
	controller.grant_shield_capped(2.0, stats.overheal_shield_cap)
	_near(controller.shield, 7.0, "Spätere Atemhilfe füllt verbrauchten Schutz schrittweise nach")
	controller.free()

func _test_talent_selection_and_capacity() -> void:
	var meta := MetaProgressionState.new(func() -> int: return 900000)
	meta.reset_defaults(900000)
	meta.unlimited_test_progression = true
	_equal(meta.preparation_capacity(), 8, "Vorbereitung besitzt ohne Organisation acht Kapazität")
	_check(meta.set_talent_selection([&"organization_1"]), "Organisation I kann einzeln gewählt werden")
	_equal(meta.preparation_capacity(), 9, "Organisation I gibt exakt eine Kapazität")
	_check(not meta.set_talent_selection([&"organization_2"]), "Organisation II verlangt Organisation I")
	_check(meta.set_talent_selection([&"organization_1", &"organization_2"]), "Beide Organisationstalente können kombiniert werden")
	_equal(meta.preparation_capacity(), 10, "Beide Organisationstalente geben zusammen zwei Kapazität")
	_check(not meta.set_talent_selection([&"broader_perspective"]), "Ein Diagnose-Endknoten kann seine Stammknoten nicht überspringen")
	_check(meta.set_talent_selection([&"early_classification", &"rapid_evaluation", &"broader_perspective", &"immediate_measure"]), "Der Diagnoseast erlaubt beide Verzweigungen nach erfüllter Kette")
	_check(not meta.set_talent_selection([&"linked_deployment", &"finding_readiness"]), "Der Einsatzast verlangt Wechselrhythmus als Einstieg")
	_check(meta.set_talent_selection([&"alternating_rhythm", &"linked_deployment", &"finding_readiness", &"emergency_window"]), "Der Einsatzast erlaubt beide Verzweigungen nach erfüllter Kette")
	_check(meta.set_talent_selection(TALENT_IDS), "Alle zwölf Talente bilden im Testmodus eine gültige Kombination")
	_equal(meta.selected_talent_ids.size(), TALENT_IDS.size(), "Alle zwölf Talente bleiben im Snapshot erhalten")

func _test_game_talent_rules() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	get_root().add_child(game)
	game.persistence_enabled = false
	game.meta.reset_defaults(910000)
	game.meta.unlimited_test_progression = true
	game.meta.prologue_seen = true
	game.meta.highest_unlocked_level = 3
	_check(game.meta.set_talent_selection(TALENT_IDS), "Integrierter Spielstand akzeptiert alle Talente")
	await process_frame

	var context := RunContext.create(
		&"localized_focus", 12345, PreparedLoadout.default_loadout(),
		game.meta.selected_talent_ids, &"high_load", &"grouping"
	)
	game.pending_run_context = context
	_check("Frühe Einordnung" in game._preparation_finding_hint(), "Frühe Einordnung erscheint direkt in der Einsatzplanung")
	context.talent_snapshot.erase(&"early_classification")
	_check("während der Behandlung" in game._preparation_finding_hint(), "Ohne Frühe Einordnung bleibt der Befund in der Einsatzplanung verborgen")
	context.talent_snapshot[&"early_classification"] = true

	# Configure the real controller once, then drive the game callbacks that own
	# cross-ability talents. No duplicate test implementation is involved.
	game.active_run_context = context
	game.active_loadout = PreparedLoadout.create(
		&"treatment_precision",
		[&"ability_focus_field", &"ability_emergency_support"],
		[&"preanalysis", &"second_opinion"]
	)
	for level in game.levels:
		if level.id == &"localized_focus":
			game.selected_level = level
			break
	_check(game.selected_level != null, "Der Integrationstest findet Fall 1 im Levelkatalog")
	if game.selected_level == null:
		game.queue_free()
		return
	game.config = RunConfig.from_level(game.selected_level)
	game.stats = PlayerStats.new()
	var treatment: TreatmentDefinition = game.treatment_definitions[&"treatment_precision"]
	game.stats.configure_prepared_treatment(treatment)
	game.stats.apply_prepared_progression({&"preanalysis": 1, &"second_opinion": 1}, game.active_loadout.passive_ids)
	game.state = RunState.new()
	game.state.reset(game.config, 2, game.stats.max_stability_bonus)
	game.mastery_tracker.begin_run(game.selected_level.id, game.config.run_duration_seconds)
	game._configure_tactical_run(treatment)
	game._set_flow(GameFlowState.State.RUNNING)
	game.reroll_available = game.active_loadout.passive_ids.has(&"second_opinion")
	_check(game.state.analysis == 2, "Startprobe beginnt einen Hauptfall wirklich mit zwei Proben")
	_check(game.reroll_available, "Zweitmeinung aktiviert exakt eine Neuauswahl im Run")
	_equal(game.finding_controller.target, roundi(float(game.selected_level.finding_progress_target) * 0.8), "Schnellauswertung reduziert die reale Befundschwelle um zwanzig Prozent")

	var q: AbilityRuntime = game.ability_controller.runtime(AbilityController.SLOT_Q)
	var e: AbilityRuntime = game.ability_controller.runtime(AbilityController.SLOT_E)
	q.start_cooldown(1.0)
	e.start_cooldown(1.0)
	var e_before := e.cooldown_remaining
	game.state.elapsed = 10.0
	game.last_ability_slot = -1
	game._on_ability_used(AbilityController.SLOT_Q, &"ability_focus_field", Vector2.ZERO)
	_near(e.cooldown_remaining, e_before - 2.0, "Gekoppelter Einsatz verkürzt nur die andere Restzeit um zwei Sekunden")
	var q_before := q.cooldown_remaining
	var e_before_alternating := e.cooldown_remaining
	game._on_ability_used(AbilityController.SLOT_E, &"ability_emergency_support", Vector2.ZERO)
	_near(q.cooldown_remaining, q_before - 2.0, "Gekoppelter Einsatz funktioniert auch in Gegenrichtung")
	_near(e.cooldown_remaining, e_before_alternating * 0.75, "Wechselrhythmus verkürzt die zweite eigene Restzeit exakt um 25 Prozent")
	game.state.elapsed += TalentDefinition.ALTERNATING_RHYTHM_WINDOW_SECONDS + 0.01
	game.last_ability_slot = AbilityController.SLOT_Q
	game.last_ability_time = 10.0
	e.cooldown_remaining = 8.0
	game._on_ability_used(AbilityController.SLOT_E, &"ability_emergency_support", Vector2.ZERO)
	_near(e.cooldown_remaining, 8.0, "Wechselrhythmus wirkt außerhalb des Viersekundenfensters nicht")

	q.cooldown_remaining = 8.0
	e.cooldown_remaining = 6.0
	var finding: FindingDefinition = game.finding_definitions[&"grouping"]
	game.finding_controller.configure(finding, 10)
	game._on_finding_revealed(finding)
	_near(q.cooldown_remaining, 4.0, "Befundbereitschaft halbiert Q exakt")
	_near(e.cooldown_remaining, 3.0, "Befundbereitschaft halbiert E exakt")
	game.hud.hide_finding()
	game.ui_router.close_modal()
	game.finding_controller.resolved = true
	game._set_flow(GameFlowState.State.RUNNING)

	q.cooldown_remaining = 5.0
	e.cooldown_remaining = 7.0
	game.emergency_talent_used = false
	game._on_stability_changed(25.0, 100.0)
	_near(q.cooldown_remaining, 0.0, "Notfallfenster setzt Q bei exakt 25 Prozent zurück")
	_near(e.cooldown_remaining, 0.0, "Notfallfenster setzt E bei exakt 25 Prozent zurück")
	q.cooldown_remaining = 4.0
	e.cooldown_remaining = 4.0
	game._on_stability_changed(20.0, 100.0)
	_near(q.cooldown_remaining, 4.0, "Notfallfenster löst pro Run nur einmal aus")
	_near(e.cooldown_remaining, 4.0, "Ein zweiter niedriger Zustandswert setzt E nicht erneut zurück")

	var reactions: Array = game._reactions_for_finding(finding)
	_equal(reactions.size(), finding.reaction_ids.size() + 1, "Weitere Perspektive ergänzt genau eine vierte Befundreaktion")

	# Sofortmaßnahme: exact additive, positive multiplier, reduction multiplier,
	# one-shot shield and expiry behavior against the unboosted reaction baseline.
	_test_immediate_measure_on_game(game)

	# Karte halten keeps the same first resource while replacing the other two.
	game.flow_state = GameFlowState.State.LEVEL_UP
	game.state.active = true
	game.reroll_available = true
	game.reroll_used = false
	var no_exclusions: Array[StringName] = []
	game.current_upgrade_options = game._choose_tactical_upgrades(no_exclusions, false)
	var held: UpgradeDefinition = game.current_upgrade_options[0]
	game._on_reroll_requested()
	_check(not game.current_upgrade_options.is_empty() and game.current_upgrade_options[0] == held, "Karte halten bewahrt beim Neuwürfeln die erste Karte")
	_equal(game.current_upgrade_options.size(), 3, "Karte halten ergänzt zwei neue eindeutige Karten")

	var guided: Array[UpgradeDefinition] = game._choose_tactical_upgrades(no_exclusions, true)
	var prepared_synergy := false
	for upgrade in guided:
		if upgrade.path == UpgradeDefinition.Path.ANTIBIOTIC and upgrade.required_component_ids.has(game.active_loadout.treatment_id):
			prepared_synergy = true
	_check(prepared_synergy, "Gezielte Auswahl kann die garantierte Plan-Synergie für das datengetriebene Intervall liefern")

	game.queue_free()
	await process_frame
	await process_frame

func _test_immediate_measure_on_game(game: Node) -> void:
	# Force creation of the fourth adaptive option for every finding as well.
	for finding in game.finding_definitions.values():
		game._reactions_for_finding(finding)
	var all_reactions: Array[ReactionDefinition] = []
	for value in game.reaction_definitions.values():
		if value is ReactionDefinition:
			all_reactions.append(value)
	all_reactions.sort_custom(func(left: ReactionDefinition, right: ReactionDefinition) -> bool: return String(left.id) < String(right.id))
	for definition in all_reactions:
		var bases: Dictionary = {}
		for modifier in definition.modifiers:
			var stat_id := StringName(str(modifier.get("stat_id", "")))
			var operation := StringName(str(modifier.get("operation", "add")))
			bases[stat_id] = 1.0 if operation == &"multiply" else (8.0 if stat_id == RunBuildState.ABILITY_SHIELD else 0.0)
		game.build_state = RunBuildState.new(bases)
		game.stats.bind_run_build(game.build_state)
		game.ability_controller.shield = 0.0
		game.ability_controller.shield_maximum = 0.0
		for index in range(definition.modifiers.size()):
			var modifier: Dictionary = definition.modifiers[index]
			if StringName(str(modifier.get("stat_id", ""))) == RunBuildState.ABILITY_SHIELD:
				game.ability_controller.grant_shield(float(modifier.get("value", 0.0)))
				continue
			game.build_state.add_modifier_dictionary(definition.id, index, modifier)
		game._apply_immediate_reaction_boost(definition)
		_near(game.reaction_boost_timer, 10.0, "%s verwendet die beschriebene Dauer" % definition.id)
		for modifier in definition.modifiers:
			var stat_id := StringName(str(modifier.get("stat_id", "")))
			var operation := StringName(str(modifier.get("operation", "add")))
			var value := float(modifier.get("value", 0.0))
			var actual_base: float = game.build_state.base_value(stat_id, 1.0 if operation == &"multiply" else 0.0)
			if stat_id == RunBuildState.ABILITY_SHIELD:
				_near(game.ability_controller.shield, value * 1.5, "%s erhöht einmaligen Schutz exakt um 50 Prozent" % definition.id)
				_near(game.build_state.value(stat_id, actual_base), actual_base, "%s verändert spätere Schildfähigkeiten nicht versteckt" % definition.id)
			elif operation == &"multiply":
				_near(game.build_state.value(stat_id, actual_base), actual_base * (1.0 + (value - 1.0) * 1.5), "%s verstärkt den Multiplikator exakt um 50 Prozent seines Effekts" % definition.id)
			elif operation == &"add":
				_near(game.build_state.value(stat_id, actual_base), actual_base + value * 1.5, "%s verstärkt den additiven Wert exakt um 50 Prozent" % definition.id)

	# Verify expiry independently on a representative additive reaction.
	var additive: ReactionDefinition = game.reaction_definitions[&"nest_samples"]
	game.build_state = RunBuildState.new({&"nest_samples": 0.0})
	game.stats.bind_run_build(game.build_state)
	game.build_state.add_modifier_dictionary(additive.id, 0, additive.modifiers[0])
	game._apply_immediate_reaction_boost(additive)
	game.reaction_boost_timer = 0.01
	game._case_mechanics_step(0.02)
	_near(game.build_state.value(&"nest_samples", 0.0), 4.0, "Temporäre Sofortmaßnahme endet ohne den dauerhaften Befundeffekt zu entfernen")

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s (erwartet %s, erhalten %s)" % [message, str(expected), str(actual)])

func _near(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	_check(absf(actual - expected) <= tolerance, "%s (erwartet %.4f, erhalten %.4f)" % [message, expected, actual])
