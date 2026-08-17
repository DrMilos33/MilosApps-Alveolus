extends SceneTree

const UIScreenHostScript := preload("res://scripts/ui/ui_screen_host.gd")
const CHURN_CYCLES := 100
const RETURN_FRAMES := 3

var assertions := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := UIScreenHostScript.new()
	host.size = Vector2(960.0, 540.0)
	get_root().add_child(host)
	await process_frame

	_check(not host.is_processing(), "UIScreenHost besitzt keine dauerhafte Prozessschleife")
	_check(not host.is_physics_processing(), "UIScreenHost besitzt keine Physikschleife")
	_check(host.screen_layer_root().name == "ScreenLayer", "Screen-Layer ist deterministisch benannt")
	_check(host.modal_layer_root().name == "ModalLayer", "Modal-Layer ist deterministisch benannt")
	_check(host.detail_layer_root().name == "DetailLayer", "Detail-Layer ist deterministisch benannt")

	var screen_a_data := _route_control("ScreenA")
	var screen_a := screen_a_data["root"] as Control
	var screen_a_button := screen_a_data["button"] as Button
	var screen_b_data := _route_control("ScreenB")
	var screen_b := screen_b_data["root"] as Control
	var screen_b_button := screen_b_data["button"] as Button
	_check(host.mount_screen(&"screen_a", screen_a), "Erster Screen lässt sich mounten")
	_check(host.mount_screen(&"screen_b", screen_b), "Zweiter Screen lässt sich mounten")
	var duplicate_route := Control.new()
	_check(not host.mount_screen(&"screen_a", duplicate_route), "Doppelte Route wird abgelehnt")
	duplicate_route.free()
	_check(not host.mount_screen(&"screen_alias", screen_a), "Dasselbe Control kann nicht doppelt gemountet werden")
	_check(screen_a.get_parent() == host.screen_layer_root(), "Screens liegen ausschließlich im Screen-Layer")

	_check(host.apply_route_state({"screens": [&"screen_a"], "modals": []}, 1), "Erster Snapshot wird angewendet")
	_check(host.is_route_visible(&"screen_a"), "Aktiver Screen ist sichtbar")
	_check(not host.is_route_visible(&"screen_b"), "Inaktiver Screen ist verborgen")
	_check(screen_b.process_mode == Node.PROCESS_MODE_DISABLED, "Verborgener Screen besitzt keinen aktiven Prozessmodus")
	_check(host.is_route_input_owner(&"screen_a"), "Aktiver Screen besitzt die GUI-Eingabe")
	_check(screen_a_button.focus_mode == Control.FOCUS_ALL, "Aktiver Screen bewahrt seinen Fokusmodus")
	_check(screen_b_button.focus_mode == Control.FOCUS_NONE, "Verborgener Screen kann keinen Fokus erhalten")

	var first_state := host.current_route_state()
	_check(not host.apply_route_state({"screens": [&"screen_a"], "modals": []}, 1), "Gleiche Revision ist idempotent")
	_check(not host.apply_route_state({"screens": [&"screen_b"], "modals": []}, 0), "Veraltete Revision wird verworfen")
	_check(host.current_route_state() == first_state, "Stale Apply verändert weder Route noch Revision")
	_check(not host.apply_route_state({"screens": [&"screen_a"], "modals": []}, 2), "Neue Revision ohne Inhaltsänderung erzeugt keinen Layout-Churn")
	_check(host.applied_revision() == 2, "Inhaltsgleiche neue Revision wird dennoch quittiert")

	_check(host.apply_route_state({"screens": [&"screen_a", &"screen_b"], "modals": []}, 3), "Screenwechsel wird angewendet")
	_check(not host.is_route_visible(&"screen_a") and host.is_route_visible(&"screen_b"), "Nur der oberste Screen bleibt sichtbar")
	_check(host.current_input_owner_id() == &"screen_b", "Eingabe folgt dem obersten Screen")

	var modal_a_data := _route_control("ModalA")
	var modal_a := modal_a_data["root"] as Control
	var modal_a_button := modal_a_data["button"] as Button
	var modal_b_data := _route_control("ModalB")
	var modal_b := modal_b_data["root"] as Control
	var modal_b_button := modal_b_data["button"] as Button
	var detail_data := _route_control("ContextDetail")
	var detail := detail_data["root"] as Control
	var detail_button := detail_data["button"] as Button
	_check(host.mount_modal(&"modal_a", modal_a), "Erstes Modal lässt sich mounten")
	_check(host.mount_modal(&"modal_b", modal_b), "Zweites Modal lässt sich mounten")
	_check(host.mount_detail(&"context_detail", detail), "Passive Detailkarte lässt sich mounten")
	_check(modal_a.get_parent() == host.modal_layer_root(), "Modal liegt im Modal-Layer")
	_check(detail.get_parent() == host.detail_layer_root(), "Detailkarte liegt im Detail-Layer")

	_check(host.apply_route_state({
		"screens": [&"screen_a", &"screen_b"],
		"modals": [&"modal_a", &"context_detail"],
	}, 4), "Modal plus passive Detailkarte werden angewendet")
	_check(host.is_route_visible(&"modal_a") and host.is_route_visible(&"context_detail"), "Beide Overlay-Layer bleiben sichtbar")
	_check(host.current_input_owner_id() == &"modal_a", "Passive Detailkarte lässt Eingabe beim obersten blockierenden Modal")
	_check(modal_a_button.focus_mode == Control.FOCUS_ALL, "Blockierendes Modal behält fokussierbare Controls")
	_check(detail_button.focus_mode == Control.FOCUS_NONE, "Passive Detailkarte kann keinen Fokus stehlen")
	_check(detail_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Passive Detailkarte ist vollständig pointer-transparent")
	_check(screen_b_button.focus_mode == Control.FOCUS_NONE, "Unterliegender Screen empfängt bei offenem Modal keine GUI-Eingabe")
	_check(detail.z_index > modal_a.z_index, "Stackreihenfolge bestimmt den visuellen Z-Wert layerübergreifend")

	_check(host.apply_route_state({
		"screens": [&"screen_a", &"screen_b"],
		"modals": [&"modal_a", &"context_detail", &"modal_b"],
	}, 5), "Zweites blockierendes Modal wird auf den Stack gelegt")
	_check(host.current_input_owner_id() == &"modal_b", "Nur das oberste blockierende Modal besitzt Eingabe")
	_check(modal_a_button.focus_mode == Control.FOCUS_NONE, "Unterliegendes Modal ist nicht mehr fokussierbar")
	_check(modal_b_button.focus_mode == Control.FOCUS_ALL, "Oberstes Modal stellt seinen ursprünglichen Fokusmodus wieder her")
	_check(modal_a.z_index < detail.z_index and detail.z_index < modal_b.z_index, "Gemischter Modal-/Detailstack besitzt deterministische Z-Reihenfolge")

	_check(host.apply_route_state({
		"screens": [&"screen_a", &"screen_b"],
		"modals": [&"modal_a", &"context_detail"],
	}, 6), "Schließen des obersten Modals wird angewendet")
	_check(host.current_input_owner_id() == &"modal_a", "Eingabe kehrt unter passiver Detailkarte zum Modal zurück")
	_check(modal_a_button.focus_mode == Control.FOCUS_ALL, "Rückkehr stellt den Eingabestatus wieder her")

	var freed_data := _route_control("FreedModal")
	var freed_modal := freed_data["root"] as Control
	_check(host.mount_modal(&"freed_modal", freed_modal), "Lifecycle-Testmodal lässt sich mounten")
	var freed_ref: WeakRef = weakref(freed_modal)
	freed_modal.queue_free()
	await _wait_return_window()
	_check(freed_ref.get_ref() == null, "Extern freigegebenes Control wird tatsächlich zerstört")
	_check(not host.has_route(&"freed_modal"), "Freigegebenes Control hinterlässt keine Route")

	var detached := host.unmount_route(&"modal_b")
	_check(detached == modal_b and detached.get_parent() == null, "Unmount überträgt ein nicht freigegebenes Control an den Aufrufer")
	_check(not host.has_route(&"modal_b"), "Unmount entfernt die Zuordnung vollständig")
	_check(modal_b_button.focus_mode == Control.FOCUS_ALL, "Unmount stellt ursprüngliche Input-Eigenschaften wieder her")
	detached.free()

	# Leave no persistent mounted route before taking the churn baseline.
	for route_id in [&"screen_a", &"screen_b", &"modal_a", &"context_detail"]:
		host.unmount_route(route_id, true)
	await _wait_return_window()
	var baseline_nodes := _node_count(host)
	var weak_views: Array[WeakRef] = []
	var revision := 10
	for cycle in range(CHURN_CYCLES):
		var route_id := StringName("churn_%d" % cycle)
		var cycle_data := _route_control("Churn%d" % cycle)
		var cycle_view := cycle_data["root"] as Control
		weak_views.append(weakref(cycle_view))
		_check(host.mount_screen(route_id, cycle_view), "Churn %d mountet genau einen Screen" % cycle)
		revision += 1
		_check(host.apply_route_state({"screens": [route_id], "modals": []}, revision), "Churn %d wendet eine neue Revision an" % cycle)
		_check(host.current_input_owner_id() == route_id, "Churn %d besitzt genau einen Eingabeeigentümer" % cycle)
		host.unmount_route(route_id, true)
		await _wait_return_window()
		_check(host.mounted_route_count() == 0, "Churn %d hinterlässt keine Route" % cycle)
		_check(_node_count(host) == baseline_nodes, "Churn %d hinterlässt keine UI-Nodes" % cycle)

	_check(_live_reference_count(weak_views) == 0, "100 Mount-/Unmountzyklen hinterlassen keine Controls")
	host.free()
	_finish()


func _route_control(control_name: String) -> Dictionary:
	var root := Control.new()
	root.name = control_name
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.focus_mode = Control.FOCUS_ALL
	var button := Button.new()
	button.name = "Action"
	button.text = control_name
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(button)
	return {"root": root, "button": button}


func _wait_return_window() -> void:
	for _frame in range(RETURN_FRAMES):
		await process_frame


func _node_count(root: Node) -> int:
	var count := 1
	for child in root.get_children():
		count += _node_count(child)
	return count


func _live_reference_count(references: Array[WeakRef]) -> int:
	var count := 0
	for reference in references:
		if reference.get_ref() != null:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_UI_SCREEN_HOST_OK assertions=%d cycles=%d" % [assertions, CHURN_CYCLES])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
