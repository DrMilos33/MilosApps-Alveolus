extends SceneTree

var assertions: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_capacity_and_generations()
	_test_forward_tick_schedule()
	_test_torus_return_phase()
	_test_run_session_pause_contract()
	_finish()


func _test_capacity_and_generations() -> void:
	var world := TreatmentBeamWorld.new().configure(2)
	_equal(world.capacity, 2, "Die World verwendet eine feste explizite Kapazität")
	_equal(world.spawn(Vector2.ZERO, Vector2.RIGHT, 120.0, 20.0, 10.0, 0.0, 0.25, false, &"instant"), EntityHandle.INVALID, "Rang 0 kann außerhalb der persistenten World instant bleiben")
	var first := _spawn(world, Vector2.ZERO, Vector2.RIGHT, false)
	var second := _spawn(world, Vector2.ZERO, Vector2.UP, false)
	_true(EntityHandle.is_valid(first) and EntityHandle.is_valid(second), "Feste Slots liefern gültige Handles")
	_equal(world.active_count(), 2, "Die konfigurierte Kapazität kann vollständig belegt werden")
	_equal(_spawn(world, Vector2.ZERO, Vector2.LEFT, false), EntityHandle.INVALID, "Ein voller Beam-World erzeugt keine ungeplanten Zustände")
	_true(world.release(first), "Ein gültiger Strahl kann synchron freigegeben werden")
	var replacement := _spawn(world, Vector2.ZERO, Vector2.LEFT, false)
	_equal(EntityHandle.slot(replacement), EntityHandle.slot(first), "Ein freier Slot wird deterministisch wiederverwendet")
	_true(EntityHandle.generation(replacement) != EntityHandle.generation(first), "Slotwiederverwendung erhöht die Generation")
	_true(world.resolve(first) == null and world.resolve(replacement) != null, "Ein altes Handle kann den wiederverwendeten Slot nicht auflösen")
	world.clear()
	_equal(world.active_count(), 0, "Clear entfernt alle aktiven Strahlen")


func _test_forward_tick_schedule() -> void:
	var topology := ArenaTopology.new(Rect2(-500.0, -500.0, 1000.0, 1000.0))
	var inside := EntityHandle.make(0, 1)
	var outside_width := EntityHandle.make(1, 1)
	var query := _query(topology, {
		inside: Vector2(100.0, 0.0),
		outside_width: Vector2(100.0, 18.0),
	})
	var world := TreatmentBeamWorld.new().configure(2)
	var events: Array[Dictionary] = []
	var snapshot_events := [0]
	var world_ref: WeakRef = weakref(world)
	world.tick_resolved.connect(func(handle: int, handles: PackedInt64Array, is_return: bool) -> void:
		var active_world: TreatmentBeamWorld = world_ref.get_ref()
		var state: TreatmentBeamState = active_world.resolve(handle) if active_world != null else null
		events.append({
			"handle": handle,
			"handles": handles.duplicate(),
			"return": is_return,
			"damage": state.damage if state != null else -1.0,
			"source": state.source_id if state != null else &"",
		})
	)
	world.snapshot_changed.connect(func() -> void: snapshot_events[0] += 1)
	var beam := world.spawn(Vector2.ZERO, Vector2.RIGHT, 200.0, 20.0, 55.0, 0.5, 0.25, false, &"treatment_line")
	_true(EntityHandle.is_valid(beam), "Ein persistenter Vorwärtsstrahl wird reserviert")
	world.step_fixed(0.10, query)
	_equal(events.size(), 1, "Der erste Fixed-Step löst den Tick bei t=0 aus")
	var first_handles: PackedInt64Array = events[0].handles
	_true(first_handles.has(inside), "Der Tick trifft ein Ziel innerhalb der Linie")
	_false(first_handles.has(outside_width), "Die öffentliche volle Breite wird korrekt halbiert an CombatQuery übergeben")
	_near(float(events[0].damage), 55.0, "Der Handle löst während des Signals den exakten Schaden auf")
	_equal(events[0].source, &"treatment_line", "Der Tick bewahrt seine Schadensquelle")
	world.step_fixed(0.14, query)
	_equal(events.size(), 1, "Vor dem 0,25-s-Rhythmus entsteht kein zusätzlicher Tick")
	world.step_fixed(0.01, query)
	_equal(events.size(), 2, "Der zweite Tick liegt exakt bei t=0,25")
	world.step_fixed(0.25, query)
	_equal(events.size(), 2, "Das halboffene Phasenende erzeugt keinen doppelten Endtick")
	_equal(world.active_count(), 0, "Der Vorwärtsstrahl endet nach seiner Phase")
	_true(snapshot_events[0] >= 4, "Spawn, Fixed-Steps und Ende veröffentlichen Snapshot-Änderungen")
	world.clear()


