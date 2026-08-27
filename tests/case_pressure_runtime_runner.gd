extends SceneTree

## Runtime contract for the authored case-pressure layer. The test exercises
## the real Game helpers but keeps physics paused so no ambient wave or input
## timing can affect the deterministic target and gate slices.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const GameScript := preload("res://scripts/game.gd")

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_static_pressure_limits()
	_test_pure_salvo_and_gate_seams()
	await _test_case_four_radial_fuse()
	await _test_live_target_and_gate_contract()
	await _test_case_one_event_target_profile()
	await _test_case_two_target_remains_mobile()
	_finish()


func _test_static_pressure_limits() -> void:
	_equal(GameScript.CASE_PRESSURE_TARGET_ACTIVE_SECONDS, 20.0, "Zielherde bleiben zwanzig Sekunden aktiv")
	_equal(GameScript.CASE_PRESSURE_WARNING_SECONDS, 1.5, "Zielherde und Tore verwenden die 1,5-Sekunden-Warnung")
	_equal(GameScript.CASE_PRESSURE_FAN_ANGLES.size(), 5, "Eine Zielherdsalve besitzt exakt fünf Projektile")
	_equal(GameScript.CASE_PRESSURE_RADIAL_MAX_PROJECTILES, 20, "Die volle Fall-4-Restgesundheit bewahrt insgesamt zwanzig Projektile")
	_equal(GameScript.CASE_PRESSURE_GATE_SPACING, 52.0, "Projektiltore behalten höchstens 52 Weltpunkte Reihenabstand")
	_equal(GameScript.CASE_PRESSURE_GATE_SAFE_GAP, 156.0, "Projektiltore behalten die sichere Lücke von mindestens 156 Weltpunkten")
	_equal(GameScript.CASE_PRESSURE_GATE_MAX_PROJECTILES, 24, "Ein Projektiltor bleibt auf 24 Projektile begrenzt")
	_equal(GameScript.PRESSURE_PROJECTILE_RESERVE, 48, "Falldruck reserviert 48 Projektilplätze")
	_equal(
		GameScript.REGULAR_PROJECTILE_LIMIT + GameScript.PRESSURE_PROJECTILE_RESERVE,
		GameScript.MAX_ACTIVE_PROJECTILES,
		"Reguläre Projektilgrenze und Falldruckreserve teilen die Gesamtkapazität exakt auf"
	)
	var levels := ContentCatalog.level_definitions()
	var order_five := _level_by_id(levels, &"critical_infection")
	var order_six := _level_by_id(levels, &"severe_pneumonia")
	_true(order_five != null and order_five.order == 5 and order_five.case_pressure_targets_stationary, "Fall 5 aktiviert stationäre Druckziele absichtlich")
	_true(order_six != null and order_six.order == 6 and order_six.case_pressure_targets_stationary, "Fall 6 aktiviert stationäre Druckziele absichtlich")
	_equal(order_five.case_pressure_plan.projectile_gate_times.size(), 2, "Fall 5 besitzt genau zwei projektierte Tore")
	_equal(order_six.case_pressure_plan.projectile_gate_times.size(), 3, "Fall 6 besitzt genau drei projektierte Tore")


