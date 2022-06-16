class_name SoftBody2D
extends Node2D

export var points: int = 10
export var radius: float = 155.0
export var color: Color = Color.lightblue
export var physics_material_override: PhysicsMaterial
export var gravity_scale: float = 1.0
export var outer_stiffness: float = 50.0
export(float, 0, 10) var outer_damping: float = 5.0
export var central_stiffness: float = 150.0
export(float, 0, 10) var central_damping: float = 1.0
export var outer_radius: float = 10.0
export var rotation_degrees_offset: float = 0.0
export var second_layer: bool = false
export var ignore_collision_between_outers: bool = true
export var self_fixing: bool = true

var rigidbodies: Array = []
var outer_spring_joints: Array = []
var outer_body_distance: float = 0.0
var icons: Array = []
var broken: bool = false

func _ready():
	$Line2D.width = outer_radius * 2
	$Line2D.default_color = color
	rotation_degrees_offset = deg2rad(rotation_degrees_offset)
	if not is_zero_approx(rotation_degrees): 
		printerr("""Use the Rotation Degrees Offset rather than Rotation Degrees
to rotate the SoftBody!""")
	create_softbody()


func create_softbody():
	# Roll through every outer point
	var shape = Physics2DServer.circle_shape_create()
	Physics2DServer.shape_set_data(shape, outer_radius)
	
	for i in points:
		var position: Vector2 = Vector2(radius * cos(rotation_degrees_offset + i * 2 * PI / points),
				radius * sin(rotation_degrees_offset + i * 2 * PI / points))
		
		var body = Physics2DServer.body_create()
		Physics2DServer.body_set_mode(body, Physics2DServer.BODY_MODE_RIGID)
		Physics2DServer.body_add_shape(body, shape)
		Physics2DServer.body_set_space(body, get_world_2d().space)
		Physics2DServer.body_set_state(body, 
				Physics2DServer.BODY_STATE_TRANSFORM,
				Transform2D(0, position + global_position))
		
		Physics2DServer.body_set_param(body, 
				Physics2DServer.BODY_PARAM_GRAVITY_SCALE,
				gravity_scale)
		
		rigidbodies.append(body)
		
		# Connect the _body_moved function to one of the points for performance
		if i == 0:
			Physics2DServer.body_set_force_integration_callback(body, self, "_body_moved", body)
		# Create damped joints for every outer point
		else:
			var last_body = rigidbodies[i-1]
			var last_body_origin = Physics2DServer.body_get_state(last_body,Physics2DServer.BODY_STATE_TRANSFORM).get_origin()
			var distance = last_body_origin.distance_to(position+global_position)
			var damped_joint = Physics2DServer.damped_spring_joint_create(position + global_position,
					last_body_origin,
					body,
					last_body)
			Physics2DServer.damped_string_joint_set_param(damped_joint,
					Physics2DServer.DAMPED_STRING_REST_LENGTH, distance)
			Physics2DServer.damped_string_joint_set_param(damped_joint,
					Physics2DServer.DAMPED_STRING_DAMPING, outer_damping)
			Physics2DServer.damped_string_joint_set_param(damped_joint,
					Physics2DServer.DAMPED_STRING_STIFFNESS, outer_stiffness)
			
			outer_spring_joints.append(damped_joint)
		
		# Connect the last outer point and the first one
		if i == points-1:
			var last_body = rigidbodies[0]
			var last_body_origin = Physics2DServer.body_get_state(last_body,Physics2DServer.BODY_STATE_TRANSFORM).get_origin()
			var distance = last_body_origin.distance_to(position+global_position)
			outer_body_distance = distance
			var damped_joint = Physics2DServer.damped_spring_joint_create(position + global_position,
					last_body_origin,
					body,
					last_body)
			Physics2DServer.damped_string_joint_set_param(damped_joint,
					Physics2DServer.DAMPED_STRING_REST_LENGTH, distance)
			Physics2DServer.damped_string_joint_set_param(damped_joint,
					Physics2DServer.DAMPED_STRING_DAMPING, outer_damping)
			Physics2DServer.damped_string_joint_set_param(damped_joint,
					Physics2DServer.DAMPED_STRING_STIFFNESS, outer_stiffness)
			
			outer_spring_joints.append(damped_joint)
	
	# Create a central point
	var central_body = Physics2DServer.body_create()
	Physics2DServer.body_set_mode(central_body, Physics2DServer.BODY_MODE_RIGID)
	shape = Physics2DServer.circle_shape_create()
	Physics2DServer.shape_set_data(shape, radius * 0.5)
	Physics2DServer.body_add_shape(central_body, shape)
	Physics2DServer.body_set_space(central_body, get_world_2d().space)
	Physics2DServer.body_set_state(central_body, 
			Physics2DServer.BODY_STATE_TRANSFORM,
			Transform2D(0, global_position))
	Physics2DServer.body_set_param(central_body, 
				Physics2DServer.BODY_PARAM_GRAVITY_SCALE,
				gravity_scale)
	
	# Connect all outer points to the central one
	for outer_body in rigidbodies:
		var outer_body_origin = Physics2DServer.body_get_state(outer_body, Physics2DServer.BODY_STATE_TRANSFORM).get_origin()
		
		var damped_joint = Physics2DServer.damped_spring_joint_create(global_position,
				outer_body_origin,
				central_body,
				outer_body)
		Physics2DServer.damped_string_joint_set_param(damped_joint,
				Physics2DServer.DAMPED_STRING_REST_LENGTH, radius)
		Physics2DServer.damped_string_joint_set_param(damped_joint,
				Physics2DServer.DAMPED_STRING_DAMPING, central_damping)
		Physics2DServer.damped_string_joint_set_param(damped_joint,
				Physics2DServer.DAMPED_STRING_STIFFNESS, central_stiffness)
	
	if ignore_collision_between_outers:
		for rigidbody in rigidbodies:
			#var next_rigidbody = rigidbodies[i+1] if i < rigidbodies.size()-1 else rigidbodies[0]
			for ignored_rigidbody in rigidbodies:
				Physics2DServer.body_add_collision_exception(rigidbody, ignored_rigidbody)
	
	if physics_material_override:
		for rigidbody in rigidbodies:
			Physics2DServer.body_set_param(rigidbody, 
					Physics2DServer.BODY_PARAM_FRICTION,
					physics_material_override.friction)
			Physics2DServer.body_set_param(rigidbody, 
					Physics2DServer.BODY_PARAM_BOUNCE,
					physics_material_override.bounce)
	
	
	if not second_layer: return
	# SECOND LAYER
	shape = Physics2DServer.circle_shape_create()
	Physics2DServer.shape_set_data(shape, outer_radius/5)
	
	var inner_rigidbodies = []
	
	for i in points:
		var position: Vector2 = Vector2(radius/2 * cos(rotation_degrees_offset+ i * 2 * PI / points),
				radius/2 * sin(rotation_degrees_offset + i * 2 * PI / points))
		
		var body = Physics2DServer.body_create()
		Physics2DServer.body_set_mode(body, Physics2DServer.BODY_MODE_RIGID)
		Physics2DServer.body_add_shape(body, shape)
		Physics2DServer.body_set_space(body, get_world_2d().space)
		Physics2DServer.body_set_state(body, 
				Physics2DServer.BODY_STATE_TRANSFORM,
				Transform2D(0, position + global_position))
		Physics2DServer.body_set_param(body, 
				Physics2DServer.BODY_PARAM_GRAVITY_SCALE,
				gravity_scale)
		
		inner_rigidbodies.append(body)
		
		# Connect the _body_moved function to one of the points for performance
		if i == 0:
			pass
		# Create damped joints for every inner point
		else:
			var last_body = inner_rigidbodies[i-1]
			var last_body_origin = Physics2DServer.body_get_state(last_body,Physics2DServer.BODY_STATE_TRANSFORM).get_origin()
			var damped_joint = Physics2DServer.damped_spring_joint_create(position + global_position,
					last_body_origin,
					body,
					last_body)
			Physics2DServer.damped_string_joint_set_param(damped_joint,
					Physics2DServer.DAMPED_STRING_REST_LENGTH, radius/2)
			Physics2DServer.damped_string_joint_set_param(damped_joint,
					Physics2DServer.DAMPED_STRING_DAMPING, 1.0)
			Physics2DServer.damped_string_joint_set_param(damped_joint,
					Physics2DServer.DAMPED_STRING_STIFFNESS, outer_stiffness)
		
		# Connect the last outer point and the first one
		if i == points-1:
			var last_body = inner_rigidbodies[0]
			var last_body_origin = Physics2DServer.body_get_state(last_body,Physics2DServer.BODY_STATE_TRANSFORM).get_origin()
			var damped_joint = Physics2DServer.damped_spring_joint_create(position + global_position,
					last_body_origin,
					body,
					last_body)
			Physics2DServer.damped_string_joint_set_param(damped_joint,
					Physics2DServer.DAMPED_STRING_REST_LENGTH, radius/2)
			Physics2DServer.damped_string_joint_set_param(damped_joint,
					Physics2DServer.DAMPED_STRING_DAMPING, 1.0)
			Physics2DServer.damped_string_joint_set_param(damped_joint,
					Physics2DServer.DAMPED_STRING_STIFFNESS, outer_stiffness)
	
	# Connect all inner points to the central one
	for inner_body in inner_rigidbodies:
		var inner_body_origin = Physics2DServer.body_get_state(inner_body, Physics2DServer.BODY_STATE_TRANSFORM).get_origin()
		
		var damped_joint = Physics2DServer.damped_spring_joint_create(global_position,
				inner_body_origin,
				central_body,
				inner_body)
		Physics2DServer.damped_string_joint_set_param(damped_joint,
				Physics2DServer.DAMPED_STRING_REST_LENGTH, radius/2)
		Physics2DServer.damped_string_joint_set_param(damped_joint,
				Physics2DServer.DAMPED_STRING_DAMPING, central_damping)
		Physics2DServer.damped_string_joint_set_param(damped_joint,
				Physics2DServer.DAMPED_STRING_STIFFNESS, central_stiffness/2)
	
	# Connect all inner points to outer ones
	for inner_body in inner_rigidbodies.size():
		var inner_body_origin: Vector2 = Physics2DServer.body_get_state(inner_rigidbodies[inner_body], Physics2DServer.BODY_STATE_TRANSFORM).get_origin()
		var outer_body_one_origin: Vector2 = Physics2DServer.body_get_state(rigidbodies[inner_body], Physics2DServer.BODY_STATE_TRANSFORM).get_origin()
		var outer_body_two = rigidbodies[inner_body+1] if inner_body < inner_rigidbodies.size()-1 else rigidbodies[0]
		var outer_body_two_origin: Vector2 = Physics2DServer.body_get_state(outer_body_two, Physics2DServer.BODY_STATE_TRANSFORM).get_origin()
		
		var distance = inner_body_origin.distance_to(outer_body_one_origin)
		
		var damped_joint = Physics2DServer.damped_spring_joint_create(outer_body_one_origin,
				inner_body_origin,
				rigidbodies[inner_body],
				inner_rigidbodies[inner_body])
		Physics2DServer.damped_string_joint_set_param(damped_joint,
				Physics2DServer.DAMPED_STRING_REST_LENGTH, distance/2)
		Physics2DServer.damped_string_joint_set_param(damped_joint,
				Physics2DServer.DAMPED_STRING_DAMPING, 1.0)
		Physics2DServer.damped_string_joint_set_param(damped_joint,
				Physics2DServer.DAMPED_STRING_STIFFNESS, central_stiffness*2)
		
		var damped_joint_two = Physics2DServer.damped_spring_joint_create(outer_body_two_origin,
				inner_body_origin,
				outer_body_two,
				inner_rigidbodies[inner_body])
		Physics2DServer.damped_string_joint_set_param(damped_joint_two,
				Physics2DServer.DAMPED_STRING_REST_LENGTH, distance/2)
		Physics2DServer.damped_string_joint_set_param(damped_joint_two,
				Physics2DServer.DAMPED_STRING_DAMPING, 1.0)
		Physics2DServer.damped_string_joint_set_param(damped_joint_two,
				Physics2DServer.DAMPED_STRING_STIFFNESS, central_stiffness*2)


