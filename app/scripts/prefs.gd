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
const TEXT_SIZES := {"normal": 1.0, "large": 1.2, "larger": 1.5}
## Mode 2: throttle on the left stick (most radios). Mode 1: throttle on the right.
const STICK_MODES := ["2", "1"]
## How much softer the sticks are near the centre (expo): 0 is the plain, straight response.
const STICK_FEELS := {"normal": 0.0, "soft": 0.3, "softer": 0.55}
## Free flight choices. Kids fly without wind; only Adult chooses the FPV flight mode.
const FREE_WINDS := ["none", "light", "gusty"]
const FREE_TIMES := ["day", "dusk", "fog", "winter"]
## Kids fly in daylight: a clear day or a snowy one.
const FREE_TIMES_KIDS := ["day", "winter"]
const FREE_FPV := ["angle", "horizon", "acro"]
## Long enough for any real name, short enough to fit the licence card.
const NAME_MAX := 32
## Longer than any flight can last: a bigger time in a saved file is not trusted.
const MAX_SECONDS := 3600.0

## A fresh install, and what "Erase all data" goes back to.
const DEFAULTS := {
	"mode": "simple", "theme": "dusk", "language": "system", "text_size": "normal",
	"welcomed": false, "kids_lock": false, "sound": true, "stick_mode": "2", "stick_feel": "normal", "pilot_name": "",
	"free": {"wind": "none", "time": "day", "balls": true, "fpv": "angle"},
}

var mode: String = DEFAULTS["mode"]
## The theme the grown-up chose. Kids mode shows "morning" instead, without changing this.
var theme: String = DEFAULTS["theme"]
var language: String = DEFAULTS["language"]
var text_size: String = DEFAULTS["text_size"]
## The first-run question "Who will play?" has been answered.
var welcomed: bool = DEFAULTS["welcomed"]
## Leaving Kids mode or opening settings needs a sum solved.
var kids_lock: bool = DEFAULTS["kids_lock"]
var sound: bool = DEFAULTS["sound"]
var stick_mode: String = DEFAULTS["stick_mode"]
var stick_feel: String = DEFAULTS["stick_feel"]
## The name on the pilot's licence: optional, kept only on this phone.
var pilot_name: String = DEFAULTS["pilot_name"]
var free: Dictionary = DEFAULTS["free"].duplicate()
## Best result per mode and task: {"simple": {"CAM_TAKEOFF": {"f": 2, "t": 14.5}}}.
## "f" = most sunflowers, "t" = shortest time of a pass, each kept on its own.
var best := {}
## When each vehicle's lessons were all passed, per mode: {"pro": {"camera": "2026-11-06"}}.
var licences := {}
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


## The answer to the first-run question: a child gets Kids mode with the grown-ups' lock on,
## a grown-up gets Simple mode. Either can be changed later.
func welcome(child: bool) -> void:
	welcomed = true
	mode = "kids" if child else "simple"
	kids_lock = child
	_undo = {}
	_save()
	_apply_theme()
	changed.emit()


func set_kids_lock(on: bool) -> void:
	if on != kids_lock:
		kids_lock = on
		_undo = {}
		_save()
		changed.emit()


func set_sound(on: bool) -> void:
	if on != sound:
		sound = on
		_undo = {}
		_save()
		changed.emit()


func set_stick_mode(value: String) -> void:
	if value in STICK_MODES and value != stick_mode:
		stick_mode = value
		_undo = {}
		_save()
		changed.emit()


func set_stick_feel(value: String) -> void:
	if STICK_FEELS.has(value) and value != stick_feel:
		stick_feel = value
		_undo = {}
		_save()
		changed.emit()


func set_pilot_name(value: String) -> void:
	var clean := _clean_name(value)
	if clean != pilot_name:
		pilot_name = clean
		_undo = {}
		_save()


func set_free(key: String, value) -> void:
	var ok: bool = {
		"wind": value in FREE_WINDS, "time": value in FREE_TIMES, "fpv": value in FREE_FPV,
		"balls": value is bool,
	}.get(key, false)
	if ok and free[key] != value:
		free[key] = value
		_undo = {}
		_save()
		changed.emit()


## Keeps the best of each: the most sunflowers and the quickest pass. Returns what was there before.
func record(key: String, flowers: int, seconds: float) -> Dictionary:
	if not best.has(mode):
		best[mode] = {}
	var before: Dictionary = best[mode].get(key, {}).duplicate()
	var now := {
		"f": maxi(int(before.get("f", 0)), clampi(flowers, 1, Rating.MAX)),
		"t": minf(float(before.get("t", MAX_SECONDS)), clampf(seconds, 0.0, MAX_SECONDS)),
	}
	best[mode][key] = now
	_undo = {}
	_save()
	return before


