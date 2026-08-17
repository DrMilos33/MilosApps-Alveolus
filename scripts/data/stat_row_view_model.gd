class_name StatRowViewModel
extends RefCounted

enum ValueKind {
	NUMBER,
	INTEGER,
	TEXT,
	BOOLEAN,
}

var id: StringName
var label: String
var value: Variant
var unit: String
var value_kind: ValueKind = ValueKind.TEXT
var decimals: int = 0
var source_id: StringName
var source_field: StringName
var description: String

static func number(
	row_id: StringName,
	row_label: String,
	numeric_value: float,
	row_unit: String = "",
	digit_count: int = 0,
	value_source: StringName = &"",
	field_source: StringName = &"",
	row_description: String = ""
) -> StatRowViewModel:
	var row := StatRowViewModel.new()
	row.id = row_id
	row.label = row_label
	row.value = numeric_value
	row.unit = row_unit
	row.value_kind = ValueKind.NUMBER
	row.decimals = maxi(0, digit_count)
	row.source_id = value_source
	row.source_field = field_source
	row.description = row_description
	return row

static func integer(
	row_id: StringName,
	row_label: String,
	integer_value: int,
	row_unit: String = "",
	value_source: StringName = &"",
	field_source: StringName = &"",
	row_description: String = ""
) -> StatRowViewModel:
	var row := StatRowViewModel.new()
	row.id = row_id
	row.label = row_label
	row.value = integer_value
	row.unit = row_unit
	row.value_kind = ValueKind.INTEGER
	row.source_id = value_source
	row.source_field = field_source
	row.description = row_description
	return row

static func text(
	row_id: StringName,
	row_label: String,
	text_value: String,
	value_source: StringName = &"",
	field_source: StringName = &"",
	row_description: String = ""
) -> StatRowViewModel:
	var row := StatRowViewModel.new()
	row.id = row_id
	row.label = row_label
	row.value = text_value
	row.value_kind = ValueKind.TEXT
	row.source_id = value_source
	row.source_field = field_source
	row.description = row_description
	return row

static func boolean(
	row_id: StringName,
	row_label: String,
	boolean_value: bool,
	value_source: StringName = &"",
	field_source: StringName = &"",
	row_description: String = ""
) -> StatRowViewModel:
	var row := StatRowViewModel.new()
	row.id = row_id
	row.label = row_label
	row.value = boolean_value
	row.value_kind = ValueKind.BOOLEAN
	row.source_id = value_source
	row.source_field = field_source
	row.description = row_description
	return row

func formatted_value() -> String:
	var result := ""
	match value_kind:
		ValueKind.NUMBER:
			var numeric := float(value)
			if decimals <= 0 and is_equal_approx(numeric, roundf(numeric)):
				result = str(roundi(numeric))
			else:
				result = ("%.*f" % [decimals, numeric]).replace(".", ",")
		ValueKind.INTEGER:
			result = str(int(value))
		ValueKind.BOOLEAN:
			result = "Ja" if bool(value) else "Nein"
		_:
			result = str(value)
	if not unit.is_empty():
		result += " " + unit
	return result
