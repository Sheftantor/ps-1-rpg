@tool
extends EditorScenePostImport

# Post-import script for res://Import/Character/Real_MainC.fbx.
# Renames the Tripo humanoid bones to the mixamorig_ names the player's
# animations, AnimationTree filters and scripts use. Bones with no Mixamo
# counterpart (Neck_Twist_A, Left_Eye, Right_Eye) keep their names.

const P := "mixamorig_"
const FINGERS := ["Thumb", "Index", "Middle", "Ring", "Pinky"]
const JOINTS := ["Proximal", "Intermediate", "Distal", "DistalEnd"]


func _post_import(scene: Node) -> Object:
	var rename := _bone_map()
	for skeleton: Skeleton3D in scene.find_children("*", "Skeleton3D", true, false):
		for bone in skeleton.get_bone_count():
			var bone_name := skeleton.get_bone_name(bone)
			if rename.has(bone_name):
				skeleton.set_bone_name(bone, rename[bone_name])
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null:
			continue
		for bind in mesh.skin.get_bind_count():
			var bind_name := mesh.skin.get_bind_name(bind)
			if rename.has(bind_name):
				mesh.skin.set_bind_name(bind, rename[bind_name])
	return scene


func _bone_map() -> Dictionary[String, String]:
	var map: Dictionary[String, String] = {
		"Hips": P + "Hips", "Spine": P + "Spine", "Chest": P + "Spine1",
		"UpperChest": P + "Spine2", "Neck": P + "Neck", "Head": P + "Head",
	}
	for side in ["Left", "Right"]:
		map[side + "_Shoulder"] = P + side + "Shoulder"
		map[side + "_UpperArm"] = P + side + "Arm"
		map[side + "_LowerArm"] = P + side + "ForeArm"
		map[side + "_Hand"] = P + side + "Hand"
		map[side + "_UpperLeg"] = P + side + "UpLeg"
		map[side + "_LowerLeg"] = P + side + "Leg"
		map[side + "_Foot"] = P + side + "Foot"
		map[side + "_Toes"] = P + side + "ToeBase"
		map[side + "_ToesEnd"] = P + side + "Toe_End"
		for finger: String in FINGERS:
			for i in JOINTS.size():
				map["%s_%s%s" % [side, finger, JOINTS[i]]] = "%s%sHand%s%d" % [P, side, finger, i + 1]
	return map
