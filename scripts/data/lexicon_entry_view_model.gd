class_name LexiconEntryViewModel
extends RefCounted

class TypePresentation:
	extends RefCounted

	var _type_id: StringName
	var _icon_id: StringName
	var _semantic_role: StringName
	var _display_name: String
	var _percent: float
	var _value_role: StringName
	var _formatted_value: String
	var _meaning: String
	var _indicator: StringName

	var type_id: StringName:
		get: return _type_id
	var icon_id: StringName:
		get: return _icon_id
	var semantic_role: StringName:
		get: return _semantic_role
	var display_name: String:
		get: return _display_name
	var percent: float:
		get: return _percent
	var value_role: StringName:
		get: return _value_role
	var formatted_value: String:
		get: return _formatted_value
	var meaning: String:
		get: return _meaning
	var indicator: StringName:
		get: return _indicator

	static func create(
		type_id_value: StringName,
		icon_id_value: StringName,
		semantic_role_value: StringName,
		display_name_value: String,
		percent_value: float,
		value_role_value: StringName
	) -> TypePresentation:
		var result := TypePresentation.new()
		result._type_id = type_id_value
		result._icon_id = icon_id_value
		result._semantic_role = semantic_role_value
		result._display_name = display_name_value
		result._percent = percent_value
		result._value_role = value_role_value
		result._formatted_value = _percent_text(percent_value, semantic_role_value == &"resistance_effective")
		result._meaning = _meaning_for(semantic_role_value, value_role_value)
		result._indicator = value_role_value
		return result

	static func _percent_text(value: float, include_sign: bool) -> String:
		var absolute := absf(value)
		var number := str(roundi(absolute)) if is_equal_approx(absolute, roundf(absolute)) else ("%.1f" % absolute).replace(".", ",")
		var sign := "+" if include_sign and value > 0.0 else ("-" if value < 0.0 else "")
		return "%s%s %%" % [sign, number]

	static func _meaning_for(semantic_role_value: StringName, value_role_value: StringName) -> String:
		if semantic_role_value == &"damage_share":
			return "Schadensanteil"
		match value_role_value:
			&"mitigation": return "Minderung"
			&"vulnerability": return "Verwundbarkeit"
		return "Neutral"


class RelatedTermPresentation:
	extends RefCounted

	var _id: StringName
	var _display_name: String
	var _explanation: String
	var _icon_id: StringName

	var id: StringName:
		get: return _id
	var display_name: String:
		get: return _display_name
	var explanation: String:
		get: return _explanation
	var meaning: String:
		get: return _explanation
	var icon_id: StringName:
		get: return _icon_id

	static func create(
		id_value: StringName,
		display_name_value: String,
		explanation_value: String,
		icon_id_value: StringName
	) -> RelatedTermPresentation:
		var result := RelatedTermPresentation.new()
		result._id = id_value
		result._display_name = display_name_value
		result._explanation = explanation_value
		result._icon_id = icon_id_value
		return result

	func duplicate_value() -> RelatedTermPresentation:
		return create(_id, _display_name, _explanation, _icon_id)

var id: StringName
var category: StringName
var display_name: String
var medical_name: String
var summary: String
var gameplay_text: String
var medical_text: String
var visual_id: StringName
var locked: bool = false
var stat_rows: Array[StatRowViewModel] = []
var related_names: PackedStringArray = PackedStringArray()
var _type_presentations: Array[TypePresentation] = []
var _related_term_presentations: Array[RelatedTermPresentation] = []

func has_details() -> bool:
	return not locked


func set_type_presentations(values: Array[TypePresentation]) -> void:
	_type_presentations.assign(values)


func type_presentations() -> Array[TypePresentation]:
	var result: Array[TypePresentation] = []
	result.assign(_type_presentations)
	return result


func set_related_term_presentations(values: Array[RelatedTermPresentation]) -> void:
	_related_term_presentations.clear()
	related_names.clear()
	for value in values:
		if value == null:
			continue
		var copy := value.duplicate_value()
		_related_term_presentations.append(copy)
		related_names.append(copy.display_name)


func related_term_presentations() -> Array[RelatedTermPresentation]:
	var result: Array[RelatedTermPresentation] = []
	for value in _related_term_presentations:
		result.append(value.duplicate_value())
	return result