func best_of(key: String, m := "") -> Dictionary:
	return best.get(m if m != "" else mode, {}).get(key, {})


## The date of the licence for a vehicle in the mode in use, or "" if not earned yet. Progress from
## before licences existed gets today's date the first time it is asked for.
func licence_date(vehicle: String) -> String:
	var lessons := Curriculum.lessons(vehicle, mode)
	if passed_count(vehicle) < lessons.size():
		return ""
	if not licences.get(mode, {}).has(vehicle):
		if not licences.has(mode):
			licences[mode] = {}
		licences[mode][vehicle] = Time.get_date_string_from_system()
		_undo = {}
		_save()
	return licences[mode][vehicle]


## Sunflowers earned in a vehicle's lessons, out of how many there are to earn.
func sunflowers_of(vehicle: String) -> Vector2i:
	var lessons := Curriculum.lessons(vehicle, mode)
	var got := 0
	for k in lessons:
		got += int(best_of(k).get("f", 0))
	return Vector2i(got, lessons.size() * Rating.MAX)


static func _clean_name(value: String) -> String:
	var out := ""
	for ch in value.strip_edges():
		# No control characters or line breaks: the name is one line on a card. Nor the
		# invisible ones that reorder or hide text (bidi overrides, zero-width marks).
		var c := ch.unicode_at(0)
		if c >= 32 and not (c >= 0x7F and c <= 0x9F) and not (c >= 0x200B and c <= 0x200F) \
				and not (c >= 0x202A and c <= 0x202E) and not (c >= 0x2066 and c <= 0x2069) and c != 0xFEFF:
			out += ch
	return out.substr(0, NAME_MAX).strip_edges()


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
		licence_date(vehicle)  # dates the licence the day the last lesson is passed


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
	_undo = {
		"mode": mode, "passed": passed.get(mode, {}).duplicate(), "missions": missions.get(mode, []).duplicate(),
		"best": best.get(mode, {}).duplicate(true), "licences": licences.get(mode, {}).duplicate(),
	}
	passed.erase(mode)
	missions.erase(mode)
	best.erase(mode)
	licences.erase(mode)
	_save()
	changed.emit()


## Erases everything: progress in every mode and all settings, as if just installed.
## undo_reset() puts it all back.
func erase_all() -> void:
	_undo = {"all": _data()}
	if path() == PATH:  # tests use a scratch file and must not touch real settings
		DirAccess.remove_absolute(OLD_PATH)
	for key in DEFAULTS:
		set(key, DEFAULTS[key].duplicate() if DEFAULTS[key] is Dictionary else DEFAULTS[key])
	best = {}
	licences = {}
	passed = {}
	missions = {}
	views = {}
	_save()
	_drop_backup()
	_apply_language()
	_apply_theme()
	changed.emit()


## The mode whose progress "Undo" would bring back.
func undo_mode() -> String:
	return str(_undo.get("mode", mode))


func undo_kind() -> String:
	return "" if _undo.is_empty() else ("all" if _undo.has("all") else "mode")


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
		best[_undo["mode"]] = _undo["best"]
		licences[_undo["mode"]] = _undo["licences"]
	_undo = {}
	_save()
	changed.emit()


## The FPV drone is flown through its own camera. With the camera drone, kids follow it from
## behind and everyone else sees it as a pilot on the ground does. Kept per mode and vehicle.
func view_for(m: String, vehicle := "camera") -> String:
	var machine := Curriculum.machine(vehicle)
	var fallback := "fpv" if machine == "fpv" else ("chase" if m == "kids" or machine == "wing" else ("ugv" if machine == "ugv" else "pilot"))
	if vehicle == "survey":
		fallback = "drone"  # a survey is flown through the camera, kids too
	return views.get(m + "/" + vehicle, fallback)


func set_view(m: String, vehicle: String, v: String) -> void:
	if v in VIEWS and m in MODES and vehicle in Curriculum.VEHICLES:
		views[m + "/" + vehicle] = v
		_undo = {}
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
	if data == null:
		# The swap may not have reached the disk: the last written copy is the next best.
		data = _read_json(path() + ".tmp")
	if data == null:
		# A damaged file (a full phone, a cut write) must not wipe progress: the copy
		# from the save before is one step behind but whole.
		data = _read_json(path() + ".bak")
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
	# JSON.parse (not parse_string): a damaged file is expected here, not an engine error.
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return null
	return json.data if json.data is Dictionary else null


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
	_apply_settings(d)
	_apply_results(d)
	_apply_progress(d)