func _test_pure_salvo_and_gate_seams() -> void:
	var pure_game := GameScript.new()
	_equal(pure_game._case_pressure_salvo_quota(100.0, 100.0), 4, "Volle Restgesundheit erhält vier Salven")
	_equal(pure_game._case_pressure_salvo_quota(75.0, 100.0), 3, "Drei verbleibende Viertel erhalten drei Salven")
	_equal(pure_game._case_pressure_salvo_quota(50.0, 100.0), 2, "Halbe Restgesundheit erhält zwei Salven")
	_equal(pure_game._case_pressure_salvo_quota(25.0, 100.0), 1, "Ein verbleibendes Viertel erhält eine Salve")
	_equal(pure_game._case_pressure_salvo_quota(0.0, 100.0), 0, "Ein leerer Herd erhält keine Salve")
	_equal(pure_game._case_pressure_salvo_quota(10.0, 0.0), 0, "Ungültige Maximalgesundheit erzeugt keine Salve")
	_equal(pure_game._case_pressure_radial_projectile_count(100.0, 100.0), 20, "Volle Restgesundheit erzeugt zwanzig Kreisprojektile")
	_equal(pure_game._case_pressure_radial_projectile_count(75.0, 100.0), 15, "Drei Viertel Restgesundheit erzeugen fünfzehn Kreisprojektile")
	_equal(pure_game._case_pressure_radial_projectile_count(50.0, 100.0), 10, "Halbe Restgesundheit erzeugt zehn Kreisprojektile")
	_equal(pure_game._case_pressure_radial_projectile_count(25.0, 100.0), 5, "Ein Viertel Restgesundheit erzeugt fünf Kreisprojektile")
	_equal(pure_game._case_pressure_radial_projectile_count(1.0, 100.0), 1, "Positives Restleben erzeugt mindestens ein Kreisprojektil")
	_equal(pure_game._case_pressure_radial_projectile_count(0.0, 100.0), 0, "Kein Restleben erzeugt kein Kreisprojektil")

	var lanes := pure_game._case_pressure_gate_lane_coordinates(-186.0, 186.0, 0.0)
	_true(not lanes.is_empty(), "Der reine Gate-Seam liefert Bahnen")
	_true(lanes.size() <= GameScript.CASE_PRESSURE_GATE_MAX_PROJECTILES, "Der reine Gate-Seam begrenzt auf 24 Projektile")
	var lower_lane := -INF
	var upper_lane := INF
	for lane in lanes:
		if lane <= 0.0:
			lower_lane = maxf(lower_lane, lane)
		else:
			upper_lane = minf(upper_lane, lane)
	_true(upper_lane - lower_lane >= GameScript.CASE_PRESSURE_GATE_SAFE_GAP, "Der reine Gate-Seam hält die sichere Lücke ein")
	var capped_lanes := pure_game._case_pressure_gate_lane_coordinates(-2000.0, 2000.0, 0.0)
	_equal(capped_lanes.size(), GameScript.CASE_PRESSURE_GATE_MAX_PROJECTILES, "Breite Tore werden deterministisch auf 24 Bahnen gekürzt")
	pure_game.free()


