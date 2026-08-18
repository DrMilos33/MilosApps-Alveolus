class_name StatSectionViewModel
extends RefCounted

var _section_id: StringName
var _title: String
var _rows: Array[Dictionary] = []


static func create(section_id: StringName, title: String, rows: Array[Dictionary]) -> StatSectionViewModel:
	var result := StatSectionViewModel.new()
	result._section_id = section_id
	result._title = title
	result._rows.assign(rows.duplicate(true))
	return result


func id() -> StringName:
	return _section_id


func title() -> String:
	return _title


func rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(_rows.duplicate(true))
	return result


func row_count() -> int:
	return _rows.size()


func row_at(index: int) -> Dictionary:
	return _rows[index].duplicate(true) if index >= 0 and index < _rows.size() else {}
