class_name RunContext
extends RefCounted

var level_id: StringName = &""
var seed: int = 0
var visible_trait_id: StringName = &""
var hidden_finding_id: StringName = &""
var loadout_snapshot: PreparedLoadout
var talent_snapshot: Dictionary = {}

static func create(
	selected_level_id: StringName,
	case_seed: int,
	loadout: PreparedLoadout,
	active_talents: Dictionary = {},
	trait_id: StringName = &"",
	finding_id: StringName = &""
) -> RunContext:
	var context := RunContext.new()
	context.level_id = selected_level_id
	context.seed = case_seed
	context.visible_trait_id = trait_id
	context.hidden_finding_id = finding_id
	context.loadout_snapshot = loadout.duplicate_loadout() if loadout != null else null
	context.talent_snapshot = active_talents.duplicate(true)
	return context

func has_talent(id: StringName) -> bool:
	return bool(talent_snapshot.get(id, false))

func duplicate_context() -> RunContext:
	return create(level_id, seed, loadout_snapshot, talent_snapshot, visible_trait_id, hidden_finding_id)