func _test_case_four_radial_fuse() -> void:
	var game := MAIN_SCENE.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.persistence_enabled = false
	game.run_test_settings.reset_defaults()
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game.selected_level = _level_by_id(game.levels, &"spreading_infection")
	_true(game.selected_level != null and game.selected_level.order == 4, "Brandschnurtest verwendet Fall 4")
	game.start_run()
	game.set_physics_process(false)

	game._spawn_case_pressure_target({&"spawn_sector": 5})
	_equal(game.case_pressure_target_states.size(), 1, "Fall 4 erzeugt genau ein Brandschnurziel")
	var handle := int(game.case_pressure_target_states.keys()[0])
	var target := game.enemy_world.resolve(handle) as InfectionEnemy
	_true(is_instance_valid(target), "Das Brandschnurziel besitzt einen gültigen Handle")
	if is_instance_valid(target):
		var runtime: Dictionary = game.case_pressure_target_states[handle]
		_equal(StringName(runtime.get(&"behavior", &"")), &"radial_fuse", "Nur Fall 4 aktiviert das radiale Brandschnurfinale")
		_true(target.is_static_flow_obstacle(), "Das Fall-4-Event bleibt ein stationäres Flusshindernis")
		_true(target.static_stun_enabled, "Das Fall-4-Event veröffentlicht seine lokale Stun-Ausnahme")
		_true(target.has_event_fuse(), "Die rein visuelle Brandschnur ist ab Aktivierung vorhanden")
		_equal(game.enemy_attack_director.role_for(handle), EnemyAttackDirector.Role.MINOR_FOCUS, "Während der Brandschnur schießt das Eventmonster normal weiter")
		_equal(game._active_case_pressure_target_count(), 1, "Ein materialisierender Zielherd belegt bereits seinen Eventslot")
		game._step_case_pressure_targets(0.25)
		_true(game.case_pressure_target_states.has(handle), "Der Runtimevertrag überlebt den Spawntelegraphen")
		_near(target.event_fuse_progress, 1.0, "Die Brandschnur beginnt erst nach vollständiger Materialisierung")

		target.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
		var stationary_position := target.global_position
		target.apply_knockback(Vector2.RIGHT, 90.0, 0.28, 1.0)
		_true(target.is_stunned(), "Stoß betäubt das ausdrücklich freigegebene statische Eventmonster")
		_true(target.global_position.is_equal_approx(stationary_position), "Die Stun-Ausnahme verschiebt das stationäre Eventmonster nicht")
		target.step_fixed(1.01)
		_true(not target.is_stunned(), "Der kurze Stoß-Stun endet weiterhin nach einer Sekunde")

		game._step_case_pressure_targets(0.0)
		target.health = target.max_health * 0.5
		var projectiles_before: int = game.projectiles.size()
		game._step_case_pressure_targets(GameScript.CASE_PRESSURE_TARGET_ACTIVE_SECONDS)
		runtime = game.case_pressure_target_states[handle]
		_equal(int(runtime.get(&"radial_projectiles_emitted", -1)), 10, "Halbes Restleben erzeugt beim Ablauf exakt zehn Kreisprojektile")
		_equal(game.projectiles.size() - projectiles_before, 10, "Der Ablauf materialisiert alle zehn proportionalen Projektile gleichzeitig")
		_true(bool(runtime.get(&"pending_expiration", false)), "Der radiale Burst reiht das Ziel exakt einmal zur Freigabe ein")
		_true(not target.has_event_fuse(), "Nach dem Ablauf bleibt keine Brandschnur am recycelten Ziel sichtbar")
		_equal(game.enemy_attack_director.role_for(handle), EnemyAttackDirector.Role.NONE, "Der Ablauf beendet den normalen Projektilangriff")
		for projectile_index in range(10):
			var projectile := game.projectiles[projectiles_before + projectile_index] as TherapyProjectile
			var expected_direction := Vector2.RIGHT.rotated(TAU * float(projectile_index) / 10.0)
			_true(projectile.direction.dot(expected_direction) > 0.999, "Kreisprojektil %d besitzt seine gleichmäßig verteilte Richtung" % projectile_index)
		game._flush_case_pressure_target_expirations()
		_equal(game.case_pressure_target_states.size(), 0, "Nach dem Burst wird der abgelaufene Zielherd vollständig freigegeben")

	game._spawn_case_pressure_target({&"spawn_sector": 9})
	var stunned_handle := int(game.case_pressure_target_states.keys()[0])
	var stunned_target := game.enemy_world.resolve(stunned_handle) as InfectionEnemy
	_true(is_instance_valid(stunned_target), "Ein zweites Brandschnurziel kann aus dem Pool aktiviert werden")
	if is_instance_valid(stunned_target):
		stunned_target.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
		game._step_case_pressure_targets(0.0)
		stunned_target.apply_knockback(Vector2.UP, 90.0, 0.28, 1.0)
		var stunned_projectiles_before: int = game.projectiles.size()
		game._step_case_pressure_targets(GameScript.CASE_PRESSURE_TARGET_ACTIVE_SECONDS)
		var stunned_runtime: Dictionary = game.case_pressure_target_states[stunned_handle]
		_true(stunned_target.is_stunned(), "Der Stoß-Stun liegt im exakten Ablaufmoment noch an")
		_equal(int(stunned_runtime.get(&"radial_projectiles_emitted", -1)), 0, "Ein im Ablaufmoment betäubtes Eventmonster wird vollständig entschärft")
		_equal(game.projectiles.size(), stunned_projectiles_before, "Der perfekt getimte Stun hinterlässt kein einziges Projektil")
		game._flush_case_pressure_target_expirations()
		_true(not stunned_target.static_stun_enabled and not stunned_target.has_event_fuse(), "Pool-Recycling löscht Stun- und Brandschnurvertrag vollständig")

	game.queue_free()
	await process_frame


func _test_live_target_and_gate_contract() -> void:
	var game := MAIN_SCENE.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	game.persistence_enabled = false
	game.run_test_settings.reset_defaults()
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game.selected_level = _level_by_id(game.levels, &"severe_pneumonia")
	_true(game.selected_level != null and game.selected_level.order == 6, "Live-Drucktest verwendet den erhaltenen Order-6-Anker")
	game.start_run()
	game.set_physics_process(false)

	_spawn_and_assert_gate(game)
	_spawn_and_assert_target(game)
	_assert_intro_and_boss_exclusion(game)

	game.queue_free()
	await process_frame


