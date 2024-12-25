extends GPUParticles2D

var controller : ShaderController

func _ready() -> void:
	controller = $".."
	await controller.ready
	
	amount = controller.NUM_MONSTERS
	process_material.set_shader_parameter("monster_data", controller.monster_data_texture)

func _on_shader_controller_property_changed() -> void:
	process_material.set_shader_parameter("scale", controller.monster_scale)
	process_material.set_shader_parameter("color", controller.monster_color)
	process_material.set_shader_parameter("color_mode", controller.monster_color_mode)
