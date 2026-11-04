# SPDX-License-Identifier: GPL-3.0-or-later
# Full licence texts: Shyriai (GPL-3.0), the fonts (OFL-1.1), Godot Engine and its parts.
extends Screen

const FILES := [
	["Shyriai · GPL-3.0-or-later", "res://licenses/GPL-3.0.txt"],
	["Unbounded · OFL-1.1", "res://assets/fonts/Unbounded-OFL.txt"],
	["Manrope · OFL-1.1", "res://assets/fonts/Manrope-OFL.txt"],
	["AndroidX · Kotlin · Apache-2.0", "res://licenses/android-libraries.txt"],
	["Apache License 2.0", "res://licenses/Apache-2.0.txt"],
]


func build() -> void:
	add_child(header(tr("ABOUT_FULL_LICENSES")))
	for f in FILES:
		_block(f[0], FileAccess.get_file_as_string(f[1]))
	_block("Godot Engine · MIT", Engine.get_license_text())
	# Third-party code inside Godot, with the licences they use.
	var parts := PackedStringArray()
	# Each with its copyright holders: the licences require the notices themselves.
	for info in Engine.get_copyright_info():
		var lic := PackedStringArray()
		var holders := PackedStringArray()
		for p in info["parts"]:
			if not lic.has(p["license"]):
				lic.append(p["license"])
			for c in p["copyright"]:
				if not holders.has(c):
					holders.append(c)
		parts.append("%s — %s\n© %s" % [info["name"], ", ".join(lic), "; ".join(holders)])
	_block(tr("LICENSES_GODOT_PARTS"), "\n\n".join(parts))
	var texts: Dictionary = Engine.get_license_info()
	for lic_name in texts.keys():
		_block(lic_name, texts[lic_name])


func _block(title: String, body: String) -> void:
	var v := UI.vbox(6)
	v.add_child(UI.eyebrow(title))
	v.add_child(UI.label(body.strip_edges(), 12, 500, "muted"))
	add_child(v)
