extends SceneTree

var assertions: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("_run_flow")

func _run_flow() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	# Flow assertions must start from a new local profile, independent of the
	# developer's real save (which is intentionally preserved by the test).
	game.persistence_enabled = false
	game.meta.reset_defaults()
	game.discovery_manager.configure(game.discovery_definitions, {})
	game.story_return_state = GameFlowState.State.CAMPUS
	game._set_flow(GameFlowState.State.STORY)
	game.hud.show_story()

	_check(game.flow_state == GameFlowState.State.STORY, "Neuer Spielstand öffnet direkt den Prolog")
	game._on_story_finished()
	_check(game.flow_state == GameFlowState.State.CAMPUS, "Prolog führt zum Praxis-Campus")

	game._on_navigate_requested(&"practice")
	_check(game.flow_state == GameFlowState.State.PRACTICE, "Praxis ist vom Campus erreichbar")
	game._on_back_requested()
	game._on_navigate_requested(&"research")
	_check(game.flow_state == GameFlowState.State.RESEARCH, "Forschung ist eine eigene Campusansicht")
	game._on_back_requested()
	game._on_navigate_requested(&"lexicon")
	_check(game.flow_state == GameFlowState.State.LEXICON, "Das medizinische Lexikon besitzt ein eigenes Campusgebäude")
	game._on_back_requested()
	game._on_navigate_requested(&"levels")
	_check(game.flow_state == GameFlowState.State.LEVEL_SELECT, "Fallarchiv ist vom Campus erreichbar")

	game._on_level_selected(&"intro")
	_check(game.flow_state == GameFlowState.State.PREPARATION, "Freigeschaltetes Intro öffnet direkt die Einsatzplanung")
	_check(game.pending_run_context != null and game.pending_loadout_draft != null, "Die Einsatzplanung besitzt einen stabilen RunContext und feste Slots")
	game._on_intro_skip_requested()
	_check(game.flow_state == GameFlowState.State.INTRO_SKIP_CONFIRMATION, "Die Introplanung bietet eine bestätigte Überspringen-Funktion")
	game._on_intro_skip_cancelled()
	_check(game.flow_state == GameFlowState.State.PREPARATION, "Intro-Überspringen kann ohne Freischaltung verworfen werden")
	game._on_preparation_start_requested(game.pending_preparation_loadout.to_dict())
	_check(game.flow_state == GameFlowState.State.RUNNING, "Die Einsatzplanung startet einen laufenden Run")
	var research_before_abort: int = game.meta.research_points
	game._set_flow(GameFlowState.State.MANUAL_PAUSE)
	game.hud.show_pause()
	game._on_abort_requested()
	_check(game.flow_state == GameFlowState.State.ABORT_CONFIRMATION, "Pause öffnet eine Abbruchbestätigung")
	game._on_abort_cancelled()
	_check(game.flow_state == GameFlowState.State.MANUAL_PAUSE, "Abbruch kann ohne Zustandsverlust verworfen werden")
	game._on_abort_requested()
	game._on_abort_confirmed()
	await process_frame
	_check(game.flow_state == GameFlowState.State.LEVEL_SELECT, "Bestätigter Abbruch kehrt zur Fallübersicht zurück")
	_check(game.meta.research_points == research_before_abort, "Abbruch vergibt keine Forschung")
	_check(game.meta.get_level_record(&"intro").attempts == 0, "Abbruch verändert keine Levelrekorde")

	game._on_level_selected(&"intro")
	game._on_preparation_start_requested(game.pending_preparation_loadout.to_dict())
	game.discovery_manager.mark_seen(&"research_reward")
	game.state.elapsed = 50.0
	game.state.mark_boss_defeated()
	await process_frame
	_check(game.flow_state == GameFlowState.State.RESULT, "Besiegter Boss führt zum Ergebnisbildschirm")
	_check(game.meta.highest_unlocked_level == 1, "Intro-Sieg schaltet exakt Fall 1 frei")
	_check(game.meta.get_level_record(&"intro").victories == 1, "Sieg wird im Levelrekord erfasst")
	var first_reward: int = game.meta.research_points

	game._show_level_select()
	game._on_level_selected(&"intro")
	game._on_preparation_start_requested(game.pending_preparation_loadout.to_dict())
	game.state.elapsed = 48.0
	game.state.mark_boss_defeated()
	await process_frame
	var replay_reward: int = game.meta.research_points - first_reward
	_check(replay_reward > 0 and replay_reward < first_reward, "Intro-Wiederholung vergibt die reduzierte Belohnung")
	_check(game.meta.highest_unlocked_level == 1, "Intro-Wiederholung überspringt keine Freischaltung")

	game.queue_free()
	await process_frame
	if failures == 0:
		print("ALVEOLUS_FLOW_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_FLOW_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)
