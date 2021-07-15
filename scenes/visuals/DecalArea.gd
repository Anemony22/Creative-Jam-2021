extends Area

class_name DecalArea

export(float) var normal_push = 0.01
export(int) var TIME_WAIT_MAX = 10
export(Array, NodePath) var valid_nodes_paths

export(Vector2) var scale_texture = Vector2(1, 1)
export(Vector2) var offset_texture = Vector2(0, 0)

export(Texture) var decal_texture

signal mesh_ready
signal interacted

var time_out = 0
var decal_shader = preload("decal_shader.shader")

var decal_mesh = null

enum {INSIDE, PARTIALLY, OUTSIDE}

# Based on following reference.
# Ref: https://github.com/Miziziziz/GodotProjectedDecals/blob/master/projectdecal.gd

func _physics_process(_delta):
	# Sets up for a one-time process to setup the handling of the meshes.
	var bodies = get_overlapping_bodies()
	
	if bodies and valid_nodes_paths.size() > 0:
		var area_planes = [
			Plane(Vector3.UP, 1),
			Plane(Vector3.DOWN, 1),
			Plane(Vector3.FORWARD, 1),
			Plane(Vector3.BACK, 1),
			Plane(Vector3.LEFT, 1),
			Plane(Vector3.RIGHT, 1)
		]

		# DEBUG: Adds cutting planes of the decal
		# for plane in area_planes:
		# 	var plane_visual = MeshInstance.new()
		# 	plane_visual.mesh = QuadMesh.new()

		# 	var rotation_quat = quat_rotation_vec3(plane_visual.transform.basis.z, plane.normal)
		# 	plane_visual.global_transform = Basis(rotation_quat)
		# 	plane_visual.translation = plane.center()
		# 	add_child(plane_visual)

		# Used to reinitialise mesh for moving decal.
		# if decal_mesh:
		# 	decal_texture = decal_mesh.get_surface_material(0).get_shader_param("decal")
		# 	decal_mesh.queue_free()
		# 	time_out = 0

		decal_mesh = generate_decal_mesh_instance(bodies, area_planes)

		var decal_material = ShaderMaterial.new()
		decal_material.shader = decal_shader
		decal_material.set_shader_param("decal", decal_texture)
		decal_material.set_shader_param("scale", scale_texture)
		decal_material.set_shader_param("offset", offset_texture)
		decal_mesh.set_surface_material(0, decal_material)

		add_child(decal_mesh)
		
		# for body in bodies:
		# 	body.hide()
		
		emit_signal("mesh_ready")
		
		set_physics_process(false)
	elif time_out == TIME_WAIT_MAX:
		# Free up resources if not intersecting with any bodies after the time out period expires.
		queue_free()
	else:
		time_out += 1

func update_mesh_texture(texture: Texture):
	var scale = scale_texture
	var aspect = texture.get_size().aspect()

	if aspect < 1:
		scale.x *= aspect
	elif aspect > 1:
		scale.y *= 1/aspect

	var material = decal_mesh.get_surface_material(0)
	material.set_shader_param("decal", texture)
	material.set_shader_param("scale", scale)

func update_texture_offset(offset: Vector2):
	var material = decal_mesh.get_surface_material(0)
	material.set_shader_param("offset", offset)

# Generates a new mesh instance for the decal
func generate_decal_mesh_instance(bodies, area_planes):
	var new_mesh = MeshInstance.new()

	var all_verts = PoolVector3Array()
	var all_normals = PoolVector3Array()

	for body in bodies:
		if is_valid_decal_body(body):
			var parent = find_body_mesh_parent(body)
			var mesh = parent.mesh

			if mesh.get_surface_count() > 0:
				var mesh_arrays = mesh.surface_get_arrays(0)
				# var mapped_vertices = mesh_arrays[ArrayMesh.ARRAY_VERTEX]
				var mapped_vertices = map_vertex_to_local(parent, mesh_arrays[ArrayMesh.ARRAY_VERTEX])
				mapped_vertices = rearrange_mesh_points(mapped_vertices, mesh_arrays[ArrayMesh.ARRAY_INDEX])

				# var mapped_normals = mesh_arrays[ArrayMesh.ARRAY_NORMAL]
				var mapped_normals = map_normal_to_local(parent, mesh_arrays[ArrayMesh.ARRAY_NORMAL])
				mapped_normals = rearrange_mesh_points(mapped_normals, mesh_arrays[ArrayMesh.ARRAY_INDEX])

				var pools = clip_mesh(mapped_vertices, mapped_normals, area_planes)

				var clipped_verts = pools[0]
				var new_normals = pools[1]

				clipped_verts = push_vertices(clipped_verts, new_normals)

				all_verts.append_array(clipped_verts)
				all_normals.append_array(new_normals)

	var clipped_mesh_arrays = []
	clipped_mesh_arrays.resize(ArrayMesh.ARRAY_MAX)
	clipped_mesh_arrays[ArrayMesh.ARRAY_VERTEX] = all_verts
	clipped_mesh_arrays[ArrayMesh.ARRAY_NORMAL] = all_normals
	clipped_mesh_arrays[ArrayMesh.ARRAY_TEX_UV] = vertex_to_uv(all_verts)

	var array_mesh = ArrayMesh.new()

	array_mesh.add_surface_from_arrays(ArrayMesh.PRIMITIVE_TRIANGLES, clipped_mesh_arrays)

	new_mesh.mesh = array_mesh

	return new_mesh

# True if this body will have the decal.
func is_valid_decal_body(body):
	var is_valid = false

	for node_path in valid_nodes_paths:
		var node = get_node(node_path)

		if body == node:
			is_valid = true
			break

	return is_valid

