extends Node
class_name BattleTimeline

var time := 0.0
var queue: Array = [] #[{ "id":int, "is_enemy":bool, "next_time":float, etc. }, dict]

func init(entries: Array) -> void:
	time = 0.0
	queue = entries
	queue.sort_custom(func(a, b): return float(a["speed"]) < float(b["speed"]))
	_sort()

func pop_next() -> Dictionary:
	_sort()
	var entry: Dictionary = queue.pop_front()
	time = float(entry["time_left"])
	return entry

func commit(entry: Dictionary, cost: float) -> void:
	entry["time_left"] = time+cost
	queue.append(entry)
	_sort()

func remove_uid(uid: int) -> void:
	for i in range(queue.size()):
		if int(queue[i]["uid"]) == uid:
			queue.remove_at(i)
			return

func add_entry(entry: Dictionary) -> void:
	#For newly spawned enemies
	entry["time_left"] = entry["speed"]/(randi_range(2,6))
	queue.append(entry)
	_sort()

func _sort() -> void:
	queue.sort_custom(func(a, b): return float(a["time_left"]) < float(b["time_left"]))
	#make first in line have 0 time remaining
	var base = queue[0]['time_left']
	for e in queue:
		var timeleft =e["time_left"]-base
		e["time_left"] =timeleft
