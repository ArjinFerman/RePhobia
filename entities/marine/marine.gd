extends Node2D

@export_category("Player Properties")
@export_range(0,2) var movement_speed = 1.0
@export_range(0,0.1) var rotation_speed = 0.005

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if Input.is_action_pressed("ui_up"):
		transform = transform.translated(-transform.y*movement_speed)
	elif Input.is_action_pressed("ui_down"):
		transform = transform.translated(transform.y*movement_speed)
		
	if Input.is_action_pressed("ui_left"):
		transform = transform.rotated_local(-rotation_speed)
	elif Input.is_action_pressed("ui_right"):
		transform = transform.rotated_local(rotation_speed)
