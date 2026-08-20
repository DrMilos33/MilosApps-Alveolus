class_name UpgradeDefinition
extends Resource

enum Path {
	ANTIBIOTIC,
	IMMUNE,
	SUPPORT
}

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var path: Path
@export var max_level: int
@export var effect: StringName
@export var magnitude: float
@export var visual_id: StringName
@export var medical_name: String
@export var required_component_ids: Array[StringName] = []
@export var required_upgrade_ids: Array[StringName] = []
@export var synergy_tags: Array[StringName] = []
@export var modifiers: Array[Dictionary] = []
@export var preview_stat: StringName
@export var preview_style: StringName = &"delta"
@export var preview_label: String
@export var preview_comparison_label: String
@export var preview_fallback: float = 0.0
@export var preview_decimals: int = 0
@export var preview_target: StringName
@export var preview_context_tags: PackedStringArray = PackedStringArray()

static func create(
	definition_id: StringName,
	display_title: String,
	text: String,
	upgrade_path: Path,
	levels: int,
	effect_id: StringName,
	value: float,
	medical: String = ""
) -> UpgradeDefinition:
	var definition := UpgradeDefinition.new()
	definition.id = definition_id
	definition.title = display_title
	definition.description = text
	definition.path = upgrade_path
	definition.max_level = levels
	definition.effect = effect_id
	definition.magnitude = value
	definition.visual_id = definition_id
	definition.medical_name = display_title if medical.is_empty() else medical
	return definition

func configure_pool(requirements: Array[StringName] = [], tags: Array[StringName] = []) -> UpgradeDefinition:
	required_component_ids = requirements.duplicate()
	synergy_tags = tags.duplicate()
	return self

func require_upgrades(ids: Array[StringName]) -> UpgradeDefinition:
	required_upgrade_ids = ids.duplicate()
	return self

func configure_modifiers(values: Array[Dictionary]) -> UpgradeDefinition:
	modifiers = values.duplicate(true)
	return self

## Describes how the exact resolved modifier value is rendered on an upgrade
## card. The numeric before/after values still come from RunBuildState, never
## from hand-written card text.
func configure_preview(
	stat_id: StringName,
	style: StringName,
	label: String,
	comparison_label: String = "",
	fallback: float = 0.0,
	decimals: int = 0,
	target: StringName = &"",
	context_tags: PackedStringArray = PackedStringArray()
) -> UpgradeDefinition:
	preview_stat = stat_id
	preview_style = style
	preview_label = label
	preview_comparison_label = label if comparison_label.is_empty() else comparison_label
	preview_fallback = fallback
	preview_decimals = maxi(0, decimals)
	preview_target = target
	preview_context_tags = context_tags.duplicate()
	return self


func heading_component_id(prepared_treatment_id: StringName = &"") -> StringName:
	## Upgrade cards render the resolved component name as their heading. General
	## treatment upgrades follow the currently prepared treatment dynamically.
	if preview_context_tags.has("treatment") and not preview_context_tags.has("active") and prepared_treatment_id != &"":
		return prepared_treatment_id
	if preview_context_tags.has("defense_cell") or id == &"neutrophils":
		return &"defense_cells"
	if id == &"mobility":
		return &"movement"
	return required_component_ids[0] if required_component_ids.size() == 1 else &""


func resolved_component_name(prepared_treatment: TreatmentDefinition, component_titles: Dictionary = {}) -> String:
	var component_id := heading_component_id(prepared_treatment.id if prepared_treatment != null else &"")
	if prepared_treatment != null and component_id == prepared_treatment.id:
		return prepared_treatment.display_name
	match component_id:
		&"defense_cells": return "Abwehrzellen"
		&"movement": return "Galopp"
	return String(component_titles.get(component_id, title))


func resolved_icon_id(prepared_treatment: TreatmentDefinition = null) -> StringName:
	var component_id := heading_component_id(prepared_treatment.id if prepared_treatment != null else &"")
	match component_id:
		&"defense_cells":
			return &"neutrophil_orbit"
		&"movement":
			return &"movement_training"
	if component_id != &"":
		return component_id
	match path:
		Path.IMMUNE:
			return &"neutrophil_orbit"
		Path.SUPPORT:
			return &"supportive_oxygenation"
	return prepared_treatment.id if prepared_treatment != null else &"treatment_precision"

func path_name() -> String:
	match path:
		Path.ANTIBIOTIC:
			return "BEHANDLUNG"
		Path.IMMUNE:
			return "ABWEHR"
		Path.SUPPORT:
			return "REGENERATION"
	return "BEHANDLUNG"

func medical_path_name() -> String:
	match path:
		Path.ANTIBIOTIC:
			return "Antibiotische Therapie"
		Path.IMMUNE:
			return "Immununterstützung"
		Path.SUPPORT:
			return "Supportive Therapie"
	return "Therapie"

func accent_color() -> Color:
	match path:
		Path.ANTIBIOTIC:
			return Color("159b99")
		Path.IMMUNE:
			return Color("eab553")
		Path.SUPPORT:
			return Color("3777c8")
	return Color.WHITE
