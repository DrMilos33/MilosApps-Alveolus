class_name AbilityCommand
extends RefCounted

## Immutable-by-convention input intent for one active ability. Commands are
## ordered by [member sequence] inside AbilityController and only mutate combat
## state when the fixed-step command queue is drained.

enum InputDevice {
	UNKNOWN,
	KEYBOARD_MOUSE,
	GAMEPAD,
}

var slot: int = -1
var requested_target: Vector2 = Vector2.ZERO
var sequence: int = 0
var issued_tick: int = 0
var input_device: InputDevice = InputDevice.UNKNOWN


static func create(
	ability_slot: int,
	target: Vector2,
	command_sequence: int = 0,
	device: InputDevice = InputDevice.UNKNOWN,
	tick: int = 0
) -> AbilityCommand:
	var command := AbilityCommand.new()
	command.slot = ability_slot
	command.requested_target = target
	command.sequence = command_sequence
	command.input_device = device
	command.issued_tick = maxi(tick, 0)
	return command


func is_valid() -> bool:
	return slot in [0, 1] and requested_target.is_finite()


func duplicate_command() -> AbilityCommand:
	return create(slot, requested_target, sequence, input_device, issued_tick)
