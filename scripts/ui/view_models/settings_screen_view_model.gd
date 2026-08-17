class_name SettingsScreenViewModel
extends RefCounted

## Immutable presentation data for SettingsScreen.


class AudioSettingViewModel extends RefCounted:
	var _id: StringName
	var _label: String
	var _linear_value: float
	var _muted: bool

	func _init(id_value: StringName, label_value: String, linear_value: float, muted_value: bool) -> void:
		_id = id_value
		_label = label_value
		_linear_value = clampf(linear_value, 0.0, 1.0)
		_muted = muted_value

	func get_id() -> StringName:
		return _id

	func get_label() -> String:
		return _label

	func get_linear_value() -> float:
		return _linear_value

	func is_muted() -> bool:
		return _muted

	func duplicate_immutable() -> AudioSettingViewModel:
		return AudioSettingViewModel.new(_id, _label, _linear_value, _muted)

	func append_signature(parts: PackedStringArray) -> void:
		parts.append(SettingsScreenViewModel._signature_part(String(_id)))
		parts.append(SettingsScreenViewModel._signature_part(_label))
		parts.append("%.6f" % _linear_value)
		parts.append("1" if _muted else "0")


class OptionSettingViewModel extends RefCounted:
	var _id: StringName
	var _label: String
	var _entries: Array[String]
	var _selected_index: int
	var _visible: bool

	func _init(
		id_value: StringName,
		label_value: String,
		entries_value: Array[String],
		selected_index_value: int,
		visible_value: bool = true
	) -> void:
		_id = id_value
		_label = label_value
		_entries = entries_value.duplicate()
		_selected_index = clampi(selected_index_value, 0, maxi(_entries.size() - 1, 0))
		_visible = visible_value

	func get_id() -> StringName:
		return _id

	func get_label() -> String:
		return _label

	func get_entries() -> Array[String]:
		return _entries.duplicate()

	func get_selected_index() -> int:
		return _selected_index

	func is_visible() -> bool:
		return _visible

	func duplicate_immutable() -> OptionSettingViewModel:
		return OptionSettingViewModel.new(_id, _label, _entries, _selected_index, _visible)

	func append_signature(parts: PackedStringArray) -> void:
		parts.append(SettingsScreenViewModel._signature_part(String(_id)))
		parts.append(SettingsScreenViewModel._signature_part(_label))
		parts.append(str(_selected_index))
		parts.append("1" if _visible else "0")
		parts.append(str(_entries.size()))
		for entry in _entries:
			parts.append(SettingsScreenViewModel._signature_part(entry))


class ToggleSettingViewModel extends RefCounted:
	var _id: StringName
	var _label: String
	var _enabled: bool
	var _visible: bool

	func _init(id_value: StringName, label_value: String, enabled_value: bool, visible_value: bool = true) -> void:
		_id = id_value
		_label = label_value
		_enabled = enabled_value
		_visible = visible_value

	func get_id() -> StringName:
		return _id

	func get_label() -> String:
		return _label

	func is_enabled() -> bool:
		return _enabled

	func is_visible() -> bool:
		return _visible

	func duplicate_immutable() -> ToggleSettingViewModel:
		return ToggleSettingViewModel.new(_id, _label, _enabled, _visible)

	func append_signature(parts: PackedStringArray) -> void:
		parts.append(SettingsScreenViewModel._signature_part(String(_id)))
		parts.append(SettingsScreenViewModel._signature_part(_label))
		parts.append("1" if _enabled else "0")
		parts.append("1" if _visible else "0")


class BindingSettingViewModel extends RefCounted:
	var _action_id: StringName
	var _label: String
	var _binding_text: String
	var _is_capturing: bool

	func _init(action_id_value: StringName, label_value: String, binding_text_value: String, is_capturing_value: bool = false) -> void:
		_action_id = action_id_value
		_label = label_value
		_binding_text = binding_text_value
		_is_capturing = is_capturing_value

	func get_action_id() -> StringName:
		return _action_id

	func get_label() -> String:
		return _label

	func get_binding_text() -> String:
		return _binding_text

	func is_capturing() -> bool:
		return _is_capturing

	func duplicate_immutable() -> BindingSettingViewModel:
		return BindingSettingViewModel.new(_action_id, _label, _binding_text, _is_capturing)

	func append_signature(parts: PackedStringArray) -> void:
		parts.append(SettingsScreenViewModel._signature_part(String(_action_id)))
		parts.append(SettingsScreenViewModel._signature_part(_label))
		parts.append(SettingsScreenViewModel._signature_part(_binding_text))
		parts.append("1" if _is_capturing else "0")