func _apply_settings(d: Dictionary) -> void:
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
	var w = d.get("welcomed")
	# Files from before the question existed belong to pilots who already know the app.
	welcomed = w if w is bool else true
	var k = d.get("kids_lock")
	if k is bool:
		kids_lock = k
	var snd = d.get("sound")
	if snd is bool:
		sound = snd
	var sm = d.get("stick_mode")
	if sm is String and sm in STICK_MODES:
		stick_mode = sm
	var sf = d.get("stick_feel")
	if sf is String and STICK_FEELS.has(sf):
		stick_feel = sf
	var pn = d.get("pilot_name")
	if pn is String:
		pilot_name = _clean_name(pn)
	var fr = d.get("free")
	if fr is Dictionary:
		for key in ["wind", "time", "fpv", "balls"]:
			var val = fr.get(key)
			if {"wind": val in FREE_WINDS, "time": val in FREE_TIMES, "fpv": val in FREE_FPV,
					"balls": val is bool}[key]:
				free[key] = val


## Best results, licences and the view chosen for each vehicle.
func _apply_results(d: Dictionary) -> void:
	var b = d.get("best")
	if b is Dictionary:
		for m_ in b.keys():
			if m_ is String and m_ in MODES and b[m_] is Dictionary:
				best[m_] = _read_best(b[m_])
	var lc = d.get("licences")
	if lc is Dictionary:
		for m_ in lc.keys():
			if m_ is String and m_ in MODES and lc[m_] is Dictionary:
				var one := {}
				for v_ in lc[m_].keys():
					var date = lc[m_][v_]
					if v_ is String and v_ in Curriculum.VEHICLES and date is String and _is_date(date):
						one[v_] = date
				licences[m_] = one
	var v = d.get("views")
	if v is Dictionary:
		for key in v.keys():
			if key is String and key.count("/") == 1 and key.get_slice("/", 0) in MODES \
					and key.get_slice("/", 1) in Curriculum.VEHICLES and v[key] is String and v[key] in VIEWS:
				views[key] = v[key]


## Lessons and missions passed. Needs the mode, so it runs after the settings.
func _apply_progress(d: Dictionary) -> void:
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


func _read_best(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d.keys():
		var r = d[k]
		if not (k is String and FlightTask.implemented(k) and r is Dictionary):
			continue
		var f = r.get("f")
		var t = r.get("t")
		# JSON numbers arrive as floats; anything odd is dropped, not trusted.
		if (f is int or (f is float and is_finite(f))) and (t is int or (t is float and is_finite(t))):
			out[k] = {"f": clampi(int(f), 1, Rating.MAX), "t": clampf(float(t), 0.0, MAX_SECONDS)}
	return out


## A calendar date like 2026-11-06, as Time writes it.
static func _is_date(s: String) -> bool:
	var m := RegEx.create_from_string("^(\\d{4})-(\\d{2})-(\\d{2})$").search(s)
	if m == null:
		return false
	var month := int(m.get_string(2))
	var day := int(m.get_string(3))
	return month >= 1 and month <= 12 and day >= 1 and day <= 31


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
		"welcomed": welcomed, "kids_lock": kids_lock, "sound": sound, "stick_mode": stick_mode, "stick_feel": stick_feel,
		"views": views.duplicate(true), "passed": passed.duplicate(true),
		"missions": missions.duplicate(true), "best": best.duplicate(true),
		"licences": licences.duplicate(true), "pilot_name": pilot_name, "free": free.duplicate(),
	}


## Writes a whole new file and then swaps it in, so the app closing mid-write leaves the old
## file whole. The file before is kept as .bak, and _load falls back to .tmp, then .bak.
## Returns false if it could not be written; the old file is then left as it was. Callers may
## ignore that: the app keeps working from memory and the next change tries to save again.
func _save() -> bool:
	var tmp := path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(_data(), "\t"))
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	if not ok:
		# A full phone: never swap a half-written file in.
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path()):
		DirAccess.remove_absolute(path() + ".bak")
		DirAccess.rename_absolute(path(), path() + ".bak")
	return DirAccess.rename_absolute(tmp, path()) == OK


## Removes the previous copy, so erased data does not linger on the phone.
func _drop_backup() -> void:
	DirAccess.remove_absolute(path() + ".bak")