func _test_case_two_target_remains_mobile() -> void:
	var game := MAIN_SCENE.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.persistence_enabled = false
	game.run_test_settings.reset_defaults()
	for discovery_id in game.discovery_definitions:
		game.discovery_manager.mark_seen(discovery_id)
	game.selected_level = _level_by_id(game.levels, &"localized_focus")
	_true(game.selected_level != null and game.selected_level.order == 2, "Mobiler Druckzieltest verwendet den erhaltenen Order-2-Anker")
	game.start_run()
	game.set_physics_process(false)
	game._spawn_case_pressure_target({&"spawn_sector": 2})
	_equal(game.case_pressure_target_states.size(), 1, "Fall 2 erzeugt genau einen beweglichen kleinen Herd")
	if not game.case_pressure_target_states.is_empty():
		var handle := int(game.case_pressure_target_states.keys()[0])
		var target := game.enemy_world.resolve(handle) as InfectionEnemy
		_true(is_instance_valid(target), "Der Fall-2-Herd besitzt einen gültigen Handle")
		if is_instance_valid(target):
			var runtime: Dictionary = game.case_pressure_target_states[handle]
			_equal(StringName(runtime.get(&"behavior", &"")), &"ambient_focus", "Fall 2 behält den beweglichen Herdvertrag")
			_true(not target.is_static_flow_obstacle(), "Der kleine Fall-2-Herd wird kein stationäres Hindernis")
			_equal(target.body_role, EnemySpawnRequest.BodyRole.MOBILE, "Fall 2 behält die normale mobile Körperrolle")
			_near(target.definition.speed * target.speed_multiplier, 42.0 * game.config.enemy_speed_multiplier * 2.0, "Der Fall-2-Schwarm bewegt sich mit doppeltem Eventtempo")
			_equal(target.resolved_visual_id(), &"bacterial_swarm", "Der Fall-2-Herd zeigt viele kleine Bakterien als ein gemeinsames Visual")
			_near(target.runtime_visual_scale, 1.12, "Der Fall-2-Schwarm veröffentlicht die leicht größere Darstellung")
			_near(target.max_health, 1200.0, "Der Fall-2-Schwarm besitzt exakt 1200 gemeinsames Leben")
			_equal(target.symbolic_health_bar_count, 1, "Der Fall-2-Schwarm veröffentlicht genau einen gemeinsamen Lebensbalken")
			_true(target.treatment_line_coverage_scaled, "Der Fall-2-Schwarm aktiviert die virtuelle Flächenabdeckung")
			target.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
			target.global_position = Vector2(120.0, 0.0)
			var beam_origin := Vector2.ZERO
			_near(target.treatment_line_damage_multiplier_for_geometry(beam_origin, Vector2.RIGHT, 300.0, 19.0), 12.0, "Basisbreite trifft zwölf virtuelle Teilbakterien")
			_near(target.treatment_line_damage_multiplier_for_geometry(beam_origin, Vector2.RIGHT, 300.0, 27.0), 16.0, "Der erste Breitenrang trifft sechzehn virtuelle Teilbakterien")
			_near(target.treatment_line_damage_multiplier_for_geometry(beam_origin, Vector2.RIGHT, 300.0, 35.0), 19.0, "Der zweite Breitenrang trifft neunzehn virtuelle Teilbakterien")
			_near(target.treatment_line_damage_multiplier_for_geometry(beam_origin, Vector2.RIGHT, 300.0, 38.0), 20.0, "Eine vollständig durchlaufene Hitbox löst exakt den zwanzigfachen Lazerwert aus")
			_true(target.treatment_line_damage_multiplier_for_geometry(beam_origin, Vector2.RIGHT.rotated(deg_to_rad(10.0)), 300.0, 35.0) < 20.0, "Ein gedrehter Teiltreffer bleibt unter dem Maximalwert")
			target.global_position = Vector2(30.0, 0.0)
			_true(target.treatment_line_damage_multiplier_for_geometry(beam_origin, Vector2.RIGHT, 300.0, 38.0) < 20.0, "Die offene Strahlstartkappe kann keinen vollständigen Treffer vortäuschen")
			target.global_position = Vector2(280.0, 0.0)
			_true(target.treatment_line_damage_multiplier_for_geometry(beam_origin, Vector2.RIGHT, 300.0, 38.0) < 20.0, "Die offene Strahlendkappe kann keinen vollständigen Treffer vortäuschen")
			target.global_position = Vector2(120.0, 0.0)
			var health_before_impulse := target.health
			target.take_damage(10.0, &"treatment_precision")
			_near(target.health, health_before_impulse - 10.0, "Andere Treffer behalten am Fall-2-Schwarm ihren normalen Schaden")
			_equal(game.enemy_attack_director.role_for(handle), EnemyAttackDirector.Role.NONE, "Der bewegliche Fall-2-Schwarm belegt keinen Schützen-Lease")
			_true(not target.can_emit_projectiles(), "Der Fall-2-Schwarm kann weder definitions- noch runtimebasiert Projektile emittieren")
			target.apply_defense_burst_shooting_lock()
			_true(not target.projectiles_suppressed(), "Ein Gegner ohne Projektilvertrag zeigt nach Stoß keine irreführende Schusssperre")
	game.queue_free()
	await process_frame


