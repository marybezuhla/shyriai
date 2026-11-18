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
