class_name ArmPoseModifier
extends SkeletonModifier3D
## Levanta los brazos hacia adelante para apuntar armas a distancia, encima
## de cualquier animación de piernas (caminar, correr, saltar).

var both_arms := false

var _right_arm := -1
var _left_arm := -1


func setup(skeleton: Skeleton3D) -> void:
	_right_arm = skeleton.find_bone("arm-right")
	_left_arm = skeleton.find_bone("arm-left")


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _right_arm < 0:
		return
	# En reposo el brazo cuelga (-Y); -90° en X lo lleva hacia adelante (+Z del modelo).
	skeleton.set_bone_pose_rotation(_right_arm, Quaternion(Vector3.RIGHT, -PI * 0.5))
	if both_arms and _left_arm >= 0:
		skeleton.set_bone_pose_rotation(_left_arm,
			Quaternion(Vector3.UP, -0.5) * Quaternion(Vector3.RIGHT, -PI * 0.45))
