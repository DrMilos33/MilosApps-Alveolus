class_name MetaProgressionState
extends RefCounted

const RESEARCH_GAIN_MULTIPLIER := 3.75
const RUN_RESEARCH_GAIN_MULTIPLIER := 1.50
const BOSS_RESEARCH_MULTIPLIER_PER_DEFEAT := 0.25
const INTRO_RESEARCH_REWARD := 30

signal research_changed(points: int, claimable: int)
signal clinic_changed
signal upgrades_changed
signal discoveries_changed
signal talents_changed
signal mastery_changed(new_ids: Array[StringName], earned_points: int)
signal loadouts_changed(level_id: StringName)
signal settings_changed

const SAVE_VERSION := 7
const PASSIVE_INTERVAL_SECONDS := 240.0 # V6 API compatibility; offline income is retired.
const PASSIVE_CAP_SECONDS := 28800.0
const UNLIMITED_TEST_POINT_POOL := 1_000_000_000
const TALENT_TREE_REVISION := 4
const SHARED_CAMPAIGN_LOADOUT_ID := &"campaign_shared"
const CAMPAIGN_LEVEL_IDS: Array[StringName] = [
	&"early_localized_focus", &"localized_focus", &"advancing_infection",
	&"spreading_infection", &"critical_infection", &"severe_pneumonia",
]

var research_points: int = 0
var passive_seconds: float = 0.0
var last_seen_unix: int = 0
var active_job_id: StringName = &""
var job_started_at: int = 0
var job_finishes_at: int = 0
var research_ranks: Dictionary = {}
var lifetime_runs: int = 0
var prologue_seen: bool = false
var highest_unlocked_level: int = 0
var level_records: Dictionary = {}
var intro_skipped: bool = false
var seen_discovery_ids: Dictionary = {}
var tutorial_status: Dictionary = {}
var show_run_stats: bool = false
var talent_ranks: Dictionary = {}
var bonus_talent_points: int = 0
## Compatibility view for older UI callers. Values are ranks instead of booleans;
## `bool(rank)` therefore keeps all existing read paths source-compatible.
var selected_talent_ids: Dictionary:
	get:
		return talent_ranks
	set(value):
		talent_ranks = value
var talent_tree_refund_pending: bool = false
var completed_mastery_ids: Dictionary = {}
var prepared_loadouts: Dictionary = {}
var level_case_seeds: Dictionary = {}
var case_seed_nonce: int = 0
var ui_settings: UISettingsState = UISettingsState.new()
var clock: Callable
var unlimited_test_progression: bool = false

func _init(time_provider: Callable = Callable()) -> void:
	clock = time_provider

func set_unlimited_test_progression(enabled: bool) -> void:
	if unlimited_test_progression == enabled:
		return
	unlimited_test_progression = enabled
	research_changed.emit(research_points, claimable_research())
	talents_changed.emit()

func is_unlimited_test_progression() -> bool:
	return unlimited_test_progression

func research_balance() -> int:
	return UNLIMITED_TEST_POINT_POOL if unlimited_test_progression else research_points

func can_afford_research(cost: int) -> bool:
	return cost >= 0 and (unlimited_test_progression or research_points >= cost)

func reset_defaults(now: int = -1) -> void:
	research_points = 0
	passive_seconds = 0.0
	last_seen_unix = _now() if now < 0 else now
	active_job_id = &""
	job_started_at = 0
	job_finishes_at = 0
	research_ranks = {}
	lifetime_runs = 0
	prologue_seen = false
	highest_unlocked_level = 0
	level_records = {}
	intro_skipped = false
	seen_discovery_ids = {}
	tutorial_status = {}
	show_run_stats = false
	talent_ranks = {}
	bonus_talent_points = 0
	talent_tree_refund_pending = false
	completed_mastery_ids = {}
	prepared_loadouts = {}
	level_case_seeds = {}
	case_seed_nonce = 0
	ui_settings = UISettingsState.new()
	_ensure_default_loadouts()
	research_changed.emit(research_points, claimable_research())
	clinic_changed.emit()
	upgrades_changed.emit()
	settings_changed.emit()
	talents_changed.emit()