func _test_case_one_event_target_profile() -> void:
	var game := MAIN_SCENE.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	game.persistence_enabled = false
	game.run_test_settings.reset_defaults()
	# Runtime fixtures must not inherit the developer's persisted hint opt-out.
	game.meta.ui_settings.show_discovery_info = true
	for discovery_id in game.discovery_definitions:
		if discovery_id != GameScript.FALL_ONE_EVENT_HINT_ID:
			game.discovery_manager.mark_seen(discovery_id)
	game.discovery_manager.seen_ids.erase(GameScript.FALL_ONE_EVENT_HINT_ID)
	game.meta.seen_discovery_ids.erase(GameScript.FALL_ONE_EVENT_HINT_ID)
	# The runtime fixture must not inherit the developer's real Fall-1 record.
	# This hint is intentionally scoped to the first attempt only.
	game.meta.level_records.erase(GameScript.FALL_ONE_ID)
	game.selected_level = _level_by_id(game.levels, &"early_localized_focus")
	_true(game.selected_level != null and game.selected_level.order == 1, "Eventherdtest verwendet Fall 1")
	game.start_run()
	game.set_physics_process(false)
	game._spawn_case_pressure_target({&"spawn_sector": 3})
	_equal(game.case_pressure_target_states.size(), 1, "Fall 1 erzeugt genau einen mobilen Eventherd")
	if not game.case_pressure_target_states.is_empty():
		var handle := int(game.case_pressure_target_states.keys()[0])
		var target := game.enemy_world.resolve(handle) as InfectionEnemy
		_true(is_instance_valid(target), "Der Fall-1-Eventherd besitzt einen gültigen Handle")
		if is_instance_valid(target):
			_true(game.discovery_manager.active.is_empty(), "Der Fall-1-Hinweis wartet bis zur tatsächlichen Materialisierung")
			_equal(target.definition.id, &"minor_focus", "Der Fall-1-Eventherd bewahrt seine stabile Gameplay-ID")
			_equal(target.definition.visual_id, &"infection_focus", "Normale kleine Herde behalten ihr bisheriges Katalogvisual")
			_equal(target.resolved_visual_id(), &"case_one_event_monster", "Nur der Fall-1-Eventherd löst auf die Nutzerzeichnung auf")
			_true(target.visual_texture != null, "Das neue Eventmonster ist als Gameplay-Textur geladen")
			_near(target.runtime_visual_scale, 1.0, "Das neue Sprite bewahrt den bisherigen Präsentationsfaktor des Eventherds")
			_near(target.visual_extent(), target.definition.radius * 2.35, "Das neue Sprite bewahrt die bisherige sichtbare Größe des kleinen Eventherds")
			_near(target.max_health, 135.0, "Der Fall-1-Eventherd besitzt 25 Prozent weniger Leben")
			_near(
				target.definition.speed * target.speed_multiplier,
				66.0 * game.config.enemy_speed_multiplier,
				"Der Fall-1-Eventherd besitzt nach diesem Patch ganzzahliges Basistempo 66"
			)
			_near(target.projectile_attack_speed_multiplier, 1.875, "Der Fall-1-Eventherd besitzt die um weitere 50 Prozent erhöhte Schussrate")
			_near(target.resolved_projectile_interval(), 2.6 / 1.875, "Die lineare Feuerrate ergibt ein Intervall von rund 1,39 Sekunden")
			_near(target.projectile_width_multiplier, 1.5, "Der Fall-1-Eventherd veröffentlicht 50 Prozent breitere Projektile")
			_near(target.projectile_speed_multiplier, 1.95, "Der Fall-1-Eventherd veröffentlicht relativ nochmals 30 Prozent schnellere Projektile")
			_near(target.defense_burst_shooting_lock_seconds, 10.0, "Der Fall-1-Eventherd übernimmt die zehnsekündige Stoßsperre")
			target.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
			_true(target.materialized_emitted, "Der Eventherd überschreitet vor dem Hinweis die echte Materialisierungsgrenze")
			_true(game.case_pressure_target_states.has(game.enemy_world.handle_for(target)), "Der materialisierte Eventherd bleibt als Fallziel registriert")
			_true(not game.meta.has_completed_level(GameScript.FALL_ONE_ID), "Der Hinweisvertrag läuft ausschließlich vor dem ersten Fallsieg")
			_equal(game.discovery_manager.active.get("id", &""), GameScript.FALL_ONE_EVENT_HINT_ID, "Die Materialisierung des ersten Fall-1-Eventherds öffnet den einmaligen Fähigkeits-Hinweis")
			_equal(game.discovery_manager.active.get("target"), target, "Der Fähigkeits-Hinweis zeigt auf das tatsächlich materialisierte Eventmonster")
			_equal(game.hud.discovery_tooltip.gameplay_label.text, "Manche Monster sind anfällig gegen bestimmte Fähigkeiten. Probiere Stoß aus.", "Der erste Event-Hinweis verwendet die freigegebene Copy")
			game._on_discovery_dismissed()
			_true(game.discovery_manager.has_seen(GameScript.FALL_ONE_EVENT_HINT_ID), "Bestätigter Event-Hinweis wird profilweit nicht wiederholt")
			var projectiles_before: int = game.projectiles.size()
			game.enemy_attack_director.step_fixed(0.899)
			_equal(game.projectiles.size(), projectiles_before, "Der unveränderte erste Telegraph feuert nicht vor 0,9 Sekunden")
			game.enemy_attack_director.step_fixed(0.002)
			_equal(game.projectiles.size(), projectiles_before + 1, "Nach dem ersten Telegraphen entsteht genau ein Eventherdprojektil")
			if game.projectiles.size() > projectiles_before:
				var projectile := game.projectiles[-1] as TherapyProjectile
				_near(projectile.hostile_width_multiplier, 1.5, "Das echte Eventherdprojektil übernimmt die breitere Darstellung und Trefferfläche")
				_near(projectile.speed, 399.75, "Das echte Eventherdprojektil fliegt relativ nochmals 30 Prozent schneller")
			target.apply_defense_burst_shooting_lock()
			_true(target.projectiles_suppressed(), "Ein Stoß beendet den Eventherdbeschuss sofort")
			target.step_fixed(9.99)
			game.enemy_attack_director.step_fixed(9.99)
			_true(target.projectiles_suppressed(), "Unmittelbar vor zehn Sekunden bleibt der Eventherd schussunfähig")
			_equal(game.projectiles.size(), projectiles_before + 1, "Während der zehnsekündigen Sperre entsteht kein weiteres Eventherdprojektil")
			target.step_fixed(0.02)
			_true(not target.projectiles_suppressed(), "Nach zehn Sekunden endet die Eventherd-Schusssperre")
			game.enemy_attack_director.step_fixed(target.resolved_projectile_interval() + 0.01)
			_equal(game.projectiles.size(), projectiles_before + 2, "Nach Ablauf der Sperre feuert der Eventherd wieder")
	game.queue_free()
	await process_frame


