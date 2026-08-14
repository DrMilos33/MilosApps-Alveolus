class_name TutorialHintDefinition
extends Resource

@export var id: StringName
@export var trigger: StringName
@export var title: String
@export_multiline var text: String

static func create(hint_id: StringName, trigger_id: StringName, display_title: String, body: String) -> TutorialHintDefinition:
	var definition := TutorialHintDefinition.new()
	definition.id = hint_id
	definition.trigger = trigger_id
	definition.title = display_title
	definition.text = body
	return definition

