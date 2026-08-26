extends SceneTree

const GAME_SCRIPT := preload("res://scripts/game.gd")

var assertions := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_topology_modes()
	_test_bounded_spatial_grid()
	_test_bounded_bodies()
	_test_bounded_projectile()
	_test_friendly_projectile_hit_callback()
	if failures == 0:
		print("ALVEOLUS_BOUNDED_ARENA_OK assertions=%d" % assertions)
	else:
		push_error("ALVEOLUS_BOUNDED_ARENA_FAILED failures=%d assertions=%d" % [failures, assertions])
	quit(0 if failures == 0 else 1)


func _test_topology_modes() -> void:
	_equal(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "Das Spiel skaliert weiterhin sein 2D-Referenzcanvas")
	_equal(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "Nicht-16:9-Fenster füllen die gesamte Fläche verzerrungsfrei")
	var bounds := Rect2(0.0, 0.0, 200.0, 200.0)
	var wrapped := ArenaTopology.new(bounds)
	_true(wrapped.is_wrapping(), "WRAP bleibt der kompatible Standardmodus")
	_near(wrapped.shortest_delta(Vector2(5.0, 100.0), Vector2(195.0, 100.0)).x, -10.0, "WRAP verwendet weiterhin die kurze Torusstrecke")
	_near(wrapped.wrap_position(Vector2(205.0, 100.0)).x, 5.0, "WRAP setzt Positionen weiterhin an die Gegenseite")

	var bounded := ArenaTopology.new(bounds, ArenaTopology.BoundaryMode.BOUNDED)
	_true(bounded.is_bounded(), "BOUNDED ist explizit anwählbar")
	_near(bounded.shortest_delta(Vector2(5.0, 100.0), Vector2(195.0, 100.0)).x, 190.0, "BOUNDED verwendet eine gerade Strecke ohne Nahtabkürzung")
	_equal(bounded.resolve_position(Vector2(205.0, -5.0), 18.0), Vector2(182.0, 18.0), "BOUNDED klemmt Körper vollständig in die Arena")
	_true(not bounded.contains_position(Vector2(5.0, 100.0), 10.0), "Körperradien zählen zur Randprüfung")
	_true(bounded.contains_position(Vector2(10.0, 100.0), 10.0), "Eine den Rand berührende Körperhülle bleibt gültig")
	_near(bounded.limit_ray_length(Vector2(100.0, 100.0), Vector2.RIGHT, 300.0), 100.0, "Ein horizontaler Strahl endet an der ersten harten Kante")
	_near(bounded.limit_ray_length(Vector2(100.0, 100.0), Vector2.ONE, 300.0), sqrt(2.0) * 100.0, "Diagonale Strahlen verwenden eine normalisierte Weltstrecke")
	_near(bounded.limit_ray_length(Vector2(-50.0, 40.0), Vector2.RIGHT, 50.0), 50.0, "Ein außerhalb liegender Ursprung wird logisch geklemmt und die Wunschlänge bleibt begrenzt")
	_near(wrapped.limit_ray_length(Vector2(100.0, 100.0), Vector2.RIGHT, 300.0), 300.0, "WRAP begrenzt Strahlen weiterhin nicht")
	_near(float(GAME_SCRIPT.PRESSURE_GRACE_SECONDS), 0.5, "Die globale Schadens-Gnadenzeit beträgt 0,5 Sekunden")


func _test_bounded_spatial_grid() -> void:
	var bounds := Rect2(0.0, 0.0, 200.0, 200.0)
	var left := EntityHandle.make(0, 1)
	var right := EntityHandle.make(1, 1)
	var bounded_grid := CombatSpatialGrid.new().configure(
		ArenaTopology.new(bounds, ArenaTopology.BoundaryMode.BOUNDED),
		50.0
	)
	bounded_grid.insert_unique(left, Vector2(5.0, 100.0))
	bounded_grid.insert_unique(right, Vector2(195.0, 100.0))
	var bounded_hits := bounded_grid.query_circle_candidates(Vector2(5.0, 100.0), 15.0)
	_true(bounded_hits.has(left), "BOUNDED findet die lokale Randzelle")
	_true(not bounded_hits.has(right), "BOUNDED verbindet gegenüberliegende Randzellen nicht")

	var wrapped_grid := CombatSpatialGrid.new().configure(ArenaTopology.new(bounds), 50.0)
	wrapped_grid.insert_unique(left, Vector2(5.0, 100.0))
	wrapped_grid.insert_unique(right, Vector2(195.0, 100.0))
	var wrapped_hits := wrapped_grid.query_circle_candidates(Vector2(5.0, 100.0), 15.0)
	_true(wrapped_hits.has(left) and wrapped_hits.has(right), "WRAP verbindet die Naht weiterhin")


