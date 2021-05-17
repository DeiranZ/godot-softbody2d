extends Line2D

func _process(delta):
	clear_points()
	for part in get_node("../Parts/OuterParts").get_children():
		add_point(part.position)
	add_point(get_node("../Parts/OuterParts/PartUL").position)
	$Polygon2D.polygon = points
