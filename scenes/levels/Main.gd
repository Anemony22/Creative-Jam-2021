extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	#OS.window_fullscreen = true


func _unhandled_key_input(event):
	if event is InputEventKey:
		if event.is_action("ui_cancel"):
			get_tree().quit()
			
		if event.is_action("ui_page_up"):
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if event.is_action("ui_page_down"):
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if event.is_action_pressed("ui_focus_next"):
			OS.window_fullscreen = !OS.window_fullscreen
