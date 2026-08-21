class_name PauseOverlayViewModel
extends RefCounted

## Immutable presentation data for PauseOverlay.
##
## The factory consumes getter-only stat-section DTOs produced by the presenter,
## copies their primitive rows at the boundary and never retains a
## domain or mutable source object. A small legacy-row adapter keeps the public
## GameHUD facade safe during the staged handoff to stat_sections().

class StatValueViewModel:
	extends RefCounted

	var _id: StringName
	var _section_id: StringName
	var _label: String
	var _formatted_value: String
	var _icon_id: StringName
	var _accent_role: StringName
	var _detail_text: String

	func _init(
		row_id: StringName,
		section_id_value: StringName,
		label_value: String,
		formatted_value: String,
		icon_value: StringName,
		accent_value: StringName,
		detail_text_value: String = ""
	) -> void:
		_id = row_id
		_section_id = section_id_value
		_label = label_value
		_formatted_value = formatted_value
		_icon_id = icon_value
		_accent_role = accent_value
		_detail_text = detail_text_value.strip_edges()

	func id() -> StringName:
		return _id

	func section_id() -> StringName:
		return _section_id

	## Compatibility alias for older read-only PauseOverlay consumers.
	func group() -> StringName:
		return _section_id

	func label() -> String:
		return _label

	func formatted_value() -> String:
		return _formatted_value

	func icon_id() -> StringName:
		return _icon_id

	func accent_role() -> StringName:
		return _accent_role

	func detail_text() -> String:
		return _detail_text


class SectionViewModel:
	extends RefCounted

	var _id: StringName
	var _title: String
	var _detail_title: String
	var _icon_id: StringName
	var _accent_role: StringName
	var _rows: Array[StatValueViewModel] = []

	func _init(
		section_id_value: StringName,
		title_value: String,
		detail_title_value: String,
		icon_value: StringName,
		accent_value: StringName,
		row_values: Array[StatValueViewModel]
	) -> void:
		_id = section_id_value
		_title = title_value
		_detail_title = detail_title_value
		_icon_id = icon_value
		_accent_role = accent_value
		_rows.assign(row_values)

	func id() -> StringName:
		return _id

	func title() -> String:
		return _title

	func detail_title() -> String:
		return _detail_title

	func display_title() -> String:
		return _title if _detail_title.is_empty() else "%s  ·  %s" % [_title, _detail_title]

	func icon_id() -> StringName:
		return _icon_id

	func accent_role() -> StringName:
		return _accent_role

	func row_count() -> int:
		return _rows.size()

	func row_at(index_value: int) -> StatValueViewModel:
		if index_value < 0 or index_value >= _rows.size():
			return null
		return _rows[index_value]

	func rows() -> Array[StatValueViewModel]:
		var result: Array[StatValueViewModel] = []
		result.assign(_rows)
		return result


var _sections: Array[SectionViewModel] = []
var _rows: Array[StatValueViewModel] = []
var _revision := 0
var _content_hash := ""
var _show_intro_skip := false


## Preferred input is the presenter's stat_sections(...): getter-only DTOs exposing
## id(), title() and rows(). Dictionary payloads with the same fields are also
## accepted by focused UI runners. Legacy flat rows are grouped only as a
## compatibility bridge and should not be produced by new callers.
static func create(stat_sections: Array, revision_value: int = 0, show_intro_skip_value: bool = false) -> PauseOverlayViewModel:
	var result := PauseOverlayViewModel.new()
	result._revision = maxi(0, revision_value)
	result._show_intro_skip = show_intro_skip_value
	var copied_sources: Array = stat_sections.duplicate(true)
	if _looks_like_legacy_rows(copied_sources):
		copied_sources = _legacy_sections(copied_sources)
	var seen_section_ids: Dictionary = {}
	for index in range(copied_sources.size()):
		var payload := _section_payload(copied_sources[index], index)
		var section_id := StringName(String(payload.get("id", "")).strip_edges())
		if section_id == &"" or seen_section_ids.has(section_id):
			continue
		var source_rows: Array = payload.get("rows", []) as Array
		var rows: Array[StatValueViewModel] = []
		var seen_row_ids: Dictionary = {}
		for row_index in range(source_rows.size()):
			var row_value: Variant = source_rows[row_index]
			if not row_value is Dictionary:
				continue
			var row := (row_value as Dictionary).duplicate(true)
			var label_value := String(row.get("label", "")).strip_edges()
			var formatted_value := String(row.get("value", "")).strip_edges()
			if label_value.is_empty() or formatted_value.is_empty():
				continue
			var row_id := StringName(String(row.get("id", "stat_%d" % (row_index + 1))).strip_edges())
			if row_id == &"" or seen_row_ids.has(row_id):
				continue
			var icon_value := StringName(String(row.get("icon_id", _row_icon(section_id, row_id))))
			if icon_value == &"":
				icon_value = _row_icon(section_id, row_id)
			var accent_value := StringName(String(row.get("accent_role", _row_accent(section_id, row_id))))
			if accent_value == &"":
				accent_value = _row_accent(section_id, row_id)
			rows.append(StatValueViewModel.new(
				row_id,
				section_id,
				label_value,
				formatted_value,
				icon_value,
				accent_value,
				String(row.get("detail_text", row.get("tooltip_text", "")))
			))
			seen_row_ids[row_id] = true
		if rows.is_empty():
			continue
		var source_title := String(payload.get("title", "")).strip_edges()
		var section_title := _section_title(section_id)
		var detail_title := source_title
		if detail_title.to_lower() in [section_title.to_lower(), "allgemein", "grundwerte"]:
			detail_title = ""
		var section := SectionViewModel.new(
			section_id,
			section_title,
			detail_title,
			_section_icon(section_id),
			_section_accent(section_id),
			rows
		)
		result._sections.append(section)
		result._rows.append_array(rows)
		seen_section_ids[section_id] = true
	result._content_hash = result._calculate_content_hash()
	return result