func accrue_time(now: int = -1) -> void:
	# Offline research and timed clinic work were retired with Save v7. Keep the
	# callable as a harmless compatibility surface for older screen flows.
	last_seen_unix = _now() if now < 0 else now
	passive_seconds = 0.0

func claimable_research() -> int:
	return 0

func claim_passive() -> int:
	return 0

func start_job(definition: ClinicJobDefinition, now: int = -1) -> bool:
	return false

func is_job_complete(now: int = -1) -> bool:
	return false

func job_seconds_remaining(now: int = -1) -> int:
	return 0

func claim_job(definitions: Dictionary, now: int = -1) -> int:
	return 0

func purchase(definition: ResearchDefinition) -> bool:
	if definition == null:
		return false
	var rank := int(research_ranks.get(definition.id, 0))
	if rank >= definition.max_level:
		return false
	var cost := definition.cost_for_rank(rank)
	if not can_afford_research(cost):
		return false
	if not unlimited_test_progression:
		research_points -= cost
	research_ranks[definition.id] = rank + 1
	research_changed.emit(research_points, claimable_research())
	upgrades_changed.emit()
	return true

func rank(id: StringName) -> int:
	return int(research_ranks.get(id, 0))

func has_research(id: StringName) -> bool:
	return rank(id) > 0

func clear_research_ranks(definitions: Array[ResearchDefinition] = []) -> int:
	if research_ranks.is_empty():
		return 0
	var refunded := 0
	if not unlimited_test_progression:
		var definitions_by_id: Dictionary = {}
		for definition in definitions:
			if definition != null:
				definitions_by_id[definition.id] = definition
		for id in research_ranks:
			var definition := definitions_by_id.get(StringName(id)) as ResearchDefinition
			if definition == null:
				continue
			var purchased_rank := clampi(int(research_ranks[id]), 0, definition.max_level)
			for rank_index in range(purchased_rank):
				refunded += definition.cost_for_rank(rank_index)
		research_points += refunded
	research_ranks = {}
	research_changed.emit(research_points, claimable_research())
	upgrades_changed.emit()
	return refunded

func award_run(
	success: bool,
	elapsed: float,
	level: int,
	defeats: int,
	multiplier: float = 1.0,
	bosses_defeated: int = 0
) -> int:
	var reward := calculate_run_reward(success, elapsed, level, defeats, multiplier, bosses_defeated)
	research_points += reward
	lifetime_runs += 1
	research_changed.emit(research_points, claimable_research())
	return reward


static func calculate_run_reward(
	success: bool,
	elapsed: float,
	level: int,
	defeats: int,
	multiplier: float = 1.0,
	bosses_defeated: int = 0
) -> int:
	var survival_bonus := mini(floori(elapsed / 120.0), 5)
	var analysis_bonus := mini(maxi(level, 0), 10)
	var enemy_bonus := mini(maxi(defeats, 0) / 20, 8)
	var reward := 2 + survival_bonus + analysis_bonus + enemy_bonus
	if success:
		reward += 12
	return maxi(1, roundi(
		float(reward)
		* maxf(multiplier, 0.0)
		* RESEARCH_GAIN_MULTIPLIER
		* RUN_RESEARCH_GAIN_MULTIPLIER
		* boss_research_multiplier(bosses_defeated)
	))


static func scaled_research_gain(base_amount: float) -> int:
	return maxi(0, roundi(maxf(base_amount, 0.0) * RESEARCH_GAIN_MULTIPLIER))


static func boss_research_multiplier(bosses_defeated: int) -> float:
	return 1.0 + float(maxi(bosses_defeated, 0)) * BOSS_RESEARCH_MULTIPLIER_PER_DEFEAT


static func intro_research_reward(_bosses_defeated: int = 0) -> int:
	return INTRO_RESEARCH_REWARD

func is_level_unlocked(order: int) -> bool:
	return order <= highest_unlocked_level

func get_level_record(level_id: StringName) -> LevelRecord:
	if not level_records.has(level_id):
		level_records[level_id] = LevelRecord.new()
	return level_records[level_id]

