extends MeshInstance3D

func cast_web_mesh(anchor: Vector3, cast_position: Vector3) -> void:
    var immediate_mesh = ImmediateMesh.new()
    
    var material = ORMMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color.WHITE_SMOKE
    set_surface_override_material(0, material)

    render_web_mesh(immediate_mesh, anchor, cast_position, material)
    
    mesh = immediate_mesh

func process_web_mesh(anchor: Vector3, cast_position: Vector3):
    var immediate_mesh = mesh as ImmediateMesh
    immediate_mesh.clear_surfaces()
    
    var material = get_active_material(0)
    
    render_web_mesh(immediate_mesh, anchor, cast_position, material)

func render_web_mesh(mesh: ImmediateMesh, anchor: Vector3, cast_position: Vector3, material: Material):
    mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
    mesh.surface_add_vertex(to_local(anchor))
    mesh.surface_add_vertex(to_local(cast_position))
    mesh.surface_end()
