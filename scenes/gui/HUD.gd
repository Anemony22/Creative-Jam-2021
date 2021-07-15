extends CanvasLayer


func display_info(title, translate, description):
	$Info/Word.text = title
	$Info/Translation.text = translate
	$Info/Description.text = description
	
	$Info.visible = true
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event):
	if Input.is_action_pressed("interact") && $Info.visible:
		$Info.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_tree().set_input_as_handled()
