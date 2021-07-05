extends KinematicBody

var gravity = -30
export var max_speed = 8
export var mouse_sensitivity = 0.002

var velocity = Vector3()

onready var prev_angle = rotation.y

func get_input():
	var input_dir = Vector3()

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
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		$CameraPivot.rotate_x(-event.relative.y * mouse_sensitivity)
		$CameraPivot.rotation.x = clamp($CameraPivot.rotation.x, -1.2, 1.2)

func _physics_process(delta):
	$TorchPivot.rotation.x = lerp($TorchPivot.rotation.x, $CameraPivot.rotation.x, 0.2)

	var angle_diff = prev_angle - rotation.y

	if angle_diff > PI:
		angle_diff -= 2*PI
	elif angle_diff < -PI:
		angle_diff += 2*PI

	$TorchPivot.rotation.y = lerp(clamp(angle_diff, -0.35, 0.35), 0, 0.2)

	prev_angle = rotation.y + $TorchPivot.rotation.y
	
	velocity.y += gravity * delta
	var desired_velocity = get_input() * max_speed

	velocity.x = desired_velocity.x
	velocity.z = desired_velocity.z
	velocity = move_and_slide(velocity, Vector3.UP, true)
