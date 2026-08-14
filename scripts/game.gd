extends Node2D

signal stability_changed(current: float, maximum: float)
signal analysis_changed(current: int, target: int, level: int)
signal level_up_requested(level: int)
signal run_finished(success: bool, reason: String)
signal flow_changed(state: GameFlowState.State)

const MAX_ACTIVE_PICKUPS := 360
const MAX_ENEMY_POOL := 640
const MAX_PROJECTILE_POOL := 96
const MAX_PICKUP_POOL := MAX_ACTIVE_PICKUPS
const MAX_DAMAGE_NUMBER_POOL := 40

var levels: Array[LevelDefinition]
var selected_level: LevelDefinition
var config: RunConfig
var state: RunState
var stats: PlayerStats
var rng := RandomNumberGenerator.new()
var enemy_definitions: Dictionary
var clinic_definitions: Dictionary
var research_definitions: Array[ResearchDefinition]
var discovery_definitions: Dictionary
var arena_visuals: Dictionary
var discovery_manager: DiscoveryManager

var topology: ArenaTopology
var simulation_root: Node2D
var arena: ArenaBackdrop
var crowd_renderer: CrowdRenderer
var avatar: TherapyAvatar
var hud: GameHUD
var meta: MetaProgressionState
var save_repository: MetaSaveRepository
var flow_state: GameFlowState.State = GameFlowState.State.CAMPUS
var settings_return_state: GameFlowState.State = GameFlowState.State.CAMPUS
var story_return_state: GameFlowState.State = GameFlowState.State.CAMPUS
var discovery_return_state: GameFlowState.State = GameFlowState.State.RUNNING
var intro_skip_return_state: GameFlowState.State = GameFlowState.State.BRIEFING

var enemies: Array[InfectionEnemy] = []
var projectiles: Array[TherapyProjectile] = []
var pickups: Array[AnalysisPickup] = []
var damage_numbers: Array[DamageNumber] = []
var enemy_pool: Array[InfectionEnemy] = []
var projectile_pool: Array[TherapyProjectile] = []
var pickup_pool: Array[AnalysisPickup] = []
var damage_number_pool: Array[DamageNumber] = []
var current_upgrade_options: Array[UpgradeDefinition] = []
var active_boss: InfectionEnemy

var spawn_accumulator: float = 0.0
var therapy_timer: float = 0.0
var immune_timer: float = 0.0
var support_timer: float = 0.0
var pressure_grace_timer: float = 0.0
var pickup_merge_cursor: int = 0
var meta_refresh_timer: float = 0.0
var defeats: int = 0
var reroll_available: bool = false
var reroll_used: bool = false
var intro_lesson: int = 0
var intro_phase: StringName = &""
var intro_start_position: Vector2 = Vector2.ZERO
var intro_primary_enemy: InfectionEnemy
var intro_upgrade_id: StringName = &""
var discovery_spawn_reservations: Dictionary = {}

var quick_run: bool = false
var stress_test: bool = false
var stress_reported: bool = false
var stress_hud_timer: float = 0.0
var completion_smoke: bool = false
var pause_smoke: bool = false
var persistence_enabled: bool = true
var pause_smoke_phase: int = 0
var pause_smoke_timer: float = 0.0
var pause_smoke_enemy_position: Vector2
var pause_smoke_elapsed: float = 0.0
var pause_smoke_therapy_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input_actions()
	var arguments := OS.get_cmdline_user_args()
	completion_smoke = arguments.has("--completion-smoke")
	stress_test = arguments.has("--stress-test")
	pause_smoke = arguments.has("--pause-smoke")
	quick_run = arguments.has("--quick-run") or completion_smoke or pause_smoke
	persistence_enabled = not quick_run and not stress_test

	levels = ContentCatalog.level_definitions()
	selected_level = levels[0]
	if completion_smoke or pause_smoke or stress_test:
		selected_level = levels[1]
	config = ContentCatalog.create_run_config(selected_level, quick_run)
	enemy_definitions = ContentCatalog.enemy_definitions()
	clinic_definitions = ContentCatalog.clinic_job_definitions()
	research_definitions = ContentCatalog.research_definitions()
	discovery_definitions = ContentCatalog.discovery_definitions()
	arena_visuals = ContentCatalog.arena_visual_definitions()
	rng.seed = config.random_seed
	topology = ArenaTopology.new(config.arena_rect())

	simulation_root = Node2D.new()
	simulation_root.name = "Simulation"
	simulation_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(simulation_root)
	arena = ArenaBackdrop.new()
	arena.configure(config.arena_rect(), arena_visuals[selected_level.id])
	simulation_root.add_child(arena)
	crowd_renderer = CrowdRenderer.new()
	crowd_renderer.configure(MAX_ENEMY_POOL, MAX_ACTIVE_PICKUPS)
	simulation_root.add_child(crowd_renderer)
	stats = PlayerStats.new()
	avatar = TherapyAvatar.new()
	avatar.configure(config.arena_rect(), stats, topology)
	avatar.position = Vector2.ZERO
	avatar.z_index = 5
	simulation_root.add_child(avatar)

	hud = GameHUD.new()
	add_child(hud)
	hud.navigate_requested.connect(_on_navigate_requested)
	hud.back_requested.connect(_on_back_requested)
	hud.quit_requested.connect(_on_quit_requested)
	hud.story_finished.connect(_on_story_finished)
	hud.level_selected.connect(_on_level_selected)
	hud.briefing_start_requested.connect(start_run)
	hud.upgrade_chosen.connect(_on_upgrade_chosen)
	hud.reroll_requested.connect(_on_reroll_requested)
	hud.resume_requested.connect(_resume_manual_pause)
	hud.pause_levels_requested.connect(_on_pause_levels_requested)
	hud.abort_requested.connect(_on_abort_requested)
	hud.abort_confirmed.connect(_on_abort_confirmed)
	hud.abort_cancelled.connect(_on_abort_cancelled)
	hud.retry_requested.connect(start_run)
	hud.result_levels_requested.connect(_show_level_select)
	hud.result_campus_requested.connect(_show_campus)
	hud.offline_claim_requested.connect(_on_offline_claim_requested)
	hud.clinic_job_start_requested.connect(_on_clinic_job_start_requested)
	hud.clinic_job_claim_requested.connect(_on_clinic_job_claim_requested)
	hud.research_purchase_requested.connect(_on_research_purchase_requested)
	hud.discovery_dismissed.connect(_on_discovery_dismissed)
	hud.intro_skip_requested.connect(_on_intro_skip_requested)
	hud.intro_skip_confirmed.connect(_on_intro_skip_confirmed)
	hud.intro_skip_cancelled.connect(_on_intro_skip_cancelled)

	meta = MetaProgressionState.new()
	save_repository = MetaSaveRepository.new()
	if persistence_enabled:
		save_repository.load_into(meta)
	else:
		meta.reset_defaults()
	_sanitize_meta()
	discovery_manager = DiscoveryManager.new()
	discovery_manager.configure(discovery_definitions, meta.seen_discovery_ids)
	discovery_manager.seen_changed.connect(_on_discovery_seen)
	if completion_smoke or pause_smoke or stress_test:
		for discovery_id in discovery_definitions:
			discovery_manager.mark_seen(discovery_id)
	meta.accrue_time()
	if arguments.has("--auto-start"):
		call_deferred("start_run")
	elif not meta.prologue_seen:
		story_return_state = GameFlowState.State.CAMPUS
		_set_flow(GameFlowState.State.STORY)
		hud.show_story()
	else:
		_show_campus()

