class_name ResultOverlayViewModel
extends RefCounted

## Immutable presentation data for ResultOverlay.


class StatViewModel extends RefCounted:
	var _id: StringName
	var _label: String
	var _value: String
	var _highlighted: bool

	func _init(id_value: StringName, label_value: String, value_text: String, highlighted_value: bool = false) -> void:
		_id = id_value
		_label = label_value
		_value = value_text
		_highlighted = highlighted_value

	func get_id() -> StringName:
		return _id

	func get_label() -> String:
		return _label

	func get_value() -> String:
		return _value

	func is_highlighted() -> bool:
		return _highlighted

	func duplicate_immutable() -> StatViewModel:
		return StatViewModel.new(_id, _label, _value, _highlighted)

	func append_signature(parts: PackedStringArray) -> void:
		parts.append(ResultOverlayViewModel._signature_part(String(_id)))
		parts.append(ResultOverlayViewModel._signature_part(_label))
		parts.append(ResultOverlayViewModel._signature_part(_value))
		parts.append("1" if _highlighted else "0")


var _revision: int
var _content_hash: int
var _success: bool
var _title: String
var _reason: String
var _detail: String
var _reward_text: String
var _unlock_text: String
var _mastery_text: String
var _stats: Array[StatViewModel]


func _init(
	revision_value: int = 0,
	success_value: bool = false,
	title_value: String = "",
	reason_value: String = "",
	detail_value: String = "",
	stats_value: Array[StatViewModel] = [],
	reward_text_value: String = "",
	unlock_text_value: String = "",
	mastery_text_value: String = ""
) -> void:
	_revision = maxi(revision_value, 0)
	_success = success_value
	_title = title_value
	_reason = reason_value
	_detail = detail_value
	_reward_text = reward_text_value
	_unlock_text = unlock_text_value
	_mastery_text = mastery_text_value
	_stats = _copy_stats(stats_value)
	_content_hash = _calculate_content_hash()


func get_revision() -> int:
	return _revision


func get_content_hash() -> int:
	return _content_hash


func is_success() -> bool:
	return _success


func get_title() -> String:
	return _title


func get_reason() -> String:
	return _reason


func get_detail() -> String:
	return _detail


func get_reward_text() -> String:
	return _reward_text


func get_unlock_text() -> String:
	return _unlock_text


func get_mastery_text() -> String:
	return _mastery_text


func get_stats() -> Array[StatViewModel]:
	return _copy_stats(_stats)


func duplicate_immutable() -> ResultOverlayViewModel:
	return ResultOverlayViewModel.new(
		_revision,
		_success,
		_title,
		_reason,
		_detail,
		_stats,
		_reward_text,
		_unlock_text,
		_mastery_text
	)


func _copy_stats(source: Array[StatViewModel]) -> Array[StatViewModel]:
	var result: Array[StatViewModel] = []
	for stat in source:
		if stat != null:
			result.append(stat.duplicate_immutable())
	return result


func _calculate_content_hash() -> int:
	var parts := PackedStringArray([
		"1" if _success else "0",
		_signature_part(_title),
		_signature_part(_reason),
		_signature_part(_detail),
		_signature_part(_reward_text),
		_signature_part(_unlock_text),
		_signature_part(_mastery_text),
		str(_stats.size()),
	])
	for stat in _stats:
		stat.append_signature(parts)
	return hash("|".join(parts))


static func _signature_part(value: String) -> String:
	return "%d:%s" % [value.length(), value]
