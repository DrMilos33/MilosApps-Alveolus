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
	_check(game.levels.size() == 7, "Der taktische Ablauf verwendet Intro plus sechs Hauptfälle")
	game.meta.prologue_seen = true
	game.meta.highest_unlocked_level = 2
	game.meta.research_ranks[&"stability_reserve"] = 1
	game.meta.research_ranks[&"sample_logistics"] = 1
	game.meta.research_ranks[&"unlock_spread_treatment"] = 1
	game.meta.research_ranks[&"unlock_defense_burst"] = 1
	game.meta.research_ranks[&"unlock_treatment_line"] = 1
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(StringName(discovery_id))
	await process_frame

	_test_fall_one_preparation_guidance(game)
	_test_case_trait_reward_bonus()
	_test_preparation_and_determinism(game)
	_test_quick_restart_contract(game)
	await _test_run_abilities_and_mastery(game)
	await _test_pause_abort_and_intro_regression(game)
	_test_save_v7_roundtrip(game)

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

func _test_fall_one_preparation_guidance(game: Node) -> void:
	const GUIDANCE_COMPLETE := &"fall1_defense_burst_guidance_complete"
	game._show_level_select()
	game._on_level_selected(&"early_localized_focus")
	_check(game.pending_preparation_guidance_active and game.hud.preparation_guidance_panel.visible, "Fall 1 startet vor dem ersten Abschluss mit der sichtbaren Stoß-Führung")
	_check(game.hud.preparation_guidance_label.text.contains("Aktiv 1") and game.hud.preparation_guidance_hide.text == "Hinweise ausblenden", "Die Fall-1-Führung nennt zuerst den Zielplatz und bietet den globalen Ausblendpfad")
	game.hud.preparation_guidance_hide.pressed.emit()
	_check(not game.meta.ui_settings.show_discovery_info and not game.pending_preparation_guidance_active and not game.hud.preparation_guidance_panel.visible, "‚Hinweise ausblenden‘ beendet die aktuelle Führung und bewahrt den ausgeschalteten Zustand")
	_check(bool(game.meta.tutorial_status.get(GUIDANCE_COMPLETE, false)), "Der Ausblendpfad markiert die Fall-1-Führung als erledigt")

	game._on_back_requested()
	game.meta.set_tutorial_step(GUIDANCE_COMPLETE, false)
	game.meta.ui_settings.show_discovery_info = true
	game._on_hints_disabled()
	game.meta.ui_settings.show_discovery_info = true
	game._on_level_selected(&"early_localized_focus")
	_check(not game.pending_preparation_guidance_active and bool(game.meta.tutorial_status.get(GUIDANCE_COMPLETE, false)), "Globales Ausblenden erledigt die Fall-1-Führung dauerhaft auch vor ihrem Öffnen")
	game._on_back_requested()
	game.meta.ui_settings.show_discovery_info = true
	game.meta.set_tutorial_step(GUIDANCE_COMPLETE, false)
	game._on_level_selected(&"early_localized_focus")
	_check(game.pending_preparation_guidance_active and game.hud.current_preparation_guidance_step == &"active_1", "Aktive Hinweise führen Fall 1 erneut kontrolliert zum Platz Aktiv 1")
	game.hud._on_preparation_slot_pressed(LoadoutSlotId.ACTIVE_1)
	_check(game.hud.current_preparation_guidance_step == &"defense_burst" and game.hud.preparation_guidance_label.text.contains("Stoß"), "Nach Aktiv 1 führt der zweite Schritt ausdrücklich zu Stoß")
	var defense_burst_button := game.hud.preparation_component_buttons.get(&"ability_defense_burst", null) as Button
	_check(defense_burst_button != null and not defense_burst_button.disabled, "Im zweiten Führungsschritt bleibt Stoß als Ziel auswählbar")
	game.hud._on_preparation_component(&"ability_defense_burst", false)
	_check(game.pending_loadout_draft.component_at(LoadoutSlotId.ACTIVE_1) == &"ability_defense_burst", "Die geführte Auswahl rüstet Stoß exakt auf Aktiv 1 aus")
	_check(not game.pending_preparation_guidance_active and not game.hud.preparation_guidance_panel.visible and bool(game.meta.tutorial_status.get(GUIDANCE_COMPLETE, false)), "Die erfolgreiche Stoß-Auswahl beendet und speichert die Führung")
	game._on_back_requested()


