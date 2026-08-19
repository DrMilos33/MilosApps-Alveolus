class_name UpgradeOverlayViewModel
extends RefCounted

## Immutable primitive presentation data for UpgradeOverlay.
##
## No upgrade definition, player-stat object or catalog reference crosses this
## boundary. At most three copied rows become immutable child view models.

class ValueRowViewModel:
	extends RefCounted

	var _id: StringName
	var _label: String
	var _value: String
	var _before_value: String
	var _accent_role: StringName

	func _init(
		row_id: StringName,
		label_value: String,
		value_text: String,
		before_text: String = "",
		accent_value: StringName = &"gold"
	) -> void:
		_id = row_id
		_label = label_value
		_value = value_text
		_before_value = before_text
		_accent_role = accent_value

	func id() -> StringName:
		return _id

	func label() -> String:
		return _label

	func value() -> String:
		return _value

	func before_value() -> String:
		return _before_value

	func accent_role() -> StringName:
		return _accent_role


class UpgradeOptionViewModel:
	extends RefCounted

	var _id: StringName
	var _title: String
	var _effect: String
	var _before_value: String
	var _after_value: String
	var _icon_id: StringName
	var _accent_role: StringName
	var _value_rows: Array[ValueRowViewModel]
	var _pick_count: int
	var _maximum_picks: int
	var _compact_title: bool

	func _init(
		option_id: StringName,
		title_value: String,
		effect_value: String,
		before_value: String,
		after_value: String,
		icon_value: StringName,
		accent_value: StringName,
		value_rows_value: Array[ValueRowViewModel] = [],
		pick_count_value: int = 0,
		maximum_picks_value: int = 1,
		compact_title_value: bool = false
	) -> void:
		_id = option_id
		_title = title_value
		_effect = effect_value
		_before_value = before_value
		_after_value = after_value
		_icon_id = icon_value
		_accent_role = accent_value
		_value_rows.assign(value_rows_value)
		_pick_count = maxi(0, pick_count_value)
		_maximum_picks = maxi(1, maximum_picks_value)
		_compact_title = compact_title_value

	func id() -> StringName:
		return _id

	func title() -> String:
		return _title

	func effect() -> String:
		return _effect

	func before_value() -> String:
		return _before_value

	func after_value() -> String:
		return _after_value

	func comparison_text() -> String:
		if _before_value.is_empty():
			return _after_value
		if _after_value.is_empty():
			return _before_value
		return "%s → %s" % [_before_value, _after_value]

	func icon_id() -> StringName:
		return _icon_id

	func accent_role() -> StringName:
		return _accent_role

	func value_rows() -> Array[ValueRowViewModel]:
		var result: Array[ValueRowViewModel] = []
		result.assign(_value_rows)
		return result

	func has_value_rows() -> bool:
		return not _value_rows.is_empty()

	func pick_count() -> int:
		return _pick_count

	func maximum_picks() -> int:
		return _maximum_picks

	func pick_index_text() -> String:
		return "%d/%d" % [_pick_count, _maximum_picks]

	func compact_title() -> bool:
		return _compact_title


var _options: Array[UpgradeOptionViewModel] = []
var _scripted_intro := false
var _education_text := ""
var _can_reroll := false
var _allow_cancel := false
var _revision := 0
var _content_hash := ""


