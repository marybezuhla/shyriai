# SPDX-License-Identifier: GPL-3.0-or-later
# The pilot's book: ten chapters to read from start to end, each tied to the lessons it explains.
# The short theory cards live on inside it: a chapter's "In short" points and its "Check yourself"
# questions are the card's. Kids get their own little book instead: a picture and a sentence or two
# a page, no numbers.
#
# A chapter's text is BOOK_<ID>_BODY, paragraphs split by "|". A word from the glossary is written
# {TERM:the words} and becomes a link that explains it; TERM is the glossary's GL_<TERM>.
class_name Book
extends RefCounted

## id, its icon, a drawing (see BookFigure) or "", the theory card it carries or "", and the
## lesson to try it in: [vehicle, key] or []. "short": false leaves out the card's points where the
## chapter already says the same.
const CHAPTERS := [
	{"id": "CONTROLS", "icon": "radio", "fig": "sticks", "card": "", "try": ["camera", "CAM_STICKS"]},
	{"id": "CHECKLIST", "icon": "list", "fig": "", "card": "TH_CHECKLIST", "try": ["camera", "CAM_TAKEOFF"], "short": false},
	{"id": "CAMERA", "icon": "camera", "fig": "", "card": "TH_SIGNAL", "try": ["camera", "CAM_HOLD"]},
	{"id": "BATTERY", "icon": "battery", "fig": "lipo", "card": "TH_BATTERY", "try": []},
	{"id": "SURVEY", "icon": "photo", "fig": "", "card": "", "try": ["survey", "SRV_TILT"]},
	{"id": "FPV", "icon": "fpv", "fig": "", "card": "", "try": ["fpv", "FPV_THROTTLE"]},
	{"id": "WING", "icon": "wing", "fig": "wing", "card": "TH_WING", "try": ["wing", "WING_LEVEL"]},
	{"id": "INTERCEPT", "icon": "intercept", "fig": "", "card": "", "try": ["intercept", "INT_CHASE"]},
	{"id": "UGV", "icon": "ugv", "fig": "", "card": "", "try": ["ugv", "UGV_DRIVE"]},
	{"id": "RULES", "icon": "info", "fig": "", "card": "TH_RULES", "try": []},
]
## The kids' book, a page each: the text is BOOK_KIDS_<n> and the pictures are glyphs.
const KIDS_PAGES := [
	["camera"], ["grownup", "kid"], ["radio"], ["battery"], ["cloud"], ["home"], ["stork", "wing"],
	["ugv"], ["camera", "kid"], ["fox", "sunflower"],
]
## Lessons whose chapter is not their vehicle's own.
const LESSON_CHAPTER := {"CAM_STICKS": "CONTROLS", "CAM_TAKEOFF": "CHECKLIST"}
const VEHICLE_CHAPTER := {
	"camera": "CAMERA", "fpv": "FPV", "ugv": "UGV", "survey": "SURVEY", "intercept": "INTERCEPT", "wing": "WING",
}


static func index_of(id: String) -> int:
	for i in CHAPTERS.size():
		if CHAPTERS[i]["id"] == id:
			return i
	return -1


## The chapter that explains a lesson.
static func chapter_for(vehicle: String, key: String) -> String:
	return LESSON_CHAPTER.get(key, VEHICLE_CHAPTER.get(vehicle, ""))


static func is_read(id: String) -> bool:
	return id in Prefs.book_read


static func read_count() -> int:
	return Prefs.book_read.size()


static func mark_read(id: String) -> void:
	if index_of(id) >= 0 and not is_read(id):
		Prefs.book_read.append(id)
		Prefs.book_changed()


## Where to go on: the first chapter not read yet, or "" when all are.
static func next_unread() -> String:
	for c in CHAPTERS:
		if not is_read(c["id"]):
			return c["id"]
	return ""


## Chapters read, as saved: known ids only, each once.
static func read(list) -> void:
	Prefs.book_read = []
	if not list is Array:
		return
	for id in list:
		if id is String and index_of(id) >= 0 and id not in Prefs.book_read:
			Prefs.book_read.append(id)


## A paragraph with its glossary words as links, for a RichTextLabel.
static func bbcode(text: String, link: Color) -> String:
	var plain := text.replace("[", "(").replace("]", ")")  # no stray BBCode from a translation
	var rx := RegEx.create_from_string("\\{([A-Z]+):([^{}]+)\\}")
	var out := ""
	var at := 0
	for m in rx.search_all(plain):
		out += plain.substr(at, m.get_start() - at)
		out += "[url=%s][color=#%s]%s[/color][/url]" % [m.get_string(1), link.to_html(false), m.get_string(2)]
		at = m.get_end()
	return out + plain.substr(at)


## The glossary words a text links to, in order, each once.
static func terms(text: String) -> Array:
	var rx := RegEx.create_from_string("\\{([A-Z]+):[^{}]+\\}")
	var out := []
	for m in rx.search_all(text):
		if m.get_string(1) not in out:
			out.append(m.get_string(1))
	return out


## The text as read aloud or shown plainly: the links' words only.
static func plain(text: String) -> String:
	return RegEx.create_from_string("\\{[A-Z]+:([^{}]+)\\}").sub(text, "$1", true)
