extends Node2D

signal stability_changed(current: float, maximum: float)
signal analysis_changed(current: int, target: int, level: int)
signal level_up_requested(level: int)
signal run_finished(success: bool, reason: String)
signal flow_changed(state: GameFlowState.State)

const MAX_ACTIVE_PICKUPS := 360
const MAX_ENEMY_POOL := 640
const MAX_ACTIVE_PROJECTILES := 512
const MAX_PROJECTILE_POOL := MAX_ACTIVE_PROJECTILES
const MAX_PICKUP_POOL := MAX_ACTIVE_PICKUPS
const MAX_DAMAGE_NUMBER_POOL := 40
const MAX_VISUAL_BURSTS := 80
const STRESS_RUN_SECONDS := 1.0e12
const INTRO_ANALYSIS_TARGET := 3
const INTRO_OBSERVATION_SECONDS := 3.0
const INTRO_FOLLOWUP_ENEMY_COUNT := 2
const INTRO_ROLE_PRIMARY := &"primary"
const INTRO_ROLE_FOLLOWUP := &"followup"
const INTRO_ROLE_BOSS := &"boss"
const INTRO_CONFIRM_ATTACK := &"enable_autoattack"
const INTRO_CONFIRM_BOSS := &"start_boss"
const PRESSURE_GRACE_SECONDS := 0.5
const SPAWN_GOLDEN_ANGLE := 2.399963229728653
const SPAWN_ANGLE_JITTER := 0.18
const WAVE_SPAWN_SECTOR_COUNT := 12
const WAVE_SPAWN_EMPTY_SECTOR_CHOICES := 3
const WAVE_SPAWN_SCREEN_MARGIN := 110.0
const WAVE_PRESSURE_NEAR_MARGIN := 300.0
const WAVE_PRESSURE_NEIGHBOR_SHARE := 0.22
const OFFSCREEN_RELOCATION_INTERVAL := 0.5
const OFFSCREEN_RELOCATION_ENEMIES_PER_BUDGET_STEP := 12
const OFFSCREEN_RELOCATION_MAXIMUM_PER_SNAPSHOT := 18
const OFFSCREEN_RELOCATION_SOURCE_MARGIN := 72.0
const OFFSCREEN_RELOCATION_HIDDEN_MARGIN := 24.0
const OFFSCREEN_RELOCATION_MINIMUM_SECTOR_DISTANCE := 2
const OFFSCREEN_RELOCATION_RANDOM_SECTOR_CHOICES := 6
const OFFSCREEN_RELOCATION_TARGET_SECTOR_ATTEMPTS := 4
const OFFSCREEN_RELOCATION_POINT_ATTEMPTS_PER_SECTOR := 2
const OFFSCREEN_RELOCATION_MAXIMUM_TARGETS_PER_SECTOR := 2
const OFFSCREEN_PLACEMENT_ANGLE_OFFSETS: Array[float] = [0.0, -0.14, 0.14, -0.24, 0.24]
const OFFSCREEN_PLACEMENT_RADIAL_OFFSETS: Array[float] = [0.0, 42.0, 84.0]
const OFFSCREEN_PLACEMENT_BODY_GAP := 4.0
const OFFSCREEN_RELOCATION_RADIAL_JITTER := 18.0
# Temporärer Content-Testmodus. Abschalten, sobald Forschung und Talente
# balanciert werden; der gespeicherte echte Punktestand bleibt unangetastet.
const UNLIMITED_PROGRESSION_TEST_MODE := false

var levels: Array[LevelDefinition]
var selected_level: LevelDefinition
var config: RunConfig
var state: RunState
var stats: PlayerStats
var rng := RandomNumberGenerator.new()
var spawn_rng := RandomNumberGenerator.new()
var relocation_rng := RandomNumberGenerator.new()
var spawn_attempt_index: int = 0
var spawn_angle_cursor: float = 0.0
var enemy_definitions: Dictionary
var clinic_definitions: Dictionary
var research_definitions: Array[ResearchDefinition]
var discovery_definitions: Dictionary
var arena_visuals: Dictionary
var discovery_manager: DiscoveryManager
var loadout_modules: Dictionary
var treatment_definitions: Dictionary
var ability_definitions: Dictionary
var case_traits: Dictionary
var finding_definitions: Dictionary
var reaction_definitions: Dictionary

var topology: ArenaTopology
var simulation_root: Node2D
var arena: ArenaBackdrop
var crowd_renderer: CrowdRenderer
var projectile_renderer: ProjectileRenderer
var hostile_projectile_renderer: ProjectileRenderer
var feedback_renderer: FeedbackRenderer
var ability_feedback_world: AbilityFeedbackWorld
var ability_target_preview: AbilityTargetPreview
var run_session: RunSession
var combat_capacity := CombatCapacity.defaults()
var cosmetic_budget_controller: CosmeticBudgetController
var enemy_world: EnemyWorld
var projectile_world: ProjectileWorld
var pickup_world: PickupWorld
var combat_query: CombatQuery
var pickup_query: CombatQuery
var defense_cell_world: DefenseCellWorld
var treatment_beam_world: TreatmentBeamWorld
var enemy_attack_director: EnemyAttackDirector
var defense_cell_damage_profile: DamageProfile
var avatar: TherapyAvatar
var hud: GameHUD
var ui_sound_service: UISoundService
var input_glyph_service: InputGlyphService
var meta: MetaProgressionState
var save_repository: MetaSaveRepository
var flow_state: GameFlowState.State = GameFlowState.State.CAMPUS
var settings_return_state: GameFlowState.State = GameFlowState.State.CAMPUS
var story_return_state: GameFlowState.State = GameFlowState.State.CAMPUS
var discovery_return_state: GameFlowState.State = GameFlowState.State.RUNNING
var intro_skip_return_state: GameFlowState.State = GameFlowState.State.PREPARATION
var restart_return_state: GameFlowState.State = GameFlowState.State.RUNNING

var enemies: Array[InfectionEnemy] = []
var projectiles: Array[TherapyProjectile] = []
var pickups: Array[AnalysisPickup] = []
var damage_numbers: Array[DamageNumber] = []
var enemy_pool: Array[InfectionEnemy] = []
var projectile_pool: Array[TherapyProjectile] = []
var pickup_pool: Array[AnalysisPickup] = []
var damage_number_pool: Array[DamageNumber] = []
var visual_bursts: Array[VisualBurst] = []
var visual_burst_pool: Array[VisualBurst] = []
var current_upgrade_options: Array[UpgradeDefinition] = []
var active_boss: InfectionEnemy
var active_boss_handles: PackedInt64Array = PackedInt64Array()
var active_boss_handle_by_instance: Dictionary = {}
var active_boss_phase_by_handle: Dictionary = {}
var boss_aggregate_maximum: float = 0.0
var boss_aggregate_phase: int = 0
var enemy_runtime_resistance_profiles: Dictionary = {}
var run_damage_by_source: Dictionary = {}

var pending_run_context: RunContext
var active_run_context: RunContext
var active_loadout: PreparedLoadout
var build_state: RunBuildState
var treatment_controller: TreatmentController
var ability_controller: AbilityController
var finding_controller: FindingController
var mastery_tracker := MasteryTracker.new()
var pending_preparation_loadout: PreparedLoadout
var pending_loadout_draft: LoadoutDraft
var pending_replacement_component: StringName = &""
var ui_router := UIScreenRouter.new()
var active_reaction: ReactionDefinition
var pending_finding_definition: FindingDefinition
var hidden_nest_timers: Dictionary = {}
var pressure_surge_timer: float = 25.0
var pressure_surge_remaining: float = 0.0
var reaction_boost_timer: float = 0.0
var reaction_boost_source: StringName = &""
var last_ability_slot: int = -1
var last_ability_time: float = -1000.0
var emergency_talent_used: bool = false
var targeting_ability_slot: int = -1
var targeting_input_device: AbilityCommand.InputDevice = AbilityCommand.InputDevice.UNKNOWN
var gamepad_target_direction: Vector2 = Vector2.ZERO
var ability_ready_states: Dictionary = {}
var treatment_beam_return_visualized: Dictionary = {}

var spawn_accumulator: float = 0.0
var offscreen_relocation_timer: float = OFFSCREEN_RELOCATION_INTERVAL
var offscreen_relocation_move_timer: float = 0.0
var offscreen_relocation_move_interval: float = OFFSCREEN_RELOCATION_INTERVAL
var offscreen_relocation_pending: int = 0
var offscreen_relocation_last_eligible_count: int = 0
var offscreen_relocation_last_planned_count: int = 0
var therapy_timer: float = 0.0
var immune_timer: float = 0.0
var support_timer: float = 0.0
var life_regeneration_accumulator: float = 0.0
var pressure_grace_timer: float = 0.0
var pickup_merge_cursor: int = 0
var meta_refresh_timer: float = 0.0
var defeats: int = 0
var defeat_reward_survival_bucket: int = -1
var reroll_available: bool = false
var reroll_used: bool = false
var intro_lesson: int = 0
var intro_phase: StringName = &""
var intro_primary_enemy: InfectionEnemy
var intro_observation_remaining: float = 0.0
var intro_autoattack_enabled: bool = false
var intro_confirmation_kind: StringName = &""
var intro_prompt_text: String = ""
var intro_prompt_semantic_mode: StringName = &"normal"
var intro_prompt_requires_left_click: bool = false
var intro_prompt_mouse_hint: String = ""
var intro_enemy_roles: Dictionary = {}
var intro_pickup_roles: Dictionary = {}
var intro_followup_defeats: int = 0
var intro_followup_pickups: int = 0
var discovery_spawn_reservations: Dictionary = {}
var _fixed_step_active: bool = false
var deferred_spawn_requests: Array[EnemySpawnRequest] = []
var deferred_spawn_cursor: int = 0
var performance_profile_enabled: bool = false
var last_phase_timings_ms: Dictionary = {}
var _combat_query_dirty: bool = true
var _combat_query_handles: PackedInt64Array = PackedInt64Array()
var _offscreen_clearance_candidates: PackedInt64Array = PackedInt64Array()
var _offscreen_ranked_sectors: PackedInt32Array = PackedInt32Array()
var _offscreen_opposite_sectors: PackedInt32Array = PackedInt32Array()
var _offscreen_relocation_candidate_handles: PackedInt64Array = PackedInt64Array()
var _offscreen_relocation_candidate_sectors: PackedInt32Array = PackedInt32Array()
var _offscreen_relocation_candidate_depths: PackedFloat32Array = PackedFloat32Array()
var _offscreen_relocation_source_backlog: PackedFloat32Array = PackedFloat32Array()
var _offscreen_relocation_target_pressure: PackedFloat32Array = PackedFloat32Array()
var _offscreen_relocation_target_reservations: PackedInt32Array = PackedInt32Array()
var _offscreen_relocation_sector_candidate_handles: PackedInt64Array = PackedInt64Array()
var _offscreen_relocation_sector_candidate_depths: PackedFloat32Array = PackedFloat32Array()
var _offscreen_selected_target_sector: int = -1
var _offscreen_relocation_candidate_cursor: int = 0
var _pickup_query_dirty: bool = true
var _pickup_query_handles: PackedInt64Array = PackedInt64Array()

var quick_run: bool = false
var stress_test: bool = false
var stress_reported: bool = false
var stress_hud_timer: float = 0.0
var stress_telemetry: RenderStressTelemetry
var stress_warmup_seconds: float = RenderStressTelemetry.DEFAULT_WARMUP_SECONDS
var stress_measurement_seconds: float = RenderStressTelemetry.DEFAULT_MEASUREMENT_SECONDS
var _web_test_options: Dictionary = {}
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
	ui_router.focus_requested.connect(_on_route_focus_requested)
	_register_input_actions()
	var arguments := OS.get_cmdline_user_args()
	_web_test_options = _read_web_test_options()
	completion_smoke = arguments.has("--completion-smoke")
	stress_test = arguments.has("--stress-test") or bool(_web_test_options.get("stress", false))
	stress_warmup_seconds = _stress_number_option(arguments, "--stress-warmup=", "warmup", RenderStressTelemetry.DEFAULT_WARMUP_SECONDS)
	stress_measurement_seconds = _stress_number_option(arguments, "--stress-duration=", "duration", RenderStressTelemetry.DEFAULT_MEASUREMENT_SECONDS)
	pause_smoke = arguments.has("--pause-smoke")
	quick_run = arguments.has("--quick-run") or completion_smoke or pause_smoke
	persistence_enabled = not quick_run and not stress_test
	# The explicit native stress run measures actual render headroom. With VSync
	# enabled, frame deltas describe the monitor cadence (and its scheduling
	# jitter) instead of the game's cost. Browser rAF remains untouched.
	if stress_test and not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

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
	loadout_modules = ContentCatalog.loadout_module_definitions()
	treatment_definitions = TreatmentDefinition.catalog()
	ability_definitions = AbilityDefinition.catalog()
	defense_cell_damage_profile = DamageProfile.single(&"defense_cell_damage", &"water")
	case_traits = ContentCatalog.case_trait_definitions()
	finding_definitions = ContentCatalog.finding_definitions()
	reaction_definitions = ContentCatalog.reaction_definitions()
	rng.seed = config.random_seed
	topology = ArenaTopology.new(config.arena_rect(), ArenaTopology.BoundaryMode.BOUNDED)

	simulation_root = Node2D.new()
	simulation_root.name = "Simulation"
	simulation_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(simulation_root)
	arena = ArenaBackdrop.new()
	arena.configure(config.arena_rect(), arena_visuals[selected_level.id])
	simulation_root.add_child(arena)
	crowd_renderer = CrowdRenderer.new()
	crowd_renderer.configure(combat_capacity.max_enemies, combat_capacity.max_pickup_stacks)
	simulation_root.add_child(crowd_renderer)
	projectile_renderer = ProjectileRenderer.new()
	projectile_renderer.configure(combat_capacity.max_projectile_visuals)
	simulation_root.add_child(projectile_renderer)
	hostile_projectile_renderer = ProjectileRenderer.new()
	hostile_projectile_renderer.name = "HostileProjectileRenderer"
	hostile_projectile_renderer.configure(
		combat_capacity.max_projectile_visuals,
		preload("res://assets/art/visual_restart/enemy_projectile.svg"),
		0.0
	)
	hostile_projectile_renderer.z_index = 7
	simulation_root.add_child(hostile_projectile_renderer)
	feedback_renderer = FeedbackRenderer.new()
	feedback_renderer.configure(combat_capacity.max_feedback_visuals)
	feedback_renderer.burst_finished.connect(_on_visual_burst_finished)
	simulation_root.add_child(feedback_renderer)
	ability_feedback_world = AbilityFeedbackWorld.new().configure(topology, MAX_VISUAL_BURSTS, false)
	ability_feedback_world.z_index = 4
	simulation_root.add_child(ability_feedback_world)
	ability_target_preview = AbilityTargetPreview.new()
	simulation_root.add_child(ability_target_preview)
	run_session = RunSession.new().configure(combat_capacity, false)
	run_session.register_system(self, RunSession.Phase.CLOCK)
	simulation_root.add_child(run_session)
	enemy_world = EnemyWorld.new().configure_enemy_world(combat_capacity)
	projectile_world = ProjectileWorld.new().configure_projectile_world(combat_capacity)
	pickup_world = PickupWorld.new().configure_pickup_world(combat_capacity)
	enemy_attack_director = EnemyAttackDirector.new().configure(combat_capacity.max_enemies, enemy_world.resolve)
	enemy_attack_director.projectile_requested.connect(_on_enemy_projectile_requested)
	enemy_attack_director.reinforcements_requested.connect(_on_enemy_reinforcements_requested)
	combat_query = CombatQuery.new().configure(
		topology,
		_enemy_position_for_handle,
		_enemy_radius_for_handle,
		_enemy_targetable_for_handle,
		enemy_world.resolve,
		CombatSpatialGrid.DEFAULT_CELL_SIZE,
		BodySizeCatalog.maximum_radius(enemy_definitions)
	)
	combat_query.set_prepare_callback(_ensure_combat_query)
	pickup_query = CombatQuery.new().configure(
		topology,
		_pickup_position_for_handle,
		Callable(),
		_pickup_targetable_for_handle,
		pickup_world.resolve,
		CombatSpatialGrid.DEFAULT_CELL_SIZE,
		0.0
	)
	pickup_query.set_prepare_callback(_ensure_pickup_query)
	cosmetic_budget_controller = CosmeticBudgetController.new().configure(true, true)
	cosmetic_budget_controller.quality_changed.connect(_on_cosmetic_quality_changed)
	add_child(cosmetic_budget_controller)
	stats = PlayerStats.new()
	avatar = TherapyAvatar.new()
	avatar.configure(config.arena_rect(), stats, topology)
	avatar.position = Vector2.ZERO
	avatar.z_index = 5
	simulation_root.add_child(avatar)
	avatar.set_physics_process(false)
	enemy_world.configure_crowd_collision(topology, avatar, BodySizeCatalog.maximum_radius(enemy_definitions))
	defense_cell_world = DefenseCellWorld.new().configure(topology, avatar, combat_query)
	defense_cell_world.enemy_hit.connect(_on_defense_cell_hit)
	treatment_beam_world = TreatmentBeamWorld.new().configure(TreatmentBeamWorld.DEFAULT_CAPACITY, topology)
	treatment_beam_world.tick_resolved.connect(_on_treatment_beam_tick)
	treatment_beam_world.beam_finished.connect(_on_treatment_beam_finished)
	ability_feedback_world.set_shield_anchor(avatar)
	treatment_controller = TreatmentController.new()
	treatment_controller.enabled = false
	treatment_controller.shots_requested.connect(_on_treatment_shots_requested)
	treatment_controller.treatment_fired.connect(_on_treatment_fired)
	treatment_controller.feedback_requested.connect(_on_treatment_feedback_requested)
	simulation_root.add_child(treatment_controller)
	treatment_controller.set_physics_process(false)
	ability_controller = AbilityController.new()
	ability_controller.ability_used.connect(_on_ability_used)
	ability_controller.execution_completed.connect(_on_ability_execution_completed)
	ability_controller.cooldown_changed.connect(_on_ability_cooldown_changed)
	ability_controller.feedback_requested.connect(_on_ability_feedback_requested)
	ability_controller.shield_changed.connect(_on_ability_shield_changed)
	ability_controller.finding_progress_requested.connect(_on_ability_finding_progress)
	simulation_root.add_child(ability_controller)
	ability_controller.set_physics_process(false)
	finding_controller = FindingController.new()
	finding_controller.progress_changed.connect(_on_finding_progress_changed)
	finding_controller.finding_revealed.connect(_on_finding_revealed)
	finding_controller.reaction_applied.connect(_on_finding_reaction_applied)

	hud = GameHUD.new()
	add_child(hud)
	ui_sound_service = UISoundService.new()
	ui_sound_service.name = "UISoundService"
	add_child(ui_sound_service)
	input_glyph_service = InputGlyphService.new()
	input_glyph_service.name = "InputGlyphService"
	add_child(input_glyph_service)
	hud.navigate_requested.connect(_on_navigate_requested)
	hud.back_requested.connect(_on_back_requested)
	hud.quit_requested.connect(_on_quit_requested)
	hud.story_finished.connect(_on_story_finished)
	hud.level_selected.connect(_on_level_selected)
	hud.preparation_start_requested.connect(_on_preparation_start_requested)
	hud.preparation_component_requested.connect(_on_preparation_component_requested)
	hud.preparation_slot_component_requested.connect(_on_preparation_slot_component_requested)
	hud.preparation_slot_clear_requested.connect(_on_preparation_slot_clear_requested)
	hud.preparation_slot_requested.connect(_on_preparation_slot_requested)
	hud.preparation_reserve_requested.connect(_on_preparation_reserve_requested)
	hud.preparation_replacement_cancelled.connect(_on_preparation_replacement_cancelled)
	hud.ability_slot_requested.connect(_on_hud_ability_slot_requested)
	hud.pause_requested.connect(_on_hud_pause_requested)
	hud.upgrade_chosen.connect(_on_upgrade_chosen)
	hud.reroll_requested.connect(_on_reroll_requested)
	hud.resume_requested.connect(_resume_manual_pause)
	hud.abort_requested.connect(_on_abort_requested)
	hud.abort_confirmed.connect(_on_abort_confirmed)
	hud.abort_cancelled.connect(_on_abort_cancelled)
	hud.retry_requested.connect(_on_retry_requested)
	hud.result_levels_requested.connect(_show_level_select)
	hud.result_campus_requested.connect(_show_campus)
	hud.offline_claim_requested.connect(_on_offline_claim_requested)
	hud.clinic_job_start_requested.connect(_on_clinic_job_start_requested)
	hud.clinic_job_claim_requested.connect(_on_clinic_job_claim_requested)
	hud.research_purchase_requested.connect(_on_research_purchase_requested)
	hud.research_reset_requested.connect(_on_research_reset_requested)
	hud.research_tab_changed.connect(_on_research_tab_changed)
	hud.talent_toggle_requested.connect(_on_talent_toggle_requested)
	hud.talent_rank_remove_requested.connect(_on_talent_rank_remove_requested)
	hud.talent_reset_requested.connect(_on_talent_reset_requested)
	hud.finding_confirmed.connect(_on_finding_confirmed)
	hud.finding_reserve_swap_requested.connect(_on_finding_reserve_swap_requested)
	hud.discovery_dismissed.connect(_on_discovery_dismissed)
	hud.intro_skip_requested.connect(_on_intro_skip_requested)
	hud.intro_skip_confirmed.connect(_on_intro_skip_confirmed)
	hud.intro_skip_cancelled.connect(_on_intro_skip_cancelled)
	hud.restart_confirmed.connect(_on_restart_confirmed)
	hud.restart_cancelled.connect(_on_restart_cancelled)
	hud.run_stats_visibility_changed.connect(_on_run_stats_visibility_changed)
	hud.ui_settings_changed.connect(_on_ui_settings_changed)
	hud.settings_reset_bindings_requested.connect(_on_settings_reset_bindings_requested)
	if hud.has_signal(&"new_game_requested"):
		hud.connect(&"new_game_requested", _on_new_game_requested)
	hud.context_detail_opened.connect(_on_context_detail_opened)
	hud.context_detail_closed.connect(_on_context_detail_closed)
	if hud.has_signal(&"run_prompt_confirmed"):
		hud.connect(&"run_prompt_confirmed", _on_run_prompt_confirmed)

	meta = MetaProgressionState.new()
	# Loading validates the talent economy. Configure the deliberately temporary
	# unlimited mode first so its valid local test selections survive a restart;
	# switching this flag off later will reject overspent trees with a refund.
	meta.set_unlimited_test_progression(UNLIMITED_PROGRESSION_TEST_MODE)
	save_repository = MetaSaveRepository.new()
	if persistence_enabled:
		save_repository.load_into(meta)
	else:
		meta.reset_defaults()
	_sanitize_meta()
	_force_current_runtime_ui_settings(meta.ui_settings)
	meta.ui_settings.apply_saved_bindings()
	meta.ui_settings.apply_audio()
	meta.ui_settings.apply_window()
	ui_sound_service.configure(meta.ui_settings)
	ability_feedback_world.set_reduced_motion(meta.ui_settings.reduce_motion)
	ui_sound_service.wire_tree(hud.root)
	input_glyph_service.configure(UISettingsState.GLYPH_KEYBOARD)
	hud.configure_input_glyphs(input_glyph_service)
	hud.configure_ui_settings(meta.ui_settings)
	hud.set_run_stats_visibility(meta.show_run_stats)
	avatar.set_character_name_visible(meta.ui_settings.show_character_name)
	discovery_manager = DiscoveryManager.new()
	discovery_manager.configure(discovery_definitions, meta.seen_discovery_ids)
	discovery_manager.seen_changed.connect(_on_discovery_seen)
	if completion_smoke or pause_smoke or stress_test:
		for discovery_id in discovery_definitions:
			discovery_manager.mark_seen(discovery_id)
	meta.accrue_time()
	if arguments.has("--auto-start") or bool(_web_test_options.get("auto_start", false)):
		call_deferred("start_run")
	elif not meta.prologue_seen:
		story_return_state = GameFlowState.State.CAMPUS
		_set_flow(GameFlowState.State.STORY)
		hud.show_story()
	else:
		_show_campus()

func _process(delta: float) -> void:
	_update_ability_target_preview()
	meta_refresh_timer -= delta
	if meta_refresh_timer <= 0.0:
		meta_refresh_timer = 1.0
		meta.accrue_time()
		if flow_state == GameFlowState.State.PRACTICE:
			hud.refresh_practice(meta, clinic_definitions)
		elif flow_state == GameFlowState.State.RESEARCH:
			_sync_progression_availability()
			hud.refresh_research(meta, research_definitions)
		elif flow_state == GameFlowState.State.CAMPUS:
			hud.refresh_campus(meta, clinic_definitions)
	if pause_smoke:
		_pause_smoke_step(delta)
	if flow_state == GameFlowState.State.RUNNING and state != null and state.active and stress_test:
		stress_hud_timer -= delta
		if stress_hud_timer <= 0.0:
			stress_hud_timer = 1.0
			hud.show_alert("STRESSTEST · %d GEGNER · %d PROBEN · %d FPS" % [enemies.size(), pickups.size(), Engine.get_frames_per_second()], Color("58dacb"), 1.2)
	if stress_test and stress_telemetry != null:
		var stress_finished := stress_telemetry.sample_frame(delta)
		# Native stress runs are command-line acceptance jobs. End them as soon as
		# the report is complete and propagate its result through the process exit
		# code. Web runs stay alive so the parent harness can read the report.
		if stress_finished and not OS.has_feature("web"):
			var stress_report := stress_telemetry.latest_report()
			stress_telemetry = null
			_cleanup_run_nodes()
			_complete_native_stress_exit.call_deferred(0 if bool(stress_report.get("passed", false)) else 4)


