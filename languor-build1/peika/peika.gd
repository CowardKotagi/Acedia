extends CharacterBody3D

# Movement Properties
var friction: float = 4
var acceleration_ground: float = 12
var acceleration_air: float = 40
var top_speed_ground: float = 5
var top_speed_air: float = 2
var projected_speed: float = 0
var lin_friction_speed: int = 10
var movement_restriction_counter: int = 0
var coyote_counter: int = 0
var friction_delay_counter: int = 0
var jump_force: int = 8
var gravity: int = 20
var jumpbuffer: int = 0

# Camera and Detection
@onready var mouse_sensitivity = 0.06 / (get_viewport().get_visible_rect().size.x/1152.0)
@onready var camera: Camera3D = $FPCamera
@onready var hand: Node3D = $Hand
@onready var ground_detection_area: RayCast3D = $GroundDetectionArea
@onready var head_detection_area: Area3D = $HeadDetectionArea
@onready var wall_detection_area: ShapeCast3D = $WallDetectionArea

# UI Labels
@onready var speed_label: Label = $Control/Speed
@onready var ground_detection_area_label: Label = $Control/Area

# Gameplay State
enum States {
	IDLE,
	WALK,
	RUN,
	FALL,
}
var state := States.IDLE

# Player Movement Data
var grounded_prev: bool = true
var grounded: bool = true
var direction: Vector3 = Vector3.ZERO

# Temporary/Debug Variables
var frame_counter: int = 0

func _ready():
	speed_label.text = str( int( ( velocity * Vector3(1, 0, 1) ).length() ) )
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	#if event is InputEventMouseButton:
		#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotation_degrees.y += event.relative.x * -mouse_sensitivity
			camera.rotation_degrees.x += event.relative.y * -mouse_sensitivity
			camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -65, 90)
			
			hand.rotation_degrees.y += event.relative.x * -mouse_sensitivity/4
			hand.rotation_degrees.y = clamp(hand.rotation_degrees.y, -33, 33)
			
			hand.rotation_degrees.z += event.relative.x * -mouse_sensitivity
			hand.rotation_degrees.z = clamp(hand.rotation_degrees.z, -33, 33)
			
			hand.rotation_degrees.x += event.relative.y * -mouse_sensitivity
			hand.rotation_degrees.x = clamp(hand.rotation_degrees.x, -65, 90)


func _physics_process(delta):
	hand.rotation_degrees.y = move_toward(hand.rotation_degrees.y, 0, 2)
	hand.rotation_degrees.z = move_toward(hand.rotation_degrees.z, 0, 2)
	grounded_prev = grounded
	# Get the input direction and handle the movement/deceleration.
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	direction = (transform.basis * Vector3(input_direction.x, 0, input_direction.y)).normalized()
	projected_speed = (velocity * Vector3(1, 0, 1)).dot(direction)
	
	var camera_forward = camera.global_transform.basis.z.normalized() * -1
	
	if Global.frame_counter % 12 == 0:
		speed_label.text = str( int( ( velocity * Vector3(1, 0, 1) ).length() ) )
		ground_detection_area_label.text = str(ground_detection_area.is_colliding())
	
	match state:
		States.IDLE:
			if Input.is_action_just_pressed("jump") or (!is_on_floor() or velocity.y > 10):
				state = States.FALL
			if input_direction:
				state = States.RUN
			grounded = true
			_ground_move(delta)
		States.WALK:
			_apply_acceleration(acceleration_ground, top_speed_ground, delta)
			if !is_on_floor():
				state = States.FALL
			if Input.is_action_pressed("run") and $CollisionShape3D.shape.height == 2:
				state = States.RUN
			if !input_direction && velocity.length() < 0.1:
				state = States.IDLE
			grounded = true
			if (Input.is_action_just_pressed("jump") or jumpbuffer > 0) && $CollisionShape3D.shape.height == 2:
				velocity.y = jump_force
				jumpbuffer = 0
			if grounded:
				if grounded_prev != grounded:
					friction_delay_counter = 0
				friction_delay_counter += 1
				if friction_delay_counter >= 4:
					_apply_friction(delta)
			if Input.is_action_pressed("crouch"):
				$CollisionShape3D.shape.height = 1
				$CollisionShape3D.transform.origin.y = 0.5
				camera.transform.origin.y = 1
			elif head_detection_area.get_overlapping_bodies().size() <= 1:
				$CollisionShape3D.shape.height = 2
				$CollisionShape3D.transform.origin.y = 1
				camera.transform.origin.y = 1.5
			top_speed_ground = 6
			grounded_prev = grounded 
		States.RUN:
			_apply_acceleration(acceleration_ground, top_speed_ground, delta)
			if !is_on_floor():
				state = States.FALL
			if !Input.is_action_pressed("run"):
				state = States.WALK
			if Input.is_action_pressed("crouch"):
				state = States.WALK
			if !input_direction && velocity.length() < 0.1:
				state = States.IDLE
			grounded = true
			if Input.is_action_just_pressed("jump") or jumpbuffer > 0:
				velocity.y = jump_force
				jumpbuffer = 0
			if grounded:
				if grounded_prev != grounded:
					friction_delay_counter = 0
				friction_delay_counter += 1
				if friction_delay_counter >= 8:
					_apply_friction(delta)
			top_speed_ground = 12
			grounded_prev = grounded 
		States.FALL:
			if coyote_counter > 0:
				coyote_counter -= 1
				if velocity.y < 0 and Input.is_action_just_pressed("jump"):
					velocity.y = jump_force
			if is_on_floor():
				coyote_counter = 12
				if input_direction:
					state = States.RUN
				else:
					state = States.IDLE
			if ground_detection_area.is_colliding() \
			and velocity.y <= 0 \
			and (Input.is_action_pressed("jump") if Global.hold_jump_bunny_hop_enabled else Input.is_action_just_pressed("jump")):
				jumpbuffer = 1
			if (wall_detection_area.is_colliding() or is_on_wall())\
			and movement_restriction_counter == 0 \
			and (Input.is_action_pressed("jump") if Global.hold_jump_wall_kick_enabled else Input.is_action_just_pressed("jump")):
				var launch_direction = ((get_wall_collision_normals().normalized() * Vector3(1, 0, 1)) * 10)
				velocity = launch_direction + (camera_forward * (velocity.length()))
				velocity.y = 4
				movement_restriction_counter = 14
			grounded = false
			if movement_restriction_counter > 0:
				movement_restriction_counter -= 1
			else:
				air_move(delta)
	
	if velocity.length() >= 12:
		camera.fov = move_toward(int(camera.fov), int(Global.player_fov + velocity.length()/2), 0.1)
	else:
		camera.fov = move_toward(int(camera.fov), Global.player_fov, 1)
	
	#region Debug tools
	#testray.target_position = projected_speed * Vector3(1, 0, 1)
	#Engine.time_scale = 0.1
	#endregion
	move_and_slide()