func _test_case_trait_reward_bonus() -> void:
	var reward_without_traits := MetaProgressionState.calculate_run_reward(false, 0.0, 10, 80, 1.0, 0, 0)
	var reward_with_two_traits := MetaProgressionState.calculate_run_reward(false, 0.0, 10, 80, 1.0, 0, 2)
	_check(is_equal_approx(MetaProgressionState.case_trait_reward_multiplier(2), 1.30), "Zwei Fallmerkmale addieren exakt 30 Prozent Forschungsbonus")
	_check(reward_without_traits == 90 and reward_with_two_traits == 117, "Der additive 30-Prozent-Bonus wird ohne Rundungsunschärfe auf die Forschungsbelohnung angewendet")

func _test_preparation_and_determinism(game: Node) -> void:
	var historical_plan := PreparedLoadout.create(
		&"treatment_spread",
		[&"ability_focus_field", &"ability_emergency_support"],
		[&"stability_reserve", &"sample_logistics"],
		&"sample_logistics"
	)
	game.meta.set_prepared_loadout(&"localized_focus", historical_plan)
	_check(game.meta.get_prepared_loadout(&"localized_focus").to_dict() == historical_plan.to_dict(), "Ein historischer Spielstand darf seinen vollständigen alten Plan weiterhin laden")
	game._show_level_select()
	game._on_level_selected(&"localized_focus")
	_check(game.selected_level != null and game.selected_level.order == 2, "localized_focus bleibt als Fall-2-Anker erhalten")
	_check(game.flow_state == GameFlowState.State.PREPARATION, "Fall 2 öffnet direkt die Einsatzplanung")
	_check(game.hud.preparation_level_facts == null and game.hud.preparation_boss_fact == null, "Ein noch nicht abgeschlossener Fall verbirgt Dauer und Bossspawn")
	_check(game.pending_run_context != null, "Vorbereitung erzeugt einen RunContext")
	_check(game.pending_preparation_loadout.treatment_id == &"treatment_spread", "Die aktuelle Planung bewahrt eine der drei erlaubten Behandlungen")
	_check(game.pending_preparation_loadout.ability_ids.is_empty(), "Die aktuelle Planung entfernt alte Aktive, ohne freie Plätze heimlich zu befüllen")
	_check(game.pending_preparation_loadout.passive_ids.is_empty() and game.pending_preparation_loadout.reserve_id == &"" and game.pending_run_context.loadout_snapshot.reserve_id == &"", "Die aktuelle Planung übernimmt keine historischen Passiven oder Reserve in einen neuen Run")
	_check(game.meta.get_prepared_loadout(&"localized_focus").to_dict() == historical_plan.to_dict(), "Bloßes Öffnen bereinigt den gespeicherten Altplan nicht destruktiv")
	_check(game.hud.planning_snapshot.mode == PlanningSnapshot.Mode.COMPONENT_PICK and game.hud.planning_snapshot.selected_slot_id == LoadoutSlotId.TREATMENT, "Die Planung startet direkt am markierten Behandlungsplatz")
	_check(bool((game.hud.preparation_slot_buttons[LoadoutSlotId.TREATMENT] as Button).get_meta(&"selected_slot", false)), "Der zuerst bediente Behandlungsplatz ist sichtbar ausgewählt")
	var first_seed: int = game.pending_run_context.seed
	_check(first_seed != 0, "Der vorbereitete Fall besitzt einen stabilen Seed")
	_check(game.pending_run_context.visible_trait_ids.is_empty(), "Der erste Versuch vor einem Abschluss besitzt keine Fallmerkmale")
	_check(game.pending_loadout_draft.validate().valid, "Das Default-Loadout ist gegen den aktuellen Testkatalog gültig")

	game._on_back_requested()
	_check(game.flow_state == GameFlowState.State.LEVEL_SELECT, "Zurück aus der Vorbereitung führt ohne altes Briefing zur Fallauswahl")
	_check(game.meta.get_prepared_loadout(&"localized_focus").to_dict() == historical_plan.to_dict(), "Zurück bewahrt den historischen Plan und alle alten Werte")
	var levels := ContentCatalog.level_definitions()
	var first_case := levels[1] as LevelDefinition
	var level := levels[2] as LevelDefinition
	_check(first_case.id == &"early_localized_focus" and first_case.order == 1, "Der neue Fall 1 besitzt seinen eigenen Fortschrittsanker")
	_check(level.id == &"localized_focus" and level.order == 2, "Die deterministische Taktikspur verwendet localized_focus als Fall 2")
	game.meta.register_level_result(first_case, true, 120.0, 3, 20)
	game._on_level_selected(&"localized_focus")
	_check(game.hud.preparation_level_facts == null and game.hud.preparation_boss_fact == null, "Der Sieg eines anderen Falls enthüllt Dauer und Bosszeit von Fall 2 nicht")
	game._on_back_requested()
	game.meta.register_level_result(level, true, 120.0, 3, 20)
	game.meta.advance_case_seed(level.id)
	game._on_level_selected(&"localized_focus")
	_check(game.hud.preparation_level_facts != null and game.hud.preparation_boss_fact != null, "Nur der konkrete abgeschlossene Fall enthüllt Dauer und Bossspawn")
	first_seed = game.pending_run_context.seed
	var first_traits: Array[StringName] = game.pending_run_context.visible_trait_ids.duplicate()
	_check(first_traits.size() == 2 and first_traits[0] != first_traits[1], "Nach dem ersten Fallsieg erscheinen genau zwei unterschiedliche sichtbare Fallmerkmale")
	_check(first_traits.all(func(trait_id: StringName) -> bool: return game.case_traits.has(trait_id)), "Beide sichtbaren Fallmerkmale stammen aus dem Katalog")
	game.meta.register_level_result(level, false, 90.0, 2, 12)
	game._on_back_requested()
	game._on_level_selected(&"localized_focus")
	_check(game.pending_run_context.seed == first_seed, "Niederlage und erneutes Öffnen bewahren den Fall-Seed")
	_check(game.pending_run_context.visible_trait_ids == first_traits, "Niederlage und erneutes Öffnen bewahren dasselbe geordnete Merkmalspaar")

	var loadout: PreparedLoadout = game.pending_preparation_loadout.duplicate_loadout()
	game._on_preparation_slot_component_requested(LoadoutSlotId.ACTIVE_1, &"ability_defense_burst")
	game._on_preparation_slot_component_requested(LoadoutSlotId.ACTIVE_2, &"ability_treatment_line")
	loadout = game.pending_loadout_draft.to_prepared()
	var validation: LoadoutValidationResult = LoadoutValidator.validate(
		loadout,
		game.loadout_modules,
		LoadoutAvailabilityPolicy.selectable_ids(game.loadout_modules, game.meta.research_ranks, true),
		game.meta.preparation_capacity()
	)
	_check(validation.valid and loadout.reserve_id == &"", "Ein reservefreier neuer Plan ist gültig")
	game._on_preparation_start_requested(loadout.to_dict())
	_check(game.flow_state == GameFlowState.State.RUNNING, "Ein gültiger Plan startet den Run")
	_check(game.active_run_context.seed == first_seed, "Der Run verwendet exakt den vorbereiteten Seed")
	_check(game.active_loadout.ability_ids == [&"ability_defense_burst", &"ability_treatment_line"], "Der Run startet ausschließlich mit den beiden aktiven Testfähigkeiten")
	var line_hud_view: Dictionary = game._ability_hud_view(game.ability_definitions[&"ability_treatment_line"])
	var line_hud_facts := str(line_hud_view.get("fact_rows", []))
	_check(not line_hud_facts.contains("Breite") and not line_hud_facts.to_lower().contains("px"), "Das Fähigkeitstooltip erfindet für Breite keine lokale Distanzstufe oder Pixelanzeige")
	_check(game.active_loadout.passive_ids.is_empty() and game.active_loadout.reserve_id == &"", "Der neue Run bleibt auch nach dem Start passiv- und reservefrei")
	_check(not game.reroll_available and game.state.analysis == 0 and game.stats.immune_level == 0, "Keine versteckte Passivwirkung wird beim Runstart aktiviert")
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

