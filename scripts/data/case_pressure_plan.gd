class_name CasePressurePlan
extends Resource

## Authored, movement-independent schedule for one main-case pressure layer.
##
## The plan deliberately contains no content IDs or save-facing state. The
## integration layer translates a due target-focus event into the existing
## runtime spawn request and supplies intro/boss state to the director.

@export var target_focus_times: PackedFloat32Array = PackedFloat32Array()
@export var projectile_gate_times: PackedFloat32Array = PackedFloat32Array()
@export_range(0, 64, 1) var max_active_targets: int = 0


static func create(
	target_times: PackedFloat32Array,
	gate_times: PackedFloat32Array,
	active_target_limit: int
) -> CasePressurePlan:
	var plan := CasePressurePlan.new()
	plan.target_focus_times = _normalized_times(target_times)
	plan.projectile_gate_times = _normalized_times(gate_times)
	plan.max_active_targets = maxi(active_target_limit, 0)
	return plan


static func default_for_case_order(case_order: int) -> CasePressurePlan:
	match case_order:
		1:
			return create(
				PackedFloat32Array([25.0, 60.0, 95.0, 130.0]),
				PackedFloat32Array(),
				2
			)
		2:
			return create(
				PackedFloat32Array([20.0, 60.0, 100.0, 140.0]),
				PackedFloat32Array(),
				1
			)
		3:
			return create(
				PackedFloat32Array([20.0, 60.0, 100.0, 140.0]),
				PackedFloat32Array([45.0, 85.0, 125.0]),
				1
			)
	return create(PackedFloat32Array(), PackedFloat32Array(), 0)


static func _normalized_times(authored_times: PackedFloat32Array) -> PackedFloat32Array:
	var sorted_times := authored_times.duplicate()
	sorted_times.sort()
	var normalized := PackedFloat32Array()
	for scheduled_time in sorted_times:
		if not is_finite(scheduled_time) or scheduled_time < 0.0:
			continue
		if not normalized.is_empty() and is_equal_approx(normalized[-1], scheduled_time):
			continue
		normalized.append(scheduled_time)
	return normalized
