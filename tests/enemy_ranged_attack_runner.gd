extends SceneTree

var assertions := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_anchor_case_boss_contract()
	await _test_intro_boss_normal_attack()
	await _test_case_two_boss_attack_and_add_lock()
	await _test_configurable_boss_contract()
	await _test_generation_safe_attack_director()
	await _test_hostile_projectile_geometry()
	if failures == 0:
		print("ALVEOLUS_ENEMY_RANGED_ATTACK_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_ENEMY_RANGED_ATTACK_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)


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
	_near(case_two.boss_projectile_attack_speed_multiplier, 1.8, "Fall 2 erhöht die Bossrate linear um 80 Prozent")
	_near(case_two.boss_reinforcement_interval, 15.0, "Fall 2 ruft alle 15 Sekunden Adds")
	var case_one := levels[1] as LevelDefinition
	_true(case_one.boss_ranged_enabled and case_one.boss_projectiles_require_empty_aura, "Fall 1 aktiviert den Bossbeschuss ausschließlich bei leerer Aura")
	_near(case_one.boss_projectile_speed_multiplier, 1.3, "Fall-1-Bossprojektile erhalten den relativen 30-Prozent-Temposchritt")
	_near(case_one.boss_add_projectile_attack_speed_multiplier, 2.0, "Fall-1-Bossverstärkungen verwenden die doppelte Schussrate")


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
	director.projectile_requested.connect(func(_source: int, pattern: int, phase: float, _role: int) -> void:
		shots.append({"pattern": pattern, "phase": phase})
	)
	_true(director.register_enemy(handle, EnemyAttackDirector.Role.BOSS), "Fall-2-Boss wird als Schütze registriert")
	_true(director.configure_boss_contract(handle, true, 15.0, 4, 0), "Fall-2-Boss übernimmt den 15-Sekunden-Addvertrag")
	director.step_fixed(0.65)
	_equal(shots.size(), 1, "Der Fall-2-Boss feuert pro Takt ein Doppelkurvenprojektil")
	_equal(int(shots[0]["pattern"]), EnemyAttackDirector.Pattern.DOUBLE_TURN, "Der echte Director emittiert das Doppelkurvenmuster")
	_near(boss.resolved_projectile_interval(), 1.6 / 1.8, "80 Prozent Rate ergeben rund 0,89 Sekunden Intervall")
	director.step_fixed(1.6 / 1.8)
	_equal(shots.size(), 2, "Nach rund 0,89 Sekunden feuert der Fall-2-Boss erneut")
	_true(float(shots[0]["phase"]) != float(shots[1]["phase"]), "Aufeinanderfolgende Projektile teilen sich deterministisch 50/50 auf beide Kurvenseiten")
	director.release(handle)
	world.release(handle, false)
	world.flush_deferred()
	boss.queue_free()
	shots.clear()

	var add := InfectionEnemy.new()
	get_root().add_child(add)
	add.configure(ContentCatalog.enemy_definitions()[&"pneumococcus"], avatar, topology)
	add.configure_projectile_modifiers(2.0, 1.0, 1.0, -1.0)
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
	_true(add.projectiles_suppressed(), "Stoß sperrt den Fall-2-Boss-Add dauerhaft")
	director.step_fixed(30.0)
	_equal(shots.size(), 0, "Ein dauerhaft gesperrter Add feuert auch nach 30 Sekunden nicht")
	director.release(add_handle)
	world.release(add_handle, false)
	world.flush_deferred()
	add.recycle()
	_true(not add.projectiles_suppressed(), "Pool-Recycling entfernt die dauerhafte Schusssperre")
	world.clear()
	add.queue_free()
	avatar.queue_free()
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


func _test_configurable_boss_contract() -> void:
	var topology := ArenaTopology.new(Rect2(-600.0, -400.0, 1200.0, 800.0))
	var avatar := TherapyAvatar.new()
	avatar.global_position = Vector2(260.0, 0.0)
	get_root().add_child(avatar)
	var world := EnemyWorld.new().configure_enemy_world()
	var director := EnemyAttackDirector.new().configure(CombatCapacity.defaults().max_enemies, world.resolve)
	var shots: Array[int] = []
	var reinforcements: Array[int] = []
	director.projectile_requested.connect(func(source: int, _pattern: int, _phase: float, _role: int) -> void:
		shots.append(source)
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
		director.configure_boss_contract(custom_handle, false, 15.0, 4, 0),
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
	_equal(shots.size(), 2, "Die Freigabe feuert das vorhandene Rautenpaar nach der Boss-Startverzögerung")
	_true(director.set_projectile_enabled(custom_handle, false), "Ein Monster in der Aura sperrt nur den Bossbeschuss wieder")
	director.step_fixed(10.0)
	_equal(shots.size(), 2, "Die erneute Aurasperre stoppt Schüsse ohne den Directorlease freizugeben")
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
	left_turn.configure_hostile(Vector2.RIGHT, 1.0, topology, avatar, null, TherapyProjectile.HOSTILE_DOUBLE_TURN, 0.0, 100.0, 500.0, 0.0, 180.0, 1.0, 100.0, 40.0)
	right_turn.configure_hostile(Vector2.RIGHT, 1.0, topology, avatar, null, TherapyProjectile.HOSTILE_DOUBLE_TURN, 0.5, 100.0, 500.0, 0.0, 180.0, 1.0, 100.0, 40.0)
	left_turn.step_fixed(1.0)
	right_turn.step_fixed(1.0)
	_near(left_turn.global_position.x, 100.0, "Erste Kurve beginnt nach exakt 100 Test-Weltpunkten")
	_true(left_turn.direction.y < -0.99 and right_turn.direction.y > 0.99, "Erste 90-Grad-Kurve verteilt Projektile auf beide Seiten")
	left_turn.step_fixed(0.4)
	right_turn.step_fixed(0.4)
	_true(left_turn.direction.x < -0.99 and right_turn.direction.x < -0.99, "Die zweite Kurve dreht in derselben Richtung weiter")
	_near(absf(left_turn.global_position.y), 40.0, "Die zweite Kurve folgt nach weiteren 40 Test-Weltpunkten")
	left_turn.recycle()
	_near(left_turn.hostile_first_turn_distance, 0.0, "Pool-Recycling löscht die erste Kurvendistanz")
	_equal(left_turn.hostile_turn_count, 0, "Pool-Recycling löscht den Kurvenfortschritt")
	for node in [normal, default_width, wide, upper, lower, left_turn, right_turn, avatar]:
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