func _complete_native_stress_exit(exit_code: int) -> void:
	# Let the RenderingServer consume the synchronously hidden final buffers
	# before the scene tree releases the renderer resources.
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(exit_code)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if run_session != null:
		run_session.step_fixed(delta)

func step_fixed(delta: float, _session: RunSession = null) -> void:
	if flow_state != GameFlowState.State.RUNNING or state == null or not state.active:
		return
	var phase_started := Time.get_ticks_usec() if performance_profile_enabled else 0
	if performance_profile_enabled:
		last_phase_timings_ms[&"spatial_query_rebuild"] = 0.0
	_fixed_step_active = true
	if enemy_world != null and enemy_world.has_method(&"prepare_avatar_body_interaction"):
		enemy_world.call(&"prepare_avatar_body_interaction", delta)
	avatar.step_fixed(delta)
	state.tick(delta)
	if not state.active:
		_finalize_fixed_step()
		return
	var survival_bucket := mini(floori(state.elapsed / 120.0), 5)
	if survival_bucket != defeat_reward_survival_bucket:
		defeat_reward_survival_bucket = survival_bucket
		_refresh_defeat_research_preview()
	if selected_level.is_tutorial:
		_intro_step(delta)
		hud.update_round_time(state.elapsed)
	else:
		hud.update_timer(state.elapsed, config.run_duration_seconds, config.final_deadline_seconds, state.boss_spawned)
	if flow_state != GameFlowState.State.RUNNING:
		_finalize_fixed_step()
		return
	pressure_grace_timer = maxf(0.0, pressure_grace_timer - delta)
	_spawn_step(delta)
	_profile_phase(&"clock_spawn", phase_started)
	phase_started = Time.get_ticks_usec() if performance_profile_enabled else 0
	enemy_world.step_fixed(delta, run_session)
	if enemy_attack_director != null and not stress_test:
		enemy_attack_director.step_fixed(delta, run_session)
	_profile_phase(&"enemy_world", phase_started)
	_combat_query_dirty = true
	_pickup_query_dirty = true
	# CombatQuery prepares its fixed-tick snapshot lazily on the first actual
	# nearest/circle/line request. Idle runs therefore pay no indexing cost.
	ability_controller.step_fixed(delta, run_session)
	phase_started = Time.get_ticks_usec() if performance_profile_enabled else 0
	if flow_state != GameFlowState.State.RUNNING:
		_finalize_fixed_step()
		return
	if not stress_test:
		if selected_level.is_tutorial:
			if intro_autoattack_enabled:
				_therapy_step(delta)
		else:
			treatment_controller.step(delta)
			if treatment_beam_world != null:
				treatment_beam_world.step_fixed(delta, combat_query)
		_immune_step(delta)
		_support_step(delta)
		_life_regeneration_step(delta)
		_case_mechanics_step(delta)
	_profile_phase(&"combat", phase_started)
	phase_started = Time.get_ticks_usec() if performance_profile_enabled else 0
	if flow_state != GameFlowState.State.RUNNING:
		_finalize_fixed_step()
		return
	projectile_world.step_fixed(delta, run_session)
	_profile_phase(&"projectile_world", phase_started)
	phase_started = Time.get_ticks_usec() if performance_profile_enabled else 0
	if flow_state != GameFlowState.State.RUNNING:
		_finalize_fixed_step()
		return
	pickup_world.step_fixed(delta, run_session)
	_pickup_query_dirty = true
	_profile_phase(&"pickup_world", phase_started)
	phase_started = Time.get_ticks_usec() if performance_profile_enabled else 0
	if ability_feedback_world != null:
		ability_feedback_world.step_fixed(delta, run_session)
	_finalize_fixed_step()
	_profile_phase(&"events_snapshot", phase_started)
	if stress_test and not stress_reported and state.elapsed >= 2.0:
		stress_reported = true
		print("STRESS_CHECK enemies=%d pickups=%d projectiles=%d feedback=%d enemy_pool=%d projectile_pool=%d objects=%d fps=%d quality=%s process_ms=%.3f physics_ms=%.3f" % [
			enemies.size(), pickups.size(), projectiles.size(), visual_bursts.size(), enemy_pool.size(), projectile_pool.size(),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Engine.get_frames_per_second(),
			cosmetic_budget_controller.quality_name() if cosmetic_budget_controller != null else "unknown",
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		])

func _profile_phase(id: StringName, started_usec: int) -> void:
	if performance_profile_enabled:
		last_phase_timings_ms[id] = float(Time.get_ticks_usec() - started_usec) / 1000.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_meta()

func _unhandled_input(event: InputEvent) -> void:
	# A held keyboard key may emit echo events. Ability commands and modal
	# actions are edge-triggered, so an echo must never enqueue a second cast or
	# repeat a destructive navigation action.
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	# Binding capture and its confirmation sheet are exclusive input layers.
	# GUI actions get the first chance to consume the event; anything reaching
	# this fallback must not trigger pause, reroll or another gameplay command.
	if hud != null and hud.is_binding_interaction_active():
		get_viewport().set_input_as_handled()
		return
	if _is_quick_restart_event(event):
		get_viewport().set_input_as_handled()
		_request_quick_restart()
		return
	if event.is_action_pressed(&"ui_info"):
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner is Control and hud.toggle_focused_context_detail(focus_owner as Control):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"ui_cancel") and hud.is_context_detail_explicit():
		hud.close_context_detail()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_RIGHT_X:
			gamepad_target_direction.x = motion.axis_value
		elif motion.axis == JOY_AXIS_RIGHT_Y:
			gamepad_target_direction.y = motion.axis_value
	if targeting_ability_slot >= 0:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause_game") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
			_cancel_ability_targeting()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_confirm_ability_targeting()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"pause_game"):
		match flow_state:
			GameFlowState.State.RUNNING:
				if _request_manual_pause():
					get_viewport().set_input_as_handled()
			GameFlowState.State.DISCOVERY_PAUSE:
				get_viewport().set_input_as_handled()
				_on_discovery_dismissed()
			GameFlowState.State.MANUAL_PAUSE:
				get_viewport().set_input_as_handled()
				if hud.is_pause_stats_open():
					hud.return_to_pause_menu()
				else:
					_resume_manual_pause()
			GameFlowState.State.LEVEL_UP:
				get_viewport().set_input_as_handled()
			GameFlowState.State.FINDING_PAUSE:
				get_viewport().set_input_as_handled()
			GameFlowState.State.ABORT_CONFIRMATION:
				get_viewport().set_input_as_handled()
				_on_abort_cancelled()
			GameFlowState.State.INTRO_SKIP_CONFIRMATION:
				get_viewport().set_input_as_handled()
				_on_intro_skip_cancelled()
			GameFlowState.State.RUN_RESTART_CONFIRMATION:
				get_viewport().set_input_as_handled()
				_on_restart_cancelled()
			GameFlowState.State.PRACTICE, GameFlowState.State.RESEARCH, GameFlowState.State.LEVEL_SELECT, GameFlowState.State.LEXICON, GameFlowState.State.SETTINGS, GameFlowState.State.PREPARATION, GameFlowState.State.STORY, GameFlowState.State.CAMPUS:
				get_viewport().set_input_as_handled()
				_on_back_requested()
		return
	if event.is_action_pressed(&"ui_cancel"):
		match flow_state:
			GameFlowState.State.DISCOVERY_PAUSE:
				_on_discovery_dismissed()
			GameFlowState.State.MANUAL_PAUSE:
				if hud.is_pause_stats_open():
					hud.return_to_pause_menu()
				else:
					_resume_manual_pause()
			GameFlowState.State.ABORT_CONFIRMATION:
				_on_abort_cancelled()
			GameFlowState.State.INTRO_SKIP_CONFIRMATION:
				_on_intro_skip_cancelled()
			GameFlowState.State.RUN_RESTART_CONFIRMATION:
				_on_restart_cancelled()
			GameFlowState.State.PRACTICE, GameFlowState.State.RESEARCH, GameFlowState.State.LEVEL_SELECT, GameFlowState.State.LEXICON, GameFlowState.State.SETTINGS, GameFlowState.State.PREPARATION, GameFlowState.State.STORY:
				_on_back_requested()
			GameFlowState.State.LEVEL_UP, GameFlowState.State.FINDING_PAUSE:
				# These decisions are mandatory. Consume Back without closing their modal.
				pass
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if flow_state == GameFlowState.State.RUNNING:
		for action_data in [[&"active_ability_1", AbilityController.SLOT_Q], [&"active_ability_2", AbilityController.SLOT_E]]:
			var action: StringName = action_data[0]
			var slot: int = action_data[1]
			if event.is_action_pressed(action):
				_begin_or_queue_ability(slot, _ability_device_for_event(event))
				get_viewport().set_input_as_handled()
				return
			if event.is_action_released(action) and targeting_ability_slot == slot:
				_confirm_ability_targeting()
				get_viewport().set_input_as_handled()
				return
	if flow_state == GameFlowState.State.DISCOVERY_PAUSE and event.is_action_pressed(&"ui_accept"):
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

