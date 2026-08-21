extends SceneTree

var assertions := 0
var failures := 0


func _init() -> void:
	call_deferred("_run_intro")


func _run_intro() -> void:
	Engine.physics_ticks_per_second = 240
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	# The UI regression is deliberately independent from the developer's save.
	# Runtime timing and spawn details live in intro_runtime_contract_runner; this
	# runner owns the actual GameHUD prompt and three-card presentation boundary.
	game.persistence_enabled = false
	game.meta.reset_defaults()
	game.discovery_manager.configure(game.discovery_definitions, {})
	game._on_story_finished()
	game._show_level_select()
	game._on_level_selected(&"intro")
	game.start_run()

	_check(game.stats.prepared_treatment != null and game.stats.prepared_treatment.id == &"treatment_precision", "Intro bewahrt die stabile Behandlungs-ID")
	_check(game.stats.prepared_treatment.display_name == "Impuls", "Die sichtbare Intro-Behandlung heißt Impuls")
	_check(game.state.analysis_target == 3, "Das Intro zeigt ein explizites Analyseziel von drei")
	_check(_prompt_shows(game.hud, "Beobachte den ersten Erreger.", PlainRunPrompt.MODE_NORMAL, false), "Der erste containerlose Beobachtungsprompt ist sichtbar")

	game.run_session.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	game.run_session.step_fixed(3.01)
	_check(game.flow_state == GameFlowState.State.INTRO_CONFIRMATION, "Nach der Beobachtung wartet das Intro in der eigenen Bestätigung")
	_check(_prompt_shows(game.hud, "Du greifst automatisch an.", PlainRunPrompt.MODE_NORMAL, true), "Die Autoangriffserklärung wartet containerlos auf Linksklick")
	_check(game.hud.run_prompt.mouse_hint_label().text == "Linksklick zum Fortfahren", "Der bestätigungspflichtige Prompt nennt den einzigen Fortsetzungsweg")

	var keyboard_accept := InputEventKey.new()
	keyboard_accept.keycode = KEY_ENTER
	keyboard_accept.pressed = true
	game.hud.run_prompt._gui_input(keyboard_accept)
	_check(game.flow_state == GameFlowState.State.INTRO_CONFIRMATION, "Tastatur-Accept löst die Linksklicklektion nicht aus")
	_confirm_prompt_with_left_click(game)
	_check(game.flow_state == GameFlowState.State.RUNNING and game.intro_autoattack_enabled, "Genau der HUD-Linksklick aktiviert den Autoangriff")
	_check(not game.hud.run_prompt.visible, "Bestätigte Promptcopy wird vom Runtime-Presenter ausgeblendet")

	var primary: InfectionEnemy = game.intro_primary_enemy
	primary.take_damage(primary.health, &"therapy")
	_check(_prompt_shows(game.hud, "Geh nah ran, um die EXP einzusammeln.", PlainRunPrompt.MODE_NORMAL, false), "Der EXP-Hinweis nutzt dieselbe containerlose View")
	_check(game.pickups.size() == 1, "Der erste Gegner hinterlässt genau einen normalen EXP-Drop")
	var primary_pickup: AnalysisPickup = game.pickups[0]
	game._on_pickup_collected(primary_pickup.analysis_value, primary_pickup)
	_check(game.state.analysis == 1 and game.enemies.size() == 2, "Der erste Drop erzeugt genau zwei Folgegegner")

	var followers: Array[InfectionEnemy] = []
	followers.assign(game.enemies)
	for enemy in followers:
		enemy.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
		enemy.take_damage(enemy.health, &"therapy")
	_check(game.pickups.size() == 2, "Beide Folgegegner hinterlassen je einen normalen EXP-Drop")
	var second_pickup: AnalysisPickup = game.pickups[0]
	game._on_pickup_collected(second_pickup.analysis_value, second_pickup)
	_check(game.state.analysis == 2 and game.flow_state == GameFlowState.State.RUNNING, "Zwei Drops reichen noch nicht für Level Up")
	var third_pickup: AnalysisPickup = game.pickups[0]
	game._on_pickup_collected(third_pickup.analysis_value, third_pickup)
	await process_frame
	await process_frame

	_check(game.flow_state == GameFlowState.State.LEVEL_UP, "Der dritte normale EXP-Drop öffnet Level Up")
	_check(game.current_upgrade_options.size() == 3, "Das Intro zeigt exakt drei normale Upgradeoptionen")
	_check(game.hud.upgrade_screen.cards().size() == 3, "Das sichtbare Level-Up enthält drei Karten")
	_check(
		game.hud.upgrade_screen.selection_helper().visible
		and game.hud.upgrade_screen.selection_helper().text == "1 von 3 Upgrades aussuchen",
		"Das Intro-Level-Up zeigt den knappen Auswahlhinweis"
	)
	for card in game.hud.upgrade_screen.cards():
		var title := card.find_child("UpgradeTitle", true, false) as Label
		var comparison := card.find_child("UpgradeComparison", true, false) as RichTextLabel
		var value_row := card.find_child("UpgradeValue_*", true, false) as RichTextLabel
		_check(title != null and title.text == "Impuls", "Jede Introkartenüberschrift nennt ausschließlich die betroffene Komponente Impuls")
		_check(
			(comparison != null and not str(comparison.get_meta(&"semantic_after", "")).is_empty())
			or (value_row != null and not str(value_row.get_meta(&"semantic_value", "")).is_empty()),
			"Jede Introkarte behält ihren normalen datengetriebenen Vorher-Nachher-Vergleich"
		)

	game._on_upgrade_chosen(game.current_upgrade_options[0])
	await process_frame
	_check(game.flow_state == GameFlowState.State.INTRO_CONFIRMATION and game.state.boss_spawned, "Eine normale Karte startet die pausierte Bossbestätigung")
	_check(_prompt_shows(game.hud, "Infektionsherd erkannt", PlainRunPrompt.MODE_CORAL, true), "Der Boss erscheint als persistenter korallener Plain-Prompt")
	_check(game.hud.run_prompt.message_label().modulate.is_equal_approx(AlveolusVisualTheme.CORAL), "Der Bosswarntext verwendet die zentrale Korallenfarbe")
	_confirm_prompt_with_left_click(game)
	_check(game.flow_state == GameFlowState.State.RUNNING and game.intro_phase == &"boss_active", "Nur der HUD-Linksklick startet die Bosssimulation")

	for discovery_id in [&"pneumococcus", &"automatic_therapy", &"analysis_pickup", &"infection_focus"]:
		_check(game.discovery_manager.has_seen(discovery_id), "Das Intro markiert %s still als gesehen" % discovery_id)
	_check(game.discovery_manager.active.is_empty() and game.discovery_manager.queue.is_empty(), "Introhinweise öffnen keine konkurrierenden Entdeckungsmodals")

	game.active_boss._physics_process(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	game.discovery_manager.mark_seen(&"research_reward")
	game.active_boss.take_damage(9999.0, &"therapy")
	_check(game.flow_state == GameFlowState.State.RESULT, "Der Mini-Boss beendet das ereignisgesteuerte Intro regulär")

	game.queue_free()
	await process_frame
	if failures == 0:
		print("ALVEOLUS_INTRO_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_INTRO_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)


func _prompt_shows(hud: GameHUD, expected_text: String, expected_mode: StringName, awaits_click: bool) -> bool:
	if hud == null or hud.run_prompt == null:
		return false
	var prompt := hud.run_prompt
	return (
		prompt.is_visible_in_tree()
		and prompt.message_label().text == expected_text
		and prompt.semantic_mode() == expected_mode
		and prompt.is_awaiting_left_click() == awaits_click
		and prompt.find_children("*", "Panel", true, false).is_empty()
		and prompt.find_children("*", "ColorRect", true, false).is_empty()
	)


func _confirm_prompt_with_left_click(game: Node) -> void:
	var left_click := InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.pressed = true
	game.hud.run_prompt._gui_input(left_click)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)