func _test_bounded_bodies() -> void:
	var topology := ArenaTopology.new(
		Rect2(0.0, 0.0, 200.0, 200.0),
		ArenaTopology.BoundaryMode.BOUNDED
	)
	var avatar := TherapyAvatar.new()
	avatar.configure(topology.bounds, PlayerStats.new(), topology)
	avatar.global_position = Vector2(199.0, 1.0)
	avatar.step_fixed(1.0 / 60.0)
	_equal(avatar.global_position, Vector2(177.0, 23.0), "Doctor bleibt mit BODY_RADIUS vollständig im Feld")

	var definition := EnemyDefinition.create(
		&"bounded_test", "Randtest", 100.0, 60.0, 5.0, 1, 18.0, Color.WHITE
	)
	var enemy := InfectionEnemy.new()
	enemy.global_position = Vector2(100.0, 100.0)
	enemy.configure(definition, avatar, topology)
	enemy.spawn_timer = 0.0
	enemy.apply_displacement(Vector2(200.0, 0.0))
	_near(enemy.global_position.x, 182.0, "Gegner-Displacement respektiert den Definitionsradius")
	enemy.global_position = Vector2(180.0, 100.0)
	enemy.apply_knockback(Vector2.RIGHT, 120.0, 0.1, 0.1)
	enemy.step_fixed(0.1)
	_near(enemy.global_position.x, 182.0, "Knockback kann Gegner nicht durch den Arenarand bewegen")

	var pickup := AnalysisPickup.new()
	pickup.global_position = Vector2(198.0, 2.0)
	pickup.configure(avatar, 1, topology)
	_equal(pickup.global_position, Vector2(188.0, 12.0), "Erfahrung bleibt mit ihrer Trefferhülle im Feld")
	pickup.free()
	enemy.free()
	avatar.free()


func _test_bounded_projectile() -> void:
	var topology := ArenaTopology.new(
		Rect2(0.0, 0.0, 200.0, 200.0),
		ArenaTopology.BoundaryMode.BOUNDED
	)
	var projectile := TherapyProjectile.new()
	projectile.global_position = Vector2(180.0, 100.0)
	var finished_count := [0]
	projectile.finished.connect(func(_projectile: TherapyProjectile) -> void: finished_count[0] += 1)
	projectile.configure_directional(Vector2.RIGHT, 10.0, topology, 200.0)
	projectile.step_fixed(0.1)
	_equal(finished_count[0], 1, "Ein Projektil endet beim Überschreiten der harten Grenze")
	_equal(projectile.global_position, Vector2(180.0, 100.0), "Ein endendes Projektil klebt nicht sichtbar am Rand")
	projectile.free()


func _test_friendly_projectile_hit_callback() -> void:
	var topology := ArenaTopology.new(Rect2(0.0, 0.0, 300.0, 300.0), ArenaTopology.BoundaryMode.BOUNDED)
	var definition := EnemyDefinition.create(&"callback_target", "Callbackziel", 100.0, 0.0, 0.0, 0, 12.0, Color.WHITE)
	var target := InfectionEnemy.new()
	target.global_position = Vector2(130.0, 100.0)
	target.configure(definition, null, topology)
	var callback_hits: Array[Variant] = []
	var projectile := TherapyProjectile.new()
	projectile.global_position = Vector2(100.0, 100.0)
	projectile.configure_directional(
		Vector2.RIGHT,
		10.0,
		topology,
		100.0,
		30.0,
		target,
		EntityHandle.INVALID,
		Callable(),
		&"treatment_precision",
		func(enemy: InfectionEnemy, amount: float, source: StringName) -> void:
			callback_hits.append([enemy, amount, source])
	)
	projectile.step_fixed(0.1)
	_equal(callback_hits.size(), 1, "Ein freundliches Impulsprojektil delegiert seinen Treffer exakt einmal")
	_equal(callback_hits[0], [target, 10.0, &"treatment_precision"], "Der Treffer-Callback erhält Ziel, Rohschaden und stabile Quelle")
	_near(target.health, 100.0, "Mit Callback wendet das Projektil keinen zweiten Direktschaden an")
	projectile.free()
	target.free()


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	push_error(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s (ist %s, erwartet %s)" % [message, actual, expected])


func _near(actual: float, expected: float, message: String, epsilon: float = 0.001) -> void:
	_true(absf(actual - expected) <= epsilon, "%s (ist %.4f, erwartet %.4f)" % [message, actual, expected])