func _test_run_abilities_and_mastery(game: Node) -> void:
	var ability_buttons: Array[Button] = game.hud.run_hud_screen.ability_buttons()
	_check(ability_buttons.size() == 2 and not ability_buttons[0].disabled and not ability_buttons[1].disabled, "Das RunHUDOverlay exponiert beide belegten Fähigkeiten als aktive UI-Aktionen")
	ability_buttons[0].pressed.emit()
	_check(game.targeting_ability_slot == AbilityController.SLOT_Q, "Die erste Run-HUD-Aktion öffnet für den Abwehrstoß die Zielvorschau")
	_check(game.ability_target_preview.is_targeting(), "Die gezielte Fähigkeit besitzt eine sichtbare Vorschaugeometrie")
	var q_echo := InputEventKey.new()
	q_echo.physical_keycode = KEY_Q
	q_echo.pressed = true
	q_echo.echo = true
	game._unhandled_input(q_echo)
	_check(game.ability_controller.queued_command_count() == 0 and game.targeting_ability_slot == AbilityController.SLOT_Q, "Tastenwiederholung erzeugt keinen zweiten Fähigkeitsbefehl")
	# Abwehrstoß ist eine gezielte Fähigkeit: Die erste Aktivierung öffnet die
	# Vorschau, dieselbe UI-Aktion bestätigt sie anschließend deterministisch.
	ability_buttons[0].pressed.emit()
	_check(game.targeting_ability_slot == -1 and game.ability_controller.queued_command_count() == 1, "Die zweite Aktivierung bestätigt das Ziel und reiht genau einen Q-Command ein")
	var e_event := InputEventAction.new()
	e_event.action = &"active_ability_2"
	e_event.pressed = true
	game._unhandled_input(e_event)
	_check(game.targeting_ability_slot == AbilityController.SLOT_E and game.ability_controller.queued_command_count() == 1, "Die Behandlungslinie E öffnet ihre gerichtete Zielvorschau")
	var e_release := InputEventAction.new()
	e_release.action = &"active_ability_2"
	e_release.pressed = false
	game._unhandled_input(e_release)
	_check(game.targeting_ability_slot == -1 and game.ability_controller.queued_command_count() == 2, "Das Loslassen von E bestätigt die Behandlungslinie")
	game.run_session.step_fixed(1.0 / 60.0)
	_check(game.ability_controller.queued_command_count() == 0, "Der feste Physiktakt verarbeitet die Ability-Commandqueue")
	_check(game.ability_feedback_world.active_count() >= 2, "Beide Fähigkeiten erzeugen unterscheidbares zentrales Feedback")
	_check(is_zero_approx(game.ability_controller.shield) and not game.hud.shield_panel.visible, "Der neue Standardplan erzeugt keinen versteckten Schutz")
	var q_runtime: AbilityRuntime = game.ability_controller.runtime(0)
	var e_runtime: AbilityRuntime = game.ability_controller.runtime(1)
	_check(q_runtime.cooldown_remaining > 0.0, "Q aktiviert die erste Fähigkeit und startet ihren Cooldown")
	_check(e_runtime.cooldown_remaining > 0.0, "E aktiviert die zweite Fähigkeit und startet ihren Cooldown")
	_check(int(game.mastery_tracker.ability_uses.get(0, 0)) == 1 and int(game.mastery_tracker.ability_uses.get(1, 0)) == 1, "Beide Fähigkeitseinsätze werden für Meisterschaft gezählt")
	var alert_before_blocked: String = game.hud.alert_label.text
	var sound_before_blocked: int = game.ui_sound_service.next_player
	game._begin_or_queue_ability(0, AbilityCommand.InputDevice.KEYBOARD_MOUSE)
	_check(game.hud.alert_label.text == alert_before_blocked, "Eine noch abklingende Fähigkeit blendet keinen Text ein")
	_check(game.ui_sound_service.next_player == (sound_before_blocked + 1) % UISoundService.PLAYER_COUNT, "Eine noch abklingende Fähigkeit antwortet ausschließlich mit einem leichten Sound")
	var queued_cooldown := AbilityExecutionResult.new()
	queued_cooldown.code = AbilityExecutionResult.Code.COOLDOWN
	queued_cooldown.reason = "Der Eingriff ist noch nicht bereit."
	var sound_before_queued_block: int = game.ui_sound_service.next_player
	game._on_ability_execution_completed(queued_cooldown)
	_check(game.hud.alert_label.text == alert_before_blocked, "Auch ein verzögert abgewiesener Cooldown erzeugt keinen Textalarm")
	_check(game.ui_sound_service.next_player == (sound_before_queued_block + 1) % UISoundService.PLAYER_COUNT, "Ein verzögert abgewiesener Cooldown verwendet denselben leichten Sound")
	var sound_before_empty: int = game.ui_sound_service.next_player
	game._begin_or_queue_ability(7, AbilityCommand.InputDevice.KEYBOARD_MOUSE)
	_check(game.hud.alert_label.text == alert_before_blocked and game.ui_sound_service.next_player == sound_before_empty, "Ein unbelegter Fähigkeitsslot bleibt vollständig stumm")

	var elapsed_before_pause: float = game.state.elapsed
	var q_before_pause: float = q_runtime.cooldown_remaining
	var pause_event := InputEventAction.new()
	pause_event.action = &"pause_game"
	pause_event.pressed = true
	game.hud.run_hud_screen.pause_action().pressed.emit()
	_check(game.flow_state == GameFlowState.State.MANUAL_PAUSE and paused, "Die Pauseaktion des RunHUDOverlay pausiert den laufenden Run vollständig")
	await process_frame
	await process_frame
	_check(is_equal_approx(game.state.elapsed, elapsed_before_pause), "Runzeit friert in manueller Pause ein")
	_check(is_equal_approx(q_runtime.cooldown_remaining, q_before_pause), "Aktive Cooldowns frieren in manueller Pause ein")
	game._unhandled_input(pause_event)
	_check(game.flow_state == GameFlowState.State.RUNNING and not paused, "Escape setzt die manuelle Pause fort")

	var points_before: int = game.meta.talent_points_earned()
	for _boss_index in range(game.state.boss_count_target):
		game.state.mark_boss_defeated()
	await process_frame
	_check(game.flow_state == GameFlowState.State.RESULT, "Ein erfolgreicher Abschluss führt zum Ergebnis")
	_check(game.meta.has_completed_mastery(&"fall_2_first_victory"), "Der Fall-2-Sieg schaltet seine erste Meisterschaft frei")
	_check(game.meta.has_completed_mastery(&"fall_2_reserve_win"), "Je ein Einsatz beider Aktivfähigkeiten erfüllt die erhaltene Fall-2-Meisterschaft")
	_check(not game.meta.has_completed_mastery(&"fall_2_active_usage"), "Je ein Einsatz erfüllt die Vierfach-Nutzung noch nicht")
	_check(game.meta.talent_points_earned() == points_before + 2, "Die zwei erfüllten Fall-2-Meisterschaften vergeben je einen Talentpunkt")
	_check(game.hud.end_mastery_panel.visible, "Das Ergebnis zeigt neue Meisterschaft sichtbar an")
	_check(game.hud.end_mastery_label.text.to_lower().contains("+2 talentpunkte"), "Das Ergebnis zeigt die zwei neuen Fall-2-Talentpunkte sichtbar an")

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
	_check(game.intro_phase == &"await_primary_materialization" and game.intro_lesson == 1, "Das Intro beginnt mit der Beobachtung des ersten Erregers")
	_check(game.state.analysis_target == 3 and game.hud.run_prompt.message_label().text == "Beobachte den ersten Erreger.", "Das Intro zeigt sein Drei-Proben-Ziel und den containerlosen Beobachtungsprompt")
	_check(not game.treatment_controller.enabled and game.ability_controller.slots.is_empty(), "Taktische Hauptfall-Systeme überschreiben das Intro nicht")
	game._set_flow(GameFlowState.State.MANUAL_PAUSE)
	game.hud.show_pause(true, game.stats, game.state)
	game._on_abort_requested()
	game._on_abort_confirmed()
	await process_frame
	_check(game.flow_state == GameFlowState.State.LEVEL_SELECT, "Auch das Intro lässt sich weiterhin sauber abbrechen")

func _test_save_v7_roundtrip(game: Node) -> void:
	var save_path := "user://alveolus_tactical_flow_v7_test.json"
	var repository := MetaSaveRepository.new(save_path)
	_check(repository.save(game.meta), "Der integrierte Fortschritt lässt sich lokal speichern")
	var restored := MetaProgressionState.new(func() -> int: return 710000)
	_check(repository.load_into(restored), "Der lokale Save-v7-Roundtrip lässt sich laden")
	_check(int(restored.to_dict().get("version", 0)) == 7, "Der integrierte Spielstand verwendet Version 7")
	_check(restored.has_completed_mastery(&"fall_2_first_victory"), "Save v7 bewahrt die Fall-2-Ergebnis-Meisterschaft")
	_check(restored.get_prepared_loadout(&"localized_focus").reserve_id == &"", "Save v7 bewahrt den für neue Runs reservefreien Behandlungsplan")
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
		"visible_trait_ids": context.visible_trait_ids.duplicate(),
		"loadout": context.loadout_snapshot.to_dict() if context.loadout_snapshot != null else {},
		"talents": context.talent_snapshot.duplicate(true),
	}

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
