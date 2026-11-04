# SPDX-License-Identifier: GPL-3.0-or-later
# Adult mission: after a storm, look at every roof in the village from above and say whether it is damaged.
# Damaged roofs have a dark hole and fallen tiles on the ground.
extends FlightTask

const ABOVE := 7.0  # m above the ground, higher than the 6 m ridge
const NEAR := 9.0  # m from the house

var _damaged: Array[int] = []
var _answers := {}  # house index -> true if the pilot said "damaged"
var _near := -1


func configure() -> void:
	view_hint = "drone"


func setup_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = task_seed
	var all := range(world.houses.size())
	for i in all.size():
		var j := rng.randi_range(i, all.size() - 1)
		var tmp = all[i]
		all[i] = all[j]
		all[j] = tmp
	for i in 3:
		_damaged.append(all[i])
		world.damage_roof(all[i])


## For tests only.
func truth(house: int) -> bool:
	return house in _damaged


func update(_dt: float, sim: DroneSim, _sticks: Dictionary) -> void:
	var n: int = world.houses.size()
	counter = _answers.size()
	counter_max = n
	progress = float(_answers.size()) / n
	_near = -1
	var best := INF
	var next := -1
	for i in n:
		if _answers.has(i):
			continue
		var d := flat_distance(sim.pos, world.houses[i]["pos"])
		if d < best:
			best = d
			next = i
	if next == -1:
		return
	if best <= NEAR and sim.altitude() >= ABOVE:
		_near = next
		choice = {"prompt": "Q_ROOF", "options": [["damaged", "OPT_DAMAGED"], ["ok", "OPT_INTACT"]]}
		marker = Vector3.INF
		beacon = 0.0
		say("HINT_SURVEY_LOOK")
	else:
		choice = {}
		marker = world.houses[next]["pos"] + Vector3(0, 9, 0)
		beacon = 3.0
		if sim.on_ground:
			say("HINT_SURVEY_UP")
		elif best <= NEAR:
			say("HINT_SURVEY_HIGHER")
		else:
			say("HINT_SURVEY_GO", [n - _answers.size()])


func choose(id: String) -> void:
	if _near < 0:
		return
	_answers[_near] = id == "damaged"
	choice = {}
	if _answers.size() < world.houses.size():
		say_for("HINT_SURVEY_NOTED", [], 1.5)
		return
	var right := 0
	for i in _answers.keys():
		if _answers[i] == (i in _damaged):
			right += 1
	if right == world.houses.size():
		pass_with("SUM_SURVEY", [right, world.houses.size()])
	else:
		fail_with("FAIL_SURVEY", [right, world.houses.size()])
