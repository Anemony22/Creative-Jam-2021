extends KinematicBody

var gravity = -30
export var max_speed = 8
export var mouse_sensitivity = 0.002

var velocity = Vector3()

onready var prev_transform = global_transform

func get_input():
	var input_dir = Vector3()

	# Directional movement
	if Input.is_action_pressed("move_forward"):
		input_dir += -global_transform.basis.z
	if Input.is_action_pressed("move_back"):
		input_dir += global_transform.basis.z
	if Input.is_action_pressed("move_left"):
		input_dir += -global_transform.basis.x
	if Input.is_action_pressed("move_right"):
		input_dir += global_transform.basis.x
	
	input_dir = input_dir.normalized()
	
	return input_dir


func _unhandled_input(event):
	# Mouse camera movement
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		$CameraPivot.rotate_x(-event.relative.y * mouse_sensitivity)
		$CameraPivot.rotation.x = clamp($CameraPivot.rotation.x, -1.2, 1.2)
	
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("interact"):
			if $CameraPivot/Camera/RayCast.is_colliding():
				var collision: Node = $CameraPivot/Camera/RayCast.get_collider()
				
				if collision.has_node("Interactable"):
					var interactable = collision.get_node("Interactable")
					print("Interacted with " + interactable.title)


func _physics_process(delta):
	# Torch lagged rotation
	var target_transform = global_transform
	target_transform = target_transform.rotated(target_transform.basis.x, $CameraPivot.rotation.x)
	
	var target_quat = Quat(target_transform.basis)
	var torch_quat = Quat(prev_transform.basis)

	var desired_quat = torch_quat.slerp(target_quat, 0.4)

	$TorchPivot.global_transform.basis = Basis(desired_quat)

	prev_transform = $TorchPivot.global_transform
	
	# Movement
	velocity.y += gravity * delta
	var desired_velocity = get_input() * max_speed

	velocity.x = desired_velocity.x
	velocity.z = desired_velocity.z
	velocity = move_and_slide(velocity, Vector3.UP, true)
	
	# Interaction
	if $CameraPivot/Camera/RayCast.is_colliding():
		var collision: Node = $CameraPivot/Camera/RayCast.get_collider()
		
		if collision.has_node("Interactable"):
			var interactable = collision.get_node("Interactable")
			
			$HUD/RayCheck/HBoxContainer/Interact.text = "Interact with " + interactable.title
			$HUD/RayCheck.visible = true
	else:
		$HUD/RayCheck.visible = false
