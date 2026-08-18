class_name PlayerStats
extends RefCounted

const BASE_MAX_HEALTH := 100.0
const BASE_DEFENSE := 0.0
const BASE_LIFE_REGENERATION := 0.0
const BASE_TREATMENT_DAMAGE := 18.0

var therapy_damage: float = BASE_TREATMENT_DAMAGE
var therapy_cooldown: float = 0.82
var therapy_range: float = 470.0
var therapy_targets: int = 1
var therapy_projectiles: int = 1
var therapy_max_hits: int = 1
var immune_level: int = 0
var immune_damage: float = 10.0
var support_level: int = 0
var max_stability_bonus: float = 0.0
var defense: float = BASE_DEFENSE
var life_regeneration_per_second: float = BASE_LIFE_REGENERATION
var experience_gain_multiplier: float = 1.0
var resistances: ResistanceProfile = ResistanceProfile.from_components(
	&"doctor_milos_resistances",
	{&"fire": 0.05, &"water": 0.10, &"earth": 0.05, &"holy": 0.15, &"undead": -0.10}
)
var pickup_range: float = 185.0
var upgrade_levels: Dictionary = {}
var ability_cooldown_multiplier: float = 1.0
var finding_progress_multiplier: float = 1.0
var support_effect_multiplier: float = 1.0
var overheal_shield_cap: float = 0.0
var prepared_passive_ids: Array[StringName] = []
var _prepared_passive_ranks: Dictionary = {}
var run_build_state: RunBuildState
var prepared_treatment: TreatmentDefinition
var prepared_abilities: Array[AbilityDefinition] = []
var _treatment_base_damage: float = BASE_TREATMENT_DAMAGE

func configure_prepared_treatment(definition: TreatmentDefinition) -> void:
	if definition == null:
		return
	prepared_treatment = definition
	_treatment_base_damage = definition.base_damage
	therapy_damage = _treatment_base_damage
	therapy_cooldown = definition.base_interval
	therapy_range = definition.base_range
	therapy_targets = definition.base_targets
	therapy_projectiles = definition.base_projectiles
	therapy_max_hits = definition.max_hits

## Connects the legacy stat surface used by HUD/intro to the shared modifier
## model used by the new treatment and active-ability controllers.
func bind_run_build(build: RunBuildState, treatment: TreatmentDefinition = null, abilities: Array[AbilityDefinition] = []) -> void:
	var is_new_binding := run_build_state != build
	run_build_state = build
	if treatment != null:
		prepared_treatment = treatment
	prepared_abilities.assign(abilities)
	if is_new_binding:
		_sync_build_bases_from_fields()

func apply_meta_progression(research_ranks: Dictionary) -> void:
	var stability_rank := int(research_ranks.get(&"stability_reserve", 0))
	var precision_rank := int(research_ranks.get(&"therapy_precision", 0))
	var experience_rank := int(research_ranks.get(&"experience_gain", 0))
	var defense_rank := int(research_ranks.get(&"defense_training", 0))
	var regeneration_rank := int(research_ranks.get(&"life_regeneration", 0))
	max_stability_bonus = float(stability_rank) * 3.0
	therapy_damage = _treatment_base_damage * (1.0 + float(precision_rank) * 0.02)
	experience_gain_multiplier = 1.0 + float(experience_rank) * 0.05
	defense = BASE_DEFENSE + float(defense_rank) * 2.0
	life_regeneration_per_second = BASE_LIFE_REGENERATION + float(regeneration_rank) * 0.25

func apply_prepared_progression(research_ranks: Dictionary, passive_ids: Array[StringName]) -> void:
	# Rebuilding a prepared plan must be reversible. This is also used by tests,
	# reserve changes and future loadout previews, so applying the same plan twice
	# must never compound percentage based passives.
	for active_id in prepared_passive_ids.duplicate():
		apply_prepared_passive(active_id, research_ranks, false)
	for id in passive_ids:
		apply_prepared_passive(id, research_ranks, true)

func apply_prepared_passive(id: StringName, research_ranks: Dictionary, enabled: bool) -> void:
	var was_enabled := prepared_passive_ids.has(id)
	if enabled == was_enabled:
		return
	var direction := 1.0 if enabled else -1.0
	# Removal uses the rank that was active when the passive was equipped. A
	# research purchase outside a run therefore cannot corrupt the live baseline.
	var rank := maxi(0, int(research_ranks.get(id, 0))) if enabled else maxi(0, int(_prepared_passive_ranks.get(id, research_ranks.get(id, 0))))
	if enabled:
		prepared_passive_ids.append(id)
		_prepared_passive_ranks[id] = rank
	else:
		prepared_passive_ids.erase(id)
		_prepared_passive_ranks.erase(id)
	match id:
		&"stability_reserve":
			max_stability_bonus = maxf(0.0, max_stability_bonus + direction * float(rank) * 3.0)
		&"therapy_precision":
			var factor := 1.0 + float(rank) * 0.02
			therapy_damage = therapy_damage * factor if enabled else therapy_damage / maxf(factor, 0.001)
		&"sample_logistics":
			var factor := 1.0 + float(rank) * 0.05
			pickup_range = pickup_range * factor if enabled else pickup_range / maxf(factor, 0.001)
		&"quick_test":
			finding_progress_multiplier = 1.20 if enabled else 1.0
		&"reserve_buffer":
			overheal_shield_cap = 12.0 if enabled else 0.0
		&"defense_readiness":
			immune_level = maxi(0, immune_level + int(direction))
		&"deployment_routine":
			ability_cooldown_multiplier = 0.92 if enabled else 1.0

