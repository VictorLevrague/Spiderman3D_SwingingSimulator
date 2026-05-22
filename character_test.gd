extends CharacterBody3D

@export var speed : float = 10.0
@export var jump_quantity: float = 10
@export var rotation_speed: float = 10.0

var last_direction: Vector3 = Vector3.FORWARD

var anchor: Vector3
var rope_length: float
var is_swinging: bool = false
@export var AIR_GRAVITY := 15.0
@export var SWING_GRAVITY:= 20.0

var web_strength = 0.1
var web_mesh: MeshInstance3D

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
    velocity.x = input_direction.x * speed
    velocity.z = input_direction.y * speed
    velocity.y -= SWING_GRAVITY * delta
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
    if web_mesh:
        _process_web_mesh()
    if position.y > anchor.y:
        stop_web_mesh()

func _process_free_fall(delta, input_direction):
    velocity.x = lerp(velocity.x, input_direction.x * speed, delta * 3.0)
    velocity.z = lerp(velocity.z, input_direction.y * speed, delta * 3.0)
    velocity.y -= AIR_GRAVITY * delta

func _process_web_mesh():
    var immediate_mesh = web_mesh.mesh as ImmediateMesh
    immediate_mesh.clear_surfaces()
    
    var material = web_mesh.get_active_material(0)
    
    immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
    immediate_mesh.surface_add_vertex(anchor)
    immediate_mesh.surface_add_vertex(get_bone_position())
    immediate_mesh.surface_end()

func attach_web():
    anchor = get_closest_swing_point()
    rope_length = (anchor - get_bone_position()).length()
    is_swinging = true
    
    web_mesh = cast_web_mesh()

func cast_web_mesh() -> MeshInstance3D:
    var mesh_instance = MeshInstance3D.new()
    var immediate_mesh = ImmediateMesh.new()
    var material = ORMMaterial3D.new()
    
    mesh_instance.mesh = immediate_mesh
    mesh_instance.set_surface_override_material(0, material)
    mesh_instance.cast_shadow = false
    
    immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
    immediate_mesh.surface_add_vertex(anchor)
    immediate_mesh.surface_add_vertex(get_bone_position())
    immediate_mesh.surface_end()
    
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color.WHITE_SMOKE
    
    get_tree().get_root().add_child(mesh_instance)
    return mesh_instance

func get_bone_position():
    var bone_idx : int = %Skeleton3D.find_bone("mixamorig_LeftHand_23")
    var local_bone_transform : Transform3D = %Skeleton3D.get_bone_global_pose(bone_idx)
    var global_bone_pos : Vector3 = %Skeleton3D.to_global(local_bone_transform.origin) 
    return global_bone_pos

func stop_web_mesh():
    is_swinging = false
    if web_mesh:
        web_mesh.queue_free()

func get_closest_swing_point():
    return %Building.get_node("%SwingPoint").global_position