func register_level_result(definition: LevelDefinition, success: bool, elapsed: float, analysis_level: int, defeats: int) -> bool:
	var record := get_level_record(definition.id)
	record.register_result(success, elapsed, analysis_level, defeats)
	var unlocked_new_level := false
	if success and definition.order >= highest_unlocked_level and highest_unlocked_level < ContentCatalog.level_definitions().size() - 1:
		highest_unlocked_level = definition.order + 1
		unlocked_new_level = true
	return unlocked_new_level

func has_completed_level(level_id: StringName) -> bool:
	return get_level_record(level_id).victories > 0

func mark_prologue_seen() -> void:
	prologue_seen = true

func has_seen_discovery(id: StringName) -> bool:
	return ContentCatalog.is_discovery_unlocked_by_default(id) or bool(seen_discovery_ids.get(id, false))

func mark_discovery_seen(id: StringName) -> void:
	if id == &"" or has_seen_discovery(id):
		return
	seen_discovery_ids[id] = true
	discoveries_changed.emit()

func mark_intro_skipped() -> void:
	intro_skipped = true
	highest_unlocked_level = maxi(highest_unlocked_level, 1)

func set_tutorial_step(key: StringName, completed: bool = true) -> void:
	tutorial_status[key] = completed

func grant_intro_completion_rewards(bosses_defeated: int = 0) -> bool:
	if bool(tutorial_status.get(&"intro_completion_rewards", false)):
		return false
	research_points += intro_research_reward(bosses_defeated)
	tutorial_status[&"intro_completion_rewards"] = true
	tutorial_status[&"research_guidance_pending"] = true
	research_changed.emit(research_points, claimable_research())
	return true

func talent_points_earned() -> int:
	var catalog := MasteryObjectiveDefinition.catalog()
	var total := 0
	for id in completed_mastery_ids:
		if catalog.has(id):
			var definition: MasteryObjectiveDefinition = catalog[id]
			total += definition.reward_points
	return total + bonus_talent_points

func talent_points_spent() -> int:
	var catalog := TalentDefinition.catalog()
	var total := 0
	for id in talent_ranks:
		if not catalog.has(id):
			continue
		var definition: TalentDefinition = catalog[id]
		var purchased_ranks := clampi(int(talent_ranks[id]), 0, definition.max_rank)
		for purchased_rank in range(purchased_ranks):
			total += definition.cost_for_rank(purchased_rank)
	return total

func available_talent_points() -> int:
	if unlimited_test_progression:
		return UNLIMITED_TEST_POINT_POOL
	return maxi(0, talent_points_earned() - talent_points_spent())

func has_talent(id: StringName) -> bool:
	return talent_rank(id) > 0

func talent_rank(id: StringName) -> int:
	return maxi(0, int(talent_ranks.get(id, 0)))

func loadout_capacity() -> int:
	return LoadoutValidator.DEFAULT_CAPACITY

func preparation_capacity() -> int:
	return loadout_capacity()

func unlocked_module_ids(module_definitions: Dictionary, research_definitions: Array[ResearchDefinition] = []) -> Dictionary:
	var unlocked: Dictionary = {}
	for id in module_definitions:
		var definition: Variant = module_definitions[id]
		if definition is LoadoutModuleDefinition:
			var module: LoadoutModuleDefinition = definition
			if module.starter or (module.unlock_research_id != &"" and rank(module.unlock_research_id) > 0):
				unlocked[StringName(id)] = true
		elif definition is Dictionary:
			var starter := bool(definition.get("starter", false))
			var research_id := StringName(str(definition.get("unlock_research_id", "")))
			if starter or (research_id != &"" and rank(research_id) > 0):
				unlocked[StringName(id)] = true
	for research in research_definitions:
		if research != null and research.unlock_module_id != &"" and rank(research.id) > 0 and module_definitions.has(research.unlock_module_id):
			unlocked[research.unlock_module_id] = true
	return unlocked

func validate_prepared_loadout(
	loadout: PreparedLoadout,
	module_definitions: Dictionary,
	research_definitions: Array[ResearchDefinition] = []
) -> LoadoutValidationResult:
	return LoadoutValidator.validate(
		loadout,
		module_definitions,
		unlocked_module_ids(module_definitions, research_definitions),
		preparation_capacity()
	)

