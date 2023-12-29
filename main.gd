extends Node2D

var boid_data : Image
var boid_data_texture : ImageTexture

var NUM_BOIDS = 22000
var IMAGE_SIZE = int(sqrt(NUM_BOIDS) + 1)

var boid_pos = []
var boid_vel = []

@export_range(0, 50) var friend_radius = 30
@export_range(0,100) var min_vel = 25
@export_range(0,100) var max_vel = 50
@export_range(0,100) var alignment_factor = 10
@export_range(0,100) var cohesion_factor = 1
@export_range(0,100) var separation_factor = 2

# GPU Variables
var SIMULATE_GPU = true
var rd := RenderingServer.create_local_rendering_device()
var params_uniform : RDUniform
var params_buffer: RID
var boid_data_buffer : RID
var bindings : Array
var boid_compute_shader : RID
var pipeline : RID
var uniform_set : RID

func _1d_to_2d(index_1d):
	return Vector2(int(index_1d / IMAGE_SIZE), int(index_1d % IMAGE_SIZE))

func _ready():
	boid_data = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAH)								
	boid_data_texture = ImageTexture.create_from_image(boid_data)
	
	_generate_boids()
	
	$BoidParticles.amount = NUM_BOIDS
	$BoidParticles.process_material.set_shader_parameter("boid_data", boid_data_texture)

	if SIMULATE_GPU:
		_setup_compute_shader()

func _generate_boids():
	for i in IMAGE_SIZE:
		for j in IMAGE_SIZE:
			boid_pos.append(Vector2(randf()*get_viewport_rect().size.x, randf()*get_viewport_rect().size.y))
			boid_vel.append(Vector2(randf_range(-1.,1.)*max_vel, randf_range(-1.,1.)*max_vel))

func _process(_delta):
	get_window().title = "Boids: " + str(NUM_BOIDS) + " FPS: " + str(Engine.get_frames_per_second())
	
	if SIMULATE_GPU:
		_update_boids_gpu(_delta)
	else:
		_update_boids_cpu(_delta)
		
	_update_data_texture()

func _update_boids_cpu(_delta):
	for i in NUM_BOIDS:
		var current_boid = boid_pos[i]
		var average_vel = Vector2.ZERO
		var midpoint = Vector2.ZERO
		var separation_vec = Vector2.ZERO
		var num_friends = 0
		for j in NUM_BOIDS:
			if i != j:
				var other_boid = boid_pos[j]
				var dist = current_boid.distance_to(other_boid)
				if(dist < friend_radius):
					num_friends += 1
					average_vel += boid_vel[j]
					midpoint += other_boid
					separation_vec += current_boid - other_boid
		if(num_friends > 0):
			average_vel /= num_friends
			boid_vel[i] += (average_vel - boid_vel[i]).normalized() * alignment_factor
			
			midpoint /= num_friends
			boid_vel[i] += (midpoint - current_boid).normalized() * cohesion_factor
			
			separation_vec /= num_friends
			boid_vel[i] += separation_vec.normalized() * separation_factor
		
		var vel_mag = boid_vel[i].length()
		vel_mag = clamp(vel_mag, min_vel, max_vel)
		boid_vel[i] = boid_vel[i].normalized() * vel_mag		
		boid_pos[i] += boid_vel[i] * _delta
		boid_pos[i] = Vector2(wrapf(boid_pos[i].x, 0, get_viewport_rect().size.x,),
							  wrapf(boid_pos[i].y, 0, get_viewport_rect().size.y,))
							
func _update_data_texture():
	if SIMULATE_GPU:
		var boid_data_image_data := rd.texture_get_data(boid_data_buffer, 0)
		boid_data.set_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAH, boid_data_image_data)
	else:
		for i in NUM_BOIDS:
			var pixel_pos = _1d_to_2d(i)
			boid_data.set_pixel(pixel_pos.x, pixel_pos.y, Color(boid_pos[i].x,boid_pos[i].y,boid_vel[i].angle(),0))
			
	boid_data_texture.update(boid_data)

func _setup_compute_shader():
	var shader_file := load("res://compute_shaders/boid_simulation.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	boid_compute_shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(boid_compute_shader)
	
	var boid_pos_buffer = _generate_vec2_buffer(boid_pos)
	var boid_pos_uniform = _generate_uniform(boid_pos_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)
	
	var boid_vel_buffer = _generate_vec2_buffer(boid_vel)
	var boid_vel_uniform = _generate_uniform(boid_vel_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)
	
	params_buffer = _generate_parameter_buffer(0)
	params_uniform = _generate_uniform(params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)
	
	var fmt := RDTextureFormat.new()
	fmt.width = IMAGE_SIZE
	fmt.height = IMAGE_SIZE
	fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var view := RDTextureView.new()
	boid_data_buffer = rd.texture_create(fmt, view, [boid_data.get_data()])
	var boid_data_buffer_uniform = _generate_uniform(boid_data_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 3)
	
	bindings = [boid_pos_uniform, boid_vel_uniform, params_uniform,boid_data_buffer_uniform]
	
func _generate_vec2_buffer(data):
	var data_buffer_bytes := PackedVector2Array(data).to_byte_array()
	var data_buffer = rd.storage_buffer_create(data_buffer_bytes.size(), data_buffer_bytes)
	return data_buffer

func _generate_uniform(data_buffer, type, binding):
	var data_uniform = RDUniform.new()
	data_uniform.uniform_type = type
	data_uniform.binding = binding
	data_uniform.add_id(data_buffer)
	return data_uniform

func _generate_parameter_buffer(delta):
	var params_buffer_bytes : PackedByteArray = PackedFloat32Array(
		[NUM_BOIDS, 
		IMAGE_SIZE, 
		friend_radius,
		min_vel, 
		max_vel,
		alignment_factor,
		cohesion_factor,
		separation_factor,
		get_viewport_rect().size.x,
		get_viewport_rect().size.y,
		delta]).to_byte_array()
	
	return rd.storage_buffer_create(params_buffer_bytes.size(), params_buffer_bytes)

func _update_boids_gpu(delta):
	rd.free_rid(params_buffer)
	params_buffer = _generate_parameter_buffer(delta)
	params_uniform.clear_ids()
	params_uniform.add_id(params_buffer)
	uniform_set = rd.uniform_set_create(bindings, boid_compute_shader, 0)
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	
	rd.compute_list_dispatch(compute_list, ceil(NUM_BOIDS/1024.), 1, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
