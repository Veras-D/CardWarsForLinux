class_name DungeonPortalIcon
extends Node3D

@onready var portal_root: Node3D = $PortalRoot
@onready var portal_vortex: Node3D = $PortalRoot/Puppet_Global/Puppet_PortalParent/Puppet_Portal

# Continuous swirl speed matching Take 001_14.anim (1 full turn per 1.5333s around local UP)
const SWIRL_RAD_PER_SEC: float = TAU / 1.533333

var anim_time: float = 0.0
var _base_vortex_rot: Quaternion = Quaternion(0.7071068, 0.0, 0.0, 0.7071067).normalized()


func _ready() -> void:
	if portal_vortex:
		_base_vortex_rot = portal_vortex.quaternion.normalized()
	reset_anim()


func reset_anim() -> void:
	anim_time = 0.0
	if portal_vortex:
		portal_vortex.quaternion = _base_vortex_rot


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	anim_time = fmod(anim_time + delta, 1.533333)
	if portal_vortex:
		portal_vortex.quaternion = _base_vortex_rot * Quaternion(Vector3.UP, anim_time * SWIRL_RAD_PER_SEC)
