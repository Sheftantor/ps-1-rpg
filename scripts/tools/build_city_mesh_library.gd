# Bakes every piece in the city kit scene (CSG, or plain MeshInstance3Ds under a
# Node3D) into a MeshLibrary for GridMap.
# Re-run after editing any piece:
#   godot --headless --path . -s res://scripts/tools/build_city_mesh_library.gd
# Item IDs are kept stable by name, so existing GridMap layouts survive a rebuild.
extends SceneTree

const KIT_SCENE := "res://scenes/city_kit/city_kit.tscn"
const OUTPUT_PATH := "res://resources/city/city_kit_mesh_library.tres"


func _initialize() -> void:
	var kit: Node3D = (load(KIT_SCENE) as PackedScene).instantiate()
	root.add_child(kit)
	# CSG rebuilds its brush deferred, so give it a frame before baking.
	await process_frame

	var old_library: MeshLibrary = null
	if ResourceLoader.exists(OUTPUT_PATH):
		old_library = ResourceLoader.load(OUTPUT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)

	var library := MeshLibrary.new()
	var next_id := 0
	if old_library:
		for id in old_library.get_item_list():
			next_id = maxi(next_id, id + 1)

	for piece in kit.get_children():
		var mesh: ArrayMesh
		var shape: Shape3D
		if piece is CSGShape3D:
			mesh = (piece as CSGShape3D).bake_static_mesh()
			shape = (piece as CSGShape3D).bake_collision_shape()
		else:
			mesh = _merge_meshes(piece as Node3D)
			if mesh.get_surface_count() == 0:
				continue
			shape = mesh.create_trimesh_shape()

		var id := old_library.find_item_by_name(piece.name) if old_library else -1
		if id == -1:
			id = next_id
			next_id += 1

		library.create_item(id)
		library.set_item_name(id, piece.name)
		library.set_item_mesh(id, mesh)
		library.set_item_shapes(id, [shape, Transform3D.IDENTITY])
		print("Baked item %d: %s" % [id, piece.name])

	var err := ResourceSaver.save(library, OUTPUT_PATH)
	if err != OK:
		push_error("Failed to save %s (error %d)" % [OUTPUT_PATH, err])
	else:
		print("Saved %s" % OUTPUT_PATH)
	quit(err)


## Merges every MeshInstance3D under a non-CSG piece into one mesh in the piece's space.
func _merge_meshes(piece: Node3D) -> ArrayMesh:
	var merged := ArrayMesh.new()
	for node in piece.find_children("*", "MeshInstance3D"):
		var mesh_instance := node as MeshInstance3D
		var to_piece := piece.global_transform.affine_inverse() * mesh_instance.global_transform
		for surface in mesh_instance.mesh.get_surface_count():
			var tool := SurfaceTool.new()
			tool.append_from(mesh_instance.mesh, surface, to_piece)
			tool.set_material(mesh_instance.get_active_material(surface))
			tool.commit(merged)
	return merged
