# SPDX-License-Identifier: GPL-3.0-or-later
extends Screen


func build() -> void:
	add_child(header(tr("SETTINGS")))

	add_child(_looks())
	if Prefs.mode == "kids":
		add_child(_kids_box())

	var lang := UI.vbox(10)
	lang.add_child(UI.eyebrow(tr("SET_LANGUAGE")))
	lang.add_child(UI.segmented([
		["system", tr("LANG_SYSTEM")], ["uk", "Українська"], ["en", "English"],
	], Prefs.language, func(l): Prefs.set_language(l)))
	add_child(lang)

	var size_box := UI.vbox(10)
	size_box.add_child(UI.eyebrow(tr("SET_TEXT_SIZE")))
	size_box.add_child(UI.segmented([
		["normal", tr("SIZE_NORMAL")], ["large", tr("SIZE_LARGE")], ["larger", tr("SIZE_LARGER")],
	], Prefs.text_size, func(v): Prefs.set_text_size(v)))
	add_child(size_box)

	var sound := UI.vbox(10)
	sound.add_child(UI.eyebrow(tr("SET_SOUND")))
	sound.add_child(UI.switch_row(tr("SOUND_ON"), tr("SOUND_DESC"), Prefs.sound,
		func(on): Prefs.set_sound(on)))
	sound.add_child(UI.switch_row(tr("SPEAK_ON"), tr("SPEAK_DESC"), Prefs.speak_hints,
		func(on): Prefs.set_speak_hints(on)))
	add_child(sound)

	# Kids fly with the simple layout always, so the stick choices are for grown-ups only.
	if Prefs.mode != "kids":
		var sticks := UI.vbox(10)
		sticks.add_child(UI.eyebrow(tr("SET_STICKS")))
		sticks.add_child(UI.segmented([["2", "Mode 2"], ["1", "Mode 1"]], Prefs.stick_mode,
			func(v): Prefs.set_stick_mode(v)))
		sticks.add_child(UI.label(tr("STICKS_MODE_DESC"), UI.SMALL, 500, "muted"))
		sticks.add_child(UI.label(tr("STICKS_FEEL"), UI.TEXT, 700))
		sticks.add_child(UI.segmented([
			["normal", tr("FEEL_NORMAL")], ["soft", tr("FEEL_SOFT")], ["softer", tr("FEEL_SOFTER")],
		], Prefs.stick_feel, func(v): Prefs.set_stick_feel(v)))
		sticks.add_child(UI.label(tr("STICKS_FEEL_DESC"), UI.SMALL, 500, "muted"))
		var pad := UI.hbox(12)
		var pt := UI.vbox(2)
		pt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pt.add_child(UI.label(tr("PAD"), UI.LEAD, 700))
		pt.add_child(UI.label(tr("PAD_DESC"), UI.SMALL, 500, "muted"))
		pad.add_child(pt)
		pad.add_child(Glyph.make("chevron", 20, Pal.c("muted")))
		sticks.add_child(UI.tappable(pad, Pal.c("surface"), func(): app.open_pad(), tr("PAD")))
		add_child(sticks)
		var fpv := UI.vbox(10)
		fpv.add_child(UI.eyebrow(tr("SET_FPV")))
		fpv.add_child(UI.label(tr("FPV_RATES"), UI.TEXT, 700))
		fpv.add_child(UI.segmented([
			["soft", tr("RATES_SOFT")], ["medium", tr("RATES_MEDIUM")], ["sharp", tr("RATES_SHARP")],
		], Prefs.fpv_rates, func(v): Prefs.set_choice("fpv_rates", v)))
		fpv.add_child(UI.label(tr("FPV_QUAD"), UI.TEXT, 700))
		fpv.add_child(UI.segmented([["5in", tr("QUAD_5IN")], ["3in", tr("QUAD_3IN")]], Prefs.fpv_quad,
			func(v): Prefs.set_choice("fpv_quad", v)))
		fpv.add_child(UI.label(tr("FPV_QUAD_DESC"), UI.SMALL, 500, "muted"))
		add_child(fpv)

	var kids := UI.vbox(10)
	kids.add_child(UI.eyebrow(tr("SET_KIDS")))
	kids.add_child(UI.switch_row(tr("KIDS_LOCK"), tr("KIDS_LOCK_DESC"), Prefs.kids_lock,
		func(on): Prefs.set_kids_lock(on)))
	add_child(kids)

	_progress_section()

	var row := UI.hbox(14)
	row.add_child(Glyph.make("info", 22, Pal.c("accent_text")))
	var t := UI.label(tr("ABOUT"), UI.LEAD, 700)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(Glyph.make("chevron", 20, Pal.c("muted")))
	add_child(UI.tappable(row, Pal.c("surface"), func(): app.open_about(), tr("ABOUT")))


## Which erase is waiting for "yes": "", "mode" or "all".
var _confirm := ""


