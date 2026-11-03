# SPDX-License-Identifier: GPL-3.0-or-later
# Goes through every screen, theme, language and mode; CI fails on any script error.
# Not shipped in the APK (see export_presets.cfg). Optional screenshots: SHYRIAI_SHOTS=<dir>.
extends Node

var shots := OS.get_environment("SHYRIAI_SHOTS")
var main: Node


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames(3)
	for lang in ["uk", "en"]:
		Prefs.set_language(lang)
		for theme in ["dusk", "day"]:
			Prefs.set_theme(theme)
			await _visit(lang, theme)
	Prefs.set_language("system")
	Prefs.set_theme("dusk")
	Prefs.set_mode("simple")
	print("SMOKE OK")
	get_tree().quit(0)


func _visit(lang: String, theme: String) -> void:
	for m in Prefs.MODES:
		Prefs.set_mode(m)
		main.open_tab("learn")
		await _shot("%s-%s-home-%s" % [lang, theme, m])
	Prefs.set_mode("simple")
	for v in Curriculum.VEHICLES:
		main.open_lessons(v)
		await _shot("%s-%s-lessons-%s" % [lang, theme, v])
		var s = main.stack.back()
		s.tab = "missions"
		s.rebuild()
		await _shot("%s-%s-lessons-%s-missions" % [lang, theme, v])
		s.tab = "learn"
		s.selected = Curriculum.lessons(v).size() - 1
		s.rebuild()
		await _frames(2)
		main.back()
	main.open_tab("missions")
	await _shot("%s-%s-missions" % [lang, theme])
	main.open_tab("theory")
	await _shot("%s-%s-theory" % [lang, theme])
	main.open_soon("Test")
	await _shot("%s-%s-soon" % [lang, theme])
	main.back()
	main.open_tab("learn")
	main.open_settings()
	await _shot("%s-%s-settings" % [lang, theme])
	main.open_about()
	await _shot("%s-%s-about" % [lang, theme])
	main.open_licenses()
	await _frames(3)
	main.back()
	main.back()
	main.back()
	await _frames(2)
	assert(main.stack.size() == 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(4)
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))