func set_talent_selection(ids: Array[StringName]) -> bool:
	var requested: Dictionary = {}
	for id in ids:
		if id != &"":
			requested[id] = 1
	if not _talent_ranks_are_valid(requested, true):
		return false
	talent_ranks = requested
	talent_tree_refund_pending = false
	talents_changed.emit()
	return true

func set_talent_active(id: StringName, active: bool) -> bool:
	if active:
		return true if has_talent(id) else set_talent_rank(id, 1)
	return set_talent_rank(id, 0)

func set_talent_rank(id: StringName, new_rank: int) -> bool:
	var catalog := TalentDefinition.catalog()
	if not catalog.has(id):
		return false
	var definition: TalentDefinition = catalog[id]
	if new_rank < 0 or new_rank > definition.max_rank:
		return false
	var requested := talent_ranks.duplicate(true)
	if new_rank == 0:
		requested.erase(id)
	else:
		requested[id] = new_rank
	if not _talent_ranks_are_valid(requested, true):
		return false
	if requested == talent_ranks:
		return true
	talent_ranks = requested
	talent_tree_refund_pending = false
	talents_changed.emit()
	return true

func purchase_talent_rank(id: StringName) -> bool:
	var catalog := TalentDefinition.catalog()
	if not catalog.has(id):
		return false
	var definition: TalentDefinition = catalog[id]
	var current_rank := talent_rank(id)
	if current_rank >= definition.max_rank:
		return false
	return set_talent_rank(id, current_rank + 1)

func clear_talents() -> void:
	if talent_ranks.is_empty() and not talent_tree_refund_pending:
		return
	talent_ranks = {}
	talent_tree_refund_pending = false
	talents_changed.emit()

func complete_mastery(id: StringName) -> bool:
	var catalog := MasteryObjectiveDefinition.catalog()
	if id == &"" or not catalog.has(id) or bool(completed_mastery_ids.get(id, false)):
		return false
	completed_mastery_ids[id] = true
	var definition: MasteryObjectiveDefinition = catalog[id]
	var new_ids: Array[StringName] = [id]
	mastery_changed.emit(new_ids, definition.reward_points)
	return true

func apply_mastery_candidates(ids: Array[StringName]) -> Array[StringName]:
	var added: Array[StringName] = []
	var points := 0
	var catalog := MasteryObjectiveDefinition.catalog()
	for id in ids:
		if id == &"" or not catalog.has(id) or bool(completed_mastery_ids.get(id, false)):
			continue
		completed_mastery_ids[id] = true
		added.append(id)
		var definition: MasteryObjectiveDefinition = catalog[id]
		points += definition.reward_points
	if not added.is_empty():
		mastery_changed.emit(added, points)
	return added

func has_completed_mastery(id: StringName) -> bool:
	return bool(completed_mastery_ids.get(id, false))

func get_prepared_loadout(level_id: StringName) -> PreparedLoadout:
	var storage_id := SHARED_CAMPAIGN_LOADOUT_ID if CAMPAIGN_LEVEL_IDS.has(level_id) else level_id
	if not prepared_loadouts.has(storage_id) or not (prepared_loadouts[storage_id] is PreparedLoadout):
		prepared_loadouts[storage_id] = _default_loadout_from_research()
	var loadout: PreparedLoadout = prepared_loadouts[storage_id]
	return loadout.duplicate_loadout()

func set_prepared_loadout(level_id: StringName, loadout: PreparedLoadout) -> bool:
	if level_id == &"" or loadout == null:
		return false
	if CAMPAIGN_LEVEL_IDS.has(level_id):
		prepared_loadouts[SHARED_CAMPAIGN_LOADOUT_ID] = loadout.duplicate_loadout()
	else:
		prepared_loadouts[level_id] = loadout.duplicate_loadout()
	loadouts_changed.emit(level_id)
	return true

func get_or_create_case_seed(level_id: StringName) -> int:
	var existing := int(level_case_seeds.get(level_id, 0))
	if existing != 0:
		return existing
	case_seed_nonce += 1
	var generated := absi(hash("%s:%d:%d:%d" % [String(level_id), _now(), lifetime_runs, case_seed_nonce])) + 1
	level_case_seeds[level_id] = generated
	return generated

func clear_case_seed(level_id: StringName) -> void:
	level_case_seeds.erase(level_id)

