# SPDX-License-Identifier: GPL-3.0-or-later
# The report after a survey: one picture at a time, with its question, decided on the ground, as real
# operators do. Afterwards the result card lists the pictures read wrong. `f` is the flight screen.
class_name Report
extends RefCounted

const THUMB := Vector2(320, 180)


## The card for the first question not answered yet.
static func card(f, task: PhotoTask) -> Control:
	var i := 0
	while i < task.report.size() and task.report[i].has("given"):
		i += 1
	var item: Dictionary = task.report[i]
	var col := UI.vbox(10)
	col.add_child(UI.label(f.tr("REPORT_N") % [i + 1, task.report.size()], UI.TITLE_S, 600, "text", true))
	col.add_child(picture(task.photos[item["photo"]].get("image"), THUMB))
	col.add_child(UI.label(f.tr(item["prompt"]), UI.TEXT, 700, "text"))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	for opt in item["options"]:
		var id: String = opt[0]
		var c := CenterContainer.new()
		c.custom_minimum_size = Vector2(130, 46)
		c.add_child(UI.label(_option(f, opt[1]), UI.TEXT, 800, "on_accent", false, false))
		row.add_child(UI.tappable(c, Pal.c("accent"), func(): f.report_answer(i, id), _option(f, opt[1]), 14, 0))
	col.add_child(row)
	return col


## The pictures read wrong: what the pilot said and what was there.
static func mistakes(f, task: PhotoTask) -> Control:
	var col := UI.vbox(8)
	for j in task.wrong:
		var item: Dictionary = task.report[j]
		var row := UI.hbox(10)
		var pic := picture(task.photos[item["photo"]].get("image"), Vector2(96, 54))
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pic)
		var said := _label_of(f, item, item["given"])
		var truth := _label_of(f, item, item["answer"])
		var l := UI.label(f.tr("REPORT_WRONG") % [j + 1, said, truth], UI.SMALL, 600, "text")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		col.add_child(row)
	return col


## A taken picture, or a plain frame where there is none (tests without a screen).
static func picture(img: Image, px: Vector2) -> Control:
	if img == null or img.is_empty():
		var c := CenterContainer.new()
		c.custom_minimum_size = px
		c.add_child(Glyph.make("photo", minf(px.y * 0.4, 40.0), Pal.c("muted")))
		return UI.panel(c, Pal.c("surface2"), 10, 0)
	var t := TextureRect.new()
	t.texture = ImageTexture.create_from_image(img)
	t.custom_minimum_size = px
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return t


## Options are translation keys, or plain numbers for counting.
static func _option(f, text: String) -> String:
	return text if text.is_valid_int() else f.tr(text)


static func _label_of(f, item: Dictionary, id: String) -> String:
	for opt in item["options"]:
		if opt[0] == id:
			return _option(f, opt[1])
	return id