# Find the mesh of the body to be processed
func find_body_mesh_parent(body):
	for child in body.get_children():
		if "mesh" in child:
			return child

func map_vertex_to_local(old_frame, vertices):
	var mapped_verts = PoolVector3Array()

	for vert in vertices:
		mapped_verts.append(to_local(old_frame.to_global(vert)))

	return mapped_verts

func map_normal_to_local(old_frame, normals):
	var mapped_normals = PoolVector3Array()

	for normal in normals:
		var normal_in_global = old_frame.to_global(normal) - old_frame.global_transform.origin
		var new_normal = to_local(normal_in_global + global_transform.origin)
		new_normal.x /= scale.x
		new_normal.y /= scale.y
		new_normal.z /= scale.z

		mapped_normals.append(new_normal)

	return mapped_normals

# Gets the clipped mesh within given planes.
func clip_mesh(mesh_verts, mesh_normals, area_planes):

	var new_vert_pool = PoolVector3Array()
	var new_normal_pool = PoolVector3Array()

	for i in range(0, mesh_verts.size(), 3):
		# if mesh_normals[i].dot(Vector3.BACK) > 0:
		var tmp_vert_pool = PoolVector3Array()
		tmp_vert_pool.append(mesh_verts[i])
		tmp_vert_pool.append(mesh_verts[i + 1])
		tmp_vert_pool.append(mesh_verts[i + 2])

		var tmp_normal_pool = PoolVector3Array()
		tmp_normal_pool.append(mesh_normals[i])
		tmp_normal_pool.append(mesh_normals[i + 1])
		tmp_normal_pool.append(mesh_normals[i + 2])

		var status = is_in_area(tmp_vert_pool, area_planes)

		if status == INSIDE:
			new_vert_pool.append_array(tmp_vert_pool)
			new_normal_pool.append_array(tmp_normal_pool)
		elif status == PARTIALLY:
			var pools = clip_triangle(tmp_vert_pool, tmp_normal_pool, area_planes)

			var verts = pools[0]
			var normals = pools[1]

			status = is_in_area(verts, area_planes)
			
			if status == INSIDE or PARTIALLY:
				new_vert_pool.append_array(verts)
				new_normal_pool.append_array(normals)
				
	return [new_vert_pool, new_normal_pool]

func is_in_area(vertices, area_planes):
	var sided_count = []
	for planes in area_planes:
		sided_count.append(0)

	for vert in vertices:
		for i in area_planes.size():
			if vert.dot(area_planes[i].normal) > area_planes[i].d + 0.001:
				sided_count[i] += 1

	if sided_count.count(0) == area_planes.size():
		return INSIDE
	elif sided_count.count(vertices.size()) > 0:
		return OUTSIDE
	else:
		return PARTIALLY

# Given a set of planes, find the triangles that exist within the volume of the planes
func clip_triangle(vertices, normals, area_planes):
	var resulting_vert_pool = PoolVector3Array()
	var resulting_normal_pool = PoolVector3Array()
	var clip_pool = PoolVector3Array()

	for plane in area_planes:
		var new_verts = Geometry.clip_polygon(vertices, plane)

		if new_verts.size() == 3:
			vertices = new_verts
		elif new_verts.size() == 4:
			clip_pool.append(new_verts[0])
			clip_pool.append(new_verts[2])
			clip_pool.append(new_verts[3])
			new_verts.resize(3)
			clip_pool.append_array(new_verts)
	
	if clip_pool.empty():
		resulting_vert_pool.append_array(vertices)
		resulting_normal_pool.append_array(normals)
	else:
		for i in range(0, clip_pool.size(), 3):
			var tmp_pool = PoolVector3Array()
			tmp_pool.append(clip_pool[i])
			tmp_pool.append(clip_pool[i + 1])
			tmp_pool.append(clip_pool[i + 2])
			var pools = clip_triangle(tmp_pool, normals, area_planes)

			resulting_vert_pool.append_array(pools[0])
			resulting_normal_pool.append_array(pools[1])

	return [resulting_vert_pool, resulting_normal_pool]

func rearrange_mesh_points(vect_pool, indices):
	var reordered_pool = PoolVector3Array()

	for i in range(indices.size()):
		reordered_pool.append(vect_pool[indices[i]])

	return reordered_pool

func vertex_to_uv(vertices):
	var uv_pool = PoolVector2Array()

	for vert in vertices:
		var uv = Vector2()
		# uv.x = (vert.x / scale.x) * scale_texture.x
		# uv.y = (vert.y / scale.y) * scale_texture.y
		uv.x = vert.x * scale.x * 0.5
		uv.y = -vert.y * scale.y * 0.5
		uv_pool.append(uv)

	return uv_pool

func push_vertices(vertices, normals):
	var map_vert_normals = {}

	for i in vertices.size():
		if not vertices[i] in map_vert_normals:
			map_vert_normals[vertices[i]] = normals[i]
		else:
			map_vert_normals[vertices[i]] += normals[i]

	for i in vertices.size():
		var n = map_vert_normals[vertices[i]].normalized()
		vertices[i] += n * normal_push

	return vertices

func generate_key(vector):
	return str(vector)

func quat_rotation_vec3(from_v, to_v):
	var angle = from_v.angle_to(to_v)
	var axis = from_v.cross(to_v)

	if axis.length() <= 0:
		axis = Vector3(to_v.y + to_v.z, to_v.x, to_v.x)
	
	return Quat(axis.normalized(), angle)
