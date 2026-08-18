extends SceneTree

var assertions := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_screen_and_modal_navigation()
	_test_context_detail_focus_contract()
	_test_late_default_focus_and_invalid_targets()
	_test_planning_starts_at_treatment()
	_test_atomic_fixed_slot_changes()
	_test_dormant_reserve_backend_compatibility()
	_test_v4_mapping_and_v5_roundtrip()
	if failures == 0:
		print("ALVEOLUS_UI_NAVIGATION_LOADOUT_OK assertions=%d" % assertions)
		quit(0)
	else:
		printerr("ALVEOLUS_UI_NAVIGATION_LOADOUT_FAILED failures=%d assertions=%d" % [failures, assertions])
		quit(1)


func _test_screen_and_modal_navigation() -> void:
	var router := UIScreenRouter.new()
	_true(router.reset(&"campus", &"campus_practice"), "Campus kann als Wurzel gesetzt werden")
	_equal(router.current_input_owner_id(), &"campus", "Die Wurzel besitzt zunächst die Eingabe")
	_equal(router.last_focus_request, &"campus_practice", "Die Wurzel fordert ihren Standardfokus an")
	_true(router.push_screen(&"level_select", &"case_intro", &"campus_cases"), "Fallauswahl wird auf den Screenstack gelegt")
	_true(router.push_screen(&"preparation", LoadoutSlotId.TREATMENT, &"case_one"), "Einsatzplanung wird direkt auf die Fallauswahl gelegt")
	_equal(router.screen_depth(), 3, "Der Screenstack bildet den tatsächlichen Weg ab")
	_true(router.open_modal(&"replace_component", &"replace_active_1", &"catalog_card"), "Austausch kann als Modalebene geöffnet werden")
	_equal(router.current_input_owner_id(), &"replace_component", "Nur das oberste Modal besitzt die Eingabe")
	_true(not router.push_screen(&"research"), "Ein Modal verhindert Navigation im Hintergrund")
	_true(router.open_modal(&"confirm_abort", &"cancel_abort", &"replace_active_2"), "Modale Ebenen können kontrolliert gestapelt werden")
	_true(router.back(&"confirm_abort"), "Zurück schließt nur das oberste Modal")
	_equal(router.current_modal_id(), &"replace_component", "Das darunterliegende Modal bleibt erhalten")
	_equal(router.last_focus_request, &"replace_active_2", "Der Fokus kehrt in das darunterliegende Modal zurück")
	_true(router.back(&"replace_active_1"), "Zurück schließt anschließend das Austauschmodal")
	_equal(router.current_screen_id(), &"preparation", "Der Basisscreen bleibt beim Schließen eines Modals bestehen")
	_equal(router.last_focus_request, &"catalog_card", "Der Fokus kehrt zum Auslöser des Modals zurück")
	_true(router.back(LoadoutSlotId.TREATMENT), "Zurück verlässt die Einsatzplanung")
	_equal(router.current_screen_id(), &"level_select", "Zurück führt direkt zur Fallauswahl statt zu einem Briefing")
	_equal(router.last_focus_request, &"case_one", "Die zuvor gewählte Fallkarte erhält den Fokus zurück")
	_true(router.back(&"case_one"), "Zurück verlässt die Fallauswahl")
	_true(not router.back(), "Die Campuswurzel kann nicht versehentlich entfernt werden")


