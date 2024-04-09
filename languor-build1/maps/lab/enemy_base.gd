extends CharacterBody3D

@export var health: int = 100
@export var wander_radius_default: float = 0.0

# AI Navigation and Detection
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var hit_detection_area: Area3D = $HitDetectionArea
@onready var sight: Area3D = $Sight
@onready var sight_raycast: RayCast3D = $RayCast3D
@onready var testball: MeshInstance3D = $TestBall #FOR DEBUGGING
var target_last_seen_location: Vector3
var sight_overlaps: Array[Node3D]
var spawn_location: Vector3
var wandering_step_counter: int
var wander_radius: float
var direction: Vector3

var death_timer: int = 0
var speed: float = 5.0
var gravity: float = 9

# Enumerations/State Machines
enum AI_States {
	REST,
	WANDER,
	INSPECT,
	SEARCH,
}
var ai_state := AI_States.REST

enum States {
	IDLE,
	MOVE,
	FALL,
	DEAD,
}
var state := States.MOVE

func _ready():
	wander_radius = 100 / wander_radius_default
	spawn_location = self.global_transform.origin
	wandering_step_counter = (Global.get_random_number_range_360() + 100) * 8

func _physics_process(delta):
	await get_tree().physics_frame
	
	if health <= 0:
		state = States.DEAD
		health = 0
	elif navigation_agent.distance_to_target() <= 1:
		direction = Vector3.ZERO
	else: 
		direction = (navigation_agent.get_next_path_position() - global_position).normalized()
	
		
	testball.global_position = navigation_agent.target_position
	
	#Call function once and store in a variable so it doesn't have to be called over and over.
	#Although, in cases where more than one number is needed at the same time, the function will simply be called twice.
	var standard_random_number_range_100: int = Global.get_random_number_range_360()
	var vision_check = check_vision()
	
	if vision_check != null:
		target_last_seen_location = vision_check
	
	#region ai_state
	match ai_state:
		AI_States.REST: 
			if vision_check != null:
				navigation_agent.target_position = target_last_seen_location
				ai_state = AI_States.INSPECT
			
			if Global.frame_counter % wandering_step_counter == 0:
				if standard_random_number_range_100 > 1:
					var random_component_first = Global.get_random_number_range_360() / int(wander_radius)
					var random_component_second = Global.get_random_number_range_360() / int(wander_radius)
					
					#If either of the numbers are odd, make them negative
					random_component_first = random_component_first if random_component_first % 2 == 0 else -random_component_first
					random_component_second = random_component_second if random_component_second % 2 == 0 else -random_component_second
					
					navigation_agent.target_position = self.global_transform.origin + Vector3((random_component_first), 0, (random_component_second))
					ai_state = AI_States.WANDER
				else:
					navigation_agent.target_position = spawn_location
					ai_state = AI_States.WANDER
		AI_States.WANDER:
			if vision_check != null:
				navigation_agent.target_position = target_last_seen_location
				ai_state = AI_States.INSPECT
			testball.global_position = navigation_agent.target_position
			if navigation_agent.is_target_reached():
				ai_state = AI_States.REST
		AI_States.INSPECT:
			navigation_agent.target_position = target_last_seen_location
			if navigation_agent.distance_to_target() <= 2 and (check_vision() == null):
				ai_state = AI_States.SEARCH
		AI_States.SEARCH:
			if vision_check != null:
				navigation_agent.target_position = target_last_seen_location
				ai_state = AI_States.INSPECT
			if navigation_agent.distance_to_target() <= 2 and (check_vision() == null):
				if standard_random_number_range_100 > 10:
					var random_component_first = Global.get_random_number_range_360() / int(wander_radius)
					var random_component_second = Global.get_random_number_range_360() / int(wander_radius)
					
					#If either of the numbers are odd, make them negative
					random_component_first = random_component_first if random_component_first % 2 == 0 else -random_component_first
					random_component_second = random_component_second if random_component_second % 2 == 0 else -random_component_second
					
					navigation_agent.target_position = self.global_transform.origin + Vector3((random_component_first), 0, (random_component_second))
				else:
					navigation_agent.target_position = spawn_location
					ai_state = AI_States.WANDER
	#endregion
	#region state
	match state:
		States.IDLE:
			if !is_on_floor():
				state = States.FALL
			if direction.length() > 0.1:
				state = States.MOVE
			velocity.x = move_toward(velocity.x, 0, 0.5)
			velocity.z = move_toward(velocity.z, 0, 0.5)
		States.MOVE:
			if !is_on_floor():
				state = States.FALL
			if direction.length() < 0.1:
				state = States.IDLE
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			rotate_towards_movement(0.5)
		States.FALL:
			velocity.y -= gravity * delta
			if is_on_floor():
				if direction:
					state = States.MOVE
				else:
					state = States.IDLE
		States.DEAD:
			velocity.x = move_toward(velocity.x, 0, 0.05)
			velocity.z = move_toward(velocity.z, 0, 0.05)
			velocity.y -= gravity * delta
			death_timer += 1
			if death_timer == 1000:
				self.queue_free()
	#endregion
	move_and_slide()

func rotate_towards_target(speed_of_rotation: float):
		var look_direction = global_position.direction_to(navigation_agent.target_position) * -1
		global_rotation.y = lerp_angle(rotation.y, atan2(look_direction.x, look_direction.z), speed_of_rotation)

func rotate_towards_movement(speed_of_rotation: float):
		var look_direction = global_position.direction_to(navigation_agent.get_next_path_position()) * -1
		global_rotation.y = lerp_angle(rotation.y, atan2(look_direction.x, look_direction.z), speed_of_rotation)

func check_vision():
	sight_overlaps = sight.get_overlapping_bodies()
	for overlap in sight_overlaps:
		if overlap.is_in_group('players') and Global.frame_counter % 12 == 0:
			sight_raycast.force_raycast_update()
			sight_raycast.look_at(overlap.global_transform.origin)
			sight_raycast.force_raycast_update()
			if sight_raycast.is_colliding() and sight_raycast.get_collider().is_in_group('players'):
				return overlap.global_transform.origin
	return null

#region SIGNALS
func _on_hit_detection_area_body_entered(body):
	if body.is_in_group('players') and state != States.DEAD:
		get_tree().quit()
#endregion
