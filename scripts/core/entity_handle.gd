class_name EntityHandle
extends RefCounted

## Compact generation-safe entity reference. Slot zero is stored as one so the
## all-zero integer remains the universal invalid handle.

const INVALID: int = 0
const SLOT_MASK: int = 0xFFFFFFFF
const GENERATION_MASK: int = 0x7FFFFFFF

static func make(slot_index: int, generation_value: int) -> int:
	if slot_index < 0 or generation_value <= 0:
		return INVALID
	var stored_slot := (slot_index + 1) & SLOT_MASK
	var safe_generation := generation_value & GENERATION_MASK
	if stored_slot == 0 or safe_generation == 0:
		return INVALID
	return (safe_generation << 32) | stored_slot

static func slot(handle: int) -> int:
	if not is_valid(handle):
		return -1
	return int(handle & SLOT_MASK) - 1

static func generation(handle: int) -> int:
	if handle == INVALID:
		return 0
	return int((handle >> 32) & GENERATION_MASK)

static func is_valid(handle: int) -> bool:
	return handle != INVALID and (handle & SLOT_MASK) != 0 and generation(handle) > 0

static func matches(handle: int, slot_index: int, generation_value: int) -> bool:
	return is_valid(handle) and slot(handle) == slot_index and generation(handle) == generation_value

static func next_generation(current: int) -> int:
	var result := (maxi(current, 0) + 1) & GENERATION_MASK
	return 1 if result == 0 else result
