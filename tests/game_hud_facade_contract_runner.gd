extends SceneTree

## Additive compatibility snapshot for the GameHUD facade at checkpoint
## 8fc0d8c. New facade members are allowed during extraction, but every member
## listed here must retain its name, ordered parameters, defaults, and return
## type until the last compatibility caller has migrated.

const GAME_HUD_PATH := "res://scripts/ui/game_hud.gd"
const CONTRACT_METHOD_PREFIXES := [
	"show_",
	"refresh_",
	"update_",
	"set_",
	"configure_",
	"hide_",
	"clear_",
	"cancel_",
	"return_",
	"is_",
]

const BASELINE_SIGNALS := {
	"navigate_requested": "destination:StringName",
	"back_requested": "",
	"quit_requested": "",
	"story_finished": "",
	"level_selected": "id:StringName",
	"upgrade_chosen": "definition:UpgradeDefinition",
	"reroll_requested": "",
	"resume_requested": "",
	"abort_requested": "",
	"abort_confirmed": "",
	"abort_cancelled": "",
	"retry_requested": "",
	"result_levels_requested": "",
	"result_campus_requested": "",
	"offline_claim_requested": "",
	"clinic_job_start_requested": "id:StringName",
	"clinic_job_claim_requested": "",
	"research_purchase_requested": "id:StringName",
	"discovery_dismissed": "",
	"intro_skip_requested": "",
	"intro_skip_confirmed": "",
	"intro_skip_cancelled": "",
	"restart_confirmed": "",
	"restart_cancelled": "",
	"run_stats_visibility_changed": "enabled:bool",
	"ui_settings_changed": "settings:UISettingsState",
	"settings_reset_bindings_requested": "",
	"preparation_start_requested": "loadout_snapshot:Dictionary",
	"preparation_component_requested": "id:StringName",
	"preparation_slot_component_requested": "slot_id:StringName,id:StringName",
	"preparation_slot_clear_requested": "slot_index:int",
	"preparation_slot_requested": "slot_id:StringName",
	"preparation_reserve_requested": "id:StringName",
	"preparation_replacement_cancelled": "",
	"ability_slot_requested": "slot:int",
	"research_tab_changed": "tab:StringName",
	"talent_toggle_requested": "id:StringName",
	"talent_reset_requested": "",
	"finding_reaction_selected": "id:StringName",
	"finding_reserve_swap_requested": "incoming_id:StringName,outgoing_id:StringName",
	"finding_confirmed": "reaction_id:StringName,incoming_id:StringName,outgoing_id:StringName",
}