func _spawn_and_assert_gate(game) -> void:
	var gate_id := 91
	var safe_position := Vector2.ZERO
	game._spawn_case_pressure_gate({
		&"gate_id": gate_id,
		&"orientation": 0,
		&"positive_direction": true,
		&"visible_rect": Rect2(-200.0, -160.0, 400.0, 320.0),
		&"safe_position": safe_position,
	})

	var gate_projectiles: Array = []
	var lanes: Array[float] = []
	for projectile in game.projectiles:
		if int(game.pressure_gate_id_by_projectile.get(projectile, -1)) != gate_id:
			continue
		gate_projectiles.append(projectile)
		lanes.append(projectile.global_position.y)
	_true(not gate_projectiles.is_empty(), "Ein Fall-6-Tor erzeugt echte feindliche Projektile")
	_true(gate_projectiles.size() <= GameScript.CASE_PRESSURE_GATE_MAX_PROJECTILES, "Das echte Tor überschreitet den 24-Projektildeckel nicht")
	_equal(int(game.pressure_gate_projectile_counts.get(gate_id, 0)), gate_projectiles.size(), "Gate-Telemetrie zählt alle erzeugten Reihenprojektile")

	lanes.sort()
	for index in range(1, lanes.size()):
		if lanes[index - 1] <= safe_position.y and lanes[index] > safe_position.y:
			continue
		_true(lanes[index] - lanes[index - 1] <= GameScript.CASE_PRESSURE_GATE_SPACING + 0.001, "Benachbarte Torbahnen bleiben höchstens 52 Weltpunkte entfernt")
	var lower_lane := -INF
	var upper_lane := INF
	for lane in lanes:
		if lane <= safe_position.y:
			lower_lane = maxf(lower_lane, lane)
		else:
			upper_lane = minf(upper_lane, lane)
	_true(upper_lane - lower_lane >= GameScript.CASE_PRESSURE_GATE_SAFE_GAP, "Die reale Torlücke bleibt mindestens 156 Weltpunkte breit")

	var profile := (game.enemy_definitions[&"minor_focus"] as EnemyDefinition).damage_profile
	var stability_before: float = float(game.state.stability)
	game._on_hostile_projectile_hit(gate_projectiles[0], GameScript.CASE_PRESSURE_PROJECTILE_DAMAGE, profile)
	var stability_after_first_hit: float = float(game.state.stability)
	_true(stability_after_first_hit < stability_before, "Der erste Treffer eines Tores verursacht Schaden")
	game.pressure_grace_timer = 0.0
	game._on_hostile_projectile_hit(gate_projectiles[-1], GameScript.CASE_PRESSURE_PROJECTILE_DAMAGE, profile)
	_equal(game.state.stability, stability_after_first_hit, "Ein Tor kann trotz zurückgesetzter Schadenspause nur einmal treffen")