func has_prepared_passive(id: StringName) -> bool:
	return prepared_passive_ids.has(id)

func preview_upgrade(definition: UpgradeDefinition) -> UpgradePreview:
	var current_level := int(upgrade_levels.get(definition.id, 0))
	var next_level := current_level + 1
	var level_text := "Stufe %d / %d" % [next_level, definition.max_level]
	if not definition.modifiers.is_empty():
		var build := _ensure_run_build()
		return build.preview_upgrade(definition, current_level)
	match definition.effect:
		&"damage":
			var after := therapy_damage + definition.magnitude
			return UpgradePreview.create(
				"+%s Schaden" % _number(definition.magnitude),
				"%s Schaden  >  %s Schaden" % [_number(therapy_damage), _number(after)],
				level_text,
				&"enemy"
			)
		&"cooldown_multiplier":
			var after := maxf(0.22, therapy_cooldown * definition.magnitude)
			var percent := roundi((1.0 - after / maxf(therapy_cooldown, 0.001)) * 100.0)
			return UpgradePreview.create(
				"+%d %% Tempo" % percent,
				"%s s  >  %s s Intervall" % [_decimal(therapy_cooldown, 2), _decimal(after, 2)],
				level_text
			)
		&"range":
			return UpgradePreview.create(
				"+%s Reichweite" % _number(definition.magnitude),
				"%s  >  %s Reichweite" % [_number(therapy_range), _number(therapy_range + definition.magnitude)],
				level_text
			)
		&"targets":
			var added := int(definition.magnitude)
			return UpgradePreview.create(
				"+%d Projektil%s" % [added, "e" if added != 1 else ""],
				"%d Ziel%s  >  %d Ziele" % [therapy_targets, "e" if therapy_targets != 1 else "", therapy_targets + added],
				level_text
			)
		&"immune_level":
			var after_level := immune_level + int(definition.magnitude)
			var count := mini(after_level + 1, 4)
			var interval := maxf(0.42, 0.82 - float(after_level) * 0.06)
			var radius := 98.0 + float(after_level) * 18.0
			return UpgradePreview.create(
				"%d Abwehrzellen" % count,
				"%s Schaden alle %s s · Radius %s" % [_number(immune_damage), _decimal(interval, 2), _number(radius)],
				level_text,
				&"avatar",
				PackedStringArray(["Nahbereichsschutz", "Kein Bonus auf Projektile"])
			)
		&"immune_damage":
			return UpgradePreview.create(
				"+%s Abwehrschaden" % _number(definition.magnitude),
				"%s Schaden  >  %s Schaden" % [_number(immune_damage), _number(immune_damage + definition.magnitude)],
				level_text
			)
		&"support_level":
			var after_level := support_level + int(definition.magnitude)
			var interval := maxf(3.8, 6.2 - float(after_level) * 0.55)
			var recovery := 2.0 + float(after_level) * 2.0
			return UpgradePreview.create(
				"+%s Leben" % _number(recovery),
				"0  >  %s je Impuls · alle %s s" % [_number(recovery), _decimal(interval, 2)],
				level_text,
				&"stability_bar"
			)
		&"max_stability":
			var after_bonus := max_stability_bonus + definition.magnitude
			return UpgradePreview.create(
				"+%s Leben" % _number(definition.magnitude),
				"%s  >  %s Startbonus" % [_number(max_stability_bonus), _number(after_bonus)],
				level_text,
				&"stability_bar"
			)
		&"pickup_range":
			return UpgradePreview.create(
				"+%s Probenradius" % _number(definition.magnitude),
				"%s  >  %s Reichweite" % [_number(pickup_range), _number(pickup_range + definition.magnitude)],
				level_text
			)
	return UpgradePreview.create("Unbekannter Effekt", "", level_text)

