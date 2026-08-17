extends SceneTree

## Static dependency boundary for extracted screen modules. Screens receive
## immutable presentation data and emit intents; they must not reach back into
## core/domain state, content catalogs, or persistence.

const SCREEN_ROOT := "res://scripts/ui/screens"
const DOMAIN_ROOTS := [
	"res://scripts/core",
	"res://scripts/data",
]
const ALLOWED_PRESENTATION_TYPES := {
	"LexiconEntryViewModel": true,
	"StatRowViewModel": true,
}
const ALLOWED_DATA_SCRIPT_FILES := {
	"lexicon_entry_view_model.gd": true,
	"stat_row_view_model.gd": true,
}
const PERSISTENCE_APIS := {
	"FileAccess": true,
	"DirAccess": true,
	"ConfigFile": true,
	"ResourceSaver": true,
}
const REQUIRED_FORBIDDEN_TYPES := [
	"MetaProgressionState",
	"PlayerStats",
	"RunState",
	"RunSession",
	"GameFlowState",
	"ContentCatalog",
	"MetaSaveRepository",
]

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var forbidden_types := _discover_forbidden_types()
	for required_type in REQUIRED_FORBIDDEN_TYPES:
		_check(
			forbidden_types.has(required_type),
			"Dependency guard discovers required boundary type %s" % required_type
		)
	_test_detector(forbidden_types)

	var screen_paths := _gd_scripts_below(SCREEN_ROOT)
	for path in screen_paths:
		var file := FileAccess.open(path, FileAccess.READ)
		_check(file != null, "Screen source can be opened: %s" % path)
		if file == null:
			continue
		var violations := _find_violations(file.get_as_text(), forbidden_types)
		_check(
			violations.is_empty(),
			"Screen dependency boundary violated in %s:\n  %s" % [path, "\n  ".join(violations)]
		)
	_finish(screen_paths.size(), forbidden_types.size())


func _discover_forbidden_types() -> Dictionary:
	var result := {}
	var class_pattern := RegEx.new()
	var parse_error := class_pattern.compile(
		"(?m)^class_name[ \\t]+([A-Za-z_][A-Za-z0-9_]*)"
	)
	_check(parse_error == OK, "Domain class-name parser compiles")
	if parse_error != OK:
		return result
	for root in DOMAIN_ROOTS:
		for path in _gd_scripts_below(root):
			var file := FileAccess.open(path, FileAccess.READ)
			_check(file != null, "Boundary source can be opened: %s" % path)
			if file == null:
				continue
			var match := class_pattern.search(file.get_as_text())
			if match == null:
				continue
			var type_name := match.get_string(1)
			if not ALLOWED_PRESENTATION_TYPES.has(type_name):
				result[type_name] = path
	return result


func _test_detector(forbidden_types: Dictionary) -> void:
	var forbidden_sample := """extends Control
var stats: PlayerStats
var session: RunSession
const Catalog = preload(\"res://scripts/data/content_catalog.gd\")
const Repository = preload(\"../core/meta_save_repository.gd\")
func persist() -> void:
\tFileAccess.open(\"user://screen-owned-save.json\", FileAccess.WRITE)
"""
	var violations := _find_violations(forbidden_sample, forbidden_types)
	_check(_has_violation(violations, "domain-type:PlayerStats"), "Guard rejects domain state types")
	_check(_has_violation(violations, "domain-type:RunSession"), "Guard rejects direct RunSession access")
	_check(_has_violation(violations, "domain-script:content_catalog.gd"), "Guard rejects direct ContentCatalog scripts")
	_check(_has_violation(violations, "domain-script:meta_save_repository.gd"), "Guard rejects relative core script paths")
	_check(_has_violation(violations, "persistence-api:FileAccess"), "Guard rejects direct persistence APIs")
	_check(_has_violation(violations, "save-path:user://"), "Guard rejects direct save paths")

	var allowed_sample := """extends Control
# MetaProgressionState and ContentCatalog may be named in migration notes.
var explanation := \"PlayerStats is adapted before it reaches this screen.\"
var view_model: LexiconEntryViewModel
var accent: Color
"""
	_check(
		_find_violations(allowed_sample, forbidden_types).is_empty(),
		"Guard ignores comments, copy, primitives, colors, and approved view models"
	)