func _process(delta: float) -> void:
	meta_refresh_timer -= delta
	if meta_refresh_timer <= 0.0:
		meta_refresh_timer = 1.0
		meta.accrue_time()
		if flow_state == GameFlowState.State.PRACTICE:
			hud.refresh_practice(meta, clinic_definitions)
		elif flow_state == GameFlowState.State.RESEARCH:
			hud.refresh_research(meta, research_definitions)
		elif flow_state == GameFlowState.State.CAMPUS:
			hud.refresh_campus(meta, clinic_definitions)
	if pause_smoke:
		_pause_smoke_step(delta)
	if flow_state != GameFlowState.State.RUNNING or state == null or not state.active:
		return
	state.tick(delta)
	if not state.active:
		return
	if selected_level.is_tutorial:
		_intro_step()
		hud.update_intro_timer(intro_lesson, intro_phase, state.boss_spawned)
	else:
		hud.update_timer(state.elapsed, config.run_duration_seconds, config.final_deadline_seconds, state.boss_spawned)
	pressure_grace_timer = maxf(0.0, pressure_grace_timer - delta)
	_spawn_step(delta)
	_therapy_step(delta)
	_immune_step(delta)
	_support_step(delta)
	crowd_renderer.sync(enemies, pickups)
	if stress_test and not stress_reported and state.elapsed >= 2.0:
		stress_reported = true
		print("STRESS_CHECK enemies=%d pickups=%d feedback=%d enemy_pool=%d projectile_pool=%d objects=%d process_ms=%.3f physics_ms=%.3f" % [
			enemies.size(), pickups.size(), damage_numbers.size(), enemy_pool.size(), projectile_pool.size(),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		])
	if stress_test:
		stress_hud_timer -= delta
		if stress_hud_timer <= 0.0:
			stress_hud_timer = 1.0
			hud.show_alert("STRESSTEST · %d GEGNER · %d ANALYSE · %d FPS" % [enemies.size(), pickups.size(), Engine.get_frames_per_second()], Color("58dacb"), 1.2)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_meta()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause_game"):
		match flow_state:
			GameFlowState.State.RUNNING:
				if state != null and state.active:
					get_viewport().set_input_as_handled()
					_set_flow(GameFlowState.State.MANUAL_PAUSE)
				hud.show_pause(selected_level != null and selected_level.is_tutorial)
			GameFlowState.State.DISCOVERY_PAUSE:
				get_viewport().set_input_as_handled()
				_on_discovery_dismissed()
			GameFlowState.State.MANUAL_PAUSE:
				get_viewport().set_input_as_handled()
				_resume_manual_pause()
			GameFlowState.State.LEVEL_UP:
				get_viewport().set_input_as_handled()
			GameFlowState.State.ABORT_CONFIRMATION:
				get_viewport().set_input_as_handled()
				_on_abort_cancelled()
			GameFlowState.State.INTRO_SKIP_CONFIRMATION:
				get_viewport().set_input_as_handled()
				_on_intro_skip_cancelled()
			GameFlowState.State.PRACTICE, GameFlowState.State.RESEARCH, GameFlowState.State.LEVEL_SELECT, GameFlowState.State.LEXICON, GameFlowState.State.SETTINGS, GameFlowState.State.BRIEFING, GameFlowState.State.STORY, GameFlowState.State.CAMPUS:
				get_viewport().set_input_as_handled()
				_on_back_requested()
		return
	if flow_state == GameFlowState.State.DISCOVERY_PAUSE and event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_on_discovery_dismissed()
		get_viewport().set_input_as_handled()
		return
	if flow_state != GameFlowState.State.LEVEL_UP:
		return
	if event.is_action_pressed(&"upgrade_1"):
		hud.activate_upgrade(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"upgrade_2"):
		hud.activate_upgrade(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"upgrade_3"):
		hud.activate_upgrade(2)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"reroll_upgrades") and reroll_available and not reroll_used:
		_on_reroll_requested()
		get_viewport().set_input_as_handled()

func _set_flow(next_state: GameFlowState.State) -> void:
	flow_state = next_state
	get_tree().paused = GameFlowState.pauses_simulation(next_state)
	flow_changed.emit(next_state)

func _show_campus() -> void:
	_cleanup_run_nodes()
	avatar.input_enabled = false
	avatar.hide()
	meta.accrue_time()
	_save_meta()
	_set_flow(GameFlowState.State.CAMPUS)
	hud.show_campus(meta, clinic_definitions)

