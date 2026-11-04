# SPDX-License-Identifier: GPL-3.0-or-later
# Settings and progress. Stored only on the phone, in one small JSON file.
# JSON holds only plain values, so a damaged or crafted file can never create objects or run code;
# everything read from it is checked against what the app knows and the rest is ignored.
extends Node

signal changed

const PATH := "user://prefs.json"
## Versions up to 0.5 used Godot's ConfigFile; it is read once, carefully, and then removed.
const OLD_PATH := "user://prefs.cfg"
const MAX_BYTES := 65536
const MODES := ["kids", "simple", "pro"]
const THEMES := ["dusk", "day", "system"]
const LANGUAGES := ["system", "uk", "en"]
const VIEWS := ["pilot", "chase", "drone", "fpv", "ugv"]
const TEXT_SIZES := {"normal": 1.0, "large": 1.15, "larger": 1.3}

var mode := "simple"
## The theme the grown-up chose. Kids mode shows "morning" instead, without changing this.
var theme := "dusk"
var language := "system"
var text_size := "normal"
## Leaving Kids mode or opening settings needs a sum solved.
var kids_lock := false
## Lessons passed, per mode and vehicle, in order: {"kids": {"camera": 3}, ...}
var passed := {}
## Missions done, per mode: {"pro": ["MIS_CAM_SEARCH"], ...}
var missions := {}
## Camera per mode and vehicle: {"kids/camera": "chase", ...}
var views := {}

## What was just erased, so it can be put back: {"mode", "passed", "missions"} or {"all": saved data}.
var _undo := {}


func _ready() -> void:
	_load()
	_apply_language()
	_apply_theme()


## Tests keep their own file, so they never touch a real pilot's progress.
func path() -> String:
	var p := OS.get_environment("SHYRIAI_PREFS")
	return p if p != "" else PATH


func set_mode(value: String) -> void:
	if value in MODES and value != mode:
		mode = value
		_undo = {}
		_save()
		_apply_theme()
		changed.emit()


func set_theme(value: String) -> void:
	if value in THEMES and value != theme:
		theme = value
		_undo = {}
		_save()
		_apply_theme()


func set_language(value: String) -> void:
	if value in LANGUAGES and value != language:
		language = value
		_undo = {}
		_save()
		_apply_language()
		changed.emit()


func set_text_size(value: String) -> void:
	if TEXT_SIZES.has(value) and value != text_size:
		text_size = value
		_undo = {}
		_save()
		_apply_theme()


func set_kids_lock(on: bool) -> void:
	if on != kids_lock:
		kids_lock = on
		_undo = {}
		_save()
		changed.emit()


## Each mode keeps its own progress: a child's lessons are not a grown-up's.
func passed_count(vehicle: String, m := "") -> int:
	var md := m if m != "" else mode
	var n := int(passed.get(md, {}).get(vehicle, 0))
	return clampi(n, 0, Curriculum.lessons(vehicle, md).size())


## A lesson counts once the ones before it are passed too.
func mark_passed(vehicle: String, index: int) -> void:
	if index < 0:
		return
	var n := passed_count(vehicle)
	if index + 1 > n and index <= n:
		if not passed.has(mode):
			passed[mode] = {}
		passed[mode][vehicle] = index + 1
		_undo = {}
		_save()


func mission_done(key: String) -> bool:
	return key in missions.get(mode, [])


func mark_mission(key: String) -> void:
	if not mission_done(key):
		if not missions.has(mode):
			missions[mode] = []
		missions[mode].append(key)
		_undo = {}
		_save()


func has_progress() -> bool:
	return not passed.get(mode, {}).is_empty() or not missions.get(mode, []).is_empty()


## Clears the lessons and missions of the mode in use. undo_reset() puts them back.
func reset_progress() -> void:
	_undo = {"mode": mode, "passed": passed.get(mode, {}).duplicate(), "missions": missions.get(mode, []).duplicate()}
	passed.erase(mode)
	missions.erase(mode)
	_save()
	changed.emit()


## Erases everything: progress in every mode and all settings, as if just installed.
## undo_reset() puts it all back.
func erase_all() -> void:
	_undo = {"all": _data()}
	DirAccess.remove_absolute(OLD_PATH)
	mode = "simple"
	theme = "dusk"
	language = "system"
	text_size = "normal"
	kids_lock = false
	passed = {}
	missions = {}
	views = {}
	_save()
	_apply_language()
	_apply_theme()
	changed.emit()


## The mode whose progress "Undo" would bring back.
func undo_mode() -> String:
	return str(_undo.get("mode", mode))


func undo_kind() -> String:
	return "" if _undo.is_empty() else ("all" if _undo.has("all") else "mode")


func can_undo_reset() -> bool:
	return not _undo.is_empty()


func undo_reset() -> void:
	if _undo.is_empty():
		return
	if _undo.has("all"):
		_apply(_undo["all"])
		_apply_language()
		_apply_theme()
	else:
		passed[_undo["mode"]] = _undo["passed"]
		missions[_undo["mode"]] = _undo["missions"]
	_undo = {}
	_save()
	changed.emit()


