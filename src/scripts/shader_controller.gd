class_name ShaderController extends Node2D

@export_category("Shaders")
@export_file("*.glsl") var shader_files: Array[String]
@export var shared_shader_vars: Dictionary
@export var shader_vars: Dictionary

var compute_groups: int

var bindings : Array
var rd: RenderingDevice
var uniform_set: RID
var shader_rids: Array[RID]
var pipelines: Array[RID]
var shader_params : PackedFloat32Array = []

func process_shaders() -> void:
	for pipeline in pipelines:
		_run_compute_shader(pipeline)
		_sync_gpu()

func _setup_compute_shaders() -> void:
	rd = RenderingServer.create_local_rendering_device()
	
	if rd == null:
		OS.alert("""Couldn't create local RenderingDevice on GPU: %s
Note: RenderingDevice is only available in the Forward+ and Mobile rendering methods, not Compatibility.""" % RenderingServer.get_video_adapter_name())
		return
	
	for shader_filename in shader_files:
		var shader_file := load(shader_filename)
		var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
		var shader_rid := rd.shader_create_from_spirv(shader_spirv)
		pipelines.append(rd.compute_pipeline_create(shader_rid))
		shader_rids.append(shader_rid)

func _run_compute_shader(pipeline):
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, compute_groups, 1, 1)
	rd.compute_list_end()
	rd.submit()
		
func _sync_gpu():
	rd.sync()

func cleanup_gpu() -> void:
	if rd == null:
		return
	
	for var_name in shared_shader_vars:
		rd.free_rid(shared_shader_vars[var_name].resource_id)
	
	for shader_rid in shader_rids:
		rd.free_rid(shader_rid)
	
	for pipeline in pipelines:
		rd.free_rid(pipeline)
	
	rd.free_rid(uniform_set)
	rd.free()
	
	rd = null
	
func _exit_tree():
	cleanup_gpu()