const BASELINE_METHODS := {
	"show_campus": "meta:MetaProgressionState,jobs:Dictionary->void",
	"refresh_campus": "meta:MetaProgressionState,jobs:Dictionary->void",
	"show_practice": "meta:MetaProgressionState,jobs:Dictionary->void",
	"refresh_practice": "meta:MetaProgressionState,jobs:Dictionary->void",
	"show_research": "meta:MetaProgressionState,definitions:Array[ResearchDefinition]->void",
	"show_research_tabs": "meta:MetaProgressionState,definitions:Array[ResearchDefinition],talent_view:Variant->void",
	"refresh_research": "meta:MetaProgressionState,definitions:Array[ResearchDefinition]->void",
	"refresh_talents": "talent_view:Variant->void",
	"show_level_select": "meta:MetaProgressionState,levels:Array[LevelDefinition]->void",
	"show_lexicon": "meta:MetaProgressionState->void",
	"cancel_lexicon_step": "->bool",
	"show_story": "->void",
	"configure_input_glyphs": "service:InputGlyphService->void",
	"configure_ui_settings": "settings:UISettingsState->void",
	"show_settings": "show_quit:bool=true,campus_context:bool=true->void",
	"show_preparation": "view_model:Variant,catalog:Array=[],loadout:Variant=null->void",
	"refresh_preparation": "view_model:Variant,catalog:Array=[],loadout:Variant=null->void",
	"show_running_hud": "->void",
	"set_run_stats_visibility": "enabled:bool->void",
	"update_run_stats": "player_stats:PlayerStats,run_state:RunState=null->void",
	"update_stability": "current:float,maximum:float->void",
	"update_shield": "current:float,maximum:float->void",
	"show_patient_hit": "->void",
	"update_analysis": "current:int,target:int,level:int->void",
	"configure_active_abilities": "abilities:Array->void",
	"clear_active_abilities": "->void",
	"update_active_ability": "slot_index:int,title:String,remaining:float,total:float,ready:bool->void",
	"set_ability_targeting": "slot_index:int,targeting:bool->void",
	"update_finding_progress": "current:int,target:int,revealed:bool=false->void",
	"hide_finding_progress": "->void",
	"update_timer": "elapsed:float,boss_spawn_seconds:float,deadline_seconds:float,boss_active:bool->void",
	"update_intro_timer": "lesson:int,phase:StringName,boss_active:bool->void",
	"show_boss": "maximum:float,phase_count:int->void",
	"update_boss_health": "current:float,maximum:float->void",
	"show_boss_phase": "phase:int->void",
	"show_alert": "text:String,color:Color=COLOR_TEAL,duration:float=2.8->void",
	"show_upgrade_choices": "options:Array[UpgradeDefinition],stats:PlayerStats,can_reroll:bool,show_education:bool=false,scripted_intro:bool=false->void",
	"show_pause": "is_intro:bool=false,player_stats:PlayerStats=null,run_state:RunState=null->void",
	"hide_pause": "->void",
	"is_pause_stats_open": "->bool",
	"return_to_pause_menu": "->void",
	"show_abort_confirmation": "->void",
	"show_intro_skip_confirmation": "->void",
	"show_restart_confirmation": "->void",
	"hide_restart_confirmation": "->void",
	"hide_intro_skip_confirmation": "->void",
	"show_finding": "definition:Variant,reactions:Array,reserve:Variant=null,swappable_passives:Array=[]->void",
	"hide_finding": "->void",
	"set_finding_swap_validation": "valid:bool,message:String=\"\"->void",
	"show_end_mastery": "new_objectives:Array,earned_points:int,total_points:int->void",
	"show_discovery": "definition:DiscoveryDefinition,gameplay_target:Variant,gameplay_override:String=\"\"->void",
	"hide_discovery": "->void",
	"set_intro_upgrade_target": "target:Variant->void",
	"show_end": "level:LevelDefinition,success:bool,reason:String,elapsed:float,analysis_level:int,defeats:int,reward:int,unlocked_new:bool->void",
	"show_preparation_replacement": "component_id:StringName,compatible_slots:Array[StringName],capacity_before:int,capacity_after_by_slot:Dictionary={}->void",
	"show_preparation_error": "message:String->void",
	"cancel_preparation_step": "->bool",
}

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var file := FileAccess.open(GAME_HUD_PATH, FileAccess.READ)
	_check(file != null, "GameHUD source can be opened")
	if file == null:
		_finish(0, 0)
		return
	var source := file.get_as_text()
	_check(BASELINE_SIGNALS.size() == 41, "Checkpoint snapshot contains all 41 baseline signals")
	_check(BASELINE_METHODS.size() == 57, "Checkpoint snapshot contains all 57 facade methods")
	_check(source.contains("class_name GameHUD"), "Facade keeps the GameHUD class identity")

	var contract := _extract_contract(source)
	var actual_signals: Dictionary = contract["signals"]
	var actual_methods: Dictionary = contract["methods"]
	for name in BASELINE_SIGNALS:
		var expected := String(BASELINE_SIGNALS[name])
		var actual := String(actual_signals.get(name, "<missing>"))
		_check(
			actual == expected,
			"GameHUD signal %s keeps '%s'; actual '%s'" % [name, expected, actual]
		)
	for name in BASELINE_METHODS:
		var expected := String(BASELINE_METHODS[name])
		var actual := String(actual_methods.get(name, "<missing>"))
		_check(
			actual == expected,
			"GameHUD method %s keeps '%s'; actual '%s'" % [name, expected, actual]
		)
	_check(
		actual_methods.get("set_boss_direction_indicator", "<missing>") == "visible:bool,direction:Vector2->void",
		"GameHUD exposes the additive process-free boss direction indicator contract"
	)

	_finish(
		maxi(0, actual_signals.size() - BASELINE_SIGNALS.size()),
		maxi(0, actual_methods.size() - BASELINE_METHODS.size())
	)


func _extract_contract(source: String) -> Dictionary:
	var signals := {}
	var signal_pattern := RegEx.new()
	var signal_error := signal_pattern.compile(
		"(?m)^signal[ \\t]+([A-Za-z_][A-Za-z0-9_]*)(?:[ \\t]*\\(([^)]*)\\))?"
	)
	_check(signal_error == OK, "Signal declaration parser compiles")
	if signal_error == OK:
		for match in signal_pattern.search_all(source):
			signals[match.get_string(1)] = _compact(match.get_string(2))

	var methods := {}
	var method_pattern := RegEx.new()
	var method_error := method_pattern.compile(
		"(?m)^func[ \\t]+([A-Za-z_][A-Za-z0-9_]*)[ \\t]*\\(([^)]*)\\)"
		+ "[ \\t\\r\\n]*(?:->[ \\t]*([^:\\r\\n]+))?[ \\t]*:"
	)
	_check(method_error == OK, "Method declaration parser compiles")
	if method_error == OK:
		for match in method_pattern.search_all(source):
			var name := match.get_string(1)
			if not _is_contract_method(name):
				continue
			methods[name] = "%s->%s" % [
				_compact(match.get_string(2)),
				_compact(match.get_string(3)),
			]
	return {"signals": signals, "methods": methods}


func _is_contract_method(name: String) -> bool:
	if name.begins_with("_"):
		return false
	for prefix in CONTRACT_METHOD_PREFIXES:
		if name.begins_with(String(prefix)):
			return true
	return false


func _compact(value: String) -> String:
	return value.replace(" ", "").replace("\t", "").replace("\r", "").replace("\n", "")


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish(additive_signal_count: int, additive_method_count: int) -> void:
	if failures.is_empty():
		print(
			"ALVEOLUS_GAME_HUD_FACADE_CONTRACT_OK assertions=%d additive_signals=%d additive_methods=%d"
			% [assertions, additive_signal_count, additive_method_count]
		)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
