class_name PreparationBioLumenFill
extends ColorRect

## A restrained horizontal teal-to-gold membrane used only by the planning CTA.

const SHADER_CODE := """
shader_type canvas_item;

// Safe first-frame defaults match the approved planning CTA. Each visible CTA
// owns its material parameters; the compiled shader remains shared.
uniform vec4 left_color : source_color = vec4(0.396078, 0.866667, 0.823529, 1.0);
uniform vec4 right_color : source_color = vec4(0.886275, 0.776471, 0.435294, 1.0);
uniform float energy = 1.0;
uniform vec2 panel_size = vec2(220.0, 48.0);
// The membrane sits one pixel inside the button border, so its radii must be
// one pixel smaller than the outer 18/5 signature. Matching them directly
// produced transparent wedges at the large corners.
uniform vec4 corner_radii = vec4(17.0, 4.0, 17.0, 4.0);

float rounded_mask(vec2 p, vec2 extent) {
	float alpha = 1.0;
	float tl = corner_radii.x;
	float tr = corner_radii.y;
	float br = corner_radii.z;
	float bl = corner_radii.w;
	if (p.x < tl && p.y < tl) alpha *= 1.0 - smoothstep(tl - 0.75, tl + 0.25, distance(p, vec2(tl, tl)));
	if (p.x > extent.x - tr && p.y < tr) alpha *= 1.0 - smoothstep(tr - 0.75, tr + 0.25, distance(p, vec2(extent.x - tr, tr)));
	if (p.x > extent.x - br && p.y > extent.y - br) alpha *= 1.0 - smoothstep(br - 0.75, br + 0.25, distance(p, vec2(extent.x - br, extent.y - br)));
	if (p.x < bl && p.y > extent.y - bl) alpha *= 1.0 - smoothstep(bl - 0.75, bl + 0.25, distance(p, vec2(bl, extent.y - bl)));
	return alpha;
}

void fragment() {
	vec2 p = UV;
	float wave = sin((p.x * 2.1 + p.y * 0.8) * 3.14159265) * 0.025;
	float t = smoothstep(0.0, 1.0, clamp(p.x + wave, 0.0, 1.0));
	vec3 base = mix(left_color.rgb, right_color.rgb, t);
	float membrane = 0.94 + 0.06 * sin((p.x * 3.0 - p.y * 1.6) * 3.14159265);
	float alpha = rounded_mask(UV * panel_size, panel_size);
	COLOR = vec4(base * mix(0.92, 1.04, energy) * membrane, alpha);
}
"""

var host: BaseButton
var left_accent := AlveolusVisualTheme.TURQUOISE
var right_accent := AlveolusVisualTheme.GOLD
var hovered := false
var pressed := false
var _signals_connected := false

func _enter_tree() -> void:
	_connect_host()

func _exit_tree() -> void:
	_disconnect_host()

static func attach(button: BaseButton, left: Color, right: Color) -> PreparationBioLumenFill:
	var existing := button.get_node_or_null("PreparationBioLumenFill") as PreparationBioLumenFill
	if existing == null:
		existing = PreparationBioLumenFill.new()
		existing.name = "PreparationBioLumenFill"
		button.add_child(existing)
		button.move_child(existing, 0)
	existing.configure(button, left, right)
	return existing

func configure(button: BaseButton, left: Color, right: Color) -> void:
	if host != null and host != button:
		_disconnect_host()
	host = button
	left_accent = left
	right_accent = right
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 1.0
	offset_top = 1.0
	offset_right = -1.0
	offset_bottom = -1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	if not material is ShaderMaterial:
		material = BioLumenMaterialCache.material(&"planning_start", SHADER_CODE)
	if not resized.is_connected(_update_size):
		resized.connect(_update_size)
	_connect_host()
	set_process(false)
	_update_shader()
	_update_size()

## Call after changing `disabled` programmatically. All interactive state is
## otherwise updated from host signals without a persistent callback.
func refresh_state() -> void:
	_update_shader()

func _update_size() -> void:
	var fill_material := material as ShaderMaterial
	if fill_material != null:
		fill_material.set_shader_parameter(&"panel_size", Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0)))

func _connect_host() -> void:
	if host == null or _signals_connected:
		return
	host.mouse_entered.connect(_on_mouse_entered)
	host.mouse_exited.connect(_on_mouse_exited)
	host.button_down.connect(_on_button_down)
	host.button_up.connect(_on_button_up)
	host.visibility_changed.connect(refresh_state)
	_signals_connected = true

func _disconnect_host() -> void:
	if host == null or not _signals_connected or not is_instance_valid(host):
		_signals_connected = false
		return
	for signal_and_callable in [
		[host.mouse_entered, Callable(self, "_on_mouse_entered")],
		[host.mouse_exited, Callable(self, "_on_mouse_exited")],
		[host.button_down, Callable(self, "_on_button_down")],
		[host.button_up, Callable(self, "_on_button_up")],
		[host.visibility_changed, Callable(self, "refresh_state")],
	]:
		var host_signal: Signal = signal_and_callable[0]
		var callback: Callable = signal_and_callable[1]
		if host_signal.is_connected(callback):
			host_signal.disconnect(callback)
	_signals_connected = false

func _on_mouse_entered() -> void:
	hovered = true
	_update_shader()

func _on_mouse_exited() -> void:
	hovered = false
	_update_shader()

func _on_button_down() -> void:
	pressed = true
	_update_shader()

func _on_button_up() -> void:
	pressed = false
	_update_shader()

func _update_shader() -> void:
	var fill_material := material as ShaderMaterial
	if fill_material == null:
		return
	var left := left_accent.lightened(0.27)
	var right := right_accent.lightened(0.12)
	var energy := 1.0
	if host != null and host.disabled:
		left = AlveolusVisualTheme.MUTED
		right = AlveolusVisualTheme.MUTED.darkened(0.08)
		energy = 0.70
	elif pressed:
		left = left.darkened(0.09)
		right = right.darkened(0.09)
		energy = 0.88
	elif hovered:
		left = left.lightened(0.06)
		right = right.lightened(0.05)
		energy = 1.08
	fill_material.set_shader_parameter(&"left_color", left)
	fill_material.set_shader_parameter(&"right_color", right)
	fill_material.set_shader_parameter(&"energy", energy)
