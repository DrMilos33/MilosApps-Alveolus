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
	game._on_story_finished()
	game._show_level_select()
	game._on_level_selected(&"intro")
	game.start_run()
	_check(game.intro_phase == &"await_movement", "Intro wartet zuerst auf echte Bewegung")
	game.state.tick(999.0)
	_check(game.state.active and not game.state.boss_spawned, "Ereignisintro besitzt keine Zeitdeadline")

	# Run the real physics path up to the first upgrade. This deliberately does
	# not call damage or pickup handlers directly, so a stuck live intro fails.
	game.avatar.global_position = Vector2(40.0, 0.0)
	var observed_discoveries: Array[StringName] = []
	for _frame in range(1200):
		await physics_frame
		if game.flow_state == GameFlowState.State.DISCOVERY_PAUSE and not game.discovery_manager.active.is_empty():
			observed_discoveries.append(game.discovery_manager.active["id"])
			game._on_discovery_dismissed()
		if game.flow_state == GameFlowState.State.LEVEL_UP:
			break
	_check(observed_discoveries.has(&"pneumococcus"), "Der reale Introablauf erklärt die erste Pneumokokke")
	_check(observed_discoveries.has(&"automatic_therapy"), "Der reale Introablauf erklärt den ersten Therapieimpuls")
	_check(observed_discoveries.has(&"analysis_pickup"), "Der reale Introablauf erklärt die erste Analyse")
	_check(game.flow_state == GameFlowState.State.LEVEL_UP, "Die echte Analyseaufnahme startet die erste Ein-Karten-Lektion")
	if game.flow_state != GameFlowState.State.LEVEL_UP or game.current_upgrade_options.is_empty():
		printerr("INTRO_DEBUG phase=%s flow=%s enemies=%d pickups=%d discoveries=%s" % [game.intro_phase, game.flow_state, game.enemies.size(), game.pickups.size(), observed_discoveries])
		game.queue_free()
		await process_frame
		quit(1)
		return
	_check(game.current_upgrade_options.size() == 1 and game.current_upgrade_options[0].id == &"potency", "Lektion 1 zeigt nur Gezielte Wirksamkeit")
	var potency_preview: UpgradePreview = game.stats.preview_upgrade(game.current_upgrade_options[0])
	_check(potency_preview.effect_text == "+8 Wirkung" and potency_preview.before_after_text.contains("18") and potency_preview.before_after_text.contains("26"), "Antibiotika-Karte zeigt exakt 18 auf 26")
	game._on_upgrade_chosen(game.current_upgrade_options[0])

	var potency_enemy: InfectionEnemy = game.intro_primary_enemy
	potency_enemy._physics_process(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	potency_enemy.take_damage(26.0, &"therapy")
	_check(game.flow_state == GameFlowState.State.LEVEL_UP and game.current_upgrade_options[0].id == &"neutrophils", "Treffer mit neuem Wert startet nur die Immunlektion")
	var immune_preview: UpgradePreview = game.stats.preview_upgrade(game.current_upgrade_options[0])
	_check(immune_preview.effect_text == "2 Neutrophile" and immune_preview.before_after_text.contains("0,76") and immune_preview.before_after_text.contains("116"), "Immunlektion zeigt Anzahl, Intervall und Radius")
	game._on_upgrade_chosen(game.current_upgrade_options[0])

	var immune_enemy: InfectionEnemy = game.intro_primary_enemy
	immune_enemy._physics_process(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	immune_enemy.take_damage(10.0, &"immune")
	immune_enemy.take_damage(10.0, &"immune")
	immune_enemy._physics_process(InfectionEnemy.DEATH_SECONDS)
	_check(game.flow_state == GameFlowState.State.LEVEL_UP and game.current_upgrade_options[0].id == &"oxygenation", "Immunbeseitigung startet nur die Supportlektion")
	var support_preview: UpgradePreview = game.stats.preview_upgrade(game.current_upgrade_options[0])
	_check(support_preview.effect_text.contains("+4") and support_preview.before_after_text.contains("5,65"), "Supportkarte zeigt exakte Regeneration")
	game._on_upgrade_chosen(game.current_upgrade_options[0])
	game._support_step(5.65)
	_check(game.state.boss_spawned and game.active_boss != null, "Mini-Boss erscheint erst nach allen drei Lektionen")
	game.active_boss._physics_process(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	_check(game.flow_state == GameFlowState.State.DISCOVERY_PAUSE and game.discovery_manager.active["id"] == &"infection_focus", "Intro-Boss erhält seine angepasste Entdeckung")
	game._on_discovery_dismissed()
	game.discovery_manager.mark_seen(&"research_reward")
	game.active_boss.take_damage(9999.0, &"therapy")
	game.active_boss._physics_process(InfectionEnemy.DEATH_SECONDS)
	_check(game.flow_state == GameFlowState.State.RESULT, "Mini-Boss beendet das ereignisgesteuerte Intro regulär")

	game.queue_free()
	await process_frame
	if failures == 0:
		print("ALVEOLUS_INTRO_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_INTRO_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)
