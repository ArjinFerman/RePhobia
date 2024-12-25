extends Camera2D

@export_range(0,2) var movement_speed = 0.25
@export_range(0,2) var zoom_speed = 0.25

func _process(_delta: float) -> void:
	if Input.is_action_just_released("zoom_in"):
		zoom += Vector2(zoom_speed, zoom_speed)
	elif Input.is_action_just_released("zoom_out"):
		zoom -= Vector2(zoom_speed, zoom_speed)
	
	if Input.is_action_pressed("camera_up"):
		transform = transform.translated(Vector2(0.0, -movement_speed))
	elif Input.is_action_pressed("camera_down"):
		transform = transform.translated(Vector2(0.0, movement_speed))
	
	if Input.is_action_pressed("camera_left"):
		transform = transform.translated(Vector2(-movement_speed, 0.0))
	elif Input.is_action_pressed("camera_right"):
		transform = transform.translated(Vector2(movement_speed, 0.0))
