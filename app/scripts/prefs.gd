# SPDX-License-Identifier: GPL-3.0-or-later
# Settings and progress. Stored only on the phone, in one small file.
extends Node

signal changed

const PATH := "user://prefs.cfg"
const MODES := ["kids", "simple", "pro"]
const THEMES := ["dusk", "day", "system"]
const LANGUAGES := ["system", "uk", "en"]
const VIEWS := ["pilot", "chase", "drone", "fpv"]

var mode := "simple"
## The theme the grown-up chose. Kids mode shows "morning" instead, without changing this.
var theme := "dusk"
var language := "system"
## Leaving Kids mode or opening settings needs a sum solved.
var kids_lock := false
## Lessons passed, per mode and vehicle, in order: {"kids": {"camera": 3}, ...}
var passed := {}
## Missions done, per mode: {"pro": ["MIS_CAM_SEARCH"], ...}
var missions := {}
## Camera per mode: {"kids": "chase", ...}
var views := {}


func _ready() -> void:
	_load()
	_apply_language()
	_apply_theme()


func set_mode(value: String) -> void:
	if value in MODES and value != mode:
		mode = value
		_save()
		_apply_theme()
		changed.emit()


func set_theme(value: String) -> void:
	if value in THEMES and value != theme:
		theme = value
		_save()
		_apply_theme()


func set_language(value: String) -> void:
	if value in LANGUAGES and value != language:
		language = value
		_save()
		_apply_language()
		changed.emit()


func set_kids_lock(on: bool) -> void:
	if on != kids_lock:
		kids_lock = on
		_save()
		changed.emit()


## Each mode keeps its own progress: a child's lessons are not a grown-up's.
func passed_count(vehicle: String, m := "") -> int:
	return int(passed.get(m if m != "" else mode, {}).get(vehicle, 0))


## A lesson counts once the ones before it are passed too.
func mark_passed(vehicle: String, index: int) -> void:
	if index < 0:
		return
	var n := passed_count(vehicle)
	if index + 1 > n and index <= n:
		if not passed.has(mode):
			passed[mode] = {}
		passed[mode][vehicle] = index + 1
		_save()


func mission_done(key: String) -> bool:
	return key in missions.get(mode, [])


func mark_mission(key: String) -> void:
	if not mission_done(key):
		if not missions.has(mode):
			missions[mode] = []
		missions[mode].append(key)
		_save()


## The FPV drone is flown through its own camera. With the camera drone, kids follow it from
## behind and everyone else sees it as a pilot on the ground does. Kept per mode and vehicle.
func view_for(m: String, vehicle := "camera") -> String:
	var fallback := "fpv" if vehicle == "fpv" else ("chase" if m == "kids" else "pilot")
	return views.get(m + "/" + vehicle, fallback)


func set_view(m: String, vehicle: String, v: String) -> void:
	if v in VIEWS and m in MODES and vehicle in Curriculum.VEHICLES:
		views[m + "/" + vehicle] = v
		_save()


func _apply_theme() -> void:
	Pal.apply("morning" if mode == "kids" else theme)


func _apply_language() -> void:
	var lang := language
	if lang == "system":
		lang = "uk" if OS.get_locale_language() == "uk" else "en"
	TranslationServer.set_locale(lang)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	# Anything unexpected in the file is ignored, never trusted.
	var m = cfg.get_value("prefs", "mode", mode)
	if m is String and m in MODES:
		mode = m
	var t = cfg.get_value("prefs", "theme", theme)
	if t is String and t in THEMES:
		theme = t
	var l = cfg.get_value("prefs", "language", language)
	if l is String and l in LANGUAGES:
		language = l
	var k = cfg.get_value("prefs", "kids_lock", false)
	if k is bool:
		kids_lock = k
	var v = cfg.get_value("prefs", "views", {})
	if v is Dictionary:
		for key in v.keys():
			if key is String and key.get_slice("/", 0) in MODES and key.get_slice("/", 1) in Curriculum.VEHICLES \
					and v[key] is String and v[key] in VIEWS:
				views[key] = v[key]
	var p = cfg.get_value("progress", "passed", {})
	if p is Dictionary:
		for key in p.keys():
			if key is String and key in MODES and p[key] is Dictionary:
				passed[key] = _read_counts(p[key])
			elif key is String and key in Curriculum.VEHICLES:
				# Version 0.3 and earlier kept one progress for all modes: it goes to the mode in use.
				if not passed.has(mode):
					passed[mode] = {}
				passed[mode].merge(_read_counts({key: p[key]}), true)
	var md = cfg.get_value("progress", "missions", {})
	if md is Array:
		missions[mode] = _read_missions(md)
	elif md is Dictionary:
		for key in md.keys():
			if key is String and key in MODES and md[key] is Array:
				missions[key] = _read_missions(md[key])


func _read_counts(d: Dictionary) -> Dictionary:
	var out := {}
	for v in d.keys():
		if v is String and v in Curriculum.VEHICLES and d[v] is int:
			out[v] = clampi(d[v], 0, Curriculum.lessons(v).size())
	return out


func _read_missions(list: Array) -> Array:
	var out := []
	for key in list:
		if key is String and key.begins_with("MIS_") and key.length() < 40 and key not in out:
			out.append(key)
	return out


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("prefs", "mode", mode)
	cfg.set_value("prefs", "theme", theme)
	cfg.set_value("prefs", "language", language)
	cfg.set_value("prefs", "kids_lock", kids_lock)
	cfg.set_value("prefs", "views", views)
	cfg.set_value("progress", "passed", passed)
	cfg.set_value("progress", "missions", missions)
	cfg.save(PATH)
