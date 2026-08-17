extends SceneTree

var assertions := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var scene := load("res://scenes/ui/lexicon_master_detail.tscn") as PackedScene
	var lexicon := scene.instantiate() as LexiconMasterDetail
	lexicon.configure(null, [&"pneumococcus", &"analysis_pickup", &"patient_stability"])
	get_root().add_child(lexicon)
	await process_frame
	await process_frame

	_test_master_detail_structure(lexicon)
	_test_lock_and_selection(lexicon)
	await _test_mouse_and_focus_navigation(lexicon)
	await _test_responsive_detail_density(lexicon)
	await _test_layout_sizes(lexicon)
	await _test_game_hud_embedding()

	lexicon.queue_free()
	await process_frame
	if failures.is_empty():
		print("ALVEOLUS_LEXICON_MASTER_DETAIL_OK assertions=%d" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _test_master_detail_structure(lexicon: LexiconMasterDetail) -> void:
	_check(lexicon.category_buttons.size() == 4, "Vier übergeordnete Kategorien sind sichtbar")
	_check(lexicon.entry_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Linke Liste scrollt nur vertikal")
	_check(lexicon.detail_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Detailbereich scrollt nur vertikal")
	_check(lexicon.entry_buttons.size() == 4, "Monsterliste enthält alle vier Gegnerarten")
	_check(lexicon.selected_entry_id == &"pneumococcus", "Die erste bekannte Kachel füllt den Detailbereich sofort")
	_check(MedicalLexiconIllustration.SAFE_MARGIN >= 4.0, "Lexikonillustrationen reservieren einen festen Sicherheitsabstand zum Kachelrand")
	for button in lexicon.entry_buttons.values():
		var illustrations: Array[Node] = button.find_children("*", "MedicalLexiconIllustration", true, false)
		_check(illustrations.size() == 1, "Jede Lexikonkachel besitzt genau eine Illustration oder Silhouette")
		if not illustrations.is_empty():
			_check(_artboard_fits_safely(illustrations[0] as MedicalLexiconIllustration), "Jede kompakte Lexikonillustration skaliert innerhalb ihrer sicheren 48-px-Fläche")
	_check(_artboard_fits_safely(lexicon.detail_illustration), "Auch die große Detailillustration wahrt ihre Icon-Safe-Area")
	_check(lexicon.detail_gameplay_text.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Lange Spieltexte umbrechen")
	_check(lexicon.detail_medical_text.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Lange medizinische Texte umbrechen")
	var safe_inset := lexicon.detail_scroll.get_node_or_null("ScrollbarSafeInset") as MarginContainer
	_check(safe_inset != null and safe_inset.get_parent() == lexicon.detail_scroll, "Der Detailinhalt besitzt direkt vor der Scrollbar einen eigenen Sicherheits-Inset")
	if safe_inset != null:
		var scrollbar_width := lexicon.detail_scroll.get_v_scroll_bar().get_combined_minimum_size().x
		_check(safe_inset.get_theme_constant("margin_right") >= ceili(scrollbar_width), "Der rechte Sicherheits-Inset hält Texte und Werte vollständig von der Scrollbar frei")
		_check(safe_inset.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Der Scrollbar-Inset füllt die verfügbare Detailbreite")
	_check(lexicon.detail_gameplay_panel != lexicon.detail_medical_panel, "Spielwirkung und medizinischer Hintergrund besitzen getrennte Flächen")
	for semantic_panel in [lexicon.detail_gameplay_panel, lexicon.detail_medical_panel]:
		_check(semantic_panel is PanelContainer and semantic_panel.get_meta(&"alveolus_component", &"") == &"semantic_copy_section", "Jede Bedeutungsebene verwendet die semantische Textflächen-Komponente")
	_check(lexicon.detail_gameplay_panel.is_ancestor_of(lexicon.detail_gameplay_text), "Der Spieltext bleibt innerhalb seiner semantischen Fläche")
	_check(lexicon.detail_medical_panel.is_ancestor_of(lexicon.detail_medical_text), "Der medizinische Text bleibt innerhalb seiner semantischen Fläche")

func _test_lock_and_selection(lexicon: LexiconMasterDetail) -> void:
	_check(lexicon.select_entry(&"pneumococcus"), "Entdecktes Bakterium ist auswählbar")
	_check(not lexicon.detail_illustration.locked, "Entdeckte Illustration ist sichtbar")
	_check(lexicon.detail_stats_grid.get_child_count() == 12, "Sechs Gegnerwerte werden strukturiert dargestellt")
	_check(lexicon.detail_title.text == "Bakterium", "Detailtitel verwendet einfachen Namen")
	_check(lexicon.detail_medical_name.text == "Pneumokokke", "Fachbegriff bleibt als zweite Ebene")

	_check(lexicon.select_entry(&"bacterial_cluster"), "Gesperrter Eintrag bleibt als Silhouette anwählbar")
	_check(lexicon.detail_illustration.locked, "Gesperrter Eintrag zeichnet die Silhouette")
	_check(lexicon.detail_title.text == "Noch nicht beobachtet", "Gesperrter Eintrag verrät keinen Namen")
	_check(not lexicon.detail_stats_grid.visible, "Gesperrter Eintrag verrät keine Werte")
	_check(not lexicon.detail_medical_name.visible, "Gesperrter Eintrag verrät keinen Fachbegriff")

	lexicon.select_category(LexiconEntryDefinition.CATEGORY_TERMS)
	_check(lexicon.entry_buttons.size() >= 27, "Begriffslexikon enthält den vollständigen Startkatalog")
	var tempo_id := &"term_treatment_speed"
	_check(lexicon.select_entry(tempo_id), "Behandlungstempo ist direkt lesbar")
	_check(lexicon.detail_gameplay_text.text.contains("Intervall"), "Detail erklärt Behandlungstempo verständlich")

func _test_responsive_detail_density(lexicon: LexiconMasterDetail) -> void:
	lexicon.select_category(LexiconEntryDefinition.CATEGORY_MONSTERS)
	_check(lexicon.select_entry(&"pneumococcus"), "Bekannter Gegner stellt seine Basiswerte für die Dichteprüfung bereit")
	await process_frame
	_check(lexicon.detail_stats_grid.columns == 4, "Breites Lexikon zeigt zwei kompakte Wertpaare pro Zeile")
	_check(lexicon.detail_stats_grid.get_child_count() == 12, "Die Zwei-Spalten-Wertansicht behält alle sechs Basiswerte")
	for index in range(0, lexicon.detail_stats_grid.get_child_count(), 2):
		var caption := lexicon.detail_stats_grid.get_child(index) as Label
		var value := lexicon.detail_stats_grid.get_child(index + 1) as Label
		_check(caption != null and value != null and value.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Jedes Basiswertpaar besteht aus Bezeichnung und rechtsbündigem Wert")
		if caption != null and value != null:
			var gap := value.get_global_rect().position.x - caption.get_global_rect().end.x
			_check(gap >= -0.5 and gap <= 16.5, "Basiswert und Bezeichnung bleiben als nahe lesbares Paar zusammen")

	# The scene has an 800-px minimum, which is intentionally still below the
	# 820-px master/detail breakpoint. Pin it to the top-left so the test covers
	# the component's compact contract independently of viewport stretch mode.
	lexicon.set_anchor(SIDE_RIGHT, 0.0)
	lexicon.set_anchor(SIDE_BOTTOM, 0.0)
	lexicon.size = Vector2(800.0, 620.0)
	await process_frame
	await process_frame
	_check(lexicon.detail_stats_grid.columns == 2, "Kompaktes Lexikon zeigt genau ein Bezeichnungs-/Wertpaar pro Zeile")
	_check(lexicon.category_bar.columns == 2, "Kompaktes Lexikon ordnet auch die Kategorien in zwei Spalten")

	lexicon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	_check(lexicon.detail_stats_grid.columns == 4, "Nach Rückkehr zur breiten Ansicht werden wieder zwei Wertpaare je Zeile gezeigt")

func _test_game_hud_embedding() -> void:
	var hud := GameHUD.new()
	get_root().add_child(hud)
	await process_frame
	await process_frame
	_check(hud.lexicon_master_detail != null, "Der GameHUD bindet die Master/Detail-Komponente direkt ein")
	if hud.lexicon_master_detail != null:
		_check(not _has_scroll_ancestor(hud.lexicon_master_detail), "Das Lexikon besitzt im GameHUD keinen zweiten äußeren ScrollContainer")
	hud.queue_free()
	await process_frame

func _test_mouse_and_focus_navigation(lexicon: LexiconMasterDetail) -> void:
	var monster_tab := lexicon.category_buttons[LexiconEntryDefinition.CATEGORY_MONSTERS] as Button
	var character_tab := lexicon.category_buttons[LexiconEntryDefinition.CATEGORY_CHARACTER] as Button
	_check(monster_tab.focus_neighbor_right == monster_tab.get_path_to(character_tab), "Kategorien besitzen explizite horizontale Fokusnavigation")
	monster_tab.pressed.emit()
	_check(lexicon.selected_category == LexiconEntryDefinition.CATEGORY_MONSTERS, "Mausklick wechselt die Kategorie")
	var visible_entries := LexiconCatalog.entries_for_category(LexiconEntryDefinition.CATEGORY_MONSTERS)
	var first := lexicon.entry_buttons[visible_entries[0].id] as Button
	var second := lexicon.entry_buttons[visible_entries[1].id] as Button
	_check(first.focus_neighbor_bottom == first.get_path_to(second), "Einträge besitzen explizite vertikale Fokusnavigation")
	_check(first.focus_neighbor_left == first.get_path_to(monster_tab), "Linksnavigation führt zur aktiven Kategorie")
	second.mouse_entered.emit()
	await process_frame
	_check(lexicon.selected_entry_id == visible_entries[1].id, "Mouseover zeigt die Detailinformation des berührten Lexikoneintrags sofort")
	lexicon.grab_initial_focus()
	await process_frame
	_check(get_root().gui_get_focus_owner() == monster_tab, "Anfangsfokus ist für Tastatur und Gamepad sichtbar")
	first.grab_focus()
	await process_frame
	_check(lexicon.selected_entry_id == visible_entries[0].id, "Tastatur- und Gamepadfokus aktualisieren dieselbe Detailvorschau wie Mouseover")
	var activation_events: Array[StringName] = []
	lexicon.entry_selected.connect(func(entry_id: StringName) -> void: activation_events.append(entry_id))
	_send_action(&"ui_accept", true)
	await process_frame
	_send_action(&"ui_accept", false)
	await process_frame
	_check(not activation_events.is_empty() and activation_events[-1] == visible_entries[0].id, "Tastatur und Gamepad Aktivierung bestätigen den fokussierten Eintrag")

func _test_layout_sizes(lexicon: LexiconMasterDetail) -> void:
	for viewport_size in [Vector2i(1280, 720), Vector2i(1024, 576), Vector2i(960, 540)]:
		get_root().size = viewport_size
		await process_frame
		await process_frame
		var root_rect := lexicon.get_global_rect()
		# canvas_items keeps Control coordinates in the 1280 x 720 reference
		# canvas and scales that complete canvas to the physical viewport.
		var reference_size := Vector2(1280.0, 720.0)
		_check(root_rect.position.x >= -0.5 and root_rect.position.y >= -0.5, "Lexikon beginnt bei %s im sichtbaren Bereich" % viewport_size)
		_check(root_rect.end.x <= reference_size.x + 0.5 and root_rect.end.y <= reference_size.y + 0.5, "Lexikon bleibt bei %s vollständig im Bild" % viewport_size)
		_check(lexicon.entry_scroll.size.x >= 260.0, "Linke Liste bleibt bei %s gut lesbar" % viewport_size)
		_check(lexicon.detail_scroll.size.x >= 400.0, "Detailtext behält bei %s ausreichend Breite" % viewport_size)

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func _artboard_fits_safely(illustration: MedicalLexiconIllustration) -> bool:
	if illustration == null:
		return false
	var control_size := illustration.size
	if control_size.x <= 0.0 or control_size.y <= 0.0:
		control_size = illustration.custom_minimum_size
	var short_side := minf(control_size.x, control_size.y)
	var available_diameter := maxf(0.0, short_side - MedicalLexiconIllustration.SAFE_MARGIN * 2.0)
	var rendered_diameter := minf(MedicalLexiconIllustration.ARTBOARD_DIAMETER, available_diameter)
	return rendered_diameter > 0.0 and (short_side - rendered_diameter) * 0.5 >= MedicalLexiconIllustration.SAFE_MARGIN - 0.01

func _send_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)

func _has_scroll_ancestor(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current is ScrollContainer:
			return true
		current = current.get_parent()
	return false
