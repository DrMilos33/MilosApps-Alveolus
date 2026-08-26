extends SceneTree

const GameScript := preload("res://scripts/game.gd")

var assertions := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_anchor_case_boss_contract()
	_test_fall_one_add_spawn_metadata()
	await _test_intro_boss_normal_attack()
	await _test_case_one_normal_and_case_two_turn_variation()
	await _test_case_two_boss_attack_and_add_lock()
	await _test_case_two_runtime_projectile_contract()
	await _test_case_three_runtime_projectile_contract()
	await _test_configurable_boss_contract()
	await _test_generation_safe_attack_director()
	await _test_hostile_projectile_geometry()
	if failures == 0:
		print("ALVEOLUS_ENEMY_RANGED_ATTACK_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_ENEMY_RANGED_ATTACK_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)


func _test_fall_one_add_spawn_metadata() -> void:
	var levels := ContentCatalog.level_definitions()
	var case_one := levels[1] as LevelDefinition
	var topology := ArenaTopology.new(Rect2(-600.0, -400.0, 1200.0, 800.0))
	var avatar := TherapyAvatar.new()
	var add := InfectionEnemy.new()
	get_root().add_child(avatar)
	get_root().add_child(add)
	add.configure(ContentCatalog.enemy_definitions()[&"pneumococcus"], avatar, topology)
	var request := EnemySpawnRequest.create(&"pneumococcus", Vector2.ZERO)
	request.metadata["ranged_shooter"] = true
	request.metadata["projectile_attack_speed_multiplier"] = case_one.boss_add_projectile_attack_speed_multiplier
	request.metadata["defense_burst_shooting_lock_seconds"] = case_one.boss_add_defense_burst_shooting_lock_seconds
	var game := GameScript.new()
	game._apply_enemy_spawn_metadata(add, request)
	add.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	_true(add.runtime_projectile_shooter, "Die echte Spawnmetadatenbrücke markiert Fall-1-Verstärkungen als Schützen")
	_near(add.projectile_attack_speed_multiplier, 2.0, "Die echte Spawnmetadatenbrücke übernimmt ihre doppelte Schussrate")
	_near(add.defense_burst_shooting_lock_seconds, 10.0, "Fall-1-Verstärkungen übernehmen den allgemeinen Zehn-Sekunden-Vertrag")
	add.apply_defense_burst_shooting_lock()
	_true(add.projectiles_suppressed(), "Ein per Fall-1-Boss beschworenes kleines Bakterium pausiert nach Stoß seine Projektile")
	add.step_fixed(9.99)
	_true(add.projectiles_suppressed(), "Die Fall-1-Verstärkung bleibt bis zur Zehn-Sekunden-Grenze gesperrt")
	add.step_fixed(0.02)
	_true(not add.projectiles_suppressed(), "Die Fall-1-Verstärkung darf nach zehn Sekunden wieder feuern")
	game.free()
	add.free()
	avatar.free()


func _test_anchor_case_boss_contract() -> void:
	var levels := ContentCatalog.level_definitions()
	var anchor_case := levels[4] as LevelDefinition
	_equal(anchor_case.id, &"spreading_infection", "Der erhaltene Rautenboss bleibt über seine stabile Fall-ID adressierbar")
	_near(anchor_case.boss_speed_multiplier, 1.35, "Der Fall-4-Boss besitzt den datengetriebenen Geschwindigkeitsfaktor")
	_equal(anchor_case.boss_phase_minions, PackedInt32Array([4, 4]), "Der Fall-4-Boss ruft in beiden Phasen vier Adds")
	var config := RunConfig.from_level(anchor_case)
	_near(config.boss_speed_multiplier, 1.35, "RunConfig bewahrt den Bossfaktor")
	var enemies := ContentCatalog.enemy_definitions()
	var boss := enemies[&"infection_focus"] as EnemyDefinition
	var nest := enemies[&"minor_focus"] as EnemyDefinition
	var intro_boss := enemies[&"intro_focus"] as EnemyDefinition
	var localized_boss := enemies[&"localized_boss"] as EnemyDefinition
	_near(boss.projectile_damage, 4.0, "Der Boss besitzt Projektilschaden")
	_near(boss.projectile_interval, 1.6, "Der Boss feuert fortlaufend")
	_equal(boss.projectile_pattern, &"diamond", "Der Boss verwendet das Rautenmuster")
	_near(nest.projectile_damage, 2.0, "Der kleine Herd besitzt Projektilschaden")
	_equal(nest.projectile_pattern, &"normal", "Der kleine Herd verwendet normale Projektile")
	_near(intro_boss.projectile_damage, 6.0, "Der Intro-Boss besitzt dreifachen Projektil-Basiswert")
	_near(intro_boss.projectile_interval, 2.6, "Der Intro-Boss feuert im ruhigen Normaltakt")
	_equal(intro_boss.projectile_pattern, &"normal", "Der Intro-Boss verwendet ausdrücklich das normale Projektil")
	_near(localized_boss.projectile_damage, 4.0, "Der Fall-2-Bakterienkern besitzt Projektilschaden")
	_near(localized_boss.projectile_interval, 1.6, "Der Fall-2-Bakterienkern verwendet die etablierte Bossbasisrate")
	_equal(localized_boss.projectile_pattern, &"double_turn", "Der Fall-2-Bakterienkern verwendet die doppelte 90-Grad-Bahn")
	var case_two := levels[2] as LevelDefinition
	_true(case_two.boss_ranged_enabled, "Fall 2 aktiviert den neuen Projektilboss")
	_near(case_two.boss_projectile_attack_speed_multiplier, 1.53, "Fall 2 reduziert die bisherige Bossrate relativ um 15 Prozent")
	_near(case_two.boss_projectile_speed_multiplier, 1.5, "Fall 2 erhöht das Bossprojektiltempo um 50 Prozent")
	_near(case_two.boss_projectile_damage_multiplier, 1.5, "Fall 2 erhöht den Bossprojektilschaden um 50 Prozent")
	_equal(case_two.boss_phase_health_thresholds, PackedFloat32Array([0.80]), "Fall 2 beginnt seine Addphase bei 80 Prozent Leben")
	_near(case_two.boss_reinforcement_interval, 15.0, "Fall 2 ruft alle 15 Sekunden Adds")
	_equal(case_two.boss_reinforcement_minimum_phase, 1, "Der 15-Sekunden-Timer startet erst mit der 80-Prozent-Phase")
	var case_one := levels[1] as LevelDefinition
	_true(case_one.boss_ranged_enabled and case_one.boss_projectiles_require_empty_aura, "Fall 1 aktiviert den Bossbeschuss ausschließlich bei leerer Aura")
	_equal(case_one.boss_projectile_pattern, &"normal", "Fall 1 überschreibt die gemeinsame Kernbasis mit einem normalen Projektil")
	_near(case_one.boss_projectile_speed_multiplier, 1.3, "Fall-1-Bossprojektile erhalten den relativen 30-Prozent-Temposchritt")
	_near(case_one.boss_projectile_turn_time_variation, 0.0, "Das normale Fall-1-Projektil trägt keine ungenutzte Kurvenvariation")
	_near(case_one.boss_add_projectile_attack_speed_multiplier, 2.0, "Fall-1-Bossverstärkungen verwenden die doppelte Schussrate")
	_near(case_one.boss_add_defense_burst_shooting_lock_seconds, 10.0, "Auch die schießenden Fall-1-Bossverstärkungen pausieren nach Stoß zehn Sekunden")
	var case_three := levels[3] as LevelDefinition
	_equal(case_two.boss_projectile_pattern, &"double_turn", "Fall 2 behält die doppelte 90-Grad-Bahn")
	_near(case_two.boss_projectile_turn_time_variation, 0.10, "Die Kurvenvariation gehört zum Fall-2-Projektil")
	_near(case_three.boss_projectile_speed_multiplier, 1.26, "Fall-3-Rautenprojektile tragen den um 30 Prozent reduzierten Tempofaktor")
	_near(case_three.boss_wave_amplitude, 136.0, "Fall-3-Rautenprojektile tragen die 60 Prozent breitere Bahn")
	_near(case_three.boss_wave_length, 550.0, "Fall-3-Rautenprojektile treffen sich erst nach 275 Weltpunkten")


func _test_case_one_normal_and_case_two_turn_variation() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var case_one_game = packed.instantiate()
	get_root().add_child(case_one_game)
	await process_frame
	await process_frame
	case_one_game.persistence_enabled = false
	for discovery_id in case_one_game.discovery_definitions:
		case_one_game.discovery_manager.mark_seen(StringName(discovery_id))
	case_one_game.selected_level = case_one_game.levels[1]
	case_one_game.start_run()
	case_one_game.set_physics_process(false)
	case_one_game._spawn_boss()
	var boss := case_one_game.active_boss as InfectionEnemy
	_true(is_instance_valid(boss), "Fall 1 materialisiert seinen normal schießenden Bakterienkern")
	if is_instance_valid(boss):
		boss.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
		var handle: int = case_one_game.enemy_world.handle_for(boss)
		_true(case_one_game.enemy_attack_director.set_projectile_enabled(handle, true), "Eine leere Aura aktiviert den Fall-1-Bossbeschuss")
		var count_before: int = case_one_game.projectiles.size()
		case_one_game.enemy_attack_director.step_fixed(0.65)
		_true(case_one_game.projectiles.size() == count_before + 1, "Fall 1 feuert pro Takt genau ein normales Projektil")
		if case_one_game.projectiles.size() > count_before:
			var projectile := case_one_game.projectiles[-1] as TherapyProjectile
			_equal(projectile.hostile_pattern, TherapyProjectile.HOSTILE_NORMAL, "Fall 1 besitzt weder Rauten- noch 90-Grad-Bahn")
			_near(projectile.speed, 325.0, "Der Mustertausch verändert das bestehende Fall-1-Projektiltempo nicht")
			_near(projectile.hostile_first_turn_seconds, 0.0, "Das normale Fall-1-Projektil hat keinen Richtungswechsel")
	case_one_game.queue_free()
	await process_frame

	var case_two_game = packed.instantiate()
	get_root().add_child(case_two_game)
	await process_frame
	await process_frame
	case_two_game.persistence_enabled = false
	for discovery_id in case_two_game.discovery_definitions:
		case_two_game.discovery_manager.mark_seen(StringName(discovery_id))
	case_two_game.selected_level = case_two_game.levels[2]
	case_two_game.start_run()
	case_two_game.set_physics_process(false)
	case_two_game._spawn_boss()
	boss = case_two_game.active_boss as InfectionEnemy
	var first_turns: Array[float] = []
	_true(is_instance_valid(boss), "Fall 2 materialisiert den variierenden 90-Grad-Boss")
	if is_instance_valid(boss):
		boss.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
		var handle: int = case_two_game.enemy_world.handle_for(boss)
		for shot_index in range(4):
			var count_before: int = case_two_game.projectiles.size()
			case_two_game._on_enemy_projectile_requested(handle, EnemyAttackDirector.Pattern.DOUBLE_TURN, float(shot_index & 1) * 0.5, EnemyAttackDirector.Role.BOSS)
			_true(case_two_game.projectiles.size() == count_before + 1, "Fall-2-Variationsschuss %d wird erzeugt" % shot_index)
			if case_two_game.projectiles.size() <= count_before:
				continue
			var projectile := case_two_game.projectiles[-1] as TherapyProjectile
			var visible_width: float = case_two_game._visible_world_rect().size.x
			var base_first: float = visible_width * 0.40 / 375.0
			var base_second: float = visible_width * 0.25 / 375.0
			_true(projectile.hostile_first_turn_seconds >= base_first * 0.9 and projectile.hostile_first_turn_seconds <= base_first * 1.1, "Erster Fall-2-Knick bleibt im ±10-Prozent-Korridor")
			_true(projectile.hostile_second_leg_seconds >= base_second * 0.9 and projectile.hostile_second_leg_seconds <= base_second * 1.1, "Zweiter Fall-2-Knick bleibt im ±10-Prozent-Korridor")
			first_turns.append(projectile.hostile_first_turn_seconds)
	_true(first_turns.size() >= 2 and not is_equal_approx(first_turns[0], first_turns[1]), "Aufeinanderfolgende Fall-2-Projektile verwenden tatsächlich unterschiedliche Knickzeiten")
	case_two_game.queue_free()
	await process_frame


func _test_case_two_boss_attack_and_add_lock() -> void:
	var topology := ArenaTopology.new(Rect2(-600.0, -400.0, 1200.0, 800.0))
	var avatar := TherapyAvatar.new()
	avatar.global_position = Vector2(300.0, 0.0)
	get_root().add_child(avatar)
	var world := EnemyWorld.new().configure_enemy_world()
	var boss := InfectionEnemy.new()
	get_root().add_child(boss)
	boss.configure(ContentCatalog.enemy_definitions()[&"localized_boss"], avatar, topology)
	boss.configure_projectile_modifiers(1.8, 1.0)
	boss.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	var handle := world.register_enemy(boss, true)
	var director := EnemyAttackDirector.new().configure(CombatCapacity.defaults().max_enemies, world.resolve)
	var shots: Array[Dictionary] = []
	var reinforcements: Array[int] = []
	director.projectile_requested.connect(func(_source: int, pattern: int, phase: float, _role: int) -> void:
		shots.append({"pattern": pattern, "phase": phase})
	)
	director.reinforcements_requested.connect(func(_source: int, count: int) -> void:
		reinforcements.append(count)
	)
	_true(director.register_enemy(handle, EnemyAttackDirector.Role.BOSS), "Fall-2-Boss wird als Schütze registriert")
	_true(director.configure_boss_contract(handle, true, 15.0, 4, 1, EnemyAttackDirector.Pattern.DOUBLE_TURN), "Fall-2-Boss übernimmt Muster und den ab Phase 1 aktiven 15-Sekunden-Addvertrag")
	boss.apply_defense_burst_shooting_lock()
	_true(not boss.projectiles_suppressed(), "Bosse ignorieren die allgemeine Stoß-Schusssperre")
	director.step_fixed(0.65)
	_equal(shots.size(), 1, "Der Fall-2-Boss feuert pro Takt ein Doppelkurvenprojektil")
	_equal(int(shots[0]["pattern"]), EnemyAttackDirector.Pattern.DOUBLE_TURN, "Der echte Director emittiert das Doppelkurvenmuster")
	_near(boss.resolved_projectile_interval(), 1.6 / 1.8, "80 Prozent Rate ergeben rund 0,89 Sekunden Intervall")
	director.step_fixed(1.6 / 1.8)
	_equal(shots.size(), 2, "Nach rund 0,89 Sekunden feuert der Fall-2-Boss erneut")
	_true(float(shots[0]["phase"]) != float(shots[1]["phase"]), "Aufeinanderfolgende Projektile teilen sich deterministisch 50/50 auf beide Kurvenseiten")
	director.step_fixed(20.0)
	_equal(reinforcements, [], "Oberhalb der 80-Prozent-Phase startet der periodische Addtimer nicht")
	_true(director.set_boss_phase(handle, 1), "Die 80-Prozent-Phase aktiviert den periodischen Addvertrag")
	director.step_fixed(14.99)
	_equal(reinforcements, [], "Nach Aktivierung bleibt der Fall-2-Boss bis 15 Sekunden ohne periodische Adds")
	director.step_fixed(0.02)
	_equal(reinforcements, [4], "15 Sekunden nach der 80-Prozent-Phase fordert der Boss vier Adds an")
	director.release(handle)
	world.release(handle, false)
	world.flush_deferred()
	boss.queue_free()
	shots.clear()

	var add := InfectionEnemy.new()
	get_root().add_child(add)
	add.configure(ContentCatalog.enemy_definitions()[&"pneumococcus"], avatar, topology)
	add.configure_projectile_modifiers(2.0, 1.0, 1.0, EnemyDefinition.DEFAULT_NON_BOSS_SHOOTING_LOCK_SECONDS, true)
	add.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	var add_handle := world.register_enemy(add, true)
	_true(director.register_enemy(add_handle, EnemyAttackDirector.Role.PHASE_ADD), "Fall-2-Add wird als Schütze registriert")
	director.step_fixed(1.11)
	_equal(shots.size(), 1, "Ein doppelt schneller Boss-Add feuert nach der unveränderten Startverzögerung")
	director.step_fixed(1.38)
	_equal(shots.size(), 1, "Die doppelte Add-Rate bleibt knapp vor 1,4 Sekunden stabil")
	director.step_fixed(0.02)
	_equal(shots.size(), 2, "Die doppelte Add-Rate feuert nach rund 1,4 Sekunden erneut")
	shots.clear()
	add.apply_defense_burst_shooting_lock()
	_true(add.projectiles_suppressed(), "Stoß sperrt den Fall-2-Boss-Add sofort")
	add.step_fixed(9.99)
	director.step_fixed(9.99)
	_true(add.projectiles_suppressed(), "Der Fall-2-Boss-Add bleibt bis zur Zehn-Sekunden-Grenze gesperrt")
	_equal(shots.size(), 0, "Während der Zehn-Sekunden-Sperre feuert der Fall-2-Boss-Add nicht")
	add.step_fixed(0.02)
	_true(not add.projectiles_suppressed(), "Die Schusssperre des Fall-2-Boss-Adds läuft nach zehn Sekunden ab")
	director.step_fixed(EnemyAttackDirector.PHASE_ADD_INTERVAL / add.projectile_attack_speed_multiplier + 0.01)
	_equal(shots.size(), 1, "Der Fall-2-Boss-Add feuert nach Ablauf der Sperre wieder")
	director.release(add_handle)
	world.release(add_handle, false)
	world.flush_deferred()
	add.configure_damage_presentation(20.0, 1, true)
	add.recycle()
	_true(not add.projectiles_suppressed(), "Pool-Recycling übernimmt keine abgelaufene Schusssperre")
	_true(not add.treatment_line_coverage_scaled and is_equal_approx(add.treatment_line_damage_multiplier, 1.0) and add.symbolic_health_bar_count == 0, "Pool-Recycling entfernt auch den Fall-2-Flächenproxy und seinen Balken")
	add.configure(ContentCatalog.enemy_definitions()[&"pneumococcus"], avatar, topology)
	add.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	add.apply_defense_burst_shooting_lock()
	_true(not add.projectiles_suppressed(), "Ein gewöhnliches Nahkampfbakterium erhält ohne Schützenrolle keine irreführende Schusssperre")
	world.clear()
	add.queue_free()
	avatar.queue_free()
	await process_frame


func _test_case_two_runtime_projectile_contract() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.persistence_enabled = false
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(StringName(discovery_id))
	game.selected_level = game.levels[2]
	game.start_run()
	game.set_physics_process(false)
	game._spawn_boss()
	var boss := game.active_boss as InfectionEnemy
	_true(is_instance_valid(boss), "Fall 2 materialisiert seinen Bakterienkern über die echte Runtimebrücke")
	_equal(String(game.hud.run_hud_vitals.get("boss_phase", "")), "Phase 80 %", "Das Boss-HUD zeigt die echte Fall-2-Beschwörungsschwelle")
	if is_instance_valid(boss):
		boss.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
		_equal(boss.phase_health_thresholds, PackedFloat32Array([0.80]), "Die echte Bossaktivierung übernimmt die 80-Prozent-Addschwelle")
		var phase_changes: Array[int] = []
		boss.boss_phase_changed.connect(func(phase: int) -> void: phase_changes.append(phase))
		boss.take_damage(boss.max_health * 0.19, &"test_threshold")
		_equal(phase_changes, [], "Oberhalb 80 Prozent beschwört der Fall-2-Boss noch keine Monster")
		boss.take_damage(boss.max_health * 0.02, &"test_threshold")
		_equal(phase_changes, [1], "Beim Unterschreiten von 80 Prozent beginnt die Fall-2-Beschwörung")
		var handle: int = game.enemy_world.handle_for(boss)
		var count_before: int = game.projectiles.size()
		game._on_enemy_projectile_requested(
			handle,
			EnemyAttackDirector.Pattern.DOUBLE_TURN,
			0.0,
			EnemyAttackDirector.Role.BOSS
		)
		_equal(game.projectiles.size(), count_before + 1, "Der echte Fall-2-Schuss erzeugt genau ein Doppelkurvenprojektil")
		if game.projectiles.size() > count_before:
			var projectile := game.projectiles[-1] as TherapyProjectile
			_near(projectile.speed, 375.0, "Die Runtime löst das Fall-2-Bossprojektil auf 375 Tempo auf")
			_near(projectile.damage, 8.0, "Der authored 50-Prozent-Schadensbonus wird nach der globalen Ganzzahlregel zu acht Schaden")
			var visible_width: float = game._visible_world_rect().size.x
			var expected_first := visible_width * 0.40 / 375.0
			var expected_second := visible_width * 0.25 / 375.0
			_true(projectile.hostile_first_turn_seconds >= expected_first * 0.9 and projectile.hostile_first_turn_seconds <= expected_first * 1.1, "Der erste Knick friert 40 Prozent Bildschirmbreite mit ±10 Prozent Variation als Zeit ein")
			_true(projectile.hostile_second_leg_seconds >= expected_second * 0.9 and projectile.hostile_second_leg_seconds <= expected_second * 1.1, "Der zweite Knick friert weitere 25 Prozent Bildschirmbreite mit ±10 Prozent Variation als Zeit ein")
			_true(projectile.hostile_time_bounded_double_turn, "Nur der Fall-2-Vertrag darf seine beiden Zeitkurven unabhängig von der Distanzgrenze vollenden")
			_near(projectile.lifetime, maxf(1050.0 / 375.0 + 0.35, projectile.hostile_first_turn_seconds + projectile.hostile_second_leg_seconds + 1.50), "Das Fall-2-Projektil lebt nach dem zweiten Knick weitere 1,5 Sekunden")
			var actual_first := projectile.hostile_first_turn_seconds
			projectile.speed *= 0.5
			projectile.step_fixed(actual_first - 0.001)
			_equal(projectile.hostile_turn_count, 0, "Eine spätere Verlangsamung löst den Knick nicht vor seinem festen Zeitpunkt aus")
			projectile.step_fixed(0.002)
			_equal(projectile.hostile_turn_count, 1, "Eine spätere Verlangsamung verschiebt den festen Knickzeitpunkt nicht")
	game.queue_free()
	await process_frame


func _test_case_three_runtime_projectile_contract() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.persistence_enabled = false
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(StringName(discovery_id))
	game.selected_level = game.levels[3]
	game.start_run()
	game.set_physics_process(false)
	game._spawn_boss()
	var boss := game.active_boss as InfectionEnemy
	_true(is_instance_valid(boss), "Fall 3 materialisiert seinen Rautenboss über die echte Runtimebrücke")
	if is_instance_valid(boss):
		boss.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
		var count_before: int = game.projectiles.size()
		game.enemy_attack_director.step_fixed(0.65)
		_equal(game.projectiles.size(), count_before + 2, "Fall 3 feuert weiterhin exakt zwei gespiegelte Rautenprojektile")
		if game.projectiles.size() >= count_before + 2:
			var first := game.projectiles[count_before] as TherapyProjectile
			var second := game.projectiles[count_before + 1] as TherapyProjectile
			for projectile in [first, second]:
				_near(projectile.speed, 267.75, "Fall-3-Projektiltempo ist relativ um 30 Prozent reduziert")
				_near(projectile.hostile_wave_amplitude, 136.0, "Die 60 Prozent breitere Fall-3-Auslenkung bleibt erhalten")
				_near(projectile.hostile_wave_length, 550.0, "Die Fall-3-Rautenlänge steigt auf 550")
			var meet_seconds := 275.0 / first.speed
			first.step_fixed(meet_seconds)
			second.step_fixed(meet_seconds)
			_near(first.global_position.distance_to(second.global_position), 0.0, "Die beiden Fall-3-Projektile treffen sich nach 275 Vorwärts-Weltpunkten wieder")
	game.queue_free()
	await process_frame


func _test_intro_boss_normal_attack() -> void:
	var topology := ArenaTopology.new(Rect2(-600.0, -400.0, 1200.0, 800.0))
	var avatar := TherapyAvatar.new()
	avatar.global_position = Vector2(260.0, 0.0)
	get_root().add_child(avatar)
	var world := EnemyWorld.new().configure_enemy_world()
	var intro_boss := InfectionEnemy.new()
	get_root().add_child(intro_boss)
	intro_boss.global_position = Vector2.ZERO
	intro_boss.configure(ContentCatalog.enemy_definitions()[&"intro_focus"], avatar, topology)
	intro_boss.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	var position_before_relocation := intro_boss.global_position
	_true(not intro_boss.can_be_relocated(), "Ein materialisierter Boss bleibt vom Offscreen-Versetzen ausgeschlossen")
	_true(not intro_boss.relocate_preserving_state(Vector2(420.0, 140.0)), "Die Entity-API lehnt Bossversetzung zusätzlich defensiv ab")
	_equal(intro_boss.global_position, position_before_relocation, "Eine abgelehnte Bossversetzung verändert seine Position nicht")
	var handle := world.register_enemy(intro_boss, true)
	var director := EnemyAttackDirector.new().configure(CombatCapacity.defaults().max_enemies, world.resolve)
	var shots: Array[Dictionary] = []
	director.projectile_requested.connect(func(source: int, pattern: int, phase: float, role: int) -> void:
		shots.append({"source": source, "pattern": pattern, "phase": phase, "role": role})
	)
	_true(director.register_enemy(handle, EnemyAttackDirector.Role.BOSS), "Intro-Boss wird generationensicher als Schütze registriert")
	director.step_fixed(0.65)
	_equal(shots.size(), 1, "Der Intro-Boss feuert pro Angriff exakt ein Projektil")
	if shots.size() == 1:
		_equal(int(shots[0]["pattern"]), EnemyAttackDirector.Pattern.NORMAL, "Der Intro-Boss feuert kein Rautenprojektil")
		_near(float(shots[0]["phase"]), 0.0, "Das normale Introprojektil besitzt keine Rautenphase")
	world.clear()
	intro_boss.queue_free()
	avatar.queue_free()
	await process_frame


func _test_generation_safe_attack_director() -> void:
	var topology := ArenaTopology.new(Rect2(-600.0, -400.0, 1200.0, 800.0))
	var avatar := TherapyAvatar.new()
	avatar.global_position = Vector2(260.0, 0.0)
	get_root().add_child(avatar)
	var world := EnemyWorld.new().configure_enemy_world()
	var boss := InfectionEnemy.new()
	get_root().add_child(boss)
	boss.global_position = Vector2.ZERO
	boss.configure(
		ContentCatalog.enemy_definitions()[&"infection_focus"],
		avatar,
		topology,
		1.0,
		1.0,
		1.0,
		PackedInt32Array([4, 4])
	)
	boss.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	var handle := world.register_enemy(boss, true)
	_true(EntityHandle.is_valid(handle), "Boss erhält einen generationensicheren World-Handle")
	var director := EnemyAttackDirector.new().configure(CombatCapacity.defaults().max_enemies, world.resolve)
	var shots: Array[Dictionary] = []
	var reinforcements: Array[int] = []
	director.projectile_requested.connect(func(source: int, pattern: int, phase: float, role: int) -> void:
		shots.append({"source": source, "pattern": pattern, "phase": phase, "role": role})
	)
	director.reinforcements_requested.connect(func(source: int, count: int) -> void:
		if source == handle:
			reinforcements.append(count)
	)
	_true(director.register_enemy(handle, EnemyAttackDirector.Role.BOSS), "Boss wird genau einmal als Schütze registriert")
	var boss_position_before_push := boss.global_position
	boss.apply_knockback(Vector2.RIGHT, 1.0, 0.1, 1.0)
	boss.step_fixed(0.05)
	_true(boss.global_position.is_equal_approx(boss_position_before_push), "Stoß betäubt den Boss, verschiebt ihn aber nicht")
	director.step_fixed(0.65)
	_equal(shots.size(), 2, "Ein Boss bleibt trotz Stoß-Stun schussfähig")
	boss.step_fixed(1.01)
	director.step_fixed(0.65)
	_equal(shots.size(), 2, "Der Bossangriffstimer läuft während des Stuns normal weiter")
	if shots.size() == 2:
		_equal(int(shots[0]["pattern"]), EnemyAttackDirector.Pattern.DIAMOND, "Beide Bossprojektile verwenden das Rautenmuster")
		_equal(int(shots[1]["pattern"]), EnemyAttackDirector.Pattern.DIAMOND, "Das zweite Bossprojektil verwendet ebenfalls das Rautenmuster")
		_near(float(shots[0]["phase"]), 0.25, "Das erste Projektil erhält die erste Rautenphase")
		_near(float(shots[1]["phase"]), 0.75, "Das zweite Projektil erhält die gespiegelte Rautenphase")
	_true(director.set_boss_phase(handle, 2), "Zweite Bossphase aktiviert den Verstärkungstimer")
	director.step_fixed(19.9)
	_equal(reinforcements.size(), 0, "Vor 20 Sekunden erscheint keine periodische Verstärkung")
	director.step_fixed(0.11)
	_equal(reinforcements, [4], "Nach 20 Sekunden werden exakt vier Adds angefordert")
	_true(director.release(handle), "Freigabe entfernt den alten Handle synchron")
	_equal(director.active_count(), 0, "Nach Freigabe bleibt kein alter Schützenslot aktiv")
	director.step_fixed(30.0)
	_equal(reinforcements, [4], "Ein freigegebener Handle erzeugt keine verspätete Verstärkung")
	world.release(handle, false)
	world.flush_deferred()
	boss.queue_free()
	avatar.queue_free()
	await process_frame


func _test_configurable_boss_contract() -> void:
	var topology := ArenaTopology.new(Rect2(-600.0, -400.0, 1200.0, 800.0))
	var avatar := TherapyAvatar.new()
	avatar.global_position = Vector2(260.0, 0.0)
	get_root().add_child(avatar)
	var world := EnemyWorld.new().configure_enemy_world()
	var director := EnemyAttackDirector.new().configure(CombatCapacity.defaults().max_enemies, world.resolve)
	var shots: Array[Dictionary] = []
	var reinforcements: Array[int] = []
	director.projectile_requested.connect(func(source: int, pattern: int, _phase: float, _role: int) -> void:
		shots.append({"source": source, "pattern": pattern})
	)
	director.reinforcements_requested.connect(func(_source: int, count: int) -> void:
		reinforcements.append(count)
	)

	var custom_boss := InfectionEnemy.new()
	get_root().add_child(custom_boss)
	custom_boss.global_position = Vector2.ZERO
	custom_boss.configure(ContentCatalog.enemy_definitions()[&"infection_focus"], avatar, topology)
	custom_boss.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	var custom_handle := world.register_enemy(custom_boss, true)
	_true(director.register_enemy(custom_handle, EnemyAttackDirector.Role.BOSS), "Der Fall-1-Boss belegt einen Director-Slot")
	_true(
		director.configure_boss_contract(custom_handle, false, 15.0, 4, 0, EnemyAttackDirector.Pattern.NORMAL),
		"Der Fall-1-Vertrag ist generationensicher konfigurierbar"
	)
	director.step_fixed(14.99)
	_equal(shots.size(), 0, "Ein Boss mit deaktiviertem Projektilvertrag feuert nicht")
	_equal(reinforcements.size(), 0, "Vor 15 Sekunden erscheint keine Fall-1-Verstärkung")
	director.step_fixed(0.02)
	_equal(shots.size(), 0, "Deaktivierte Bossprojektile bleiben auch am Verstärkungstick aus")
	_equal(reinforcements, [4], "Phase 0 fordert nach 15 Sekunden exakt vier Adds an")
	_true(director.set_projectile_enabled(custom_handle, true), "Die leere Aura kann den bestehenden Bosslease zum Schießen freigeben")
	director.step_fixed(0.65)
	_equal(shots.size(), 1, "Die Fall-1-Überschreibung feuert genau ein Projektil statt des zugrunde liegenden Rautenpaars")
	if shots.size() == 1:
		_equal(int(shots[0]["pattern"]), EnemyAttackDirector.Pattern.NORMAL, "Der Fall-1-Bossvertrag überschreibt ausschließlich das Muster mit Normal")
	_true(director.set_projectile_enabled(custom_handle, false), "Ein Monster in der Aura sperrt nur den Bossbeschuss wieder")
	director.step_fixed(10.0)
	_equal(shots.size(), 1, "Die erneute Aurasperre stoppt Schüsse ohne den Directorlease freizugeben")
	_true(director.release(custom_handle), "Der benutzerdefinierte Bossvertrag wird synchron freigegeben")
	_true(
		not director.configure_boss_contract(custom_handle, true, 1.0, 9, 0),
		"Ein freigegebener Boss-Handle kann keinen Slot mehr konfigurieren"
	)
	world.release(custom_handle, false)
	custom_boss.queue_free()

	shots.clear()
	reinforcements.clear()
	var default_boss := InfectionEnemy.new()
	get_root().add_child(default_boss)
	default_boss.global_position = Vector2.ZERO
	default_boss.configure(ContentCatalog.enemy_definitions()[&"infection_focus"], avatar, topology)
	default_boss.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	var default_handle := world.register_enemy(default_boss, true)
	_equal(EntityHandle.slot(default_handle), EntityHandle.slot(custom_handle), "Der Regressionstest verwendet denselben recycelten Director-Slot")
	_true(default_handle != custom_handle, "Der recycelte Slot erhält eine neue Generation")
	_true(director.register_enemy(default_handle, EnemyAttackDirector.Role.BOSS), "Der recycelte Slot übernimmt wieder den Defaultvertrag")
	director.step_fixed(0.65)
	_equal(shots.size(), 2, "Nach Recycling sind Bossprojektile standardmäßig wieder aktiv")
	if shots.size() == 2:
		_equal(int(shots[0]["pattern"]), EnemyAttackDirector.Pattern.DIAMOND, "Slot-Recycling übernimmt keine normale Fall-1-Musterüberschreibung")
		_equal(int(shots[1]["pattern"]), EnemyAttackDirector.Pattern.DIAMOND, "Der geerbte Rautenvertrag emittiert wieder sein zweites Projektil")
	_true(director.set_boss_phase(default_handle, 1), "Phase 1 bleibt unter dem Defaultminimum")
	director.step_fixed(20.1)
	_equal(reinforcements.size(), 0, "Der Defaultvertrag ruft vor Phase 2 keine Adds")
	_true(director.set_boss_phase(default_handle, 2), "Phase 2 aktiviert den recycelten Defaultvertrag")
	director.step_fixed(19.9)
	_equal(reinforcements.size(), 0, "Der recycelte Defaultvertrag bewahrt das 20-Sekunden-Intervall")
	director.step_fixed(0.11)
	_equal(reinforcements, [4], "Der Defaultvertrag bleibt 20 Sekunden, vier Adds, ab Phase 2")
	director.release(default_handle)
	world.release(default_handle, false)
	default_boss.queue_free()
	avatar.queue_free()
	await process_frame


func _test_hostile_projectile_geometry() -> void:
	var topology := ArenaTopology.new(Rect2(-600.0, -400.0, 1200.0, 800.0))
	var avatar := TherapyAvatar.new()
	avatar.global_position = Vector2(100.0, 0.0)
	get_root().add_child(avatar)
	var hits: Array[float] = []
	var normal := TherapyProjectile.new()
	get_root().add_child(normal)
	normal.global_position = Vector2.ZERO
	normal.hostile_hit.connect(func(_projectile: TherapyProjectile, amount: float, _profile: DamageProfile) -> void: hits.append(amount))
	normal.configure_hostile(Vector2.RIGHT, 7.0, topology, avatar, DamageProfile.single(&"test_enemy", &"earth"), TherapyProjectile.HOSTILE_NORMAL, 0.0, 1000.0, 200.0)
	normal.step_fixed(0.1)
	_equal(hits, [7.0], "Ein normales Gegnerprojektil verursacht nur bei echter Avatarüberlappung Schaden")

	avatar.global_position = Vector2(100.0, 37.0)
	var default_width := TherapyProjectile.new()
	var wide := TherapyProjectile.new()
	get_root().add_child(default_width)
	get_root().add_child(wide)
	for projectile in [default_width, wide]:
		projectile.global_position = Vector2.ZERO
		projectile.hostile_hit.connect(func(_projectile: TherapyProjectile, amount: float, _profile: DamageProfile) -> void: hits.append(amount))
	default_width.configure_hostile(Vector2.RIGHT, 8.0, topology, avatar, null, TherapyProjectile.HOSTILE_NORMAL, 0.0, 1000.0, 200.0)
	default_width.step_fixed(0.1)
	_equal(hits, [7.0], "Die normale Projektilbreite trifft 37 Weltpunkte seitlich versetzt noch nicht")
	wide.configure_hostile(Vector2.RIGHT, 9.0, topology, avatar, null, TherapyProjectile.HOSTILE_NORMAL, 0.0, 1000.0, 200.0, 44.0, 180.0, 1.5)
	wide.step_fixed(0.1)
	_equal(hits, [7.0, 9.0], "Ein 50 Prozent breiteres Projektil erweitert die passende Trefferfläche von 33 auf 38")
	wide.recycle()
	_near(wide.hostile_width_multiplier, 1.0, "Pool-Recycling setzt die Projektilbreite auf Standard zurück")

	avatar.global_position = Vector2(500.0, 0.0)
	var upper := TherapyProjectile.new()
	var lower := TherapyProjectile.new()
	get_root().add_child(upper)
	get_root().add_child(lower)
	for projectile in [upper, lower]:
		projectile.global_position = Vector2.ZERO
	upper.configure_hostile(Vector2.RIGHT, 1.0, topology, avatar, null, TherapyProjectile.HOSTILE_DIAMOND, 0.25, 200.0, 600.0)
	lower.configure_hostile(Vector2.RIGHT, 1.0, topology, avatar, null, TherapyProjectile.HOSTILE_DIAMOND, 0.75, 200.0, 600.0)
	upper.step_fixed(0.1)
	lower.step_fixed(0.1)
	_near(upper.global_position.x, lower.global_position.x, "Rautenprojektile besitzen denselben Vorwärtsfortschritt")
	_near(upper.global_position.y, -lower.global_position.y, "Rautenprojektile bewegen sich sichtbar spiegelbildlich")
	_true(absf(upper.global_position.y) > 1.0, "Das Rautenmuster besitzt eine erkennbare seitliche Auslenkung")

	var left_turn := TherapyProjectile.new()
	var right_turn := TherapyProjectile.new()
	get_root().add_child(left_turn)
	get_root().add_child(right_turn)
	for projectile in [left_turn, right_turn]:
		projectile.global_position = Vector2.ZERO
	left_turn.configure_hostile(Vector2.RIGHT, 1.0, topology, avatar, null, TherapyProjectile.HOSTILE_DOUBLE_TURN, 0.0, 100.0, 500.0, 0.0, 180.0, 1.0, 1.0, 0.4)
	right_turn.configure_hostile(Vector2.RIGHT, 1.0, topology, avatar, null, TherapyProjectile.HOSTILE_DOUBLE_TURN, 0.5, 100.0, 500.0, 0.0, 180.0, 1.0, 1.0, 0.4)
	left_turn.step_fixed(1.0)
	right_turn.step_fixed(1.0)
	_near(left_turn.global_position.x, 100.0, "Erste Kurve beginnt nach exakt einer Sekunde")
	_true(left_turn.direction.y < -0.99 and right_turn.direction.y > 0.99, "Erste 90-Grad-Kurve verteilt Projektile auf beide Seiten")
	left_turn.step_fixed(0.4)
	right_turn.step_fixed(0.4)
	_true(left_turn.direction.x < -0.99 and right_turn.direction.x < -0.99, "Die zweite Kurve dreht in derselben Richtung weiter")
	_near(absf(left_turn.global_position.y), 40.0, "Die zweite Kurve folgt nach weiteren 0,4 Sekunden")
	var faster_turn := TherapyProjectile.new()
	get_root().add_child(faster_turn)
	faster_turn.global_position = Vector2.ZERO
	faster_turn.configure_hostile(Vector2.RIGHT, 1.0, topology, avatar, null, TherapyProjectile.HOSTILE_DOUBLE_TURN, 0.0, 200.0, 500.0, 0.0, 180.0, 1.0, 1.0, 0.4)
	faster_turn.step_fixed(1.0)
	_true(faster_turn.direction.y < -0.99, "Eine spätere Geschwindigkeitsänderung verschiebt den ersten Kurvenzeitpunkt nicht")
	_near(faster_turn.global_position.x, 200.0, "Höheres Tempo verändert nur die bis zum festen Zeitpunkt zurückgelegte Strecke")
	var overshoot_turn := TherapyProjectile.new()
	get_root().add_child(overshoot_turn)
	overshoot_turn.global_position = Vector2.ZERO
	overshoot_turn.configure_hostile(Vector2.RIGHT, 1.0, topology, avatar, null, TherapyProjectile.HOSTILE_DOUBLE_TURN, 0.0, 100.0, 500.0, 0.0, 180.0, 1.0, 1.0, 0.4, true)
	overshoot_turn.step_fixed(1.5)
	_equal(overshoot_turn.hostile_turn_count, 2, "Ein großer Fixed-Step darf beide Zeitkurven exakt konsumieren")
	_true(overshoot_turn.global_position.is_equal_approx(Vector2(90.0, -40.0)), "Der Restweg wird nach beiden Kurven auf den jeweils neuen Segmenten fortgesetzt")
	var tail_turn := TherapyProjectile.new()
	var tail_finishes: Array[int] = []
	get_root().add_child(tail_turn)
	tail_turn.finished.connect(func(_projectile: TherapyProjectile) -> void: tail_finishes.append(1))
	tail_turn.global_position = Vector2.ZERO
	tail_turn.configure_hostile(Vector2.RIGHT, 1.0, topology, avatar, null, TherapyProjectile.HOSTILE_DOUBLE_TURN, 0.0, 100.0, 1.0, 0.0, 180.0, 1.0, 1.0, 0.4, true)
	tail_turn.step_fixed(2.89)
	_equal(tail_finishes.size(), 0, "Das zeitgebundene Boss-2-Projektil bleibt bis knapp vor 1,5 Sekunden Nachflug aktiv")
	tail_turn.step_fixed(0.02)
	_equal(tail_finishes.size(), 1, "Das zeitgebundene Boss-2-Projektil endet nach 1,5 Sekunden Nachflug")
	var bounded_turn := TherapyProjectile.new()
	get_root().add_child(bounded_turn)
	bounded_turn.global_position = Vector2.ZERO
	var bounded_finishes: Array[int] = []
	bounded_turn.finished.connect(func(_projectile: TherapyProjectile) -> void: bounded_finishes.append(1))
	bounded_turn.configure_hostile(Vector2.RIGHT, 1.0, topology, avatar, null, TherapyProjectile.HOSTILE_DOUBLE_TURN, 0.0, 100.0, 50.0, 0.0, 180.0, 1.0, 1.0, 0.4)
	bounded_turn.step_fixed(0.6)
	_near(bounded_turn.travelled_distance, 50.0, "Andere Doppelkurvenverträge behalten ihre authored Distanzgrenze")
	_equal(bounded_finishes.size(), 1, "Die normale Distanzgrenze beendet ein nicht zeitgebundenes Doppelkurvenprojektil")
	left_turn.recycle()
	_near(left_turn.hostile_first_turn_seconds, 0.0, "Pool-Recycling löscht den ersten Kurvenzeitpunkt")
	_near(left_turn.hostile_second_leg_seconds, 0.0, "Pool-Recycling löscht den zweiten Kurvenzeitpunkt")
	_near(left_turn.hostile_elapsed_seconds, 0.0, "Pool-Recycling löscht die vergangene Kurvenzeit")
	_equal(left_turn.hostile_turn_count, 0, "Pool-Recycling löscht den Kurvenfortschritt")
	_true(overshoot_turn.hostile_time_bounded_double_turn, "Der zeitgebundene Testkörper trägt vor Recycling den Fall-2-Vertrag")
	overshoot_turn.recycle()
	_true(not overshoot_turn.hostile_time_bounded_double_turn, "Pool-Recycling löscht den Fall-2-Zeitvertrag")
	for node in [normal, default_width, wide, upper, lower, left_turn, right_turn, faster_turn, overshoot_turn, tail_turn, bounded_turn, avatar]:
		node.queue_free()
	await process_frame


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual == expected:
		return
	failures += 1
	printerr("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	assertions += 1
	if absf(actual - expected) <= tolerance:
		return
	failures += 1
	printerr("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])
