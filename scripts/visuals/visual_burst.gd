class_name VisualBurst
extends RefCounted

## Process-free data shell for one short combat feedback event. Rendering and
## lifetime are owned centrally by FeedbackRenderer.

const MAX_PARTICLES := 28

var global_position: Vector2 = Vector2.ZERO
var kind: StringName = &"soft"
var color: Color = Color.WHITE
var particle_count: int = 0
var duration: float = 0.0
var spread_radius: float = 0.0
var remaining: float = 0.0
var activation_generation: int = 0
var active: bool = false


func configure(
	visual_kind: StringName,
	visual_color: Color,
	requested_particle_count: int = 8,
	requested_duration: float = 0.32,
	requested_radius: float = 34.0
) -> VisualBurst:
	activation_generation += 1
	kind = visual_kind
	color = visual_color
	particle_count = clampi(requested_particle_count, 1, MAX_PARTICLES)
	duration = maxf(requested_duration, 0.001)
	spread_radius = maxf(requested_radius, 0.0)
	remaining = duration
	active = true
	return self


func recycle() -> void:
	active = false
	particle_count = 0
	remaining = 0.0


func progress() -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(1.0 - remaining / duration, 0.0, 1.0)
