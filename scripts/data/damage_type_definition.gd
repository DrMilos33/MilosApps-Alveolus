class_name DamageTypeDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var type_index: int = -1


static func create(definition_id: StringName, title: String, index_value: int) -> DamageTypeDefinition:
	var definition := DamageTypeDefinition.new()
	definition.id = definition_id
	definition.display_name = title
	definition.type_index = index_value
	return definition