func _show_practice() -> void:
	_set_flow(GameFlowState.State.PRACTICE)
	hud.show_practice(meta, clinic_definitions)

func _show_research() -> void:
	_set_flow(GameFlowState.State.RESEARCH)
	hud.show_research(meta, research_definitions)

func _show_level_select() -> void:
	_cleanup_run_nodes()
	avatar.input_enabled = false
	avatar.hide()
	_set_flow(GameFlowState.State.LEVEL_SELECT)
	hud.show_level_select(meta, levels)

func _show_lexicon() -> void:
	_cleanup_run_nodes()
	avatar.input_enabled = false
	avatar.hide()
	_set_flow(GameFlowState.State.LEXICON)
	hud.show_lexicon(meta)

func _show_settings(return_state: GameFlowState.State) -> void:
	settings_return_state = return_state
	_set_flow(GameFlowState.State.SETTINGS)
	hud.show_settings(not OS.has_feature("web"), return_state != GameFlowState.State.MANUAL_PAUSE)

func _on_navigate_requested(destination: StringName) -> void:
	match destination:
		&"practice":
			_show_practice()
		&"research":
			_show_research()
		&"levels":
			_show_level_select()
		&"lexicon":
			_show_lexicon()
		&"settings":
			_show_settings(flow_state)
		&"story":
			story_return_state = flow_state
			_set_flow(GameFlowState.State.STORY)
			hud.show_story()

func _on_back_requested() -> void:
	match flow_state:
		GameFlowState.State.CAMPUS:
			return
		GameFlowState.State.PRACTICE, GameFlowState.State.RESEARCH, GameFlowState.State.LEVEL_SELECT, GameFlowState.State.LEXICON:
			_show_campus()
		GameFlowState.State.BRIEFING:
			_show_level_select()
		GameFlowState.State.STORY:
			_return_from_story()
		GameFlowState.State.SETTINGS:
			_return_from_settings()

func _return_from_settings() -> void:
	match settings_return_state:
		GameFlowState.State.MANUAL_PAUSE:
			_set_flow(GameFlowState.State.MANUAL_PAUSE)
			hud.show_running_hud()
			hud.show_pause(selected_level != null and selected_level.is_tutorial)
		GameFlowState.State.CAMPUS:
			_show_campus()
		_:
			_show_campus()

func _on_story_finished() -> void:
	meta.mark_prologue_seen()
	_save_meta()
	_return_from_story()

func _return_from_story() -> void:
	if story_return_state == GameFlowState.State.LEVEL_SELECT:
		_show_level_select()
	else:
		_show_campus()

func _on_level_selected(id: StringName) -> void:
	for definition in levels:
		if definition.id == id and meta.is_level_unlocked(definition.order):
			selected_level = definition
			_set_flow(GameFlowState.State.BRIEFING)
			hud.show_briefing(definition)
			return

func _on_quit_requested() -> void:
	_save_meta()
	get_tree().quit()

func start_run() -> void:
	_cleanup_run_nodes()
	config = ContentCatalog.create_run_config(selected_level, quick_run)
	topology.bounds = config.arena_rect()
	arena.configure(config.arena_rect(), arena_visuals[selected_level.id])
	stats = PlayerStats.new()
	if not selected_level.is_tutorial:
		stats.apply_meta_progression(meta.research_ranks)
	if completion_smoke:
		stats.therapy_damage = 250.0
		stats.therapy_cooldown = 0.28
		stats.therapy_range = 1200.0
		stats.therapy_targets = 12
		stats.immune_level = 2
		stats.immune_damage = 30.0
		stats.support_level = 1
	avatar.configure(config.arena_rect(), stats, topology)
	avatar.global_position = Vector2.ZERO
	avatar.reset_physics_interpolation()
	avatar.input_enabled = true
	avatar.show()
	avatar.queue_redraw()
	rng.seed = config.random_seed + Time.get_ticks_msec()
	spawn_accumulator = config.initial_spawn_interval
	therapy_timer = 0.18
	immune_timer = 0.75
	support_timer = 6.0
	pressure_grace_timer = 0.0
	pickup_merge_cursor = 0
	defeats = 0
	stress_reported = false
	stress_hud_timer = 0.0
	reroll_available = meta.has_research(&"second_opinion")
	reroll_used = false
	current_upgrade_options.clear()
	active_boss = null
	intro_lesson = 1 if selected_level.is_tutorial else 0
	intro_phase = &"await_movement" if selected_level.is_tutorial else &""
	intro_start_position = avatar.global_position
	intro_primary_enemy = null
	intro_upgrade_id = &""
	discovery_spawn_reservations.clear()
	discovery_manager.clear_pending()

	state = RunState.new()
	state.stability_changed.connect(_on_stability_changed)
	state.analysis_changed.connect(_on_analysis_changed)
	state.level_up_requested.connect(_on_level_up_requested)
	state.boss_due.connect(_spawn_boss)
	state.run_finished.connect(_on_run_finished)
	var starting_analysis := 2 if meta.has_research(&"preanalysis") and not selected_level.is_tutorial else 0
	state.reset(config, starting_analysis, stats.max_stability_bonus)

	hud.show_running_hud()
	_set_flow(GameFlowState.State.RUNNING)
	if selected_level.is_tutorial:
		hud.update_intro_timer(1, intro_phase, false)
		if not meta.tutorial_status.has(&"movement"):
			hud.show_alert("Bewege dich mit WASD oder den Pfeiltasten", Color("f2bd68"), 3.2)
	else:
		hud.update_timer(0.0, config.run_duration_seconds, config.final_deadline_seconds, false)
		for index in range(3):
			_spawn_enemy(&"pneumococcus", _spawn_position_around_avatar(470.0 + index * 34.0))
		if discovery_manager.request(&"patient_stability", null):
			_try_present_next_discovery()
	if stress_test:
		for index in range(600):
			var angle := TAU * float(index) / 600.0
			var ring := 360.0 + float(index % 10) * 52.0
			_spawn_enemy(&"pneumococcus", topology.wrap_position(Vector2.from_angle(angle) * ring))
		for index in range(1200):
			var angle := TAU * float(index) / 1200.0
			var ring := 510.0 + float(index % 8) * 61.0
			_spawn_analysis_pickup(1, topology.wrap_position(Vector2.from_angle(angle) * ring))