func _test_context_detail_focus_contract() -> void:
	var router := UIScreenRouter.new()
	var focus_requests: Array = []
	router.focus_requested.connect(func(target: Variant) -> void: focus_requests.append(target))
	var campus_default := Button.new()
	var modal_trigger := Button.new()
	var modal_default := Button.new()
	var detail_trigger := Button.new()
	_true(router.reset(&"campus", campus_default), "Der Fokusstack startet am Campus")
	_true(router.open_modal(&"pause", modal_default, modal_trigger), "Das Pausenmodal wird über seinem Auslöser geöffnet")
	_equal(router.current_modal_id(), &"pause", "Das Pausenmodal ist eindeutig die oberste Modalroute")
	_equal(router.current_focus_owner_id(), &"pause", "Ein interaktives Modal übernimmt den Fokus")
	_true(router.remember_focus(detail_trigger), "Das Modal merkt sich den Auslöser der Detailkarte")
	var requests_before_detail := focus_requests.size()
	_true(router.open_context_detail(&"context_detail", detail_trigger), "Eine Kontextkarte kann modal verschachtelt werden")
	_equal(router.current_modal_id(), &"context_detail", "Die Kontextkarte ist eindeutig das oberste Modal")
	_equal(router.current_input_owner_id(), &"context_detail", "Die Kontextkarte verarbeitet ihre Schließaktion selbst")
	_equal(router.current_focus_owner_id(), &"pause", "Die passive Kontextkarte stiehlt dem Dialog keinen Fokus")
	_equal(focus_requests.size(), requests_before_detail, "Das Öffnen der Kontextkarte fordert keinen neuen Fokus an")
	_true(router.close_modal(), "Das erste Schließen entfernt nur die Kontextkarte")
	_equal(router.current_modal_id(), &"pause", "Das darunterliegende Modal bleibt nach dem Detailschließen aktiv")
	_equal(router.last_focus_request, detail_trigger, "Der Fokus kehrt zum Auslöser der Kontextkarte zurück")
	_true(router.close_modal(), "Das zweite Schließen entfernt das Pausenmodal")
	_equal(router.current_modal_id(), &"", "Nach zwei Schließaktionen ist der Modalstack leer")
	_equal(router.last_focus_request, modal_trigger, "Der Fokus kehrt zum Auslöser des Pausenmodals zurück")
	campus_default.free()
	modal_trigger.free()
	modal_default.free()
	detail_trigger.free()


func _test_late_default_focus_and_invalid_targets() -> void:
	var router := UIScreenRouter.new()
	var focus_requests: Array = []
	router.focus_requested.connect(func(target: Variant) -> void: focus_requests.append(target))
	var screen_default := Button.new()
	var modal_trigger := Button.new()
	var late_modal_default := Button.new()
	_true(router.reset(&"campus", screen_default), "Ein gültiger Screen-Default wird registriert")
	_true(router.open_modal(&"settings", null, modal_trigger), "Ein Modal darf vor seinem sichtbaren Default geöffnet werden")
	_equal(router.last_focus_request, null, "Ohne registrierten Modal-Default wird kein fremder Fokus angefordert")
	_true(router.set_default_focus(&"settings", late_modal_default), "Der Defaultfokus kann nach dem Öffnen registriert werden")
	_equal(router.last_focus_request, late_modal_default, "Ein nachgereichter Default des Fokusowners wird sofort angefordert")
	_equal(focus_requests[focus_requests.size() - 1], late_modal_default, "Die Fassade erhält dafür ein eindeutiges Fokussignal")

	var freed_default := Button.new()
	freed_default.free()
	_true(not router.set_default_focus(&"settings", freed_default), "Ein bereits freigegebenes Control wird als Default verworfen")
	_true(not router.remember_focus(freed_default), "Ein freigegebenes Control wird nicht als letzter Fokus gespeichert")
	_true(not router.set_default_focus(&"missing", screen_default), "Ein unbekannter Routename nimmt keinen Default an")

	modal_trigger.free()
	_true(router.close_modal(), "Das Modal lässt sich trotz freigegebenem Auslöser schließen")
	_equal(router.last_focus_request, screen_default, "Ein ungültiger Auslöser fällt auf den gültigen Screen-Default zurück")
	late_modal_default.free()
	screen_default.free()


func _test_planning_starts_at_treatment() -> void:
	var snapshot := PlanningSnapshot.new()
	snapshot.begin_component_pick(LoadoutSlotId.TREATMENT, &"treatment_precision")
	_equal(snapshot.mode, PlanningSnapshot.Mode.COMPONENT_PICK, "Die Planung überspringt den alten Übersichtsmodus")
	_equal(snapshot.selected_slot_id, LoadoutSlotId.TREATMENT, "Der erste eindeutige Fokus liegt auf der Behandlung")
	_equal(snapshot.current_component_id, &"treatment_precision", "Der direkt gewählte Platz kennt seinen aktuellen Inhalt")
	_true(LoadoutSlotId.planning().has(snapshot.selected_slot_id), "Der direkte Einstieg verwendet einen sichtbaren Planplatz")
	var fresh := PreparedLoadout.default_loadout()
	_equal(fresh.reserve_id, &"", "Ein neuer Standardplan enthält keine Reserve")


