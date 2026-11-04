# SPDX-License-Identifier: GPL-3.0-or-later
# Settings and progress. Stored only on the phone, in one small file.
extends Node

signal changed

const PATH := "user://prefs.cfg"
const MODES := ["kids", "simple", "pro"]
const THEMES := ["dusk", "day", "system"]
const LANGUAGES := ["system", "uk", "en"]
const VIEWS := ["pilot", "chase"]

var mode := "simple"
## The theme the grown-up chose. Kids mode shows "morning" instead, without changing this.
var theme := "dusk"
var language := "system"
## Leaving Kids mode or opening settings needs a sum solved.
var kids_lock := false
## Lessons passed per vehicle, in order: {"camera": 3, ...}
var passed := {}
var missions_done: Array[String] = []
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


func passed_count(vehicle: String) -> int:
	return int(passed.get(vehicle, 0))


## A lesson counts once the ones before it are passed too.
func mark_passed(vehicle: String, index: int) -> void:
	if index < 0:
		return
	if index + 1 > passed_count(vehicle) and index <= passed_count(vehicle):
		passed[vehicle] = index + 1
		_save()


func mark_mission(key: String) -> void:
	if key not in missions_done:
		missions_done.append(key)
		_save()


## Kids follow the drone from behind; everyone else sees it as a pilot on the ground does.
func view_for(m: String) -> String:
	return views.get(m, "chase" if m == "kids" else "pilot")


func set_view(m: String, v: String) -> void:
	if v in VIEWS and m in MODES:
		views[m] = v
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
			if key is String and key in MODES and v[key] is String and v[key] in VIEWS:
				views[key] = v[key]
	var p = cfg.get_value("progress", "passed", {})
	if p is Dictionary:
		for key in p.keys():
			if key is String and key in Curriculum.VEHICLES and (p[key] is int):
				passed[key] = clampi(p[key], 0, Curriculum.lessons(key).size())
	var md = cfg.get_value("progress", "missions", [])
	if md is Array:
		for key in md:
			if key is String and key.begins_with("MIS_") and key.length() < 40 and key not in missions_done:
				missions_done.append(key)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("prefs", "mode", mode)
	cfg.set_value("prefs", "theme", theme)
	cfg.set_value("prefs", "language", language)
	cfg.set_value("prefs", "kids_lock", kids_lock)
	cfg.set_value("prefs", "views", views)
	cfg.set_value("progress", "passed", passed)
	cfg.set_value("progress", "missions", missions_done)
	cfg.save(PATH)
