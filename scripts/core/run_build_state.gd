class_name RunBuildState
extends RefCounted

signal changed(stat: StringName)

## Shared public stat IDs. New systems may add more StringName stats without
## changing this class; these constants only prevent spelling drift in the
## combat foundation.
const TREATMENT_DAMAGE := &"therapy_damage"
const TREATMENT_INTERVAL := &"therapy_cooldown"
const TREATMENT_RANGE := &"therapy_range"
const TREATMENT_TARGETS := &"therapy_targets"
const TREATMENT_PROJECTILES := &"therapy_projectiles"
const TREATMENT_MAX_HITS := &"treatment_max_hits"
const TREATMENT_SPREAD := &"treatment_spread"
const TREATMENT_BEAM_DURATION := &"treatment_beam_duration"
const TREATMENT_BEAM_TICK := &"treatment_beam_tick"
const TREATMENT_BEAM_RETURN := &"treatment_beam_return"
const TREATMENT_MANUAL_AIM := &"treatment_manual_aim"
const DEFENSE_CELL_DAMAGE := &"defense_cell_damage"
const DEFENSE_CELL_RADIUS := &"defense_cell_radius"
const DEFENSE_CELL_PROJECTILES := &"defense_cell_projectiles"
const DEFENSE_CELL_HIT_INTERVAL := &"defense_cell_hit_interval"
const ACTIVE_COOLDOWN := &"ability_cooldown"
const ABILITY_DAMAGE := &"ability_damage"
const ABILITY_RADIUS := &"ability_radius"
const ABILITY_DURATION := &"ability_duration"
const ABILITY_RANGE := &"ability_range"
const ABILITY_RECOVERY := &"ability_recovery"
const ABILITY_SHIELD := &"shield"
const ABILITY_KNOCKBACK := &"ability_knockback"
const ABILITY_WIDTH := &"ability_width"
const ABILITY_ENEMY_SPEED := &"ability_enemy_speed"
const ABILITY_CONTACT := &"ability_contact"
const MARKED_DAMAGE := &"marked_damage"
const FINDING_PROGRESS := &"finding_progress"
const SUPPORT_EFFECT := &"support_effect"
const PICKUP_RANGE := &"pickup_range"
const MOVEMENT_SPEED := &"movement_speed"
const BASE_DEFENSE_CELL_DAMAGE := 5.4
const BASE_DEFENSE_CELL_RADIUS_STAGE := 4

var _base_values: Dictionary = {}
var _modifiers: Array[ModifierDefinition] = []

func _init(base_values: Dictionary = {}) -> void:
	for stat_id in base_values:
		_base_values[StringName(stat_id)] = float(base_values[stat_id])

static func from_treatment(definition: TreatmentDefinition) -> RunBuildState:
	if definition == null:
		return RunBuildState.new()
	return RunBuildState.new({
		TREATMENT_DAMAGE: definition.base_damage,
		TREATMENT_INTERVAL: definition.base_interval,
		TREATMENT_RANGE: definition.base_range,
		TREATMENT_TARGETS: definition.base_targets,
		TREATMENT_PROJECTILES: definition.base_projectiles,
		TREATMENT_MAX_HITS: definition.max_hits,
		TREATMENT_SPREAD: definition.spread_degrees,
		TREATMENT_BEAM_DURATION: 0.0,
		TREATMENT_BEAM_TICK: 0.25,
		TREATMENT_BEAM_RETURN: 0.0,
		TREATMENT_MANUAL_AIM: 0.0,
		DEFENSE_CELL_DAMAGE: BASE_DEFENSE_CELL_DAMAGE,
		DEFENSE_CELL_RADIUS: CombatDistanceScale.world_from_stage(BASE_DEFENSE_CELL_RADIUS_STAGE),
		DEFENSE_CELL_PROJECTILES: 2.0,
		DEFENSE_CELL_HIT_INTERVAL: 0.1,
		ACTIVE_COOLDOWN: 1.0,
		FINDING_PROGRESS: 1.0,
		SUPPORT_EFFECT: 1.0,
	})

func set_base(stat: StringName, amount: float) -> void:
	_base_values[stat] = amount
	changed.emit(stat)

func base_value(stat: StringName, fallback: float = 0.0) -> float:
	return float(_base_values.get(stat, fallback))

func add_modifier(definition: ModifierDefinition) -> bool:
	if definition == null or definition.id.is_empty() or definition.stat.is_empty():
		return false
	remove_modifier(definition.id, false)
	_modifiers.append(definition)
	changed.emit(definition.stat)
	return true

