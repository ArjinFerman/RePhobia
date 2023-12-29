shader_type particles;
uniform sampler2D boid_data;
uniform float scale = .5;

void process() {
	ivec2 pos_image_size = textureSize(boid_data, 0);
	ivec2 row_col = ivec2( int(float(INDEX)/float(pos_image_size.y)), 
						   int(mod(float(INDEX),float(pos_image_size.x))));
	vec4 boid_pos_rot = texelFetch(boid_data, row_col, 0);
	
	mat2 scale_rot_mat = mat2(vec2(cos(boid_pos_rot.b), sin(boid_pos_rot.b)),
							  vec2(-sin(boid_pos_rot.b), cos(boid_pos_rot.b)));
	scale_rot_mat *= scale;
	TRANSFORM[0].xy = scale_rot_mat[0];
	TRANSFORM[1].xy = scale_rot_mat[1];
	TRANSFORM[3].xy = vec2(boid_pos_rot.r, boid_pos_rot.g); 
}
