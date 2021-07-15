extends Spatial

# Exports for the decal component
export(Array, NodePath) var valid_nodes_paths

export(Vector2) var decal_scale = Vector2(1, 1)
export(Vector2) var decal_offset = Vector2(0, 0)

# Exports for the animation component
export(String) var animation_name
export(SpriteFrames) var frames

var decal_area : DecalArea
var sprite_animator : AnimatedSprite

# Called when the node enters the scene tree for the first time.
func _ready():
	# Setup the decal
	decal_area = $Decal
	
	decal_area.scale = scale
	
	# Removes the scaling from the node (only used for visual purposes)
	scale = Vector3(1, 1 , 1)
	
	var root_paths = []
	for path in valid_nodes_paths:
		root_paths.append(get_node(path).get_path())
	
	decal_area.valid_nodes_paths = root_paths
	decal_area.scale_texture = decal_scale
	decal_area.offset_texture = decal_offset
	
	# Setup the animator
	sprite_animator = $AnimatedSprite
	
	sprite_animator.animation = animation_name
	sprite_animator.frames = frames


func _on_AnimatedSprite_frame_changed():
	update_decal()


func _on_Decal_mesh_ready():
	update_decal()


func update_decal():
	var current_frame = sprite_animator.frame
	var sprite_frames = sprite_animator.frames
	
	var sprite_texture = sprite_frames.get_frame(animation_name, current_frame)
	
	decal_area.update_mesh_texture(sprite_texture)


func stop():
	sprite_animator.stop()


func play():
	sprite_animator.play(animation_name)


func _on_Decal_interacted():
	if sprite_animator.playing:
		stop()
	else:
		play()