func _test_torus_return_phase() -> void:
	var topology := ArenaTopology.new(Rect2(-500.0, -500.0, 1000.0, 1000.0))
	var across_seam := EntityHandle.make(2, 1)
	var near_endpoint := EntityHandle.make(3, 1)
	var query := _query(topology, {
		across_seam: Vector2(-480.0, 0.0),
		near_endpoint: Vector2(-450.0, 0.0),
	})
	var world := TreatmentBeamWorld.new().configure(1)
	var directions: Array[Vector2] = []
	var return_flags: Array[bool] = []
	var hit_sets: Array[PackedInt64Array] = []
	var world_ref: WeakRef = weakref(world)
	world.tick_resolved.connect(func(handle: int, handles: PackedInt64Array, is_return: bool) -> void:
		var active_world: TreatmentBeamWorld = world_ref.get_ref()
		var state: TreatmentBeamState = active_world.resolve(handle) if active_world != null else null
		directions.append(state.phase_direction() if state != null else Vector2.ZERO)
		return_flags.append(is_return)
		hit_sets.append(handles.duplicate())
	)
	var beam := world.spawn(Vector2(480.0, 0.0), Vector2.RIGHT, 80.0, 16.0, 30.0, 0.5, 0.25, true, &"piercing_return")
	world.step_fixed(0.5, query)
	_equal(return_flags, [false, false, true], "Das Phasenende startet genau einen Rücklauf mit eigenem t=0-Tick")
	var return_state := world.resolve(beam)
	_true(return_state != null and return_state.is_return, "Der Strahl bleibt nach der Vorwärtsphase im Rücklauf aktiv")
	_near(return_state.phase_origin(topology).x, -440.0, "Der Rücklauf beginnt am torusgewickelten Vorwärtsendpunkt")
	_near(return_state.phase_direction().x, -1.0, "Der Rücklauf kehrt die Richtung um")
	for handles in hit_sets:
		_true(handles.has(across_seam) and handles.has(near_endpoint), "Vorwärts- und Rücklaufticks verwenden dieselbe torusfähige Geometrie")
	world.step_fixed(0.25, query)
	_equal(return_flags, [false, false, true, true], "Der Rücklauf tickt im selben 0,25-s-Rhythmus")
	world.step_fixed(0.25, query)
	_equal(world.active_count(), 0, "Nach genau einer Rücklaufphase wird der Strahl freigegeben")
	world.step_fixed(1.0, query)
	_equal(return_flags.size(), 4, "Ein abgeschlossener Rücklauf kann nicht erneut beginnen")
	_equal(directions, [Vector2.RIGHT, Vector2.RIGHT, Vector2.LEFT, Vector2.LEFT], "Jedes Tick-Signal meldet seine tatsächliche Phasenrichtung")
	world.clear()


func _test_run_session_pause_contract() -> void:
	var topology := ArenaTopology.new(Rect2(-500.0, -500.0, 1000.0, 1000.0))
	var target := EntityHandle.make(4, 1)
	var query := _query(topology, {target: Vector2(50.0, 0.0)})
	var world := TreatmentBeamWorld.new().configure(1)
	var events := [0]
	world.tick_resolved.connect(func(_handle: int, _handles: PackedInt64Array, _return: bool) -> void: events[0] += 1)
	_spawn(world, Vector2.ZERO, Vector2.RIGHT, false)
	var session := RunSession.new().configure(null, false)
	session.register_callable(func(delta: float) -> void: world.step_fixed(delta, query), RunSession.Phase.COMBAT)
	_true(session.start(), "RunSession startet den registrierten Beam-World-Aufruf")
	_true(session.pause_session(), "RunSession kann vor dem ersten Beam-Tick pausieren")
	_false(session.step_fixed(0.25), "Eine pausierte Session führt keinen Fixed-Step aus")
	_equal(events[0], 0, "Pause friert auch den t=0-Tick vollständig ein")
	_true(session.resume_session(), "Die Session kann fortgesetzt werden")
	_true(session.step_fixed(0.01), "Nach Fortsetzen läuft der Fixed-Step wieder")
	_equal(events[0], 1, "Der aufgeschobene t=0-Tick erscheint erst nach Fortsetzen")
	session.cancel()
	session.free()
	world.clear()


func _spawn(world: TreatmentBeamWorld, origin: Vector2, direction: Vector2, with_return: bool) -> int:
	return world.spawn(origin, direction, 120.0, 20.0, 10.0, 0.5, 0.25, with_return, &"test_beam")


func _query(topology: ArenaTopology, positions: Dictionary) -> CombatQuery:
	var handles := PackedInt64Array()
	for handle in positions:
		handles.append(int(handle))
	var query := CombatQuery.new().configure(
		topology,
		func(handle: int) -> Vector2: return positions.get(handle, Vector2.ZERO),
		func(_handle: int) -> float: return 0.0,
		func(handle: int) -> bool: return positions.has(handle),
		func(handle: int) -> Variant: return positions.get(handle),
		64.0,
		0.0
	)
	query.rebuild(handles)
	return query


func _true(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)


func _false(value: bool, message: String) -> void:
	_true(not value, message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual != expected:
		failures.append("%s (erwartet %s, erhalten %s)" % [message, str(expected), str(actual)])


func _near(actual: float, expected: float, message: String) -> void:
	assertions += 1
	if not is_equal_approx(actual, expected):
		failures.append("%s (erwartet %s, erhalten %s)" % [message, str(expected), str(actual)])


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_TREATMENT_BEAM_WORLD_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	push_error("ALVEOLUS_TREATMENT_BEAM_WORLD_FAILED failures=%d assertions=%d" % [failures.size(), assertions])
	quit(1)
