extends SceneTree

var assertions := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.physics_ticks_per_second = 240
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	game.persistence_enabled = false
	game.meta.reset_defaults()
	game.discovery_manager.configure(game.discovery_definitions, {})
	game._on_story_finished()
	game._show_level_select()
	game._on_level_selected(&"intro")
	game.start_run()

	_check(game.state.analysis_target == 3, "Intro starts with an explicit analysis target of three")
	_check(game.intro_phase == &"await_primary_materialization", "Intro waits for the first enemy to materialize")
	_check(game.intro_prompt_snapshot().text == "Beobachte den ersten Erreger.", "Run start publishes the observation prompt")
	_check(not game.intro_autoattack_enabled and game.projectiles.is_empty(), "Autoattack is disabled before observation")
	_check(is_instance_valid(game.intro_primary_enemy), "Run start creates exactly one primary enemy")
	_check(game.enemies.size() == 1, "No hidden tutorial followers exist at run start")

	game.run_session.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	_check(game.intro_phase == &"observe_primary", "Observation begins on actual materialization")
	_check(is_equal_approx(game.intro_observation_remaining, 3.0), "Materialization starts the full three-second observation window")
	game.run_session.step_fixed(2.99)
	_check(game.flow_state == GameFlowState.State.RUNNING and game.projectiles.is_empty(), "No autoattack fires before three observed seconds")
	game.run_session.step_fixed(0.02)
	_check(game.flow_state == GameFlowState.State.INTRO_CONFIRMATION, "Three observed seconds enter the dedicated confirmation flow")
	_check(game.run_session.lifecycle == RunSession.Lifecycle.PAUSED and game.get_tree().paused, "Intro confirmation pauses session and scene tree")
	_check(game.intro_prompt_snapshot().text == "Du greifst automatisch an." and game.intro_prompt_snapshot().requires_left_click, "Attack explanation requires a left-click confirmation")
	var paused_elapsed: float = game.state.elapsed
	_check(not game.run_session.step_fixed(1.0) and is_equal_approx(game.state.elapsed, paused_elapsed), "Paused intro confirmation freezes RunSession time")

	var direct_click := InputEventMouseButton.new()
	direct_click.button_index = MOUSE_BUTTON_LEFT
	direct_click.pressed = true
	game._unhandled_input(direct_click)
	_check(game.flow_state == GameFlowState.State.INTRO_CONFIRMATION, "game.gd does not consume the prompt's left click through a competing input route")
	game._on_run_prompt_confirmed()
	_check(game.flow_state == GameFlowState.State.RUNNING and game.run_session.lifecycle == RunSession.Lifecycle.RUNNING, "GameHUD confirmation resumes the fixed simulation")
	_check(game.intro_autoattack_enabled and game.intro_phase == &"await_primary_defeat", "Only confirmation enables tutorial autoattack")

	var primary: InfectionEnemy = game.intro_primary_enemy
	var primary_death_position := primary.global_position
	primary.take_damage(primary.health, &"therapy")
	_check(game.intro_phase == &"await_primary_pickup", "Primary death advances to the pickup lesson")
	_check(game.pickups.size() == 1, "Primary death creates one normal EXP drop")
	var primary_pickup: AnalysisPickup = game.pickups[0]
	_check(primary_pickup.global_position.is_equal_approx(primary_death_position), "Primary EXP is created exactly at the death position")
	_check(not primary_pickup.guided_to_target, "Primary EXP does not use the removed guided/avatar-offset path")
	_check(game.intro_prompt_snapshot().text == "Geh nah ran, um die EXP einzusammeln.", "Primary death publishes the collection prompt")

	game._on_pickup_collected(primary_pickup.analysis_value, primary_pickup)
	_check(game.state.analysis == 1 and game.state.level == 0, "First normal EXP contributes one of three analysis points")
	_check(game.enemies.size() == 2 and game.intro_phase == &"followup_combat", "Collecting primary EXP creates exactly two follow-up enemies")
	var followers: Array[InfectionEnemy] = []
	followers.assign(game.enemies)
	for enemy in followers:
		(enemy as InfectionEnemy).step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
		(enemy as InfectionEnemy).take_damage((enemy as InfectionEnemy).health, &"therapy")
	_check(game.intro_followup_defeats == 2 and game.pickups.size() == 2, "Both follow-up enemies die normally and each create EXP")

	var first_followup_pickup: AnalysisPickup = game.pickups[0]
	game._on_pickup_collected(first_followup_pickup.analysis_value, first_followup_pickup)
	_check(game.state.analysis == 2 and game.flow_state == GameFlowState.State.RUNNING, "Level-up remains locked until the second follow-up EXP is collected")
	var final_followup_pickup: AnalysisPickup = game.pickups[0]
	game._on_pickup_collected(final_followup_pickup.analysis_value, final_followup_pickup)
	_check(game.state.level == 1 and game.flow_state == GameFlowState.State.LEVEL_UP, "The third normal EXP triggers the normal level-up")
	_check(game.current_upgrade_options.size() == 3, "Intro level-up contains exactly three valid cards")
	_check(game.stats.run_build_state == game.build_state, "Intro cards apply to the same RunBuildState used by runtime stats")
	for definition in game.current_upgrade_options:
		_check(definition.path == UpgradeDefinition.Path.ANTIBIOTIC, "Intro cards exclude ability/immune paths")
		_check(definition.required_component_ids.has(&"treatment_precision"), "Every intro card applies to the stable treatment_precision component")

	game._on_upgrade_chosen(game.current_upgrade_options[0])
	_check(game.state.boss_spawned and is_instance_valid(game.active_boss), "Selecting one normal card starts the boss phase")
	_check(game.flow_state == GameFlowState.State.INTRO_CONFIRMATION and game.run_session.lifecycle == RunSession.Lifecycle.PAUSED, "Boss spawn waits in the dedicated paused confirmation flow")
	_check(game.intro_prompt_snapshot().text == "Infektionsherd erkannt" and game.intro_prompt_snapshot().semantic_mode == &"coral", "Boss confirmation publishes the persistent coral prompt")
	game._on_run_prompt_confirmed()
	_check(game.flow_state == GameFlowState.State.RUNNING and game.intro_phase == &"boss_active", "GameHUD boss confirmation alone resumes boss simulation")

	for discovery_id in [&"pneumococcus", &"automatic_therapy", &"analysis_pickup", &"infection_focus"]:
		_check(game.discovery_manager.has_seen(discovery_id), "Intro silently marks %s as seen" % discovery_id)
	_check(game.discovery_manager.active.is_empty() and game.discovery_manager.queue.is_empty(), "Intro learning events do not open or queue discovery modals")

	var settings := UISettingsState.new()
	settings.ui_scale = 2.0
	settings.glyph_mode = UISettingsState.GLYPH_GAMEPAD
	game._force_current_runtime_ui_settings(settings)
	_check(is_equal_approx(settings.ui_scale, 1.0) and settings.glyph_mode == UISettingsState.GLYPH_KEYBOARD, "Runtime normalizes legacy scale/glyph saves to 100 percent keyboard mode")

	var intro_boss: InfectionEnemy = game.active_boss
	game.run_session.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	intro_boss.take_damage(intro_boss.health, &"therapy")
	_check(game.flow_state == GameFlowState.State.DISCOVERY_PAUSE and game.hud.end_overlay.visible, "Der erste Introabschluss zeigt den normalen Rundenergebnis-Screen mit pausierendem Hinweis")
	_check(game.hud.discovery_tooltip.visible and game.hud.discovery_tooltip.gameplay_label.text == "Nutze Forschung im Forschungsgebäude für dauerhafte Upgrades.", "Intro-Hinweis erklärt kompakt den nächsten Forschungsschritt")
	_check(game.hud.discovery_tooltip.target_object == game.hud.end_reward, "Intro-Hinweis ist am tatsächlichen Forschungssymbol der Belohnung verankert")
	var expected_intro_reward := MetaProgressionState.intro_research_reward(1)
	_check(game.meta.research_points == expected_intro_reward, "Intro-Ergebnis vergibt Basisforschung plus Bossmultiplikator: %d (aktuell %d)" % [expected_intro_reward, game.meta.research_points])
	_check(game.meta.talent_points_earned() == 0, "Intro-Ergebnis vergibt noch keinen Talentpunkt")

	game.queue_free()
	await process_frame
	if failures == 0:
		print("ALVEOLUS_INTRO_RUNTIME_CONTRACT_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_INTRO_RUNTIME_CONTRACT_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)
