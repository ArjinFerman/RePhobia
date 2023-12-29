extends Node2D

var boid_data : Image
var boid_data_texture : ImageTexture

var NUM_BOIDS = 150
var IMAGE_SIZE = int(sqrt(NUM_BOIDS) + 1)

var boid_pos = []
var boid_vel = []

@export var friend_radius = 30
@export var max_vel = 50
@export var alignment_factor = 10
@export var cohesion_factor = 1
@export var separation_factor = 2

func _1d_to_2d(index_1d):
	return Vector2(int(index_1d / IMAGE_SIZE), int(index_1d % IMAGE_SIZE))

func _ready():
	boid_data = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAH)								
	boid_data_texture = ImageTexture.create_from_image(boid_data)
	
	_generate_boids()
	
	$BoidParticles.amount = NUM_BOIDS
	$BoidParticles.process_material.set_shader_parameter("boid_data", boid_data_texture)

func _generate_boids():
	for i in IMAGE_SIZE:
		for j in IMAGE_SIZE:
			boid_pos.append(Vector2(randf()*get_viewport_rect().size.x, randf()*get_viewport_rect().size.y))
			boid_vel.append(Vector2(randf_range(-1.,1.)*max_vel, randf_range(-1.,1.)*max_vel))

func _process(_delta):
	get_window().title = "Boids: " + str(NUM_BOIDS) + " FPS: " + str(Engine.get_frames_per_second())
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
		
		boid_vel[i] = boid_vel[i].normalized() * max_vel		
		boid_pos[i] += boid_vel[i] * _delta
		boid_pos[i] = Vector2(wrapf(boid_pos[i].x, 0, get_viewport_rect().size.x,),
							  wrapf(boid_pos[i].y, 0, get_viewport_rect().size.y,))
							
func _update_data_texture():
	for i in NUM_BOIDS:
		var pixel_pos = _1d_to_2d(i)
		boid_data.set_pixel(pixel_pos.x, pixel_pos.y, Color(boid_pos[i].x,boid_pos[i].y,boid_vel[i].angle(),0))
	boid_data_texture.update(boid_data)


	
