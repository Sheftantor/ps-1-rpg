@tool
extends EditorScenePostImport

# Post-import script for res://Import/Character/MC-Rig/NewMain_Base.glb.
# Tripo nests the rig as root/"human figure 3d model"/Skeleton3D; this lifts the
# Skeleton3D (and the skinned mesh under it) straight under the root, so the
# model has the same layout as Real_MainC (root/Skeleton3D) and the player's
# paths ($Facing/Model/Skeleton3D/RightHandAttachment, animation tracks
# "Skeleton3D:mixamorig_*") work unchanged. The removed node has an identity
# transform, so nothing moves. Bones already use mixamorig_ names.


func _post_import(scene: Node) -> Object:
	for skeleton: Skeleton3D in scene.find_children("*", "Skeleton3D", true, false):
		var holder := skeleton.get_parent()
		if holder == scene:
			continue
		_own(skeleton, null)
		holder.remove_child(skeleton)
		scene.add_child(skeleton)
		_own(skeleton, scene)
		if holder.get_child_count() == 0 and holder.transform.is_equal_approx(Transform3D()):
			holder.get_parent().remove_child(holder)
			holder.free()
	return scene


func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_own(child, owner_node)
