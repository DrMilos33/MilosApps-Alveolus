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
	# The live tutorial regression must not depend on or mutate the player's
	# local discovery history.
	game.persistence_enabled = false
	game.meta.reset_defaults()
	game.discovery_manager.configure(game.discovery_definitions, {})
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
	game.run_session.step_fixed(1.0 / 240.0)
	_check(game.intro_phase == &"enemy_approach", "Bewegung startet vor dem ersten Gegner eine eigene Annäherungsphase")
	_check(is_equal_approx(game.intro_transition_timer, 0.85), "Die Annäherungsphase dauert verbindlich 0,85 Sekunden")
	_check(game.intro_primary_enemy == null, "Während der Annäherungsphase existiert noch kein versteckter Gegner")
	game.run_session.step_fixed(0.84)
	_check(game.intro_phase == &"enemy_approach" and game.intro_primary_enemy == null, "Vor Ablauf der 0,85 Sekunden wird der erste Gegner nicht vorzeitig erzeugt")
	game.run_session.step_fixed(0.02)
	_check(game.intro_phase == &"await_enemy" and is_instance_valid(game.intro_primary_enemy), "Nach der Annäherungsphase erscheint genau der geführte erste Gegner")
	_check(is_equal_approx(game.intro_primary_enemy.status_speed_multiplier(), 0.58), "Der erste Gegner verwendet den ruhigeren Bewegungsfaktor 0,58")
	var observed_discoveries: Array[StringName] = []
	var observed_first_projectile_speed := false
	var observed_guided_pickup_speed := false
	var observed_recycled_projectile_default := false
	var observed_recycled_pickup_default := false
	for _frame in range(1200):
		# Drive the new centralized fixed-step path deterministically. Discovery
		# pauses still stop the session; the test dismisses them before advancing.
		if game.flow_state == GameFlowState.State.DISCOVERY_PAUSE and not game.discovery_manager.active.is_empty():
			observed_discoveries.append(game.discovery_manager.active["id"])
			game._on_discovery_dismissed()
		if game.flow_state == GameFlowState.State.RUNNING:
			game.run_session.step_fixed(1.0 / 240.0)
		for projectile in game.projectiles:
			if is_instance_valid(projectile) and is_equal_approx((projectile as TherapyProjectile).speed, 360.0):
				observed_first_projectile_speed = true
		for pickup in game.pickups:
			if is_instance_valid(pickup) and (pickup as AnalysisPickup).guided_to_target and is_equal_approx((pickup as AnalysisPickup).guided_speed, 280.0):
				observed_guided_pickup_speed = true
		for projectile in game.projectile_pool:
			if is_instance_valid(projectile) and is_equal_approx((projectile as TherapyProjectile).speed, TherapyProjectile.DEFAULT_SPEED):
				observed_recycled_projectile_default = true
		for pickup in game.pickup_pool:
			if is_instance_valid(pickup) and not (pickup as AnalysisPickup).guided_to_target and is_equal_approx((pickup as AnalysisPickup).guided_speed, AnalysisPickup.DEFAULT_GUIDED_SPEED):
				observed_recycled_pickup_default = true
		await process_frame
		if game.flow_state == GameFlowState.State.LEVEL_UP:
			break
	# Collection is applied at the end of the fixed step. In headless runs the
	# pooled node can therefore become observable on the same process frame on
	# which the level-up state stops the loop.
	for pickup in game.pickup_pool:
		if is_instance_valid(pickup) and not (pickup as AnalysisPickup).guided_to_target and is_equal_approx((pickup as AnalysisPickup).guided_speed, AnalysisPickup.DEFAULT_GUIDED_SPEED):
			observed_recycled_pickup_default = true
	_check(observed_discoveries.has(&"pneumococcus"), "Der reale Introablauf erklärt die erste Pneumokokke")
	_check(observed_discoveries.has(&"automatic_therapy"), "Der reale Introablauf erklärt den ersten Therapieimpuls")
	_check(observed_discoveries.has(&"analysis_pickup"), "Der reale Introablauf erklärt die erste Analyse")
	_check(observed_first_projectile_speed, "Das erste Intro-Therapieprojektil fliegt lesbar mit Geschwindigkeit 360")
	_check(observed_guided_pickup_speed, "Die erste geführte Analyseprobe bewegt sich lesbar mit Geschwindigkeit 280")
	_check(observed_recycled_projectile_default, "Ein recyceltes Therapieprojektil setzt seine Geschwindigkeit auf 720 zurück")
	_check(observed_recycled_pickup_default, "Eine recycelte Analyseprobe setzt Führung und Geschwindigkeit auf den Standard 680 zurück")
	_check(game.flow_state == GameFlowState.State.LEVEL_UP, "Die echte Analyseaufnahme startet die erste Ein-Karten-Lektion")
	if game.flow_state != GameFlowState.State.LEVEL_UP or game.current_upgrade_options.is_empty():
		var debug_enemy: InfectionEnemy = game.enemies[0] if not game.enemies.is_empty() else null
		printerr("INTRO_DEBUG phase=%s flow=%s session=%s enemies=%d handles=%d allocated=%d regular=%d world_handle=%s targetable=%s spawn=%.3f distance=%.1f timer=%.3f targets=%d projectiles=%d pickups=%d discoveries=%s" % [
			game.intro_phase,
			game.flow_state,
			game.run_session.lifecycle,
			game.enemies.size(),
			game.enemy_world.handles().size(),
			game.enemy_world.allocated_count(),
			game.enemy_world.regular_count,
			game.enemy_world.handle_for(debug_enemy) if debug_enemy != null else EntityHandle.INVALID,
			debug_enemy.is_targetable() if debug_enemy != null else false,
			debug_enemy.spawn_timer if debug_enemy != null else -1.0,
			game.topology.distance(game.avatar.global_position, debug_enemy.global_position) if debug_enemy != null else -1.0,
			game.therapy_timer,
			game._nearest_targets(game.stats.therapy_range, game.stats.therapy_targets).size(),
			game.projectiles.size(),
			game.pickups.size(),
			observed_discoveries,
		])
		game.queue_free()
		await process_frame
		quit(1)
		return
	_check(game.current_upgrade_options.size() == 1 and game.current_upgrade_options[0].id == &"potency", "Lektion 1 zeigt nur Gezielte Wirksamkeit")
	_check(not game.hud.upgrade_target_preview.visible and game.hud.upgrade_target_preview.target_type == &"", "Die Intro-Verbesserung zeichnet keine Welt- oder Zielvorschau")
	_check(_scripted_upgrade_card_is_qualitative(game.hud, "Deine Behandlung verursacht jetzt mehr Schaden."), "Die Wirkungslektion erklärt den Nutzen qualitativ und ohne Vorher/Nachher-Grundwerte")
	game._on_upgrade_chosen(game.current_upgrade_options[0])

	var potency_enemy: InfectionEnemy = game.intro_primary_enemy
	potency_enemy._physics_process(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	potency_enemy.take_damage(26.0, &"therapy")
	_check(game.flow_state == GameFlowState.State.LEVEL_UP and game.current_upgrade_options[0].id == &"neutrophils", "Treffer mit neuem Wert startet nur die Immunlektion")
	_check(not game.hud.upgrade_target_preview.visible and game.hud.upgrade_target_preview.target_type == &"", "Auch die Abwehrlektion bleibt frei von einer Weltvorschau")
	_check(_scripted_upgrade_card_is_qualitative(game.hud, "Abwehrzellen schützen den Nahbereich automatisch."), "Die Abwehrlektion verwendet kurze qualitative Erklärung statt Grundwertvergleich")
	game._on_upgrade_chosen(game.current_upgrade_options[0])

	var immune_enemy: InfectionEnemy = game.intro_primary_enemy
	immune_enemy._physics_process(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	immune_enemy.take_damage(10.0, &"immune")
	immune_enemy.take_damage(10.0, &"immune")
	_check(game.flow_state == GameFlowState.State.LEVEL_UP and game.current_upgrade_options[0].id == &"oxygenation", "Immunbeseitigung startet nur die Supportlektion")
	_check(not game.hud.upgrade_target_preview.visible and game.hud.upgrade_target_preview.target_type == &"", "Auch die Atemhilfelektion bleibt frei von einer Weltvorschau")
	_check(_scripted_upgrade_card_is_qualitative(game.hud, "Atemhilfe stellt regelmäßig Zustand wieder her."), "Die Atemhilfelektion verwendet kurze qualitative Erklärung statt Grundwertvergleich")
	game._on_upgrade_chosen(game.current_upgrade_options[0])
	game._support_step(5.65)
	_check(game.state.boss_spawned and game.active_boss != null, "Mini-Boss erscheint erst nach allen drei Lektionen")
	game.active_boss._physics_process(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	_check(game.flow_state == GameFlowState.State.DISCOVERY_PAUSE and game.discovery_manager.active["id"] == &"infection_focus", "Intro-Boss erhält seine angepasste Entdeckung")
	game._on_discovery_dismissed()
	game.discovery_manager.mark_seen(&"research_reward")
	game.active_boss.take_damage(9999.0, &"therapy")
	_check(game.flow_state == GameFlowState.State.RESULT, "Mini-Boss beendet das ereignisgesteuerte Intro regulär")

	game.queue_free()
	await process_frame
	if failures == 0:
		print("ALVEOLUS_INTRO_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_INTRO_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)

func _scripted_upgrade_card_is_qualitative(hud: GameHUD, expected_copy: String) -> bool:
	if hud == null or hud.upgrade_cards == null:
		return false
	var live_cards: Array[Control] = []
	for child in hud.upgrade_cards.get_children():
		if child is Control and not child.is_queued_for_deletion():
			live_cards.append(child)
	if live_cards.size() != 1:
		return false
	var card := live_cards[0]
	var text := _control_text(card)
	# The numeric comparison row is intentionally absent for scripted lessons;
	# exactly two copy controls leave room only for title and qualitative effect.
	return text.contains(expected_copy) and _control_copy_count(card) == 2

func _control_text(node: Node) -> String:
	var result := ""
	if node is Label:
		result += (node as Label).text + "\n"
	elif node is RichTextLabel:
		result += (node as RichTextLabel).get_parsed_text() + "\n"
	for child in node.get_children():
		result += _control_text(child)
	return result

func _control_copy_count(node: Node) -> int:
	var result := 1 if node is Label or node is RichTextLabel else 0
	for child in node.get_children():
		result += _control_copy_count(child)
	return result

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)
