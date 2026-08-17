extends SceneTree

## Exercises the shared Bio-Lumen material path after an explicit warm-up.
##
## Engine-wide object and memory monitors are deliberately not compared for
## exact equality: renderer and resource caches may remain warm. This runner
## owns exact assertions only for UI nodes, callback owners and the three
## process-wide Bio-Lumen ShaderMaterials.

const BATCH_SIZE := 12
const CYCLES := 100
const RETURN_FRAMES := 3

var assertions := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Control.new()
	host.name = "UIChurnHost"
	get_root().add_child(host)

	# Compile and allocate the fixed material set before taking the baseline.
	var warmup := _create_batch(-1)
	var warmup_root := warmup["root"] as Control
	host.add_child(warmup_root)
	await process_frame
	warmup_root.free()
	await _wait_return_window()

	var baseline_nodes := _node_count(host)
	var baseline_shaders := BioLumenMaterialCache.shader_count()
	var baseline_materials := BioLumenMaterialCache.material_count()
	var baseline_material_creations := BioLumenMaterialCache.materials_created()
	_check(baseline_shaders == 3, "Warm-up besitzt genau drei semantische Bio-Lumen-Shader")
	_check(baseline_shaders <= 4, "Bio-Lumen bleibt unter dem Budget von vier Shaderprogrammen")
	_check(baseline_materials == 3, "Warm-up besitzt genau drei geteilte Bio-Lumen-Materialien")
	_check(baseline_materials <= 24, "Bio-Lumen bleibt unter dem Budget von 24 Live-Materialien")
	_check(baseline_material_creations == baseline_materials, "Der Cache erzeugt jedes semantische Material nur einmal")

	for cycle in range(CYCLES):
		var batch_data := _create_batch(cycle)
		var batch := batch_data["root"] as Control
		var owner_refs: Array = batch_data["owner_refs"]
		host.add_child(batch)
		await process_frame

		_check(
			BioLumenMaterialCache.shader_count() == baseline_shaders,
			"Zyklus %d erzeugt kein weiteres Shaderprogramm" % cycle
		)
		_check(
			BioLumenMaterialCache.material_count() == baseline_materials,
			"Zyklus %d erzeugt kein weiteres Live-Material" % cycle
		)
		_check(
			BioLumenMaterialCache.materials_created() == baseline_material_creations,
			"Zyklus %d erzeugt keine neue Materialinstanz" % cycle
		)

		batch.free()
		await _wait_return_window()
		_check(_node_count(host) == baseline_nodes, "Zyklus %d hinterlässt keine UI-Nodes" % cycle)
		_check(_live_reference_count(owner_refs) == 0, "Zyklus %d hinterlässt keine Callback-Owner" % cycle)

	host.free()
	_finish()

