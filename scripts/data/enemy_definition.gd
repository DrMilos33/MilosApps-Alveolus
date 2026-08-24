class_name EnemyDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var max_health: float
@export var speed: float
@export var base_damage: float
## Deprecated compatibility alias until the runtime damage ingress is migrated.
var contact_damage: float
@export var analysis_value: int
@export var radius: float
@export var contact_radius: float
@export var body_size_class: BodySizeCatalog.SizeClass = BodySizeCatalog.SizeClass.SMALL
@export var color: Color
@export var is_boss: bool = false
@export var player_push_enabled: bool = true
@export var discovery_id: StringName
@export var visual_id: StringName
@export var medical_name: String
@export var damage_profile: DamageProfile
@export var resistance_profile: ResistanceProfile
@export var projectile_damage: float = 0.0
@export var projectile_interval: float = 0.0
@export var projectile_pattern: StringName = &""
@export var contact_enabled: bool = true

static func create(
	definition_id: StringName,
	name: String,
	health: float,
	move_speed: float,
	damage: float,
	analysis: int,
	body_radius: float,
	body_color: Color,
	boss: bool = false,
	discovery: StringName = &"",
	visual: StringName = &"",
	medical: String = "",
	profile: DamageProfile = null,
	resistances: ResistanceProfile = null
) -> EnemyDefinition:
	var definition := EnemyDefinition.new()
	definition.id = definition_id
	definition.display_name = name
	definition.max_health = health
	definition.speed = float(roundi(move_speed))
	definition.base_damage = float(roundi(damage))
	definition.contact_damage = definition.base_damage
	definition.analysis_value = analysis
	definition.radius = body_radius
	definition.contact_radius = maxf(1.0, body_radius * 0.90)
	definition.body_size_class = BodySizeCatalog.class_for_radius(body_radius)
	definition.color = body_color
	definition.is_boss = boss
	definition.discovery_id = discovery
	definition.visual_id = definition_id if visual.is_empty() else visual
	definition.medical_name = name if medical.is_empty() else medical
	definition.damage_profile = profile if profile != null else _default_damage_profile(definition_id)
	definition.resistance_profile = resistances if resistances != null else _default_resistance_profile(definition_id)
	return definition


func configure_contact_radius(radius_value: float) -> EnemyDefinition:
	contact_radius = clampf(radius_value, 1.0, maxf(radius, 1.0))
	return self


func configure_player_push(enabled: bool) -> EnemyDefinition:
	player_push_enabled = enabled
	return self


func configure_projectile_attack(
	attack_damage: float,
	attack_interval: float,
	pattern: StringName = &"normal",
	allow_contact_damage: bool = true
) -> EnemyDefinition:
	projectile_damage = maxf(0.0, attack_damage)
	projectile_interval = maxf(0.0, attack_interval)
	projectile_pattern = pattern if projectile_damage > 0.0 and projectile_interval > 0.0 else &""
	contact_enabled = allow_contact_damage
	return self


static func _default_damage_profile(definition_id: StringName) -> DamageProfile:
	match definition_id:
		&"pneumococcus":
			return DamageProfile.single(&"pneumococcus_damage", &"fire")
		&"bacterial_cluster":
			return DamageProfile.from_components(&"bacterial_cluster_damage", {&"earth": 0.60, &"fire": 0.40})
		&"minor_focus":
			return DamageProfile.single(&"minor_focus_damage", &"wind")
		&"infection_focus", &"localized_boss", &"intro_focus":
			return DamageProfile.from_components(&"infection_focus_damage", {&"fire": 0.40, &"wind": 0.60})
	return null


static func _default_resistance_profile(definition_id: StringName) -> ResistanceProfile:
	match definition_id:
		&"pneumococcus":
			return ResistanceProfile.from_components(&"pneumococcus_resistances", {&"water": 10.0, &"earth": -10.0})
		&"bacterial_cluster":
			return ResistanceProfile.from_components(&"bacterial_cluster_resistances", {&"earth": 20.0, &"fire": -15.0})
		&"minor_focus":
			return ResistanceProfile.from_components(&"minor_focus_resistances", {&"wind": 25.0, &"water": -20.0})
		&"infection_focus", &"localized_boss", &"intro_focus":
			return ResistanceProfile.from_components(&"infection_focus_resistances", {&"fire": 15.0, &"wind": 25.0, &"water": -15.0})
	return ResistanceProfile.neutral(StringName("%s_resistances" % String(definition_id)))