var _revision: int
var _content_hash: int
var _show_quit: bool
var _status_text: String
var _audio_settings: Array[AudioSettingViewModel]
var _option_settings: Array[OptionSettingViewModel]
var _toggle_settings: Array[ToggleSettingViewModel]
var _binding_settings: Array[BindingSettingViewModel]


func _init(
	revision_value: int = 0,
	audio_settings_value: Array[AudioSettingViewModel] = [],
	option_settings_value: Array[OptionSettingViewModel] = [],
	toggle_settings_value: Array[ToggleSettingViewModel] = [],
	binding_settings_value: Array[BindingSettingViewModel] = [],
	status_text_value: String = "",
	show_quit_value: bool = false
) -> void:
	_revision = maxi(revision_value, 0)
	_show_quit = show_quit_value
	_status_text = status_text_value
	_audio_settings = _copy_audio(audio_settings_value)
	_option_settings = _copy_options(option_settings_value)
	_toggle_settings = _copy_toggles(toggle_settings_value)
	_binding_settings = _copy_bindings(binding_settings_value)
	_content_hash = _calculate_content_hash()


func get_revision() -> int:
	return _revision


func get_content_hash() -> int:
	return _content_hash


func should_show_quit() -> bool:
	return _show_quit


func get_status_text() -> String:
	return _status_text


func get_audio_settings() -> Array[AudioSettingViewModel]:
	return _copy_audio(_audio_settings)


func get_option_settings() -> Array[OptionSettingViewModel]:
	return _copy_options(_option_settings)


func get_toggle_settings() -> Array[ToggleSettingViewModel]:
	return _copy_toggles(_toggle_settings)


func get_binding_settings() -> Array[BindingSettingViewModel]:
	return _copy_bindings(_binding_settings)


func duplicate_immutable() -> SettingsScreenViewModel:
	return SettingsScreenViewModel.new(
		_revision,
		_audio_settings,
		_option_settings,
		_toggle_settings,
		_binding_settings,
		_status_text,
		_show_quit
	)


func _copy_audio(source: Array[AudioSettingViewModel]) -> Array[AudioSettingViewModel]:
	var result: Array[AudioSettingViewModel] = []
	for entry in source:
		if entry != null:
			result.append(entry.duplicate_immutable())
	return result


func _copy_options(source: Array[OptionSettingViewModel]) -> Array[OptionSettingViewModel]:
	var result: Array[OptionSettingViewModel] = []
	for entry in source:
		if entry != null:
			result.append(entry.duplicate_immutable())
	return result


func _copy_toggles(source: Array[ToggleSettingViewModel]) -> Array[ToggleSettingViewModel]:
	var result: Array[ToggleSettingViewModel] = []
	for entry in source:
		if entry != null:
			result.append(entry.duplicate_immutable())
	return result


func _copy_bindings(source: Array[BindingSettingViewModel]) -> Array[BindingSettingViewModel]:
	var result: Array[BindingSettingViewModel] = []
	for entry in source:
		if entry != null:
			result.append(entry.duplicate_immutable())
	return result


func _calculate_content_hash() -> int:
	var parts := PackedStringArray([
		"1" if _show_quit else "0",
		_signature_part(_status_text),
		str(_audio_settings.size()),
	])
	for entry in _audio_settings:
		entry.append_signature(parts)
	parts.append(str(_option_settings.size()))
	for entry in _option_settings:
		entry.append_signature(parts)
	parts.append(str(_toggle_settings.size()))
	for entry in _toggle_settings:
		entry.append_signature(parts)
	parts.append(str(_binding_settings.size()))
	for entry in _binding_settings:
		entry.append_signature(parts)
	return hash("|".join(parts))


static func _signature_part(value: String) -> String:
	return "%d:%s" % [value.length(), value]
