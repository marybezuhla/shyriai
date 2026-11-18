# SPDX-License-Identifier: GPL-3.0-or-later
# Smoke checks for the badges: the home card appears once there is progress, and the badges screen
# fits in both languages, in every mode and at every text size, with no word cut or off the screen.
# Run from smoke.gd; `s` is that test node. Not shipped in the APK.
extends RefCounted

var s: Node
var main: Node


func _init(smoke: Node) -> void:
	s = smoke
	main = smoke.main


func run() -> void:
	Prefs.erase_all()
	Prefs.welcome(false)
	Prefs.set_kids_lock(false)
	for m in Prefs.MODES:
		Prefs.set_mode(m)
		main.open_tab("learn")
		await s._frames(2)
		assert(not _home_has_card(), "no badges card before any progress (%s)" % m)
		_some_progress()
		main.open_tab("learn")
		await s._frames(2)
		assert(_home_has_card(), "the badges card once there is progress (%s)" % m)
		for lang in ["uk", "en"]:
			Prefs.set_language(lang)
			for size in Prefs.TEXT_SIZES:
				Prefs.set_text_size(size)
				main.open_badges()
				await s._frames(3)
				_fits("%s %s %s" % [m, lang, size])
				await s._shot("badges-%s-%s-%s" % [lang, m, size])
				main.back()
				await s._frames(1)
	await _every_screen_fits()
	Prefs.set_text_size("normal")
	Prefs.set_language("uk")
	Prefs.set_mode("simple")
	main.open_tab("learn")
	await s._frames(2)
	await s._shot("badges-uk-home")
	# Pointer events reach the screen only with a real window (the screenshot runs have one).
	if DisplayServer.get_name() != "headless":
		await _press_look()
	Prefs.erase_all()
	Prefs.welcome(false)


## No word is cut on any menu screen, in any mode, language or text size.
func _every_screen_fits() -> void:
	var opens := {
		"home": func(): main.open_tab("learn"), "missions": func(): main.open_tab("missions"),
		"theory": func(): main.open_tab("theory"), "settings": func(): main.open_settings(),
		"lessons": func(): main.open_lessons("intercept"), "cards": func(): main.open_pilot_cards(),
		"glossary": func(): main.open_glossary(), "book": func(): main.open_book(),
		"about": func(): main.open_about(), "pad": func(): main.open_pad(),
		"kidsbook": func(): main.open_kids_book(), "card": func(): main.open_theory("TH_BATTERY"),
		"pilots": func(): main.open_pilots(true), "chapter": func(): main.open_chapter("BATTERY"),
	}
	for m in Prefs.MODES:
		Prefs.set_mode(m)
		for lang in ["uk", "en"]:
			Prefs.set_language(lang)
			for size in Prefs.TEXT_SIZES:
				Prefs.set_text_size(size)
				for name in opens:
					main.open_tab("learn")
					opens[name].call()
					await s._frames(2)
					_fits("%s %s %s %s" % [name, m, lang, size])
				main.open_tab("learn")


func _home_has_card() -> bool:
	return s._texts(main.stack.back()).has(s.tr("BADGES_KIDS" if Prefs.mode == "kids" else "BADGES"))


func _some_progress() -> void:
	var cam: Array = Curriculum.lessons("camera", Prefs.mode)
	for i in cam.size():
		Prefs.mark_passed("camera", i)
		Prefs.record(cam[i], 3 if i < 3 else 2, 10.0)
	Prefs.mark_passed("fpv", 0)
	Prefs.mark_mission(Curriculum.missions("camera", Prefs.mode)[0])
	Book.mark_read("CONTROLS")


## Every label is on the screen, and its longest word fits on one line.
func _fits(tag: String) -> void:
	var screen: Control = main.stack.back()
	var right: float = main.get_viewport_rect().size.x
	for n in screen.find_children("*", "Label", true, false):
		var l := n as Label
		var r := l.get_global_rect()
		assert(r.end.x <= right + 0.5, "%s: \"%s\" stays on the screen (%d > %d)" % [tag, l.text, r.end.x, right])
		var font := l.get_theme_font("font")
		var px := l.get_theme_font_size("font_size")
		for w in l.text.replace("\u200b", " ").split(" ", false):
			var ww := font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			assert(ww <= l.size.x + 1.0, "%s: the word \"%s\" fits (%d > %d)" % [tag, w, ww, l.size.x])


## A card darkens under a resting finger, but not under one that scrolls the list.
func _press_look() -> void:
	var card: PanelContainer = null
	for p in main.stack.back().find_children("*", "PanelContainer", true, false):
		if p.get_child_count() > 1 and p.get_child(-1) is Button and p.get_global_rect().size.y > 60:
			card = p
			break
	assert(card != null, "the home screen has a card to press")
	var normal := card.get_theme_stylebox("panel")
	var at := card.get_global_rect().get_center()
	_mouse(at, true)
	await s._seconds(0.2)
	assert(card.get_theme_stylebox("panel") != normal, "a resting finger darkens the card")
	_mouse(at + Vector2(0, 40), false, true)
	await s._frames(2)
	assert(card.get_theme_stylebox("panel") == normal, "a moving finger turns it back")
	_mouse(at + Vector2(0, 40), false)
	await s._frames(2)
	_mouse(at, true)
	_mouse(at + Vector2(0, 30), false, true)
	await s._seconds(0.2)
	assert(card.get_theme_stylebox("panel") == normal, "a scroll never darkens it")
	_mouse(at + Vector2(0, 30), false)
	await s._frames(2)
	if main.stack.size() > 1:
		main.back()
	main.open_tab("learn")
	await s._frames(2)


func _mouse(at: Vector2, down: bool, move := false) -> void:
	if move:
		var m := InputEventMouseMotion.new()
		m.position = at
		m.global_position = at
		m.relative = Vector2(0, 40)
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
		return
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)