func _body_moved(_state: Physics2DDirectBodyState, _user_data):
	$Line2D.clear_points()
	for body in rigidbodies:
		var body_state = Physics2DServer.body_get_state(body, Physics2DServer.BODY_STATE_TRANSFORM)
		var body_position = body_state.get_origin() - global_position
		$Line2D.add_point(body_position)
	$Line2D.add_point(Physics2DServer.body_get_state(rigidbodies[0], Physics2DServer.BODY_STATE_TRANSFORM).get_origin() - global_position)
	
	if self_fixing:
		if broken:
			if Geometry.triangulate_polygon($Line2D.points).size() != 0:
				broken = false
				for damped_joint in outer_spring_joints:
					Physics2DServer.damped_string_joint_set_param(damped_joint,
						Physics2DServer.DAMPED_STRING_REST_LENGTH, outer_body_distance)
					Physics2DServer.damped_string_joint_set_param(damped_joint,
							Physics2DServer.DAMPED_STRING_DAMPING, 0.5)
			return
		elif Geometry.triangulate_polygon($Line2D.points).size() == 0:
			# The body broke!
			broken = true
			for damped_joint in outer_spring_joints:
				Physics2DServer.damped_string_joint_set_param(damped_joint,
					Physics2DServer.DAMPED_STRING_REST_LENGTH, 0.1)
				Physics2DServer.damped_string_joint_set_param(damped_joint,
						Physics2DServer.DAMPED_STRING_DAMPING, 0.0001)
			
			return
	
	update()


func _draw():
	if $Line2D.points.size() >= 3:
		draw_colored_polygon($Line2D.points, color)
