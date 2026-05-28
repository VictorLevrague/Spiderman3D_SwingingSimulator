extends CharacterBody3D

@export_group("Grounded")
@export var speed : float = 10.0
@export var rotation_speed: float = 10.0
@export var jump_quantity: float = 10
@export var base_fov: float = 75.

@export_group("Swinging")
@export var swinging_speed: float = 3
@export var swing_gravity:= 3
@export var web_strength = 0.1
@export_range(0, 1.0) var boost_to_web_anchor: float = 0.5
@export var speed_boost_swinging: float = 6.
@export var maximum_height_web: float = 50.
@export var speed_fov_change : float = 0.75
@export var swing_fov: float = 90.
@export var height_boost: float = 15.

@export_group("Wall Climbing")
@export var wall_climbing_speed: float = 10.0
@export var side_wall_climbing_speed: float = 10.0

@export_group("Free Falling")
@export var air_gravity := 15.0
 
var anchor: Vector3
var rope_length: float
var is_swinging: bool = false
var last_direction: Vector3 = Vector3.FORWARD

@onready var web_renderer: MeshInstance3D = %WebRenderer

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("swing"):
        if not is_swinging and not is_on_floor():
            attach_web()
    if event.is_action_released("swing"):
        stop_web_mesh()

func _physics_process(delta: float) -> void:
    var input_direction = Input.get_vector("move_left","move_right","move_forward","move_backward")
    
    if input_direction.length() > 0.1:
        last_direction = Vector3(input_direction.x, 0, input_direction.y).normalized()
        var target_angle = atan2(last_direction.x, last_direction.z)
        %Sketchfab_Scene.rotation.y = lerp_angle(%Sketchfab_Scene.rotation.y, target_angle, rotation_speed * delta)
    
    if is_on_floor():
        _process_grounded(delta, input_direction)
    elif is_swinging:
        _process_swing(delta, input_direction)
    else:
        _process_free_fall(delta, input_direction)

    var direction_to_wall = last_direction.dot(-get_wall_normal().normalized())
    
    if is_on_wall() and direction_to_wall > 0.5:
        var side_direction = - get_wall_normal().cross(up_direction)
        velocity.x = input_direction.x * side_direction.x * side_wall_climbing_speed
        velocity.z = input_direction.x * side_direction.z * side_wall_climbing_speed
        velocity.y = - input_direction.y * wall_climbing_speed
    move_and_slide()

func _process_grounded(delta: float, input_direction: Vector2) -> void:
    stop_web_mesh()
    velocity.x = input_direction.x * speed
    velocity.z = input_direction.y * speed
    if velocity.length() > 0.5:
        %AnimationPlayer.play("Run")
    else:
        %AnimationPlayer.play("Idle")
    if Input.is_action_just_pressed("jump"):
        velocity.y += jump_quantity
        #%AnimationPlayer.play("Jump")

func _process_swing(delta: float, input_direction):
    velocity.x += input_direction.x * swinging_speed * delta
    velocity.z += input_direction.y * swinging_speed * delta
    velocity.y -= swing_gravity * delta
    var to_anchor: Vector3 = anchor - get_bone_position()
    var distance_to_anchor: float = to_anchor.length()
    if rope_length > 0:
        var current_distance_to_anchor = get_bone_position().distance_to(anchor)
        if current_distance_to_anchor > rope_length:
            var direction_to_web_anchor = (anchor - get_bone_position()).normalized()
            global_position += direction_to_web_anchor * (current_distance_to_anchor - rope_length) * web_strength
            var radial_velocity = velocity.dot(direction_to_web_anchor)
            if radial_velocity < 0:
                velocity -= direction_to_web_anchor * radial_velocity
    if web_renderer.mesh:
        %WebRenderer.process_web_mesh(anchor, get_bone_position())
    if position.y > anchor.y or not has_line_of_sight(self.global_position, anchor):
        stop_web_mesh()

func _process_free_fall(delta, input_direction):
    velocity.x = lerp(velocity.x, input_direction.x * speed, delta * 3.0)
    velocity.z = lerp(velocity.z, input_direction.y * speed, delta * 3.0)
    velocity.y -= air_gravity * delta

func attach_web():
    anchor = get_best_swing_point_anchor()
    if anchor:
        rope_length = (anchor - get_bone_position()).length() * (1 - boost_to_web_anchor)
        is_swinging = true
        velocity.x = last_direction.x * swinging_speed * speed_boost_swinging
        velocity.y += height_boost
        velocity.z = last_direction.z * swinging_speed * speed_boost_swinging
        
        %WebRenderer.cast_web_mesh(anchor, get_bone_position())
        var camera_fov_tween: Tween = get_tree().create_tween()
        camera_fov_tween.tween_property(%Camera3D, "fov", swing_fov, speed_fov_change)
    else: 
        stop_web_mesh()

func stop_web_mesh():
    is_swinging = false
    if web_renderer.mesh:
        %WebRenderer.mesh = null
    var camera_fov_tween: Tween = get_tree().create_tween()
    camera_fov_tween.tween_property(%Camera3D, "fov", base_fov, speed_fov_change)

func get_best_swing_point_anchor() -> Vector3:
    #TODO: enhance the swing_point chosen. The heighest is always chosen, even though one that is near and almost as high could be better.
    var best_swing_point
    var greateast_distance = 0
    for swing_point in get_tree().get_nodes_in_group("swing_point"):
        if swing_point.global_position.y > self.global_position.y and has_line_of_sight(self.global_position, swing_point.global_position):
            var distance_to_player: float = swing_point.global_position.distance_to(self.global_position)
            print(distance_to_player)
            if distance_to_player < maximum_height_web and distance_to_player > greateast_distance:
                best_swing_point = swing_point
                greateast_distance = distance_to_player
    if best_swing_point:
        return best_swing_point.global_position
    else:
        return Vector3.ZERO

func get_bone_position():
    var bone_idx : int = %Skeleton3D.find_bone("mixamorig_LeftHand_23")
    var local_bone_transform : Transform3D = %Skeleton3D.get_bone_global_pose(bone_idx)
    var global_bone_pos : Vector3 = %Skeleton3D.to_global(local_bone_transform.origin)
    return global_bone_pos

func has_line_of_sight(from: Vector3, to: Vector3) -> bool:
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1
    query.exclude = [self]
    var result = space_state.intersect_ray(query)
    return result.is_empty()
