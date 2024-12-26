class_name MonsterController extends ShaderController
var DEBUG_LOG = false

var game_time = 0.0
var BIN_SIZE = 128
var BINS = Vector2i.ZERO
var NUM_BINS = 0

var NUM_MONSTERS = 1024

var IMAGE_SIZE = int(ceil(sqrt(NUM_MONSTERS)))
var monster_data : Image
var monster_data_texture : ImageTexture
var bullet_data : Image
var bullet_data_texture : ImageTexture

signal property_changed

@export_category("Monster Settings")
@export_range(0.1, 10) var monster_scale: float = 0.5:
	set(new_scale):
		monster_scale = new_scale
		property_changed.emit()

@export_range(0.1, 10) var collision_radius = 1.0
@export_range(0, 1.8) var collision_factor = 1.0
@export_range(0,100) var max_vel = 75.0

@export_category("Rendering")
@export var monster_color = Color(Color.WHITE):
	set(new_color):
		monster_color = new_color
		property_changed.emit()

enum MonsterColorMode {SOLID, COLLISIONS}
@export var monster_color_mode : MonsterColorMode:
	set(new_color_mode):
		monster_color_mode = new_color_mode
		property_changed.emit()

@export var bin_grid = false:
	set(new_grid):
		bin_grid = new_grid
		property_changed.emit()

@export_category("Other")
@export var pause = false

func _ready():
	bullet_data = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF)
	bullet_data_texture = ImageTexture.create_from_image(bullet_data)
	
	monster_data = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF)
	monster_data_texture = ImageTexture.create_from_image(monster_data)
	
	monster_color = monster_color
	monster_color_mode = monster_color_mode
	monster_scale = monster_scale
	bin_grid = bin_grid
	
	BINS = Vector2i(snapped(get_viewport_rect().size.x / BIN_SIZE + .4,1),
					snapped(get_viewport_rect().size.y / BIN_SIZE + .4,1))
	NUM_BINS = BINS.x * BINS.y
	
	_generate_monsters()

	_setup_compute_shaders()
	_update_shader_params(0)

func _generate_monsters():
	var bullets : PackedFloat32Array
	var monsters : PackedFloat32Array
	for i in NUM_MONSTERS:
		monsters.append_array([randf() * get_viewport_rect().size.x, randf()  * get_viewport_rect().size.y, 0.0, 0.0])
		bullets.append_array([-1.0, -1.0, -1.0, -1.0])
	
	monster_data.set_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF, monsters.to_byte_array())
	monster_data_texture.update(monster_data)
	
	bullet_data.set_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF, bullets.to_byte_array())
	bullet_data_texture.update(bullet_data)

func _process(delta):
	get_window().title = "GPU: / Monsters: " + str(NUM_MONSTERS) + " / FPS: " + str(Engine.get_frames_per_second())
	game_time += delta
	
	_update_data_texture("monster_data_buffer", monster_data, monster_data_texture)
	_update_data_texture("bullet_data_buffer", bullet_data, bullet_data_texture)
	_update_shader_params(delta)
	process_shaders()

func _update_data_texture(shader_var_name, image, image_texture):
	var image_data := rd.texture_get_data(shared_shader_vars[shader_var_name].resource_id, 0)
	image.set_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF, image_data)
	image_texture.update(image)

func _update_shader_params(delta):
	var shader_params_bytes = prepare_shader_params(delta).to_byte_array()
	rd.buffer_update(shared_shader_vars["params_buffer"].resource_id, 0, shader_params_bytes.size(), shader_params_bytes)

func _setup_compute_shaders():
	super()
	
	shader_params = prepare_shader_params(0)
	shared_shader_vars["params_buffer"] = ShaderVariable.create_buffer(rd, 0, shader_params)
	
	var fmt := RDTextureFormat.new()
	fmt.width = IMAGE_SIZE
	fmt.height = IMAGE_SIZE
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var num_monsters_array = PackedInt32Array()
	var num_bins_array = PackedInt32Array()
	num_monsters_array.resize(NUM_MONSTERS)
	num_bins_array.resize(NUM_BINS)
	
	shared_shader_vars["bin_params_buffer"] = ShaderVariable.create_buffer(rd, 1, PackedInt32Array([BIN_SIZE, BINS.x, BINS.y, NUM_BINS]))
	shared_shader_vars["bin_buffer"] = ShaderVariable.create_buffer(rd, 2, num_monsters_array)
	shared_shader_vars["bin_sum_buffer"] = ShaderVariable.create_buffer(rd, 3, num_bins_array)
	shared_shader_vars["bin_prefix_sum_buffer"] = ShaderVariable.create_buffer(rd, 4, num_bins_array)
	shared_shader_vars["bin_index_tracker_buffer"] = ShaderVariable.create_buffer(rd, 5, num_bins_array)
	shared_shader_vars["bin_reindex_buffer"] = ShaderVariable.create_buffer(rd, 6, num_monsters_array)
	shared_shader_vars["monster_data_buffer"] = ShaderVariable.create_texture(rd, 7, fmt, [monster_data.get_data()])
	shared_shader_vars["bullet_data_buffer"] = ShaderVariable.create_texture(rd, 8, fmt, [bullet_data.get_data()])
	
	bindings = [
		shared_shader_vars["params_buffer"].uniform,
		shared_shader_vars["monster_data_buffer"].uniform,
		shared_shader_vars["bin_params_buffer"].uniform,
		shared_shader_vars["bin_buffer"].uniform,
		shared_shader_vars["bin_sum_buffer"].uniform,
		shared_shader_vars["bin_prefix_sum_buffer"].uniform,
		shared_shader_vars["bin_index_tracker_buffer"].uniform,
		shared_shader_vars["bin_reindex_buffer"].uniform,
		shared_shader_vars["bullet_data_buffer"].uniform,
	]
	
	uniform_set = rd.uniform_set_create(bindings, shader_rids.back(), 0)
	compute_groups = ceil(NUM_MONSTERS/1024.)

func prepare_shader_params(delta: float) -> PackedFloat32Array:
	var playerPos: Vector2 = $".."/Marine.global_position
	var weaponLight: Transform2D = $".."/Marine/WeaponSprite/WeaponLight.global_transform
	return PackedFloat32Array([
		NUM_MONSTERS,
		IMAGE_SIZE,
		monster_scale,
		collision_radius,
		collision_factor,
		max_vel,
		playerPos.x,
		playerPos.y,
		game_time,
		delta,
		pause,
		monster_color_mode,
		weaponLight.origin.x,
		weaponLight.origin.y,
		-weaponLight.y.x,
		-weaponLight.y.y,
	])
