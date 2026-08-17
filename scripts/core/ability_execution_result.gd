class_name AbilityExecutionResult
extends RefCounted

## Complete, deterministic outcome of one AbilityCommand. The simulation owns
## damage and status changes; renderers consume only this snapshot.

enum Code {
	SUCCESS,
	INVALID_COMMAND,
	EMPTY_SLOT,
	COOLDOWN,
	NOT_CONFIGURED,
	UNKNOWN_HANDLER,
	CAPACITY_REACHED,
}

var success: bool = false
var code: Code = Code.INVALID_COMMAND
var reason: String = ""
var sequence: int = 0
var slot: int = -1
var ability_id: StringName = &""
var effect_id: StringName = &""
var origin: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var radius: float = 0.0
var length: float = 0.0
var width: float = 0.0
var duration: float = 0.0
var zone_handle: int = EntityHandle.INVALID
var affected_handles: PackedInt64Array = PackedInt64Array()
var visual_points: PackedVector2Array = PackedVector2Array()
var values: Dictionary = {}


static func succeeded(command: AbilityCommand, definition: AbilityDefinition) -> AbilityExecutionResult:
	var result := AbilityExecutionResult.new()
	result.success = true
	result.code = Code.SUCCESS
	result.sequence = command.sequence if command != null else 0
	result.slot = command.slot if command != null else -1
	if definition != null:
		result.ability_id = definition.id
		result.effect_id = definition.effect_id
	return result


static func failed(
	command: AbilityCommand,
	failure_code: Code,
	message: String,
	definition: AbilityDefinition = null
) -> AbilityExecutionResult:
	var result := AbilityExecutionResult.new()
	result.code = failure_code
	result.reason = message
	result.sequence = command.sequence if command != null else 0
	result.slot = command.slot if command != null else -1
	if definition != null:
		result.ability_id = definition.id
		result.effect_id = definition.effect_id
	return result


func geometry_snapshot() -> Dictionary:
	return {
		"origin": origin,
		"target": target,
		"direction": direction,
		"radius": radius,
		"length": length,
		"width": width,
		"duration": duration,
	}
