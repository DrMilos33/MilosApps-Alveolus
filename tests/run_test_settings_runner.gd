extends SceneTree

const SETTINGS_PATH := "res://scripts/core/run_test_settings.gd"
const REPOSITORY_PATH := "res://scripts/core/run_test_settings_repository.gd"
const RunTestSettingsScript := preload(SETTINGS_PATH)
const RunTestSettingsRepositoryScript := preload(REPOSITORY_PATH)
const CONTRACT_PATH := "user://alveolus_test_tools_contract.cfg"

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_remove_contract_file()
	_test_defaults_and_ranges()
	_test_change_contract()
	_test_repository_roundtrip()
	_test_source_boundaries()
	_remove_contract_file()
	_finish()


func _test_defaults_and_ranges() -> void:
	var settings: RunTestSettings = RunTestSettingsScript.new()
	_check(not settings.damage_immunity_enabled(), "Schadensimmunität ist standardmäßig aus")
	_check(settings.outgoing_damage_bonus_percent() == 0, "Ausgehender Schaden startet bei +0 Prozent")
	_check(settings.movement_speed_percent() == 100, "Galopp startet bei 100 Prozent")
	_check(is_equal_approx(settings.outgoing_damage_multiplier(), 1.0), "+0 Prozent ergibt den neutralen Schadensmultiplikator")
	_check(is_equal_approx(settings.movement_speed_multiplier(), 1.0), "100 Prozent ergibt den neutralen Bewegungsmultiplikator")

	var normalized: RunTestSettings = RunTestSettingsScript.new(true, 307, 47)
	_check(normalized.damage_immunity_enabled(), "Konstruktor übernimmt Immunität")
	_check(normalized.outgoing_damage_bonus_percent() == 300, "Schaden wird bei 300 Prozent begrenzt")
	_check(normalized.movement_speed_percent() == 50, "Galopp wird bei 50 Prozent begrenzt")
	normalized.set_outgoing_damage_bonus_percent(24)
	normalized.set_movement_speed_percent(198)
	_check(normalized.outgoing_damage_bonus_percent() == 20, "Schaden rastet deterministisch in Zehnerschritten")
	_check(normalized.movement_speed_percent() == 200, "Galopp rastet deterministisch in Fünferschritten")
	_check(is_equal_approx(normalized.outgoing_damage_multiplier(), 1.2), "Schadensbonus besitzt einen Integrator-fertigen Faktor")
	_check(is_equal_approx(normalized.movement_speed_multiplier(), 2.0), "Galopp besitzt einen Integrator-fertigen Faktor")


func _test_change_contract() -> void:
	var settings: RunTestSettings = RunTestSettingsScript.new()
	var changed_count := [0]
	var reset_count := [0]
	var immunity_values: Array[bool] = []
	var damage_values: Array[int] = []
	var movement_values: Array[int] = []
	settings.changed.connect(func() -> void: changed_count[0] += 1)
	settings.defaults_restored.connect(func() -> void: reset_count[0] += 1)
	settings.damage_immunity_changed.connect(func(value: bool) -> void: immunity_values.append(value))
	settings.outgoing_damage_bonus_percent_changed.connect(func(value: int) -> void: damage_values.append(value))
	settings.movement_speed_percent_changed.connect(func(value: int) -> void: movement_values.append(value))
	_check(settings.set_damage_immunity(true), "Immunitätsänderung wird angenommen")
	_check(settings.set_outgoing_damage_bonus_percent(40), "Schadensänderung wird angenommen")
	_check(settings.set_movement_speed_percent(115), "Galoppänderung wird angenommen")
	_check(not settings.set_movement_speed_percent(116), "Ein Wert im gleichen Rasterfeld erzeugt keine Scheinänderung")
	_check(settings.reset_defaults(), "Reset stellt veränderte Werte wieder her")
	_check(changed_count[0] == 4 and reset_count[0] == 1, "Jede echte Änderung und genau ein Reset werden signalisiert")
	_check(immunity_values == [true, false], "Immunität signalisiert Änderung und Reset")
	_check(damage_values == [40, 0], "Schaden signalisiert Änderung und Reset")
	_check(movement_values == [115, 100], "Galopp signalisiert Änderung und Reset")
	_check(not settings.reset_defaults(), "Reset auf bereits aktive Defaults bleibt idempotent")


func _test_repository_roundtrip() -> void:
	var repository: RunTestSettingsRepository = RunTestSettingsRepositoryScript.new(CONTRACT_PATH)
	_check(repository.path() == CONTRACT_PATH, "Repository erlaubt einen isolierten Testpfad")
	var default_repository: RunTestSettingsRepository = RunTestSettingsRepositoryScript.new()
	_check(default_repository.path() == "user://alveolus_test_tools.cfg", "Produktionspfad ist die eigenständige Testtools-Datei")
	var missing: RunTestSettings = repository.load_settings()
	_check(not missing.damage_immunity_enabled() and missing.outgoing_damage_bonus_percent() == 0 and missing.movement_speed_percent() == 100, "Fehlende Datei lädt sichere Defaults")
	var changed: RunTestSettings = RunTestSettingsScript.new(true, 130, 145)
	_check(repository.save(changed), "Repository speichert Testwerte")

	# A new repository and a new state object model the next process start.
	var restarted_repository: RunTestSettingsRepository = RunTestSettingsRepositoryScript.new(CONTRACT_PATH)
	var restarted: RunTestSettings = restarted_repository.load_settings()
	_check(restarted != changed, "Neustart lädt ein unabhängiges Zustandsobjekt")
	_check(restarted.damage_immunity_enabled() and restarted.outgoing_damage_bonus_percent() == 130 and restarted.movement_speed_percent() == 145, "Alle Testwerte überleben den simulierten Neustart")
	var defaults := restarted_repository.reset_to_defaults()
	_check(not defaults.damage_immunity_enabled() and defaults.outgoing_damage_bonus_percent() == 0 and defaults.movement_speed_percent() == 100, "Repository-Reset liefert Defaults")
	var after_reset: RunTestSettings = RunTestSettingsRepositoryScript.new(CONTRACT_PATH).load_settings()
	_check(not after_reset.damage_immunity_enabled() and after_reset.outgoing_damage_bonus_percent() == 0 and after_reset.movement_speed_percent() == 100, "Repository-Reset bleibt über Neustart erhalten")


func _test_source_boundaries() -> void:
	var source := FileAccess.get_file_as_string(SETTINGS_PATH) + "\n" + FileAccess.get_file_as_string(REPOSITORY_PATH)
	for forbidden in ["UISettingsState", "MetaProgressionState", "save_game", "game.gd", "player_stats"]:
		_check(not source.contains(forbidden), "Testwerte bleiben frei von regulärer Save-/Gameplay-Abhängigkeit %s" % forbidden)
	_check(source.contains("user://alveolus_test_tools.cfg"), "Repository benennt den separaten Debug-Persistenzpfad ausdrücklich")


func _remove_contract_file() -> void:
	var absolute_path := ProjectSettings.globalize_path(CONTRACT_PATH)
	if FileAccess.file_exists(CONTRACT_PATH):
		DirAccess.remove_absolute(absolute_path)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("RUN_TEST_SETTINGS_OK assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("RUN_TEST_SETTINGS_FAILED assertions=%d failures=%d" % [assertions, failures.size()])
	quit(1)