func apply_upgrade(definition: UpgradeDefinition) -> bool:
	var current_level := int(upgrade_levels.get(definition.id, 0))
	if current_level >= definition.max_level:
		return false
	if not definition.modifiers.is_empty():
		var build := _ensure_run_build()
		if not build.apply_upgrade(definition, current_level + 1):
			return false
		upgrade_levels[definition.id] = current_level + 1
		_sync_fields_from_build()
		return true
	match definition.effect:
		&"damage":
			therapy_damage += definition.magnitude
		&"cooldown_multiplier":
			therapy_cooldown = maxf(0.22, therapy_cooldown * definition.magnitude)
		&"range":
			therapy_range += definition.magnitude
		&"targets":
			therapy_targets += int(definition.magnitude)
		&"immune_level":
			immune_level += int(definition.magnitude)
		&"immune_damage":
			immune_damage += definition.magnitude
		&"support_level":
			support_level += int(definition.magnitude)
		&"max_stability":
			max_stability_bonus += definition.magnitude
		&"pickup_range":
			pickup_range += definition.magnitude
		_:
			return false
	upgrade_levels[definition.id] = current_level + 1
	return true

func _ensure_run_build() -> RunBuildState:
	if run_build_state == null:
		if prepared_treatment == null:
			prepared_treatment = TreatmentDefinition.catalog()[&"treatment_precision"]
		run_build_state = RunBuildState.from_treatment(prepared_treatment)
		_sync_build_bases_from_fields()
	return run_build_state

func _sync_build_bases_from_fields() -> void:
	if run_build_state == null:
		return
	run_build_state.set_base(RunBuildState.TREATMENT_DAMAGE, therapy_damage)
	run_build_state.set_base(RunBuildState.TREATMENT_INTERVAL, therapy_cooldown)
	run_build_state.set_base(RunBuildState.TREATMENT_RANGE, therapy_range)
	run_build_state.set_base(RunBuildState.TREATMENT_TARGETS, float(therapy_targets))
	run_build_state.set_base(RunBuildState.TREATMENT_PROJECTILES, float(therapy_projectiles))
	run_build_state.set_base(RunBuildState.TREATMENT_MAX_HITS, float(therapy_max_hits))
	run_build_state.set_base(RunBuildState.DEFENSE_CELL_DAMAGE, immune_damage)
	run_build_state.set_base(RunBuildState.DEFENSE_CELL_RADIUS, 15.0)
	run_build_state.set_base(RunBuildState.DEFENSE_CELL_PROJECTILES, 2.0)
	run_build_state.set_base(RunBuildState.DEFENSE_CELL_HIT_INTERVAL, 0.1)
	run_build_state.set_base(RunBuildState.ACTIVE_COOLDOWN, ability_cooldown_multiplier)
	run_build_state.set_base(RunBuildState.FINDING_PROGRESS, finding_progress_multiplier)
	run_build_state.set_base(RunBuildState.SUPPORT_EFFECT, support_effect_multiplier)
	run_build_state.set_base(RunBuildState.PICKUP_RANGE, pickup_range)

func _sync_fields_from_build() -> void:
	if run_build_state == null:
		return
	var tags := prepared_treatment.tags if prepared_treatment != null else PackedStringArray(["treatment", "precise", "tracking"])
	therapy_damage = run_build_state.value(RunBuildState.TREATMENT_DAMAGE, therapy_damage, tags)
	therapy_cooldown = run_build_state.value(RunBuildState.TREATMENT_INTERVAL, therapy_cooldown, tags)
	therapy_range = run_build_state.value(RunBuildState.TREATMENT_RANGE, therapy_range, tags)
	therapy_targets = maxi(1, roundi(run_build_state.value(RunBuildState.TREATMENT_TARGETS, float(therapy_targets), tags)))
	therapy_projectiles = maxi(1, roundi(run_build_state.value(RunBuildState.TREATMENT_PROJECTILES, float(therapy_projectiles), tags)))
	therapy_max_hits = maxi(1, roundi(run_build_state.value(RunBuildState.TREATMENT_MAX_HITS, float(therapy_max_hits), tags)))
	immune_damage = run_build_state.value(RunBuildState.DEFENSE_CELL_DAMAGE, immune_damage, PackedStringArray(["defense_cell"]))
	pickup_range = run_build_state.value(RunBuildState.PICKUP_RANGE, pickup_range)

func immune_cell_count() -> int:
	if immune_level <= 0:
		return 0
	if run_build_state == null:
		return 2
	return clampi(roundi(run_build_state.value(RunBuildState.DEFENSE_CELL_PROJECTILES, 2.0, PackedStringArray(["defense_cell"]))), 1, 12)

func immune_interval() -> float:
	if run_build_state == null:
		return 0.1
	return maxf(0.1, run_build_state.value(
		RunBuildState.DEFENSE_CELL_HIT_INTERVAL,
		0.1,
		PackedStringArray(["defense_cell"])
	))