func _spawn_step(delta: float) -> void:
	if selected_level.is_tutorial:
		return
	if state.boss_spawned or enemies.size() >= 220:
		return
	spawn_accumulator -= delta
	if spawn_accumulator > 0.0:
		return
	var progress := clampf(state.elapsed / config.run_duration_seconds, 0.0, 1.0)
	var interval := lerpf(config.initial_spawn_interval, config.final_spawn_interval, pow(progress, 0.82))
	spawn_accumulator += interval
	var batch := 1
	if progress > 0.58 and rng.randf() < 0.22:
		batch = 2
	for index in range(batch):
		var type: StringName = &"pneumococcus"
		var cluster_chance := lerpf(config.cluster_chance_start, config.cluster_chance_end, progress)
		if discovery_manager.has_seen(&"pneumococcus") and rng.randf() < cluster_chance:
			type = &"bacterial_cluster"
		_spawn_enemy(type, _spawn_position_around_avatar(rng.randf_range(500.0, 620.0)))

func _therapy_step(delta: float) -> void:
	if selected_level.is_tutorial and intro_phase == &"await_immune_defeat":
		return
	therapy_timer -= delta
	if therapy_timer > 0.0:
		return
	therapy_timer += stats.therapy_cooldown
	var targets := _nearest_targets(stats.therapy_range, stats.therapy_targets)
	for enemy in targets:
		var projectile: TherapyProjectile
		if not projectile_pool.is_empty():
			projectile = projectile_pool.pop_back()
		else:
			projectile = TherapyProjectile.new()
			projectile.z_index = 6
			projectile.finished.connect(_on_projectile_finished)
			projectile.discovery_ready.connect(_on_projectile_discovery_ready)
			simulation_root.add_child(projectile)
		projectile.global_position = avatar.global_position
		projectile.configure(enemy, stats.therapy_damage, topology, not discovery_manager.has_seen(&"automatic_therapy"))
		projectile.global_position = avatar.global_position
		projectile.reset_physics_interpolation()
		projectiles.append(projectile)

func _on_projectile_discovery_ready(projectile: TherapyProjectile) -> void:
	if discovery_manager.request(&"automatic_therapy", projectile):
		_try_present_next_discovery()

func _immune_step(delta: float) -> void:
	if stats.immune_level <= 0:
		return
	immune_timer -= delta
	if immune_timer > 0.0:
		return
	immune_timer += maxf(0.42, 0.82 - stats.immune_level * 0.06)
	var radius := avatar.neutrophil_radius()
	var damage := stats.immune_damage + float(stats.immune_level - 1) * 3.0
	for enemy in enemies:
		var immune_radius := radius + enemy.definition.radius if is_instance_valid(enemy) else 0.0
		if is_instance_valid(enemy) and enemy.is_targetable() and topology.distance_squared(avatar.global_position, enemy.global_position) <= immune_radius * immune_radius:
			enemy.take_damage(damage, &"immune")

func _support_step(delta: float) -> void:
	if stats.support_level <= 0:
		return
	support_timer -= delta
	if support_timer > 0.0:
		return
	support_timer += maxf(3.8, 6.2 - float(stats.support_level) * 0.55)
	var recovery := 2.0 + float(stats.support_level) * 2.0
	state.change_stability(recovery)
	if selected_level.is_tutorial and intro_phase == &"await_support_tick":
		intro_phase = &"boss_pending"
		meta.set_tutorial_step(&"supportive_therapy")
		discovery_manager.mark_seen(&"patient_stability")
		state.trigger_event_boss()

func _intro_step() -> void:
	if not selected_level.is_tutorial or state == null or not state.active:
		return
	if intro_phase == &"await_movement" and topology.distance(intro_start_position, avatar.global_position) >= 32.0:
		meta.set_tutorial_step(&"movement")
		intro_phase = &"await_enemy"
		intro_primary_enemy = _spawn_enemy(&"pneumococcus", _spawn_position_around_avatar(390.0), 0.55)

func _spawn_enemy(type: StringName, spawn_position: Vector2, health_scale_override: float = -1.0) -> InfectionEnemy:
	if not enemy_definitions.has(type):
		return null
	var definition: EnemyDefinition = enemy_definitions[type]
	var progress := 0.0 if state == null or config.event_driven_intro else clampf(state.elapsed / maxf(config.run_duration_seconds, 0.001), 0.0, 1.0)
	var health_scale := lerpf(config.enemy_health_start, config.enemy_health_end, progress)
	var phases := PackedInt32Array()
	if definition.is_boss:
		health_scale = config.boss_health_multiplier
		phases = config.boss_phase_minions
	if health_scale_override > 0.0:
		health_scale = health_scale_override
	var resolved_spawn_position := spawn_position
	if discovery_manager != null and not discovery_manager.has_seen(definition.discovery_id) and not discovery_spawn_reservations.has(definition.discovery_id):
		resolved_spawn_position = _visible_discovery_spawn_position(definition.radius)
		discovery_spawn_reservations[definition.discovery_id] = true
	var wrapped_position := topology.wrap_position(resolved_spawn_position)
	var enemy: InfectionEnemy
	if not enemy_pool.is_empty():
		enemy = enemy_pool.pop_back()
	else:
		enemy = InfectionEnemy.new()
		enemy.z_index = 2
		enemy.defeated.connect(_on_enemy_defeated)
		enemy.pressure_applied.connect(_on_pressure_applied)
		enemy.minions_requested.connect(_on_minions_requested)
		enemy.damage_feedback.connect(_on_enemy_damage_feedback)
		enemy.health_changed.connect(_on_enemy_health_changed.bind(enemy))
		enemy.boss_phase_changed.connect(_on_boss_phase_changed)
		enemy.materialized.connect(_on_enemy_materialized)
		enemy.damage_applied.connect(_on_enemy_damage_applied)
		simulation_root.add_child(enemy)
	enemy.global_position = wrapped_position
	enemy.configure(definition, avatar, topology, health_scale, config.enemy_speed_multiplier, config.contact_damage_multiplier, phases)
	enemy.global_position = wrapped_position
	enemy.reset_physics_interpolation()
	enemies.append(enemy)
	return enemy

