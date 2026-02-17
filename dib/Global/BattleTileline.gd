extends Node
class_name BattleTimeline

var time := 0.0
var queue: Array = [] #[{ "id":int, "is_enemy":bool, "next_time":float, etc. }, dict]

func init(entries: Array) -> void:
	queue.clear()
	time = 0.0
	for e in entries:
		var entry = e.duplicate(true)
		if not entry.has("time_left"):
			#similar to add_entry() behavior
			var speed := float(entry.get("speed", 100.0))
			entry["time_left"] = 0.1 + (100.0 / max(speed, 1.0)) + randf() * 0.2
		queue.append(entry)
	queue.sort_custom(func(a, b): return float(a["speed"]) < float(b["speed"]))
	_sort()

#get monster data (up next)
func pop_next() -> Dictionary:
	_sort()
	var entry: Dictionary = queue.pop_front()
	time = float(entry["time_left"])
	return entry

#add to priority queue
func commit(entry: Dictionary, cost: float) -> void:
	entry["time_left"] = time+cost
	queue.append(entry)
	_sort()
#dead
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
