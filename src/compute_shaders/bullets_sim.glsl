#[compute]
#version 450

layout (local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

#include "shared_data.glsl"

float BULLET_SPEED = 1000;

void main() {
	if (bool(params.pause))
		return;

	int my_index = int(gl_GlobalInvocationID.x);
	if (my_index >= params.num_monsters) return;

	ivec2 pixel_pos = one_to_two(my_index, int(params.image_size));
	vec4 my_data = imageLoad(bullet_data, pixel_pos);
	vec2 my_pos = my_data.xy;
	vec2 my_vel = vec2(0,0);
	float my_rot = my_data.z;
	float my_lifetime = my_data.w;

	if (my_lifetime < 0) {
		if ((int(params.game_time*4) + my_index) % 1024 == 0) {
			my_lifetime = 0.0;
			my_pos = vec2(params.weapon_pos_x, params.weapon_pos_y);
			my_vel = vec2(params.weapon_dir_x, params.weapon_dir_y);

			// Calculate rotation
			my_rot = acos(dot(my_vel, vec2(1, 0)));
			if (isnan(my_rot)) {
				my_rot = 0.0;
			} else if (my_vel.y < 0) {
				my_rot = -my_rot;
			}

			my_vel *= BULLET_SPEED;
		}
	} else {
		my_vel = vec2(cos(my_rot), sin(my_rot)) * BULLET_SPEED;
		my_pos += my_vel * params.delta_time;
		my_lifetime += params.delta_time;
	}

	//monster_vel.data[my_index] = my_pos;
	imageStore(bullet_data, pixel_pos, vec4(my_pos.x, my_pos.y, my_rot, my_lifetime));
}