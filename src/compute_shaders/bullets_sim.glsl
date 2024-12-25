#[compute]
#version 450

layout (local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

#include "shared_data.glsl"

void main() {
	int my_index = int(gl_GlobalInvocationID.x);
	if (my_index >= params.num_monsters) return;

	vec2 my_pos = monster_vel.data[my_index];
	vec2 my_vel = vec2(0, 1) * params.max_vel;

	my_pos += my_vel * params.delta_time;

	if (!bool(params.pause))
	{
		monster_vel.data[my_index] = my_pos;
	}

	ivec2 pixel_pos = ivec2(int(mod(my_index, params.image_size)), int(my_index / params.image_size));
	// Calculate rotation
	float my_rot = imageLoad(bullet_data, pixel_pos).b;

	imageStore(bullet_data, pixel_pos, vec4(my_pos.x, my_pos.y, my_rot, 0));
}