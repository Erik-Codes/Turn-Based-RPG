extends Control
class_name SwipeDetector

signal swiped(dir: String, uid: int)
signal tapped(uid: int)

const SWIPE_THRESHOLD := 50.0

var _start := Vector2.ZERO
var _tracking := false
var uid: int = -1

func set_uid(v: int) -> void:
	uid = v

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			_start = event.position
			_tracking = true
			accept_event()
		else:
			_handle_release(event.position)
			accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start = event.position
			_tracking = true
			accept_event()
		else:
			_handle_release(event.position)
			accept_event()
		return

func _handle_release(end_pos: Vector2) -> void:
	if not _tracking:
		return
	_tracking = false

	var d := end_pos - _start
	var ax = abs(d.x)
	var ay = abs(d.y)

	# TAP (below threshold)
	if ax < SWIPE_THRESHOLD and ay < SWIPE_THRESHOLD:
		tapped.emit(uid)
		return

	# SWIPE
	if ax > ay:
		swiped.emit("right" if d.x > 0 else "left", uid)
	else:
		swiped.emit("down" if d.y > 0  else "up", uid)
