# SPDX-License-Identifier: GPL-3.0-or-later
# The pilot's book: every chapter has its texts in both languages, its glossary words exist, its
# lesson exists, what was read is saved and checked, and the kids' little book has no numbers.
extends "res://tests/sim_home.gd"


func test_book() -> void:
	var ids := []
	for ch in Book.CHAPTERS:
		var id: String = ch["id"]
		check(id not in ids, "chapter %s is listed once" % id)
		ids.append(id)
		for lang in ["uk", "en"]:
			TranslationServer.set_locale(lang)
			for part in ["_T", "_DESC", "_BODY"]:
				var key := "BOOK_%s%s" % [id, part]
				check(String(TranslationServer.translate(key)) != key, "%s has a text (%s)" % [key, lang])
			var body := String(TranslationServer.translate("BOOK_%s_BODY" % id))
			for term in Book.terms(body):
				check(String(TranslationServer.translate("GL_%s_T" % term)) != "GL_%s_T" % term, "%s explains %s (%s)" % [id, term, lang])
			check(not Book.plain(body).contains("{") and not Book.bbcode(body, Color.WHITE).contains("{"), "%s shows no markup (%s)" % [id, lang])
		var go: Array = ch["try"]
		if not go.is_empty():
			check(go[1] in Curriculum.lessons(go[0]), "%s leads to a real lesson" % id)
		if ch["card"] != "":
			check(ch["card"] in Curriculum.THEORY, "%s carries a real theory card" % id)
	_glossary_matches_book()
	TranslationServer.set_locale("en")
	for v in Curriculum.VEHICLES:
		for key in Curriculum.lessons(v):
			check(Book.index_of(Book.chapter_for(v, key)) >= 0, "lesson %s has a chapter" % key)
	check(Book.bbcode("a [b] {GPS:c}", Color.WHITE).begins_with("a (b) [url=GPS]"), "a translation cannot add its own BBCode")
	Prefs.erase_all()
	check(Book.next_unread() == "CONTROLS" and Book.read_count() == 0, "the book starts at chapter 1")
	Book.mark_read("CONTROLS")
	Book.mark_read("CONTROLS")
	Book.mark_read("NOPE")
	check(Book.read_count() == 1 and Book.next_unread() == "CHECKLIST", "a chapter counts once, an unknown one not at all")
	Prefs._apply({"book_read": ["RULES", "RULES", 3, "NOPE", {"x": 1}, "WING"]})
	check(Prefs.book_read == ["RULES", "WING"], "what was read is checked when loaded")
	Prefs._apply({"book_read": "WING"})
	check(Prefs.book_read.is_empty(), "a list that is not a list is ignored")
	Prefs.erase_all()
	check(Prefs.book_read.is_empty(), "erasing everything forgets the reading too")


## The glossary and the book stay in step: every word the book links is in the glossary, every
## glossary word is linked from some chapter, and both languages link the same words.
func _glossary_matches_book() -> void:
	var listed: Array = preload("res://scripts/screens/glossary.gd").TERMS
	var linked := {}
	for ch in Book.CHAPTERS:
		var per_lang := []
		for lang in ["uk", "en"]:
			TranslationServer.set_locale(lang)
			var t := Book.terms(String(TranslationServer.translate("BOOK_%s_BODY" % ch["id"])))
			t.sort()
			per_lang.append(t)
			for term in t:
				linked[term] = true
		check(per_lang[0] == per_lang[1], "%s links the same words in both languages" % ch["id"])
	for term in listed:
		check(listed.count(term) == 1, "%s is in the glossary once" % term)
		check(linked.has(term), "the glossary word %s is linked from a chapter" % term)
		for lang in ["uk", "en"]:
			TranslationServer.set_locale(lang)
			check(String(TranslationServer.translate("GL_" + term)) != "GL_" + term, "%s is explained (%s)" % [term, lang])
	for term in linked:
		check(term in listed, "the linked word %s is in the glossary" % term)