func _spawn_and_assert_target(game) -> void:
	game._spawn_case_pressure_target({&"spawn_sector": 4})
	_equal(game.case_pressure_target_states.size(), 1, "Der Falldruck erzeugt genau einen Zielherd")
	var handle := int(game.case_pressure_target_states.keys()[0])
	var target := game.enemy_world.resolve(handle) as InfectionEnemy
	_true(is_instance_valid(target), "Der Zielherd besitzt einen auflösbaren EnemyWorld-Handle")
	if not is_instance_valid(target):
		return
	var runtime: Dictionary = game.case_pressure_target_states[handle]
	_equal(target.definition.id, &"minor_focus", "Der Falldruck verwendet den kleinen Herd als Ziel")
	_equal(StringName(runtime.get(&"behavior", &"")), &"stationary_fan", "Fall 6 markiert den Zielherd als stationären Fächer")
	_equal(StringName(runtime.get(&"phase", &"")), &"active", "Der Zielherd beginnt in der aktiven Lebensphase")
	_equal(float(runtime.get(&"remaining", 0.0)), GameScript.CASE_PRESSURE_TARGET_ACTIVE_SECONDS, "Der Zielherd erhält seine vollen 20 Sekunden")
	_equal(int(runtime.get(&"reward_points", 0)), 7, "Der Zielherd führt nur seine sieben zusätzlichen Belohnungspunkte getrennt")
	_equal(target.speed_multiplier, 0.0, "Der stationäre Zielherd erhält keine Bewegungsmultiplikation")
	_true(target.is_static_flow_obstacle(), "Fall-6-Zielherde veröffentlichen ihre stationäre Hindernisrolle")
	_equal(target.body_role, EnemySpawnRequest.BodyRole.STATIC_FLOW_OBSTACLE, "Die Zielherdrolle erreicht InfectionEnemy unverändert")
	_equal(target.obstacle_traversal, EnemySpawnRequest.ObstacleTraversal.DEFAULT, "Zielherde verwenden die normale Nichtboss-Umlaufregel")
	_true(not bool(game.enemy_world.bulk_member_state(handle).get("active", true)), "Stationäre Zielherde sind keine Pulkmitglieder")
	_equal(game.enemy_attack_director.role_for(handle), EnemyAttackDirector.Role.MINOR_FOCUS, "Der stationäre Zielherd schießt in seinen ersten 20 Sekunden normal")

	target.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	_true(target.is_targetable(), "Der Zielherd wird nach seinem normalen Spawntelegraphen angreifbar")
	game._step_case_pressure_targets(0.0)
	game._step_case_pressure_targets(GameScript.CASE_PRESSURE_TARGET_ACTIVE_SECONDS)
	runtime = game.case_pressure_target_states[handle]
	_equal(StringName(runtime.get(&"phase", &"")), &"warning", "Nach 20 Sekunden beginnt die Zielherd-Warnung")
	_equal(float(runtime.get(&"remaining", 0.0)), GameScript.CASE_PRESSURE_WARNING_SECONDS, "Die Zielherd-Warnung dauert exakt 1,5 Sekunden")
	_equal(game.enemy_attack_director.role_for(handle), EnemyAttackDirector.Role.NONE, "Mit Beginn der Warnung endet der normale Zielherdangriff")
	game._step_case_pressure_targets(GameScript.CASE_PRESSURE_WARNING_SECONDS)
	runtime = game.case_pressure_target_states[handle]
	_equal(StringName(runtime.get(&"phase", &"")), &"finale", "Nach der Warnung beginnt das Fächerfinale")

	var projectile_count_before: int = game.projectiles.size()
	for _salvo in range(4):
		game._step_case_pressure_targets(GameScript.CASE_PRESSURE_SALVO_INTERVAL + 0.01)
	runtime = game.case_pressure_target_states[handle]
	_equal(int(runtime.get(&"salvos_emitted", 0)), 4, "Volle Zielherdgesundheit erzeugt höchstens vier Salven nach den verbleibenden Vierteln")
	_equal(game.projectiles.size() - projectile_count_before, 20, "Vier Fünfer-Salven erzeugen exakt zwanzig Projektile")
	_true(bool(runtime.get(&"pending_expiration", false)), "Nach der vierten Salve wird der Zielherd sicher zur Freigabe vorgemerkt")

	var defeats_before: int = int(game.defeats)
	game._on_enemy_defeated(target, target.definition.analysis_value, false)
	_equal(game.defeats, defeats_before + 1, "Ein besiegter Zielherd bleibt genau ein sichtbarer Defeat")
	_equal(game.case_pressure_reward_defeat_points, 7, "Der Zielherdbonus bleibt als sieben zusätzliche Reward-Defeats getrennt gezählt")
	_equal(game.defeats + game.case_pressure_reward_defeat_points, defeats_before + 8, "Sichtbarer Defeat und Zusatzpunkte ergeben intern insgesamt acht Belohnungspunkte")
	_assert_remaining_health_quarters(game)