func _test_atomic_fixed_slot_changes() -> void:
	var definitions := _definitions()
	var draft := LoadoutDraft.from_prepared(
		PreparedLoadout.create(
			&"treatment_precision",
			[&"ability_focus", &"ability_support"],
			[&"passive_stability", &"passive_precision"],
			&"passive_samples"
		),
		definitions,
		_all_unlocked(definitions),
		8
	)
	var before := draft.slot_snapshot()
	var request := draft.equip(&"ability_push")
	_equal(request.status, LoadoutChangeResult.REQUIRES_REPLACEMENT, "Ein voller Aktivplan verlangt eine explizite Platzwahl")
	_equal(request.replacement_slots, [LoadoutSlotId.ACTIVE_1, LoadoutSlotId.ACTIVE_2], "Nur passende Aktivplätze werden zum Austausch angeboten")
	_equal(draft.slot_snapshot(), before, "Die Austausch-Anforderung verändert keinen Slot")

	var replacement := draft.confirm_replacement(&"ability_push", LoadoutSlotId.ACTIVE_2)
	_true(replacement.applied, "Ein ausdrücklich bestätigter Austausch wird angewendet")
	_equal(replacement.displaced_component_id, &"ability_support", "Das Ergebnis benennt die verdrängte Fähigkeit")
	_equal(draft.component_at(LoadoutSlotId.ACTIVE_2), &"ability_push", "Nur der gewählte Aktivplatz wird ersetzt")
	_equal(draft.component_at(LoadoutSlotId.ACTIVE_1), &"ability_focus", "Der andere Aktivplatz bleibt unverändert")

	var wrong_kind_snapshot := draft.slot_snapshot()
	var wrong_kind := draft.replace(&"passive_guard", LoadoutSlotId.ACTIVE_1)
	_equal(wrong_kind.status, LoadoutChangeResult.INVALID, "Ein Passivmodul passt nicht in einen Aktivplatz")
	_equal(draft.slot_snapshot(), wrong_kind_snapshot, "Eine falsche Platzart mutiert den Plan nicht")
	var treatment_remove := draft.remove(LoadoutSlotId.TREATMENT)
	_equal(treatment_remove.status, LoadoutChangeResult.INVALID, "Die Grundbehandlung kann nicht ersatzlos entfernt werden")
	_equal(draft.component_at(LoadoutSlotId.TREATMENT), &"treatment_precision", "Fehlgeschlagenes Entfernen bewahrt die Grundbehandlung")


func _test_dormant_reserve_backend_compatibility() -> void:
	var definitions := _definitions()
	var draft := LoadoutDraft.from_prepared(
		PreparedLoadout.create(
			&"treatment_precision",
			[&"ability_focus"],
			[&"passive_stability"],
			&"passive_heavy"
		),
		definitions,
		_all_unlocked(definitions),
		7
	)
	var duplicate_snapshot := draft.slot_snapshot()
	var duplicate := draft.equip(&"ability_focus")
	_equal(duplicate.status, LoadoutChangeResult.ALREADY_EQUIPPED, "Erneutes Anklicken rüstet keine Duplikate aus")
	_equal(duplicate.focus_slot, LoadoutSlotId.ACTIVE_1, "Ein vorhandenes Modul liefert seinen Fokusplatz")
	_equal(draft.slot_snapshot(), duplicate_snapshot, "Ein Duplikatklick verändert nichts")

	var reserve_before := draft.slot_snapshot()
	var invalid_swap := draft.swap_slots(LoadoutSlotId.PASSIVE_1, LoadoutSlotId.RESERVE)
	_equal(invalid_swap.status, LoadoutChangeResult.INVALID, "Der kompatible Altbestand lehnt einen zu teuren Reservetausch vor der Mutation ab")
	_equal(invalid_swap.capacity_before, 5, "Das Ergebnis meldet die Kapazität vor dem Reservetausch")
	_equal(invalid_swap.capacity_after, 8, "Das Ergebnis meldet die hypothetische Kapazität nach dem Reservetausch")
	_equal(invalid_swap.capacity_delta, 3, "Das Kapazitätsdelta wird exakt berechnet")
	_equal(draft.slot_snapshot(), reserve_before, "Ein ungültiger Reservetausch ist atomar")

	var roomy := LoadoutDraft.from_prepared(draft.to_prepared(), definitions, _all_unlocked(definitions), 10)
	var valid_swap := roomy.swap_slots(LoadoutSlotId.PASSIVE_1, LoadoutSlotId.RESERVE)
	_true(valid_swap.applied, "Der ruhende Reserve-Backendvertrag bleibt für alte Spielstände funktionsfähig")
	_equal(roomy.component_at(LoadoutSlotId.PASSIVE_1), &"passive_heavy", "Die Reserve wird aktiv")
	_equal(roomy.component_at(LoadoutSlotId.RESERVE), &"passive_stability", "Das bisherige Modul wird zur Reserve")
	_equal(valid_swap.capacity_delta, 3, "Auch ein gültiger Tausch meldet sein Kapazitätsdelta")