func _create_batch(cycle: int) -> Dictionary:
	var batch := Control.new()
	batch.name = "BioLumenChurn_%d" % cycle
	var owner_refs: Array[WeakRef] = []
	var global_material: ShaderMaterial = null
	var planning_material: ShaderMaterial = null
	var surface_material: ShaderMaterial = null

	for index in range(BATCH_SIZE):
		var primary := AlveolusUIComponents.action_button(
			"Primär %d" % index,
			AlveolusUIComponents.ACTION_PRIMARY
		)
		batch.add_child(primary)
		var primary_fill := primary.get_node_or_null("BioLumenFill") as BioLumenButtonFill
		_check(_is_process_free(primary_fill), "Primärfüllung %d besitzt keinen Process-Callback" % index)
		primary_fill.configure(primary, AlveolusVisualTheme.TEAL if index % 2 == 0 else AlveolusVisualTheme.TURQUOISE)
		_check(_host_callbacks(primary, primary_fill) == 7, "Primärfüllung dupliziert bei Reconfigure keine Callbacks")
		var primary_material := primary_fill.material as ShaderMaterial
		if global_material == null:
			global_material = primary_material
		_check(primary_material == global_material, "Globale Primärfüllungen teilen ein ShaderMaterial")
		owner_refs.append(weakref(primary_fill))
		AlveolusUIComponents.set_button_disabled(primary, index % 3 == 0)
		primary_fill.refresh_state()

		var planning_start := AlveolusUIComponents.planning_start_button("Plan %d" % index)
		batch.add_child(planning_start)
		var planning_fill := planning_start.get_node_or_null("PreparationBioLumenFill") as PreparationBioLumenFill
		_check(_is_process_free(planning_fill), "PlanningStart %d besitzt keinen Process-Callback" % index)
		planning_fill.configure(planning_start, AlveolusVisualTheme.TURQUOISE, AlveolusVisualTheme.GOLD)
		_check(_host_callbacks(planning_start, planning_fill) == 5, "PlanningStart dupliziert bei Reconfigure keine Callbacks")
		var planning_instance := planning_fill.material as ShaderMaterial
		if planning_material == null:
			planning_material = planning_instance
		_check(planning_instance == planning_material, "PlanningStart-Füllungen teilen ein ShaderMaterial")
		owner_refs.append(weakref(planning_fill))
		planning_fill.refresh_state()

		var candidate := Button.new()
		candidate.set_meta(&"catalog_state", &"available")
		candidate.set_meta(&"catalog_available", true)
		batch.add_child(candidate)
		var surface_fill := PreparationBioLumenSurfaceFill.attach(candidate)
		_check(_is_process_free(surface_fill), "Kartenfüllung %d besitzt keinen Process-Callback" % index)
		PreparationBioLumenSurfaceFill.attach(candidate)
		_check(_host_callbacks(candidate, surface_fill) == 7, "Kartenfüllung dupliziert bei Reconfigure keine Callbacks")
		var surface_instance := surface_fill.material as ShaderMaterial
		if surface_material == null:
			surface_material = surface_instance
		_check(surface_instance == surface_material, "Kartenfüllungen teilen ein ShaderMaterial")
		owner_refs.append(weakref(surface_fill))
		surface_fill.set_catalog_state(&"assigned" if index % 2 == 0 else &"available", index % 2 != 0)
		surface_fill.set_selected(index % 4 == 0)
		surface_fill.refresh_state()

		var semantic_card := AlveolusUIComponents.surface(
			AlveolusVisualTheme.SurfaceRole.ACTION_CARD,
			AlveolusVisualTheme.TEAL
		)
		batch.add_child(semantic_card)
		var semantic_fill := semantic_card.get_node_or_null("BioLumenSurface") as BioLumenSurfaceFill
		_check(_is_process_free(semantic_fill), "Semantische Kartenfüllung %d besitzt keinen Process-Callback" % index)
		_check(semantic_fill != null and semantic_fill.material == surface_instance, "Globale Karten und Planung teilen den gecachten Surface-Materialpfad")
		owner_refs.append(weakref(semantic_fill))

	_check(global_material != planning_material, "Globale und Planning-Start-Füllung behalten getrennte Materialien")
	_check(planning_material != surface_material, "Planning-Start und Kartenfüllung behalten getrennte Materialien")
	_check(global_material != surface_material, "Globale und Kartenfüllung behalten getrennte Materialien")
	return {"root": batch, "owner_refs": owner_refs}

func _host_callbacks(button: BaseButton, owner: Object) -> int:
	var count := 0
	for host_signal_value in [
		button.mouse_entered,
		button.mouse_exited,
		button.button_down,
		button.button_up,
		button.focus_entered,
		button.focus_exited,
		button.visibility_changed,
	]:
		var host_signal: Signal = host_signal_value
		for connection_value in host_signal.get_connections():
			var connection: Dictionary = connection_value
			var callback: Callable = connection.get("callable", Callable())
			if callback.is_valid() and callback.get_object_id() == owner.get_instance_id():
				count += 1
	return count

func _is_process_free(fill: CanvasItem) -> bool:
	return fill != null and not fill.is_processing() and not fill.is_physics_processing()

func _wait_return_window() -> void:
	for _frame in range(RETURN_FRAMES):
		await process_frame

func _live_reference_count(references: Array) -> int:
	var count := 0
	for reference in references:
		if reference is WeakRef and (reference as WeakRef).get_ref() != null:
			count += 1
	return count

func _node_count(root: Node) -> int:
	var count := 1
	for child in root.get_children():
		count += _node_count(child)
	return count

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("ALVEOLUS_UI_CHURN_OK assertions=%d cycles=%d shaders=%d materials=%d materials_created=%d" % [
			assertions,
			CYCLES,
			BioLumenMaterialCache.shader_count(),
			BioLumenMaterialCache.material_count(),
			BioLumenMaterialCache.materials_created(),
		])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
