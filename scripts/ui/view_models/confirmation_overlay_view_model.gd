class_name ConfirmationOverlayViewModel
extends RefCounted

## Immutable presentation data for the shared abort/restart/intro confirmation.

const CANCEL_POLICY_CANCEL := &"cancel"
const CANCEL_POLICY_CONSUME := &"consume"

var _revision: int
var _content_hash: String
var _title: String
var _short_text: String
var _confirm_label: String
var _cancel_label: String
var _danger: bool
var _cancel_policy: StringName


func _init(
	revision_value: int = 0,
	title_value: String = "",
	short_text_value: String = "",
	confirm_label_value: String = "Bestätigen",
	cancel_label_value: String = "Zurück",
	danger_value: bool = false,
	cancel_policy_value: StringName = CANCEL_POLICY_CANCEL
) -> void:
	_revision = maxi(0, revision_value)
	_title = title_value.strip_edges()
	_short_text = short_text_value.strip_edges()
	_confirm_label = confirm_label_value.strip_edges()
	_cancel_label = cancel_label_value.strip_edges()
	if _confirm_label.is_empty():
		_confirm_label = "Bestätigen"
	if _cancel_label.is_empty():
		_cancel_label = "Zurück"
	_danger = danger_value
	_cancel_policy = _normalized_cancel_policy(cancel_policy_value)
	_content_hash = _calculate_content_hash()


func revision() -> int:
	return _revision


func content_hash() -> String:
	return _content_hash


func title() -> String:
	return _title


func short_text() -> String:
	return _short_text


func confirm_label() -> String:
	return _confirm_label


func cancel_label() -> String:
	return _cancel_label


func is_danger() -> bool:
	return _danger


func cancel_policy() -> StringName:
	return _cancel_policy


func duplicate_immutable() -> ConfirmationOverlayViewModel:
	return ConfirmationOverlayViewModel.new(
		_revision,
		String(_title),
		String(_short_text),
		String(_confirm_label),
		String(_cancel_label),
		_danger,
		StringName(_cancel_policy)
	)


func _calculate_content_hash() -> String:
	var parts := PackedStringArray([
		_signature_part(_title),
		_signature_part(_short_text),
		_signature_part(_confirm_label),
		_signature_part(_cancel_label),
		"1" if _danger else "0",
		_signature_part(String(_cancel_policy)),
	])
	return "|".join(parts).sha256_text()


static func _normalized_cancel_policy(value: StringName) -> StringName:
	if value == CANCEL_POLICY_CONSUME:
		return CANCEL_POLICY_CONSUME
	return CANCEL_POLICY_CANCEL


static func _signature_part(value: String) -> String:
	return "%d:%s" % [value.length(), value]
