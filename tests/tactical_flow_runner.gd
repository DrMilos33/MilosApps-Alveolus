extends SceneTree

var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	get_root().add_child(game)
	# _ready() may read the normal save, but this runner must never mutate it.
	game.persistence_enabled = false
	game.meta.reset_defaults(710000)
	game.meta.prologue_seen = true
	game.meta.highest_unlocked_level = 1
	game.meta.research_ranks[&"stability_reserve"] = 1
	game.meta.research_ranks[&"sample_logistics"] = 1
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(StringName(discovery_id))
	await process_frame

	_test_preparation_and_determinism(game)
	_test_quick_restart_contract(game)
	await _test_run_abilities_finding_and_mastery(game)
	await _test_pause_abort_and_intro_regression(game)
	_test_save_v5_roundtrip(game)

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("ALVEOLUS_TACTICAL_FLOW_OK assertions=%d" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		printerr("ALVEOLUS_TACTICAL_FLOW_FAILED failures=%d assertions=%d" % [failures.size(), assertions])
		quit(1)

func _test_preparation_and_determinism(game: Node) -> void:
	var historical_plan: PreparedLoadout = game.meta.get_prepared_loadout(&"localized_focus")
	historical_plan.reserve_id = &"sample_logistics"
	game.meta.set_prepared_loadout(&"localized_focus", historical_plan)
	_check(game.meta.get_prepared_loadout(&"localized_focus").reserve_id == &"sample_logistics", "Ein historischer Spielstand darf seine Reserve weiterhin laden")
	game._show_level_select()
	game._on_level_selected(&"localized_focus")
	_check(game.flow_state == GameFlowState.State.PREPARATION, "Fall 1 öffnet direkt die Einsatzplanung")
	_check(game.pending_run_context != null, "Vorbereitung erzeugt einen RunContext")
	_check(game.pending_preparation_loadout.reserve_id == &"" and game.pending_run_context.loadout_snapshot.reserve_id == &"", "Die aktuelle Planung übernimmt eine historische Reserve nicht in einen neuen Run")
	_check(game.hud.planning_snapshot.mode == PlanningSnapshot.Mode.COMPONENT_PICK and game.hud.planning_snapshot.selected_slot_id == LoadoutSlotId.TREATMENT, "Die Planung startet direkt am markierten Behandlungsplatz")
	_check(bool((game.hud.preparation_slot_buttons[LoadoutSlotId.TREATMENT] as Button).get_meta(&"selected_slot", false)), "Der zuerst bediente Behandlungsplatz ist sichtbar ausgewählt")
	var first_seed: int = game.pending_run_context.seed
	var first_trait: StringName = game.pending_run_context.visible_trait_id
	var first_finding: StringName = game.pending_run_context.hidden_finding_id
	_check(first_seed != 0, "Der vorbereitete Fall besitzt einen stabilen Seed")
	_check(first_trait != &"" and game.case_traits.has(first_trait), "Das sichtbare Fallmerkmal stammt aus dem Katalog")
	_check(first_finding != &"" and game.finding_definitions.has(first_finding), "Der verborgene Befund stammt aus dem Katalog")
	_check(game.meta.validate_prepared_loadout(game.pending_preparation_loadout, game.loadout_modules, game.research_definitions).valid, "Das Default-Loadout ist gültig")

	game._on_back_requested()
	_check(game.flow_state == GameFlowState.State.LEVEL_SELECT, "Zurück aus der Vorbereitung führt ohne altes Briefing zur Fallauswahl")
	game._on_level_selected(&"localized_focus")
	_check(game.pending_run_context.seed == first_seed, "Erneutes Öffnen bewahrt den Fall-Seed")
	_check(game.pending_run_context.visible_trait_id == first_trait, "Fallmerkmal ist für denselben Seed deterministisch")
	_check(game.pending_run_context.hidden_finding_id == first_finding, "Befund ist für denselben Seed deterministisch")

	var loadout: PreparedLoadout = game.pending_preparation_loadout.duplicate_loadout()
	var validation: LoadoutValidationResult = game.meta.validate_prepared_loadout(loadout, game.loadout_modules, game.research_definitions)
	_check(validation.valid and loadout.reserve_id == &"", "Ein reservefreier neuer Plan ist gültig")
	game._on_preparation_start_requested(loadout.to_dict())
	_check(game.flow_state == GameFlowState.State.RUNNING, "Ein gültiger Plan startet den Run")
	_check(game.active_run_context.seed == first_seed, "Der Run verwendet exakt den vorbereiteten Seed")
	_check(game.active_loadout.reserve_id == &"", "Der neue Run bleibt auch nach dem Start reservefrei")
	_check(game.build_state != null and game.treatment_controller.enabled, "Grundbehandlung und Buildzustand sind aktiv")
	_check(game.ability_controller.runtime(0) != null and game.ability_controller.runtime(1) != null, "Q und E sind mit den vorbereiteten Fähigkeiten belegt")

func _test_quick_restart_contract(game: Node) -> void:
	var initial_context := _run_context_snapshot(game.active_run_context)
	var initial_seed: int = game.active_run_context.seed
	game.state.tick(1.25)
	var elapsed_before_cancel: float = game.state.elapsed
	game.meta.ui_settings.confirm_run_restart = true
	var restart_chord := _restart_chord()
	_check(game._is_quick_restart_event(restart_chord), "Nur der exakte Strg+R-Chord wird als Rundeneustart erkannt")
	var plain_r := _key_event(KEY_R)
	plain_r.pressed = true
	_check(not game._is_quick_restart_event(plain_r), "Ein einzelnes R bleibt für die Upgrade-Neuwahl reserviert")
	var shifted_restart := _restart_chord()
	shifted_restart.shift_pressed = true
	_check(not game._is_quick_restart_event(shifted_restart), "Strg+Umschalt+R löst keinen versehentlichen Neustart aus")

	game._unhandled_input(restart_chord)
	_check(game.flow_state == GameFlowState.State.RUN_RESTART_CONFIRMATION and paused, "Strg+R pausiert den Run in einer eigenen Neustartbestätigung")
	_check(game.ui_router.current_modal_id() == &"restart" and game.ui_router.modal_depth() == 1, "Die Neustartbestätigung besitzt genau eine modale Route")
	_check(game.hud.restart_overlay.visible, "Die bestätigungspflichtige Einstellung zeigt den Neustartdialog")
	game._on_restart_cancelled()
	_check(game.flow_state == GameFlowState.State.RUNNING and not paused, "Abbrechen kehrt verlustfrei in den laufenden Run zurück")
	_check(is_equal_approx(game.state.elapsed, elapsed_before_cancel), "Abbrechen setzt weder Runzeit noch Simulation zurück")
	_check(game.ui_router.modal_depth() == 0 and not game.hud.restart_overlay.visible, "Nach Abbrechen bleiben weder Modalroute noch Neustartoverlay zurück")

	var pause_event := InputEventAction.new()
	pause_event.action = &"pause_game"
	pause_event.pressed = true
	game._unhandled_input(pause_event)
	_check(game.flow_state == GameFlowState.State.MANUAL_PAUSE and game.ui_router.current_modal_id() == &"pause", "Der Neustartvertrag kann auch aus der manuellen Pause geprüft werden")
	game._unhandled_input(_restart_chord())
	_check(game.flow_state == GameFlowState.State.RUN_RESTART_CONFIRMATION and game.ui_router.modal_depth() == 2, "Aus der Pause liegt die Neustartfrage sauber über dem Pausemenü")
	game._on_restart_cancelled()
	_check(game.flow_state == GameFlowState.State.MANUAL_PAUSE and paused and game.ui_router.current_modal_id() == &"pause", "Abbrechen stellt den vorherigen Pausezustand mitsamt Route wieder her")
	game._unhandled_input(pause_event)
	_check(game.flow_state == GameFlowState.State.RUNNING and game.ui_router.modal_depth() == 0, "Fortsetzen schließt nach der Rückkehr auch die verbliebene Pausenroute")

	game.state.tick(0.75)
	game._unhandled_input(_restart_chord())
	game._on_restart_confirmed()
	_check(game.flow_state == GameFlowState.State.RUNNING and not paused and game.state.active, "Bestätigen startet dieselbe Runde unmittelbar neu")
	_check(game.active_run_context.seed == initial_seed and _run_context_snapshot(game.active_run_context) == initial_context, "Bestätigter Neustart bewahrt vollständigen RunContext und Seed")
	_check(is_zero_approx(game.state.elapsed), "Bestätigter Neustart setzt nur den Laufzustand auf den Anfang zurück")
	_check(game.ui_router.modal_depth() == 0 and not game.hud.restart_overlay.visible, "Bestätigter Neustart räumt alle geöffneten Modals auf")

	game.meta.ui_settings.confirm_run_restart = false
	game.state.tick(0.5)
	game._unhandled_input(_restart_chord())
	_check(game.flow_state == GameFlowState.State.RUNNING and not game.hud.restart_overlay.visible, "Bei ausgeschalteter Bestätigung startet Strg+R ohne Zwischendialog neu")
	_check(is_zero_approx(game.state.elapsed) and game.ui_router.modal_depth() == 0, "Direkter Neustart beginnt bei null und hinterlässt keine Modalroute")
	_check(game.active_run_context.seed == initial_seed and _run_context_snapshot(game.active_run_context) == initial_context, "Auch der direkte Neustart bewahrt RunContext und Seed")
	game.meta.ui_settings.confirm_run_restart = true

	# Godot prüft Action-Bindings standardmäßig nicht exakt. Der globale Chord
	# muss daher vor dem auf R liegenden Reroll konsumiert werden.
	var saved_options: Array[UpgradeDefinition] = game.current_upgrade_options.duplicate()
	var saved_reroll_available: bool = game.reroll_available
	var saved_reroll_used: bool = game.reroll_used
	game.reroll_available = true
	game.reroll_used = false
	game._set_flow(GameFlowState.State.LEVEL_UP)
	_check(_restart_chord().is_action_pressed(&"reroll_upgrades"), "Godots nicht-exakte Actionprüfung erkennt Strg+R zugleich als Reroll und reproduziert den Prioritätskonflikt")
	game._unhandled_input(_restart_chord())
	_check(game.flow_state == GameFlowState.State.LEVEL_UP and not game.reroll_used, "Strg+R wird vor der Reroll-Action konsumiert und löst in der Upgradepause keine Neuwahl aus")
	game.reroll_available = saved_reroll_available
	game.reroll_used = saved_reroll_used
	game.current_upgrade_options = saved_options
	game._set_flow(GameFlowState.State.RUNNING)

func _test_run_abilities_finding_and_mastery(game: Node) -> void:
	var q_event := InputEventAction.new()
	q_event.action = &"active_ability_1"
	q_event.pressed = true
	game._unhandled_input(q_event)
	_check(game.targeting_ability_slot == AbilityController.SLOT_Q, "Q öffnet für das Fokusfeld zuerst die Zielvorschau")
	_check(game.ability_target_preview.is_targeting(), "Die gezielte Fähigkeit besitzt eine sichtbare Vorschaugeometrie")
	var q_echo := InputEventKey.new()
	q_echo.physical_keycode = KEY_Q
	q_echo.pressed = true
	q_echo.echo = true
	game._unhandled_input(q_echo)
	_check(game.ability_controller.queued_command_count() == 0 and game.targeting_ability_slot == AbilityController.SLOT_Q, "Tastenwiederholung erzeugt keinen zweiten Fähigkeitsbefehl")
	# Fokusfeld ist eine gezielte Fähigkeit: Drücken öffnet die Vorschau,
	# Loslassen bestätigt sie und reiht den deterministischen Command ein.
	var q_release := InputEventAction.new()
	q_release.action = &"active_ability_1"
	q_release.pressed = false
	game._unhandled_input(q_release)
	_check(game.targeting_ability_slot == -1 and game.ability_controller.queued_command_count() == 1, "Loslassen bestätigt das Ziel und reiht genau einen Q-Command ein")
	var e_event := InputEventAction.new()
	e_event.action = &"active_ability_2"
	e_event.pressed = true
	game._unhandled_input(e_event)
	_check(game.ability_controller.queued_command_count() == 2, "Die Selbstfähigkeit E wird ohne Zielvorschau eingereiht")
	game.run_session.step_fixed(1.0 / 60.0)
	_check(game.ability_controller.queued_command_count() == 0, "Der feste Physiktakt verarbeitet die Ability-Commandqueue")
	_check(game.ability_feedback_world.active_count() >= 2, "Beide Fähigkeiten erzeugen unterscheidbares zentrales Feedback")
	_check(game.ability_controller.shield > 0.0 and game.hud.shield_panel.visible, "Notfallhilfe zeigt ihren wirksamen Schutz im Run-HUD")
	var q_runtime: AbilityRuntime = game.ability_controller.runtime(0)
	var e_runtime: AbilityRuntime = game.ability_controller.runtime(1)
	_check(q_runtime.cooldown_remaining > 0.0, "Q aktiviert die erste Fähigkeit und startet ihren Cooldown")
	_check(e_runtime.cooldown_remaining > 0.0, "E aktiviert die zweite Fähigkeit und startet ihren Cooldown")
	_check(int(game.mastery_tracker.ability_uses.get(0, 0)) == 1 and int(game.mastery_tracker.ability_uses.get(1, 0)) == 1, "Beide Fähigkeitseinsätze werden für Meisterschaft gezählt")

	var elapsed_before_pause: float = game.state.elapsed
	var q_before_pause: float = q_runtime.cooldown_remaining
	var pause_event := InputEventAction.new()
	pause_event.action = &"pause_game"
	pause_event.pressed = true
	game._unhandled_input(pause_event)
	_check(game.flow_state == GameFlowState.State.MANUAL_PAUSE and paused, "Escape pausiert den laufenden Run vollständig")
	await process_frame
	await process_frame
	_check(is_equal_approx(game.state.elapsed, elapsed_before_pause), "Runzeit friert in manueller Pause ein")
	_check(is_equal_approx(q_runtime.cooldown_remaining, q_before_pause), "Aktive Cooldowns frieren in manueller Pause ein")
	game._unhandled_input(pause_event)
	_check(game.flow_state == GameFlowState.State.RUNNING and not paused, "Escape setzt die manuelle Pause fort")

	var target: int = game.finding_controller.target
	_check(target > 0, "Der Hauptfall besitzt eine Befundschwelle")
	game.finding_controller.add_progress(target)
	_check(game.flow_state == GameFlowState.State.FINDING_PAUSE and paused, "Voller Befundfortschritt öffnet eine echte Befundpause")
	_check(game.finding_controller.revealed and not game.finding_controller.resolved, "Der Befund wartet auf eine Reaktionswahl")
	var finding: FindingDefinition = game.finding_controller.definition
	var reaction_id: StringName = finding.reaction_ids[0]
	var passive_ids_before_finding: Array[StringName] = game.active_loadout.passive_ids.duplicate()
	_check(not game.hud.finding_reserve_row.is_visible_in_tree() and game.hud.finding_swap_toggle.disabled, "Der Befund blendet die ruhende Reservebedienung vollständig aus")
	game._on_finding_confirmed(reaction_id, &"", &"")
	_check(game.flow_state == GameFlowState.State.RUNNING and not paused, "Reaktionswahl setzt den Run fort")
	_check(game.finding_controller.resolved and game.active_reaction.id == reaction_id, "Die gewählte Befundreaktion wird exakt angewendet")
	_check(game.active_loadout.passive_ids == passive_ids_before_finding and game.active_loadout.reserve_id == &"", "Eine Befundreaktion verändert den reservefreien Plan nicht versteckt")
	_check(not game.mastery_tracker.reserve_was_swapped, "Der ruhende Reservepfad erzeugt keinen versteckten Trackerzustand")

	var points_before: int = game.meta.talent_points_earned()
	game.state.mark_boss_defeated()
	await process_frame
	_check(game.flow_state == GameFlowState.State.RESULT, "Ein erfolgreicher Abschluss führt zum Ergebnis")
	_check(game.meta.has_completed_mastery(&"fall_1_first_victory"), "Der erste Fall-Sieg schaltet Meisterschaft frei")
	_check(game.meta.has_completed_mastery(&"fall_1_early_finding"), "Ein früher Befund wird am Ergebnis ausgewertet")
	_check(game.meta.has_completed_mastery(&"fall_1_healthy_win"), "Ein stabiler Abschluss wird am Ergebnis ausgewertet")
	_check(game.meta.talent_points_earned() >= points_before + 3, "Neue Meisterschaft vergibt getrennte Talentpunkte")
	_check(game.hud.end_mastery_panel.visible, "Das Ergebnis zeigt neue Meisterschaft sichtbar an")

func _test_pause_abort_and_intro_regression(game: Node) -> void:
	var research_before_abort: int = game.meta.research_points
	var attempts_before_abort: int = game.meta.get_level_record(&"localized_focus").attempts
	game._show_level_select()
	game._on_level_selected(&"localized_focus")
	game._on_preparation_start_requested(game.pending_preparation_loadout.to_dict())
	game._set_flow(GameFlowState.State.MANUAL_PAUSE)
	game.hud.show_pause(false, game.stats, game.state)
	game._on_abort_requested()
	_check(game.flow_state == GameFlowState.State.ABORT_CONFIRMATION, "Pause öffnet die Abbruchbestätigung")
	game._on_abort_cancelled()
	_check(game.flow_state == GameFlowState.State.MANUAL_PAUSE, "Ein Abbruch kann verlustfrei verworfen werden")
	game._on_abort_requested()
	game._on_abort_confirmed()
	await process_frame
	_check(game.flow_state == GameFlowState.State.LEVEL_SELECT, "Bestätigter Abbruch kehrt zur Fallauswahl zurück")
	_check(game.meta.research_points == research_before_abort, "Abbruch vergibt keine Forschung")
	_check(game.meta.get_level_record(&"localized_focus").attempts == attempts_before_abort, "Abbruch verändert keine Rekorde")

	game._on_level_selected(&"intro")
	_check(game.flow_state == GameFlowState.State.PREPARATION, "Das Intro verwendet dieselbe kompakte Einsatzplanung")
	game._on_preparation_start_requested(game.pending_preparation_loadout.to_dict())
	_check(game.flow_state == GameFlowState.State.RUNNING, "Der feste Introplan startet über dieselbe Hauptaktion")
	_check(game.intro_phase == &"await_movement" and game.intro_lesson == 1, "Das ereignisgesteuerte Intro beginnt unverändert mit Bewegung")
	_check(not game.treatment_controller.enabled and game.ability_controller.slots.is_empty(), "Taktische Hauptfall-Systeme überschreiben das Intro nicht")
	game._set_flow(GameFlowState.State.MANUAL_PAUSE)
	game.hud.show_pause(true, game.stats, game.state)
	game._on_abort_requested()
	game._on_abort_confirmed()
	await process_frame
	_check(game.flow_state == GameFlowState.State.LEVEL_SELECT, "Auch das Intro lässt sich weiterhin sauber abbrechen")

func _test_save_v5_roundtrip(game: Node) -> void:
	var save_path := "user://alveolus_tactical_flow_v5_test.json"
	var repository := MetaSaveRepository.new(save_path)
	_check(repository.save(game.meta), "Der integrierte Fortschritt lässt sich lokal speichern")
	var restored := MetaProgressionState.new(func() -> int: return 710000)
	_check(repository.load_into(restored), "Der lokale Save-v5-Roundtrip lässt sich laden")
	_check(int(restored.to_dict().get("version", 0)) == 5, "Der integrierte Spielstand verwendet Version 5")
	_check(restored.has_completed_mastery(&"fall_1_first_victory"), "Save-v5 bewahrt Ergebnis-Meisterschaft")
	_check(restored.get_prepared_loadout(&"localized_focus").reserve_id == &"", "Save-v5 bewahrt den für neue Runs reservefreien Behandlungsplan")
	var absolute_path := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_path)

func _restart_chord() -> InputEventKey:
	var event := _key_event(KEY_R)
	event.pressed = true
	event.ctrl_pressed = true
	return event

func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	return event

func _run_context_snapshot(context: RunContext) -> Dictionary:
	if context == null:
		return {}
	return {
		"level_id": context.level_id,
		"seed": context.seed,
		"visible_trait_id": context.visible_trait_id,
		"hidden_finding_id": context.hidden_finding_id,
		"loadout": context.loadout_snapshot.to_dict() if context.loadout_snapshot != null else {},
		"talents": context.talent_snapshot.duplicate(true),
	}

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