func _test_v4_mapping_and_v5_roundtrip() -> void:
	var v4_loadout := {
		"treatment_id": "treatment_precision",
		"ability_ids": ["ability_focus", "ability_support", "ability_legacy_extra"],
		"passive_ids": ["passive_stability", "passive_precision", "passive_legacy_extra"],
		"reserve_id": "passive_samples",
	}
	var migrated := LoadoutSlotSaveAdapter.migrate_v4_loadout(v4_loadout)
	_equal(int(migrated.get("slot_schema_version", 0)), 1, "Ein V4-Plan wird in die feste Slotstruktur migriert")
	var slots: Dictionary = migrated.get("slots", {})
	_equal(slots.get("active_1"), "ability_focus", "Die erste aktive Fähigkeit behält ihren stabilen Platz")
	_equal(slots.get("active_2"), "ability_support", "Die zweite aktive Fähigkeit behält ihren stabilen Platz")
	_equal(slots.get("passive_1"), "passive_stability", "Das erste Passivmodul behält seinen stabilen Platz")
	_equal(slots.get("passive_2"), "passive_precision", "Das zweite Passivmodul behält seinen stabilen Platz")
	_equal(slots.get("reserve"), "passive_samples", "Die Reserve bleibt getrennt erhalten")
	var restored := LoadoutSlotSaveAdapter.deserialize_loadout(migrated)
	_equal(restored.ability_ids, [&"ability_focus", &"ability_support"], "V5 lädt exakt zwei aktive Plätze")
	_equal(restored.passive_ids, [&"passive_stability", &"passive_precision"], "V5 lädt exakt zwei Passivplätze")
	_equal(restored.reserve_id, &"passive_samples", "V5-Roundtrip bewahrt eine historische Reserve trotz ausgeblendeter UI")

	var save_v4 := {
		"version": 4,
		"research_points": 123,
		"prepared_loadouts": {"localized_focus": v4_loadout},
		"unrelated_future_data": {"keep": true},
	}
	var save_v5 := LoadoutSlotSaveAdapter.migrate_v4_save(save_v4)
	_equal(int(save_v5.get("version", 0)), 5, "Der Adapter erzeugt einen Save-v5-Container")
	_equal(save_v5.get("research_points"), 123, "Nicht betroffene Fortschrittsdaten bleiben erhalten")
	_equal(save_v5.get("unrelated_future_data"), {"keep": true}, "Unbekannte Savefelder werden nicht verworfen")
	var decoded := LoadoutSlotSaveAdapter.deserialize_prepared_loadouts(save_v5.get("prepared_loadouts"))
	_true(decoded.has(&"localized_focus"), "V5-Pläne lassen sich fallweise dekodieren")
	_equal((decoded[&"localized_focus"] as PreparedLoadout).treatment_id, &"treatment_precision", "Der dekodierte Fall behält seine Behandlung")
	var original_v4 := LoadoutSlotSaveAdapter.deserialize_loadout(v4_loadout)
	_equal(original_v4.reserve_id, &"passive_samples", "Der Adapter liest eingebettete V4-Pläne weiterhin direkt")


func _definitions() -> Dictionary:
	return {
		&"treatment_precision": {"kind": "treatment", "capacity_cost": 2},
		&"ability_focus": {"kind": "ability", "capacity_cost": 2},
		&"ability_support": {"kind": "ability", "capacity_cost": 2},
		&"ability_push": {"kind": "ability", "capacity_cost": 2},
		&"passive_stability": {"kind": "passive", "capacity_cost": 1},
		&"passive_precision": {"kind": "passive", "capacity_cost": 1},
		&"passive_samples": {"kind": "passive", "capacity_cost": 1},
		&"passive_guard": {"kind": "passive", "capacity_cost": 2},
		&"passive_heavy": {"kind": "passive", "capacity_cost": 4},
	}


func _all_unlocked(definitions: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for component_id in definitions:
		result[component_id] = true
	return result


func _true(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	printerr("FAIL: %s" % message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual == expected:
		return
	failures += 1
	printerr("FAIL: %s | expected=%s actual=%s" % [message, str(expected), str(actual)])
