class_name PlayerStats
extends RefCounted

const BASE_MAX_HEALTH := 50.0
const BASE_DEFENSE := 0.0
const BASE_LIFE_REGENERATION := 0.0
const BASE_TREATMENT_DAMAGE := 10.0
const BASE_MOVEMENT_SPEED := 171.0

var therapy_damage: float = BASE_TREATMENT_DAMAGE
var therapy_cooldown: float = 0.965
var therapy_range: float = 480.0
var therapy_targets: int = 1
var therapy_projectiles: int = 1
var therapy_max_hits: int = 1
var immune_level: int = 0
var immune_damage: float = RunBuildState.BASE_DEFENSE_CELL_DAMAGE
var support_level: int = 0
var max_stability_bonus: float = 0.0
var defense: float = BASE_DEFENSE
var life_regeneration_per_second: float = BASE_LIFE_REGENERATION
var experience_gain_multiplier: float = 1.0
var movement_speed: float = BASE_MOVEMENT_SPEED
var resistances: ResistanceProfile = ResistanceProfile.from_components(
	&"doctor_milos_resistances",
	{&"fire": 0.0, &"water": 10.0, &"earth": 5.0, &"wind": -10.0}
)
var pickup_range: float = 180.0
var upgrade_levels: Dictionary = {}
var upgrade_family_counts: Dictionary = {}
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
	var movement_rank := int(research_ranks.get(&"movement_training", 0))
	max_stability_bonus = float(stability_rank) * 3.0
	therapy_damage = float(roundi(_treatment_base_damage * (1.0 + float(precision_rank) * 0.02)))
	experience_gain_multiplier = 1.0 + float(experience_rank) * 0.05
	defense = BASE_DEFENSE + float(defense_rank) * 2.0
	life_regeneration_per_second = BASE_LIFE_REGENERATION + float(regeneration_rank) * 0.25
	movement_speed = float(roundi(BASE_MOVEMENT_SPEED * (1.0 + float(movement_rank) * 0.03)))

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
	if definition == null:
		return UpgradePreview.create("Unbekannter Effekt", "", "")
	var current_level := int(upgrade_levels.get(definition.id, 0))
	var next_level := current_level + 1
	var level_text := str(upgrade_pick_count(definition) + 1)
	if definition.show_cap and not definition.repeatable and definition.max_level > 0:
		level_text = "Stufe %d / %d" % [next_level, definition.max_level]
	if not definition.modifiers.is_empty():
		var build := _ensure_run_build()
		var preview_tags := definition.preview_context_tags
		var component_id := definition.heading_component_id(prepared_treatment.id if prepared_treatment != null else &"")
		if prepared_treatment != null and component_id == prepared_treatment.id:
			preview_tags = prepared_treatment.tags
		else:
			for ability in prepared_abilities:
				if ability != null and component_id == ability.id:
					preview_tags = ability.tags
					break
		var preview := build.preview_upgrade(definition, current_level, preview_tags)
		preview.presentation_icon_id = definition.resolved_icon_id(prepared_treatment)
		return preview
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
			var before_rate := 1.0 / maxf(therapy_cooldown, 0.001)
			var after_rate := 1.0 / maxf(after, 0.001)
			return UpgradePreview.create(
				"+%s/s Attack Speed" % _decimal(after_rate - before_rate, 2),
				"%s/s  >  %s/s Attack Speed" % [_decimal(before_rate, 2), _decimal(after_rate, 2)],
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
			var interval := immune_interval()
			var radius := CombatDistanceScale.world_from_stage(RunBuildState.BASE_DEFENSE_CELL_RADIUS_STAGE)
			var formatted_value := "%s Schaden · %s · %s" % [
				_number(immune_damage),
				CombatRateScale.formatted_per_second(interval),
				CombatDistanceScale.formatted_radius(radius),
			]
			return UpgradePreview.create(
				"%d Abwehrzellen" % count,
				formatted_value,
				level_text,
				&"avatar",
				PackedStringArray(["Nahbereichsschutz", "Kein Bonus auf Projektile"]),
				"",
				formatted_value,
				definition.resolved_icon_id(prepared_treatment)
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
				"+%s Erfahrungsradius" % _number(definition.magnitude),
				"%s  >  %s Reichweite" % [_number(pickup_range), _number(pickup_range + definition.magnitude)],
				level_text
			)
	return UpgradePreview.create("Unbekannter Effekt", "", level_text)

func apply_upgrade(definition: UpgradeDefinition) -> bool:
	if definition == null:
		return false
	var current_level := int(upgrade_levels.get(definition.id, 0))
	var family_key := definition.resolved_family_key(prepared_treatment.id if prepared_treatment != null else &"")
	var family_count := upgrade_pick_count(definition)
	if not definition.can_offer(family_count, current_level):
		return false
	if not definition.modifiers.is_empty():
		var build := _ensure_run_build()
		if not build.apply_upgrade(definition, current_level + 1):
			return false
		upgrade_levels[definition.id] = current_level + 1
		upgrade_family_counts[family_key] = family_count + 1
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
	upgrade_family_counts[family_key] = family_count + 1
	return true


func upgrade_pick_count(definition: UpgradeDefinition) -> int:
	if definition == null:
		return 0
	var prepared_treatment_id := prepared_treatment.id if prepared_treatment != null else &""
	var family_key := definition.resolved_family_key(prepared_treatment_id)
	if upgrade_family_counts.has(family_key):
		return maxi(0, int(upgrade_family_counts[family_key]))
	# Compatibility for tests and old run snapshots that only populate the
	# per-definition counters. Run upgrades are not persisted between runs, so
	# this fallback is intentionally read-only and migration-free.
	var count := 0
	for candidate in ContentCatalog.upgrade_definitions():
		if candidate.resolved_family_key(prepared_treatment_id) == family_key:
			count += maxi(0, int(upgrade_levels.get(candidate.id, 0)))
	return count

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
	run_build_state.set_base(RunBuildState.DEFENSE_CELL_RADIUS, CombatDistanceScale.world_from_stage(RunBuildState.BASE_DEFENSE_CELL_RADIUS_STAGE))
	run_build_state.set_base(RunBuildState.DEFENSE_CELL_PROJECTILES, 2.0)
	run_build_state.set_base(RunBuildState.DEFENSE_CELL_HIT_INTERVAL, 0.2)
	run_build_state.set_base(RunBuildState.ACTIVE_COOLDOWN, ability_cooldown_multiplier)
	run_build_state.set_base(RunBuildState.FINDING_PROGRESS, finding_progress_multiplier)
	run_build_state.set_base(RunBuildState.SUPPORT_EFFECT, support_effect_multiplier)
	run_build_state.set_base(RunBuildState.PICKUP_RANGE, pickup_range)
	run_build_state.set_base(RunBuildState.MOVEMENT_SPEED, movement_speed)

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
	movement_speed = run_build_state.value(RunBuildState.MOVEMENT_SPEED, movement_speed)


func refresh_resolved_run_build() -> void:
	_sync_fields_from_build()

func immune_cell_count() -> int:
	if immune_level <= 0:
		return 0
	if run_build_state == null:
		return 2
	return clampi(roundi(run_build_state.value(RunBuildState.DEFENSE_CELL_PROJECTILES, 2.0, PackedStringArray(["defense_cell"]))), 1, 12)

func immune_interval() -> float:
	if run_build_state == null:
		return 0.2
	return maxf(0.1, run_build_state.value(
		RunBuildState.DEFENSE_CELL_HIT_INTERVAL,
		0.2,
		PackedStringArray(["defense_cell"])
	))

func immune_radius() -> float:
	if immune_level <= 0:
		return 0.0
	if run_build_state == null:
		return CombatDistanceScale.world_from_stage(RunBuildState.BASE_DEFENSE_CELL_RADIUS_STAGE)
	return maxf(1.0, run_build_state.value(
		RunBuildState.DEFENSE_CELL_RADIUS,
		CombatDistanceScale.world_from_stage(RunBuildState.BASE_DEFENSE_CELL_RADIUS_STAGE),
		PackedStringArray(["defense_cell"])
	))

func immune_orbit_radius() -> float:
	return immune_radius()

func support_recovery() -> float:
	if support_level <= 0:
		return 0.0
	var multiplier := support_effect_multiplier
	if run_build_state != null:
		multiplier = run_build_state.value(RunBuildState.SUPPORT_EFFECT, support_effect_multiplier)
	return (2.0 + float(support_level) * 2.0) * multiplier

func support_interval() -> float:
	return maxf(3.8, 6.2 - float(support_level) * 0.55)

func stat_sections(
	current_life: float = -1.0,
	maximum_life: float = -1.0,
	current_shield: float = 0.0,
	maximum_shield: float = 0.0
) -> Array[StatSectionViewModel]:
	# Character values are a live read model, not a copy of the values from run
	# start. Resolve the shared RunBuildState at presentation time so every
	# selected upgrade is visible even if a compatibility field has not been
	# mirrored yet by an older controller path.
	var treatment_tags := prepared_treatment.tags if prepared_treatment != null else PackedStringArray(["treatment", "precise", "tracking"])
	var resolved_movement_speed := run_build_state.value(RunBuildState.MOVEMENT_SPEED, movement_speed) if run_build_state != null else movement_speed
	var resolved_treatment_damage := run_build_state.value(RunBuildState.TREATMENT_DAMAGE, therapy_damage, treatment_tags) if run_build_state != null else therapy_damage
	var resolved_treatment_interval := run_build_state.value(RunBuildState.TREATMENT_INTERVAL, therapy_cooldown, treatment_tags) if run_build_state != null else therapy_cooldown
	var resolved_treatment_range := run_build_state.value(RunBuildState.TREATMENT_RANGE, therapy_range, treatment_tags) if run_build_state != null else therapy_range
	var resolved_treatment_targets := maxi(1, roundi(run_build_state.value(RunBuildState.TREATMENT_TARGETS, float(therapy_targets), treatment_tags))) if run_build_state != null else therapy_targets
	var resolved_treatment_projectiles := maxi(1, roundi(run_build_state.value(RunBuildState.TREATMENT_PROJECTILES, float(therapy_projectiles), treatment_tags))) if run_build_state != null else therapy_projectiles
	var resolved_treatment_hits := maxi(1, roundi(run_build_state.value(RunBuildState.TREATMENT_MAX_HITS, float(therapy_max_hits), treatment_tags))) if run_build_state != null else therapy_max_hits
	var life_value := "–"
	if current_life >= 0.0 and maximum_life >= 0.0:
		life_value = "%s / %s" % [_number(current_life), _number(maximum_life)]
	var general_rows: Array[Dictionary] = [
		_stat_row(&"life", "Leben", life_value),
		_stat_row(&"shield", "Schild", "%s / %s" % [_number(current_shield), _number(maximum_shield)]),
		_stat_row(&"movement_speed", "Galopp", _number(resolved_movement_speed)),
		_stat_row(
			&"defense",
			"Verteidigung",
			_number(defense),
			"Effektive Schadensminderung: %s %%" % _number(MitigationCurve.defense_effective_percent(defense))
		),
		_stat_row(&"life_regeneration", "Regeneration", "%s/s" % _number(life_regeneration_per_second)),
		_stat_row(&"experience_gain", "Erfahrung", "+%d %%" % roundi((experience_gain_multiplier - 1.0) * 100.0)),
	]
	for type_id in DamageTypeCatalog.ALL_IDS:
		general_rows.append(_stat_row(
			StringName("resistance_%s" % String(type_id)),
			"Resistenz %s" % DamageTypeCatalog.display_name(type_id),
			"%s %%" % _number(resistances.effective_percent_for_type(type_id))
		))
	var sections: Array[StatSectionViewModel] = [StatSectionViewModel.create(&"general", "ALLGEMEIN", general_rows)]
	var treatment_id := prepared_treatment.id if prepared_treatment != null else &"treatment_precision"
	var treatment_title := prepared_treatment.display_name if prepared_treatment != null else "Behandlung"
	var treatment_rows: Array[Dictionary] = [
		_stat_row(&"damage", "Schaden", _number(resolved_treatment_damage)),
		_stat_row(&"attack_speed", "Attack Speed", CombatRateScale.formatted_per_second(resolved_treatment_interval)),
		_stat_row(&"targets", "Ziele", str(resolved_treatment_targets)),
		_stat_row(&"range_stage", "Reichweite", str(CombatDistanceScale.stage_from_world(resolved_treatment_range))),
		_stat_row(&"projectiles", "Projektile", str(resolved_treatment_projectiles)),
		_stat_row(&"max_hits", "Max. Treffer", str(resolved_treatment_hits)),
	]
	_append_damage_type_rows(treatment_rows, prepared_treatment.damage_profile if prepared_treatment != null else null)
	sections.append(StatSectionViewModel.create(StringName("treatment:%s" % String(treatment_id)), treatment_title, treatment_rows))
	for slot in range(prepared_abilities.size()):
		var ability := prepared_abilities[slot]
		if ability == null:
			continue
		var ability_rows: Array[Dictionary] = []
		var cooldown_multiplier := run_build_state.value(RunBuildState.ACTIVE_COOLDOWN, ability_cooldown_multiplier, ability.tags) if run_build_state != null else ability_cooldown_multiplier
		ability_rows.append(_stat_row(&"cooldown", "Abklingzeit", "%s s" % _decimal(ability.cooldown * cooldown_multiplier, 1)))
		if ability.parameters.has("damage"):
			var damage := run_build_state.value(RunBuildState.ABILITY_DAMAGE, float(ability.parameters["damage"]), ability.tags) if run_build_state != null else float(ability.parameters["damage"])
			ability_rows.append(_stat_row(&"damage", "Schaden", _number(damage)))
			_append_damage_type_rows(ability_rows, ability.damage_profile)
		for parameter_id in [&"radius", &"range"]:
			if not ability.parameters.has(parameter_id):
				continue
			var stat_id := RunBuildState.ABILITY_RADIUS if parameter_id == &"radius" else RunBuildState.ABILITY_RANGE
			var world_value := run_build_state.value(stat_id, float(ability.parameters[parameter_id]), ability.tags) if run_build_state != null else float(ability.parameters[parameter_id])
			ability_rows.append(_stat_row(StringName("%s_stage" % String(parameter_id)), "Radius" if parameter_id == &"radius" else "Reichweite", str(CombatDistanceScale.stage_from_world(world_value))))
		sections.append(StatSectionViewModel.create(StringName("ability:%d:%s" % [slot, String(ability.id)]), ability.display_name, ability_rows))
	if immune_level > 0:
		var resolved_cell_damage := run_build_state.value(RunBuildState.DEFENSE_CELL_DAMAGE, immune_damage, PackedStringArray(["defense_cell"])) if run_build_state != null else immune_damage
		sections.append(StatSectionViewModel.create(&"ability:run:defense_cells", "Abwehrzellen", [
			_stat_row(&"damage", "Schaden", _number(resolved_cell_damage)),
			_stat_row(&"attack_speed", "Attack Speed", CombatRateScale.formatted_per_second(immune_interval())),
			_stat_row(&"projectiles", "Projektile", str(immune_cell_count())),
			_stat_row(&"radius_stage", "Radius", str(CombatDistanceScale.stage_from_world(immune_radius()))),
		]))
	if support_level > 0:
		sections.append(StatSectionViewModel.create(&"ability:run:regeneration", "Regeneration", [
			_stat_row(&"recovery", "Heilung", "+%s" % _number(support_recovery())),
			_stat_row(&"attack_speed", "Attack Speed", CombatRateScale.formatted_per_second(support_interval())),
		]))
	return sections


func _append_damage_type_rows(rows: Array[Dictionary], profile: DamageProfile) -> void:
	if profile == null:
		return
	for type_id in DamageTypeCatalog.ALL_IDS:
		var weight := profile.weight_for_type(type_id)
		if weight <= 0.0001:
			continue
		rows.append(_stat_row(
			StringName("damage_type_%s" % String(type_id)),
			DamageTypeCatalog.display_name(type_id),
			"%d %%" % roundi(weight * 100.0)
		))


func stat_rows(current_stability: float = -1.0, maximum_stability: float = -1.0, _legacy_movement_speed: float = BASE_MOVEMENT_SPEED) -> Array[Dictionary]:
	## Compatibility facade for the current GameHUD. New screens consume the
	## stable-ID stat_sections() DTOs above; this adapter preserves the existing
	## semantic groups until that UI handoff is integrated.
	var state_value := "–"
	if current_stability >= 0.0 and maximum_stability >= 0.0:
		state_value = "%s / %s" % [_number(current_stability), _number(maximum_stability)]
	var rows: Array[Dictionary] = [
		{"group": "ALLGEMEIN", "label": "Leben", "value": state_value},
		{"group": "ALLGEMEIN", "label": "Galopp", "value": _number(movement_speed)},
		{"group": "ALLGEMEIN", "label": "Verteidigung", "value": "%s %%" % _number(MitigationCurve.defense_effective_percent(defense))},
		{"group": "ALLGEMEIN", "label": "Regeneration", "value": "%s/s" % _number(life_regeneration_per_second)},
		{"group": "ALLGEMEIN", "label": "Erfahrung", "value": "+%d %%" % roundi((experience_gain_multiplier - 1.0) * 100.0)},
		{"group": "BEHANDLUNG", "label": "Schaden", "value": _number(therapy_damage)},
		{"group": "BEHANDLUNG", "label": "Attack Speed", "value": CombatRateScale.formatted_per_second(therapy_cooldown)},
		{"group": "BEHANDLUNG", "label": "Ziele", "value": str(therapy_targets)},
		{"group": "BEHANDLUNG", "label": "Reichweite", "value": str(CombatDistanceScale.stage_from_world(therapy_range))},
		{"group": "ABWEHR", "label": "Zellen", "value": str(immune_cell_count())},
		{"group": "ABWEHR", "label": "Schaden", "value": _number(immune_damage) if immune_level > 0 else "–"},
		{"group": "ABWEHR", "label": "Attack Speed", "value": CombatRateScale.formatted_per_second(immune_interval()) if immune_level > 0 else "–"},
		{"group": "ABWEHR", "label": "Radius", "value": str(CombatDistanceScale.stage_from_world(immune_radius())) if immune_level > 0 else "–"},
		{"group": "REGENERATION", "label": "Heilung", "value": "+%s" % _number(support_recovery()) if support_level > 0 else "–"},
		{"group": "REGENERATION", "label": "Intervall", "value": "%s s" % _decimal(support_interval(), 2) if support_level > 0 else "–"},
		{"group": "ERFAHRUNG", "label": "Aufnahmeradius", "value": str(CombatDistanceScale.stage_from_world(pickup_range))},
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
	return "Leben  %s\nSchaden  %s   ·   Attack Speed  %s\nZiele  %d   ·   Reichweite %d\nVerteidigung  %s %%   ·   Regeneration  %s/s\nAbwehrzellen  %d   ·   Abwehrschaden  %s\nErfahrungsradius %d" % [
		state_text,
		_number(therapy_damage),
		CombatRateScale.formatted_per_second(therapy_cooldown),
		therapy_targets,
		CombatDistanceScale.stage_from_world(therapy_range),
		_number(MitigationCurve.defense_effective_percent(defense)),
		_number(life_regeneration_per_second),
		immune_cell_count(),
		_number(immune_damage) if immune_level > 0 else "–",
		CombatDistanceScale.stage_from_world(pickup_range),
	]


func _stat_row(id: StringName, label: String, value: String, detail_text: String = "") -> Dictionary:
	var row := {"id": id, "label": label, "value": value}
	if not detail_text.is_empty():
		row["detail_text"] = detail_text
	return row

func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return _decimal(value, 1)

func _decimal(value: float, digits: int) -> String:
	return ("%.*f" % [digits, value]).replace(".", ",")
