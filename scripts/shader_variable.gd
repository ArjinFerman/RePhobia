class_name ShaderVariable

var resource_id: RID
var uniform: RDUniform

static func create_texture(rd: RenderingDevice, bindingId: int, format: RDTextureFormat, 
		data: Array[PackedByteArray] = []) -> ShaderVariable:
	# The TextureUsageBits are stored as 'bit fields', denoting what can be done with the data.
	# Because of how bit fields work, we can just sum the required ones: 8 + 64 + 128
	format.usage_bits = \
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	# Prepare heightmap texture. We will set the data later.
	var shader_var = ShaderVariable.new()
	shader_var.resource_id = rd.texture_create(format, RDTextureView.new(), data)
	
	shader_var.uniform = RDUniform.new()
	shader_var.uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	shader_var.uniform.binding = bindingId  # This matches the binding in the shader.
	shader_var.uniform.add_id(shader_var.resource_id)
	
	return shader_var
	
static func create_buffer(rd: RenderingDevice, bindingId: int, buffer) -> ShaderVariable:
	# Create a storage buffer that can hold our float values.
	# Each float has 4 bytes (32 bit) so 10 x 4 = 40 bytes
	var shader_var = ShaderVariable.new()
	var buffer_bytes = buffer.to_byte_array()
	shader_var.resource_id = rd.storage_buffer_create(buffer_bytes.size(), buffer_bytes)
	# Create a uniform to assign the buffer to the rendering device
	shader_var.uniform = RDUniform.new()
	shader_var.uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	shader_var.uniform.binding = bindingId # this needs to match the "binding" in our shader file
	shader_var.uniform.add_id(shader_var.resource_id)
	
	return shader_var
	
static func create_vec3(rd: RenderingDevice, bindingId: int, buffer) -> ShaderVariable:
	# Create a storage buffer that can hold our float values.
	# Each float has 4 bytes (32 bit) so 10 x 4 = 40 bytes
	var shader_var = ShaderVariable.new()
	var buffer_bytes = buffer.to_byte_array()
	shader_var.resource_id = rd.storage_buffer_create(buffer_bytes.size(), buffer_bytes)
	# Create a uniform to assign the buffer to the rendering device
	shader_var.uniform = RDUniform.new()
	shader_var.uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	shader_var.uniform.binding = bindingId # this needs to match the "binding" in our shader file
	shader_var.uniform.add_id(shader_var.resource_id)
	
	return shader_var