func _spawn_boss() -> void:
	if state == null or not state.active:
		return
	active_boss = _spawn_enemy(&"infection_focus", _spawn_position_around_avatar(600.0))
	if active_boss != null:
		hud.show_boss(active_boss.max_health, config.boss_phase_minions.size())
	if selected_level.is_tutorial:
		intro_phase = &"boss_active"
		intro_lesson = 3

func _on_minions_requested(origin: Vector2, count: int) -> void:
	if state == null or not state.active:
		return
	for index in range(count):
		var angle := TAU * float(index) / float(maxi(count, 1)) + rng.randf_range(-0.22, 0.22)
		var position := topology.wrap_position(origin + Vector2.from_angle(angle) * rng.randf_range(88.0, 130.0))
		_spawn_enemy(&"pneumococcus", position)

func _on_boss_phase_changed(phase: int) -> void:
	hud.show_boss_phase(phase)
	if discovery_manager.request(&"boss_phases", active_boss):
		_try_present_next_discovery()

func _on_enemy_materialized(enemy: InfectionEnemy) -> void:
	if not is_instance_valid(enemy) or enemy.definition == null:
		return
	if selected_level.is_tutorial and enemy.definition.id == &"pneumococcus" and intro_phase == &"await_enemy":
		intro_phase = &"enemy_discovery"
	var requested := discovery_manager.request(enemy.definition.discovery_id, enemy, {"tutorial_boss": selected_level.is_tutorial and enemy.definition.is_boss})
	if requested:
		_try_present_next_discovery()
	elif selected_level.is_tutorial and enemy.definition.id == &"pneumococcus" and intro_phase == &"enemy_discovery":
		intro_phase = &"await_first_shot"

func _on_enemy_damage_applied(enemy: InfectionEnemy, _amount: float, source: StringName) -> void:
	if not selected_level.is_tutorial or source != &"therapy":
		return
	if intro_phase == &"await_first_shot":
		intro_phase = &"await_first_analysis"
		meta.set_tutorial_step(&"automatic_therapy")
	elif intro_phase == &"await_potency_hit":
		intro_phase = &"potency_complete"
		meta.set_tutorial_step(&"antibiotic_therapy")
		_present_intro_upgrade(&"neutrophils", 2, enemy)

func _try_present_next_discovery() -> void:
	if discovery_manager == null or not discovery_manager.active.is_empty():
		return
	if flow_state not in [GameFlowState.State.RUNNING, GameFlowState.State.RESULT, GameFlowState.State.DISCOVERY_PAUSE]:
		return
	var item := discovery_manager.take_next()
	if item.is_empty():
		return
	if flow_state != GameFlowState.State.DISCOVERY_PAUSE:
		discovery_return_state = flow_state
	_set_flow(GameFlowState.State.DISCOVERY_PAUSE)
	var definition := discovery_manager.definition(item["id"])
	var override := ""
	var context: Dictionary = item.get("context", {})
	if definition.id == &"infection_focus" and bool(context.get("tutorial_boss", false)):
		override = "Mini-Boss · vereinfachte Variante ohne Phasenschübe."
	hud.show_discovery(definition, item.get("target"), override)

func _on_discovery_dismissed() -> void:
	if flow_state != GameFlowState.State.DISCOVERY_PAUSE or discovery_manager.active.is_empty():
		return
	var completed_id := discovery_manager.complete_active()
	hud.hide_discovery()
	if selected_level != null and selected_level.is_tutorial and completed_id == &"pneumococcus" and intro_phase == &"enemy_discovery":
		intro_phase = &"await_first_shot"
	_save_meta()
	if not discovery_manager.queue.is_empty():
		_try_present_next_discovery()
		return
	_set_flow(discovery_return_state)
	if discovery_return_state == GameFlowState.State.RESULT:
		return

func _on_discovery_seen(_id: StringName) -> void:
	_save_meta()

func _on_enemy_health_changed(current: float, maximum: float, enemy: InfectionEnemy) -> void:
	if enemy == active_boss:
		hud.update_boss_health(current, maximum)

func _on_enemy_damage_feedback(position: Vector2, amount: float) -> void:
	while damage_numbers.size() >= 40:
		var oldest: DamageNumber = damage_numbers.pop_front()
		if is_instance_valid(oldest):
			_store_damage_number(oldest)
	var number: DamageNumber
	if not damage_number_pool.is_empty():
		number = damage_number_pool.pop_back()
	else:
		number = DamageNumber.new()
		number.z_index = 7
		number.finished.connect(_on_damage_number_finished)
		simulation_root.add_child(number)
	number.position = position + Vector2(rng.randf_range(-8.0, 8.0), -18.0)
	number.configure(amount)
	number.global_position = position + Vector2(rng.randf_range(-8.0, 8.0), -18.0)
	damage_numbers.append(number)

func _on_damage_number_finished(number: DamageNumber) -> void:
	damage_numbers.erase(number)
	_store_damage_number(number)

func _store_damage_number(number: DamageNumber) -> void:
	number.recycle()
	if damage_number_pool.size() < MAX_DAMAGE_NUMBER_POOL:
		if not damage_number_pool.has(number):
			damage_number_pool.append(number)
	else:
		number.queue_free()

