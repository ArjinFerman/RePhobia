#[compute]
#version 450

layout (local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

#include "shared_data.glsl"

void main() {
	int my_index = int(gl_GlobalInvocationID.x);
	if (my_index >= params.num_monsters) return;

	bool use_bins = true;
	int num_friends = 0;
	int color_mode = int(params.color_mode);
	float collision_radius = 5.0 * params.collision_radius;
	float massFactor = 0.50;

	my_index = bin_reindex.data[my_index];
	vec2 my_pos = monster_pos.data[my_index];
	vec2 my_col_shift = vec2(0, 0);

	int my_bin = bin.data[my_index];

	vec2 my_bin_x_y = one_to_two(my_bin, bin_params.bins_x);
	vec2 starting_bin = my_bin_x_y - vec2(1, 1);
	vec2 current_bin = starting_bin;
	float collision_count = 0;
	float collision_factor = params.collision_factor;

	for (int y = 0; y < 3; y++) {
		current_bin.y = starting_bin.y + y;
		if (current_bin.y < 0 || current_bin.y > bin_params.bins_y) continue;

		for (int x = 0; x < 3; x++) {
			current_bin.x = starting_bin.x + x;
			if (current_bin.x < 0 || current_bin.x > bin_params.bins_x) continue;

			int bin_index = two_to_one(current_bin, bin_params.bins_x);
			for (int i = bin_prefix_sum.data[bin_index - 1]; i < bin_prefix_sum.data[bin_index]; i++) {

				int detection_type = 1;
				int other_index = bin_reindex.data[i];

				if(my_index != other_index) {
					vec2 other_pos = monster_pos.data[other_index];

					vec2 themToMe = my_pos - other_pos;
					float radiusSum = collision_radius + collision_radius;
					float dist = length(themToMe) + 0.00001;
					float distCondition = step(dist, radiusSum); // No reaction if distance greater than 2x monster radius;

					collision_count += distCondition;
					my_col_shift += themToMe * (radiusSum/dist - 1) * massFactor * distCondition;
				}
			}
		}
	}

	vec2 my_vel = vec2(params.player_pos_x, params.player_pos_y) - my_pos;
	float vel_mag = length(my_vel);
	float my_col_shift_mag = length(my_col_shift);

	if (my_col_shift_mag > 0 && vel_mag > 0 && collision_count > 0) {
		my_col_shift *= (1+abs(cross(vec3(my_col_shift/my_col_shift_mag, 0), vec3(my_vel/vel_mag, 0)).z)/(collision_count*2-collision_factor));
		my_vel *= dot(my_col_shift/my_col_shift_mag, my_vel/vel_mag);
	}

	if (vel_mag > 0) {
		vel_mag = clamp(vel_mag, params.max_vel, params.max_vel);
		my_vel = normalize(my_vel) * vel_mag;
	}

	my_pos += my_col_shift;
	my_pos += my_vel * params.delta_time;

	if (!bool(params.pause))
	{
		monster_pos.data[my_index] = my_pos;
	}
	bin.data[my_index] = int(my_pos.x / bin_params.bin_size) + int(my_pos.y / bin_params.bin_size) * bin_params.bins_x;

	ivec2 pixel_pos = ivec2(int(mod(my_index, params.image_size)), int(my_index / params.image_size));
	//ivec2 pixel_pos = ivec2(my_bin_x_y);
	// Calculate rotation
	float my_rot = imageLoad(monster_data, pixel_pos).b;
	if (length(my_vel) > 0 && length(my_col_shift) <= 0) {
		vec2 norm_vel = normalize(my_vel);
		vec2 target = vec2(1, 0);
		float det = target.x*norm_vel.y - target.y*norm_vel.x;
		my_rot = atan(det, dot(norm_vel, target));
	}

	switch (color_mode) {
		case 0:
		case 1:
			imageStore(monster_data, pixel_pos, vec4(my_pos.x, my_pos.y, my_rot, collision_count));
			break;
	}
}