func advance_case_seed(level_id: StringName) -> int:
	if level_id == &"":
		return 0
	var previous_seed := get_or_create_case_seed(level_id)
	case_seed_nonce += 1
	var generated := absi(hash("%s:%d:%d:%d" % [
		String(level_id), previous_seed, lifetime_runs, case_seed_nonce
	])) + 1
	if generated == previous_seed:
		generated = 1 if previous_seed == 2147483647 else previous_seed + 1
	level_case_seeds[level_id] = generated
	return generated

func create_run_context(
	level_id: StringName,
	visible_trait_id: StringName = &"",
	hidden_finding_id: StringName = &""
) -> RunContext:
	return RunContext.create(
		level_id,
		get_or_create_case_seed(level_id),
		get_prepared_loadout(level_id),
		talent_ranks,
		visible_trait_id,
		hidden_finding_id
	)

func to_dict() -> Dictionary:
	var serialized_records: Dictionary = {}
	for id in level_records:
		var record: LevelRecord = level_records[id]
		serialized_records[String(id)] = record.to_dict()
	var serialized_loadouts: Dictionary = {}
	for id in prepared_loadouts:
		if prepared_loadouts[id] is PreparedLoadout:
			var loadout: PreparedLoadout = prepared_loadouts[id]
			serialized_loadouts[String(id)] = LoadoutSlotSaveAdapter.serialize_loadout(loadout)
	var serialized_seeds: Dictionary = {}
	for id in level_case_seeds:
		serialized_seeds[String(id)] = int(level_case_seeds[id])
	return {
		"version": SAVE_VERSION,
		"research_points": research_points,
		"research_ranks": research_ranks.duplicate(true),
		"lifetime_runs": lifetime_runs,
		"prologue_seen": prologue_seen,
		"highest_unlocked_level": highest_unlocked_level,
		"level_records": serialized_records,
		"intro_skipped": intro_skipped,
		"seen_discovery_ids": seen_discovery_ids.keys().map(func(id: Variant) -> String: return String(id)),
		"tutorial_status": tutorial_status.duplicate(true),
		"show_run_stats": show_run_stats,
		"talent_ranks": _string_keyed_rank_dictionary(talent_ranks),
		"bonus_talent_points": bonus_talent_points,
		# Kept for one compatibility cycle so older diagnostics can still display
		# which nodes are active. V6 loading exclusively trusts `talent_ranks`.
		"selected_talent_ids": _positive_dictionary_keys(talent_ranks),
		"talent_tree_revision": TALENT_TREE_REVISION,
		"talent_tree_refund_pending": talent_tree_refund_pending,
		"completed_mastery_ids": _true_dictionary_keys(completed_mastery_ids),
		"prepared_loadouts": serialized_loadouts,
		"level_case_seeds": serialized_seeds,
		"case_seed_nonce": case_seed_nonce,
		"ui_settings": ui_settings.to_dict(),
	}