## Accepted row keys: id, title, effect, before, after, icon_id, accent_role,
## value_rows, pick_count, maximum_picks and compact_title. Each value row is
## already display-ready and accepts id, label, value, optional before and
## accent_role. The UI never derives units or maps content IDs. Invalid or
## duplicate IDs are discarded and the visible contract is capped at three
## choices.
static func create(
	option_rows: Array,
	revision_value: int = 0,
	scripted_intro_value: bool = false,
	education_text_value: String = "",
	can_reroll_value: bool = false,
	allow_cancel_value: bool = false
) -> UpgradeOverlayViewModel:
	var result := UpgradeOverlayViewModel.new()
	result._revision = maxi(0, revision_value)
	result._scripted_intro = scripted_intro_value
	result._education_text = education_text_value.strip_edges()
	result._can_reroll = can_reroll_value
	result._allow_cancel = allow_cancel_value
	var copied_rows: Array = option_rows.duplicate(true)
	var seen_ids: Dictionary = {}
	for index in range(copied_rows.size()):
		if result._options.size() >= 3:
			break
		var row_value: Variant = copied_rows[index]
		if not row_value is Dictionary:
			continue
		var row := row_value as Dictionary
		var option_id := StringName(String(row.get("id", "")))
		var title_value := String(row.get("title", "")).strip_edges()
		var effect_value := String(row.get("effect", "")).strip_edges()
		if option_id == &"" or title_value.is_empty() or effect_value.is_empty() or seen_ids.has(option_id):
			continue
		seen_ids[option_id] = true
		var icon_value := StringName(String(row.get("icon_id", "ability")))
		if icon_value == &"":
			icon_value = &"ability"
		var accent_value := StringName(String(row.get("accent_role", "turquoise")))
		if accent_value == &"":
			accent_value = &"turquoise"
		var value_rows := _copy_value_rows(row.get("value_rows", []), accent_value)
		result._options.append(UpgradeOptionViewModel.new(
			option_id,
			title_value,
			effect_value,
			String(row.get("before", "")).strip_edges(),
			String(row.get("after", "")).strip_edges(),
			icon_value,
			accent_value,
			value_rows,
			int(row.get("pick_count", 0)),
			int(row.get("maximum_picks", 1)),
			bool(row.get("compact_title", false))
		))
	result._content_hash = result._calculate_content_hash()
	return result


func revision() -> int:
	return _revision


func content_hash() -> String:
	return _content_hash


func option_count() -> int:
	return _options.size()


func is_valid() -> bool:
	return not _options.is_empty()


func option_at(index_value: int) -> UpgradeOptionViewModel:
	if index_value < 0 or index_value >= _options.size():
		return null
	return _options[index_value]


func options() -> Array[UpgradeOptionViewModel]:
	var result: Array[UpgradeOptionViewModel] = []
	result.assign(_options)
	return result


func scripted_intro() -> bool:
	return _scripted_intro


func education_text() -> String:
	return _education_text


func shows_education() -> bool:
	return _scripted_intro and not _education_text.is_empty()


func can_reroll() -> bool:
	return _can_reroll


func allow_cancel() -> bool:
	return _allow_cancel


static func _copy_value_rows(source_value: Variant, fallback_accent: StringName) -> Array[ValueRowViewModel]:
	var result: Array[ValueRowViewModel] = []
	if not source_value is Array:
		return result
	var copied_rows: Array = (source_value as Array).duplicate(true)
	var seen_ids: Dictionary = {}
	for row_value in copied_rows:
		if result.size() >= 3:
			break
		if not row_value is Dictionary:
			continue
		var row := row_value as Dictionary
		var row_id := StringName(String(row.get("id", "")))
		var label_value := String(row.get("label", "")).strip_edges()
		var value_text := String(row.get("value", "")).strip_edges()
		if row_id == &"" or label_value.is_empty() or value_text.is_empty() or seen_ids.has(row_id):
			continue
		seen_ids[row_id] = true
		var accent_value := StringName(String(row.get("accent_role", fallback_accent)))
		if accent_value == &"":
			accent_value = fallback_accent
		result.append(ValueRowViewModel.new(
			row_id,
			label_value,
			value_text,
			String(row.get("before", "")).strip_edges(),
			accent_value
		))
	return result


func _calculate_content_hash() -> String:
	var canonical := PackedStringArray([
		"1" if _scripted_intro else "0",
		_length_prefixed(_education_text),
		"1" if _can_reroll else "0",
		"1" if _allow_cancel else "0",
	])
	for option in _options:
		canonical.append(_length_prefixed(String(option.id())))
		canonical.append(_length_prefixed(option.title()))
		canonical.append(_length_prefixed(option.effect()))
		canonical.append(_length_prefixed(option.before_value()))
		canonical.append(_length_prefixed(option.after_value()))
		canonical.append(_length_prefixed(String(option.icon_id())))
		canonical.append(_length_prefixed(String(option.accent_role())))
		canonical.append(str(option.pick_count()))
		canonical.append(str(option.maximum_picks()))
		canonical.append("1" if option.compact_title() else "0")
		canonical.append(str(option.value_rows().size()))
		for row in option.value_rows():
			canonical.append(_length_prefixed(String(row.id())))
			canonical.append(_length_prefixed(row.label()))
			canonical.append(_length_prefixed(row.value()))
			canonical.append(_length_prefixed(row.before_value()))
			canonical.append(_length_prefixed(String(row.accent_role())))
	return "|".join(canonical).sha256_text()


func _length_prefixed(value: String) -> String:
	return "%d:%s" % [value.length(), value]