func _find_violations(source: String, forbidden_types: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	var lexical := _lex_source(source)
	var code := String(lexical["code"])
	var identifier_pattern := RegEx.new()
	var parse_error := identifier_pattern.compile("[A-Za-z_][A-Za-z0-9_]*")
	if parse_error != OK:
		var internal_error: Array[String] = ["internal:identifier-parser"]
		return internal_error
	for match in identifier_pattern.search_all(code):
		var identifier := match.get_string()
		var line := _line_at(source, match.get_start())
		if forbidden_types.has(identifier):
			violations.append("domain-type:%s line=%d" % [identifier, line])
		elif PERSISTENCE_APIS.has(identifier):
			violations.append("persistence-api:%s line=%d" % [identifier, line])

	var literal_entries: Array = lexical["strings"]
	for literal_data in literal_entries:
		var literal := String(literal_data["value"]).replace("\\", "/").to_lower()
		var line := int(literal_data["line"])
		if literal.contains("user://"):
			violations.append("save-path:user:// line=%d" % line)
		if _is_core_script_path(literal):
			violations.append("domain-script:%s line=%d" % [_path_file(literal), line])
		elif _is_forbidden_data_script_path(literal):
			violations.append("domain-script:%s line=%d" % [_path_file(literal), line])
	return violations


func _lex_source(source: String) -> Dictionary:
	var code := ""
	var strings: Array[Dictionary] = []
	var index := 0
	while index < source.length():
		var character := source[index]
		if character == "#":
			while index < source.length() and source[index] != "\n":
				code += " "
				index += 1
			continue
		if character != "\"" and character != "'":
			code += character
			index += 1
			continue

		var quote := character
		var start_index := index
		var triple := index + 2 < source.length() \
			and source[index + 1] == quote \
			and source[index + 2] == quote
		var delimiter_size := 3 if triple else 1
		for _delimiter_character in range(delimiter_size):
			code += " "
		index += delimiter_size
		var literal := ""
		while index < source.length():
			if triple and index + 2 < source.length() \
				and source[index] == quote \
				and source[index + 1] == quote \
				and source[index + 2] == quote:
				for _delimiter_character in range(3):
					code += " "
				index += 3
				break
			if not triple and source[index] == quote:
				code += " "
				index += 1
				break
			if source[index] == "\\" and index + 1 < source.length():
				literal += source[index]
				literal += source[index + 1]
				code += "  "
				index += 2
				continue
			literal += source[index]
			code += "\n" if source[index] == "\n" else " "
			index += 1
		strings.append({"value": literal, "line": _line_at(source, start_index)})
	return {"code": code, "strings": strings}


func _is_core_script_path(path: String) -> bool:
	return path.contains("scripts/core/") or path.contains("../core/")


func _is_forbidden_data_script_path(path: String) -> bool:
	if not path.contains("scripts/data/") and not path.contains("../data/"):
		return false
	return not ALLOWED_DATA_SCRIPT_FILES.has(_path_file(path))


func _path_file(path: String) -> String:
	return path.get_file().get_slice("?", 0).get_slice("#", 0)


func _line_at(source: String, offset: int) -> int:
	return source.left(maxi(0, offset)).count("\n") + 1


func _has_violation(violations: Array[String], prefix: String) -> bool:
	for violation in violations:
		if violation.begins_with(prefix):
			return true
	return false


func _gd_scripts_below(root_path: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		return result
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var path := root_path.path_join(entry)
			if directory.current_is_dir():
				result.append_array(_gd_scripts_below(path))
			elif entry.get_extension().to_lower() == "gd":
				result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
	result.sort()
	return result


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish(screen_count: int, forbidden_type_count: int) -> void:
	if failures.is_empty():
		print(
			"ALVEOLUS_UI_SCREEN_DEPENDENCY_GUARD_OK assertions=%d screens=%d forbidden_types=%d"
			% [assertions, screen_count, forbidden_type_count]
		)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
