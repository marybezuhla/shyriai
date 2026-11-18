# SPDX-License-Identifier: GPL-3.0-or-later
# The pilot's badges and how far the whole training has come, worked out from what the app keeps
# anyway (lessons passed, missions done, sunflowers, chapters read): nothing new is saved. Each mode
# has its own, as its progress does, and in Kids mode each child on the phone has their own.
#
# A badge is at level 0 (still ahead), 1 (on the way) or 2 (earned). Big steps have a double rim.
class_name Badges
extends RefCounted

## A clean flight earns the second sunflower; this many lessons flown clean earn the badge.
const CLEAN := 10


## Every badge for the mode in use, in the order shown: {id, icon, level, big, title, how, note}.
## title and how are string keys; note is a short "5 of 10" or "" (never in Kids mode).
static func all() -> Array:
	var kids := Prefs.mode == "kids"
	var out := []
	var started := Curriculum.VEHICLES.filter(func(v): return Prefs.passed_count(v) > 0).size()
	out.append(_badge("FIRST", "play", 2 if started > 0 else 0))
	var licences := 0
	for v in Curriculum.VEHICLES:
		var done := Prefs.passed_count(v)
		var total := Curriculum.lessons(v, Prefs.mode).size()
		if done >= total:
			licences += 1
		var b := _badge("LIC", Curriculum.ICONS[v], _share(done, total), true)
		b["title"] = "VEH_" + v.to_upper()
		b["vehicle"] = v
		out.append(b)
	if not kids:
		var clean := _lessons_with(2)
		out.append(_badge("CLEAN", "check", _steps(clean, CLEAN), false, _of(clean, CLEAN)))
	out.append(_badge("FIELD", "sunflower", _field()))
	var missions := _missions()
	out.append(_badge("MISSION", "missions", 2 if missions.x > 0 else 0))
	out.append(_badge("MISSIONS", "flag_done", _share(missions.x, missions.y, true), true))
	if not kids:
		var chapters := Book.read_count()
		var total := Book.CHAPTERS.size()
		out.append(_badge("READER", "theory", _share(chapters, total, true), false, _of(chapters, total)))
		out.append(_badge("ALL", "learn", _share(started, Curriculum.VEHICLES.size(), true), false,
			_of(started, Curriculum.VEHICLES.size())))
		out.append(_badge("ACE", "star", _share(licences, Curriculum.VEHICLES.size(), true), true))
	return out


static func earned(list: Array) -> int:
	return list.filter(func(b): return b["level"] == 2).size()


## How far the whole training has come in this mode: x done of y, per part. The book is not
## a Kids mode part: the kids' little book is not counted.
static func totals() -> Dictionary:
	var lessons := Vector2i.ZERO
	var flowers := Vector2i.ZERO
	for v in Curriculum.VEHICLES:
		var keys := Curriculum.lessons(v, Prefs.mode)
		lessons += Vector2i(Prefs.passed_count(v), keys.size())
		for k in keys + Curriculum.missions(v, Prefs.mode):
			flowers += Vector2i(int(Prefs.best_of(k).get("f", 0)), Rating.MAX)
	var out := {"lessons": lessons, "missions": _missions(), "flowers": flowers}
	if Prefs.mode != "kids":
		out["chapters"] = Vector2i(Book.read_count(), Book.CHAPTERS.size())
	return out


static func _badge(id: String, icon: String, level: int, big := false, note := "") -> Dictionary:
	return {"id": id, "icon": icon, "level": level, "big": big, "title": "BADGE_%s_T" % id,
		"how": "BADGE_%s_HOW" % id, "note": note}


## Earned when all are done; on the way from half (or from the first one, if `any`).
static func _share(done: int, total: int, any := false) -> int:
	if total <= 0 or done >= total:
		return 2
	if done * 2 >= total or (any and done > 0):
		return 1
	return 0


static func _steps(n: int, goal: int) -> int:
	return 2 if n >= goal else (1 if n * 2 >= goal else 0)


static func _of(n: int, total: int) -> String:
	return TranslationServer.translate("BADGE_OF") % [mini(n, total), total]


## Lessons of this mode with at least that many sunflowers.
static func _lessons_with(flowers: int) -> int:
	var n := 0
	for v in Curriculum.VEHICLES:
		for k in Curriculum.lessons(v, Prefs.mode):
			if int(Prefs.best_of(k).get("f", 0)) >= flowers:
				n += 1
	return n


## A whole course with every sunflower: earned; a lesson with all three: on the way.
static func _field() -> int:
	var level := 0
	for v in Curriculum.VEHICLES:
		var s := Prefs.sunflowers_of(v)
		if s.y > 0 and s.x >= s.y:
			return 2
	if _lessons_with(Rating.MAX) > 0:
		level = 1
	return level


static func _missions() -> Vector2i:
	var n := Vector2i.ZERO
	for v in Curriculum.VEHICLES:
		for k in Curriculum.missions(v, Prefs.mode):
			n += Vector2i(1 if Prefs.mission_done(k) else 0, 1)
	return n
