extends SceneTree

var assertions := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_case_two_boss_contract()
	await _test_intro_boss_normal_attack()
	await _test_generation_safe_attack_director()
	await _test_hostile_projectile_geometry()
	if failures == 0:
		print("ALVEOLUS_ENEMY_RANGED_ATTACK_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_ENEMY_RANGED_ATTACK_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)


func _test_case_two_boss_contract() -> void:
	var levels := ContentCatalog.level_definitions()
	var second_case := levels[2] as LevelDefinition
	_near(second_case.boss_speed_multiplier, 1.35, "Der Fall-2-Boss besitzt den datengetriebenen Geschwindigkeitsfaktor")
	_equal(second_case.boss_phase_minions, PackedInt32Array([4, 4]), "Der Fall-2-Boss ruft in beiden Phasen vier Adds")
	var config := RunConfig.from_level(second_case)
	_near(config.boss_speed_multiplier, 1.35, "RunConfig bewahrt den Bossfaktor")
	var enemies := ContentCatalog.enemy_definitions()
	var boss := enemies[&"infection_focus"] as EnemyDefinition
	var nest := enemies[&"minor_focus"] as EnemyDefinition
	var intro_boss := enemies[&"intro_focus"] as EnemyDefinition
	_near(boss.projectile_damage, 4.0, "Der Boss besitzt Projektilschaden")
	_near(boss.projectile_interval, 1.6, "Der Boss feuert fortlaufend")
	_equal(boss.projectile_pattern, &"diamond", "Der Boss verwendet das Rautenmuster")
	_near(nest.projectile_damage, 2.0, "Der kleine Herd besitzt Projektilschaden")
	_equal(nest.projectile_pattern, &"normal", "Der kleine Herd verwendet normale Projektile")
	_near(intro_boss.projectile_damage, 6.0, "Der Intro-Boss besitzt dreifachen Projektil-Basiswert")
	_near(intro_boss.projectile_interval, 2.6, "Der Intro-Boss feuert im ruhigen Normaltakt")
	_equal(intro_boss.projectile_pattern, &"normal", "Der Intro-Boss verwendet ausdrücklich das normale Projektil")


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
	boss.apply_knockback(Vector2.RIGHT, 1.0, 0.1, 1.0)
	director.step_fixed(0.65)
	_equal(shots.size(), 0, "Ein gestunnter Boss feuert keine Projektile und pausiert seinen Angriffstimer")
	boss.step_fixed(1.01)
	director.step_fixed(0.65)
	_equal(shots.size(), 2, "Ein Bossangriff erzeugt exakt zwei Projektile")
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
	for node in [normal, upper, lower, avatar]:
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