func air_move(delta):
	_apply_acceleration(acceleration_air, top_speed_air, delta)
	velocity.y -= gravity * delta

func _apply_acceleration(acceleration: float, top_speed: float, delta):
	var speed_remaining: float = top_speed - projected_speed  # Simpler calculation
	var acceleration_final: float = 0
	if speed_remaining <= 0:
		return
	acceleration_final = max(acceleration * delta * top_speed, 0)
	velocity.x += acceleration_final * direction.x
	velocity.z += acceleration_final * direction.z

func _apply_friction(delta):
	var speed_scalar: float = 0
	var friction_curve: float = 0
	var speed_loss: float = 0
	if(velocity.length() < 0.01):
		return
	friction_curve = clampf(velocity.length(), lin_friction_speed, INF)
	speed_loss = friction_curve * friction * delta
	speed_scalar = clampf(velocity.length() - speed_loss, 0, INF)
	speed_scalar /= clampf(velocity.length(), 1, INF)
	velocity *= speed_scalar

func get_wall_collision_normals():
	var normals = []
	for i in range(wall_detection_area.get_collision_count()):
		normals.append(wall_detection_area.get_collision_normal(i))
	if normals.size() == 0:
		return Vector3.ZERO
	var sum = Vector3.ZERO
	for normal in normals:
		sum += normal
	var average_normal = sum / normals.size()
	return average_normal

#region UNUSED FUNCTIONS

func _ground_move(delta):
	_apply_acceleration(acceleration_ground, top_speed_ground, delta)
	if Input.is_action_just_pressed("jump") or jumpbuffer > 0:
		velocity.y = jump_force
		jumpbuffer = 0
	if Input.is_action_pressed("run"):
		top_speed_ground = 10
	else:
		top_speed_ground = 4
	if Input.is_action_pressed("crouch"):
		$CollisionShape3D.shape.height = 1
		$CollisionShape3D.transform.origin.y = 0.5
		camera.transform.origin.y = 1
	elif head_detection_area.get_overlapping_bodies().size() <= 1:
		$CollisionShape3D.shape.height = 2
		$CollisionShape3D.transform.origin.y = 1
		camera.transform.origin.y = 1.5
	if grounded:
		if grounded_prev != grounded:
			friction_delay_counter = 0
		friction_delay_counter += 1
		if friction_delay_counter >= 12:
			_apply_friction(delta)
	grounded_prev = grounded 

#endregion
