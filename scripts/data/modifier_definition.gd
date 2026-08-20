class_name ModifierDefinition
extends Resource

## A deterministic change to one numeric run stat. RunBuildState is the only
## place that interprets these operations, so previews and gameplay can share
## the exact same calculation.
enum Operation {
	ADD,
	MULTIPLY,
	OVERRIDE,
	CLAMP_MIN,
	CLAMP_MAX,
	ATTACK_SPEED_ADD,
}

@export var id: StringName
@export var source_id: StringName
@export var stat: StringName
@export var operation: Operation = Operation.ADD
@export var value: float = 0.0
@export var priority: int = 0
@export var required_tags: PackedStringArray = PackedStringArray()
@export var excluded_tags: PackedStringArray = PackedStringArray()

static func create(
	modifier_id: StringName,
	stat_id: StringName,
	modifier_operation: Operation,
	amount: float,
	source: StringName = &"",
	tags: PackedStringArray = PackedStringArray(),
	modifier_priority: int = 0
) -> ModifierDefinition:
	var definition := ModifierDefinition.new()
	definition.id = modifier_id
	definition.source_id = modifier_id if source.is_empty() else source
	definition.stat = stat_id
	definition.operation = modifier_operation
	definition.value = amount
	definition.required_tags = tags
	definition.priority = modifier_priority
	return definition

static func from_dict(
	data: Dictionary,
	modifier_id: StringName,
	source: StringName = &"",
	tags: PackedStringArray = PackedStringArray(),
	modifier_priority: int = 0
) -> ModifierDefinition:
	return create(
		modifier_id,
		StringName(data.get("stat_id", &"")),
		operation_from_id(StringName(data.get("operation", &"add"))),
		float(data.get("value", 0.0)),
		source,
		tags,
		modifier_priority
	)

static func operation_from_id(operation_id: StringName) -> Operation:
	match operation_id:
		&"multiply":
			return Operation.MULTIPLY
		&"override":
			return Operation.OVERRIDE
		&"clamp_min", &"minimum":
			return Operation.CLAMP_MIN
		&"clamp_max", &"maximum":
			return Operation.CLAMP_MAX
		&"attack_speed_add":
			return Operation.ATTACK_SPEED_ADD
	return Operation.ADD

func applies_to(context_tags: PackedStringArray = PackedStringArray()) -> bool:
	for required_tag in required_tags:
		if not context_tags.has(required_tag):
			return false
	for excluded_tag in excluded_tags:
		if context_tags.has(excluded_tag):
			return false
	return true
