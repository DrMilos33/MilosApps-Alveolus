class_name SettingsScreenViewModel
extends RefCounted

## Immutable presentation data for SettingsScreen.

## These values remain part of the immutable settings snapshot so existing
## saves and the compatibility facade can still round-trip them. The current
## settings surface deliberately does not offer controls for them.
const DORMANT_OPTION_IDS := {
	&"ui_scale": true,
	&"glyph_mode": true,
}


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
	var _binding_texts: Array[String]
	var _capturing_slot: int

	func _init(
		action_id_value: StringName,
		label_value: String,
		binding_text_value: Variant,
		capturing_slot_value: Variant = -1
	) -> void:
		_action_id = action_id_value
		_label = label_value
		_binding_texts = []
		if binding_text_value is Array:
			for entry in binding_text_value:
				if _binding_texts.size() >= 2:
					break
				_binding_texts.append(str(entry))
		else:
			# Compatibility for the former single-summary constructor. The new
			# screen extracts keyboard entries and deliberately omits the former
			# controller suffix from its visual presentation.
			var keyboard_summary := str(binding_text_value)
			if keyboard_summary.contains("|"):
				keyboard_summary = keyboard_summary.get_slice("|", 0).strip_edges()
			elif keyboard_summary.contains("·"):
				keyboard_summary = keyboard_summary.get_slice("·", 0).strip_edges()
			for entry in keyboard_summary.split("/", false, 2):
				if _binding_texts.size() >= 2:
					break
				_binding_texts.append(entry.strip_edges())
		while _binding_texts.size() < 2:
			_binding_texts.append("Nicht belegt")
		if capturing_slot_value is bool:
			_capturing_slot = 0 if bool(capturing_slot_value) else -1
		else:
			_capturing_slot = clampi(int(capturing_slot_value), -1, 1)

	func get_action_id() -> StringName:
		return _action_id

	func get_label() -> String:
		return _label

	func get_binding_text(slot_index: int = 0) -> String:
		if slot_index < 0 or slot_index >= _binding_texts.size():
			return "Nicht belegt"
		return _binding_texts[slot_index]

	func get_binding_texts() -> Array[String]:
		return _binding_texts.duplicate()

	func is_capturing() -> bool:
		return _capturing_slot >= 0

	func is_slot_capturing(slot_index: int) -> bool:
		return _capturing_slot == slot_index

	func get_capturing_slot() -> int:
		return _capturing_slot

	func duplicate_immutable() -> BindingSettingViewModel:
		return BindingSettingViewModel.new(_action_id, _label, _binding_texts, _capturing_slot)

	func append_signature(parts: PackedStringArray) -> void:
		parts.append(SettingsScreenViewModel._signature_part(String(_action_id)))
		parts.append(SettingsScreenViewModel._signature_part(_label))
		parts.append(str(_binding_texts.size()))
		for binding_text in _binding_texts:
			parts.append(SettingsScreenViewModel._signature_part(binding_text))
		parts.append(str(_capturing_slot))


class BindingConflictViewModel extends RefCounted:
	var _action_id: StringName
	var _slot_index: int
	var _action_label: String
	var _conflicting_action_id: StringName
	var _conflicting_action_label: String
	var _binding_text: String

	func _init(
		action_id_value: StringName,
		slot_index_value: int,
		action_label_value: String,
		conflicting_action_id_value: StringName,
		conflicting_action_label_value: String,
		binding_text_value: String
	) -> void:
		_action_id = action_id_value
		_slot_index = clampi(slot_index_value, 0, 1)
		_action_label = action_label_value
		_conflicting_action_id = conflicting_action_id_value
		_conflicting_action_label = conflicting_action_label_value
		_binding_text = binding_text_value

	func action_id() -> StringName:
		return _action_id

	func slot_index() -> int:
		return _slot_index

	func action_label() -> String:
		return _action_label

	func conflicting_action_id() -> StringName:
		return _conflicting_action_id

	func conflicting_action_label() -> String:
		return _conflicting_action_label

	func binding_text() -> String:
		return _binding_text

	func duplicate_immutable() -> BindingConflictViewModel:
		return BindingConflictViewModel.new(
			_action_id,
			_slot_index,
			_action_label,
			_conflicting_action_id,
			_conflicting_action_label,
			_binding_text
		)

	func append_signature(parts: PackedStringArray) -> void:
		parts.append(SettingsScreenViewModel._signature_part(String(_action_id)))
		parts.append(str(_slot_index))
		parts.append(SettingsScreenViewModel._signature_part(_action_label))
		parts.append(SettingsScreenViewModel._signature_part(String(_conflicting_action_id)))
		parts.append(SettingsScreenViewModel._signature_part(_conflicting_action_label))
		parts.append(SettingsScreenViewModel._signature_part(_binding_text))


var _revision: int
var _content_hash: int
var _show_quit: bool
var _status_text: String
var _audio_settings: Array[AudioSettingViewModel]
var _option_settings: Array[OptionSettingViewModel]
var _toggle_settings: Array[ToggleSettingViewModel]
var _binding_settings: Array[BindingSettingViewModel]
var _binding_conflict: BindingConflictViewModel


func _init(
	revision_value: int = 0,
	audio_settings_value: Array[AudioSettingViewModel] = [],
	option_settings_value: Array[OptionSettingViewModel] = [],
	toggle_settings_value: Array[ToggleSettingViewModel] = [],
	binding_settings_value: Array[BindingSettingViewModel] = [],
	status_text_value: String = "",
	show_quit_value: bool = false,
	binding_conflict_value: BindingConflictViewModel = null
) -> void:
	_revision = maxi(revision_value, 0)
	_show_quit = show_quit_value
	_status_text = status_text_value
	_audio_settings = _copy_audio(audio_settings_value)
	_option_settings = _copy_options(option_settings_value)
	_toggle_settings = _copy_toggles(toggle_settings_value)
	_binding_settings = _copy_bindings(binding_settings_value)
	_binding_conflict = binding_conflict_value.duplicate_immutable() if binding_conflict_value != null else null
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


func get_visible_option_settings() -> Array[OptionSettingViewModel]:
	var result: Array[OptionSettingViewModel] = []
	for entry in _option_settings:
		if entry.is_visible() and not DORMANT_OPTION_IDS.has(entry.get_id()):
			result.append(entry.duplicate_immutable())
	return result


func get_toggle_settings() -> Array[ToggleSettingViewModel]:
	return _copy_toggles(_toggle_settings)


func get_binding_settings() -> Array[BindingSettingViewModel]:
	return _copy_bindings(_binding_settings)


func get_binding_conflict() -> BindingConflictViewModel:
	return _binding_conflict.duplicate_immutable() if _binding_conflict != null else null


func duplicate_immutable() -> SettingsScreenViewModel:
	return SettingsScreenViewModel.new(
		_revision,
		_audio_settings,
		_option_settings,
		_toggle_settings,
		_binding_settings,
		_status_text,
		_show_quit,
		_binding_conflict
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
	parts.append("1" if _binding_conflict != null else "0")
	if _binding_conflict != null:
		_binding_conflict.append_signature(parts)
	return hash("|".join(parts))


static func _signature_part(value: String) -> String:
	return "%d:%s" % [value.length(), value]
