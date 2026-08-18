class_name RewardPresentation
extends RefCounted

var _stable_id: StringName
var _icon_id: StringName
var _formatted_value: String
var _accessibility_text: String


static func create(
	stable_id_value: StringName,
	icon_id_value: StringName,
	formatted_value: String,
	accessibility_value: String
) -> RewardPresentation:
	var result := RewardPresentation.new()
	result._stable_id = stable_id_value
	result._icon_id = icon_id_value
	result._formatted_value = formatted_value
	result._accessibility_text = accessibility_value
	return result


static func research(value: int) -> RewardPresentation:
	var amount := maxi(0, value)
	return create(&"research", &"research", "+%d" % amount, "Forschung: +%d" % amount)


static func experience(value: int) -> RewardPresentation:
	var amount := maxi(0, value)
	return create(&"experience", &"analysis_pickup", "+%d" % amount, "Erfahrung: +%d" % amount)


func stable_id() -> StringName:
	return _stable_id


func icon_id() -> StringName:
	return _icon_id


func formatted_value() -> String:
	return _formatted_value


func value() -> String:
	return _formatted_value


func accessibility_text() -> String:
	return _accessibility_text


func duplicate_value() -> RewardPresentation:
	return create(_stable_id, _icon_id, _formatted_value, _accessibility_text)
