# SPDX-License-Identifier: GPL-3.0-or-later
# The sounds of a flight: motors that follow the throttle, a chime when a task counts, a short blip
# for each ball or gate, a soft thud on a bump, a beep while the robot's link is down.
# Every sound is made here in code, so there are no audio files and no licences to track.
class_name FlightSound
extends Node

const RATE := 22050
## Made once, the first time anyone flies; every later flight reuses them.
static var _cache := {}

var _on := true
var _kids := false
var _motor: AudioStreamPlayer
var _fx: AudioStreamPlayer
var _beep: AudioStreamPlayer
var _beep_left := 0.0
var _load := 0.0


func setup(vehicle: String, kids: bool, on: bool) -> void:
	_on = on
	_kids = kids
	if not _on:
		return
	_motor = _player(_stream("ugv" if vehicle == "ugv" else ("fpv" if vehicle == "fpv" else "drone")))
	_motor.volume_db = -80.0
	_fx = _player(_stream("chime"))
	_beep = _player(_stream("beep"))


## Called every frame: the motors rise and fall with how hard they work (0 = still, 1 = full).
func motors(load_: float, running: bool, delta: float) -> void:
	if not _on:
		return
	var target := clampf(load_, 0.0, 1.0) if running else 0.0
	# A little smoothing, so the pitch glides like a real motor's and never jumps.
	_load = move_toward(_load, target, delta * 2.5)
	if _load < 0.02:
		if _motor.playing:
			_motor.stop()
		return
	if not _motor.playing:
		_motor.play()
	_motor.pitch_scale = 0.8 + 0.55 * _load
	_motor.volume_db = linear_to_db(0.25 + 0.75 * _load) + (-16.0 if _kids else -12.0)


## A short sound: "chime" (passed), "blip" (a ball, a gate, a step done), "thud" (a bump),
## "fail" (not this time, or a picture that will not do), "shutter" (a picture taken).
func play(name_: String) -> void:
	if not _on:
		return
	_fx.stream = _stream(name_)
	_fx.volume_db = (-10.0 if _kids else -7.0) if name_ != "thud" else -4.0
	_fx.play()


## While the robot has no link, a quiet beep once a second.
func no_link(down: bool, delta: float) -> void:
	if not _on:
		return
	if not down:
		_beep_left = 0.0
		return
	_beep_left -= delta
	if _beep_left <= 0.0:
		_beep_left = 1.0
		_beep.volume_db = -14.0
		_beep.play()


## Quiet while paused, and for good when the flight ends.
func hush(on: bool) -> void:
	if not _on:
		return
	for pl in [_motor, _fx, _beep]:
		pl.stream_paused = on


func stop_motors() -> void:
	if _on:
		_load = 0.0
		_motor.stop()


func _player(s: AudioStream) -> AudioStreamPlayer:
	var pl := AudioStreamPlayer.new()
	pl.stream = s
	add_child(pl)
	return pl


static func _stream(name_: String) -> AudioStreamWAV:
	if not _cache.has(name_):
		_cache[name_] = _make(name_)
	return _cache[name_]


static func _make(name_: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var out := PackedFloat32Array()
	var loop := false
	match name_:
		"drone", "fpv":
			# Two rotor pairs a few hertz apart: the slow beat is what makes a quadcopter sound alive.
			# Half a second holds a whole number of waves of both, so the loop has no click.
			var f := 110.0 if name_ == "drone" else 220.0
			var f2 := f + (2.0 if name_ == "drone" else 4.0)
			var n := RATE / 2
			out.resize(n)
			var lp := 0.0
			for i in n:
				var t := float(i) / RATE
				var s := 0.0
				for h in [1, 2, 3, 4]:
					s += (sin(TAU * f * h * t) + sin(TAU * f2 * h * t)) / (h * h)
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08  # soft air noise
				out[i] = s * 0.22 + lp * 0.35
			loop = true
		"ugv":
			# A low electric whine over the rumble of tracks.
			var n := RATE / 2
			out.resize(n)
			var lp := 0.0
			for i in n:
				var t := float(i) / RATE
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.03
				var tread := 0.5 + 0.5 * sin(TAU * 24.0 * t)
				out[i] = sin(TAU * 330.0 * t) * 0.12 + sin(TAU * 60.0 * t) * 0.25 + lp * 1.6 * tread
			loop = true
		"chime":
			out = _notes([[784.0, 0.0], [1046.5, 0.12]], 0.7)
		"blip":
			out = _notes([[1174.7, 0.0]], 0.12)
		"fail":
			out = _notes([[523.3, 0.0], [392.0, 0.14]], 0.5)
		"beep":
			out = _notes([[660.0, 0.0]], 0.15)
		"shutter":
			# Two quick mechanical clicks, like a camera's.
			var n := int(RATE * 0.12)
			out.resize(n)
			for i in n:
				var t := float(i) / RATE
				var click := exp(-t * 300.0) + 0.7 * exp(-maxf(t - 0.06, 0.0) * 300.0) * float(t >= 0.06)
				out[i] = rng.randf_range(-1.0, 1.0) * click * 0.8
		"thud":
			var n := int(RATE * 0.3)
			out.resize(n)
			var lp := 0.0
			for i in n:
				var t := float(i) / RATE
				lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.05
				out[i] = (lp * 2.5 + sin(TAU * (80.0 - 120.0 * t) * t) * 0.6) * exp(-t * 14.0)
	return _wav(out, loop)


## Soft bell-like notes: [hertz, start second], each fading away; `length` in seconds.
static func _notes(notes: Array, length: float) -> PackedFloat32Array:
	var n := int(RATE * length)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for note in notes:
			var dt: float = t - note[1]
			if dt >= 0.0:
				var f: float = note[0]
				var attack := minf(dt / 0.006, 1.0)  # no click at the start
				s += (sin(TAU * f * dt) + 0.25 * sin(TAU * f * 2.0 * dt)) * attack * exp(-dt * 7.0)
		out[i] = s * 0.45
	return out


static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w
