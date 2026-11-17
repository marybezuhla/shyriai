# SPDX-License-Identifier: GPL-3.0-or-later
# Smoke checks for package 4: the six looks, kids' pilots, the celebration, records and the big
# licence, the break reminder and the larger-text option rows.
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
	Prefs.set_language("uk")
	for t in ["day", "sky", "mallow", "dusk", "starry", "seanight"]:
		Prefs.set_theme(t)
		main.open_tab("learn")
		await s._frames(2)
		assert(Pal.current == t, "the look %s applies" % t)
		await s._shot("uk-%s-home" % t)
	Prefs.set_theme("dusk")
	main.open_settings()
	await s._frames(2)
	await s._shot("uk-dusk-settings-looks")
	main.back()
	await _pilots()
	await _celebration()
	await _records()
	await _break()
	Prefs.set_text_size("larger")
	main.open_settings()
	await s._frames(2)
	await s._shot("uk-dusk-settings-larger")
	main.back()
	Prefs.set_text_size("normal")
	Prefs.erase_all()
	Prefs.welcome(false)


func _pilots() -> void:
	Prefs.set_mode("kids")
	Prefs.set_kids_lock(false)
	assert(Pal.current == "morning", "kids see Day as Morning")
	KidPilots.add()
	KidPilots.add()
	main.open_tab("learn")
	await s._frames(2)
	main.open_pilots()
	await s._frames(2)
	assert(s._texts(main.stack.back()).has(s.tr("PILOTS_WHO")), "who's flying?")
	await s._shot("uk-kids-pilots")
	main.back()
	await s._frames(2)
	await s._shot("uk-kids-home-pilot")
	Prefs.set_mode("simple")


func _celebration() -> void:
	main.start("camera", "CAM_STICKS")
	await s._frames(2)
	main.flight.task.pass_with("SUM_CAM_STICKS", [])
	await s._seconds(0.2)
	assert(not main.flight.find_children("*", "Confetti", true, false).is_empty(), "a passed lesson has confetti")
	var next: String = Curriculum.lessons("camera", "simple")[1]
	assert(s._texts(main.flight._overlay).has(s.tr("NEXT_TO") % Curriculum.label(next)), "the next lesson is named")
	await s._shot("uk-dusk-flight-celebration")
	main.close_flight()


func _records() -> void:
	for i in Curriculum.lessons("camera", "simple").size():
		Prefs.mark_passed("camera", i)
		Prefs.record(Curriculum.lessons("camera", "simple")[i], 3 - i % 3, 30.0 + i * 7.0)
	main.open_pilot_cards()
	await s._frames(2)
	var texts: Array = s._texts(main.stack.back())
	assert(texts.has(s.tr("RECORDS").to_upper()) and texts.has(s.tr("CARD_BIG")), "records and the big licence")
	await s._shot("uk-dusk-records")
	var card: Node = main.stack.back()
	card._show_big("camera", Prefs.licence_date("camera"), false)
	await s._frames(2)
	await s._shot("uk-dusk-licence-big")
	main.back()


func _break() -> void:
	Prefs.set_mode("kids")
	main.flown = BreakCard.AFTER + 1.0
	main.start("camera", Curriculum.lessons("camera", "kids")[0])
	await s._frames(2)
	assert(main.flight == null and not main.find_children("*", "BreakCard", true, false).is_empty(), "a break before the next flight")
	await s._shot("uk-kids-break")
	main.find_children("*", "BreakCard", true, false)[0]._go(main.find_children("*", "BreakCard", true, false)[0].on_rest)
	assert(main.flown == 0.0, "resting starts the count again")
	Prefs.set_mode("simple")