func revision() -> int:
	return _revision


func content_hash() -> String:
	return _content_hash


func section_count() -> int:
	return _sections.size()


func section_at(index_value: int) -> SectionViewModel:
	if index_value < 0 or index_value >= _sections.size():
		return null
	return _sections[index_value]


func section_by_id(section_id: StringName) -> SectionViewModel:
	for section in _sections:
		if section.id() == section_id:
			return section
	return null


func sections() -> Array[SectionViewModel]:
	var result: Array[SectionViewModel] = []
	result.assign(_sections)
	return result


func stat_count() -> int:
	return _rows.size()


func has_stats() -> bool:
	return not _sections.is_empty()


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
	for section in _sections:
		canonical.append(_length_prefixed(String(section.id())))
		canonical.append(_length_prefixed(section.title()))
		canonical.append(_length_prefixed(section.detail_title()))
		canonical.append(_length_prefixed(String(section.icon_id())))
		canonical.append(_length_prefixed(String(section.accent_role())))
		for row in section.rows():
			canonical.append(_length_prefixed(String(row.id())))
			canonical.append(_length_prefixed(row.label()))
			canonical.append(_length_prefixed(row.formatted_value()))
			canonical.append(_length_prefixed(String(row.icon_id())))
			canonical.append(_length_prefixed(String(row.accent_role())))
			canonical.append(_length_prefixed(row.detail_text()))
	return "|".join(canonical).sha256_text()


func _length_prefixed(value: String) -> String:
	return "%d:%s" % [value.length(), value]


static func _section_payload(source_value: Variant, index: int) -> Dictionary:
	if source_value is Dictionary:
		return (source_value as Dictionary).duplicate(true)
	if source_value is Object:
		var source := source_value as Object
		if source.has_method("id") and source.has_method("title") and source.has_method("rows"):
			var source_rows: Variant = source.call("rows")
			return {
				"id": source.call("id"),
				"title": source.call("title"),
				"rows": source_rows.duplicate(true) if source_rows is Array else [],
			}
	return {"id": StringName("section_%d" % (index + 1)), "title": "", "rows": []}


static func _looks_like_legacy_rows(values: Array) -> bool:
	if values.is_empty() or not values[0] is Dictionary:
		return false
	var first := values[0] as Dictionary
	return first.has("label") and first.has("value") and not first.has("rows")


static func _legacy_sections(rows: Array) -> Array:
	var order: Array[StringName] = []
	var grouped: Dictionary = {}
	for row_value in rows:
		if not row_value is Dictionary:
			continue
		var row := (row_value as Dictionary).duplicate(true)
		var legacy_group := String(row.get("group", "general")).strip_edges().to_lower()
		var section_id := _legacy_section_id(legacy_group)
		if not grouped.has(section_id):
			grouped[section_id] = []
			order.append(section_id)
		var section_rows := grouped[section_id] as Array
		section_rows.append(row)
	var result: Array = []
	for section_id in order:
		result.append({"id": section_id, "title": _section_title(section_id), "rows": grouped[section_id]})
	return result


static func _legacy_section_id(group_value: String) -> StringName:
	match group_value:
		"behandlung", "treatment":
			return &"treatment:legacy"
		"aktiv", "active":
			return &"ability:0:legacy"
	return &"general"


static func _section_title(section_id: StringName) -> String:
	var value := String(section_id)
	if value == "general":
		return "Grundwerte"
	if value.begins_with("treatment:"):
		return "Behandlung"
	if value.begins_with("ability:"):
		var parts := value.split(":")
		var slot := int(parts[1]) if parts.size() > 1 else 0
		return "Aktiv %d" % (slot + 1)
	return "Werte"


static func _section_icon(section_id: StringName) -> StringName:
	var value := String(section_id)
	if value.begins_with("treatment:"):
		return &"treatment"
	if value.begins_with("ability:"):
		var parts := value.split(":")
		if parts.size() > 2 and not parts[2].is_empty() and parts[2] != "legacy":
			var ability_id := String(parts[2])
			return StringName(ability_id if ability_id.begins_with("ability_") else "ability_%s" % ability_id)
		return &"ability"
	return &"stability_reserve"


static func _section_accent(section_id: StringName) -> StringName:
	var value := String(section_id)
	if value.begins_with("treatment:"):
		return &"teal"
	if value.begins_with("ability:0:"):
		return &"cobalt"
	if value.begins_with("ability:1:"):
		return &"turquoise"
	return &"gold"


static func _row_icon(section_id: StringName, row_id: StringName) -> StringName:
	var row := String(row_id)
	match row:
		"life":
			return &"stability_reserve"
		"shield", "defense":
			return &"defense_training"
		"movement_speed":
			return &"movement_training"
		"life_regeneration":
			return &"life_regeneration"
		"experience_gain":
			return &"experience_gain"
	if row.begins_with("resistance_"):
		return StringName("damage_%s" % row.trim_prefix("resistance_"))
	return _section_icon(section_id)


static func _row_accent(section_id: StringName, row_id: StringName) -> StringName:
	var row := String(row_id)
	if row.ends_with("_fire"):
		return &"coral"
	if row.ends_with("_water"):
		return &"cobalt"
	if row.ends_with("_earth"):
		return &"gold"
	if row.ends_with("_wind"):
		return &"turquoise"
	return _section_accent(section_id)
