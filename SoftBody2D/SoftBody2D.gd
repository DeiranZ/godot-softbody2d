extends Node2D

var dir = Vector2.ZERO

func _physics_process(delta):
	dir = Vector2.ZERO
	
	if Input.is_action_pressed("ui_right"):
		dir.x += 1
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if Input.is_action_pressed("ui_down"):
		dir.y += 1
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1
	
	for part in $Parts/OuterParts.get_children():
		part.apply_central_impulse(dir * 5)
	
	$Parts/CentralPart.apply_central_impulse(dir * 5)
