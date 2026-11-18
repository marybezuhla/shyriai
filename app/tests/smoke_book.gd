# SPDX-License-Identifier: GPL-3.0-or-later
# Smoke checks for the pilot's book: the Theory tab, the contents, every chapter in both languages
# and at the largest text, a word explained and closed with Back, the lesson's "Read about it",
# and the kids' little book page by page.
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
	Prefs.set_mode("simple")
	for lang in ["uk", "en"]:
		Prefs.set_language(lang)
		for size in ["normal", "larger"]:
			Prefs.set_text_size(size)
			await _chapters("%s-%s" % [lang, size])
	Prefs.set_text_size("normal")
	Prefs.set_language("uk")
	await _word_and_back()
	await _from_lesson()
	await _kids()
	Prefs.erase_all()
	Prefs.welcome(false)


func _chapters(tag: String) -> void:
	main.open_tab("theory")
	await s._frames(2)
	await s._shot("book-%s-theory" % tag)
	main.open_book()
	await s._frames(2)
	await s._shot("book-%s-contents" % tag)
	for ch in Book.CHAPTERS:
		main.open_chapter(ch["id"])
		await s._frames(2)
		var screen: Control = main.stack.back()
		for l in screen.find_children("*", "RichTextLabel", true, false):
			assert(not (l as RichTextLabel).get_parsed_text().contains("{"), "no markup shows in %s" % ch["id"])
		await s._shot("book-%s-%s" % [tag, ch["id"].to_lower()])
		var scroll: ScrollContainer = main.find_children("*", "ScrollContainer", true, false)[0]
		scroll.scroll_vertical = 1000000
		await s._frames(4)
		await s._shot("book-%s-%s-end" % [tag, ch["id"].to_lower()])
		assert(Book.is_read(ch["id"]), "%s counts as read once its end was on the screen" % ch["id"])
		main.back()
		await s._frames(1)
	main.back()
	await s._frames(2)
	assert(Book.next_unread() == "", "all chapters read")
	Prefs.book_read = []


func _word_and_back() -> void:
	main.open_book()
	main.open_chapter("FPV")
	await s._frames(2)
	var depth: int = main.stack.size()
	main.stack.back()._explain("ARM")
	await s._frames(2)
	await s._shot("book-uk-word")
	main.back()
	await s._frames(2)
	assert(main.stack.size() == depth, "Back closes only the word")
	main.stack.back()._explain("NOT_A_WORD")  # an unknown word opens nothing
	main.back()
	await s._frames(2)
	assert(main.stack.size() == depth - 1, "and then the chapter")
	# "Next" takes the chapter's place, so Back still leads to the contents.
	main.open_chapter("CONTROLS")
	main.open_chapter("CHECKLIST", true)
	assert(main.stack.size() == depth, "next chapter replaces the one before")
	main.back()
	main.back()
	await s._frames(2)


func _from_lesson() -> void:
	main.open_lessons("wing", "WING_STALL")
	await s._frames(3)
	var texts: Array = s._texts(main.stack.back())
	var want := s.tr("BOOK_READ_ABOUT") % [Book.index_of("WING") + 1, s.tr("BOOK_WING_T")]
	assert(texts.has(want), "a lesson offers its chapter")
	await s._shot("book-uk-lesson")
	# Lesson, its chapter, the lesson again: back and forth, the screens do not pile up.
	var depth: int = main.stack.size()
	main.stack.back()._to_chapter("WING")
	await s._frames(2)
	assert(main.stack.size() == depth + 1 and main.stack.back().id == "WING", "the lesson opens its chapter")
	main.stack.back()._to_lesson("wing", "WING_LEVEL")
	await s._frames(2)
	assert(main.stack.size() == depth and main.stack.back().selected == 0, "and the chapter goes back to the lesson")
	main.back()
	await s._frames(2)
	# The last chapter, opened from "Read on": "Back to the contents" leads to the contents.
	main.open_tab("theory")
	main.open_chapter("RULES")
	await s._frames(2)
	main.stack.back()._to_contents()
	await s._frames(2)
	assert(main.stack.size() == 2 and main.stack.back().get_script() == preload("res://scripts/screens/book_contents.gd"),
		"the last chapter leads to the contents")
	main.back()
	await s._frames(2)


func _kids() -> void:
	Prefs.set_mode("kids")
	main.open_tab("theory")
	await s._frames(2)
	await s._shot("book-kids-theory")
	var texts: Array = s._texts(main.stack.back())
	assert(not texts.has(s.tr("BOOK")), "kids get their own little book, not the grown-ups' one")
	main.open_kids_book()
	for n in Book.KIDS_PAGES.size():
		var page: Node = main.stack.back()
		page.page = n
		page.rebuild()
		await s._frames(2)
		for t in s._texts(page):
			assert(not RegEx.create_from_string("\\d").search(t), "no numbers in the kids' book: " + t)
		await s._shot("book-kids-%d" % (n + 1))
	main.back()
	await s._frames(2)
	Prefs.set_mode("simple")