func add_modifier_dictionary(source_id: StringName, index: int, data: Dictionary) -> bool:
	var stat_id := StringName(str(data.get("stat_id", "")))
	if stat_id == &"":
		return false
	var operation_id := StringName(str(data.get("operation", "add")))
	var operation := ModifierDefinition.Operation.ADD
	match operation_id:
		&"multiply":
			operation = ModifierDefinition.Operation.MULTIPLY
		&"override":
			operation = ModifierDefinition.Operation.OVERRIDE
		&"clamp_min":
			operation = ModifierDefinition.Operation.CLAMP_MIN
		&"clamp_max":
			operation = ModifierDefinition.Operation.CLAMP_MAX
	var required_tags := PackedStringArray()
	for tag in data.get("required_tags", []):
		required_tags.append(String(tag))
	var modifier := ModifierDefinition.create(
		StringName("%s_%d" % [String(source_id), index]),
		stat_id,
		operation,
		float(data.get("value", 0.0)),
		source_id,
		required_tags,
		int(data.get("priority", 0))
	)
	for tag in data.get("excluded_tags", []):
		modifier.excluded_tags.append(String(tag))
	return add_modifier(modifier)

## Adds one level of an upgrade. Each level has a unique source so repeated
## additive and multiplicative upgrades stack while remaining removable.
func apply_upgrade(definition: UpgradeDefinition, level: int) -> bool:
	if definition == null or definition.modifiers.is_empty() or level <= 0:
		return false
	var source_id := StringName("upgrade_%s_%d" % [String(definition.id), level])
	var applied := 0
	for index in range(definition.modifiers.size()):
		if add_modifier_dictionary(source_id, index, definition.modifiers[index]):
			applied += 1
	return applied == definition.modifiers.size()

## Uses a duplicated build plus apply_upgrade(), so this preview cannot drift
## from the value that gameplay receives after choosing the card.
func preview_upgrade(definition: UpgradeDefinition, current_level: int = 0) -> UpgradePreview:
	if definition == null:
		return UpgradePreview.create("Unbekannter Effekt", "", "")
	var next_level := current_level + 1
	var level_text := "Stufe %d / %d" % [next_level, definition.max_level]
	if definition.preview_stat.is_empty() or definition.modifiers.is_empty():
		return UpgradePreview.create("Unbekannter Effekt", "", level_text)
	var tags := definition.preview_context_tags
	var before := value(definition.preview_stat, definition.preview_fallback, tags)
	var candidate := duplicate_state()
	if not candidate.apply_upgrade(definition, next_level):
		return UpgradePreview.create("Unbekannter Effekt", "", level_text)
	var after := candidate.value(definition.preview_stat, definition.preview_fallback, tags)
	return _format_upgrade_preview(definition, before, after, level_text)

func remove_modifier(id: StringName, notify: bool = true) -> bool:
	for index in range(_modifiers.size() - 1, -1, -1):
		if _modifiers[index].id != id:
			continue
		var stat_id := _modifiers[index].stat
		_modifiers.remove_at(index)
		if notify:
			changed.emit(stat_id)
		return true
	return false

func remove_source(source_id: StringName) -> int:
	var removed := 0
	var changed_stats: Dictionary = {}
	for index in range(_modifiers.size() - 1, -1, -1):
		if _modifiers[index].source_id != source_id:
			continue
		changed_stats[_modifiers[index].stat] = true
		_modifiers.remove_at(index)
		removed += 1
	for stat_id in changed_stats:
		changed.emit(stat_id)
	return removed

func has_modifier(id: StringName) -> bool:
	return _modifiers.any(func(item: ModifierDefinition) -> bool: return item.id == id)

func modifiers_for(stat: StringName, context_tags: PackedStringArray = PackedStringArray()) -> Array[ModifierDefinition]:
	var result: Array[ModifierDefinition] = []
	for definition in _modifiers:
		if definition.stat == stat and definition.applies_to(context_tags):
			result.append(definition)
	result.sort_custom(func(left: ModifierDefinition, right: ModifierDefinition) -> bool:
		if left.priority == right.priority:
			return String(left.id) < String(right.id)
		return left.priority < right.priority
	)
	return result

## Resolution order is intentionally fixed: additions, multipliers, the
## highest-priority override, then lower/upper clamps. This makes modifier
## previews independent of insertion order.
func value(stat: StringName, fallback: float = 0.0, context_tags: PackedStringArray = PackedStringArray()) -> float:
	var resolved := base_value(stat, fallback)
	var additive := 0.0
	var multiplier := 1.0
	var override_found := false
	var override_value := 0.0
	var override_priority := -2147483648
	var minimum := -INF
	var maximum := INF
	for definition in modifiers_for(stat, context_tags):
		match definition.operation:
			ModifierDefinition.Operation.ADD:
				additive += definition.value
			ModifierDefinition.Operation.MULTIPLY:
				multiplier *= definition.value
			ModifierDefinition.Operation.OVERRIDE:
				if not override_found or definition.priority >= override_priority:
					override_found = true
					override_priority = definition.priority
					override_value = definition.value
			ModifierDefinition.Operation.CLAMP_MIN:
				minimum = maxf(minimum, definition.value)
			ModifierDefinition.Operation.CLAMP_MAX:
				maximum = minf(maximum, definition.value)
	resolved = override_value if override_found else (resolved + additive) * multiplier
	if minimum > maximum:
		# A minimum is the safety boundary when contradictory modifiers exist.
		maximum = minimum
	resolved = clampf(resolved, minimum, maximum)
	return CombatDistanceScale.quantize_world(resolved) if CombatDistanceScale.is_staged_stat(stat) else resolved