func _on_enemy_defeated(enemy: InfectionEnemy, analysis_value: int, was_boss: bool) -> void:
	enemies.erase(enemy)
	defeats += 1
	var guided_intro_pickup := selected_level.is_tutorial and intro_phase == &"await_first_analysis" and enemy.definition.id == &"pneumococcus"
	var pickup_position := topology.wrap_position(avatar.global_position + Vector2(92.0, -48.0)) if guided_intro_pickup else enemy.global_position
	_spawn_analysis_pickup(analysis_value, pickup_position, guided_intro_pickup)
	if selected_level.is_tutorial and intro_phase == &"await_immune_defeat" and enemy.last_damage_source == &"immune":
		intro_lesson = 3
		intro_phase = &"support_setup"
		state.change_stability(-minf(16.0, maxf(0.0, state.stability - 1.0)))
		hud.show_patient_hit()
		_present_intro_upgrade(&"oxygenation", 3, null)
	if was_boss:
		active_boss = null
		state.mark_boss_defeated()
	_store_enemy(enemy)

func _store_enemy(enemy: InfectionEnemy) -> void:
	enemy.recycle()
	if enemy_pool.size() < MAX_ENEMY_POOL:
		if not enemy_pool.has(enemy):
			enemy_pool.append(enemy)
	else:
		enemy.queue_free()

func _spawn_analysis_pickup(value: int, spawn_position: Vector2, guided: bool = false) -> AnalysisPickup:
	if not guided and pickups.size() >= MAX_ACTIVE_PICKUPS:
		for _attempt in range(pickups.size()):
			pickup_merge_cursor = posmod(pickup_merge_cursor, pickups.size())
			var existing: AnalysisPickup = pickups[pickup_merge_cursor]
			pickup_merge_cursor += 1
			if is_instance_valid(existing) and not existing.is_queued_for_deletion():
				existing.absorb(value)
				return existing
	var pickup: AnalysisPickup
	if not pickup_pool.is_empty():
		pickup = pickup_pool.pop_back()
	else:
		pickup = AnalysisPickup.new()
		pickup.z_index = 1
		simulation_root.add_child(pickup)
		pickup.collected.connect(_on_pickup_collected.bind(pickup))
	pickup.global_position = spawn_position
	pickup.configure(avatar, value, topology, rng.randf_range(0.0, TAU), guided)
	pickup.global_position = spawn_position
	pickup.reset_physics_interpolation()
	pickups.append(pickup)
	if discovery_manager.request(&"analysis_pickup", pickup):
		_try_present_next_discovery()
	return pickup

func _on_pickup_collected(value: int, pickup: AnalysisPickup) -> void:
	pickups.erase(pickup)
	_store_pickup(pickup)
	if selected_level.is_tutorial:
		if state != null:
			state.analysis = mini(state.analysis + value, state.analysis_target - 1)
			state.analysis_changed.emit(state.analysis, state.analysis_target, state.level)
		if intro_phase == &"await_first_analysis":
			meta.set_tutorial_step(&"analysis")
			var upgrade_target: InfectionEnemy = intro_primary_enemy if is_instance_valid(intro_primary_enemy) else null
			_present_intro_upgrade(&"potency", 1, upgrade_target)
	elif state != null:
		state.add_analysis(value)

func _on_projectile_finished(projectile: TherapyProjectile) -> void:
	projectiles.erase(projectile)
	_store_projectile(projectile)

func _store_projectile(projectile: TherapyProjectile) -> void:
	projectile.recycle()
	if projectile_pool.size() < MAX_PROJECTILE_POOL:
		if not projectile_pool.has(projectile):
			projectile_pool.append(projectile)
	else:
		projectile.queue_free()

func _store_pickup(pickup: AnalysisPickup) -> void:
	pickup.recycle()
	if pickup_pool.size() < MAX_PICKUP_POOL:
		if not pickup_pool.has(pickup):
			pickup_pool.append(pickup)
	else:
		pickup.queue_free()

func _on_pressure_applied(amount: float) -> void:
	if state == null or not state.active or state.level_up_pending or pressure_grace_timer > 0.0:
		return
	if selected_level.is_tutorial and not state.boss_spawned:
		amount = minf(amount, maxf(0.0, state.stability - 1.0))
	state.change_stability(-amount)
	pressure_grace_timer = 0.68
	hud.show_patient_hit()

func _on_stability_changed(current: float, maximum: float) -> void:
	stability_changed.emit(current, maximum)
	hud.update_stability(current, maximum)

func _on_analysis_changed(current: int, target: int, level: int) -> void:
	analysis_changed.emit(current, target, level)
	hud.update_analysis(current, target, level)

func _on_level_up_requested(level: int) -> void:
	if selected_level.is_tutorial:
		state.resolve_level_up()
		return
	level_up_requested.emit(level)
	current_upgrade_options = ContentCatalog.choose_upgrades(stats.upgrade_levels, rng, 3, level == 1)
	if current_upgrade_options.is_empty():
		state.resolve_level_up()
		return
	if completion_smoke:
		var definition: UpgradeDefinition = current_upgrade_options[0]
		stats.apply_upgrade(definition)
		if definition.effect == &"max_stability":
			state.increase_max_stability(definition.magnitude)
		state.resolve_level_up()
		return
	_set_flow(GameFlowState.State.LEVEL_UP)
	hud.show_upgrade_choices(current_upgrade_options, stats, reroll_available and not reroll_used, false)

func _present_intro_upgrade(id: StringName, lesson: int, target_enemy: InfectionEnemy) -> void:
	var definition: UpgradeDefinition
	for candidate in ContentCatalog.upgrade_definitions():
		if candidate.id == id:
			definition = candidate
			break
	if definition == null:
		return
	if id == &"potency" and (target_enemy == null or not is_instance_valid(target_enemy) or target_enemy.is_queued_for_deletion() or not target_enemy.is_targetable()):
		intro_primary_enemy = _spawn_enemy(&"pneumococcus", _spawn_position_around_avatar(330.0), 0.72)
		target_enemy = intro_primary_enemy
	intro_lesson = lesson
	intro_phase = StringName("upgrade_%s" % String(id))
	intro_upgrade_id = id
	current_upgrade_options = [definition]
	var target: Variant = null
	if id == &"potency" and target_enemy != null:
		target = target_enemy
	elif id == &"neutrophils":
		target = avatar
	hud.set_intro_upgrade_target(target)
	_set_flow(GameFlowState.State.LEVEL_UP)
	hud.show_upgrade_choices(current_upgrade_options, stats, false, false)

