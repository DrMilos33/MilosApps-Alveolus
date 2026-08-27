class_name CaseArchiveViewModel
extends RefCounted

## Immutable presentation data for CaseArchiveScreen.
##
## The presenter/facade is responsible for translating domain records into
## these primitives. Neither this model nor its consumer needs access to the
## content catalog, save state or progression services.


class CaseEntryViewModel extends RefCounted:
	var _id: StringName
	var _order: int
	var _title: String
	var _status_text: String
	var _facts_text: String
	var _best_text: String
	var _record_text: String
	var _is_tutorial: bool
	var _is_unlocked: bool
	var _accent: Color
	var _is_completed: bool

	func _init(
		id_value: StringName,
		order_value: int,
		title_value: String,
		status_text_value: String,
		facts_text_value: String,
		best_text_value: String,
		record_text_value: String,
		is_tutorial_value: bool,
		is_unlocked_value: bool,
		accent_value: Color,
		is_completed_value: bool = false
	) -> void:
		_id = id_value
		_order = order_value
		_title = title_value
		_status_text = status_text_value
		_facts_text = facts_text_value
		_best_text = best_text_value
		_record_text = record_text_value
		_is_tutorial = is_tutorial_value
		_is_unlocked = is_unlocked_value
		_accent = accent_value
		_is_completed = is_completed_value

	func get_id() -> StringName:
		return _id

	func get_order() -> int:
		return _order

	func get_title() -> String:
		return _title

	func get_status_text() -> String:
		return _status_text

	func get_facts_text() -> String:
		return _facts_text

	func get_best_text() -> String:
		return _best_text

	func get_record_text() -> String:
		return _record_text

	func is_tutorial() -> bool:
		return _is_tutorial

	func is_unlocked() -> bool:
		return _is_unlocked

	func get_accent() -> Color:
		return _accent


	func is_completed() -> bool:
		return _is_completed

	func duplicate_immutable() -> CaseEntryViewModel:
		return CaseEntryViewModel.new(
			_id,
			_order,
			_title,
			_status_text,
			_facts_text,
			_best_text,
			_record_text,
			_is_tutorial,
			_is_unlocked,
			_accent,
			_is_completed
		)

	func append_content_signature(parts: PackedStringArray) -> void:
		parts.append(_signature_part(String(_id)))
		parts.append(str(_order))
		parts.append(_signature_part(_title))
		parts.append(_signature_part(_status_text))
		parts.append(_signature_part(_facts_text))
		parts.append(_signature_part(_best_text))
		parts.append(_signature_part(_record_text))
		parts.append("1" if _is_tutorial else "0")
		parts.append("1" if _is_unlocked else "0")
		parts.append(_accent.to_html(true))
		parts.append("1" if _is_completed else "0")

	func _signature_part(value: String) -> String:
		return "%d:%s" % [value.length(), value]


var _revision: int
var _content_hash: int
var _selected_case_id: StringName
var _entries: Array[CaseEntryViewModel] = []


func _init(
	revision_value: int = 0,
	entries_value: Array[CaseEntryViewModel] = [],
	selected_case_id_value: StringName = &""
) -> void:
	_revision = maxi(revision_value, 0)
	_selected_case_id = selected_case_id_value
	_entries = _deep_copy_entries(entries_value)
	_content_hash = _calculate_content_hash()


func get_revision() -> int:
	return _revision


func get_content_hash() -> int:
	return _content_hash


func get_selected_case_id() -> StringName:
	return _selected_case_id


func get_entries() -> Array[CaseEntryViewModel]:
	return _deep_copy_entries(_entries)


func get_entry(case_id: StringName) -> CaseEntryViewModel:
	for entry in _entries:
		if entry.get_id() == case_id:
			return entry.duplicate_immutable()
	return null


## The first unlocked, unfinished campaign entry is the visual destination of
## the journey. Presentation order is authoritative; localized status text is
## deliberately not parsed for progression state.
func get_next_case_id() -> StringName:
	var next_entry: CaseEntryViewModel
	for entry in _entries:
		if entry == null or entry.is_tutorial() or not entry.is_unlocked() or entry.is_completed():
			continue
		if next_entry == null or entry.get_order() < next_entry.get_order():
			next_entry = entry
	return next_entry.get_id() if next_entry != null else &""


func duplicate_immutable() -> CaseArchiveViewModel:
	return CaseArchiveViewModel.new(_revision, _entries, _selected_case_id)


func _deep_copy_entries(source: Array[CaseEntryViewModel]) -> Array[CaseEntryViewModel]:
	var result: Array[CaseEntryViewModel] = []
	for entry in source:
		if entry != null:
			result.append(entry.duplicate_immutable())
	return result


func _calculate_content_hash() -> int:
	var parts := PackedStringArray([
		"%d:%s" % [String(_selected_case_id).length(), String(_selected_case_id)],
		str(_entries.size()),
	])
	for entry in _entries:
		entry.append_content_signature(parts)
	return hash("|".join(parts))