## The FPV drone is flown through its own camera. With the camera drone, kids follow it from
## behind and everyone else sees it as a pilot on the ground does. Kept per mode and vehicle.
func view_for(m: String, vehicle := "camera") -> String:
	var fallback := "fpv" if vehicle == "fpv" else ("chase" if m == "kids" else ("ugv" if vehicle == "ugv" else "pilot"))
	return views.get(m + "/" + vehicle, fallback)


func set_view(m: String, vehicle: String, v: String) -> void:
	if v in VIEWS and m in MODES and vehicle in Curriculum.VEHICLES:
		views[m + "/" + vehicle] = v
		_save()


func _apply_theme() -> void:
	Pal.apply("morning" if mode == "kids" else theme, TEXT_SIZES.get(text_size, 1.0))


func _apply_language() -> void:
	var lang := language
	if lang == "system":
		lang = "uk" if OS.get_locale_language() == "uk" else "en"
	TranslationServer.set_locale(lang)


# --- Reading and writing ---------------------------------------------------------

func _load() -> void:
	var data = _read_json(path())
	if data == null and path() == PATH:
		data = _read_old_config()
		if data != null:
			_apply(data)
			# The old file goes only once its contents are safely in the new one.
			if _save():
				DirAccess.remove_absolute(OLD_PATH)
			return
		# A refused or unreadable old file is not kept either.
		DirAccess.remove_absolute(OLD_PATH)
	if data is Dictionary:
		_apply(data)


func _read_json(p: String):
	if not FileAccess.file_exists(p):
		return null
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null or f.get_length() > MAX_BYTES:
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else null


## The old ConfigFile format can describe engine objects; such a file is refused, not parsed.
func _read_old_config():
	if not FileAccess.file_exists(OLD_PATH):
		return null
	var f := FileAccess.open(OLD_PATH, FileAccess.READ)
	if f == null or f.get_length() > MAX_BYTES:
		return null
	var text := f.get_as_text()
	var rx := RegEx.create_from_string("(Object|Resource|ExtResource|SubResource)\\s*\\(")
	if rx.search(text) != null:
		return null
	var cfg := ConfigFile.new()
	if cfg.parse(text) != OK:
		return null
	var out := {}
	# Older files may lack some keys; asking for a missing key without a default logs an error.
	for k in ["mode", "theme", "language", "kids_lock", "views"]:
		if cfg.has_section_key("prefs", k):
			out[k] = cfg.get_value("prefs", k)
	for k in ["passed", "missions"]:
		if cfg.has_section_key("progress", k):
			out[k] = cfg.get_value("progress", k)
	return out


## Takes only what the app knows; anything else in the file is ignored.
func _apply(d: Dictionary) -> void:
	var m = d.get("mode")
	if m is String and m in MODES:
		mode = m
	var t = d.get("theme")
	if t is String and t in THEMES:
		theme = t
	var l = d.get("language")
	if l is String and l in LANGUAGES:
		language = l
	var ts = d.get("text_size")
	if ts is String and TEXT_SIZES.has(ts):
		text_size = ts
	var k = d.get("kids_lock")
	if k is bool:
		kids_lock = k
	var v = d.get("views")
	if v is Dictionary:
		for key in v.keys():
			if key is String and key.count("/") == 1 and key.get_slice("/", 0) in MODES \
					and key.get_slice("/", 1) in Curriculum.VEHICLES and v[key] is String and v[key] in VIEWS:
				views[key] = v[key]
	var p = d.get("passed")
	if p is Dictionary:
		for key in p.keys():
			if key is String and key in MODES and p[key] is Dictionary:
				passed[key] = _read_counts(p[key], key)
			elif key is String and key in Curriculum.VEHICLES:
				# Version 0.3 and earlier kept one progress for all modes: it goes to the mode in use.
				if not passed.has(mode):
					passed[mode] = {}
				passed[mode].merge(_read_counts({key: p[key]}, mode), true)
	var md = d.get("missions")
	if md is Array:
		missions[mode] = _read_missions(md)
	elif md is Dictionary:
		for key in md.keys():
			if key is String and key in MODES and md[key] is Array:
				missions[key] = _read_missions(md[key])


func _read_counts(d: Dictionary, m: String) -> Dictionary:
	var out := {}
	for v in d.keys():
		var n = d[v]
		# JSON numbers arrive as floats.
		if v is String and v in Curriculum.VEHICLES and (n is int or (n is float and is_finite(n))):
			out[v] = clampi(int(n), 0, Curriculum.lessons(v, m).size())
	return out


func _read_missions(list: Array) -> Array:
	var known := {}
	for v in Curriculum.VEHICLES:
		for m in Curriculum.missions(v, "kids") + Curriculum.missions(v, "simple"):
			known[m] = true
	var out := []
	for key in list:
		if key is String and known.has(key) and key not in out:
			out.append(key)
	return out


func _data() -> Dictionary:
	return {
		"version": 1, "mode": mode, "theme": theme, "language": language, "text_size": text_size,
		"kids_lock": kids_lock, "views": views.duplicate(true), "passed": passed.duplicate(true),
		"missions": missions.duplicate(true),
	}


## Writes a whole new file and then swaps it in, so a phone switching off mid-write
## can never leave half a file. Returns false if it could not be written.
func _save() -> bool:
	var tmp := path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(_data(), "\t"))
	f.close()
	return DirAccess.rename_absolute(tmp, path()) == OK
