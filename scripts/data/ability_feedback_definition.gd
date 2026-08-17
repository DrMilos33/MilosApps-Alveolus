class_name AbilityFeedbackDefinition
extends Resource

## Data-only visual language shared by active abilities and base treatments.

enum Shape {
	RING,
	FIELD,
	LINE,
	PULL,
	TRACER,
}

@export var source_id: StringName = &""
@export var effect_id: StringName = &""
@export var shape: Shape = Shape.RING
@export var primary_color: Color = Color.WHITE
@export var secondary_color: Color = Color.WHITE
@export var duration: float = 0.3
@export var line_width: float = 5.0
@export var fill_alpha: float = 0.12
@export var persistent: bool = false
@export var inward: bool = false
@export var effect_priority: CosmeticBudgetController.EffectPriority = CosmeticBudgetController.EffectPriority.CRITICAL
@export var audio_cue: StringName = &""


static func create(
	id: StringName,
	effect: StringName,
	visual_shape: Shape,
	primary: Color,
	secondary: Color,
	visual_duration: float,
	stroke_width: float,
	alpha: float,
	is_persistent: bool = false,
	is_inward: bool = false,
	audio: StringName = &"ability_cast"
) -> AbilityFeedbackDefinition:
	var definition := AbilityFeedbackDefinition.new()
	definition.source_id = id
	definition.effect_id = effect
	definition.shape = visual_shape
	definition.primary_color = primary
	definition.secondary_color = secondary
	definition.duration = maxf(visual_duration, 0.01)
	definition.line_width = maxf(stroke_width, 1.0)
	definition.fill_alpha = clampf(alpha, 0.0, 1.0)
	definition.persistent = is_persistent
	definition.inward = is_inward
	definition.audio_cue = audio
	return definition


static func catalog() -> Dictionary:
	return {
		&"ability_focus_field": create(
			&"ability_focus_field", &"focus_field", Shape.FIELD,
			Color("159b99"), Color("8ce2d5"), 7.0, 5.0, 0.115, true, true, &"ability_focus"
		),
		&"ability_emergency_support": create(
			&"ability_emergency_support", &"emergency_support", Shape.RING,
			Color("3777c8"), Color("dcebf0"), 0.48, 7.0, 0.12, false, false, &"ability_support"
		),
		&"ability_defense_burst": create(
			&"ability_defense_burst", &"defense_burst", Shape.RING,
			Color("eab553"), Color("fff0b8"), 0.34, 8.0, 0.10, false, false, &"ability_burst"
		),
		&"ability_treatment_line": create(
			&"ability_treatment_line", &"treatment_line", Shape.LINE,
			Color("49cfe0"), Color("e1fbff"), 0.22, 8.0, 0.08, false, false, &"ability_line"
		),
		&"ability_protection_field": create(
			&"ability_protection_field", &"protective_field", Shape.FIELD,
			Color("3777c8"), Color("83b8f2"), 6.0, 5.0, 0.105, true, false, &"ability_field"
		),
		&"ability_sample_pull": create(
			&"ability_sample_pull", &"sample_pull", Shape.PULL,
			Color("159b99"), Color("d8fff6"), 0.52, 5.0, 0.08, false, true, &"ability_pull"
		),
		&"treatment_precision": create(
			&"treatment_precision", &"treatment_precision", Shape.TRACER,
			Color("159b99"), Color("d8fff6"), 0.20, 4.0, 0.0, false, false, &"treatment_precise"
		),
		&"treatment_spread": create(
			&"treatment_spread", &"treatment_spread", Shape.TRACER,
			Color("ef7766"), Color("ffe1d9"), 0.24, 5.0, 0.0, false, false, &"treatment_spread"
		),
		&"treatment_pierce": create(
			&"treatment_pierce", &"treatment_pierce", Shape.LINE,
			Color("3777c8"), Color("dcebf0"), 0.20, 6.0, 0.06, false, false, &"treatment_pierce"
		),
	}


static func validate_catalog() -> PackedStringArray:
	var errors := PackedStringArray()
	var definitions := catalog()
	var required: Array[StringName] = []
	required.append_array(AbilityDefinition.catalog().keys())
	required.append_array(TreatmentDefinition.catalog().keys())
	for source_id in required:
		if not definitions.has(source_id):
			errors.append("Fehlendes Feedback: %s" % source_id)
			continue
		var definition := definitions[source_id] as AbilityFeedbackDefinition
		if definition == null or definition.source_id != source_id:
			errors.append("Ungültige Feedbackdefinition: %s" % source_id)
		elif definition.duration <= 0.0 or definition.line_width <= 0.0:
			errors.append("Ungültige Geometrie: %s" % source_id)
	return errors