func test_kids_book() -> void:
	var rx := RegEx.create_from_string("\\d|мішен|(^|[^а-яіїєґ])ціл(ь|і|ься)([^а-яіїєґ]|$)|target|(^|[^a-z])aim")
	for lang in ["uk", "en"]:
		TranslationServer.set_locale(lang)
		var keys := ["BOOK_KIDS", "BOOK_KIDS_DESC", "BOOK_KIDS_NEXT", "BOOK_KIDS_DONE", "BOOK_KIDS_BACK", "THEORY_INTRO_KIDS"]
		for n in Book.KIDS_PAGES.size():
			keys.append("BOOK_KIDS_%d" % (n + 1))
		for k in keys:
			var text := String(TranslationServer.translate(k))
			check(text != k and rx.search(text) == null, "kids book %s (%s) has a text with no numbers: %s" % [k, lang, text])
	TranslationServer.set_locale("en")


func _level(id: String, vehicle := "") -> int:
	for b in Badges.all():
		if b["id"] == id and b.get("vehicle", "") == vehicle:
			return b["level"]
	return -1


## The badges come from the progress already kept: earned step by step, nothing new saved.
func test_badges() -> void:
	TranslationServer.set_locale("uk")
	Prefs.erase_all()
	Prefs.set_mode("simple")
	var saved_keys := Prefs._data().keys()
	check(Badges.earned(Badges.all()) == 0 and Badges.all().size() == 14, "a new pilot has 14 badges ahead, none earned")
	check(Badges.all().all(func(b): return b["level"] == 0), "every badge starts pale")
	var t := Badges.totals()
	check(t["lessons"] == Vector2i(0, 35) and t["chapters"] == Vector2i(0, 10), "the totals start at nothing (%s)" % t)
	Prefs.mark_passed("camera", 0)
	Prefs.record("CAM_STICKS", 3, 5.0)
	check(_level("FIRST") == 2 and _level("LIC", "camera") == 0 and _level("ALL") == 1, "one lesson: the first flight, all craft begun")
	check(_level("FIELD") == 1, "three sunflowers on a lesson: the field is on the way")
	var cam: Array = Curriculum.lessons("camera", "simple")
	for i in cam.size():
		Prefs.mark_passed("camera", i)
		Prefs.record(cam[i], 3, 5.0)
	check(_level("LIC", "camera") == 2 and _level("ACE") == 1 and _level("FIELD") == 2, "a whole course: its licence and the field")
	check(_level("CLEAN") == 1, "eight clean lessons: on the way, not ten yet")
	var fpv: Array = Curriculum.lessons("fpv", "simple")
	for i in 2:
		Prefs.mark_passed("fpv", i)
		Prefs.record(fpv[i], 2, 50.0)
	check(_level("CLEAN") == 2 and _level("LIC", "fpv") == 1, "ten clean lessons; half the FPV course is on the way")
	Prefs.mark_mission("MIS_CAM_SEARCH")
	check(_level("MISSION") == 2 and _level("MISSIONS") == 1, "a mission: the first one, all of them on the way")
	for ch in Book.CHAPTERS:
		Book.mark_read(ch["id"])
	check(_level("READER") == 2, "the whole book read")
	check(Badges.totals()["missions"].x == 1 and Badges.totals()["flowers"].x == 28, "the totals count what was done (%s)" % Badges.totals())
	check(Prefs._data().keys() == saved_keys, "the badges save nothing of their own")
	Prefs.set_mode("pro")
	check(_level("FIRST") == 0, "each mode has its own badges")
	Prefs.set_mode("kids")
	var kids := Badges.all()
	check(kids.size() == 10 and kids.all(func(b): return b["note"] == ""), "kids get ten badges and no numbers")
	check(not Badges.totals().has("chapters"), "the kids' totals leave out the grown-ups' book")
	TranslationServer.set_locale("en")
	Prefs.erase_all()
