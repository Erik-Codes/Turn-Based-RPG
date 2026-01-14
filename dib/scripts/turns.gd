#extends Node
#class_name TurnQueue
#
#
#var current_time: float = 0.0
#var _queue: Array = []
#
#func _tu_cost_for_speed(speed: float) -> float:
	#return speed
#
#func add_actor(monster: Global.Monster) -> void:
	#var entry := {
		#"ref": monster,
		#"tu_cost": _tu_cost_for_speed(Global.monster_data[monster]['speed']),
		#"time_left": Global.monster_data[monster]['speed'] # can set to 0 to all start together, or randomize small offsets
	#}
	#_queue.append(entry)
	#_sort_queue()
#
#func remove_actor(monster: Global.Monster) -> void:
	#for i in range(_queue.size()):
		#if _queue[i]["ref"] == monster:
			#_queue.remove_at(i)
			#return
#
#func next_actor() -> Dictionary:
	## Returns the monster dictionary that should act next (and re-schedules them).
	## You’ll call this whenever you're ready to start the next turn.
	#if _queue.is_empty():
		#return {}
	#_sort_queue()
	#var entry = _queue.pop_front()
	#current_time = entry["time_left"]
	#var monster = Global.monster_data[entry["ref"]]
	## IMPORTANT: monster speed might have changed since last scheduled
	#entry["tu_cost"] = _tu_cost_for_speed(monster['speed'])
	## Default: schedule next turn with normal cost
	#entry["time_left"] = current_time + entry["tu_cost"]
	#_queue.append(entry)
	#_sort_queue()
	#return monster
#
#func schedule_with_action_cost(monster: Dictionary, action_cost_multiplier: float) -> void:
	## Optional helper if you want "heavy actions" to delay the next turn more.
	## action_cost_multiplier: 1.0 = normal, 1.5 = slower, 0.5 = faster action.
	#for entry in _queue:
		#if entry["ref"] == monster:
			#var speed = monster.get("speed", 1.0)
			#entry["tu_cost"] = _tu_cost_for_speed(speed) * max(action_cost_multiplier, 0.0)
			#entry["time_left"] = current_time + entry["tu_cost"]
			#_sort_queue()
			#return
#
#func change_speed(monster: Dictionary, new_speed: float) -> void:
	## Handles mid-round speed changes fairly by preserving "progress" toward next turn.
	#for entry in _queue:
		#if entry["ref"] == monster:
			#var old_cost: float = entry["tu_cost"]
			#var old_next: float = entry["time_left"]
#
			#monster["speed"] = new_speed
#
			#var new_cost: float = _tu_cost_for_speed(new_speed)
			#entry["tu_cost"] = new_cost
#
			## How far along were they toward their next action?
			## progress = 0 => just acted, progress = 1 => about to act
			#var elapsed: float = clamp(current_time - (old_next - old_cost), 0.0, old_cost)
			#var progress: float = 0.0 if (old_cost <= 0.0) else (elapsed / old_cost)
#
			## Keep the same progress, but under the new speed/cost
			#var remaining_new: float = (1.0 - progress) * new_cost
			#entry["time_left"] = current_time + remaining_new
#
			#_sort_queue()
			#return
#
#func peek_time_left() -> float:
	#if _queue.is_empty():
		#return INF
	#_sort_queue()
	#return _queue[0]["time_left"]
#
#func _sort_queue() -> void:
	#_queue.sort_custom(func(a, b): return a["time_left"] < b["time_left"])