func _on_reroll_requested() -> void:
	if flow_state != GameFlowState.State.LEVEL_UP or not reroll_available or reroll_used:
		return
	reroll_used = true
	var excluded: Array[StringName] = []
	for definition in current_upgrade_options:
		excluded.append(definition.id)
	current_upgrade_options = ContentCatalog.choose_upgrades(stats.upgrade_levels, rng, 3, state.level == 1, excluded)
	hud.show_upgrade_choices(current_upgrade_options, stats, false, false)

func _on_upgrade_chosen(definition: UpgradeDefinition) -> void:
	if flow_state != GameFlowState.State.LEVEL_UP or state == null or not state.active:
		return
	if not stats.apply_upgrade(definition):
		return
	if definition.effect == &"max_stability":
		state.increase_max_stability(definition.magnitude)
	avatar.queue_redraw()
	hud.show_running_hud()
	if active_boss != null and is_instance_valid(active_boss):
		hud.show_boss(active_boss.max_health, config.boss_phase_minions.size())
		hud.update_boss_health(active_boss.health, active_boss.max_health)
	var scripted_intro := selected_level.is_tutorial and intro_upgrade_id == definition.id
	_set_flow(GameFlowState.State.RUNNING)
	state.resolve_level_up()
	if scripted_intro:
		intro_upgrade_id = &""
		match definition.id:
			&"potency":
				intro_phase = &"await_potency_hit"
				therapy_timer = 0.12
			&"neutrophils":
				intro_phase = &"await_immune_defeat"
				immune_timer = 0.20
				discovery_manager.mark_seen(&"neutrophil_orbit")
				intro_primary_enemy = _spawn_enemy(&"pneumococcus", _spawn_position_around_avatar(104.0), 0.68)
			&"oxygenation":
				intro_phase = &"await_support_tick"
				support_timer = 5.65
				discovery_manager.mark_seen(&"supportive_oxygenation")
		_save_meta()
		return
	if definition.effect == &"immune_level":
		discovery_manager.request(&"neutrophil_orbit", avatar)
	elif definition.effect == &"support_level":
		discovery_manager.request(&"supportive_oxygenation", null)
	_try_present_next_discovery()

func _on_run_finished(success: bool, reason: String) -> void:
	run_finished.emit(success, reason)
	if completion_smoke:
		print("COMPLETION_SMOKE success=%s elapsed=%.2f defeats=%d reason=%s" % [str(success), state.elapsed, defeats, reason])
		get_tree().quit(0 if success else 2)
		return
	avatar.input_enabled = false
	var repeated_intro := selected_level.is_tutorial and meta.has_completed_level(selected_level.id)
	var multiplier := config.reward_multiplier * (0.25 if repeated_intro else 1.0)
	var reward := meta.award_run(success, state.elapsed, state.level, defeats, multiplier)
	var unlocked_new := meta.register_level_result(selected_level, success, state.elapsed, state.level, defeats)
	_save_meta()
	_set_flow(GameFlowState.State.RESULT)
	hud.show_end(selected_level, success, reason, state.elapsed, state.level, defeats, reward, unlocked_new)
	if discovery_manager.request(&"research_reward", null):
		_try_present_next_discovery()

func _resume_manual_pause() -> void:
	if flow_state != GameFlowState.State.MANUAL_PAUSE or state == null or not state.active:
		return
	hud.hide_pause()
	_set_flow(GameFlowState.State.RUNNING)

func _on_pause_levels_requested() -> void:
	if flow_state != GameFlowState.State.MANUAL_PAUSE:
		return
	if state != null:
		state.cancel()
	_cleanup_run_nodes()
	avatar.input_enabled = false
	avatar.hide()
	_show_level_select()

func _on_abort_requested() -> void:
	if flow_state != GameFlowState.State.MANUAL_PAUSE:
		return
	_set_flow(GameFlowState.State.ABORT_CONFIRMATION)
	hud.show_abort_confirmation()

func _on_abort_cancelled() -> void:
	if flow_state != GameFlowState.State.ABORT_CONFIRMATION:
		return
	_set_flow(GameFlowState.State.MANUAL_PAUSE)
	hud.show_running_hud()
	hud.show_pause(selected_level != null and selected_level.is_tutorial)

func _on_abort_confirmed() -> void:
	if flow_state != GameFlowState.State.ABORT_CONFIRMATION:
		return
	if state != null:
		state.cancel()
	_cleanup_run_nodes()
	avatar.input_enabled = false
	avatar.hide()
	_show_level_select()

func _on_intro_skip_requested() -> void:
	if selected_level == null or not selected_level.is_tutorial or flow_state not in [GameFlowState.State.BRIEFING, GameFlowState.State.MANUAL_PAUSE]:
		return
	intro_skip_return_state = flow_state
	_set_flow(GameFlowState.State.INTRO_SKIP_CONFIRMATION)
	hud.show_intro_skip_confirmation()

func _on_intro_skip_cancelled() -> void:
	if flow_state != GameFlowState.State.INTRO_SKIP_CONFIRMATION:
		return
	hud.hide_intro_skip_confirmation()
	if intro_skip_return_state == GameFlowState.State.MANUAL_PAUSE:
		_set_flow(GameFlowState.State.MANUAL_PAUSE)
		hud.show_running_hud()
		hud.show_pause(true)
	else:
		_set_flow(GameFlowState.State.BRIEFING)
		hud.show_briefing(selected_level)

func _on_intro_skip_confirmed() -> void:
	if flow_state != GameFlowState.State.INTRO_SKIP_CONFIRMATION or selected_level == null or not selected_level.is_tutorial:
		return
	if state != null and state.active:
		state.cancel()
	discovery_manager.clear_pending()
	_cleanup_run_nodes()
	avatar.input_enabled = false
	avatar.hide()
	meta.mark_intro_skipped()
	meta.set_tutorial_step(&"intro_skipped")
	_save_meta()
	_show_level_select()