func immune_radius() -> float:
	if immune_level <= 0:
		return 0.0
	if run_build_state == null:
		return 15.0
	return maxf(1.0, run_build_state.value(
		RunBuildState.DEFENSE_CELL_RADIUS,
		15.0,
		PackedStringArray(["defense_cell"])
	))

func immune_orbit_radius() -> float:
	return 80.0 + float(immune_level) * 18.0 if immune_level > 0 else 0.0

func support_recovery() -> float:
	if support_level <= 0:
		return 0.0
	var multiplier := support_effect_multiplier
	if run_build_state != null:
		multiplier = run_build_state.value(RunBuildState.SUPPORT_EFFECT, support_effect_multiplier)
	return (2.0 + float(support_level) * 2.0) * multiplier

func support_interval() -> float:
	return maxf(3.8, 6.2 - float(support_level) * 0.55)

func stat_rows(current_stability: float = -1.0, maximum_stability: float = -1.0, movement_speed: float = 275.0) -> Array[Dictionary]:
	var state_value := "–"
	if current_stability >= 0.0 and maximum_stability >= 0.0:
		state_value = "%s / %s" % [_number(current_stability), _number(maximum_stability)]
	var rows: Array[Dictionary] = [
		{"group": "ALLGEMEIN", "label": "Leben", "value": state_value},
		{"group": "ALLGEMEIN", "label": "Bewegung", "value": _number(movement_speed)},
		{"group": "ALLGEMEIN", "label": "Verteidigung", "value": _number(defense)},
		{"group": "ALLGEMEIN", "label": "Regeneration", "value": "%s/s" % _number(life_regeneration_per_second)},
		{"group": "ALLGEMEIN", "label": "Erfahrung", "value": "+%d %%" % roundi((experience_gain_multiplier - 1.0) * 100.0)},
		{"group": "BEHANDLUNG", "label": "Schaden", "value": _number(therapy_damage)},
		{"group": "BEHANDLUNG", "label": "Intervall", "value": "%s s" % _decimal(therapy_cooldown, 2)},
		{"group": "BEHANDLUNG", "label": "Ziele", "value": str(therapy_targets)},
		{"group": "BEHANDLUNG", "label": "Reichweite", "value": _number(therapy_range)},
		{"group": "ABWEHR", "label": "Zellen", "value": str(immune_cell_count())},
		{"group": "ABWEHR", "label": "Schaden", "value": _number(immune_damage) if immune_level > 0 else "–"},
		{"group": "ABWEHR", "label": "Intervall", "value": "%s s" % _decimal(immune_interval(), 2) if immune_level > 0 else "–"},
		{"group": "ABWEHR", "label": "Radius", "value": _number(immune_radius()) if immune_level > 0 else "–"},
		{"group": "REGENERATION", "label": "Heilung", "value": "+%s" % _number(support_recovery()) if support_level > 0 else "–"},
		{"group": "REGENERATION", "label": "Intervall", "value": "%s s" % _decimal(support_interval(), 2) if support_level > 0 else "–"},
		{"group": "PROBEN", "label": "Aufnahmeradius", "value": _number(pickup_range)},
	]
	if prepared_treatment != null:
		rows.append({"group": "BEHANDLUNG", "label": "Grundimpuls", "value": prepared_treatment.display_name})
	if therapy_projectiles > 1:
		rows.append({"group": "BEHANDLUNG", "label": "Projektile", "value": str(therapy_projectiles)})
	if therapy_max_hits > 1:
		rows.append({"group": "BEHANDLUNG", "label": "Max. Treffer", "value": str(therapy_max_hits)})
	for index in range(prepared_abilities.size()):
		var ability := prepared_abilities[index]
		if ability != null:
			rows.append({"group": "AKTIV", "label": "%s · %s" % ["Q" if index == 0 else "E", ability.display_name], "value": "%s s Basis" % _decimal(ability.cooldown * ability_cooldown_multiplier, 1)})
	return rows

func compact_stat_text(current_stability: float = -1.0, maximum_stability: float = -1.0) -> String:
	var state_text := "%s/%s" % [_number(current_stability), _number(maximum_stability)] if current_stability >= 0.0 and maximum_stability >= 0.0 else "–"
	return "Leben  %s\nSchaden  %s   ·   Intervall  %s s\nZiele  %d   ·   Reichweite  %s\nVerteidigung  %s   ·   Regeneration  %s/s\nAbwehrzellen  %d   ·   Abwehrschaden  %s\nProbenradius  %s" % [
		state_text,
		_number(therapy_damage),
		_decimal(therapy_cooldown, 2),
		therapy_targets,
		_number(therapy_range),
		_number(defense),
		_number(life_regeneration_per_second),
		immune_cell_count(),
		_number(immune_damage) if immune_level > 0 else "–",
		_number(pickup_range),
	]

func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return _decimal(value, 1)

func _decimal(value: float, digits: int) -> String:
	return ("%.*f" % [digits, value]).replace(".", ",")
