class_name BioLumenMaterialCache
extends RefCounted

const SURFACE_SHADER_CODE := """
shader_type canvas_item;

// Regular material uniforms are intentional here. CanvasItem instance
// uniforms rendered as opaque black in the WebGL Compatibility export even
// though the native Compatibility renderer accepted them. Each fill receives
// a small material instance, while the compiled shader stays process-wide.
uniform vec4 left_color : source_color = vec4(0.043137, 0.231373, 0.239216, 1.0);
uniform vec4 right_color : source_color = vec4(0.023529, 0.121569, 0.149020, 1.0);
uniform vec2 panel_size = vec2(280.0, 64.0);
uniform vec4 corner_radii = vec4(15.0, 5.0, 15.0, 5.0);
uniform float energy = 1.0;

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
	float drift = sin((p.x * 1.9 + p.y * 0.72) * 3.14159265) * 0.022;
	float t = smoothstep(-0.04, 1.02, clamp(p.x + drift, 0.0, 1.0));
	vec3 base = mix(left_color.rgb, right_color.rgb, t);
	float lumen = exp(-dot((p - vec2(0.10, 0.24)) * vec2(2.1, 2.8), (p - vec2(0.10, 0.24)) * vec2(2.1, 2.8)));
	float grain = (fract(sin(dot(floor(p * panel_size), vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 0.006;
	base = base * energy + left_color.rgb * lumen * 0.105 + vec3(grain);
	float alpha = rounded_mask(UV * panel_size, panel_size);
	COLOR = vec4(base, alpha);
}
"""

## Process-wide cache for the small, fixed set of Bio-Lumen shaders.
##
## Bio-Lumen controls keep their colours, dimensions and interaction state in
## regular uniforms on a lightweight material instance. This is the portable
## path across native and WebGL Compatibility. Shader compilation remains
## shared; WeakRefs only expose the live material count to churn regression
## tests and never retain released UI resources.

static var _shaders: Dictionary = {}
static var _materials: Array[WeakRef] = []
static var _source_hashes: Dictionary = {}
static var _materials_created := 0

static func material(shader_id: StringName, source: String) -> ShaderMaterial:
	var shared_shader := shader(shader_id, source)
	# Keep the diagnostic WeakRef list bounded even when production code never
	# calls material_count() between screen rebuilds.
	_compact_material_refs()
	var instance := ShaderMaterial.new()
	instance.resource_name = "BioLumen_%s" % shader_id
	instance.resource_local_to_scene = true
	instance.shader = shared_shader
	_materials.append(weakref(instance))
	_materials_created += 1
	return instance

static func shader(shader_id: StringName, source: String) -> Shader:
	if _shaders.has(shader_id):
		assert(
			int(_source_hashes.get(shader_id, 0)) == source.hash(),
			"Bio-Lumen shader id '%s' was reused with different source." % shader_id
		)
		return _shaders[shader_id] as Shader
	var instance := Shader.new()
	instance.code = source
	_shaders[shader_id] = instance
	_source_hashes[shader_id] = source.hash()
	return instance

static func shader_count() -> int:
	return _shaders.size()

static func material_count() -> int:
	_compact_material_refs()
	return _materials.size()

static func materials_created() -> int:
	return _materials_created

static func _compact_material_refs() -> void:
	for index in range(_materials.size() - 1, -1, -1):
		if _materials[index].get_ref() == null:
			_materials.remove_at(index)