func _on_offline_claim_requested() -> void:
	meta.accrue_time()
	if meta.claim_passive() > 0:
		_save_meta()
	hud.refresh_practice(meta, clinic_definitions)

func _on_clinic_job_start_requested(id: StringName) -> void:
	if clinic_definitions.has(id) and meta.start_job(clinic_definitions[id]):
		_save_meta()
	hud.refresh_practice(meta, clinic_definitions)

func _on_clinic_job_claim_requested() -> void:
	if meta.claim_job(clinic_definitions) > 0:
		_save_meta()
	hud.refresh_practice(meta, clinic_definitions)

func _on_research_purchase_requested(id: StringName) -> void:
	for definition in research_definitions:
		if definition.id == id and meta.purchase(definition):
			_save_meta()
			break
	hud.refresh_research(meta, research_definitions)

func _nearest_targets(max_range: float, count: int) -> Array[InfectionEnemy]:
	var nearest: Array[InfectionEnemy] = []
	var distances: Array[float] = []
	var maximum_squared := max_range * max_range
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.is_targetable():
			var distance_squared := topology.distance_squared(avatar.global_position, enemy.global_position)
			if distance_squared > maximum_squared:
				continue
			var insertion_index := 0
			while insertion_index < distances.size() and distances[insertion_index] <= distance_squared:
				insertion_index += 1
			if insertion_index >= count:
				continue
			nearest.insert(insertion_index, enemy)
			distances.insert(insertion_index, distance_squared)
			if nearest.size() > count:
				nearest.resize(count)
				distances.resize(count)
	return nearest

func _spawn_position_around_avatar(distance: float) -> Vector2:
	var safe_distance := minf(distance, minf(config.arena_size.x, config.arena_size.y) * 0.5 - 70.0)
	var angle := rng.randf_range(0.0, TAU)
	return topology.wrap_position(avatar.global_position + Vector2.from_angle(angle) * safe_distance)

func _visible_discovery_spawn_position(radius: float) -> Vector2:
	var safe_bounds := config.arena_rect().grow(-(radius + 42.0))
	var horizontal_offset := 310.0
	if avatar.global_position.x + horizontal_offset > safe_bounds.end.x:
		horizontal_offset = -horizontal_offset
	var candidate := avatar.global_position + Vector2(horizontal_offset, -118.0)
	return Vector2(
		clampf(candidate.x, safe_bounds.position.x, safe_bounds.end.x),
		clampf(candidate.y, safe_bounds.position.y, safe_bounds.end.y)
	)

func _cleanup_run_nodes() -> void:
	if discovery_manager != null:
		discovery_manager.clear_pending()
	if hud != null:
		hud.hide_discovery()
	if crowd_renderer != null:
		crowd_renderer.clear()
	for enemy in enemies:
		if is_instance_valid(enemy):
			_store_enemy(enemy)
	for projectile in projectiles:
		if is_instance_valid(projectile):
			_store_projectile(projectile)
	for pickup in pickups:
		if is_instance_valid(pickup):
			_store_pickup(pickup)
	for number in damage_numbers:
		if is_instance_valid(number):
			_store_damage_number(number)
	enemies.clear()
	projectiles.clear()
	pickups.clear()
	damage_numbers.clear()
	current_upgrade_options.clear()
	active_boss = null

func _sanitize_meta() -> void:
	if meta.active_job_id != &"" and not clinic_definitions.has(meta.active_job_id):
		meta.active_job_id = &""
		meta.job_started_at = 0
		meta.job_finishes_at = 0
	for definition in research_definitions:
		var stored_rank := meta.rank(definition.id)
		meta.research_ranks[definition.id] = clampi(stored_rank, 0, definition.max_level)
	meta.highest_unlocked_level = clampi(meta.highest_unlocked_level, 0, levels.size() - 1)

func _save_meta() -> void:
	if not persistence_enabled or meta == null or save_repository == null:
		return
	meta.accrue_time()
	save_repository.save(meta)

func _pause_smoke_step(delta: float) -> void:
	if pause_smoke_phase == 0 and flow_state == GameFlowState.State.RUNNING and state != null and state.elapsed >= 1.0 and not enemies.is_empty():
		pause_smoke_enemy_position = enemies[0].global_position
		pause_smoke_elapsed = state.elapsed
		pause_smoke_therapy_timer = therapy_timer
		pause_smoke_phase = 1
		_set_flow(GameFlowState.State.MANUAL_PAUSE)
		hud.show_pause(selected_level != null and selected_level.is_tutorial)
	elif pause_smoke_phase == 1:
		pause_smoke_timer += delta
		if pause_smoke_timer >= 0.6:
			var enemy_unchanged := is_instance_valid(enemies[0]) and enemies[0].global_position.is_equal_approx(pause_smoke_enemy_position)
			var elapsed_unchanged := is_equal_approx(state.elapsed, pause_smoke_elapsed)
			var timer_unchanged := is_equal_approx(therapy_timer, pause_smoke_therapy_timer)
			var passed := enemy_unchanged and elapsed_unchanged and timer_unchanged
			print("PAUSE_SMOKE success=%s enemy=%s elapsed=%s timer=%s" % [str(passed), str(enemy_unchanged), str(elapsed_unchanged), str(timer_unchanged)])
			get_tree().quit(0 if passed else 3)

func _register_input_actions() -> void:
	_add_keys(&"move_left", [KEY_A, KEY_LEFT])
	_add_keys(&"move_right", [KEY_D, KEY_RIGHT])
	_add_keys(&"move_up", [KEY_W, KEY_UP])
	_add_keys(&"move_down", [KEY_S, KEY_DOWN])
	_add_keys(&"pause_game", [KEY_P, KEY_ESCAPE])
	_add_keys(&"upgrade_1", [KEY_1])
	_add_keys(&"upgrade_2", [KEY_2])
	_add_keys(&"upgrade_3", [KEY_3])
	_add_keys(&"reroll_upgrades", [KEY_R])

func _add_keys(action: StringName, keycodes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keycodes:
		var event := InputEventKey.new()
		event.physical_keycode = int(keycode)
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