func load_dict(data: Dictionary) -> bool:
	var version := int(data.get("version", -1))
	if version < 1 or version > SAVE_VERSION:
		return false
	# V4 stored variable-length ability/passive arrays. Normalize the complete
	# container first so every V5 load below sees the same fixed-slot schema and
	# legacy surplus entries can never leak back into a five-slot plan.
	if version == 4:
		data = LoadoutSlotSaveAdapter.migrate_v4_save(data)
		version = int(data.get("version", version))
	research_points = maxi(0, int(data.get("research_points", 0)))
	passive_seconds = 0.0
	last_seen_unix = _now()
	active_job_id = &""
	job_started_at = 0
	job_finishes_at = 0
	var loaded_ranks: Variant = data.get("research_ranks", {})
	research_ranks = {}
	if typeof(loaded_ranks) == TYPE_DICTIONARY:
		for id in loaded_ranks:
			research_ranks[StringName(str(id))] = maxi(0, int(loaded_ranks[id]))
	lifetime_runs = maxi(0, int(data.get("lifetime_runs", 0)))
	prologue_seen = bool(data.get("prologue_seen", false)) if version >= 2 else false
	var stored_unlock := int(data.get("highest_unlocked_level", 0)) if version >= 2 else 0
	highest_unlocked_level = _migrated_unlocked_order(stored_unlock, version)
	level_records = {}
	if version >= 2:
		var loaded_records: Variant = data.get("level_records", {})
		if typeof(loaded_records) == TYPE_DICTIONARY:
			for id in loaded_records:
				if typeof(loaded_records[id]) == TYPE_DICTIONARY:
					level_records[StringName(str(id))] = LevelRecord.from_dict(loaded_records[id])
	intro_skipped = bool(data.get("intro_skipped", false)) if version >= 3 else false
	seen_discovery_ids = {}
	if version >= 3:
		var loaded_discoveries: Variant = data.get("seen_discovery_ids", [])
		if typeof(loaded_discoveries) == TYPE_ARRAY:
			for id in loaded_discoveries:
				seen_discovery_ids[StringName(str(id))] = true
		elif typeof(loaded_discoveries) == TYPE_DICTIONARY:
			for id in loaded_discoveries:
				if bool(loaded_discoveries[id]):
					seen_discovery_ids[StringName(str(id))] = true
		var loaded_tutorial: Variant = data.get("tutorial_status", {})
		tutorial_status = loaded_tutorial.duplicate(true) if typeof(loaded_tutorial) == TYPE_DICTIONARY else {}
	else:
		tutorial_status = {}
	show_run_stats = bool(data.get("show_run_stats", false))
	talent_ranks = {}
	# The earlier prototype granted this field at the end of the intro. Talent
	# points now begin with Fall 2 mastery, so old intro bonuses are normalized.
	bonus_talent_points = 0
	talent_tree_refund_pending = false
	completed_mastery_ids = {}
	prepared_loadouts = {}
	level_case_seeds = {}
	case_seed_nonce = 0
	ui_settings = UISettingsState.from_dict(data.get("ui_settings", {})) if version >= 5 else UISettingsState.new()
	if version >= 4:
		completed_mastery_ids = _known_id_dictionary(data.get("completed_mastery_ids", []), MasteryObjectiveDefinition.catalog())
		if version >= 6:
			var stored_tree_revision := int(data.get("talent_tree_revision", 1))
			var requested_ranks := _known_rank_dictionary(data.get("talent_ranks", {}), TalentDefinition.catalog())
			if stored_tree_revision == TALENT_TREE_REVISION and _talent_ranks_are_valid(requested_ranks, true):
				talent_ranks = requested_ranks
				talent_tree_refund_pending = bool(data.get("talent_tree_refund_pending", false))
			else:
				talent_ranks = {}
				talent_tree_refund_pending = not requested_ranks.is_empty()
		else:
			# V5 and older stored boolean node IDs from the retired tree. Mastery
			# remains untouched, so every earned point is immediately available.
			var legacy_talents := _any_positive_dictionary(data.get("selected_talent_ids", []))
			talent_ranks = {}
			talent_tree_refund_pending = not legacy_talents.is_empty()
		var loaded_loadouts: Variant = data.get("prepared_loadouts", {})
		if typeof(loaded_loadouts) == TYPE_DICTIONARY:
			for id in loaded_loadouts:
				if typeof(loaded_loadouts[id]) == TYPE_DICTIONARY:
					prepared_loadouts[StringName(str(id))] = LoadoutSlotSaveAdapter.deserialize_loadout(loaded_loadouts[id])
		var loaded_seeds: Variant = data.get("level_case_seeds", {})
		if typeof(loaded_seeds) == TYPE_DICTIONARY:
			for id in loaded_seeds:
				var seed := int(loaded_seeds[id])
				if seed != 0:
					level_case_seeds[StringName(str(id))] = seed
		case_seed_nonce = maxi(0, int(data.get("case_seed_nonce", level_case_seeds.size())))
	_ensure_default_loadouts()
	return true

func set_ui_settings(settings: UISettingsState) -> void:
	ui_settings = settings.duplicate_settings() if settings != null else UISettingsState.new()
	settings_changed.emit()

