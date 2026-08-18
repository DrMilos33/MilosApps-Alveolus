class_name PauseOverlayViewModel
extends RefCounted

## Immutable presentation data for PauseOverlay.
##
## The factory accepts only primitive row dictionaries, deep-copies them at
## the boundary and exposes immutable child view models through defensive array
## copies. It deliberately has no dependency on run, save or catalog objects.

class StatValueViewModel:
	extends RefCounted

	var _id: StringName
	var _group: StringName
	var _label: String
	var _formatted_value: String
	var _icon_id: StringName
	var _accent_role: StringName

	func _init(
		row_id: StringName,
		group_value: StringName,
		label_value: String,
		formatted_value: String,
		icon_value: StringName,
		accent_value: StringName
	) -> void:
		_id = row_id
		_group = group_value
		_label = label_value
		_formatted_value = formatted_value
		_icon_id = icon_value
		_accent_role = accent_value

	func id() -> StringName:
		return _id

	func group() -> StringName:
		return _group

	func label() -> String:
		return _label

	func formatted_value() -> String:
		return _formatted_value

	func icon_id() -> StringName:
		return _icon_id

	func accent_role() -> StringName:
		return _accent_role


var _rows: Array[StatValueViewModel] = []
var _revision := 0
var _content_hash := ""
var _show_intro_skip := false


## Accepted keys: id, group, label, value, icon_id and accent_role. The latter
## two are optional presentation hints; stable fallbacks are derived from the
## display group without retaining the mutable source Dictionary.
static func create(stat_rows: Array, revision_value: int = 0, show_intro_skip_value: bool = false) -> PauseOverlayViewModel:
	var result := PauseOverlayViewModel.new()
	result._revision = maxi(0, revision_value)
	result._show_intro_skip = show_intro_skip_value
	var copied_rows: Array = stat_rows.duplicate(true)
	for index in range(copied_rows.size()):
		var row_value: Variant = copied_rows[index]
		if not row_value is Dictionary:
			continue
		var row := row_value as Dictionary
		var label_value := String(row.get("label", "")).strip_edges()
		var formatted_value := String(row.get("value", "")).strip_edges()
		if label_value.is_empty() or formatted_value.is_empty():
			continue
		var group_value := StringName(String(row.get("group", "general")).strip_edges().to_lower())
		if group_value == &"":
			group_value = &"general"
		var row_id := StringName(String(row.get("id", "stat_%d" % (index + 1))))
		if row_id == &"":
			row_id = StringName("stat_%d" % (index + 1))
		var icon_value := StringName(String(row.get("icon_id", _default_icon(group_value))))
		if icon_value == &"":
			icon_value = _default_icon(group_value)
		var accent_value := StringName(String(row.get("accent_role", _default_accent(group_value))))
		if accent_value == &"":
			accent_value = _default_accent(group_value)
		result._rows.append(StatValueViewModel.new(
			row_id,
			group_value,
			label_value,
			formatted_value,
			icon_value,
			accent_value
		))
	result._content_hash = result._calculate_content_hash()
	return result


func revision() -> int:
	return _revision


func content_hash() -> String:
	return _content_hash


func stat_count() -> int:
	return _rows.size()


func has_stats() -> bool:
	return not _rows.is_empty()


func show_intro_skip() -> bool:
	return _show_intro_skip


func stat_at(index_value: int) -> StatValueViewModel:
	if index_value < 0 or index_value >= _rows.size():
		return null
	return _rows[index_value]


func stats() -> Array[StatValueViewModel]:
	var result: Array[StatValueViewModel] = []
	result.assign(_rows)
	return result


func _calculate_content_hash() -> String:
	var canonical := PackedStringArray(["intro_skip:%s" % str(_show_intro_skip)])
	for row in _rows:
		canonical.append(_length_prefixed(String(row.id())))
		canonical.append(_length_prefixed(String(row.group())))
		canonical.append(_length_prefixed(row.label()))
		canonical.append(_length_prefixed(row.formatted_value()))
		canonical.append(_length_prefixed(String(row.icon_id())))
		canonical.append(_length_prefixed(String(row.accent_role())))
	return "|".join(canonical).sha256_text()


func _length_prefixed(value: String) -> String:
	return "%d:%s" % [value.length(), value]


static func _default_icon(group: StringName) -> StringName:
	match group:
		&"treatment", &"behandlung":
			return &"treatment"
		&"active", &"aktiv":
			return &"ability"
		&"defense", &"abwehr":
			return &"immune"
		&"support", &"regeneration":
			return &"support"
		&"samples", &"proben":
			return &"sample"
	return &"information"


static func _default_accent(group: StringName) -> StringName:
	match group:
		&"treatment", &"behandlung":
			return &"teal"
		&"active", &"aktiv", &"samples", &"proben":
			return &"cobalt"
		&"defense", &"abwehr":
			return &"coral"
		&"support", &"regeneration":
			return &"turquoise"
	return &"gold"
