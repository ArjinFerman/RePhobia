shader_type particles;
uniform sampler2D bullet_data;
uniform float scale = 0.5;
uniform vec4 color : source_color;
uniform uint color_mode;

void process() {
	ivec2 pos_image_size = textureSize(bullet_data, 0);

	ivec2 texel_pos = ivec2(int(mod(float(INDEX),float(pos_image_size.x))),
							int(float(INDEX)/float(pos_image_size.x)));

	vec4 bullet_pos_rot = texelFetch(bullet_data, texel_pos, 0);

	mat2 scale_rot_mat = mat2(vec2(cos(bullet_pos_rot.b), sin(bullet_pos_rot.b)), // First column
							  vec2(-sin(bullet_pos_rot.b), cos(bullet_pos_rot.b))); // Second column

	scale_rot_mat[0] *= scale;
	scale_rot_mat[1] *= scale;

    VELOCITY = vec3(0,0,0);

	TRANSFORM[0].xy = scale_rot_mat[0];
	TRANSFORM[1].xy = scale_rot_mat[1];
	TRANSFORM[3].xy = vec2(bullet_pos_rot.r, bullet_pos_rot.g);

	switch(color_mode){
		case 0:
			COLOR = color;
			break;
		case 1:
			COLOR = vec4(1.0, 1.0-bullet_pos_rot.a/6.0, 1.0-bullet_pos_rot.a, 1);
			break;
	}
}
