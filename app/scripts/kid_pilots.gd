# SPDX-License-Identifier: GPL-3.0-or-later
# Several children on one phone, each with their own Kids mode progress. A pilot is an animal and a
# colour: no names, nothing that points at a child. Up to six. With one pilot nothing changes and
# no one is asked; from two on, Kids mode starts with "Who's flying?".
#
# The pilot flying now keeps their progress in Prefs' usual Kids mode fields, so the rest of the app
# needs to know nothing about pilots; the others' progress waits in Prefs.kid_pilots[i]["slice"].
class_name KidPilots
extends RefCounted

const MAX := 6
const ANIMALS := ["fox", "owl", "hedgehog", "hare", "stork", "bee"]
const COLORS := ["gold", "blue", "pink", "green", "violet", "orange"]
## The Kids mode parts of the progress that each pilot has their own of.
const FIELDS := ["passed", "missions", "best", "licences"]


static func count() -> int:
	return maxi(1, Prefs.kid_pilots.size())


## Who's flying needs asking only with two pilots or more.
static func ask() -> bool:
	return Prefs.kid_pilots.size() >= 2


static func animal(i: int) -> String:
	return Prefs.kid_pilots[i]["animal"] if i < Prefs.kid_pilots.size() else ANIMALS[0]


static func color(i: int) -> Color:
	var c: String = Prefs.kid_pilots[i]["color"] if i < Prefs.kid_pilots.size() else COLORS[0]
	return Pal.TOY[c]


## The Kids mode progress flying now, as one slice.
static func live_slice() -> Dictionary:
	var s := {}
	for f in FIELDS:
		var all: Dictionary = Prefs.get(f)
		s[f] = all.get("kids", {} if f != "missions" else []).duplicate(true)
	return s


static func _put(slice: Dictionary) -> void:
	for f in FIELDS:
		var all: Dictionary = Prefs.get(f)
		all["kids"] = slice.get(f, {} if f != "missions" else []).duplicate(true)


## A new pilot with the next free animal and colour; they fly next. False when there are six.
static func add() -> bool:
	if Prefs.kid_pilots.size() >= MAX:
		return false
	if Prefs.kid_pilots.is_empty():
		# The child who has been flying so far becomes the first pilot, progress and all.
		Prefs.kid_pilots.append({"animal": ANIMALS[0], "color": COLORS[0], "slice": {}})
		Prefs.kid_pilot = 0
	var used_a := Prefs.kid_pilots.map(func(p): return p["animal"])
	var used_c := Prefs.kid_pilots.map(func(p): return p["color"])
	var a: String = ANIMALS.filter(func(x): return x not in used_a)[0]
	var c: String = COLORS.filter(func(x): return x not in used_c)[0]
	Prefs.kid_pilots.append({"animal": a, "color": c, "slice": {}})
	select(Prefs.kid_pilots.size() - 1)
	return true


## The pilot who flies now: their progress comes out, the one before goes back in their slot.
static func select(i: int) -> void:
	if i < 0 or i >= Prefs.kid_pilots.size():
		return
	if i != Prefs.kid_pilot:
		Prefs.kid_pilots[Prefs.kid_pilot]["slice"] = live_slice()
		_put(Prefs.kid_pilots[i]["slice"])
		Prefs.kid_pilots[i]["slice"] = {}
		Prefs.kid_pilot = i
	Prefs.pilots_changed()


## A pilot and their progress, gone. The last one cannot be removed, only started again.
static func remove(i: int) -> void:
	if Prefs.kid_pilots.size() < 2 or i < 0 or i >= Prefs.kid_pilots.size():
		return
	if i == Prefs.kid_pilot:
		select(0 if i != 0 else 1)
	Prefs.kid_pilots.remove_at(i)
	if Prefs.kid_pilot > i:
		Prefs.kid_pilot -= 1
	Prefs.pilots_changed()  # one pilot left is kept as it is: no one is asked (see ask())


## A removed pilot back in their place, with their progress, not flying.
static func restore(at: int, pilot: Dictionary) -> void:
	if Prefs.kid_pilots.size() >= MAX:
		return
	if Prefs.kid_pilots.is_empty():
		var a: String = ANIMALS.filter(func(x): return x != pilot["animal"])[0]
		var c: String = COLORS.filter(func(x): return x != pilot["color"])[0]
		Prefs.kid_pilots.append({"animal": a, "color": c, "slice": {}})
		Prefs.kid_pilot = 0
	var i := clampi(at, 0, Prefs.kid_pilots.size())
	Prefs.kid_pilots.insert(i, pilot)
	if i <= Prefs.kid_pilot:
		Prefs.kid_pilot += 1
	Prefs.pilots_changed()


## 0 to 3 sunflowers for the picker: none yet, some, half or more, every lesson. No numbers.
static func flowers(i: int) -> int:
	var s: Dictionary = live_slice() if i == Prefs.kid_pilot else Prefs.kid_pilots[i]["slice"]
	var done := 0
	var total := 0
	for v in Curriculum.VEHICLES:
		var n := Curriculum.lessons(v, "kids").size()
		total += n
		done += mini(int(s.get("passed", {}).get(v, 0)), n)
	if done == 0:
		return 0
	return 3 if done >= total else (2 if done * 2 >= total else 1)


## Saved pilots, checked like everything else read from the file.
static func read(list, active) -> void:
	Prefs.kid_pilots = []
	Prefs.kid_pilot = 0
	if not list is Array:
		return
	for p in list:
		if Prefs.kid_pilots.size() >= MAX:
			break
		if p is Dictionary and p.get("animal") in ANIMALS and p.get("color") in COLORS and p.get("slice", {}) is Dictionary:
			Prefs.kid_pilots.append({"animal": p["animal"], "color": p["color"], "slice": _read_slice(p.get("slice", {}))})
	if Prefs.kid_pilots.size() < 2:
		Prefs.kid_pilots = []
		return
	if (active is int or active is float) and int(active) >= 0 and int(active) < Prefs.kid_pilots.size():
		Prefs.kid_pilot = int(active)


static func _read_slice(s: Dictionary) -> Dictionary:
	var out := {}
	if s.get("passed") is Dictionary:
		out["passed"] = Prefs._read_counts(s["passed"], "kids")
	if s.get("missions") is Array:
		out["missions"] = Prefs._read_missions(s["missions"])
	if s.get("best") is Dictionary:
		out["best"] = Prefs._read_best(s["best"])
	if s.get("licences") is Dictionary:
		var lc := {}
		for v in s["licences"]:
			if v in Curriculum.VEHICLES and s["licences"][v] is String and Prefs._is_date(s["licences"][v]):
				lc[v] = s["licences"][v]
		out["licences"] = lc
	return out