func _is_quick_restart_event(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key := event as InputEventKey
	var is_r := key.keycode == KEY_R or key.physical_keycode == KEY_R
	return key.pressed and not key.echo and is_r and key.ctrl_pressed and not key.alt_pressed and not key.shift_pressed and not key.meta_pressed

func _can_skip_intro() -> bool:
	return selected_level != null and selected_level.is_tutorial and meta != null and not meta.intro_skipped

func _request_quick_restart() -> void:
	if flow_state == GameFlowState.State.RUN_RESTART_CONFIRMATION:
		return
	if flow_state not in [GameFlowState.State.RUNNING, GameFlowState.State.MANUAL_PAUSE] or state == null or not state.active:
		return
	if meta != null and not meta.ui_settings.confirm_run_restart:
		_restart_current_run()
		return
	restart_return_state = flow_state
	ui_router.open_modal(&"restart", null, get_viewport().gui_get_focus_owner())
	_set_flow(GameFlowState.State.RUN_RESTART_CONFIRMATION)
	hud.show_restart_confirmation()

func _on_restart_cancelled() -> void:
	if flow_state != GameFlowState.State.RUN_RESTART_CONFIRMATION:
		return
	ui_router.close_modal(get_viewport().gui_get_focus_owner())
	hud.hide_restart_confirmation()
	_set_flow(restart_return_state)
	if restart_return_state == GameFlowState.State.MANUAL_PAUSE:
		hud.show_running_hud()
		hud.show_pause(_can_skip_intro(), stats, state)

func _on_restart_confirmed() -> void:
	if flow_state != GameFlowState.State.RUN_RESTART_CONFIRMATION:
		return
	_restart_current_run()

func _restart_current_run() -> void:
	if selected_level == null:
		return
	var context := active_run_context.duplicate_context() if active_run_context != null else null
	while ui_router.modal_depth() > 0:
		ui_router.close_modal()
	hud.hide_restart_confirmation()
	start_run(context)

func _set_flow(next_state: GameFlowState.State) -> void:
	if next_state != GameFlowState.State.RUNNING and targeting_ability_slot >= 0:
		_cancel_ability_targeting()
	if run_session != null:
		if next_state == GameFlowState.State.RUNNING and run_session.lifecycle == RunSession.Lifecycle.PAUSED:
			run_session.resume_session()
		elif GameFlowState.pauses_simulation(next_state) and run_session.lifecycle == RunSession.Lifecycle.RUNNING:
			run_session.pause_session()
	flow_state = next_state
	get_tree().paused = GameFlowState.pauses_simulation(next_state)
	flow_changed.emit(next_state)

func _on_hud_ability_slot_requested(slot: int) -> void:
	if flow_state != GameFlowState.State.RUNNING:
		return
	if targeting_ability_slot == slot:
		_confirm_ability_targeting()
		return
	if targeting_ability_slot >= 0:
		_cancel_ability_targeting()
	var device := AbilityCommand.InputDevice.KEYBOARD_MOUSE
	if input_glyph_service != null and input_glyph_service.method() == InputGlyphService.GAMEPAD:
		device = AbilityCommand.InputDevice.GAMEPAD
	_begin_or_queue_ability(slot, device)

func _begin_or_queue_ability(slot: int, device: AbilityCommand.InputDevice) -> void:
	if ability_controller == null:
		return
	var runtime := ability_controller.runtime(slot)
	if runtime == null or runtime.definition == null:
		return
	if not runtime.is_ready():
		if ui_sound_service != null:
			ui_sound_service.play(UISoundService.ABILITY_BLOCKED)
		return
	if runtime.definition.target_mode == AbilityDefinition.TargetMode.SELF:
		_queue_ability_command(slot, avatar.global_position, device)
		return
	targeting_ability_slot = slot
	targeting_input_device = device
	var requested_target := _current_ability_target(device, runtime.definition)
	ability_target_preview.begin(runtime.definition, build_state, topology, avatar.global_position, requested_target, meta.ui_settings.reduce_motion)
	hud.set_ability_targeting(slot, true)

func _confirm_ability_targeting() -> void:
	if targeting_ability_slot < 0 or ability_controller == null:
		return
	var slot := targeting_ability_slot
	var runtime := ability_controller.runtime(slot)
	var target := ability_target_preview.resolved_target() if ability_target_preview != null and ability_target_preview.is_targeting() else avatar.global_position
	var device := targeting_input_device
	_cancel_ability_targeting()
	if runtime != null and runtime.definition != null:
		_queue_ability_command(slot, target, device)

func _cancel_ability_targeting() -> void:
	if targeting_ability_slot >= 0:
		hud.set_ability_targeting(targeting_ability_slot, false)
	targeting_ability_slot = -1
	targeting_input_device = AbilityCommand.InputDevice.UNKNOWN
	if ability_target_preview != null:
		ability_target_preview.cancel()

func _queue_ability_command(slot: int, target: Vector2, device: AbilityCommand.InputDevice) -> void:
	var tick := run_session.fixed_tick if run_session != null else 0
	if ability_controller.queue_slot(slot, target, device, tick) == null:
		hud.show_alert("Die Fähigkeit konnte nicht vorgemerkt werden.", AlveolusVisualTheme.CORAL, 1.4)

func _update_ability_target_preview() -> void:
	if targeting_ability_slot < 0 or flow_state != GameFlowState.State.RUNNING or ability_target_preview == null:
		return
	var runtime := ability_controller.runtime(targeting_ability_slot)
	if runtime == null or runtime.definition == null:
		_cancel_ability_targeting()
		return
	ability_target_preview.update_target(avatar.global_position, _current_ability_target(targeting_input_device, runtime.definition))

func _current_ability_target(device: AbilityCommand.InputDevice, definition: AbilityDefinition) -> Vector2:
	if device != AbilityCommand.InputDevice.GAMEPAD:
		return get_global_mouse_position()
	var direction := gamepad_target_direction
	if direction.length_squared() < 0.16:
		direction = avatar.last_facing
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var distance := float(definition.parameters.get("range", definition.parameters.get("radius", 220.0)))
	if definition.target_mode == AbilityDefinition.TargetMode.CURSOR_AREA:
		distance = maxf(distance * 1.25, 220.0)
	return topology.wrap_position(avatar.global_position + direction * distance)

func _ability_device_for_event(event: InputEvent) -> AbilityCommand.InputDevice:
	return AbilityCommand.InputDevice.GAMEPAD if event is InputEventJoypadButton or event is InputEventJoypadMotion else AbilityCommand.InputDevice.KEYBOARD_MOUSE

func _on_route_focus_requested(target: Variant) -> void:
	if target is Control and is_instance_valid(target) and (target as Control).is_visible_in_tree():
		(target as Control).grab_focus.call_deferred()

func _show_campus(reset_route: bool = true) -> void:
	_cleanup_run_nodes()
	avatar.input_enabled = false
	avatar.hide()
	meta.accrue_time()
	_save_meta()
	_set_flow(GameFlowState.State.CAMPUS)
	hud.show_campus(meta, clinic_definitions)
	if bool(meta.tutorial_status.get(&"research_guidance_pending", false)) and hud.has_method("show_campus_research_guidance"):
		hud.call("show_campus_research_guidance")
	if reset_route:
		ui_router.reset(&"campus")

func _show_practice() -> void:
	_route_to(&"practice")
	_set_flow(GameFlowState.State.PRACTICE)
	hud.show_practice(meta, clinic_definitions)

func _show_research() -> void:
	_route_to(&"research")
	_set_flow(GameFlowState.State.RESEARCH)
	_sync_progression_availability()
	hud.show_research_tabs(
		meta,
		research_definitions,
		TalentDefinition.definitions()
	)

func _show_level_select(update_route: bool = true) -> void:
	_cleanup_run_nodes()
	avatar.input_enabled = false
	avatar.hide()
	_set_flow(GameFlowState.State.LEVEL_SELECT)
	hud.show_level_select(meta, levels)
	if update_route:
		if ui_router.current_screen_id() != &"campus":
			ui_router.reset(&"campus")
		_route_to(&"level_select")

func _show_lexicon() -> void:
	_cleanup_run_nodes()
	avatar.input_enabled = false
	avatar.hide()
	_set_flow(GameFlowState.State.LEXICON)
	hud.show_lexicon(meta)
	_route_to(&"lexicon")

func _show_settings(return_state: GameFlowState.State) -> void:
	settings_return_state = return_state
	if return_state == GameFlowState.State.MANUAL_PAUSE:
		ui_router.open_modal(&"settings", null, get_viewport().gui_get_focus_owner())
	else:
		ui_router.push_screen(&"settings", null, get_viewport().gui_get_focus_owner())
	_set_flow(GameFlowState.State.SETTINGS)
	hud.show_settings(not OS.has_feature("web"), return_state != GameFlowState.State.MANUAL_PAUSE)

func _on_navigate_requested(destination: StringName) -> void:
	if flow_state == GameFlowState.State.CAMPUS and bool(meta.tutorial_status.get(&"research_guidance_pending", false)):
		meta.set_tutorial_step(&"research_guidance_pending", false)
		if hud.has_method("hide_campus_research_guidance"):
			hud.call("hide_campus_research_guidance")
		_save_meta()
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
			ui_router.push_screen(&"story", null, get_viewport().gui_get_focus_owner())
			_set_flow(GameFlowState.State.STORY)
			hud.show_story()

func _route_to(screen_id: StringName) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if ui_router.current_screen_id() == &"":
		ui_router.reset(&"campus")
	if ui_router.current_screen_id() == screen_id:
		return
	ui_router.push_screen(screen_id, null, owner)

func _on_back_requested() -> void:
	match flow_state:
		GameFlowState.State.CAMPUS:
			return
		GameFlowState.State.PRACTICE, GameFlowState.State.RESEARCH, GameFlowState.State.LEVEL_SELECT:
			_show_campus(false)
			ui_router.back(get_viewport().gui_get_focus_owner())
		GameFlowState.State.LEXICON:
			if hud.cancel_lexicon_step():
				return
			_show_campus(false)
			ui_router.back(get_viewport().gui_get_focus_owner())
		GameFlowState.State.PREPARATION:
			if hud.cancel_preparation_step():
				return
			if pending_replacement_component != &"":
				_on_preparation_replacement_cancelled()
			else:
				_show_level_select(false)
				ui_router.back(get_viewport().gui_get_focus_owner())
		GameFlowState.State.STORY:
			_return_from_story()
		GameFlowState.State.SETTINGS:
			_return_from_settings()

func _return_from_settings() -> void:
	ui_router.back(get_viewport().gui_get_focus_owner())
	_restore_screen(settings_return_state)

func _on_story_finished() -> void:
	meta.mark_prologue_seen()
	_save_meta()
	_return_from_story()

func _return_from_story() -> void:
	ui_router.back(get_viewport().gui_get_focus_owner())
	_restore_screen(story_return_state)

func _restore_screen(target_state: GameFlowState.State) -> void:
	match target_state:
		GameFlowState.State.MANUAL_PAUSE:
			_set_flow(GameFlowState.State.MANUAL_PAUSE)
			hud.show_running_hud()
			hud.show_pause(_can_skip_intro(), stats, state)
		GameFlowState.State.PRACTICE:
			_set_flow(GameFlowState.State.PRACTICE)
			hud.show_practice(meta, clinic_definitions)
		GameFlowState.State.RESEARCH:
			_set_flow(GameFlowState.State.RESEARCH)
			_sync_progression_availability()
			hud.show_research_tabs(
				meta,
				research_definitions,
				TalentDefinition.definitions()
			)
		GameFlowState.State.LEVEL_SELECT:
			_show_level_select(false)
		GameFlowState.State.LEXICON:
			_set_flow(GameFlowState.State.LEXICON)
			hud.show_lexicon(meta)
		GameFlowState.State.PREPARATION:
			_set_flow(GameFlowState.State.PREPARATION)
			_refresh_preparation()
		_:
			_show_campus(false)

func _on_level_selected(id: StringName) -> void:
	for definition in levels:
		if definition.id == id and meta.is_level_unlocked(definition.order):
			selected_level = definition
			# Selecting a case always opens the same explicit planning step. The
			# quick-run flag shortens simulation timings for tests; it must not
			# silently bypass a user-facing navigation contract.
			_show_preparation()
			return

func _on_quit_requested() -> void:
	_save_meta()
	get_tree().quit()

func _on_new_game_requested() -> void:
	_cleanup_run_nodes()
	meta.reset_defaults()
	meta.set_unlimited_test_progression(UNLIMITED_PROGRESSION_TEST_MODE)
	discovery_manager.configure(discovery_definitions, meta.seen_discovery_ids)
	_save_meta()
	story_return_state = GameFlowState.State.CAMPUS
	ui_router.reset(&"story")
	_set_flow(GameFlowState.State.STORY)
	hud.show_story()

func _on_run_stats_visibility_changed(enabled: bool) -> void:
	meta.show_run_stats = enabled
	_save_meta()

func _on_ui_settings_changed(settings: UISettingsState) -> void:
	_force_current_runtime_ui_settings(settings)
	meta.set_ui_settings(settings)
	meta.ui_settings.apply_audio()
	if ability_feedback_world != null:
		ability_feedback_world.set_reduced_motion(meta.ui_settings.reduce_motion)
	if ui_sound_service != null:
		ui_sound_service.configure(meta.ui_settings)
	if input_glyph_service != null:
		input_glyph_service.configure(UISettingsState.GLYPH_KEYBOARD)
	if avatar != null:
		avatar.set_character_name_visible(meta.ui_settings.show_character_name)
	_save_meta()


func _force_current_runtime_ui_settings(settings: UISettingsState) -> void:
	if settings == null:
		return
	# Save v6 keeps both fields for backwards compatibility, but this milestone
	# has one visible presentation/input contract. Old 200%- or gamepad-forced
	# saves therefore cannot silently alter the current runtime.
	settings.ui_scale = 1.0
	settings.glyph_mode = UISettingsState.GLYPH_KEYBOARD

func _on_settings_reset_bindings_requested() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down", &"pause_game", &"active_ability_1", &"active_ability_2", &"upgrade_1", &"upgrade_2", &"upgrade_3", &"reroll_upgrades", &"ui_accept", &"ui_cancel", &"ui_info"]:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
	_register_input_actions()
	meta.ui_settings.input_bindings.clear()
	hud.configure_ui_settings(meta.ui_settings)
	_save_meta()

func _on_context_detail_opened(source: Control, explicit: bool) -> void:
	if not explicit or source == null:
		return
	if ui_router.current_modal_id() == &"context_detail":
		ui_router.remember_focus(source)
		return
	ui_router.open_context_detail(&"context_detail", source)

func _on_context_detail_closed() -> void:
	if ui_router.current_modal_id() == &"context_detail":
		ui_router.close_modal(get_viewport().gui_get_focus_owner())

func _on_retry_requested() -> void:
	if selected_level != null and not quick_run:
		_show_preparation()
	else:
		start_run()

func _show_preparation() -> void:
	if selected_level == null:
		return
	pending_run_context = _create_case_context(selected_level)
	if pending_run_context == null:
		return
	# Historical plans remain stored until the player actually changes or starts
	# this plan. The effective draft follows the current balancing catalog without
	# deleting owned research, legacy actives or passive values from the save.
	pending_preparation_loadout = LoadoutAvailabilityPolicy.sanitized_copy(
		pending_run_context.loadout_snapshot,
		loadout_modules,
		meta.research_ranks,
		_first_case_complete()
	)
	pending_run_context.loadout_snapshot = pending_preparation_loadout.duplicate_loadout()
	var available := LoadoutAvailabilityPolicy.selectable_ids(loadout_modules, meta.research_ranks, _first_case_complete())
	pending_loadout_draft = LoadoutDraft.from_prepared(pending_preparation_loadout, loadout_modules, available, meta.preparation_capacity())
	pending_replacement_component = &""
	_set_flow(GameFlowState.State.PREPARATION)
	if ui_router.current_screen_id() != &"level_select":
		ui_router.reset(&"campus")
		ui_router.push_screen(&"level_select")
	ui_router.push_screen(&"preparation", null, get_viewport().gui_get_focus_owner())
	_refresh_preparation()

func _create_case_context(level: LevelDefinition) -> RunContext:
	if level == null:
		return null
	var seed := meta.get_or_create_case_seed(level.id)
	if not meta.has_completed_level(level.id):
		return meta.create_run_context(level.id, &"", &"")
	var case_rng := RandomNumberGenerator.new()
	case_rng.seed = seed
	return meta.create_run_context(
		level.id,
		_deterministic_case_choice(level.visible_trait_ids, case_rng),
		_deterministic_case_choice(level.hidden_finding_ids, case_rng)
	)

func _deterministic_case_choice(ids: Array[StringName], case_rng: RandomNumberGenerator) -> StringName:
	var valid: Array[StringName] = []
	for id in ids:
		if id != &"":
			valid.append(id)
	if valid.is_empty():
		return &""
	return valid[case_rng.randi_range(0, valid.size() - 1)]

func _refresh_preparation() -> void:
	if pending_loadout_draft == null:
		return
	pending_preparation_loadout = pending_loadout_draft.to_prepared()
	var validation := pending_loadout_draft.validate()
	var case_trait_value: Variant = case_traits.get(pending_run_context.visible_trait_id)
	var view_model := {
		"level_title": selected_level.title,
		"level_description": selected_level.briefing_text,
		"duration_text": selected_level.duration_text(),
		"boss_time_text": selected_level.boss_time_text(),
		"tutorial_locked": selected_level.is_tutorial,
		"can_skip_intro": selected_level.is_tutorial and not meta.intro_skipped,
		"trait": case_trait_value,
		"validation": validation,
		"finding_hint": _preparation_finding_hint(),
		"unlocked_ids": meta.unlocked_module_ids(loadout_modules, research_definitions),
		"available_ids": LoadoutAvailabilityPolicy.selectable_ids(loadout_modules, meta.research_ranks, _first_case_complete()),
		"availability_reasons": _preparation_availability_reasons(),
		"locked_slot_ids": {LoadoutSlotId.ACTIVE_2: true} if not _first_case_complete() else {},
		"slot_lock_reasons": {
			LoadoutSlotId.ACTIVE_2: "Wird nach Abschluss von Fall 1 freigeschaltet."
		} if not _first_case_complete() else {},
		"slot_snapshot": pending_loadout_draft.slot_snapshot(),
		"loadout_snapshot": pending_preparation_loadout.to_dict(),
		"replacement_component": pending_replacement_component,
	}
	hud.show_preparation(view_model, loadout_modules.values(), pending_preparation_loadout)

func _preparation_finding_hint() -> String:
	return "Der genaue Befund entsteht während der Behandlung."

func _preparation_availability_reasons() -> Dictionary:
	var reasons: Dictionary = {}
	for raw_id in loadout_modules:
		var id := StringName(raw_id)
		var reason := LoadoutAvailabilityPolicy.unavailable_reason(
			id,
			loadout_modules,
			meta.research_ranks,
			_first_case_complete()
		)
		if not reason.is_empty():
			reasons[id] = reason
	return reasons

func _on_preparation_component_requested(id: StringName) -> void:
	if flow_state != GameFlowState.State.PREPARATION or pending_loadout_draft == null or _is_preparation_loadout_locked():
		return
	var available := LoadoutAvailabilityPolicy.selectable_ids(loadout_modules, meta.research_ranks, _first_case_complete())
	if not bool(available.get(id, false)) or not loadout_modules.has(id):
		return
	var result := pending_loadout_draft.equip(id)
	_handle_loadout_change(result)

func _on_preparation_slot_component_requested(slot_id: StringName, id: StringName) -> void:
	if flow_state != GameFlowState.State.PREPARATION or pending_loadout_draft == null or _is_preparation_loadout_locked():
		return
	if not LoadoutSlotId.planning().has(slot_id) or not loadout_modules.has(id):
		return
	if slot_id == LoadoutSlotId.ACTIVE_2 and not _first_case_complete():
		return
	var available := LoadoutAvailabilityPolicy.selectable_ids(loadout_modules, meta.research_ranks, _first_case_complete())
	if not bool(available.get(id, false)):
		return
	# The plan already names an explicit target slot, so replacement is atomic
	# and immediately reversible. A second confirmation added friction without
	# protecting any irreversible action.
	var result := pending_loadout_draft.replace(id, slot_id)
	_handle_loadout_change(result)

func _on_preparation_slot_clear_requested(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= LoadoutSlotId.planning().size():
		return
	_on_preparation_slot_requested(LoadoutSlotId.planning()[slot_index])

func _on_preparation_slot_requested(slot_id: StringName) -> void:
	if flow_state != GameFlowState.State.PREPARATION or pending_loadout_draft == null or _is_preparation_loadout_locked():
		return
	if not LoadoutSlotId.planning().has(slot_id):
		return
	if slot_id == LoadoutSlotId.ACTIVE_2 and not _first_case_complete():
		return
	var result: LoadoutChangeResult
	if pending_replacement_component != &"":
		result = pending_loadout_draft.confirm_replacement(pending_replacement_component, slot_id)
		if result.applied:
			pending_replacement_component = &""
	else:
		result = pending_loadout_draft.remove(slot_id)
	_handle_loadout_change(result)

func _handle_loadout_change(result: LoadoutChangeResult) -> void:
	if result == null:
		return
	if result.needs_replacement():
		pending_replacement_component = result.component_id
		var capacity_previews: Dictionary = {}
		var incoming: LoadoutModuleDefinition = loadout_modules.get(result.component_id)
		for slot_id in result.replacement_slots:
			var outgoing: LoadoutModuleDefinition = loadout_modules.get(pending_loadout_draft.component_at(slot_id))
			var after := result.capacity_before
			if incoming != null:
				after += incoming.capacity_cost
			if outgoing != null:
				after -= outgoing.capacity_cost
			capacity_previews[slot_id] = after
		hud.show_preparation_replacement(result.component_id, result.replacement_slots, result.capacity_before, capacity_previews)
		return
	if result.is_noop():
		hud.complete_preparation_change(result.focus_slot)
		_refresh_preparation()
		return
	if not result.applied:
		hud.show_preparation_error(result.first_error())
		return
	pending_preparation_loadout = pending_loadout_draft.to_prepared()
	if pending_loadout_draft.validate().valid:
		meta.set_prepared_loadout(selected_level.id, pending_preparation_loadout)
		pending_run_context.loadout_snapshot = pending_preparation_loadout.duplicate_loadout()
		_save_meta()
	hud.complete_preparation_change(result.target_slot)
	_refresh_preparation()

func _on_preparation_reserve_requested(id: StringName) -> void:
	if flow_state != GameFlowState.State.PREPARATION or pending_loadout_draft == null or not loadout_modules.has(id) or _is_preparation_loadout_locked():
		return
	var definition: LoadoutModuleDefinition = loadout_modules[id]
	var available := LoadoutAvailabilityPolicy.selectable_ids(loadout_modules, meta.research_ranks, _first_case_complete())
	if definition.kind != LoadoutModuleDefinition.Kind.PASSIVE or not bool(available.get(id, false)):
		return
	var result := pending_loadout_draft.equip(id, LoadoutSlotId.RESERVE)
	if result.needs_replacement():
		result = pending_loadout_draft.replace(id, LoadoutSlotId.RESERVE)
	_handle_loadout_change(result)

func _on_preparation_replacement_cancelled() -> void:
	if flow_state != GameFlowState.State.PREPARATION:
		return
	pending_replacement_component = &""
	_refresh_preparation()

func _is_preparation_loadout_locked() -> bool:
	return selected_level != null and selected_level.is_tutorial

func _on_preparation_start_requested(snapshot: Dictionary) -> void:
	if flow_state != GameFlowState.State.PREPARATION or pending_run_context == null or pending_loadout_draft == null:
		return
	var requested := pending_loadout_draft.to_prepared()
	var validation := pending_loadout_draft.validate()
	if not validation.valid:
		_refresh_preparation()
		return
	pending_preparation_loadout = requested.duplicate_loadout()
	meta.set_prepared_loadout(selected_level.id, requested)
	pending_run_context.loadout_snapshot = requested.duplicate_loadout()
	_save_meta()
	start_run(pending_run_context)

func start_run(run_context: RunContext = null) -> void:
	_cleanup_run_nodes()
	if cosmetic_budget_controller != null:
		cosmetic_budget_controller.reset_quality()
	config = ContentCatalog.create_run_config(selected_level, quick_run)
	active_run_context = _resolved_run_context(run_context)
	active_loadout = active_run_context.loadout_snapshot.duplicate_loadout() if active_run_context != null and active_run_context.loadout_snapshot != null else null
	if active_run_context != null:
		config.random_seed = active_run_context.seed
		_apply_case_trait_to_config(active_run_context.visible_trait_id)
	if stress_test:
		_configure_stress_run_config()
	_compile_enemy_runtime_resistance_profiles()
	topology.bounds = config.arena_rect()
	combat_query.configure(
		topology,
		_enemy_position_for_handle,
		_enemy_radius_for_handle,
		_enemy_targetable_for_handle,
		enemy_world.resolve,
		CombatSpatialGrid.DEFAULT_CELL_SIZE,
		BodySizeCatalog.maximum_radius(enemy_definitions)
	)
	pickup_query.configure(
		topology,
		_pickup_position_for_handle,
		Callable(),
		_pickup_targetable_for_handle,
		pickup_world.resolve,
		CombatSpatialGrid.DEFAULT_CELL_SIZE,
		0.0
	)
	_combat_query_dirty = true
	_pickup_query_dirty = true
	arena.configure(config.arena_rect(), arena_visuals[selected_level.id])
	stats = PlayerStats.new()
	var treatment: TreatmentDefinition = treatment_definitions.get(active_loadout.treatment_id) if active_loadout != null else null
	# The tutorial keeps tactical controllers disabled, but still carries the
	# identity of its demonstrated treatment so generic upgrade presentation can
	# name the affected component without guessing from content IDs.
	if selected_level.is_tutorial and treatment == null:
		treatment = treatment_definitions.get(&"treatment_precision")
	if treatment != null:
		stats.configure_prepared_treatment(treatment)
	if not selected_level.is_tutorial and treatment != null:
		# Forschung ist dauerhafte Charakterprogression. Sie wirkt unabhängig von
		# der Einsatzplanung; Passivmodule sind im aktuellen Ausbau deaktiviert.
		stats.apply_meta_progression(meta.research_ranks)
	if completion_smoke:
		stats.therapy_damage = 250.0
		stats.therapy_cooldown = 0.28
		stats.therapy_range = 1200.0
		stats.therapy_targets = 12
		stats.therapy_projectiles = 12
		stats.immune_level = 2
		stats.immune_damage = 30.0
		stats.support_level = 1
	avatar.configure(config.arena_rect(), stats, topology)
	avatar.global_position = Vector2.ZERO
	avatar.reset_physics_interpolation()
	avatar.input_enabled = true
	avatar.set_character_name_visible(meta.ui_settings.show_character_name)
	avatar.show()
	avatar.queue_redraw()
	rng.seed = config.random_seed
	_reset_spawn_position_sequence()
	relocation_rng.seed = int(config.random_seed) ^ 0x52454C4F43415445
	spawn_accumulator = config.initial_spawn_interval
	offscreen_relocation_timer = OFFSCREEN_RELOCATION_INTERVAL
	offscreen_relocation_move_timer = 0.0
	offscreen_relocation_move_interval = OFFSCREEN_RELOCATION_INTERVAL
	offscreen_relocation_pending = 0
	offscreen_relocation_last_eligible_count = 0
	offscreen_relocation_last_planned_count = 0
	therapy_timer = 0.18
	immune_timer = 0.75
	support_timer = 6.0
	life_regeneration_accumulator = 0.0
	pressure_grace_timer = 0.0
	pickup_merge_cursor = 0
	defeats = 0
	run_damage_by_source.clear()
	defeat_reward_survival_bucket = -1
	stress_reported = false
	stress_hud_timer = 0.0
	reroll_available = false
	reroll_used = false
	current_upgrade_options.clear()
	active_boss = null
	active_boss_handles.clear()
	active_boss_handle_by_instance.clear()
	active_boss_phase_by_handle.clear()
	boss_aggregate_maximum = 0.0
	boss_aggregate_phase = 0
	intro_lesson = 1 if selected_level.is_tutorial else 0
	intro_phase = &"await_primary_materialization" if selected_level.is_tutorial else &""
	intro_primary_enemy = null
	intro_observation_remaining = 0.0
	intro_autoattack_enabled = false
	intro_confirmation_kind = &""
	intro_enemy_roles.clear()
	intro_pickup_roles.clear()
	intro_followup_defeats = 0
	intro_followup_pickups = 0
	_set_intro_prompt("", &"normal", false, "")
	discovery_spawn_reservations.clear()
	discovery_manager.clear_pending()
	active_reaction = null
	pending_finding_definition = null
	hidden_nest_timers.clear()
	pressure_surge_timer = 25.0
	pressure_surge_remaining = 0.0
	reaction_boost_timer = 0.0
	reaction_boost_source = &""
	last_ability_slot = -1
	last_ability_time = -1000.0
	emergency_talent_used = false
	ability_ready_states.clear()

	state = RunState.new()
	state.stability_changed.connect(_on_stability_changed)
	state.analysis_changed.connect(_on_analysis_changed)
	state.level_up_requested.connect(_on_level_up_requested)
	state.boss_due.connect(_spawn_boss)
	state.run_finished.connect(_on_run_finished)
	state.reset(config, 0, stats.max_stability_bonus)
	if selected_level.is_tutorial:
		state.set_analysis_target(INTRO_ANALYSIS_TARGET)
	state.set_analysis_gain_multiplier(stats.experience_gain_multiplier * config.experience_gain_multiplier)
	if run_session != null:
		run_session.reset()
		run_session.start(active_run_context)
	_configure_tactical_run(treatment)
	mastery_tracker.begin_run(selected_level.id, config.run_duration_seconds)
	mastery_tracker.record_stability(state.stability, state.max_stability)
	hud.update_run_stats(stats, state)
	hud.update_shield(0.0, 0.0)
	_refresh_defeat_research_preview()
	hud.show_running_hud()
	if ui_sound_service != null:
		ui_sound_service.play(UISoundService.RUN_START)
	ui_router.replace_screen(&"run", null, get_viewport().gui_get_focus_owner())
	_set_flow(GameFlowState.State.RUNNING)
	if selected_level.is_tutorial:
		treatment_controller.enabled = false
		ability_controller.clear()
		hud.configure_active_abilities([])
		hud.hide_finding_progress()
		hud.update_round_time(0.0)
		_set_intro_prompt("Beobachte den ersten Erreger.", &"normal", false, "")
		intro_primary_enemy = _spawn_enemy(&"pneumococcus", _spawn_position_around_avatar(470.0, _enemy_body_radius(&"pneumococcus")), 0.55)
		if is_instance_valid(intro_primary_enemy):
			intro_enemy_roles[intro_primary_enemy] = INTRO_ROLE_PRIMARY
			intro_primary_enemy.set_status_modifier(&"intro_guidance", 0.58, 1.0)
	else:
		treatment_controller.enabled = true
		hud.update_timer(0.0, config.run_duration_seconds, config.final_deadline_seconds, false)
		for index in range(3):
			_spawn_enemy(&"pneumococcus", _spawn_position_around_avatar(470.0 + index * 34.0, _enemy_body_radius(&"pneumococcus")))
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
		_spawn_stress_projectiles()
		for index in range(combat_capacity.max_feedback_visuals):
			var angle := TAU * float(index) / float(combat_capacity.max_feedback_visuals)
			_spawn_visual_burst(Vector2.from_angle(angle) * 260.0, &"stress", AlveolusVisualTheme.TURQUOISE, 4, STRESS_RUN_SECONDS, 24.0)
		stress_telemetry = RenderStressTelemetry.new().configure(
			_stress_telemetry_snapshot,
			stress_warmup_seconds,
			stress_measurement_seconds
		)
		stress_telemetry.begin()

func _spawn_stress_projectiles() -> void:
	var shots: Array[TreatmentShot] = []
	for index in range(combat_capacity.max_projectile_states):
		var angle := TAU * float(index) / float(combat_capacity.max_projectile_states)
		var origin := Vector2.from_angle(angle) * (170.0 + float(index % 5) * 14.0)
		shots.append(TreatmentShot.tracking(origin, enemies[index % enemies.size()], 0.0, 2000.0, &"stress"))
	_on_treatment_shots_requested(shots)
	for index in range(projectiles.size()):
		var projectile := projectiles[index]
		projectile.lifetime = STRESS_RUN_SECONDS
		projectile.speed = 520.0
		projectile.direction = Vector2.from_angle(TAU * float(index) / float(maxi(projectiles.size(), 1)) + PI * 0.5)
		projectile.rotation = projectile.direction.angle()
		projectile.target = null
		projectile.target_handle = EntityHandle.INVALID
		projectile.target_resolver = Callable()

func _configure_stress_run_config() -> void:
	# Stress telemetry measures a stable, exact render load. It must never be
	# terminated by the selected level's deadline or by crowd contact while a
	# long native/browser measurement is still in progress.
	config.run_duration_seconds = STRESS_RUN_SECONDS
	config.final_deadline_seconds = STRESS_RUN_SECONDS * 2.0
	config.initial_stability = 1.0e9
	config.contact_damage_multiplier = 0.0
	config.initial_spawn_interval = STRESS_RUN_SECONDS
	config.final_spawn_interval = STRESS_RUN_SECONDS

func _stress_telemetry_snapshot() -> Dictionary:
	var enemy_active := enemy_world.active_count() if enemy_world != null else enemies.size()
	var pickup_active := pickup_world.active_count() if pickup_world != null else pickups.size()
	var projectile_active := projectile_world.active_count() if projectile_world != null else projectiles.size()
	return {
		"quality": cosmetic_budget_controller.quality_name() if cosmetic_budget_controller != null else "unknown",
		"flow": {
			"state": int(flow_state),
			"running": flow_state == GameFlowState.State.RUNNING,
			"run_active": state != null and state.active,
			"running_active": flow_state == GameFlowState.State.RUNNING and state != null and state.active,
		},
		"entities": {
			"enemies": enemies.size(),
			"regular_enemies": enemy_world.regular_count if enemy_world != null else enemies.size(),
			"critical_enemies": enemy_world.critical_count if enemy_world != null else 0,
			"pickups": pickups.size(),
			"projectiles": projectiles.size(),
			"feedback": visual_bursts.size() + damage_numbers.size(),
			"visual_bursts": visual_bursts.size(),
			"damage_numbers": damage_numbers.size(),
		},
		"pools": {
			"enemies": {
				"active": enemy_active,
				"inactive": enemy_pool.size(),
				"available_slots": enemy_world.available_count() if enemy_world != null else maxi(0, combat_capacity.max_enemies - enemy_active),
				"capacity": combat_capacity.max_enemies,
			},
			"pickups": {
				"active": pickup_active,
				"inactive": pickup_pool.size(),
				"available_slots": pickup_world.available_count() if pickup_world != null else maxi(0, combat_capacity.max_pickup_stacks - pickup_active),
				"capacity": combat_capacity.max_pickup_stacks,
			},
			"projectiles": {
				"active": projectile_active,
				"inactive": projectile_pool.size(),
				"available_slots": projectile_world.available_count() if projectile_world != null else maxi(0, combat_capacity.max_projectile_states - projectile_active),
				"capacity": combat_capacity.max_projectile_states,
			},
			"feedback": {
				"active": visual_bursts.size() + damage_numbers.size(),
				"inactive": visual_burst_pool.size() + damage_number_pool.size(),
				"capacity": combat_capacity.max_feedback_visuals,
			},
		},
		"render": {
			"objects_in_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			"draw_calls_in_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"primitives_in_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			"projectile_visuals": projectile_renderer.active_count() if projectile_renderer != null else projectiles.size(),
			"crowd_enemy_visuals": crowd_renderer.active_enemy_visual_count() if crowd_renderer != null else enemies.size(),
			"crowd_pickup_visuals": crowd_renderer.active_pickup_visual_count() if crowd_renderer != null else pickups.size(),
			"crowd_visuals": crowd_renderer.active_visual_count() if crowd_renderer != null else enemies.size() + pickups.size(),
			"feedback_visuals": feedback_renderer.active_count() if feedback_renderer != null else visual_bursts.size(),
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		},
	}

func _read_web_test_options() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var encoded: Variant = JavaScriptBridge.eval(
		"JSON.stringify((function(){const q=new URLSearchParams(location.search);return {stress:q.get('stress')==='1',auto_start:q.get('auto_start')==='1',warmup:q.get('stress_warmup'),duration:q.get('stress_duration')};})())",
		true
	)
	var parsed: Variant = JSON.parse_string(str(encoded))
	return parsed if parsed is Dictionary else {}

func _stress_number_option(arguments: PackedStringArray, prefix: String, web_key: String, fallback: float) -> float:
	for argument in arguments:
		if argument.begins_with(prefix):
			return clampf(float(argument.trim_prefix(prefix)), 0.0, 3600.0)
	var web_value: Variant = _web_test_options.get(web_key)
	if web_value != null and not str(web_value).is_empty():
		return clampf(float(web_value), 0.0, 3600.0)
	return fallback

func _resolved_run_context(requested: RunContext) -> RunContext:
	if selected_level == null or selected_level.is_tutorial:
		return null
	var resolved: RunContext = null
	if requested != null and requested.level_id == selected_level.id:
		resolved = requested.duplicate_context()
	elif quick_run:
		resolved = RunContext.create(selected_level.id, config.random_seed, PreparedLoadout.default_loadout(), {})
	else:
		resolved = _create_case_context(selected_level)
	if resolved != null:
		resolved.loadout_snapshot = LoadoutAvailabilityPolicy.sanitized_copy(
			resolved.loadout_snapshot,
			loadout_modules,
			meta.research_ranks,
			_first_case_complete()
		)
	return resolved

func _apply_case_trait_to_config(trait_id: StringName) -> void:
	var case_trait_definition: CaseTraitDefinition = case_traits.get(trait_id)
	if case_trait_definition == null:
		return
	for modifier in case_trait_definition.modifiers:
		var stat_id := StringName(str(modifier.get("stat_id", "")))
		var operation := StringName(str(modifier.get("operation", "add")))
		var value := float(modifier.get("value", 0.0))
		match stat_id:
			&"spawn_interval":
				config.initial_spawn_interval = _apply_scalar_modifier(config.initial_spawn_interval, operation, value)
				config.final_spawn_interval = _apply_scalar_modifier(config.final_spawn_interval, operation, value)
			&"enemy_health":
				config.enemy_health_start = _apply_scalar_modifier(config.enemy_health_start, operation, value)
				config.enemy_health_end = _apply_scalar_modifier(config.enemy_health_end, operation, value)
			&"boss_health":
				config.boss_health_multiplier = _apply_scalar_modifier(config.boss_health_multiplier, operation, value)
			&"enemy_speed":
				config.enemy_speed_multiplier = _apply_scalar_modifier(config.enemy_speed_multiplier, operation, value)
			&"contact_damage", &"enemy_damage":
				config.contact_damage_multiplier = _apply_scalar_modifier(config.contact_damage_multiplier, operation, value)
			&"enemy_resistance_effective":
				config.enemy_resistance_effective_bonus = _apply_scalar_modifier(config.enemy_resistance_effective_bonus, operation, value)
			&"enemy_defense":
				config.enemy_defense = maxf(0.0, _apply_scalar_modifier(config.enemy_defense, operation, value))
			&"boss_count":
				config.boss_count = maxi(1, roundi(_apply_scalar_modifier(float(config.boss_count), operation, value)))
			&"spawn_rate":
				config.spawn_rate_multiplier = maxf(0.01, _apply_scalar_modifier(config.spawn_rate_multiplier, operation, value))
			&"experience_gain":
				config.experience_gain_multiplier = maxf(0.0, _apply_scalar_modifier(config.experience_gain_multiplier, operation, value))

func _apply_scalar_modifier(current: float, operation: StringName, value: float) -> float:
	match operation:
		&"multiply":
			return current * value
		&"override":
			return value
	return current + value


func _compile_enemy_runtime_resistance_profiles() -> void:
	enemy_runtime_resistance_profiles.clear()
	for id in enemy_definitions:
		var definition := enemy_definitions[id] as EnemyDefinition
		if definition == null:
			continue
		if is_zero_approx(config.enemy_resistance_effective_bonus):
			enemy_runtime_resistance_profiles[id] = definition.resistance_profile
		else:
			enemy_runtime_resistance_profiles[id] = ResistanceProfile.with_effective_percentage_bonus(
				StringName("%s_runtime" % String(id)),
				definition.resistance_profile,
				config.enemy_resistance_effective_bonus
			)

func _configure_tactical_run(treatment: TreatmentDefinition) -> void:
	build_state = RunBuildState.from_treatment(treatment)
	if treatment == null:
		treatment_controller.enabled = false
		ability_controller.clear()
		return
	build_state.set_base(RunBuildState.TREATMENT_DAMAGE, stats.therapy_damage)
	build_state.set_base(RunBuildState.TREATMENT_INTERVAL, stats.therapy_cooldown)
	build_state.set_base(RunBuildState.TREATMENT_RANGE, stats.therapy_range)
	build_state.set_base(RunBuildState.TREATMENT_TARGETS, stats.therapy_targets)
	build_state.set_base(RunBuildState.PICKUP_RANGE, stats.pickup_range)
	build_state.set_base(RunBuildState.ACTIVE_COOLDOWN, stats.ability_cooldown_multiplier)
	build_state.set_base(RunBuildState.FINDING_PROGRESS, stats.finding_progress_multiplier)
	build_state.set_base(RunBuildState.SUPPORT_EFFECT, stats.support_effect_multiplier)
	build_state.set_base(RunBuildState.MOVEMENT_SPEED, stats.movement_speed)
	var equipped_abilities: Array[AbilityDefinition] = []
	if not selected_level.is_tutorial:
		for id in active_loadout.ability_ids:
			var ability: AbilityDefinition = ability_definitions.get(id)
			if ability != null:
				equipped_abilities.append(ability)
	if stats.has_method("bind_run_build"):
		stats.call("bind_run_build", build_state, treatment, equipped_abilities)
	if selected_level.is_tutorial:
		stats.refresh_resolved_run_build()
		treatment_controller.enabled = false
		ability_controller.clear()
		return
	var talent_context := active_run_context
	var damage_rank := talent_context.talent_rank(&"treatment_damage_training") if talent_context != null else 0
	var spread_rank := talent_context.talent_rank(&"spread_penetration") if talent_context != null else 0
	var persistence_rank := talent_context.talent_rank(&"piercing_persistence") if talent_context != null else 0
	var manual_rank := talent_context.talent_rank(&"manual_treatment_aim") if talent_context != null else 0
	if damage_rank > 0:
		build_state.add_modifier_dictionary(&"talent_treatment_damage_training", 0, {
			"stat_id": RunBuildState.TREATMENT_DAMAGE,
			"operation": &"add",
			"value": TalentDefinition.magnitude_for(&"treatment_damage_training", 2.0) * float(damage_rank),
			"required_tags": PackedStringArray(["treatment"]),
		})
	if treatment.id == &"treatment_spread" and spread_rank > 0:
		build_state.set_base(RunBuildState.TREATMENT_MAX_HITS, float(treatment.max_hits + spread_rank))
	if treatment.id == &"treatment_pierce":
		build_state.set_base(RunBuildState.TREATMENT_BEAM_DURATION, float(persistence_rank) * 0.5)
		build_state.set_base(RunBuildState.TREATMENT_BEAM_TICK, 0.25)
		build_state.set_base(RunBuildState.TREATMENT_BEAM_RETURN, 0.0)
	build_state.set_base(RunBuildState.TREATMENT_MANUAL_AIM, 1.0 if manual_rank > 0 else 0.0)
	stats.refresh_resolved_run_build()
	treatment_controller.configure(treatment, build_state, topology, avatar, _treatment_candidates, ability_controller)
	treatment_controller.configure_manual_aim(_treatment_aim_world_position, manual_rank > 0)
	treatment_controller.enabled = true
	ability_controller.configure(build_state, topology, avatar, func() -> Array: return enemies, func() -> Array: return pickups, state)
	ability_controller.configure_queries(combat_query, pickup_query)
	var ability_views: Array = []
	for slot in range(mini(active_loadout.ability_ids.size(), 2)):
		var ability: AbilityDefinition = ability_definitions.get(active_loadout.ability_ids[slot])
		if ability != null and ability_controller.equip(slot, ability):
			ability_views.append(_ability_hud_view(ability))
	hud.configure_active_abilities(ability_views)
	var finding: FindingDefinition = finding_definitions.get(active_run_context.hidden_finding_id) if active_run_context != null else null
	if finding != null:
		finding_controller.configure(finding, maxi(1, selected_level.finding_progress_target))
	else:
		hud.hide_finding_progress()

func _ability_hud_view(definition: AbilityDefinition) -> Dictionary:
	if definition == null:
		return {}
	var rows: Array[Dictionary] = []
	var cooldown := definition.cooldown
	if build_state != null:
		cooldown *= build_state.value(RunBuildState.ACTIVE_COOLDOWN, 1.0, definition.tags)
	rows.append({"label": "Abklingzeit", "value": "%s s" % _hud_number(cooldown, 1)})
	var values := definition.parameters
	if values.has("damage"):
		var damage := float(values.get("damage", 0.0))
		if build_state != null:
			damage = build_state.value(RunBuildState.ABILITY_DAMAGE, damage, definition.tags)
		rows.append({"label": "Schaden", "value": _hud_number(damage)})
		if definition.damage_profile != null:
			for type_id in DamageTypeCatalog.ALL_IDS:
				var weight := definition.damage_profile.weight_for_type(type_id)
				if weight <= 0.0001:
					continue
				rows.append({
					"label": "",
					"value": "%d %%" % roundi(weight * 100.0),
					"icon_kind": AlveolusVisualTheme.damage_type_icon_kind(type_id),
					"accessible_label": "%s-Schaden" % DamageTypeCatalog.display_name(type_id),
				})
	if values.has("recovery"):
		var recovery := float(values.get("recovery", 0.0))
		if build_state != null:
			recovery = build_state.value(RunBuildState.ABILITY_RECOVERY, recovery, definition.tags)
		rows.append({"label": "Heilung", "value": _hud_number(recovery)})
	if values.has("shield"):
		var shield := float(values.get("shield", 0.0))
		if build_state != null:
			shield = build_state.value(RunBuildState.ABILITY_SHIELD, shield, definition.tags)
		rows.append({"label": "Schild", "value": _hud_number(shield)})
	if values.has("range"):
		var range_value := float(values.get("range", 0.0))
		if build_state != null:
			range_value = build_state.value(RunBuildState.ABILITY_RANGE, range_value, definition.tags)
		rows.append({"label": "Reichweite", "value": str(CombatDistanceScale.stage_from_world(range_value))})
	if values.has("radius"):
		var radius := float(values.get("radius", 0.0))
		if build_state != null:
			radius = build_state.value(RunBuildState.ABILITY_RADIUS, radius, definition.tags)
		rows.append({"label": "Radius", "value": str(CombatDistanceScale.stage_from_world(radius))})
	if values.has("projectiles"):
		rows.append({"label": "Projektile", "value": str(int(values.get("projectiles", 1)))})
	return {
		"id": definition.id,
		"display_name": definition.display_name,
		"description": definition.description,
		"cooldown_total": cooldown,
		"fact_rows": rows,
	}

func _active_ability_hud_views() -> Array:
	var result: Array = []
	if active_loadout == null:
		return result
	for id in active_loadout.ability_ids.slice(0, 2):
		var definition: AbilityDefinition = ability_definitions.get(id)
		if definition != null:
			result.append(_ability_hud_view(definition))
	return result

func _hud_number(value: float, decimals: int = 0) -> String:
	if decimals <= 0 or is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return ("%.*f" % [decimals, value]).replace(".", ",")

func _spawn_step(delta: float) -> void:
	_drain_deferred_spawns(8)
	if selected_level.is_tutorial or stress_test:
		return
	_offscreen_relocation_step(delta)
	if state.boss_spawned or enemies.size() >= 220:
		return
	spawn_accumulator -= delta
	if spawn_accumulator > 0.0:
		return
	var progress := clampf(state.elapsed / config.run_duration_seconds, 0.0, 1.0)
	var interval := lerpf(config.initial_spawn_interval, config.final_spawn_interval, pow(progress, 0.82))
	var finding := _active_finding()
	if finding != null and finding.behavior == FindingDefinition.Behavior.ACCELERATION and progress >= 0.5:
		var late_factor := inverse_lerp(0.5, 1.0, progress)
		interval *= lerpf(1.0, 1.0 - finding.magnitude, late_factor)
	interval /= maxf(config.spawn_rate_multiplier, 0.01)
	spawn_accumulator += interval
	var batch := 1
	if progress > 0.58 and rng.randf() < 0.22:
		batch = 2
	for index in range(batch):
		var type: StringName = &"pneumococcus"
		var cluster_chance := lerpf(config.cluster_chance_start, config.cluster_chance_end, progress)
		if finding != null and finding.behavior == FindingDefinition.Behavior.GROUPING:
			cluster_chance = clampf(cluster_chance + finding.magnitude, 0.0, 0.85)
		if discovery_manager.has_seen(&"pneumococcus") and rng.randf() < cluster_chance:
			type = &"bacterial_cluster"
		_spawn_enemy(type, _wave_spawn_position_around_avatar(rng.randf_range(500.0, 620.0), _enemy_body_radius(type)))

func _drain_deferred_spawns(maximum_per_tick: int) -> void:
	var emitted := 0
	while deferred_spawn_cursor < deferred_spawn_requests.size() and emitted < maximum_per_tick:
		var request := deferred_spawn_requests[deferred_spawn_cursor]
		if request == null or not request.is_valid() or not enemy_definitions.has(request.definition_id):
			deferred_spawn_cursor += 1
			continue
		var critical := request.is_critical()
		if not combat_capacity.can_allocate_enemy(enemy_world.regular_count, enemy_world.critical_count, critical):
			break
		var spawned := _spawn_enemy(request.definition_id, request.position, request.health_scale, critical, false, request)
		if spawned == null:
			break
		deferred_spawn_cursor += 1
		emitted += 1
	if deferred_spawn_cursor >= deferred_spawn_requests.size():
		deferred_spawn_requests.clear()
		deferred_spawn_cursor = 0
	elif deferred_spawn_cursor >= 512:
		deferred_spawn_requests = deferred_spawn_requests.slice(deferred_spawn_cursor)
		deferred_spawn_cursor = 0

func _therapy_step(delta: float) -> void:
	therapy_timer -= delta
	if therapy_timer > 0.0:
		return
	therapy_timer += stats.therapy_cooldown
	# The tutorial uses this lightweight legacy firing path, but projectile
	# upgrades must retain the same meaning as the normal treatment strategy.
	# Each acquired Impuls projectile therefore selects one distinct target.
	var targets := _nearest_targets(stats.therapy_range, stats.therapy_projectiles)
	if not targets.is_empty():
		avatar.show_treatment_impulse()
	for enemy in targets:
		if projectiles.size() >= MAX_ACTIVE_PROJECTILES:
			enemy.take_damage(stats.therapy_damage, &"therapy")
			continue
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
		projectile.configure(
			enemy,
			stats.therapy_damage,
			topology,
			not discovery_manager.has_seen(&"automatic_therapy"),
			&"therapy",
			enemy_world.handle_for(enemy),
			enemy_world.resolve,
			TherapyProjectile.DEFAULT_SPEED
		)
		projectile.global_position = avatar.global_position
		projectile.reset_physics_interpolation()
		projectile.set_physics_process(false)
		var projectile_handle := projectile_world.register_projectile(projectile)
		if not EntityHandle.is_valid(projectile_handle):
			_store_projectile(projectile)
			enemy.take_damage(stats.therapy_damage, &"therapy")
			continue
		if projectile_renderer == null or not projectile_renderer.register_projectile(projectile, projectile_handle, projectile.discovery_pending):
			projectile_world.release(projectile_handle, false)
			_store_projectile(projectile)
			enemy.take_damage(stats.therapy_damage, &"therapy")
			continue
		projectiles.append(projectile)

func _on_treatment_shots_requested(shots: Array[TreatmentShot]) -> void:
	if flow_state != GameFlowState.State.RUNNING or state == null or not state.active:
		return
	if not shots.is_empty():
		avatar.show_treatment_impulse()
	for shot in shots:
		if shot == null:
			continue
		if shot.mode == TreatmentShot.Mode.TRACKING and is_instance_valid(shot.target):
			if projectiles.size() >= MAX_ACTIVE_PROJECTILES:
				shot.target.take_damage(_resolved_treatment_damage(shot.damage, shot.target), shot.source_id)
				continue
			var projectile: TherapyProjectile
			if not projectile_pool.is_empty():
				projectile = projectile_pool.pop_back()
			else:
				projectile = TherapyProjectile.new()
				projectile.z_index = 6
				projectile.finished.connect(_on_projectile_finished)
				projectile.discovery_ready.connect(_on_projectile_discovery_ready)
				simulation_root.add_child(projectile)
			projectile.global_position = shot.origin
			projectile.configure(
				shot.target,
				_resolved_treatment_damage(shot.damage, shot.target),
				topology,
				false,
				shot.source_id,
				enemy_world.handle_for(shot.target),
				enemy_world.resolve
			)
			projectile.global_position = shot.origin
			projectile.reset_physics_interpolation()
			projectile.set_physics_process(false)
			var projectile_handle := projectile_world.register_projectile(projectile)
			if not EntityHandle.is_valid(projectile_handle):
				_store_projectile(projectile)
				shot.target.take_damage(_resolved_treatment_damage(shot.damage, shot.target), shot.source_id)
				continue
			if projectile_renderer == null or not projectile_renderer.register_projectile(projectile, projectile_handle, projectile.discovery_pending):
				projectile_world.release(projectile_handle, false)
				_store_projectile(projectile)
				shot.target.take_damage(_resolved_treatment_damage(shot.damage, shot.target), shot.source_id)
				continue
			projectiles.append(projectile)
		elif shot.mode == TreatmentShot.Mode.LINE or shot.mode == TreatmentShot.Mode.DIRECTIONAL:
			var beam_duration := 0.0
			if shot.source_id == &"treatment_pierce" and build_state != null:
				beam_duration = build_state.value(RunBuildState.TREATMENT_BEAM_DURATION, 0.0, PackedStringArray(["piercing"]))
			if beam_duration > 0.0 and shot.mode == TreatmentShot.Mode.LINE:
				_spawn_treatment_beam(shot, beam_duration)
				continue
			# Resolve once. Damage and feedback consume this exact generation-safe
			# snapshot, including each spread ray's independent shortened endpoint.
			_ensure_combat_query()
			shot.resolve_query_snapshot(combat_query)
			if shot.mode == TreatmentShot.Mode.DIRECTIONAL:
				_spawn_directional_treatment_projectile(shot)
				continue
			for handle in shot.resolved_handles:
				var enemy := enemy_world.resolve(handle) as InfectionEnemy
				if is_instance_valid(enemy) and enemy.is_targetable():
					enemy.take_damage(_resolved_treatment_damage(shot.damage, enemy), shot.source_id)

func _on_treatment_feedback_requested(_treatment_id: StringName, shots: Array[TreatmentShot]) -> void:
	if ability_feedback_world == null:
		return
	# Tracking shots already own a moving ProjectileRenderer visual. Hitscan
	# treatments need a short tracer because their damage resolves immediately.
	for shot in shots:
		if shot != null and shot.mode == TreatmentShot.Mode.LINE and not (
			shot.source_id == &"treatment_pierce"
			and build_state != null
			and build_state.value(RunBuildState.TREATMENT_BEAM_DURATION, 0.0, PackedStringArray(["piercing"])) > 0.0
		):
			ability_feedback_world.spawn_treatment_shot(shot)

func _spawn_directional_treatment_projectile(shot: TreatmentShot) -> void:
	var target: InfectionEnemy = null
	var target_handle := EntityHandle.INVALID
	if not shot.resolved_handles.is_empty():
		target_handle = int(shot.resolved_handles[0])
		target = enemy_world.resolve(target_handle) as InfectionEnemy
	var resolved_damage := _resolved_treatment_damage(shot.damage, target) if is_instance_valid(target) else shot.damage
	if projectiles.size() >= MAX_ACTIVE_PROJECTILES:
		if is_instance_valid(target) and target.is_targetable():
			target.take_damage(resolved_damage, shot.source_id)
		return
	var projectile: TherapyProjectile
	if not projectile_pool.is_empty():
		projectile = projectile_pool.pop_back()
	else:
		projectile = TherapyProjectile.new()
		projectile.z_index = 6
		projectile.finished.connect(_on_projectile_finished)
		projectile.discovery_ready.connect(_on_projectile_discovery_ready)
		simulation_root.add_child(projectile)
	projectile.global_position = shot.origin
	projectile.configure_directional(
		shot.direction,
		resolved_damage,
		topology,
		shot.requested_range_value,
		shot.impact_distance,
		target,
		target_handle,
		enemy_world.resolve,
		shot.source_id
	)
	projectile.global_position = shot.origin
	projectile.reset_visual_motion()
	var projectile_handle := projectile_world.register_projectile(projectile)
	if not EntityHandle.is_valid(projectile_handle):
		_store_projectile(projectile)
		if is_instance_valid(target) and target.is_targetable():
			target.take_damage(resolved_damage, shot.source_id)
		return
	if projectile_renderer == null or not projectile_renderer.register_projectile(projectile, projectile_handle, false):
		projectile_world.release(projectile_handle, false)
		_store_projectile(projectile)
		if is_instance_valid(target) and target.is_targetable():
			target.take_damage(resolved_damage, shot.source_id)
		return
	projectiles.append(projectile)


func _on_enemy_projectile_requested(source_handle: int, pattern: int, phase: float, role: int) -> void:
	if enemy_world == null or projectile_world == null or hostile_projectile_renderer == null:
		return
	var source := enemy_world.resolve(source_handle) as InfectionEnemy
	if not is_instance_valid(source) or not source.is_targetable() or source.definition == null or not is_instance_valid(avatar):
		return
	if projectiles.size() >= MAX_ACTIVE_PROJECTILES:
		return
	var heading := topology.shortest_delta(source.global_position, avatar.global_position).normalized()
	if heading.length_squared() <= 0.0001:
		heading = Vector2.RIGHT
	var amount := source.definition.projectile_damage * source.damage_multiplier
	var move_speed := 230.0
	if role == EnemyAttackDirector.Role.PHASE_ADD:
		amount = source.definition.base_damage * source.damage_multiplier * 0.75
		move_speed = 215.0
	elif role == EnemyAttackDirector.Role.MINOR_FOCUS:
		move_speed = 205.0
	elif role == EnemyAttackDirector.Role.BOSS:
		amount *= config.boss_projectile_damage_multiplier
		move_speed = 250.0
	amount = float(roundi(amount))
	if amount <= 0.0:
		return
	var projectile: TherapyProjectile
	if not projectile_pool.is_empty():
		projectile = projectile_pool.pop_back()
	else:
		projectile = TherapyProjectile.new()
		projectile.z_index = 7
		projectile.finished.connect(_on_projectile_finished)
		projectile.discovery_ready.connect(_on_projectile_discovery_ready)
		simulation_root.add_child(projectile)
	if not projectile.hostile_hit.is_connected(_on_hostile_projectile_hit):
		projectile.hostile_hit.connect(_on_hostile_projectile_hit)
	projectile.global_position = source.global_position
	projectile.configure_hostile(
		heading,
		amount,
		topology,
		avatar,
		source.definition.damage_profile,
		TherapyProjectile.HOSTILE_DIAMOND if pattern == EnemyAttackDirector.Pattern.DIAMOND else TherapyProjectile.HOSTILE_NORMAL,
		phase,
		move_speed,
		1050.0,
		config.boss_wave_amplitude if role == EnemyAttackDirector.Role.BOSS else 44.0
	)
	projectile.global_position = source.global_position
	projectile.reset_visual_motion()
	var projectile_handle := projectile_world.register_projectile(projectile)
	if not EntityHandle.is_valid(projectile_handle):
		_store_projectile(projectile)
		return
	if not hostile_projectile_renderer.register_projectile(projectile, projectile_handle, false):
		projectile_world.release(projectile_handle, false)
		_store_projectile(projectile)
		return
	projectiles.append(projectile)


func _on_hostile_projectile_hit(_projectile: TherapyProjectile, amount: float, profile: DamageProfile) -> void:
	_apply_incoming_damage(amount, profile)


func _on_enemy_reinforcements_requested(source_handle: int, count: int) -> void:
	if not EntityHandle.is_valid(source_handle) or count <= 0 or enemy_world == null:
		return
	var source := enemy_world.resolve(source_handle) as InfectionEnemy
	if not is_instance_valid(source) or not source.is_targetable():
		return
	if _fixed_step_active:
		run_session.event_queue.push(&"minions_requested", source_handle, EntityHandle.INVALID, float(count), source.global_position)
		return
	_apply_minions_requested(source.global_position, count, source_handle)

func _spawn_treatment_beam(shot: TreatmentShot, duration: float) -> void:
	if treatment_beam_world == null:
		return
	var tick_interval := build_state.value(RunBuildState.TREATMENT_BEAM_TICK, 0.25, PackedStringArray(["piercing"]))
	var returns := build_state.value(RunBuildState.TREATMENT_BEAM_RETURN, 0.0, PackedStringArray(["piercing"])) >= 0.5
	var handle := treatment_beam_world.spawn(
		shot.origin, shot.direction, shot.requested_range_value, shot.hit_radius * 2.0,
		shot.damage, duration, tick_interval, returns, shot.source_id
	)
	if not EntityHandle.is_valid(handle):
		shot.resolve_query_snapshot(combat_query)
		for enemy_handle in shot.resolved_handles:
			var fallback_enemy := enemy_world.resolve(enemy_handle) as InfectionEnemy
			if is_instance_valid(fallback_enemy) and fallback_enemy.is_targetable():
				fallback_enemy.take_damage(_resolved_treatment_damage(shot.damage, fallback_enemy), shot.source_id)
		return
	var beam := treatment_beam_world.resolve(handle)
	if beam == null:
		return
	treatment_beam_return_visualized[handle] = false
	if ability_feedback_world != null:
		ability_feedback_world.spawn(
			shot.source_id, shot.origin, shot.origin + shot.direction * beam.length,
			shot.direction, 0.0, beam.length, shot.hit_radius * 2.0, duration
		)

func _on_treatment_beam_tick(handle: int, enemy_handles: PackedInt64Array, is_return: bool) -> void:
	var beam := treatment_beam_world.resolve(handle) if treatment_beam_world != null else null
	if beam == null:
		return
	if is_return and not bool(treatment_beam_return_visualized.get(handle, false)):
		treatment_beam_return_visualized[handle] = true
		if ability_feedback_world != null:
			var return_origin := beam.phase_origin(topology)
			var return_direction := beam.phase_direction()
			ability_feedback_world.spawn(
				beam.source_id, return_origin, return_origin + return_direction * beam.length,
				return_direction, 0.0, beam.length, beam.width, beam.duration
			)
	for enemy_handle in enemy_handles:
		var enemy := enemy_world.resolve(enemy_handle) as InfectionEnemy
		if is_instance_valid(enemy) and enemy.is_targetable():
			enemy.take_damage(_resolved_treatment_damage(beam.damage, enemy), beam.source_id)

func _on_treatment_beam_finished(handle: int) -> void:
	treatment_beam_return_visualized.erase(handle)

func _treatment_aim_world_position() -> Vector2:
	return get_global_mouse_position()

func _on_treatment_fired(_treatment_id: StringName) -> void:
	if not selected_level.is_tutorial and discovery_manager.request(&"automatic_therapy", avatar):
		_try_present_next_discovery()

func _resolved_treatment_damage(base_damage: float, enemy: InfectionEnemy) -> float:
	if enemy == null or enemy.definition == null:
		return base_damage
	var result := base_damage
	if build_state != null and enemy.definition.id == &"bacterial_cluster":
		result *= build_state.value(&"group_area_effect", 1.0)
	if build_state != null and enemy.definition.id == &"minor_focus":
		result *= build_state.value(&"nest_damage", 1.0)
	var profile := stats.prepared_treatment.damage_profile if stats != null and stats.prepared_treatment != null else null
	return CombatDamageResolver.resolve_against_enemy(result, profile, enemy)

func _on_projectile_discovery_ready(projectile: TherapyProjectile) -> void:
	if selected_level != null and selected_level.is_tutorial:
		discovery_manager.mark_seen(&"automatic_therapy")
		return
	if discovery_manager.request(&"automatic_therapy", projectile):
		_try_present_next_discovery()

func _immune_step(delta: float) -> void:
	if defense_cell_world == null:
		return
	if stats.immune_level <= 0:
		defense_cell_world.clear()
		return
	var count := stats.immune_cell_count()
	var orbit_radius := stats.immune_orbit_radius()
	var collision_radius := DefenseCellWorld.DEFAULT_HIT_RADIUS
	var damage := stats.immune_damage
	var hit_interval := stats.immune_interval()
	if build_state != null:
		count = maxi(1, roundi(build_state.value(RunBuildState.DEFENSE_CELL_PROJECTILES, float(count), PackedStringArray(["defense_cell"]))))
		orbit_radius = build_state.value(RunBuildState.DEFENSE_CELL_RADIUS, orbit_radius, PackedStringArray(["defense_cell"]))
		damage = build_state.value(RunBuildState.DEFENSE_CELL_DAMAGE, damage, PackedStringArray(["defense_cell"]))
		hit_interval = build_state.value(RunBuildState.DEFENSE_CELL_HIT_INTERVAL, hit_interval, PackedStringArray(["defense_cell"]))
	defense_cell_world.configure_stats(count, orbit_radius, collision_radius, damage, hit_interval)
	_ensure_combat_query()
	defense_cell_world.step_fixed(delta)

func _on_defense_cell_hit(handle: int, damage: float) -> void:
	var enemy := enemy_world.resolve(handle) as InfectionEnemy
	if is_instance_valid(enemy) and enemy.is_targetable():
		var resolved := CombatDamageResolver.resolve_against_enemy(damage, defense_cell_damage_profile, enemy)
		enemy.take_damage(resolved, &"immune")

func _life_regeneration_step(delta: float) -> void:
	if stats == null or state == null or stats.life_regeneration_per_second <= 0.0 or state.stability >= state.max_stability:
		return
	life_regeneration_accumulator += maxf(delta, 0.0)
	if life_regeneration_accumulator < 0.25:
		return
	var elapsed := life_regeneration_accumulator
	life_regeneration_accumulator = 0.0
	var regeneration_multiplier := stats.support_effect_multiplier
	if build_state != null and not selected_level.is_tutorial:
		regeneration_multiplier = build_state.value(RunBuildState.SUPPORT_EFFECT, regeneration_multiplier)
	state.change_stability(stats.life_regeneration_per_second * regeneration_multiplier * elapsed)

func _support_step(delta: float) -> void:
	if stats.support_level <= 0:
		return
	support_timer -= delta
	if support_timer > 0.0:
		return
	support_timer += maxf(3.8, 6.2 - float(stats.support_level) * 0.55)
	var support_multiplier := stats.support_effect_multiplier
	if build_state != null and not selected_level.is_tutorial:
		support_multiplier = build_state.value(RunBuildState.SUPPORT_EFFECT, stats.support_effect_multiplier)
	var recovery := (2.0 + float(stats.support_level) * 2.0) * support_multiplier
	var overflow := maxf(0.0, state.stability + recovery - state.max_stability)
	state.change_stability(recovery)
	if overflow > 0.0 and stats.overheal_shield_cap > 0.0 and ability_controller != null:
		ability_controller.grant_shield_capped(overflow, stats.overheal_shield_cap)

func _intro_step(delta: float) -> void:
	if not selected_level.is_tutorial or state == null or not state.active:
		return
	if intro_phase != &"observe_primary":
		return
	intro_observation_remaining = maxf(0.0, intro_observation_remaining - maxf(delta, 0.0))
	if intro_observation_remaining > 0.0:
		return
	intro_phase = &"await_attack_confirmation"
	intro_confirmation_kind = INTRO_CONFIRM_ATTACK
	_set_intro_prompt("Du greifst automatisch an.", &"normal", true, "Linksklick zum Fortfahren")
	_set_flow(GameFlowState.State.INTRO_CONFIRMATION)


func intro_prompt_snapshot() -> Dictionary:
	return {
		"text": intro_prompt_text,
		"semantic_mode": intro_prompt_semantic_mode,
		"requires_left_click": intro_prompt_requires_left_click,
		"mouse_hint": intro_prompt_mouse_hint,
	}


func _set_intro_prompt(text: String, semantic_mode: StringName, requires_left_click: bool, mouse_hint: String) -> void:
	intro_prompt_text = text
	intro_prompt_semantic_mode = &"coral" if semantic_mode == &"coral" else &"normal"
	intro_prompt_requires_left_click = requires_left_click
	intro_prompt_mouse_hint = mouse_hint
	if hud == null:
		return
	if text.is_empty():
		if hud.has_method(&"hide_run_prompt"):
			hud.call(&"hide_run_prompt")
		return
	if hud.has_method(&"show_run_prompt"):
		hud.call(&"show_run_prompt", text, intro_prompt_semantic_mode, requires_left_click, mouse_hint)


func _on_run_prompt_confirmed() -> void:
	if flow_state != GameFlowState.State.INTRO_CONFIRMATION or not intro_prompt_requires_left_click:
		return
	var confirmation := intro_confirmation_kind
	if confirmation not in [INTRO_CONFIRM_ATTACK, INTRO_CONFIRM_BOSS]:
		return
	intro_confirmation_kind = &""
	_set_intro_prompt("", &"normal", false, "")
	match confirmation:
		INTRO_CONFIRM_ATTACK:
			intro_phase = &"await_primary_defeat"
			intro_autoattack_enabled = true
			therapy_timer = 0.12
			discovery_manager.mark_seen(&"automatic_therapy")
			meta.set_tutorial_step(&"automatic_therapy")
		INTRO_CONFIRM_BOSS:
			intro_phase = &"boss_active"
			intro_autoattack_enabled = true
		_:
			return
	_set_flow(GameFlowState.State.RUNNING)

func _spawn_enemy(
	type: StringName,
	spawn_position: Vector2,
	health_scale_override: float = -1.0,
	critical_spawn: bool = false,
	defer_if_full: bool = true,
	spawn_request: EnemySpawnRequest = null
) -> InfectionEnemy:
	if not enemy_definitions.has(type):
		return null
	var definition: EnemyDefinition = enemy_definitions[type]
	var critical := critical_spawn or definition.is_boss
	var progress := 0.0 if state == null or config.event_driven_intro else clampf(state.elapsed / maxf(config.run_duration_seconds, 0.001), 0.0, 1.0)
	var health_scale := lerpf(config.enemy_health_start, config.enemy_health_end, progress)
	var movement_scale := spawn_request.movement_scale if spawn_request != null else config.enemy_speed_multiplier
	var damage_scale := spawn_request.contact_scale if spawn_request != null else config.contact_damage_multiplier
	var phases := spawn_request.boss_phases.duplicate() if spawn_request != null else PackedInt32Array()
	if definition.is_boss:
		health_scale = config.boss_health_multiplier
		if spawn_request == null:
			phases = config.boss_phase_minions
	if health_scale_override > 0.0:
		health_scale = health_scale_override
	if not combat_capacity.can_allocate_enemy(enemy_world.regular_count, enemy_world.critical_count, critical):
		if defer_if_full and deferred_spawn_requests.size() - deferred_spawn_cursor < 2048:
			if spawn_request != null:
				deferred_spawn_requests.append(spawn_request.duplicate_request())
			else:
				deferred_spawn_requests.append(EnemySpawnRequest.create(
					type,
					spawn_position,
					definition.visual_id,
					health_scale,
					movement_scale,
					damage_scale,
					phases,
					EnemySpawnRequest.Priority.CRITICAL if critical else EnemySpawnRequest.Priority.REGULAR
				))
		return null
	var resolved_spawn_position := spawn_position
	var force_detailed_discovery := discovery_manager != null and not discovery_manager.has_seen(definition.discovery_id) and not discovery_spawn_reservations.has(definition.discovery_id)
	if force_detailed_discovery:
		resolved_spawn_position = _visible_discovery_spawn_position(definition.radius)
		discovery_spawn_reservations[definition.discovery_id] = true
	var bounded_position := topology.resolve_position(resolved_spawn_position, definition.radius)
	var enemy: InfectionEnemy
	if not enemy_pool.is_empty():
		enemy = enemy_pool.pop_back()
	else:
		enemy = InfectionEnemy.new()
		enemy.z_index = 2
		enemy.defeated.connect(_on_enemy_defeated)
		enemy.pressure_applied.connect(_on_pressure_applied.bind(enemy))
		enemy.minions_requested.connect(_on_minions_requested.bind(enemy))
		enemy.damage_feedback.connect(_on_enemy_damage_feedback)
		enemy.health_changed.connect(_on_enemy_health_changed.bind(enemy))
		enemy.boss_phase_changed.connect(_on_boss_phase_changed.bind(enemy))
		enemy.materialized.connect(_on_enemy_materialized)
		enemy.damage_applied.connect(_on_enemy_damage_applied)
		simulation_root.add_child(enemy)
	enemy.global_position = bounded_position
	enemy.configure(
		definition,
		avatar,
		topology,
		health_scale,
		movement_scale,
		damage_scale,
		phases,
		enemy_runtime_resistance_profiles.get(type) as ResistanceProfile,
		config.enemy_defense
	)
	_apply_group_control_to_enemy(enemy)
	enemy.global_position = bounded_position
	enemy.reset_physics_interpolation()
	enemy.set_physics_process(false)
	var world_handle := enemy_world.register_enemy(enemy, critical)
	if not EntityHandle.is_valid(world_handle):
		enemy.recycle()
		if enemy_pool.size() < MAX_ENEMY_POOL:
			enemy_pool.append(enemy)
		return null
	_combat_query_dirty = true
	enemies.append(enemy)
	crowd_renderer.register_enemy(enemy, force_detailed_discovery)
	if enemy_attack_director != null and definition.id == &"minor_focus":
		enemy_attack_director.register_enemy(world_handle, EnemyAttackDirector.Role.MINOR_FOCUS)
	_apply_enemy_spawn_metadata(enemy, spawn_request)
	return enemy

func _apply_enemy_spawn_metadata(enemy: InfectionEnemy, request: EnemySpawnRequest) -> void:
	if enemy == null or request == null:
		return
	if request.source_id == &"hidden_nest":
		hidden_nest_timers[enemy] = maxf(0.1, float(request.metadata.get("release_after_seconds", 20.0)))
	if bool(request.metadata.get("ranged_shooter", false)) and enemy_attack_director != null and enemy_world != null:
		var handle := enemy_world.handle_for(enemy)
		if EntityHandle.is_valid(handle):
			enemy_attack_director.register_enemy(handle, EnemyAttackDirector.Role.PHASE_ADD)

func _spawn_boss() -> void:
	if state == null or not state.active:
		return
	active_boss_handles.clear()
	active_boss_handle_by_instance.clear()
	active_boss_phase_by_handle.clear()
	active_boss = null
	boss_aggregate_maximum = 0.0
	boss_aggregate_phase = 0
	for boss_index in range(maxi(1, config.boss_count)):
		var request := EnemySpawnRequest.create(
			config.boss_enemy_id,
			_spawn_position_around_avatar(600.0 + float(boss_index) * 36.0, _enemy_body_radius(config.boss_enemy_id)),
			&"infection_focus",
			config.boss_health_multiplier,
			config.enemy_speed_multiplier * config.boss_speed_multiplier,
			config.contact_damage_multiplier,
			config.boss_phase_minions,
			EnemySpawnRequest.Priority.CRITICAL,
			&"boss"
		)
		var boss := _spawn_enemy(
			config.boss_enemy_id,
			request.position,
			-1.0,
			true,
			false,
			request
		)
		if boss == null:
			continue
		_register_active_boss(boss)
		if selected_level.is_tutorial:
			intro_enemy_roles[boss] = INTRO_ROLE_BOSS
	if active_boss != null:
		mastery_tracker.record_boss_spawned(state.elapsed)
		_show_active_boss_hud()
	if selected_level.is_tutorial and active_boss != null:
		intro_lesson = 3
		intro_phase = &"await_boss_confirmation"
		intro_autoattack_enabled = false
		intro_confirmation_kind = INTRO_CONFIRM_BOSS
		discovery_manager.mark_seen(&"infection_focus")
		_set_intro_prompt("Infektionsherd erkannt", &"coral", true, "Linksklick zum Fortfahren")
		_set_flow(GameFlowState.State.INTRO_CONFIRMATION)


func _register_active_boss(enemy: InfectionEnemy) -> void:
	if enemy == null or enemy_world == null:
		return
	var handle := enemy_world.handle_for(enemy)
	if not EntityHandle.is_valid(handle) or active_boss_handles.has(handle):
		return
	active_boss_handles.append(handle)
	active_boss_handle_by_instance[enemy.get_instance_id()] = handle
	active_boss_phase_by_handle[handle] = 0
	boss_aggregate_maximum += maxf(enemy.max_health, 0.0)
	if enemy_attack_director != null and config.boss_ranged_enabled:
		enemy_attack_director.register_enemy(handle, EnemyAttackDirector.Role.BOSS)
	if active_boss == null:
		active_boss = enemy


func _remove_active_boss(enemy: InfectionEnemy) -> bool:
	if enemy == null:
		return false
	var handle := int(active_boss_handle_by_instance.get(enemy.get_instance_id(), EntityHandle.INVALID))
	active_boss_handle_by_instance.erase(enemy.get_instance_id())
	active_boss_phase_by_handle.erase(handle)
	var index := active_boss_handles.find(handle)
	if index >= 0:
		active_boss_handles.remove_at(index)
	_refresh_active_boss_reference()
	return index >= 0


func _refresh_active_boss_reference() -> void:
	active_boss = null
	for handle in active_boss_handles:
		var enemy := enemy_world.resolve(handle) as InfectionEnemy
		if is_instance_valid(enemy):
			active_boss = enemy
			return


func active_boss_health_snapshot() -> Dictionary:
	var current := 0.0
	var maximum := boss_aggregate_maximum
	var remaining := 0
	if enemy_world != null:
		for handle in active_boss_handles:
			var enemy := enemy_world.resolve(handle) as InfectionEnemy
			if not is_instance_valid(enemy):
				continue
			current += maxf(enemy.health, 0.0)
			remaining += 1
	return {
		"current": current,
		"maximum": maximum,
		"remaining": remaining,
		"target": state.boss_count_target if state != null else maxi(1, config.boss_count),
	}


func active_boss_handle_snapshot() -> PackedInt64Array:
	return active_boss_handles.duplicate()


func _show_active_boss_hud() -> void:
	var snapshot := active_boss_health_snapshot()
	var maximum := float(snapshot.get("maximum", 0.0))
	if maximum <= 0.0:
		return
	var boss_title := "Infektionsherd"
	var boss_definition := enemy_definitions.get(config.boss_enemy_id) as EnemyDefinition
	if boss_definition != null:
		boss_title = boss_definition.display_name
	hud.set_boss_title(boss_title)
	hud.show_boss(maximum, config.boss_phase_minions.size())
	hud.update_boss_health(float(snapshot.get("current", 0.0)), maximum)
	if boss_aggregate_phase > 0:
		hud.show_boss_phase(boss_aggregate_phase)

func _on_minions_requested(origin: Vector2, count: int, source_enemy: InfectionEnemy = null) -> void:
	var source_handle := enemy_world.handle_for(source_enemy) if enemy_world != null and is_instance_valid(source_enemy) else EntityHandle.INVALID
	if _fixed_step_active:
		run_session.event_queue.push(&"minions_requested", source_handle, EntityHandle.INVALID, float(count), origin)
		return
	_apply_minions_requested(origin, count, source_handle)

func _apply_minions_requested(origin: Vector2, count: int, source_handle: int = EntityHandle.INVALID) -> void:
	if state == null or not state.active:
		return
	var progress := 0.0 if config.event_driven_intro else clampf(state.elapsed / maxf(config.run_duration_seconds, 0.001), 0.0, 1.0)
	var health_scale := lerpf(config.enemy_health_start, config.enemy_health_end, progress)
	for index in range(count):
		var angle := TAU * float(index) / float(maxi(count, 1)) + rng.randf_range(-0.22, 0.22)
		var position := topology.wrap_position(origin + Vector2.from_angle(angle) * rng.randf_range(88.0, 130.0))
		var request := EnemySpawnRequest.create(
			&"pneumococcus",
			position,
			&"pneumococcus",
			health_scale,
			config.enemy_speed_multiplier,
			config.contact_damage_multiplier,
			PackedInt32Array(),
			EnemySpawnRequest.Priority.CRITICAL,
			&"boss_phase_add"
		)
		request.metadata["ranged_shooter"] = EntityHandle.is_valid(source_handle)
		_spawn_enemy(&"pneumococcus", position, health_scale, true, true, request)

func _on_boss_phase_changed(phase: int, enemy: InfectionEnemy) -> void:
	if not is_instance_valid(enemy) or enemy_world == null:
		return
	var handle := int(active_boss_handle_by_instance.get(enemy.get_instance_id(), EntityHandle.INVALID))
	if not EntityHandle.is_valid(handle) or enemy_world.resolve(handle) != enemy:
		return
	var previous_phase := int(active_boss_phase_by_handle.get(handle, 0))
	if phase <= previous_phase:
		return
	active_boss_phase_by_handle[handle] = phase
	if enemy_attack_director != null:
		enemy_attack_director.set_boss_phase(handle, phase)
	if phase > boss_aggregate_phase:
		boss_aggregate_phase = phase
		hud.show_boss_phase(boss_aggregate_phase)
	if discovery_manager.request(&"boss_phases", enemy):
		_try_present_next_discovery()

func _on_enemy_materialized(enemy: InfectionEnemy) -> void:
	if not is_instance_valid(enemy) or enemy.definition == null:
		return
	if selected_level.is_tutorial:
		var intro_role := StringName(intro_enemy_roles.get(enemy, &""))
		if intro_role == INTRO_ROLE_PRIMARY and intro_phase == &"await_primary_materialization":
			intro_phase = &"observe_primary"
			intro_observation_remaining = INTRO_OBSERVATION_SECONDS
			discovery_manager.mark_seen(&"pneumococcus")
			meta.set_tutorial_step(&"pneumococcus")
		elif intro_role in [INTRO_ROLE_FOLLOWUP, INTRO_ROLE_BOSS]:
			discovery_manager.mark_seen(enemy.definition.discovery_id)
		return
	var requested := discovery_manager.request(enemy.definition.discovery_id, enemy, {"tutorial_boss": selected_level.is_tutorial and enemy.definition.is_boss})
	if requested:
		_try_present_next_discovery()

func _on_enemy_damage_applied(enemy: InfectionEnemy, amount: float, source: StringName) -> void:
	var resolved_source := _damage_stat_source(source)
	if resolved_source != &"":
		run_damage_by_source[resolved_source] = float(run_damage_by_source.get(resolved_source, 0.0)) + maxf(amount, 0.0)
	if not selected_level.is_tutorial or source != &"therapy":
		return
	discovery_manager.mark_seen(&"automatic_therapy")

func _damage_stat_source(source: StringName) -> StringName:
	if source in [&"therapy", &"treatment"]:
		return active_loadout.treatment_id if active_loadout != null else &"treatment_precision"
	if source == &"immune":
		return &"defense_cells"
	if source == &"defense_burst":
		return &"ability_defense_burst"
	if source == &"treatment_line":
		return &"ability_treatment_line"
	if source in treatment_definitions or source in ability_definitions:
		return source
	return source

func result_damage_statistics() -> Array[Dictionary]:
	var ordered_ids: Array[StringName] = []
	if active_loadout != null:
		ordered_ids.append(active_loadout.treatment_id)
		for ability_id in active_loadout.ability_ids:
			if ability_id != &"" and not ordered_ids.has(ability_id):
				ordered_ids.append(ability_id)
	if stats != null and stats.immune_level > 0:
		ordered_ids.append(&"defense_cells")
	for source_value in run_damage_by_source:
		var source_id := StringName(source_value)
		if not ordered_ids.has(source_id):
			ordered_ids.append(source_id)
	var result: Array[Dictionary] = []
	for source_id in ordered_ids:
		if source_id == &"":
			continue
		result.append({
			"id": source_id,
			"label": _damage_stat_label(source_id),
			"damage": roundi(float(run_damage_by_source.get(source_id, 0.0))),
		})
	return result

func _damage_stat_label(source_id: StringName) -> String:
	if treatment_definitions.has(source_id):
		return (treatment_definitions[source_id] as TreatmentDefinition).display_name
	if ability_definitions.has(source_id):
		return (ability_definitions[source_id] as AbilityDefinition).display_name
	if source_id == &"defense_cells":
		return "Abwehrzellen"
	return String(source_id).replace("_", " ").capitalize()

func _try_present_next_discovery() -> void:
	if discovery_manager == null or not discovery_manager.active.is_empty():
		return
	if flow_state not in [GameFlowState.State.RUNNING, GameFlowState.State.RESULT, GameFlowState.State.DISCOVERY_PAUSE]:
		return
	if meta != null and not meta.ui_settings.show_discovery_info:
		# The setting suppresses only the modal interruption. Discovery progress
		# remains complete and save-compatible, so re-enabling the option cannot
		# replay a backlog of old information cards.
		while not discovery_manager.queue.is_empty():
			discovery_manager.take_next()
			discovery_manager.complete_active()
		return
	var item := discovery_manager.take_next()
	if item.is_empty():
		return
	if flow_state != GameFlowState.State.DISCOVERY_PAUSE:
		discovery_return_state = flow_state
	_set_flow(GameFlowState.State.DISCOVERY_PAUSE)
	ui_router.open_modal(&"discovery", null, get_viewport().gui_get_focus_owner())
	var definition := discovery_manager.definition(item["id"])
	var override := ""
	var context: Dictionary = item.get("context", {})
	if definition.id == &"infection_focus" and bool(context.get("tutorial_boss", false)):
		override = "Mini-Boss · vereinfachte Variante ohne Phasenschübe."
	hud.show_discovery(definition, item.get("target"), override)

func _on_discovery_dismissed() -> void:
	if flow_state != GameFlowState.State.DISCOVERY_PAUSE or discovery_manager.active.is_empty():
		return
	discovery_manager.complete_active()
	hud.hide_discovery()
	_save_meta()
	if not discovery_manager.queue.is_empty():
		_try_present_next_discovery()
		return
	ui_router.close_modal(get_viewport().gui_get_focus_owner())
	_set_flow(discovery_return_state)
	if discovery_return_state == GameFlowState.State.RESULT:
		return

func _on_discovery_seen(_id: StringName) -> void:
	_save_meta()

func _on_enemy_health_changed(current: float, maximum: float, enemy: InfectionEnemy) -> void:
	if enemy != null and active_boss_handle_by_instance.has(enemy.get_instance_id()):
		var snapshot := active_boss_health_snapshot()
		hud.update_boss_health(float(snapshot.get("current", current)), float(snapshot.get("maximum", maximum)))

func _on_enemy_damage_feedback(_position: Vector2, _amount: float) -> void:
	# Intentionally quiet: damage numbers, hit particles and scale impulses made
	# dense fights visually noisy. The signal remains as a stable extension hook.
	pass

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
	var handle := enemy_world.handle_for(enemy) if enemy_world != null and is_instance_valid(enemy) else EntityHandle.INVALID
	if enemy_attack_director != null and EntityHandle.is_valid(handle):
		enemy_attack_director.release(handle)
	if crowd_renderer != null and is_instance_valid(enemy):
		crowd_renderer.release_enemy(enemy, enemy.activation_generation)
	if enemy_world != null and is_instance_valid(enemy):
		if EntityHandle.is_valid(handle):
			enemy_world.release(handle, _fixed_step_active)
			_combat_query_dirty = true
	if _fixed_step_active:
		run_session.event_queue.push(&"enemy_defeated", handle, EntityHandle.INVALID, float(analysis_value), enemy.global_position, {
			"enemy": enemy,
			"was_boss": was_boss,
		})
		return
	_apply_enemy_defeated(enemy, analysis_value, was_boss)

func _apply_enemy_defeated(enemy: InfectionEnemy, analysis_value: int, was_boss: bool) -> void:
	if not is_instance_valid(enemy) or not enemies.has(enemy):
		return
	var death_position := enemy.global_position
	var intro_role := StringName(intro_enemy_roles.get(enemy, &""))
	enemies.erase(enemy)
	defeats += 1
	if enemy.definition != null and enemy.definition.id == &"minor_focus":
		hidden_nest_timers.erase(enemy)
		if build_state != null:
			var extra_samples := maxi(0, roundi(build_state.value(&"nest_samples", 0.0)))
			analysis_value += extra_samples
			if extra_samples > 0:
				for slot in range(2):
					var runtime := ability_controller.runtime(slot)
					if runtime != null:
						runtime.reduce(1.0)
	var spawned_pickup := _spawn_analysis_pickup(analysis_value, death_position, false)
	if selected_level.is_tutorial:
		if intro_role in [INTRO_ROLE_PRIMARY, INTRO_ROLE_FOLLOWUP] and spawned_pickup != null:
			intro_pickup_roles[spawned_pickup] = intro_role
		if intro_role == INTRO_ROLE_PRIMARY:
			intro_primary_enemy = null
			intro_phase = &"await_primary_pickup"
			intro_autoattack_enabled = false
			_set_intro_prompt("Geh nah ran, um die EXP einzusammeln.", &"normal", false, "")
		elif intro_role == INTRO_ROLE_FOLLOWUP:
			intro_followup_defeats += 1
		intro_enemy_roles.erase(enemy)
	if was_boss:
		_remove_active_boss(enemy)
		var final_boss_defeated := state.mark_boss_defeated()
		if final_boss_defeated:
			mastery_tracker.record_boss_defeated(state.elapsed if state != null else 0.0)
		else:
			_show_active_boss_hud()
	if state != null and state.active:
		_refresh_defeat_research_preview()
	_store_enemy(enemy)


func _spawn_intro_followups() -> void:
	intro_phase = &"followup_combat"
	intro_lesson = 2
	intro_autoattack_enabled = true
	therapy_timer = 0.12
	_set_intro_prompt("", &"normal", false, "")
	for index in range(INTRO_FOLLOWUP_ENEMY_COUNT):
		var enemy := _spawn_enemy(
			&"pneumococcus",
			_spawn_position_around_avatar(390.0 + float(index) * 36.0, _enemy_body_radius(&"pneumococcus")),
			0.55,
			true,
			false
		)
		if enemy != null:
			intro_enemy_roles[enemy] = INTRO_ROLE_FOLLOWUP

func _store_enemy(enemy: InfectionEnemy) -> void:
	if crowd_renderer != null:
		crowd_renderer.release_enemy(enemy, enemy.activation_generation)
	if not _release_registry_entity_for_pool(enemy_world, enemy, &"enemy"):
		return
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
	pickup.configure(
		avatar,
		value,
		topology,
		rng.randf_range(0.0, TAU),
		guided,
		280.0 if guided and selected_level != null and selected_level.is_tutorial else AnalysisPickup.DEFAULT_GUIDED_SPEED
	)
	pickup.decorative_trail_enabled = guided or cosmetic_budget_controller == null or cosmetic_budget_controller.pickup_trails_enabled()
	pickup.global_position = spawn_position
	pickup.reset_physics_interpolation()
	pickup.set_physics_process(false)
	var pickup_handle := pickup_world.register_pickup(pickup)
	if not EntityHandle.is_valid(pickup_handle):
		pickup.recycle()
		if pickup_pool.size() < MAX_PICKUP_POOL:
			pickup_pool.append(pickup)
		for existing in pickups:
			if is_instance_valid(existing) and EntityHandle.is_valid(pickup_world.handle_for(existing)):
				existing.absorb(value)
				return existing
		return null
	_pickup_query_dirty = true
	pickups.append(pickup)
	var force_detailed := guided or (discovery_manager != null and not discovery_manager.has_seen(&"analysis_pickup"))
	crowd_renderer.register_pickup(pickup, force_detailed)
	if selected_level != null and selected_level.is_tutorial:
		discovery_manager.mark_seen(&"analysis_pickup")
	elif discovery_manager.request(&"analysis_pickup", pickup):
		_try_present_next_discovery()
	return pickup

func _on_pickup_collected(value: int, pickup: AnalysisPickup) -> void:
	var handle := pickup_world.handle_for(pickup) if pickup_world != null and is_instance_valid(pickup) else EntityHandle.INVALID
	if crowd_renderer != null and is_instance_valid(pickup):
		crowd_renderer.release_pickup(pickup)
	if pickup_world != null and is_instance_valid(pickup):
		if EntityHandle.is_valid(handle):
			pickup_world.release(handle, _fixed_step_active)
			_pickup_query_dirty = true
	if _fixed_step_active:
		run_session.event_queue.push(&"pickup_collected", handle, EntityHandle.INVALID, float(value), pickup.global_position, pickup)
		return
	_apply_pickup_collected(value, pickup)

func _apply_pickup_collected(value: int, pickup: AnalysisPickup) -> void:
	if not is_instance_valid(pickup) or not pickups.has(pickup):
		return
	var intro_role := StringName(intro_pickup_roles.get(pickup, &""))
	intro_pickup_roles.erase(pickup)
	pickups.erase(pickup)
	_store_pickup(pickup)
	if selected_level.is_tutorial:
		if intro_role == INTRO_ROLE_PRIMARY:
			meta.set_tutorial_step(&"analysis")
			_spawn_intro_followups()
		elif intro_role == INTRO_ROLE_FOLLOWUP:
			intro_followup_pickups += 1
			if intro_followup_defeats == INTRO_FOLLOWUP_ENEMY_COUNT and intro_followup_pickups == INTRO_FOLLOWUP_ENEMY_COUNT:
				intro_phase = &"await_intro_upgrade"
				intro_autoattack_enabled = false
		if state != null:
			state.add_analysis(value)
	elif state != null:
		state.add_analysis(value)
		if finding_controller != null and finding_controller.definition != null and not finding_controller.revealed:
			finding_controller.add_progress(value, build_state.value(RunBuildState.FINDING_PROGRESS, stats.finding_progress_multiplier) if build_state != null else stats.finding_progress_multiplier)

func _on_projectile_finished(projectile: TherapyProjectile) -> void:
	var handle := projectile_world.handle_for(projectile) if projectile_world != null and is_instance_valid(projectile) else EntityHandle.INVALID
	_release_projectile_visual(projectile, handle)
	if projectile_world != null and is_instance_valid(projectile):
		if EntityHandle.is_valid(handle):
			projectile_world.release(handle, _fixed_step_active)
	if _fixed_step_active:
		run_session.event_queue.push(&"projectile_finished", handle, EntityHandle.INVALID, 0.0, projectile.global_position, projectile)
		return
	_apply_projectile_finished(projectile)

func _apply_projectile_finished(projectile: TherapyProjectile) -> void:
	if not is_instance_valid(projectile) or not projectiles.has(projectile):
		return
	projectiles.erase(projectile)
	_store_projectile(projectile)

func _flush_combat_events() -> void:
	# Signals may be emitted while attacks iterate the active registries. Apply
	# structural mutations only after the fixed simulation step is complete.
	if run_session != null:
		run_session.event_queue.flush_to(_apply_combat_event)

func _apply_combat_event(event: CombatEventQueue.CombatEvent) -> void:
	match event.type:
		&"enemy_defeated":
			var payload: Dictionary = event.payload if event.payload is Dictionary else {}
			_apply_enemy_defeated(payload.get("enemy") as InfectionEnemy, roundi(event.amount), bool(payload.get("was_boss", false)))
		&"pickup_collected":
			_apply_pickup_collected(roundi(event.amount), event.payload as AnalysisPickup)
		&"projectile_finished":
			_apply_projectile_finished(event.payload as TherapyProjectile)
		&"minions_requested":
			_apply_minions_requested(event.position, roundi(event.amount), event.subject_handle)

func _finalize_fixed_step() -> void:
	_fixed_step_active = false
	var phase_started := Time.get_ticks_usec() if performance_profile_enabled else 0
	# Damage can retire an enemy after EnemyWorld has already completed its
	# phase. Flush physical leases before combat events recycle Nodes into pools.
	# A second flush covers releases produced by an event callback while still
	# keeping every structural mutation outside registry iteration.
	_flush_deferred_world_releases()
	_flush_combat_events()
	_flush_deferred_world_releases()
	_update_boss_direction_indicator()
	_profile_phase(&"event_queue_flush", phase_started)
	phase_started = Time.get_ticks_usec() if performance_profile_enabled else 0
	if crowd_renderer != null:
		crowd_renderer.publish_snapshot()
	_profile_phase(&"crowd_snapshot", phase_started)
	phase_started = Time.get_ticks_usec() if performance_profile_enabled else 0
	if projectile_renderer != null:
		projectile_renderer.publish_snapshot()
	if hostile_projectile_renderer != null:
		hostile_projectile_renderer.publish_snapshot()
	_profile_phase(&"projectile_snapshot", phase_started)
	phase_started = Time.get_ticks_usec() if performance_profile_enabled else 0
	if ability_feedback_world != null:
		ability_feedback_world.publish_snapshot()
	_profile_phase(&"ability_feedback_snapshot", phase_started)

func _store_projectile(projectile: TherapyProjectile) -> void:
	var allocated_handle := projectile_world.allocated_handle_for(projectile) if projectile_world != null else EntityHandle.INVALID
	_release_projectile_visual(projectile, allocated_handle)
	if not _release_registry_entity_for_pool(projectile_world, projectile, &"projectile"):
		return
	projectile.recycle()
	if projectile_pool.size() < MAX_PROJECTILE_POOL:
		if not projectile_pool.has(projectile):
			projectile_pool.append(projectile)
	else:
		projectile.queue_free()


func _update_boss_direction_indicator() -> void:
	if hud == null or topology == null or enemy_world == null or active_boss_handles.is_empty():
		if hud != null:
			hud.set_boss_direction_indicator(false, Vector2.ZERO)
		return
	var visible_rect := _visible_world_rect()
	var camera_center := visible_rect.get_center()
	var selected_direction := Vector2.ZERO
	var selected_distance_squared := INF
	var selected_handle := EntityHandle.INVALID
	for handle_value in active_boss_handles:
		var handle := int(handle_value)
		var boss := enemy_world.resolve(handle) as InfectionEnemy
		if not is_instance_valid(boss) or boss.definition == null or not boss.is_targetable():
			continue
		var visible_radius := maxf(boss.definition.radius, boss.visual_extent() * 0.5)
		var closest := Vector2(
			clampf(boss.global_position.x, visible_rect.position.x, visible_rect.end.x),
			clampf(boss.global_position.y, visible_rect.position.y, visible_rect.end.y)
		)
		if boss.global_position.distance_squared_to(closest) <= visible_radius * visible_radius:
			continue
		var direction := topology.shortest_delta(camera_center, boss.global_position)
		var distance_squared := direction.length_squared()
		if (
			distance_squared < selected_distance_squared
			or (is_equal_approx(distance_squared, selected_distance_squared) and handle < selected_handle)
		):
			selected_direction = direction.normalized()
			selected_distance_squared = distance_squared
			selected_handle = handle
	hud.set_boss_direction_indicator(not selected_direction.is_zero_approx(), selected_direction)


func _release_projectile_visual(projectile: TherapyProjectile, handle: int) -> void:
	if not EntityHandle.is_valid(handle):
		return
	if projectile_renderer != null:
		projectile_renderer.release_projectile(projectile, handle)
	if hostile_projectile_renderer != null:
		hostile_projectile_renderer.release_projectile(projectile, handle)

func _store_pickup(pickup: AnalysisPickup) -> void:
	if crowd_renderer != null:
		crowd_renderer.release_pickup(pickup)
	if not _release_registry_entity_for_pool(pickup_world, pickup, &"pickup"):
		return
	pickup.recycle()
	if pickup_pool.size() < MAX_PICKUP_POOL:
		if not pickup_pool.has(pickup):
			pickup_pool.append(pickup)
	else:
		pickup.queue_free()

func _flush_deferred_world_releases() -> void:
	if enemy_world != null:
		enemy_world.flush_deferred()
	if projectile_world != null:
		projectile_world.flush_deferred()
	if pickup_world != null:
		pickup_world.flush_deferred()

## Pool ownership begins only after the registry's physical lease is gone.
## handle_for() is intentionally insufficient here because it hides retiring
## entities immediately; allocated_handle_for() observes the complete lease.
func _release_registry_entity_for_pool(world: NodeEntityRegistry, entity: Node, kind: StringName) -> bool:
	if world == null or not is_instance_valid(entity):
		return true
	if _fixed_step_active:
		push_error("Cannot pool %s while a fixed-step registry is iterating" % kind)
		return false
	var handle := world.allocated_handle_for(entity)
	if not EntityHandle.is_valid(handle):
		return true
	if world.is_active(handle):
		world.release(handle, true)
	world.flush_deferred()
	if EntityHandle.is_valid(world.allocated_handle_for(entity)):
		push_error("Cannot pool %s before its registry lease is physically released" % kind)
		return false
	return true

func _spawn_visual_burst(position: Vector2, kind: StringName, color: Color, count: int, duration: float, radius: float) -> void:
	var visual_limit := MAX_VISUAL_BURSTS
	if cosmetic_budget_controller != null:
		visual_limit = cosmetic_budget_controller.visual_limit(CosmeticBudgetController.EffectPriority.COMBAT, MAX_VISUAL_BURSTS)
		count = cosmetic_budget_controller.particle_count(count, CosmeticBudgetController.EffectPriority.COMBAT)
	if visual_bursts.size() >= visual_limit:
		return
	var burst: VisualBurst
	if not visual_burst_pool.is_empty():
		burst = visual_burst_pool.pop_back()
	else:
		burst = VisualBurst.new()
	burst.global_position = position
	burst.configure(kind, color, count, duration, radius)
	if feedback_renderer == null or not feedback_renderer.register_burst(burst):
		burst.recycle()
		if visual_burst_pool.size() < MAX_VISUAL_BURSTS:
			visual_burst_pool.append(burst)
		return
	visual_bursts.append(burst)

func _on_cosmetic_quality_changed(_previous: CosmeticBudgetController.Quality, _current: CosmeticBudgetController.Quality) -> void:
	if ability_feedback_world != null:
		ability_feedback_world.set_quality_tier(_current)
	var trails_enabled := cosmetic_budget_controller.pickup_trails_enabled()
	for pickup in pickups:
		if is_instance_valid(pickup):
			pickup.decorative_trail_enabled = pickup.guided_to_target or trails_enabled
			pickup.queue_redraw()

func _on_visual_burst_finished(burst: VisualBurst) -> void:
	visual_bursts.erase(burst)
	_store_visual_burst(burst)

func _store_visual_burst(burst: VisualBurst) -> void:
	if feedback_renderer != null:
		feedback_renderer.release_burst(burst, burst.activation_generation)
	burst.recycle()
	if visual_burst_pool.size() < MAX_VISUAL_BURSTS:
		if not visual_burst_pool.has(burst):
			visual_burst_pool.append(burst)

func _on_pressure_applied(amount: float, source_enemy: InfectionEnemy = null) -> void:
	var incoming_profile := source_enemy.definition.damage_profile if source_enemy != null and source_enemy.definition != null else null
	_apply_incoming_damage(amount, incoming_profile, source_enemy)


func _apply_incoming_damage(amount: float, incoming_profile: DamageProfile, source_enemy: InfectionEnemy = null) -> void:
	if state == null or not state.active or state.level_up_pending or pressure_grace_timer > 0.0:
		return
	if build_state != null and source_enemy != null and source_enemy.definition != null and source_enemy.definition.id == &"bacterial_cluster":
		amount *= build_state.value(&"group_contact", 1.0)
	if pressure_surge_remaining > 0.0:
		var finding := _active_finding()
		if finding != null and finding.behavior == FindingDefinition.Behavior.PRESSURE_SURGES:
			amount *= 1.0 + finding.magnitude
		if build_state != null:
			amount *= build_state.value(&"surge_contact", 1.0)
	amount = CombatDamageResolver.resolve(amount, incoming_profile, stats.resistances if stats != null else null, stats.defense if stats != null else 0.0)
	if ability_controller != null:
		amount = ability_controller.absorb_pressure(amount)
	if amount <= 0.0:
		return
	if selected_level.is_tutorial and not state.boss_spawned:
		amount = minf(amount, maxf(0.0, state.stability - 1.0))
	state.change_stability(-amount)
	pressure_grace_timer = PRESSURE_GRACE_SECONDS
	avatar.show_damage_flash()

func _on_stability_changed(current: float, maximum: float) -> void:
	stability_changed.emit(current, maximum)
	hud.update_stability(current, maximum)
	mastery_tracker.record_stability(current, maximum)

func _on_ability_used(slot: int, _ability_id: StringName, _target: Vector2) -> void:
	mastery_tracker.record_ability_used(slot)
	last_ability_slot = slot
	last_ability_time = state.elapsed if state != null else 0.0

func _on_ability_execution_completed(result: AbilityExecutionResult) -> void:
	if result == null or result.success:
		return
	if result.code == AbilityExecutionResult.Code.COOLDOWN:
		if ui_sound_service != null:
			ui_sound_service.play(UISoundService.ABILITY_BLOCKED)
		return
	hud.show_alert(result.reason, Color("eab553"), 1.5)

func _on_ability_cooldown_changed(slot: int, remaining: float, total: float) -> void:
	var title := ""
	if ability_controller != null:
		var runtime := ability_controller.runtime(slot)
		if runtime != null and runtime.definition != null:
			title = runtime.definition.display_name
	var ready := remaining <= 0.0
	var was_ready := bool(ability_ready_states.get(slot, true))
	ability_ready_states[slot] = ready
	if ready and not was_ready and ui_sound_service != null:
		ui_sound_service.play(UISoundService.ABILITY_READY)
	hud.update_active_ability(slot, title, remaining, total, ready)

func _on_ability_feedback_requested(result: AbilityExecutionResult) -> void:
	if ability_feedback_world != null:
		ability_feedback_world.spawn_from_result(result)

func _on_ability_shield_changed(current: float, maximum: float) -> void:
	hud.update_shield(current, maximum)
	if ability_feedback_world != null:
		ability_feedback_world.update_shield(current, maximum)

func _on_ability_finding_progress(amount: float) -> void:
	if finding_controller != null and finding_controller.definition != null:
		finding_controller.add_progress(maxi(1, roundi(amount)))

func _on_finding_progress_changed(current: int, target: int) -> void:
	hud.update_finding_progress(current, target, current >= target)

func _on_finding_revealed(definition: FindingDefinition) -> void:
	if definition == null or state == null:
		return
	mastery_tracker.record_finding_revealed(state.elapsed)
	if definition.behavior == FindingDefinition.Behavior.HIDDEN_NESTS:
		_spawn_hidden_nests(maxi(1, roundi(definition.magnitude)))
	if flow_state == GameFlowState.State.LEVEL_UP:
		pending_finding_definition = definition
		return
	_present_finding(definition)

func _present_finding(definition: FindingDefinition) -> void:
	if definition == null or finding_controller.resolved:
		return
	pending_finding_definition = null
	_set_flow(GameFlowState.State.FINDING_PAUSE)
	ui_router.open_modal(&"finding", null, get_viewport().gui_get_focus_owner())
	var reactions := _reactions_for_finding(definition)
	var reserve: Variant = loadout_modules.get(active_loadout.reserve_id) if active_loadout != null and active_loadout.reserve_id != &"" else null
	var swappable: Array = []
	if active_loadout != null:
		for id in active_loadout.passive_ids:
			if loadout_modules.has(id):
				swappable.append(loadout_modules[id])
	hud.show_finding(definition, reactions, reserve, swappable)

func _reactions_for_finding(definition: FindingDefinition) -> Array:
	var result: Array = []
	for id in definition.reaction_ids:
		if reaction_definitions.has(id):
			result.append(reaction_definitions[id])
	return result

func _on_finding_confirmed(reaction_id: StringName, incoming_id: StringName, outgoing_id: StringName) -> void:
	if flow_state != GameFlowState.State.FINDING_PAUSE or not reaction_definitions.has(reaction_id):
		return
	var reaction: ReactionDefinition = reaction_definitions[reaction_id]
	if finding_controller.definition == null or reaction.finding_id != finding_controller.definition.id:
		return
	if incoming_id != &"" or outgoing_id != &"":
		if active_loadout == null or incoming_id != active_loadout.reserve_id:
			return
		var validation := LoadoutValidator.validate_reserve_swap(
			active_loadout,
			outgoing_id,
			loadout_modules,
			meta.unlocked_module_ids(loadout_modules, research_definitions),
			meta.preparation_capacity()
		)
		if not validation.valid:
			hud.set_finding_swap_validation(false, validation.first_error())
			return
		_apply_reserve_swap(outgoing_id)
	if not finding_controller.resolve(reaction):
		return
	hud.hide_finding()
	hud.hide_finding_progress()
	hud.show_running_hud()
	_show_active_boss_hud()
	ui_router.close_modal(get_viewport().gui_get_focus_owner())
	_set_flow(GameFlowState.State.RUNNING)

func _on_finding_reserve_swap_requested(incoming_id: StringName, outgoing_id: StringName) -> void:
	if flow_state != GameFlowState.State.FINDING_PAUSE:
		return
	if incoming_id == &"" and outgoing_id == &"":
		hud.set_finding_swap_validation(true, "Kein Reservewechsel gewählt.")
		return
	if active_loadout == null or incoming_id != active_loadout.reserve_id:
		hud.set_finding_swap_validation(false, "Reserveauswahl ist nicht mehr gültig.")
		return
	var validation := LoadoutValidator.validate_reserve_swap(
		active_loadout,
		outgoing_id,
		loadout_modules,
		meta.unlocked_module_ids(loadout_modules, research_definitions),
		meta.preparation_capacity()
	)
	hud.set_finding_swap_validation(validation.valid, "Reservewechsel ist gültig." if validation.valid else validation.first_error())

func _apply_reserve_swap(outgoing_id: StringName) -> void:
	var incoming_id := active_loadout.reserve_id
	var before_bonus := stats.max_stability_bonus
	stats.apply_prepared_passive(outgoing_id, meta.research_ranks, false)
	stats.apply_prepared_passive(incoming_id, meta.research_ranks, true)
	active_loadout = LoadoutValidator.apply_reserve_swap(active_loadout, outgoing_id)
	state.adjust_max_stability(stats.max_stability_bonus - before_bonus)
	reroll_available = active_loadout.passive_ids.has(&"second_opinion")
	_sync_passive_swap_to_build(incoming_id, outgoing_id)
	mastery_tracker.record_reserve_swap()
	hud.update_run_stats(stats, state)

func _on_finding_reaction_applied(definition: ReactionDefinition) -> void:
	if definition == null or build_state == null:
		return
	active_reaction = definition
	build_state.remove_source(definition.id)
	for index in range(definition.modifiers.size()):
		var modifier_data: Dictionary = definition.modifiers[index]
		# One-shot shield reactions are applied below. Registering them in the
		# shared build as well would silently strengthen every later shield skill.
		if StringName(str(modifier_data.get("stat_id", ""))) == RunBuildState.ABILITY_SHIELD:
			continue
		build_state.add_modifier(ModifierDefinition.from_dict(
			modifier_data,
			StringName("%s_%d" % [String(definition.id), index]),
			definition.id
		))
	if definition.id == &"surge_buffer":
		ability_controller.grant_shield(12.0)
	if definition.id == &"group_control":
		for enemy in enemies:
			_apply_group_control_to_enemy(enemy)
	stats.call("_sync_fields_from_build")
	hud.update_run_stats(stats, state)

func _apply_group_control_to_enemy(enemy: InfectionEnemy) -> void:
	if enemy == null or enemy.definition == null or enemy.definition.id != &"bacterial_cluster" or build_state == null:
		return
	var strength := build_state.value(&"group_control", 1.0)
	if strength > 1.001:
		enemy.set_status_modifier(&"finding_group_control", 1.0 / strength, 1.0)
	else:
		enemy.clear_status_modifier(&"finding_group_control")

func _apply_immediate_reaction_boost(definition: ReactionDefinition) -> void:
	reaction_boost_source = StringName("immediate_%s" % String(definition.id))
	build_state.remove_source(reaction_boost_source)
	var bonus_fraction := TalentDefinition.IMMEDIATE_MEASURE_BONUS_FRACTION
	for index in range(definition.modifiers.size()):
		var data: Dictionary = definition.modifiers[index].duplicate(true)
		var stat_id := StringName(str(data.get("stat_id", "")))
		var value := float(data.get("value", 0.0))
		var operation := StringName(str(data.get("operation", "add")))
		if stat_id == RunBuildState.ABILITY_SHIELD:
			# The normal one-shot grant already happened. Add its exact 50 % bonus
			# immediately instead of turning it into a hidden future ability buff.
			var bonus_shield := maxf(0.0, value * bonus_fraction)
			ability_controller.grant_shield_capped(bonus_shield, value + bonus_shield)
			continue
		if operation == &"multiply":
			# Modifiers multiply with each other. Compute the quotient needed to
			# make the combined delta exactly 150 %, rather than multiplying a
			# second approximate delta (1.30 * 1.15 would incorrectly be 1.495).
			var boosted_total := 1.0 + (value - 1.0) * (1.0 + bonus_fraction)
			data["value"] = boosted_total / value if not is_zero_approx(value) else boosted_total
		elif operation == &"add":
			data["value"] = value * bonus_fraction
		else:
			continue
		build_state.add_modifier(ModifierDefinition.from_dict(
			data,
			StringName("%s_%d" % [String(reaction_boost_source), index]),
			reaction_boost_source
		))
	reaction_boost_timer = TalentDefinition.magnitude_for(&"immediate_measure", TalentDefinition.IMMEDIATE_MEASURE_DURATION_SECONDS)
	if definition.id == &"group_control":
		for enemy in enemies:
			_apply_group_control_to_enemy(enemy)

func _sync_passive_swap_to_build(incoming_id: StringName, outgoing_id: StringName) -> void:
	if build_state == null:
		return
	_adjust_passive_build_base(outgoing_id, false)
	_adjust_passive_build_base(incoming_id, true)
	build_state.set_base(RunBuildState.ACTIVE_COOLDOWN, stats.ability_cooldown_multiplier)
	build_state.set_base(RunBuildState.FINDING_PROGRESS, stats.finding_progress_multiplier)
	build_state.set_base(RunBuildState.SUPPORT_EFFECT, stats.support_effect_multiplier)
	stats.call("_sync_fields_from_build")

func _adjust_passive_build_base(id: StringName, enabled: bool) -> void:
	var direction_factor := 1.0
	match id:
		&"therapy_precision":
			direction_factor = 1.0 + float(meta.rank(id)) * 0.02
			build_state.set_base(RunBuildState.TREATMENT_DAMAGE, build_state.base_value(RunBuildState.TREATMENT_DAMAGE) * direction_factor if enabled else build_state.base_value(RunBuildState.TREATMENT_DAMAGE) / maxf(direction_factor, 0.001))
		&"sample_logistics":
			direction_factor = 1.0 + float(meta.rank(id)) * 0.05
			build_state.set_base(RunBuildState.PICKUP_RANGE, build_state.base_value(RunBuildState.PICKUP_RANGE) * direction_factor if enabled else build_state.base_value(RunBuildState.PICKUP_RANGE) / maxf(direction_factor, 0.001))
		&"quick_test":
			build_state.set_base(RunBuildState.FINDING_PROGRESS, stats.finding_progress_multiplier)
		&"deployment_routine":
			build_state.set_base(RunBuildState.ACTIVE_COOLDOWN, stats.ability_cooldown_multiplier)

func _sync_legacy_upgrade_to_build(definition: UpgradeDefinition) -> void:
	if build_state == null or definition == null or not definition.modifiers.is_empty():
		return
	if definition.effect == &"pickup_range":
		build_state.set_base(RunBuildState.PICKUP_RANGE, stats.pickup_range)

func _active_finding() -> FindingDefinition:
	if active_run_context == null:
		return null
	return finding_definitions.get(active_run_context.hidden_finding_id)

func _case_mechanics_step(delta: float) -> void:
	var finding := _active_finding()
	if finding != null and finding.behavior == FindingDefinition.Behavior.PRESSURE_SURGES:
		if pressure_surge_remaining > 0.0:
			pressure_surge_remaining = maxf(0.0, pressure_surge_remaining - delta)
		else:
			pressure_surge_timer -= delta
			if pressure_surge_timer <= 0.0:
				pressure_surge_timer += 25.0
				pressure_surge_remaining = 4.0
				hud.show_alert("BELASTUNGSSCHUB · 4 SEKUNDEN", Color("ef7766"), 2.2)
	if reaction_boost_timer > 0.0:
		reaction_boost_timer = maxf(0.0, reaction_boost_timer - delta)
		if reaction_boost_timer <= 0.0 and build_state != null:
			build_state.remove_source(reaction_boost_source)
			stats.call("_sync_fields_from_build")
			hud.update_run_stats(stats, state)
			for enemy in enemies:
				_apply_group_control_to_enemy(enemy)
	for nest in hidden_nest_timers.keys():
		if not is_instance_valid(nest) or nest.is_queued_for_deletion():
			hidden_nest_timers.erase(nest)
			continue
		var remaining := float(hidden_nest_timers[nest]) - delta
		if remaining > 0.0:
			hidden_nest_timers[nest] = remaining
			continue
		for index in range(4):
			var angle := TAU * float(index) / 4.0 + rng.randf_range(-0.18, 0.18)
			_spawn_enemy(&"pneumococcus", topology.wrap_position(nest.global_position + Vector2.from_angle(angle) * 84.0))
		hidden_nest_timers.erase(nest)

func _spawn_hidden_nests(count: int) -> void:
	for index in range(count):
		var spawn_position := _spawn_position_around_avatar(390.0 + float(index) * 85.0, _enemy_body_radius(&"minor_focus"))
		var request := EnemySpawnRequest.create(
			&"minor_focus",
			spawn_position,
			&"infection_focus",
			1.0,
			config.enemy_speed_multiplier,
			config.contact_damage_multiplier,
			PackedInt32Array(),
			EnemySpawnRequest.Priority.REGULAR,
			&"hidden_nest"
		)
		request.metadata["release_after_seconds"] = 20.0
		_spawn_enemy(&"minor_focus", spawn_position, 1.0, false, true, request)

func _on_analysis_changed(current: int, target: int, level: int) -> void:
	analysis_changed.emit(current, target, level)
	hud.update_analysis(current, target, level)
	_refresh_defeat_research_preview()

func _refresh_defeat_research_preview() -> void:
	if hud == null or meta == null or state == null or selected_level == null:
		return
	var repeated_intro := selected_level.is_tutorial and meta.has_completed_level(selected_level.id)
	var multiplier := config.reward_multiplier * (0.25 if repeated_intro else 1.0)
	var reward := MetaProgressionState.calculate_run_reward(
		false,
		state.elapsed,
		state.level,
		defeats,
		multiplier,
		state.bosses_defeated
	)
	hud.update_defeat_research_reward(reward)


func result_reward_presentations(research_reward: int) -> Array[RewardPresentation]:
	var result: Array[RewardPresentation] = [
		RewardPresentation.research(research_reward),
		RewardPresentation.experience(state.total_experience_gained if state != null else 0),
	]
	return result

func _on_level_up_requested(level: int) -> void:
	if selected_level.is_tutorial:
		if intro_phase != &"await_intro_upgrade":
			state.resolve_level_up()
			return
		level_up_requested.emit(level)
		current_upgrade_options = _choose_intro_treatment_upgrades(3)
		if current_upgrade_options.size() != 3:
			push_error("Intro upgrade pool must provide exactly three treatment cards")
			state.resolve_level_up()
			return
		intro_lesson = 2
		_set_flow(GameFlowState.State.LEVEL_UP)
		ui_router.open_modal(&"level_up", null, get_viewport().gui_get_focus_owner())
		hud.show_upgrade_choices(current_upgrade_options, stats, false, false, true)
		return
	level_up_requested.emit(level)
	# Jede Auswahl enthält mindestens einen Ausbau der ausgerüsteten
	# Grundbehandlung. Aktive Fähigkeiten und Abwehrzellen bleiben zusätzliche
	# Optionen, verdrängen aber nie den Auto-Angriff vollständig.
	current_upgrade_options = _choose_tactical_upgrades([], true)
	if current_upgrade_options.is_empty():
		state.resolve_level_up()
		return
	if completion_smoke:
		var definition: UpgradeDefinition = current_upgrade_options[0]
		stats.apply_upgrade(definition)
		if definition.effect == &"max_stability":
			state.increase_max_stability(definition.magnitude)
		_sync_legacy_upgrade_to_build(definition)
		state.resolve_level_up()
		return
	_set_flow(GameFlowState.State.LEVEL_UP)
	ui_router.open_modal(&"level_up", null, get_viewport().gui_get_focus_owner())
	hud.show_upgrade_choices(current_upgrade_options, stats, reroll_available and not reroll_used, false)

func _on_reroll_requested() -> void:
	if flow_state != GameFlowState.State.LEVEL_UP or not reroll_available or reroll_used:
		return
	reroll_used = true
	var excluded: Array[StringName] = []
	for definition in current_upgrade_options:
		excluded.append(definition.id)
	current_upgrade_options = _choose_tactical_upgrades(excluded, false, 3)
	hud.show_upgrade_choices(current_upgrade_options, stats, false, false)

func _choose_tactical_upgrades(excluded: Array[StringName], guarantee_treatment: bool, count: int = 3) -> Array[UpgradeDefinition]:
	if active_loadout == null:
		return ContentCatalog.choose_upgrades(stats.upgrade_levels, rng, count, guarantee_treatment, excluded)
	var component_ids := active_loadout.active_component_ids()
	var tags: Array[StringName] = []
	for id in component_ids:
		if not loadout_modules.has(id):
			continue
		var module: LoadoutModuleDefinition = loadout_modules[id]
		for tag in module.tags:
			if not tags.has(tag):
				tags.append(tag)
	return UpgradePoolBuilder.choose(ContentCatalog.upgrade_definitions(), stats.upgrade_levels, rng, component_ids, tags, count, excluded, guarantee_treatment)


func _choose_intro_treatment_upgrades(count: int) -> Array[UpgradeDefinition]:
	var definitions: Array[UpgradeDefinition] = []
	for definition in ContentCatalog.upgrade_definitions():
		if definition.path != UpgradeDefinition.Path.ANTIBIOTIC:
			continue
		if not definition.required_component_ids.has(&"treatment_precision"):
			continue
		definitions.append(definition)
	var component_ids: Array[StringName] = [&"treatment_precision"]
	var tags: Array[StringName] = [&"treatment", &"precise", &"tracking"]
	return UpgradePoolBuilder.choose(definitions, stats.upgrade_levels, rng, component_ids, tags, count, [], false)

func _on_upgrade_chosen(definition: UpgradeDefinition) -> void:
	if flow_state != GameFlowState.State.LEVEL_UP or state == null or not state.active:
		return
	if not stats.apply_upgrade(definition):
		return
	if definition.effect == &"max_stability":
		state.increase_max_stability(definition.magnitude)
	_sync_legacy_upgrade_to_build(definition)
	avatar.queue_redraw()
	hud.update_run_stats(stats, state)
	if not selected_level.is_tutorial:
		hud.configure_active_abilities(_active_ability_hud_views())
	hud.show_running_hud()
	_show_active_boss_hud()
	var completes_intro_upgrade := selected_level.is_tutorial \
		and intro_phase == &"await_intro_upgrade" \
		and current_upgrade_options.has(definition)
	ui_router.close_modal(get_viewport().gui_get_focus_owner())
	_set_flow(GameFlowState.State.RUNNING)
	state.resolve_level_up()
	if completes_intro_upgrade:
		intro_phase = &"boss_pending"
		intro_autoattack_enabled = false
		meta.set_tutorial_step(&"upgrade")
		state.trigger_event_boss()
		_save_meta()
		return
	if pending_finding_definition != null:
		_present_finding(pending_finding_definition)
		return
	if definition.effect == &"immune_level":
		# Abwehrzellen sind im Ausbau und am Avatar unmittelbar sichtbar. Ein
		# zweites Discovery-Popup würde die Auswahl nur erneut unterbrechen.
		discovery_manager.mark_seen(&"neutrophil_orbit")
	_try_present_next_discovery()

func _on_run_finished(success: bool, reason: String) -> void:
	if run_session != null:
		run_session.finish(success, reason)
	run_finished.emit(success, reason)
	if completion_smoke:
		print("COMPLETION_SMOKE success=%s elapsed=%.2f defeats=%d reason=%s" % [str(success), state.elapsed, defeats, reason])
		get_tree().quit(0 if success else 2)
		return
	avatar.input_enabled = false
	var first_intro_completion := success and selected_level.is_tutorial and not meta.has_completed_level(selected_level.id)
	var reward := 0
	var unlocked_new := false
	if first_intro_completion:
		unlocked_new = meta.register_level_result(selected_level, true, state.elapsed, state.level, defeats)
		var research_before_intro_reward := meta.research_points
		meta.grant_intro_completion_rewards(state.bosses_defeated)
		reward = meta.research_points - research_before_intro_reward
	else:
		var repeated_intro := selected_level.is_tutorial and meta.has_completed_level(selected_level.id)
		var multiplier := config.reward_multiplier * (0.25 if repeated_intro else 1.0)
		reward = meta.award_run(
			success,
			state.elapsed,
			state.level,
			defeats,
			multiplier,
			state.bosses_defeated
		)
		unlocked_new = meta.register_level_result(selected_level, success, state.elapsed, state.level, defeats)
	# Der sichtbare Fallzustand bleibt bei Niederlage und Abbruch unverändert.
	# Nur ein erfolgreicher Abschluss erzeugt die nächste deterministische
	# Merkmals-/Befundkombination. Der allererste Sieg selbst hat keine Parameter.
	if success and not selected_level.is_tutorial:
		meta.advance_case_seed(selected_level.id)
	var new_mastery_ids := meta.apply_mastery_candidates(mastery_tracker.completed_candidates(success))
	_save_meta()
	_set_flow(GameFlowState.State.RESULT)
	ui_router.replace_screen(&"result", null, get_viewport().gui_get_focus_owner())
	hud.show_end(selected_level, success, reason, state.elapsed, state.level, defeats, reward, unlocked_new)
	if first_intro_completion and hud.has_method("set_result_guidance"):
		hud.call("set_result_guidance", "Nutze die Forschung für Upgrades im Forschungsgebäude.")
	if hud.has_method("set_result_reward_presentations"):
		hud.call("set_result_reward_presentations", result_reward_presentations(reward))
	if hud.has_method("set_result_damage_statistics"):
		hud.call("set_result_damage_statistics", result_damage_statistics())
	if ui_sound_service != null:
		ui_sound_service.play(UISoundService.REWARD)
	if not new_mastery_ids.is_empty():
		var mastery_cards: Array = []
		var mastery_catalog := MasteryObjectiveDefinition.catalog()
		var earned_points := 0
		for id in new_mastery_ids:
			if mastery_catalog.has(id):
				var objective: MasteryObjectiveDefinition = mastery_catalog[id]
				mastery_cards.append(objective)
				earned_points += objective.reward_points
		hud.show_end_mastery(mastery_cards, earned_points, meta.talent_points_earned())
	if not first_intro_completion and discovery_manager.request(&"research_reward", null):
		_try_present_next_discovery()

func _resume_manual_pause() -> void:
	if flow_state != GameFlowState.State.MANUAL_PAUSE or state == null or not state.active:
		return
	hud.hide_pause()
	ui_router.close_modal(get_viewport().gui_get_focus_owner())
	_set_flow(GameFlowState.State.RUNNING)

func _on_hud_pause_requested() -> void:
	_request_manual_pause()

func _request_manual_pause() -> bool:
	if flow_state != GameFlowState.State.RUNNING or state == null or not state.active:
		return false
	ui_router.open_modal(&"pause", null, get_viewport().gui_get_focus_owner())
	_set_flow(GameFlowState.State.MANUAL_PAUSE)
	hud.show_pause(_can_skip_intro(), stats, state)
	return true

func _on_abort_requested() -> void:
	if flow_state != GameFlowState.State.MANUAL_PAUSE:
		return
	ui_router.open_modal(&"abort", null, get_viewport().gui_get_focus_owner())
	_set_flow(GameFlowState.State.ABORT_CONFIRMATION)
	hud.show_abort_confirmation()

func _on_abort_cancelled() -> void:
	if flow_state != GameFlowState.State.ABORT_CONFIRMATION:
		return
	ui_router.close_modal(get_viewport().gui_get_focus_owner())
	_set_flow(GameFlowState.State.MANUAL_PAUSE)
	hud.show_running_hud()
	hud.show_pause(_can_skip_intro(), stats, state)

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
	if not _can_skip_intro() or flow_state not in [GameFlowState.State.PREPARATION, GameFlowState.State.MANUAL_PAUSE]:
		return
	intro_skip_return_state = flow_state
	ui_router.open_modal(&"intro_skip", null, get_viewport().gui_get_focus_owner())
	_set_flow(GameFlowState.State.INTRO_SKIP_CONFIRMATION)
	hud.show_intro_skip_confirmation()

func _on_intro_skip_cancelled() -> void:
	if flow_state != GameFlowState.State.INTRO_SKIP_CONFIRMATION:
		return
	ui_router.close_modal(get_viewport().gui_get_focus_owner())
	hud.hide_intro_skip_confirmation()
	if intro_skip_return_state == GameFlowState.State.MANUAL_PAUSE:
		_set_flow(GameFlowState.State.MANUAL_PAUSE)
		hud.show_running_hud()
		hud.show_pause(_can_skip_intro(), stats, state)
	else:
		_set_flow(GameFlowState.State.PREPARATION)
		_refresh_preparation()

func _on_intro_skip_confirmed() -> void:
	if flow_state != GameFlowState.State.INTRO_SKIP_CONFIRMATION or selected_level == null or not selected_level.is_tutorial:
		return
	if state != null and state.active:
		state.cancel()
	discovery_manager.clear_pending()
	_cleanup_run_nodes()
	avatar.input_enabled = false
	avatar.hide()
	meta.grant_intro_completion_rewards()
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
		if definition.id != id:
			continue
		if not LoadoutAvailabilityPolicy.research_purchase_enabled(definition, _first_case_complete()):
			break
		if meta.purchase(definition):
			_save_meta()
		break
	_sync_progression_availability()
	hud.refresh_research(meta, research_definitions)

func _on_research_reset_requested() -> void:
	if flow_state != GameFlowState.State.RESEARCH:
		return
	meta.clear_research_ranks(research_definitions)
	_save_meta()
	_sync_progression_availability()
	hud.refresh_research(meta, research_definitions)

func _on_research_tab_changed(tab: StringName) -> void:
	if flow_state == GameFlowState.State.RESEARCH and tab == &"talents":
		hud.refresh_talents(_talent_view_model())

func _on_talent_toggle_requested(id: StringName) -> void:
	if flow_state != GameFlowState.State.RESEARCH or not _talents_unlocked():
		return
	if meta.purchase_talent_rank(id):
		_save_meta()
	hud.refresh_talents(_talent_view_model())

func _on_talent_rank_remove_requested(id: StringName) -> void:
	if flow_state != GameFlowState.State.RESEARCH or not _talents_unlocked():
		return
	var current_rank := meta.talent_rank(id)
	if current_rank > 0 and meta.set_talent_rank(id, current_rank - 1):
		_save_meta()
	elif ui_sound_service != null:
		ui_sound_service.play(UISoundService.ERROR)
	hud.refresh_talents(_talent_view_model())

func _on_talent_reset_requested() -> void:
	if flow_state != GameFlowState.State.RESEARCH or not _talents_unlocked():
		return
	meta.clear_talents()
	_save_meta()
	hud.refresh_talents(_talent_view_model())

func _talent_view_model() -> Dictionary:
	var cards: Array = []
	var definitions := TalentDefinition.definitions()
	var titles: Dictionary = {}
	for definition in definitions:
		titles[definition.id] = definition.title
	for definition in definitions:
		var prerequisites_met := true
		var requirement_titles := PackedStringArray()
		for required_id in definition.required_ids:
			requirement_titles.append(String(titles.get(StringName(required_id), String(required_id))))
			if not meta.has_talent(StringName(required_id)):
				prerequisites_met = false
				break
		var current_rank := meta.talent_rank(definition.id)
		var maximum := current_rank >= definition.max_rank
		cards.append({
			"id": definition.id,
			"title": definition.title,
			"description": definition.description,
			"cost": 0 if maximum else definition.cost_for_rank(current_rank),
			"category": &"treatment",
			"active": current_rank > 0,
			"current_rank": current_rank,
			"max_rank": definition.max_rank,
			"maximum": maximum,
			"prerequisite_met": prerequisites_met,
			"required_ids": definition.required_ids.duplicate(),
			"requirement_text": " + ".join(requirement_titles) if not requirement_titles.is_empty() else "Einstieg des Astes",
			"tree_tier": definition.tree_tier,
			"tree_lane": definition.tree_lane,
		})
	return {
		"total_points": meta.talent_points_earned(),
		"spent_points": meta.talent_points_spent(),
		"unlimited": meta.is_unlimited_test_progression(),
		"tree_refunded": meta.talent_tree_refund_pending,
		"tree_unlocked": _talents_unlocked(),
		"tree_lock_text": "Schließe zuerst die Einführung ab.",
		"talents": cards,
	}


func _first_case_complete() -> bool:
	return meta != null and meta.has_completed_level(&"localized_focus")


func _sync_progression_availability() -> void:
	hud.set_progression_availability(_first_case_complete(), _talents_unlocked())


func _talents_unlocked() -> bool:
	return meta != null and (meta.has_completed_level(&"intro") or meta.intro_skipped)

func _nearest_targets(max_range: float, count: int) -> Array[InfectionEnemy]:
	var nearest: Array[InfectionEnemy] = []
	_ensure_combat_query()
	for handle in combat_query.nearest(avatar.global_position, max_range, count):
		var enemy := enemy_world.resolve(handle) as InfectionEnemy
		if is_instance_valid(enemy):
			nearest.append(enemy)
	return nearest

func _treatment_candidates() -> Array:
	if treatment_controller == null or treatment_controller.definition == null or build_state == null:
		return enemies
	_ensure_combat_query()
	var definition := treatment_controller.definition
	var maximum_range := build_state.value(RunBuildState.TREATMENT_RANGE, definition.base_range, definition.tags)
	var result: Array = []
	for handle in combat_query.circle(avatar.global_position, maximum_range):
		var enemy := enemy_world.resolve(handle) as InfectionEnemy
		if is_instance_valid(enemy):
			result.append(enemy)
	return result

func _ensure_combat_query() -> void:
	if not _combat_query_dirty:
		return
	var started := Time.get_ticks_usec() if performance_profile_enabled else 0
	_combat_query_handles = enemy_world.handles(_combat_query_handles)
	combat_query.rebuild(_combat_query_handles)
	_combat_query_dirty = false
	if performance_profile_enabled:
		last_phase_timings_ms[&"spatial_query_rebuild"] = float(Time.get_ticks_usec() - started) / 1000.0

func _ensure_pickup_query() -> void:
	if not _pickup_query_dirty or pickup_query == null:
		return
	_pickup_query_handles = pickup_world.handles(_pickup_query_handles)
	pickup_query.rebuild(_pickup_query_handles)
	_pickup_query_dirty = false

func _enemy_position_for_handle(handle: int) -> Vector2:
	var enemy := enemy_world.resolve(handle) as InfectionEnemy
	return enemy.global_position if is_instance_valid(enemy) else Vector2.ZERO

func _enemy_radius_for_handle(handle: int) -> float:
	var enemy := enemy_world.resolve(handle) as InfectionEnemy
	return enemy.definition.radius if is_instance_valid(enemy) and enemy.definition != null else 0.0

func _enemy_targetable_for_handle(handle: int) -> bool:
	var enemy := enemy_world.resolve(handle) as InfectionEnemy
	return is_instance_valid(enemy) and enemy.is_targetable()

func _pickup_position_for_handle(handle: int) -> Vector2:
	var pickup := pickup_world.resolve(handle) as AnalysisPickup
	return pickup.global_position if is_instance_valid(pickup) else Vector2.ZERO

func _pickup_targetable_for_handle(handle: int) -> bool:
	return is_instance_valid(pickup_world.resolve(handle))

func _enemy_body_radius(type: StringName) -> float:
	var definition := enemy_definitions.get(type) as EnemyDefinition
	return definition.radius if definition != null else 0.0


func _spawn_position_around_avatar(distance: float, body_radius: float = 0.0) -> Vector2:
	var safe_distance := minf(distance, minf(config.arena_size.x, config.arena_size.y) * 0.5 - 70.0)
	# Preserve the established content-RNG sequence. Spawn geometry uses its own
	# stream, but this draw keeps later enemy types and upgrade rolls unchanged.
	var _content_rng_compatibility_draw: float = rng.randf_range(0.0, TAU)
	var angle := fposmod(
		spawn_angle_cursor + spawn_rng.randf_range(-SPAWN_ANGLE_JITTER, SPAWN_ANGLE_JITTER),
		TAU
	)
	spawn_angle_cursor = fposmod(spawn_angle_cursor + SPAWN_GOLDEN_ANGLE, TAU)
	return _safe_spawn_position_for_angle(angle, safe_distance, body_radius)


func _safe_spawn_position_for_angle(angle: float, distance: float, body_radius: float) -> Vector2:
	var desired := avatar.global_position + Vector2.from_angle(angle) * distance
	if not topology.is_bounded() or topology.contains_position(desired, body_radius):
		return topology.resolve_position(desired, body_radius)
	var sector_width := TAU / float(WAVE_SPAWN_SECTOR_COUNT)
	for alternative_index in range(1, WAVE_SPAWN_SECTOR_COUNT):
		var step := ceili(float(alternative_index) * 0.5)
		var direction := 1.0 if alternative_index % 2 == 1 else -1.0
		var alternative := avatar.global_position + Vector2.from_angle(angle + float(step) * sector_width * direction) * distance
		if topology.contains_position(alternative, body_radius):
			return alternative
	return topology.resolve_position(desired, body_radius)


## Standard waves evaluate only the pressure which can currently influence the
## player. Nearby bodies count more than distant ones and the wider red groups
## count twice. One of the three calmest valid sectors is selected using the
## dedicated deterministic spawn stream, and the body is placed just outside
## the actual camera rectangle. This creates several attack fronts without
## teaching locomotion to predict or flank the player.
func _wave_spawn_position_around_avatar(distance: float, body_radius: float = 0.0) -> Vector2:
	var candidate := _spawn_position_around_avatar(distance, body_radius)
	if not is_instance_valid(avatar) or topology == null:
		return candidate
	var sector_pressure := _local_wave_sector_pressure()
	var candidate_delta := topology.shortest_delta(avatar.global_position, candidate)
	if candidate_delta.length_squared() <= 0.0001:
		return candidate
	var sector_width := TAU / float(WAVE_SPAWN_SECTOR_COUNT)
	var candidate_angle := fposmod(candidate_delta.angle(), TAU)
	var ranked_sectors: Array[Dictionary] = []
	for sector in range(WAVE_SPAWN_SECTOR_COUNT):
		var sector_center := (float(sector) + 0.5) * sector_width
		var sector_position := _offscreen_spawn_position(sector_center, body_radius)
		if sector_position == Vector2.INF:
			continue
		ranked_sectors.append({
			"sector": sector,
			"pressure": float(sector_pressure[sector]),
			"angle_distance": absf(_shortest_signed_angle(candidate_angle, sector_center)),
			"position": sector_position,
		})
	ranked_sectors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pressure_a := float(a["pressure"])
		var pressure_b := float(b["pressure"])
		if not is_equal_approx(pressure_a, pressure_b):
			return pressure_a < pressure_b
		var angle_a := float(a["angle_distance"])
		var angle_b := float(b["angle_distance"])
		if not is_equal_approx(angle_a, angle_b):
			return angle_a < angle_b
		return int(a["sector"]) < int(b["sector"])
	)
	if ranked_sectors.is_empty():
		return candidate
	var choice_count := mini(WAVE_SPAWN_EMPTY_SECTOR_CHOICES, ranked_sectors.size())
	var choice_index := spawn_rng.randi_range(0, choice_count - 1)
	return Vector2(ranked_sectors[choice_index]["position"])


func _local_wave_sector_pressure() -> PackedFloat32Array:
	var pressure := PackedFloat32Array()
	pressure.resize(WAVE_SPAWN_SECTOR_COUNT)
	pressure.fill(0.0)
	if not is_instance_valid(avatar) or topology == null:
		return pressure
	var local_rect := _visible_world_rect().grow(WAVE_PRESSURE_NEAR_MARGIN)
	var local_radius := local_rect.size.length() * 0.5 + avatar.global_position.distance_to(local_rect.get_center())
	var local_radius_squared := local_radius * local_radius
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.activation_active or enemy.dying:
			continue
		if not local_rect.has_point(enemy.global_position):
			continue
		var enemy_delta := topology.shortest_delta(avatar.global_position, enemy.global_position)
		var distance_squared := enemy_delta.length_squared()
		if distance_squared <= 0.0001 or distance_squared > local_radius_squared:
			continue
		var distance_weight := 1.0 - clampf(sqrt(distance_squared) / local_radius, 0.0, 1.0)
		var body_weight := 2.0 if enemy.definition != null and enemy.definition.id == &"bacterial_cluster" else 1.0
		var weight := body_weight * (0.35 + 1.65 * distance_weight * distance_weight)
		var sector := _sector_for_delta(enemy_delta)
		pressure[sector] += weight
		pressure[posmod(sector - 1, WAVE_SPAWN_SECTOR_COUNT)] += weight * WAVE_PRESSURE_NEIGHBOR_SHARE
		pressure[posmod(sector + 1, WAVE_SPAWN_SECTOR_COUNT)] += weight * WAVE_PRESSURE_NEIGHBOR_SHARE
	return pressure


func _visible_world_half_extents() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var zoom := avatar.camera.zoom if is_instance_valid(avatar) and is_instance_valid(avatar.camera) else Vector2.ONE
	return Vector2(
		viewport_size.x * 0.5 / maxf(absf(zoom.x), 0.001),
		viewport_size.y * 0.5 / maxf(absf(zoom.y), 0.001)
	)


func _visible_world_rect() -> Rect2:
	var half_extents := _visible_world_half_extents()
	var center := avatar.global_position
	if is_instance_valid(avatar) and is_instance_valid(avatar.camera):
		center = avatar.camera.get_screen_center_position()
	return Rect2(center - half_extents, half_extents * 2.0)


func _offscreen_spawn_position(
	angle: float,
	body_radius: float,
	ignored_enemy: InfectionEnemy = null,
	prefer_outer: bool = false,
	use_enemy_world_index: bool = false
) -> Vector2:
	var candidate_count := OFFSCREEN_PLACEMENT_RADIAL_OFFSETS.size() * OFFSCREEN_PLACEMENT_ANGLE_OFFSETS.size()
	for candidate_index in range(candidate_count):
		var position := _offscreen_spawn_candidate(
			angle,
			body_radius,
			candidate_index,
			prefer_outer,
			ignored_enemy,
			use_enemy_world_index
		)
		if position != Vector2.INF:
			return position
	return Vector2.INF


func _offscreen_spawn_candidate(
	angle: float,
	body_radius: float,
	candidate_index: int,
	prefer_outer: bool,
	ignored_enemy: InfectionEnemy = null,
	use_enemy_world_index: bool = false,
	radial_jitter: float = 0.0
) -> Vector2:
	var angle_count := OFFSCREEN_PLACEMENT_ANGLE_OFFSETS.size()
	var radial_count := OFFSCREEN_PLACEMENT_RADIAL_OFFSETS.size()
	if candidate_index < 0 or candidate_index >= angle_count * radial_count:
		return Vector2.INF
	var radial_order_index := floori(float(candidate_index) / float(angle_count))
	var angle_index := candidate_index % angle_count
	var radial_index := radial_count - 1 - radial_order_index if prefer_outer else radial_order_index
	var radial_offset := maxf(
		float(OFFSCREEN_PLACEMENT_RADIAL_OFFSETS[radial_index]) + radial_jitter,
		0.0
	)
	var angle_offset := float(OFFSCREEN_PLACEMENT_ANGLE_OFFSETS[angle_index])
	var direction := Vector2.from_angle(angle + angle_offset)
	var distance := _ray_distance_to_visible_edge(avatar.global_position, direction)
	distance += WAVE_SPAWN_SCREEN_MARGIN + body_radius + radial_offset
	var position := avatar.global_position + direction * distance
	if topology.is_bounded() and not topology.contains_position(position, body_radius):
		return Vector2.INF
	position = topology.resolve_position(position, body_radius)
	if not _offscreen_position_is_fully_hidden(position, body_radius):
		return Vector2.INF
	return (
		position
		if _offscreen_position_is_clear(position, body_radius, ignored_enemy, use_enemy_world_index)
		else Vector2.INF
	)


func _offscreen_position_is_fully_hidden(position: Vector2, body_radius: float) -> bool:
	var hidden_rect := _visible_world_rect().grow(body_radius + OFFSCREEN_RELOCATION_HIDDEN_MARGIN)
	return not hidden_rect.has_point(position)


func _ray_distance_to_visible_edge(origin: Vector2, direction: Vector2) -> float:
	var visible_rect := _visible_world_rect()
	var distance := INF
	if direction.x > 0.0001:
		distance = minf(distance, (visible_rect.end.x - origin.x) / direction.x)
	elif direction.x < -0.0001:
		distance = minf(distance, (visible_rect.position.x - origin.x) / direction.x)
	if direction.y > 0.0001:
		distance = minf(distance, (visible_rect.end.y - origin.y) / direction.y)
	elif direction.y < -0.0001:
		distance = minf(distance, (visible_rect.position.y - origin.y) / direction.y)
	return maxf(0.0, distance if is_finite(distance) else _visible_world_half_extents().length())


func _offscreen_position_is_clear(
	position: Vector2,
	body_radius: float,
	ignored_enemy: InfectionEnemy = null,
	use_enemy_world_index: bool = false
) -> bool:
	var broad_phase_radius := body_radius + OFFSCREEN_PLACEMENT_BODY_GAP + combat_query.maximum_body_radius
	if (
		use_enemy_world_index
		and enemy_world != null
		and enemy_world.collision_index_covers_all_active_enemies()
	):
		_offscreen_clearance_candidates = enemy_world.query_collision_candidates(
			position,
			broad_phase_radius,
			_offscreen_clearance_candidates
		)
	else:
		_ensure_combat_query()
		_offscreen_clearance_candidates = combat_query.grid.query_circle_candidates(
			position,
			broad_phase_radius,
			_offscreen_clearance_candidates
		)
	return _offscreen_position_is_clear_from_candidates(position, body_radius, ignored_enemy)


func _offscreen_position_is_clear_from_candidates(
	position: Vector2,
	body_radius: float,
	ignored_enemy: InfectionEnemy = null
) -> bool:
	for handle_value in _offscreen_clearance_candidates:
		var other := combat_query.resolve(int(handle_value)) as InfectionEnemy
		if not is_instance_valid(other) or other == ignored_enemy or other.definition == null or other.dying:
			continue
		var minimum_distance := body_radius + other.definition.radius + OFFSCREEN_PLACEMENT_BODY_GAP
		if topology.shortest_delta(position, other.global_position).length_squared() < minimum_distance * minimum_distance:
			return false
	return true


func _sector_for_delta(delta: Vector2) -> int:
	return floori(fposmod(delta.angle(), TAU) / TAU * float(WAVE_SPAWN_SECTOR_COUNT)) % WAVE_SPAWN_SECTOR_COUNT


func _offscreen_relocation_step(delta: float) -> void:
	offscreen_relocation_timer -= delta
	offscreen_relocation_move_timer = maxf(0.0, offscreen_relocation_move_timer - delta)
	if not is_instance_valid(avatar) or topology == null or enemy_world == null:
		offscreen_relocation_pending = 0
		return
	if offscreen_relocation_timer <= 0.0:
		while offscreen_relocation_timer <= 0.0:
			offscreen_relocation_timer += OFFSCREEN_RELOCATION_INTERVAL
		_prepare_offscreen_relocation_snapshot()
	if offscreen_relocation_pending <= 0 or offscreen_relocation_move_timer > 0.0:
		return
	offscreen_relocation_move_timer += offscreen_relocation_move_interval
	var candidate_index := _offscreen_relocation_candidate_cursor
	_offscreen_relocation_candidate_cursor += 1
	offscreen_relocation_pending = maxi(0, offscreen_relocation_pending - 1)
	if candidate_index < 0 or candidate_index >= _offscreen_relocation_candidate_handles.size():
		return
	var selected_handle := int(_offscreen_relocation_candidate_handles[candidate_index])
	var selected_enemy := enemy_world.resolve(selected_handle) as InfectionEnemy
	var source_exclusion_rect := _visible_world_rect().grow(OFFSCREEN_RELOCATION_SOURCE_MARGIN)
	if not _enemy_can_relocate_offscreen(selected_enemy, source_exclusion_rect):
		return
	var source_delta := topology.shortest_delta(avatar.global_position, selected_enemy.global_position)
	if source_delta.length_squared() <= 0.0001:
		return
	var source_sector := _sector_for_delta(source_delta)
	var selected_radius := selected_enemy.definition.radius if selected_enemy.definition != null else 18.0
	var target_position := _offscreen_relocation_target(
		source_sector,
		source_delta.normalized(),
		selected_radius,
		selected_enemy
	)
	if target_position == Vector2.INF:
		return
	if not _offscreen_position_is_fully_hidden(target_position, selected_radius):
		return
	var weight := 2.0 if selected_enemy.definition != null and selected_enemy.definition.id == &"bacterial_cluster" else 1.0
	var relocation_applied := false
	var previous_position := selected_enemy.global_position
	if selected_enemy.has_method(&"relocate_preserving_state"):
		relocation_applied = bool(selected_enemy.call(&"relocate_preserving_state", target_position))
	else:
		selected_enemy.global_position = target_position
		selected_enemy.reset_visual_motion()
		relocation_applied = true
	if not relocation_applied:
		return
	var handle := enemy_world.handle_for(selected_enemy)
	if EntityHandle.is_valid(handle) and enemy_world.has_method(&"mark_enemy_relocated"):
		enemy_world.call(&"mark_enemy_relocated", handle, previous_position)
		if not _combat_query_dirty:
			combat_query.grid.move(handle, previous_position, selected_enemy.global_position)
		else:
			_combat_query_dirty = true
	else:
		_combat_query_dirty = true
	if crowd_renderer != null and crowd_renderer.has_method(&"mark_enemy_teleported"):
		crowd_renderer.call(&"mark_enemy_teleported", selected_enemy)
	if _offscreen_selected_target_sector >= 0:
		var target_sector := _offscreen_selected_target_sector
		_offscreen_relocation_target_pressure[target_sector] += weight
		_offscreen_relocation_target_pressure[posmod(target_sector - 1, WAVE_SPAWN_SECTOR_COUNT)] += weight * WAVE_PRESSURE_NEIGHBOR_SHARE
		_offscreen_relocation_target_pressure[posmod(target_sector + 1, WAVE_SPAWN_SECTOR_COUNT)] += weight * WAVE_PRESSURE_NEIGHBOR_SHARE
	_combat_query_dirty = true


func _prepare_offscreen_relocation_snapshot() -> void:
	offscreen_relocation_pending = 0
	_offscreen_relocation_candidate_cursor = 0
	offscreen_relocation_last_eligible_count = 0
	offscreen_relocation_last_planned_count = 0
	_offscreen_relocation_candidate_handles.resize(OFFSCREEN_RELOCATION_MAXIMUM_PER_SNAPSHOT)
	_offscreen_relocation_candidate_handles.fill(EntityHandle.INVALID)
	_offscreen_relocation_candidate_sectors.resize(OFFSCREEN_RELOCATION_MAXIMUM_PER_SNAPSHOT)
	_offscreen_relocation_candidate_sectors.fill(-1)
	_offscreen_relocation_candidate_depths.resize(OFFSCREEN_RELOCATION_MAXIMUM_PER_SNAPSHOT)
	_offscreen_relocation_candidate_depths.fill(-INF)
	_offscreen_relocation_source_backlog.resize(WAVE_SPAWN_SECTOR_COUNT)
	_offscreen_relocation_source_backlog.fill(0.0)
	_offscreen_relocation_target_pressure.resize(WAVE_SPAWN_SECTOR_COUNT)
	_offscreen_relocation_target_pressure.fill(0.0)
	_offscreen_relocation_target_reservations.resize(WAVE_SPAWN_SECTOR_COUNT)
	_offscreen_relocation_target_reservations.fill(0)
	var sector_candidate_capacity := WAVE_SPAWN_SECTOR_COUNT * OFFSCREEN_RELOCATION_MAXIMUM_PER_SNAPSHOT
	_offscreen_relocation_sector_candidate_handles.resize(sector_candidate_capacity)
	_offscreen_relocation_sector_candidate_handles.fill(EntityHandle.INVALID)
	_offscreen_relocation_sector_candidate_depths.resize(sector_candidate_capacity)
	_offscreen_relocation_sector_candidate_depths.fill(-INF)
	var source_exclusion_rect := _visible_world_rect().grow(OFFSCREEN_RELOCATION_SOURCE_MARGIN)
	var local_rect := _visible_world_rect().grow(WAVE_PRESSURE_NEAR_MARGIN)
	var local_radius := local_rect.size.length() * 0.5 + avatar.global_position.distance_to(local_rect.get_center())
	var local_radius_squared := local_radius * local_radius
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.definition == null or not enemy.activation_active or enemy.dying:
			continue
		var source_delta := topology.shortest_delta(avatar.global_position, enemy.global_position)
		if source_delta.length_squared() <= 0.0001:
			continue
		var source_sector := _sector_for_delta(source_delta)
		var weight := 2.0 if enemy.definition != null and enemy.definition.id == &"bacterial_cluster" else 1.0
		var distance_squared := source_delta.length_squared()
		if local_rect.has_point(enemy.global_position) and distance_squared <= local_radius_squared:
			var distance_weight := 1.0 - clampf(sqrt(distance_squared) / local_radius, 0.0, 1.0)
			var local_weight := weight * (0.35 + 1.65 * distance_weight * distance_weight)
			_offscreen_relocation_target_pressure[source_sector] += local_weight
			_offscreen_relocation_target_pressure[posmod(source_sector - 1, WAVE_SPAWN_SECTOR_COUNT)] += local_weight * WAVE_PRESSURE_NEIGHBOR_SHARE
			_offscreen_relocation_target_pressure[posmod(source_sector + 1, WAVE_SPAWN_SECTOR_COUNT)] += local_weight * WAVE_PRESSURE_NEIGHBOR_SHARE
		if not _enemy_can_relocate_offscreen(enemy, source_exclusion_rect):
			continue
		var handle := enemy_world.handle_for(enemy)
		if not EntityHandle.is_valid(handle):
			continue
		offscreen_relocation_last_eligible_count += 1
		_offscreen_relocation_source_backlog[source_sector] += weight
		var outside_depth := _distance_outside_rect(enemy.global_position, source_exclusion_rect)
		_insert_offscreen_sector_candidate(handle, source_sector, outside_depth)
	for sector in range(WAVE_SPAWN_SECTOR_COUNT):
		var sector_offset := sector * OFFSCREEN_RELOCATION_MAXIMUM_PER_SNAPSHOT
		for candidate_offset in range(OFFSCREEN_RELOCATION_MAXIMUM_PER_SNAPSHOT):
			var candidate_index := sector_offset + candidate_offset
			var handle := int(_offscreen_relocation_sector_candidate_handles[candidate_index])
			if not EntityHandle.is_valid(handle):
				continue
			_insert_offscreen_relocation_candidate(
				handle,
				sector,
				float(_offscreen_relocation_sector_candidate_depths[candidate_index])
			)
	var available_candidate_count := 0
	for handle_value in _offscreen_relocation_candidate_handles:
		if EntityHandle.is_valid(int(handle_value)):
			available_candidate_count += 1
	var planned_count := mini(
		available_candidate_count,
		_offscreen_relocation_budget_for_count(offscreen_relocation_last_eligible_count)
	)
	offscreen_relocation_last_planned_count = planned_count
	offscreen_relocation_pending = planned_count
	if planned_count > 0:
		offscreen_relocation_move_interval = OFFSCREEN_RELOCATION_INTERVAL / float(planned_count)
		offscreen_relocation_move_timer = offscreen_relocation_move_interval * 0.5
	else:
		offscreen_relocation_move_interval = OFFSCREEN_RELOCATION_INTERVAL


func _offscreen_relocation_budget_for_count(eligible_count: int) -> int:
	if eligible_count <= 0:
		return 0
	return clampi(
		ceili(float(eligible_count) / float(OFFSCREEN_RELOCATION_ENEMIES_PER_BUDGET_STEP)),
		1,
		OFFSCREEN_RELOCATION_MAXIMUM_PER_SNAPSHOT
	)


func _offscreen_relocation_rate_for_count(eligible_count: int) -> float:
	return float(_offscreen_relocation_budget_for_count(eligible_count)) / OFFSCREEN_RELOCATION_INTERVAL


func _insert_offscreen_sector_candidate(handle: int, source_sector: int, outside_depth: float) -> void:
	var sector_offset := source_sector * OFFSCREEN_RELOCATION_MAXIMUM_PER_SNAPSHOT
	var insert_offset := -1
	for candidate_offset in range(OFFSCREEN_RELOCATION_MAXIMUM_PER_SNAPSHOT):
		var candidate_index := sector_offset + candidate_offset
		var stored_handle := int(_offscreen_relocation_sector_candidate_handles[candidate_index])
		var stored_depth := float(_offscreen_relocation_sector_candidate_depths[candidate_index])
		if (
			not EntityHandle.is_valid(stored_handle)
			or outside_depth > stored_depth
			or (is_equal_approx(outside_depth, stored_depth) and handle < stored_handle)
		):
			insert_offset = candidate_offset
			break
	if insert_offset < 0:
		return
	for shift_offset in range(OFFSCREEN_RELOCATION_MAXIMUM_PER_SNAPSHOT - 1, insert_offset, -1):
		var target_index := sector_offset + shift_offset
		var source_index := target_index - 1
		_offscreen_relocation_sector_candidate_handles[target_index] = _offscreen_relocation_sector_candidate_handles[source_index]
		_offscreen_relocation_sector_candidate_depths[target_index] = _offscreen_relocation_sector_candidate_depths[source_index]
	var insert_index := sector_offset + insert_offset
	_offscreen_relocation_sector_candidate_handles[insert_index] = handle
	_offscreen_relocation_sector_candidate_depths[insert_index] = outside_depth


func _insert_offscreen_relocation_candidate(handle: int, source_sector: int, outside_depth: float) -> void:
	var insert_index := -1
	var candidate_backlog := float(_offscreen_relocation_source_backlog[source_sector])
	for index in range(OFFSCREEN_RELOCATION_MAXIMUM_PER_SNAPSHOT):
		var stored_handle := int(_offscreen_relocation_candidate_handles[index])
		if not EntityHandle.is_valid(stored_handle):
			insert_index = index
			break
		var stored_sector := int(_offscreen_relocation_candidate_sectors[index])
		var stored_backlog := float(_offscreen_relocation_source_backlog[stored_sector])
		var stored_depth := float(_offscreen_relocation_candidate_depths[index])
		if (
			candidate_backlog > stored_backlog
			or (is_equal_approx(candidate_backlog, stored_backlog) and outside_depth > stored_depth)
			or (
				is_equal_approx(candidate_backlog, stored_backlog)
				and is_equal_approx(outside_depth, stored_depth)
				and handle < stored_handle
			)
		):
			insert_index = index
			break
	if insert_index < 0:
		return
	for shift_index in range(OFFSCREEN_RELOCATION_MAXIMUM_PER_SNAPSHOT - 1, insert_index, -1):
		_offscreen_relocation_candidate_handles[shift_index] = _offscreen_relocation_candidate_handles[shift_index - 1]
		_offscreen_relocation_candidate_sectors[shift_index] = _offscreen_relocation_candidate_sectors[shift_index - 1]
		_offscreen_relocation_candidate_depths[shift_index] = _offscreen_relocation_candidate_depths[shift_index - 1]
	_offscreen_relocation_candidate_handles[insert_index] = handle
	_offscreen_relocation_candidate_sectors[insert_index] = source_sector
	_offscreen_relocation_candidate_depths[insert_index] = outside_depth


func _offscreen_relocation_target(
	source_sector: int,
	_source_direction: Vector2,
	body_radius: float,
	ignored_enemy: InfectionEnemy
) -> Vector2:
	_offscreen_selected_target_sector = -1
	_rank_offscreen_sectors(_offscreen_relocation_target_pressure)
	_offscreen_opposite_sectors.resize(WAVE_SPAWN_SECTOR_COUNT)
	var eligible_count := 0
	for ranked_sector_value in _offscreen_ranked_sectors:
		var ranked_sector := int(ranked_sector_value)
		if _sector_ring_distance(source_sector, ranked_sector) < OFFSCREEN_RELOCATION_MINIMUM_SECTOR_DISTANCE:
			continue
		if int(_offscreen_relocation_target_reservations[ranked_sector]) >= OFFSCREEN_RELOCATION_MAXIMUM_TARGETS_PER_SECTOR:
			continue
		_offscreen_opposite_sectors[eligible_count] = ranked_sector
		eligible_count += 1
	if eligible_count <= 0:
		return Vector2.INF
	# Relocation owns a deterministic RNG stream separate from ordinary spawns.
	# Pick among several calm sectors, then jitter angle and depth inside that
	# sector. The Director therefore creates broad, unpredictable fronts without
	# guessing where the player will run or changing later content RNG draws.
	var random_rank_limit := mini(OFFSCREEN_RELOCATION_RANDOM_SECTOR_CHOICES, eligible_count)
	var preferred_rank := relocation_rng.randi_range(0, random_rank_limit - 1)
	var sector_width := TAU / float(WAVE_SPAWN_SECTOR_COUNT)
	for sector_attempt in range(mini(eligible_count, OFFSCREEN_RELOCATION_TARGET_SECTOR_ATTEMPTS)):
		var ranked_index := (preferred_rank + sector_attempt) % eligible_count
		var target_sector := int(_offscreen_opposite_sectors[ranked_index])
		var angle_jitter := relocation_rng.randf_range(-sector_width * 0.34, sector_width * 0.34)
		var target_position := _offscreen_random_relocation_position(
			(float(target_sector) + 0.5) * sector_width + angle_jitter,
			body_radius,
			ignored_enemy
		)
		if target_position == Vector2.INF:
			continue
		var target_delta := topology.shortest_delta(avatar.global_position, target_position)
		if target_delta.length_squared() <= 0.0001:
			continue
		var actual_target_sector := _sector_for_delta(target_delta)
		if (
			_sector_ring_distance(source_sector, actual_target_sector) < OFFSCREEN_RELOCATION_MINIMUM_SECTOR_DISTANCE
			or int(_offscreen_relocation_target_reservations[actual_target_sector]) >= OFFSCREEN_RELOCATION_MAXIMUM_TARGETS_PER_SECTOR
		):
			continue
		if not _offscreen_position_is_fully_hidden(target_position, body_radius):
			continue
		_offscreen_selected_target_sector = actual_target_sector
		_offscreen_relocation_target_reservations[actual_target_sector] += 1
		return target_position
	return Vector2.INF


func _offscreen_random_relocation_position(
	angle: float,
	body_radius: float,
	ignored_enemy: InfectionEnemy
) -> Vector2:
	var candidate_count := OFFSCREEN_PLACEMENT_RADIAL_OFFSETS.size() * OFFSCREEN_PLACEMENT_ANGLE_OFFSETS.size()
	if candidate_count <= 0:
		return Vector2.INF
	var start_index := relocation_rng.randi_range(0, candidate_count - 1)
	# Seven is coprime with the 15 authored angle/depth combinations, so the
	# bounded attempt window samples different bands without allocations.
	for attempt in range(mini(OFFSCREEN_RELOCATION_POINT_ATTEMPTS_PER_SECTOR, candidate_count)):
		var candidate_index := (start_index + attempt * 7) % candidate_count
		var radial_jitter := relocation_rng.randf_range(
			-OFFSCREEN_RELOCATION_RADIAL_JITTER,
			OFFSCREEN_RELOCATION_RADIAL_JITTER
		)
		var position := _offscreen_spawn_candidate(
			angle,
			body_radius,
			candidate_index,
			false,
			ignored_enemy,
			true,
			radial_jitter
		)
		if position != Vector2.INF:
			return position
	return Vector2.INF


func _sector_ring_distance(first_sector: int, second_sector: int) -> int:
	var direct_distance := absi(first_sector - second_sector)
	return mini(direct_distance, WAVE_SPAWN_SECTOR_COUNT - direct_distance)


func _distance_outside_rect(position: Vector2, rect: Rect2) -> float:
	var horizontal := 0.0
	if position.x < rect.position.x:
		horizontal = rect.position.x - position.x
	elif position.x > rect.end.x:
		horizontal = position.x - rect.end.x
	var vertical := 0.0
	if position.y < rect.position.y:
		vertical = rect.position.y - position.y
	elif position.y > rect.end.y:
		vertical = position.y - rect.end.y
	return Vector2(horizontal, vertical).length()


func _rank_offscreen_sectors(pressure: PackedFloat32Array) -> void:
	_offscreen_ranked_sectors.resize(WAVE_SPAWN_SECTOR_COUNT)
	for sector in range(WAVE_SPAWN_SECTOR_COUNT):
		_offscreen_ranked_sectors[sector] = sector
	for index in range(1, WAVE_SPAWN_SECTOR_COUNT):
		var candidate_sector := int(_offscreen_ranked_sectors[index])
		var insert_index := index - 1
		while insert_index >= 0:
			var stored_sector := int(_offscreen_ranked_sectors[insert_index])
			var candidate_pressure := float(pressure[candidate_sector])
			var stored_pressure := float(pressure[stored_sector])
			if (
				candidate_pressure > stored_pressure
				or (is_equal_approx(candidate_pressure, stored_pressure) and candidate_sector >= stored_sector)
			):
				break
			_offscreen_ranked_sectors[insert_index + 1] = stored_sector
			insert_index -= 1
		_offscreen_ranked_sectors[insert_index + 1] = candidate_sector


func _enemy_can_relocate_offscreen(enemy: InfectionEnemy, source_exclusion_rect: Rect2) -> bool:
	if not is_instance_valid(enemy) or enemy.definition == null:
		return false
	if enemy.definition.is_boss or enemy.definition.id == &"minor_focus":
		return false
	if enemy.definition.id not in [&"pneumococcus", &"bacterial_cluster"]:
		return false
	if selected_level == null or selected_level.is_tutorial or intro_enemy_roles.has(enemy):
		return false
	if not enemy.activation_active or enemy.dying or not enemy.is_targetable() or enemy.is_stunned():
		return false
	var handle := enemy_world.handle_for(enemy)
	if enemy_attack_director != null and enemy_attack_director.role_for(handle) != EnemyAttackDirector.Role.NONE:
		return false
	if enemy.has_method(&"can_be_relocated") and not bool(enemy.call(&"can_be_relocated")):
		return false
	return not source_exclusion_rect.has_point(enemy.global_position)


func _shortest_signed_angle(from_angle: float, to_angle: float) -> float:
	return fposmod(to_angle - from_angle + PI, TAU) - PI

func _reset_spawn_position_sequence() -> void:
	spawn_attempt_index += 1
	spawn_rng.seed = config.random_seed
	spawn_angle_cursor = fposmod(
		spawn_rng.randf_range(0.0, TAU) + float(spawn_attempt_index - 1) * SPAWN_GOLDEN_ANGLE,
		TAU
	)

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
	if run_session != null:
		if run_session.is_active():
			run_session.cancel()
		else:
			run_session.reset()
	_fixed_step_active = false
	if run_session != null:
		run_session.event_queue.clear()
	deferred_spawn_requests.clear()
	deferred_spawn_cursor = 0
	if discovery_manager != null:
		discovery_manager.clear_pending()
	if hud != null:
		hud.hide_discovery()
		hud.hide_finding()
		hud.hide_finding_progress()
		hud.clear_active_abilities()
		hud.set_boss_direction_indicator(false, Vector2.ZERO)
		hud.update_shield(0.0, 0.0)
	if treatment_controller != null:
		treatment_controller.enabled = false
	if treatment_beam_world != null:
		treatment_beam_world.clear()
	treatment_beam_return_visualized.clear()
	if ability_controller != null:
		ability_controller.clear()
	_cancel_ability_targeting()
	if ability_feedback_world != null:
		ability_feedback_world.clear()
	if crowd_renderer != null:
		crowd_renderer.clear()
	if projectile_renderer != null:
		projectile_renderer.clear()
	if hostile_projectile_renderer != null:
		hostile_projectile_renderer.clear()
	if enemy_attack_director != null:
		enemy_attack_director.clear()
	if feedback_renderer != null:
		feedback_renderer.clear()
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
	for burst in visual_bursts:
		if is_instance_valid(burst):
			_store_visual_burst(burst)
	enemies.clear()
	projectiles.clear()
	pickups.clear()
	damage_numbers.clear()
	visual_bursts.clear()
	if enemy_world != null:
		enemy_world.clear()
	if projectile_world != null:
		projectile_world.clear()
	if pickup_world != null:
		pickup_world.clear()
	current_upgrade_options.clear()
	active_boss = null
	active_boss_handles.clear()
	active_boss_handle_by_instance.clear()
	active_boss_phase_by_handle.clear()
	boss_aggregate_maximum = 0.0
	boss_aggregate_phase = 0
	enemy_runtime_resistance_profiles.clear()
	intro_enemy_roles.clear()
	intro_pickup_roles.clear()
	intro_confirmation_kind = &""
	intro_autoattack_enabled = false
	_set_intro_prompt("", &"normal", false, "")
	active_run_context = null
	active_loadout = null
	build_state = null
	active_reaction = null
	pending_finding_definition = null
	hidden_nest_timers.clear()

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
		hud.show_pause(_can_skip_intro(), stats, state)
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
	_add_keys(&"active_ability_1", [KEY_Q])
	_add_keys(&"active_ability_2", [KEY_E])
	_add_keys(&"ui_accept", [KEY_ENTER, KEY_SPACE])
	_add_keys(&"ui_cancel", [KEY_ESCAPE])
	_add_keys(&"ui_info", [KEY_I])
	_add_joy_button(&"move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button(&"move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button(&"move_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button(&"move_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis(&"move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis(&"move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button(&"pause_game", JOY_BUTTON_START)
	_add_joy_button(&"active_ability_1", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button(&"active_ability_2", JOY_BUTTON_RIGHT_SHOULDER)
	# Y is the cross-screen information action. Reroll remains context-specific
	# on X so the same physical input never fires both commands.
	_add_joy_button(&"reroll_upgrades", JOY_BUTTON_X)
	_add_joy_button(&"ui_accept", JOY_BUTTON_A)
	_add_joy_button(&"ui_cancel", JOY_BUTTON_B)
	_add_joy_button(&"ui_info", JOY_BUTTON_Y)

func _add_keys(action: StringName, keycodes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keycodes:
		var event := InputEventKey.new()
		event.physical_keycode = int(keycode)
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)

func _add_joy_button(action: StringName, button_index: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _add_joy_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.22)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
