class_name MetaProgressionState
extends RefCounted

signal research_changed(points: int, claimable: int)
signal clinic_changed
signal upgrades_changed
signal discoveries_changed

const SAVE_VERSION := 3
const PASSIVE_INTERVAL_SECONDS := 600.0
const PASSIVE_CAP_SECONDS := 28800.0

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
var clock: Callable

func _init(time_provider: Callable = Callable()) -> void:
	clock = time_provider

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
	research_changed.emit(research_points, claimable_research())
	clinic_changed.emit()
	upgrades_changed.emit()

func accrue_time(now: int = -1) -> void:
	var current_time := _now() if now < 0 else now
	if last_seen_unix <= 0:
		last_seen_unix = current_time
		return
	var elapsed := maxi(0, current_time - last_seen_unix)
	if elapsed > 0:
		passive_seconds = minf(PASSIVE_CAP_SECONDS, passive_seconds + float(elapsed))
		last_seen_unix = current_time
		research_changed.emit(research_points, claimable_research())
	elif current_time > last_seen_unix:
		last_seen_unix = current_time

func claimable_research() -> int:
	return floori(passive_seconds / PASSIVE_INTERVAL_SECONDS)

func claim_passive() -> int:
	var amount := claimable_research()
	if amount <= 0:
		return 0
	passive_seconds -= float(amount) * PASSIVE_INTERVAL_SECONDS
	research_points += amount
	research_changed.emit(research_points, claimable_research())
	return amount

func start_job(definition: ClinicJobDefinition, now: int = -1) -> bool:
	if definition == null or active_job_id != &"":
		return false
	var current_time := _now() if now < 0 else now
	active_job_id = definition.id
	job_started_at = current_time
	job_finishes_at = current_time + definition.duration_seconds
	clinic_changed.emit()
	return true

func is_job_complete(now: int = -1) -> bool:
	if active_job_id == &"":
		return false
	var current_time := _now() if now < 0 else now
	return current_time >= job_finishes_at

func job_seconds_remaining(now: int = -1) -> int:
	if active_job_id == &"":
		return 0
	var current_time := _now() if now < 0 else now
	return maxi(0, job_finishes_at - current_time)

func claim_job(definitions: Dictionary, now: int = -1) -> int:
	if not is_job_complete(now) or not definitions.has(active_job_id):
		return 0
	var definition: ClinicJobDefinition = definitions[active_job_id]
	var reward := definition.reward
	research_points += reward
	active_job_id = &""
	job_started_at = 0
	job_finishes_at = 0
	research_changed.emit(research_points, claimable_research())
	clinic_changed.emit()
	return reward

func purchase(definition: ResearchDefinition) -> bool:
	if definition == null:
		return false
	var rank := int(research_ranks.get(definition.id, 0))
	if rank >= definition.max_level:
		return false
	var cost := definition.cost_for_rank(rank)
	if cost <= 0 or research_points < cost:
		return false
	research_points -= cost
	research_ranks[definition.id] = rank + 1
	research_changed.emit(research_points, claimable_research())
	upgrades_changed.emit()
	return true

func rank(id: StringName) -> int:
	return int(research_ranks.get(id, 0))

func has_research(id: StringName) -> bool:
	return rank(id) > 0

func award_run(success: bool, elapsed: float, level: int, defeats: int, multiplier: float = 1.0) -> int:
	var survival_bonus := mini(floori(elapsed / 120.0), 5)
	var analysis_bonus := mini(maxi(level, 0), 10)
	var enemy_bonus := mini(maxi(defeats, 0) / 20, 8)
	var reward := 2 + survival_bonus + analysis_bonus + enemy_bonus
	if success:
		reward += 12
	reward = maxi(1, roundi(float(reward) * maxf(multiplier, 0.0)))
	research_points += reward
	lifetime_runs += 1
	research_changed.emit(research_points, claimable_research())
	return reward

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
	return bool(seen_discovery_ids.get(id, false))

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

func to_dict() -> Dictionary:
	var serialized_records: Dictionary = {}
	for id in level_records:
		var record: LevelRecord = level_records[id]
		serialized_records[String(id)] = record.to_dict()
	return {
		"version": SAVE_VERSION,
		"research_points": research_points,
		"passive_seconds": passive_seconds,
		"last_seen_unix": last_seen_unix,
		"active_job_id": String(active_job_id),
		"job_started_at": job_started_at,
		"job_finishes_at": job_finishes_at,
		"research_ranks": research_ranks.duplicate(true),
		"lifetime_runs": lifetime_runs,
		"prologue_seen": prologue_seen,
		"highest_unlocked_level": highest_unlocked_level,
		"level_records": serialized_records,
		"intro_skipped": intro_skipped,
		"seen_discovery_ids": seen_discovery_ids.keys().map(func(id: Variant) -> String: return String(id)),
		"tutorial_status": tutorial_status.duplicate(true)
	}

func load_dict(data: Dictionary) -> bool:
	var version := int(data.get("version", -1))
	if version < 1 or version > SAVE_VERSION:
		return false
	research_points = maxi(0, int(data.get("research_points", 0)))
	passive_seconds = clampf(float(data.get("passive_seconds", 0.0)), 0.0, PASSIVE_CAP_SECONDS)
	last_seen_unix = int(data.get("last_seen_unix", _now()))
	active_job_id = StringName(str(data.get("active_job_id", "")))
	job_started_at = maxi(0, int(data.get("job_started_at", 0)))
	job_finishes_at = maxi(0, int(data.get("job_finishes_at", 0)))
	var loaded_ranks: Variant = data.get("research_ranks", {})
	research_ranks = {}
	if typeof(loaded_ranks) == TYPE_DICTIONARY:
		for id in loaded_ranks:
			research_ranks[StringName(str(id))] = maxi(0, int(loaded_ranks[id]))
	lifetime_runs = maxi(0, int(data.get("lifetime_runs", 0)))
	prologue_seen = bool(data.get("prologue_seen", false)) if version >= 2 else false
	highest_unlocked_level = clampi(int(data.get("highest_unlocked_level", 0)), 0, ContentCatalog.level_definitions().size() - 1) if version >= 2 else 0
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
	return true

func _now() -> int:
	if clock.is_valid():
		return int(clock.call())
	return int(Time.get_unix_time_from_system())