func value_with(candidate: ModifierDefinition, fallback: float = 0.0, context_tags: PackedStringArray = PackedStringArray()) -> float:
	if candidate == null:
		return fallback
	var previous: ModifierDefinition = null
	for item in _modifiers:
		if item.id == candidate.id:
			previous = item
			break
	if previous != null:
		_modifiers.erase(previous)
	_modifiers.append(candidate)
	var result := value(candidate.stat, fallback, context_tags)
	_modifiers.erase(candidate)
	if previous != null:
		_modifiers.append(previous)
	return result

func snapshot(stats: PackedStringArray, context_tags: PackedStringArray = PackedStringArray()) -> Dictionary:
	var result: Dictionary = {}
	for stat_id in stats:
		result[stat_id] = value(stat_id, 0.0, context_tags)
	return result

func duplicate_state() -> RunBuildState:
	var copy := RunBuildState.new(_base_values.duplicate(true))
	copy._modifiers.assign(_modifiers)
	return copy

func _format_upgrade_preview(definition: UpgradeDefinition, before: float, after: float, level_text: String) -> UpgradePreview:
	var label := definition.preview_label
	var comparison_label := definition.preview_comparison_label
	var before_text := _formatted_number(before, definition.preview_decimals)
	var after_text := _formatted_number(after, definition.preview_decimals)
	var delta := after - before
	var effect_text := "%s%s %s" % [_sign(delta), _formatted_effect_number(absf(delta), definition.preview_decimals), label]
	var formatted_before := "%s %s" % [before_text, comparison_label]
	var formatted_after := "%s %s" % [after_text, comparison_label]
	match definition.preview_style:
		&"distance_stage":
			var before_stage := CombatDistanceScale.stage_from_world(before)
			var after_stage := CombatDistanceScale.stage_from_world(after)
			effect_text = "%s%d" % [_sign(float(after_stage - before_stage)), absi(after_stage - before_stage)]
			formatted_before = str(before_stage)
			formatted_after = str(after_stage)
		&"tempo":
			var percent := roundi((1.0 - after / maxf(before, 0.001)) * 100.0)
			effect_text = "+%d %% Rate" % percent
			formatted_before = CombatRateScale.formatted_per_second(before)
			formatted_after = CombatRateScale.formatted_per_second(after)
		&"cooldown":
			var percent := roundi((1.0 - after / maxf(before, 0.001)) * 100.0)
			effect_text = "-%d %% Abklingzeit" % percent
			formatted_before = "%s s" % before_text
			formatted_after = "%s s" % after_text
		&"percent":
			var percent := roundi(absf(after / maxf(before, 0.001) - 1.0) * 100.0)
			effect_text = "%s%d %% %s" % [_sign(delta), percent, label]
		&"seconds":
			effect_text = "%s%s s %s" % [_sign(delta), _formatted_number(absf(delta), definition.preview_decimals), label]
			formatted_before = "%s s %s" % [before_text, comparison_label]
			formatted_after = "%s s %s" % [after_text, comparison_label]
		&"count":
			effect_text = "%s%d %s" % [_sign(delta), roundi(absf(delta)), label]
			if comparison_label == "Ziele":
				formatted_before = "%d %s" % [roundi(before), "Ziel" if roundi(before) == 1 else "Ziele"]
				formatted_after = "%d %s" % [roundi(after), "Ziel" if roundi(after) == 1 else "Ziele"]
			else:
				formatted_before = str(roundi(before))
				formatted_after = "%d %s" % [roundi(after), comparison_label]
	var comparison := "%s  >  %s" % [formatted_before, formatted_after]
	return UpgradePreview.create(
		effect_text,
		comparison,
		level_text,
		definition.preview_target,
		PackedStringArray(),
		formatted_before,
		formatted_after,
		definition.resolved_icon_id()
	)

func _formatted_number(value: float, decimals: int) -> String:
	if decimals <= 0:
		return str(roundi(value))
	return ("%.*f" % [decimals, value]).replace(".", ",")

func _formatted_effect_number(value: float, decimals: int) -> String:
	var formatted := _formatted_number(value, decimals)
	while formatted.contains(",") and formatted.ends_with("0"):
		formatted = formatted.left(-1)
	if formatted.ends_with(","):
		formatted = formatted.left(-1)
	return formatted

func _sign(value: float) -> String:
	return "+" if value >= 0.0 else "-"