## Reset the progress of the mode in use, e.g. so a younger sibling can start fresh. It asks first,
## and can be put back straight after.
func _progress_section() -> void:
	var box := UI.vbox(10)
	box.add_child(UI.eyebrow(tr("SET_PROGRESS")))
	var mode_name := tr("MODE_" + Prefs.mode.to_upper())
	var undo := Prefs.undo_kind()
	if undo != "":
		var col := UI.vbox(10)
		var undone := tr("MODE_" + Prefs.undo_mode().to_upper())
		col.add_child(UI.label(tr("ERASE_DONE") if undo == "all" else tr("RESET_DONE") % undone, UI.BODY, 600))
		col.add_child(UI.primary(tr("RESET_UNDO"), func(): Prefs.undo_reset(); rebuild()))
		box.add_child(UI.panel(col, Pal.c("surface"), 18, 14))
	elif _confirm != "":
		var all := _confirm == "all"
		var col2 := UI.vbox(10)
		col2.add_child(UI.label(tr("ERASE_ASK") if all else tr("RESET_ASK") % mode_name, UI.BODY, 600))
		var r := UI.hbox(10)
		var yes_text := tr("ERASE_YES") if all else tr("RESET_YES")
		var yes := CenterContainer.new()
		yes.custom_minimum_size = Vector2(0, 52)
		yes.add_child(UI.label(yes_text, UI.TEXT, 800, "on_accent", false, false))
		var y := UI.tappable(yes, Pal.c("accent"), confirm_erase, yes_text, 16, 0)
		y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(y)
		var no := CenterContainer.new()
		no.custom_minimum_size = Vector2(0, 52)
		no.add_child(UI.label(tr("CANCEL"), UI.TEXT, 700, "text", false, false))
		var n := UI.tappable(no, Pal.c("surface2"), func(): _confirm = ""; rebuild(), tr("CANCEL"), 16, 0)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(n)
		col2.add_child(r)
		box.add_child(UI.panel(col2, Pal.c("surface"), 18, 14))
	else:
		box.add_child(_action_row(tr("RESET_PROGRESS") % mode_name, Prefs.has_progress(), "mode"))
		box.add_child(_action_row(tr("ERASE_ALL"), true, "all"))
	add_child(box)


## "Yes" on the question: erase what was asked about.
func confirm_erase() -> void:
	if _confirm == "all":
		Prefs.erase_all()
	elif _confirm == "mode":
		Prefs.reset_progress()
	_confirm = ""
	rebuild()


func _action_row(text: String, active: bool, kind: String) -> Control:
	var row := UI.hbox(12)
	var t := UI.label(text, UI.LEAD, 700, "text" if active else "muted")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	if not active:
		return UI.panel(row, Pal.c("surface"), 18, 14)
	return UI.tappable(row, Pal.c("surface"), func(): _confirm = kind; rebuild(), text)


## The six looks: light ones above, their dark pairs below, each shown in its own colours. Kids
## choose among the light ones; "Follow the system" switches within the pair.
func _looks() -> Control:
	var look := UI.vbox(10)
	look.add_child(UI.eyebrow(tr("SET_THEME")))
	var kids := Prefs.mode == "kids"
	var rows := [["day", "sky", "mallow"]] if kids else [["day", "sky", "mallow"], ["dusk", "starry", "seanight"]]
	var chosen := Pal.light_of(Prefs.theme) if kids else Prefs.theme
	for row in rows:
		var line := UI.hbox(8)
		for t in row:
			line.add_child(_look_tile(t, t == chosen or (kids and Pal.light_of(Prefs.theme) == t)))
		look.add_child(line)
	if kids:
		look.add_child(UI.label(tr("THEME_KIDS_NOTE"), UI.SMALL, 500, "muted"))
	else:
		look.add_child(UI.switch_row(tr("THEME_SYSTEM"), tr("THEME_SYSTEM_DESC"), Prefs.theme_system,
			func(on): Prefs.set_theme_system(on)))
	return look


func _look_tile(t: String, on: bool) -> Control:
	var th: Dictionary = Pal.THEMES[Pal.KIDS_LOOK.get(t, t) if Prefs.mode == "kids" else t]
	var col := UI.vbox(6)
	var name_ := UI.label(tr("THEME_" + t.to_upper()), UI.SMALL, 700, "text", false, false)
	name_.add_theme_color_override("font_color", th["text"])
	name_.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_)
	var sw := UI.hbox(4)
	for k in ["accent_text", "accent"]:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.add_theme_stylebox_override("panel", UI.box(th[k], 8, 0))
		sw.add_child(dot)
	col.add_child(sw)
	var tile := UI.tappable(col, th["bg"], func(): Prefs.set_theme(_pair_for(t)), tr("THEME_" + t.to_upper()), 14, 10,
		false, Pal.c("focus") if on else th["line"])
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return tile


## Kids pick a light look; the grown-up's dark choice of the same pair stays theirs.
func _pair_for(t: String) -> String:
	if Prefs.mode == "kids" and Pal.light_of(Prefs.theme) == t:
		return Prefs.theme
	return t


## Kids mode, for grown-ups (settings are behind the lock): the children on this phone, and the
## reminder to take a break.
func _kids_box() -> Control:
	var box := UI.vbox(10)
	box.add_child(UI.eyebrow(tr("SET_KIDS")))
	var row := UI.hbox(12)
	var t := UI.vbox(2)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(UI.label(tr("PILOTS"), UI.LEAD, 700))
	t.add_child(UI.label(tr("PILOTS_DESC"), UI.SMALL, 500, "muted"))
	row.add_child(t)
	row.add_child(Glyph.make("chevron", 20, Pal.c("muted")))
	box.add_child(UI.tappable(row, Pal.c("surface"), func(): app.open_pilots(), tr("PILOTS")))
	box.add_child(UI.switch_row(tr("BREAK_ON"), tr("BREAK_DESC"), Prefs.break_reminder,
		func(on): Prefs.set_break_reminder(on)))
	return box
