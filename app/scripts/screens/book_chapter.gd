# SPDX-License-Identifier: GPL-3.0-or-later
# One chapter of the pilot's book: the text, a drawing, the words it uses from the glossary (a tap
# explains them), the theory card's short points and questions, and the lesson to try it in.
# The chapter counts as read once its end has been on the screen.
extends Screen

var id := ""
## The answer picked for each question of "Check yourself", while this chapter is open.
var picked := {}
## A word's explanation, open over the chapter.
var _pop: CanvasLayer
var _end: Control


func build() -> void:
	var i := Book.index_of(id)
	var ch: Dictionary = Book.CHAPTERS[i]
	add_child(header(tr("BOOK_%s_T" % id), tr("BOOK_CHAPTER") % [i + 1, Book.CHAPTERS.size()]))
	var body := tr("BOOK_%s_BODY" % id)
	var text := UI.vbox(14)
	var paras := body.split("|")
	for k in paras.size():
		text.add_child(_para(paras[k]))
		if k == 0 and ch["fig"] != "":
			text.add_child(UI.panel(BookFigure.make(ch["fig"]), Pal.c("surface2"), 16, 12))
	add_child(UI.panel(text, Pal.c("surface"), 22, 18))
	var card: String = ch["card"]
	if card != "" and ch.get("short", true):
		var short := UI.vbox(10)
		short.add_child(UI.eyebrow(tr("BOOK_SHORT")))
		short.add_child(UI.points(tr(card + "_BODY")))
		add_child(UI.panel(short, Pal.c("surface"), 22, 18))
	_words(body)
	if card != "" and tr(card + "_SOURCES") != card + "_SOURCES":
		var v := UI.vbox(6)
		v.add_child(UI.eyebrow(tr("SOURCES")))
		v.add_child(UI.label(tr(card + "_SOURCES"), UI.SMALL, 500, "muted"))
		add_child(v)
	if card != "":
		add_child(Quiz.panel(card, picked, rebuild))
	_ways_on(i, ch)


func _para(p: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.meta_underlined = true
	r.add_theme_font_override("normal_font", Pal.font(500))
	r.add_theme_font_size_override("normal_font_size", roundi(UI.LEAD * Pal.text_scale()))
	r.add_theme_color_override("default_color", Pal.c("text"))
	r.add_theme_constant_override("line_separation", roundi(4 * Pal.text_scale()))
	r.text = Book.bbcode(p.strip_edges(), Pal.c("accent_text"))
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.meta_clicked.connect(func(term): _explain(str(term)))
	return r


## The chapter's glossary words as buttons too: easy to find again, and reachable without touch.
func _words(body: String) -> void:
	var terms := Book.terms(body)
	if terms.is_empty():
		return
	var col := UI.vbox(8)
	col.add_child(UI.eyebrow(tr("BOOK_WORDS")))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for t in terms:
		var term: String = t
		var title := tr("GL_%s_T" % term)
		flow.add_child(UI.tappable(UI.label(title, UI.SMALL, 700, "text", false, false), Pal.c("surface2"),
			func(): _explain(term), title, 12, 9))
	col.add_child(flow)
	add_child(col)


## The lesson to try it in, and the next chapter.
func _ways_on(i: int, ch: Dictionary) -> void:
	var col := UI.vbox(8)
	var go: Array = ch["try"]
	if not go.is_empty() and Prefs.mode != "kids":
		col.add_child(UI.label(tr("BOOK_TRY_IN") % Curriculum.label(go[1]), UI.SMALL, 600, "muted"))
		col.add_child(UI.primary(tr("BOOK_TRY"), func(): _to_lesson(go[0], go[1]), "play"))
	if i + 1 < Book.CHAPTERS.size():
		var nxt: String = Book.CHAPTERS[i + 1]["id"]
		col.add_child(UI.secondary(tr("BOOK_NEXT") % [i + 2, tr("BOOK_%s_T" % nxt)], func(): app.open_chapter(nxt, true)))
	else:
		col.add_child(UI.secondary(tr("BOOK_TO_CONTENTS"), _to_contents))
	_end = col
	add_child(col)


## Opened from that course's lessons: back to them, so screens do not pile up.
func _to_lesson(vehicle: String, key: String) -> void:
	var below = app.stack[-2] if app.stack.size() > 1 else null
	if below != null and below.get("vehicle") == vehicle:
		app.back()
		below.selected = Curriculum.lessons(vehicle, Prefs.mode).find(key)
		below.show_lesson()
		below.rebuild()
	else:
		app.open_lessons(vehicle, key)


## The contents, wherever this chapter was opened from.
func _to_contents() -> void:
	var below = app.stack[-2] if app.stack.size() > 1 else null
	if below != null and below.get_script() == preload("res://scripts/screens/book_contents.gd"):
		app.back()
	else:
		app.open_book(true)


func _process(_delta: float) -> void:
	# Read once the end has been on the screen.
	if is_instance_valid(_end) and _end.is_visible_in_tree() and not Book.is_read(id):
		if get_viewport_rect().intersects(_end.get_global_rect()):
			Book.mark_read(id)


func _explain(term: String) -> void:
	if tr("GL_%s_T" % term) == "GL_%s_T" % term:
		return  # not a glossary word: nothing to show
	close_overlay()
	var cover := Control.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.add_child(shade)
	var close := Button.new()
	close.flat = true
	close.set_anchors_preset(Control.PRESET_FULL_RECT)
	close.set("accessibility_name", tr("CLOSE"))
	cover.add_child(close)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := UI.vbox(6)
	col.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 56.0, 460.0), 0)
	col.add_child(UI.label(tr("GL_%s_T" % term), UI.LEAD, 700, "bg"))
	col.add_child(UI.label(tr("GL_" + term), UI.TEXT, 500, "bg"))
	col.add_child(UI.label(tr("BOOK_TAP_CLOSE"), UI.SMALL, 500, "bg"))
	var card := UI.panel(col, Pal.c("text"), 16, 16)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(card)
	cover.add_child(center)
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(cover)
	close.pressed.connect(layer.queue_free)
	add_child(layer)
	_pop = layer
	close.grab_focus.call_deferred()  # a screen reader or keyboard lands on the explanation


## Back with a word open closes only the word.
func close_overlay() -> bool:
	if is_instance_valid(_pop) and not _pop.is_queued_for_deletion():
		_pop.queue_free()
		return true
	return false
