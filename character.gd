extends CharacterBody3D

@export_group("Grounded")
@export var speed : float = 10.0
@export var rotation_speed: float = 10.0
@export var jump_quantity: float = 10

@export_group("Swinging")
@export var swinging_speed: float = 7.
@export var swing_gravity:= 20.0
@export var web_strength = 0.1
@export_range(0, 1.0) var boost_to_web_anchor: float = 0.2

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

    last_direction = Vector3(input_direction.x, 0, input_direction.y)
    
    if input_direction.length() > 0.1:
        var target_angle = atan2(last_direction.x, last_direction.z)
        %Sketchfab_Scene.rotation.y = lerp_angle(%Sketchfab_Scene.rotation.y, target_angle, rotation_speed * delta)
    
    if is_on_floor():
        _process_grounded(delta, input_direction)
    elif is_swinging:
        _process_swing(delta, input_direction)
    else:
        _process_free_fall(delta, input_direction)

    if is_on_wall() and last_direction.dot(-get_wall_normal()) > 0:
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
    velocity.x = input_direction.x * swinging_speed
    velocity.z = input_direction.y * swinging_speed
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
    if position.y > anchor.y:
        stop_web_mesh()

func _process_free_fall(delta, input_direction):
    velocity.x = lerp(velocity.x, input_direction.x * speed, delta * 3.0)
    velocity.z = lerp(velocity.z, input_direction.y * speed, delta * 3.0)
    velocity.y -= air_gravity * delta

func attach_web():
    anchor = get_closest_swing_point()
    rope_length = (anchor - get_bone_position()).length() * (1 - boost_to_web_anchor)
    is_swinging = true
    
    %WebRenderer.cast_web_mesh(anchor, get_bone_position())

func stop_web_mesh():
    is_swinging = false
    if web_renderer.mesh:
        %WebRenderer.mesh = null

func get_closest_swing_point():
    return %Building.get_node("%SwingPoint").global_position

func get_bone_position():
    var bone_idx : int = %Skeleton3D.find_bone("mixamorig_LeftHand_23")
    var local_bone_transform : Transform3D = %Skeleton3D.get_bone_global_pose(bone_idx)
    var global_bone_pos : Vector3 = %Skeleton3D.to_global(local_bone_transform.origin)
    return global_bone_pos