func _assert_remaining_health_quarters(game) -> void:
	game._spawn_case_pressure_target({&"spawn_sector": 7})
	var handle := int(game.case_pressure_target_states.keys()[0])
	var target := game.enemy_world.resolve(handle) as InfectionEnemy
	_true(is_instance_valid(target), "Ein zweiter Zielherd kann für den Vierteltest aufgelöst werden")
	if not is_instance_valid(target):
		return
	target.step_fixed(InfectionEnemy.SPAWN_TOTAL_SECONDS)
	target.health = target.max_health * 0.5
	var runtime: Dictionary = game.case_pressure_target_states[handle]
	runtime[&"phase"] = &"finale"
	runtime[&"remaining"] = 0.0
	runtime[&"locked_heading"] = Vector2.RIGHT
	runtime[&"just_spawned"] = false
	game.case_pressure_target_states[handle] = runtime
	var projectile_count_before: int = game.projectiles.size()
	for _salvo in range(2):
		game._step_case_pressure_targets(GameScript.CASE_PRESSURE_SALVO_INTERVAL + 0.01)
	runtime = game.case_pressure_target_states[handle]
	_equal(int(runtime.get(&"salvos_emitted", 0)), 2, "Halbe Restgesundheit erzeugt nur die zwei verbleibenden Viertelsalven")
	_equal(game.projectiles.size() - projectile_count_before, 10, "Zwei verbleibende Viertel ergeben exakt zwei Fünfer-Salven")


func _assert_intro_and_boss_exclusion(game) -> void:
	var target_count_before: int = game.case_pressure_target_states.size()
	var gate_count_before: int = game.case_pressure_pending_gates.size()
	game.selected_level = game.levels[0]
	game.case_pressure_director.configure(game.config.case_pressure_plan, game.config.random_seed, GameScript.WAVE_SPAWN_SECTOR_COUNT)
	game.state.elapsed = 200.0
	game.state.boss_spawned = false
	game._case_pressure_step(0.1)
	_equal(game.case_pressure_target_states.size(), target_count_before, "Die Einführung erzeugt keine Zielherde")
	_equal(game.case_pressure_pending_gates.size(), gate_count_before, "Die Einführung erzeugt keine Projektiltore")

	game.selected_level = _level_by_id(game.levels, &"severe_pneumonia")
	game.case_pressure_director.configure(game.config.case_pressure_plan, game.config.random_seed, GameScript.WAVE_SPAWN_SECTOR_COUNT)
	game.state.boss_spawned = true
	game._case_pressure_step(200.0)
	_equal(game.case_pressure_target_states.size(), target_count_before, "Ein aktiver Boss unterdrückt neue Zielherde")
	_equal(game.case_pressure_pending_gates.size(), gate_count_before, "Ein aktiver Boss unterdrückt neue Projektiltore")


func _level_by_id(levels: Array[LevelDefinition], id: StringName) -> LevelDefinition:
	for level in levels:
		if level.id == id:
			return level
	return null


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	_true(actual == expected, "%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	_true(absf(actual - expected) <= tolerance, "%s (expected=%.4f actual=%.4f)" % [message, expected, actual])


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_CASE_PRESSURE_RUNTIME_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	push_error("ALVEOLUS_CASE_PRESSURE_RUNTIME_FAILED failures=%d assertions=%d" % [failures.size(), assertions])
	quit(1)