func _ensure_default_loadouts() -> void:
	var shared: PreparedLoadout = prepared_loadouts.get(SHARED_CAMPAIGN_LOADOUT_ID) as PreparedLoadout
	if shared == null:
		for order in range(mini(highest_unlocked_level, CAMPAIGN_LEVEL_IDS.size()), 0, -1):
			var candidate_id := CAMPAIGN_LEVEL_IDS[order - 1]
			var candidate := prepared_loadouts.get(candidate_id) as PreparedLoadout
			if candidate != null:
				shared = candidate.duplicate_loadout()
				break
	if shared == null:
		for level_id in CAMPAIGN_LEVEL_IDS:
			var candidate := prepared_loadouts.get(level_id) as PreparedLoadout
			if candidate != null:
				shared = candidate.duplicate_loadout()
				break
	if shared == null:
		shared = _default_loadout_from_research()
	prepared_loadouts[SHARED_CAMPAIGN_LOADOUT_ID] = shared.duplicate_loadout()
	for level_id in CAMPAIGN_LEVEL_IDS:
		if not prepared_loadouts.has(level_id):
			prepared_loadouts[level_id] = shared.duplicate_loadout()


static func _migrated_unlocked_order(stored_order: int, source_version: int) -> int:
	var maximum := ContentCatalog.level_definitions().size() - 1
	if source_version >= 7:
		return clampi(stored_order, 0, maximum)
	# V6 and older exposed three campaign anchors at orders 1/2/3. Their stable
	# IDs now live at 2/4/6; intermediate cases below the mapped anchor become
	# available without rewriting records, seeds or loadouts.
	match clampi(stored_order, 0, 3):
		1:
			return 2
		2:
			return 4
		3:
			return 6
	return 0

func _default_loadout_from_research() -> PreparedLoadout:
	# Research ownership remains stored, but passive modules are intentionally
	# outside the current combat-balancing catalog.
	return PreparedLoadout.default_loadout()

static func _true_dictionary_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id in source:
		if bool(source[id]):
			result.append(String(id))
	result.sort()
	return result

static func _known_id_dictionary(value: Variant, catalog: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) == TYPE_ARRAY:
		for raw_id in value:
			var id := StringName(str(raw_id))
			if catalog.has(id):
				result[id] = true
	elif typeof(value) == TYPE_DICTIONARY:
		for raw_id in value:
			var id := StringName(str(raw_id))
			if bool(value[raw_id]) and catalog.has(id):
				result[id] = true
	return result

func _talent_ranks_are_valid(requested: Dictionary, enforce_economy: bool) -> bool:
	var catalog := TalentDefinition.catalog()
	var spent := 0
	for raw_id in requested:
		var id := StringName(str(raw_id))
		if not catalog.has(id):
			return false
		var definition: TalentDefinition = catalog[id]
		var purchased_rank := int(requested[raw_id])
		if purchased_rank <= 0 or purchased_rank > definition.max_rank:
			return false
		for rank_index in range(purchased_rank):
			spent += definition.cost_for_rank(rank_index)
		for required_id in definition.required_ids:
			if int(requested.get(StringName(required_id), requested.get(String(required_id), 0))) <= 0:
				return false
	if enforce_economy and not unlimited_test_progression and spent > talent_points_earned():
		return false
	return true

static func _known_rank_dictionary(value: Variant, catalog: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for raw_id in value:
		var id := StringName(str(raw_id))
		if not catalog.has(id):
			continue
		var definition: TalentDefinition = catalog[id]
		var loaded_rank := clampi(int(value[raw_id]), 0, definition.max_rank)
		if loaded_rank > 0:
			result[id] = loaded_rank
	return result

static func _string_keyed_rank_dictionary(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id in source:
		var purchased_rank := maxi(0, int(source[id]))
		if purchased_rank > 0:
			result[String(id)] = purchased_rank
	return result

static func _positive_dictionary_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id in source:
		if int(source[id]) > 0:
			result.append(String(id))
	result.sort()
	return result

static func _any_positive_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) == TYPE_ARRAY:
		for raw_id in value:
			if str(raw_id) != "":
				result[StringName(str(raw_id))] = true
	elif typeof(value) == TYPE_DICTIONARY:
		for raw_id in value:
			if bool(value[raw_id]):
				result[StringName(str(raw_id))] = true
	return result

func _now() -> int:
	if clock.is_valid():
		return int(clock.call())
	return int(Time.get_unix_time_from_system())
