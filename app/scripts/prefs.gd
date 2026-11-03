# SPDX-License-Identifier: GPL-3.0-or-later
# Settings and progress. Stored only on the phone, in one small file.
extends Node

signal changed

const PATH := "user://prefs.cfg"
const MODES := ["kids", "simple", "pro"]
const THEMES := ["dusk", "day", "system"]
const LANGUAGES := ["system", "uk", "en"]

var mode := "simple"
var theme := "dusk"
var language := "system"
## Lessons passed per vehicle, in order: {"camera": 3, ...}
var passed := {}


func _ready() -> void:
	_load()
	_apply_language()
	Pal.apply(theme)


func set_mode(value: String) -> void:
	if value in MODES and value != mode:
		mode = value
		_save()
		changed.emit()


func set_theme(value: String) -> void:
	if value in THEMES and value != theme:
		theme = value
		_save()
		Pal.apply(theme)


func set_language(value: String) -> void:
	if value in LANGUAGES and value != language:
		language = value
		_save()
		_apply_language()
		changed.emit()


func passed_count(vehicle: String) -> int:
	return int(passed.get(vehicle, 0))


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
	var p = cfg.get_value("progress", "passed", {})
	if p is Dictionary:
		for k in p.keys():
			if k is String and k in Curriculum.VEHICLES and (p[k] is int):
				passed[k] = clampi(p[k], 0, Curriculum.lessons(k).size())


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("prefs", "mode", mode)
	cfg.set_value("prefs", "theme", theme)
	cfg.set_value("prefs", "language", language)
	cfg.set_value("progress", "passed", passed)
	cfg.save(PATH)
