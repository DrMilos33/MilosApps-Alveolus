class_name RunContext
extends RefCounted

enum Mode {
	CAMPAIGN,
	PRACTICE_TEST,
}

var level_id: StringName = &""
var seed: int = 0
var visible_trait_ids: Array[StringName] = []
var visible_trait_id: StringName:
	get:
		return visible_trait_ids[0] if not visible_trait_ids.is_empty() else &""
var loadout_snapshot: PreparedLoadout
var talent_snapshot: Dictionary = {}
var mode: Mode = Mode.CAMPAIGN
var practice_scenario: Variant = null
var practice_boss_profile: Variant = null

static func create(
	selected_level_id: StringName,
	case_seed: int,
	loadout: PreparedLoadout,
	active_talents: Dictionary = {},
	trait_id: StringName = &"",
	trait_ids: Array[StringName] = []
) -> RunContext:
	var context := RunContext.new()
	context.level_id = selected_level_id
	context.seed = case_seed
	context.visible_trait_ids = trait_ids.duplicate()
	if context.visible_trait_ids.is_empty() and trait_id != &"":
		context.visible_trait_ids.append(trait_id)
	context.loadout_snapshot = loadout.duplicate_loadout() if loadout != null else null
	context.talent_snapshot = active_talents.duplicate(true)
	return context


static func create_practice(
	scenario: Variant,
	boss_profile: Variant,
	case_seed: int,
	loadout: PreparedLoadout,
	active_talents: Dictionary = {}
) -> RunContext:
	var context := create(&"", case_seed, loadout, active_talents)
	context.mode = Mode.PRACTICE_TEST
	context.practice_scenario = _duplicate_value(scenario)
	context.practice_boss_profile = _duplicate_value(boss_profile)
	return context

func has_talent(id: StringName) -> bool:
	return talent_rank(id) > 0

func talent_rank(id: StringName) -> int:
	return maxi(0, int(talent_snapshot.get(id, talent_snapshot.get(String(id), 0))))

func duplicate_context() -> RunContext:
	var copy := create(
		level_id,
		seed,
		loadout_snapshot,
		talent_snapshot,
		visible_trait_id,
		visible_trait_ids
	)
	copy.mode = mode
	copy.practice_scenario = _duplicate_value(practice_scenario)
	copy.practice_boss_profile = _duplicate_value(practice_boss_profile)
	return copy


func is_practice_test() -> bool:
	return mode == Mode.PRACTICE_TEST


static func _duplicate_value(value: Variant) -> Variant:
	if value == null:
		return null
	if value is Resource:
		return (value as Resource).duplicate(true)
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	if value is RefCounted and value.has_method(&"duplicate_immutable"):
		return value.call(&"duplicate_immutable")
	if value is RefCounted and value.has_method(&"duplicate_definition"):
		return value.call(&"duplicate_definition")
	return value
