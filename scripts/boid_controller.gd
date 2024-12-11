class_name BoidController extends ShaderController
var DEBUG_LOG = false

var NUM_BOIDS = 1024
var delta : float = 0
var boid_pos : PackedVector2Array = []
var boid_vel : PackedVector2Array = []

var IMAGE_SIZE = int(ceil(sqrt(NUM_BOIDS)))
var boid_data : Image
var boid_data_texture : ImageTexture

@export_category("Boid Settings")
@export_range(0.1, 10) var boid_scale: float = 0.5:
	set(new_scale):
		boid_scale = new_scale
		if is_inside_tree():
			$BoidParticles.process_material.set_shader_parameter("scale", boid_scale)

@export_range(0.1, 10) var collision_radius = 1.0
@export_range(0, 1.8) var collision_factor = 1.0
@export_range(0,100) var max_vel = 75.0

@export_category("Rendering")
@export var boid_color = Color(Color.WHITE) :
	set(new_color):
		boid_color = new_color
		if is_inside_tree():
			$BoidParticles.process_material.set_shader_parameter("color", boid_color)

enum BoidColorMode {SOLID, COLLISIONS}
@export var boid_color_mode : BoidColorMode :
	set(new_color_mode):
		boid_color_mode = new_color_mode
		if is_inside_tree():
			$BoidParticles.process_material.set_shader_parameter("color_mode", boid_color_mode)

@export var bin_grid = false:
	set(new_grid):
		bin_grid = new_grid
		if is_inside_tree():
			$Grid.visible = bin_grid

@export_category("Other")
@export var pause = false :
	set(new_value):
		pause = new_value

# BIN Variable
var BIN_SIZE = 128
var BINS = Vector2i.ZERO
var NUM_BINS = 0

func _ready():	
	boid_data = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAH)
	boid_data_texture = ImageTexture.create_from_image(boid_data)
	
	boid_color = boid_color
	boid_color_mode = boid_color_mode
	boid_scale = boid_scale
	bin_grid = bin_grid
	
	BINS = Vector2i(snapped(get_viewport_rect().size.x / BIN_SIZE + .4,1),
					snapped(get_viewport_rect().size.y / BIN_SIZE + .4,1))
	NUM_BINS = BINS.x * BINS.y
	
	$Grid.bin_size = BIN_SIZE
	$Grid.bins_x = BINS.x
	$Grid.bins_y = BINS.y
	
	print(NUM_BINS)
	
	_generate_boids()
	
	if DEBUG_LOG:
		for i in boid_pos.size():
			print("Boid: ", i, " Pos: ", boid_pos[i], " Vel: ", boid_vel[i])
	
	$BoidParticles.amount = NUM_BOIDS
	$BoidParticles.process_material.set_shader_parameter("boid_data", boid_data_texture)

	_setup_compute_shaders()
	_update_shader_params(0)

func _generate_boids():
	for i in NUM_BOIDS:
		boid_pos.append(Vector2(randf() * get_viewport_rect().size.x, randf()  * get_viewport_rect().size.y))
		boid_vel.append(Vector2(randf_range(-1.0, 1.0) * max_vel, randf_range(-1.0, 1.0) * max_vel))

func _process(delta):	
	get_window().title = "GPU: / Boids: " + str(NUM_BOIDS) + " / FPS: " + str(Engine.get_frames_per_second())
	
	_update_data_texture()
	_update_shader_params(delta)
	process_shaders()

func _update_data_texture():
	var boid_data_image_data := rd.texture_get_data(shared_shader_vars["boid_data_buffer"].resource_id, 0)
	boid_data.set_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAH, boid_data_image_data)
	boid_data_texture.update(boid_data)

func _update_shader_params(delta):
	var shader_params_bytes = prepare_shader_params(delta).to_byte_array()
	rd.buffer_update(shared_shader_vars["params_buffer"].resource_id, 0, shader_params_bytes.size(), shader_params_bytes)

func _setup_compute_shaders():
	super()
	
	shader_params = prepare_shader_params(0)
	shared_shader_vars["boid_pos_buffer"] = ShaderVariable.create_buffer(rd, 0, boid_pos)
	shared_shader_vars["boid_vel_buffer"] = ShaderVariable.create_buffer(rd, 1, boid_vel)
	shared_shader_vars["params_buffer"] = ShaderVariable.create_buffer(rd, 2, shader_params)
	
	var fmt := RDTextureFormat.new()
	fmt.width = IMAGE_SIZE
	fmt.height = IMAGE_SIZE
	fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var num_boids_array = PackedInt32Array()
	var num_bins_array = PackedInt32Array()
	num_boids_array.resize(NUM_BOIDS)
	num_bins_array.resize(NUM_BINS)
	
	shared_shader_vars["boid_data_buffer"] = ShaderVariable.create_texture(rd, 3, fmt, [boid_data.get_data()])
	shared_shader_vars["bin_params_buffer"] = ShaderVariable.create_buffer(rd, 4, PackedInt32Array([BIN_SIZE, BINS.x, BINS.y, NUM_BINS]))
	shared_shader_vars["bin_buffer"] = ShaderVariable.create_buffer(rd, 5, num_boids_array)
	shared_shader_vars["bin_sum_buffer"] = ShaderVariable.create_buffer(rd, 6, num_bins_array)
	shared_shader_vars["bin_prefix_sum_buffer"] = ShaderVariable.create_buffer(rd, 7, num_bins_array)
	shared_shader_vars["bin_index_tracker_buffer"] = ShaderVariable.create_buffer(rd, 8, num_bins_array)
	shared_shader_vars["bin_reindex_buffer"] = ShaderVariable.create_buffer(rd, 9, num_boids_array)
	
	bindings = [shared_shader_vars["boid_pos_buffer"].uniform,
				shared_shader_vars["boid_vel_buffer"].uniform,
				shared_shader_vars["params_buffer"].uniform,
				shared_shader_vars["boid_data_buffer"].uniform,
				shared_shader_vars["bin_params_buffer"].uniform,
				shared_shader_vars["bin_buffer"].uniform,
				shared_shader_vars["bin_sum_buffer"].uniform,
				shared_shader_vars["bin_prefix_sum_buffer"].uniform,
				shared_shader_vars["bin_index_tracker_buffer"].uniform,
				shared_shader_vars["bin_reindex_buffer"].uniform]
	
	uniform_set = rd.uniform_set_create(bindings, shader_rids.back(), 0)
	compute_groups = ceil(NUM_BOIDS/1024.)

func prepare_shader_params(delta: float) -> PackedFloat32Array:
	var playerPos: Vector2 = $".."/Marine.transform.origin
	return PackedFloat32Array(
		[NUM_BOIDS, 
		IMAGE_SIZE,
		boid_scale,
		collision_radius,
		collision_factor,
		max_vel,
		playerPos.x,
		playerPos.y,
		delta,
		pause,
		boid_color_mode])
