class_name MetaSaveRepository
extends RefCounted

const DEFAULT_PATH := "user://alveolus_save_v1.json"

var save_path: String

func _init(path: String = DEFAULT_PATH) -> void:
	save_path = path

func load_into(state: MetaProgressionState) -> bool:
	if not FileAccess.file_exists(save_path):
		state.reset_defaults()
		return true
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("ALVEOLUS: Spielstand konnte nicht geöffnet werden; Standardstand wird verwendet.")
		state.reset_defaults()
		return false
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	var parsed: Variant = parser.data
	if parse_error != OK or typeof(parsed) != TYPE_DICTIONARY or not state.load_dict(parsed):
		push_warning("ALVEOLUS: Spielstand ist beschädigt oder hat eine unbekannte Version; Standardstand wird verwendet.")
		state.reset_defaults()
		return false
	return true

func save(state: MetaProgressionState) -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("ALVEOLUS: Spielstand konnte nicht gespeichert werden.")
		return false
	file.store_string(JSON.stringify(state.to_dict(), "\t"))
	file.flush()
	return true
