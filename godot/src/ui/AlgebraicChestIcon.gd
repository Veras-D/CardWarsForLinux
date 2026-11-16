class_name AlgebraicChestIcon
extends ChestIconBase

const ANIM := preload("res://src/ui/AlgebraicChestAnimData.gd")
const SFX_RATTLE: AudioStream = preload("res://assets/audio/sfx/Algebraic_Chest_Rattle.wav")

@onready var puppet_global: Node3D = $AlgebraicChestRoot/Puppet_Global
@onready var puppet_base: Node3D = $AlgebraicChestRoot/Puppet_Global/Puppet_Base
@onready var puppet_lid: Node3D = $AlgebraicChestRoot/Puppet_Global/Puppet_Base/Puppet_Lid
@onready var puppet_card: Node3D = $AlgebraicChestRoot/Puppet_Global/Puppet_Card
@onready var puppet_sparkle: Node3D = $AlgebraicChestRoot/Puppet_Global/Puppet_Sparkle


func _init() -> void:
	_rattle_stream = SFX_RATTLE
	_rattle_time = 1.8
	_open_burst_time = 3.58
	_card_pop_time = 4.03


func _get_idle_duration() -> float:
	return ANIM.ALG_IDLE_DURATION


func _get_open_duration() -> float:
	return ANIM.ALG_OPEN_DURATION


func _get_close_duration() -> float:
	return ANIM.ALG_END_DURATION


func _apply_idle_frame(t: float) -> void:
	_apply_bone(puppet_global, ANIM.ALG_IDLE_POS_PUPPET_GLOBAL, ANIM.ALG_IDLE_ROT_PUPPET_GLOBAL, ANIM.ALG_IDLE_SCALE_PUPPET_GLOBAL, t)
	_apply_bone(puppet_base, ANIM.ALG_IDLE_POS_PUPPET_BASE, ANIM.ALG_IDLE_ROT_PUPPET_BASE, ANIM.ALG_IDLE_SCALE_PUPPET_BASE, t)
	_apply_bone(puppet_lid, ANIM.ALG_IDLE_POS_PUPPET_LID, ANIM.ALG_IDLE_ROT_PUPPET_LID, ANIM.ALG_IDLE_SCALE_PUPPET_LID, t)
	_apply_bone(puppet_card, ANIM.ALG_IDLE_POS_PUPPET_CARD, ANIM.ALG_IDLE_ROT_PUPPET_CARD, ANIM.ALG_IDLE_SCALE_PUPPET_CARD, t)
	_apply_bone(puppet_sparkle, ANIM.ALG_IDLE_POS_PUPPET_SPARKLE, ANIM.ALG_IDLE_ROT_PUPPET_SPARKLE, ANIM.ALG_IDLE_SCALE_PUPPET_SPARKLE, t)


func _apply_open_frame(t: float) -> void:
	_apply_bone(puppet_global, ANIM.ALG_OPEN_POS_PUPPET_GLOBAL, ANIM.ALG_OPEN_ROT_PUPPET_GLOBAL, ANIM.ALG_OPEN_SCALE_PUPPET_GLOBAL, t)
	_apply_bone(puppet_base, ANIM.ALG_OPEN_POS_PUPPET_BASE, ANIM.ALG_OPEN_ROT_PUPPET_BASE, ANIM.ALG_OPEN_SCALE_PUPPET_BASE, t)
	_apply_bone(puppet_lid, ANIM.ALG_OPEN_POS_PUPPET_LID, ANIM.ALG_OPEN_ROT_PUPPET_LID, ANIM.ALG_OPEN_SCALE_PUPPET_LID, t)
	_apply_bone(puppet_card, ANIM.ALG_OPEN_POS_PUPPET_CARD, ANIM.ALG_OPEN_ROT_PUPPET_CARD, ANIM.ALG_OPEN_SCALE_PUPPET_CARD, t)
	_apply_bone(puppet_sparkle, ANIM.ALG_OPEN_POS_PUPPET_SPARKLE, ANIM.ALG_OPEN_ROT_PUPPET_SPARKLE, ANIM.ALG_OPEN_SCALE_PUPPET_SPARKLE, t)


func _apply_close_frame(t: float) -> void:
	_apply_bone(puppet_global, ANIM.ALG_END_POS_PUPPET_GLOBAL, ANIM.ALG_END_ROT_PUPPET_GLOBAL, ANIM.ALG_END_SCALE_PUPPET_GLOBAL, t)
	_apply_bone(puppet_base, ANIM.ALG_END_POS_PUPPET_BASE, ANIM.ALG_END_ROT_PUPPET_BASE, ANIM.ALG_END_SCALE_PUPPET_BASE, t)
	_apply_bone(puppet_lid, ANIM.ALG_END_POS_PUPPET_LID, ANIM.ALG_END_ROT_PUPPET_LID, ANIM.ALG_END_SCALE_PUPPET_LID, t)
	_apply_bone(puppet_card, ANIM.ALG_END_POS_PUPPET_CARD, ANIM.ALG_END_ROT_PUPPET_CARD, ANIM.ALG_END_SCALE_PUPPET_CARD, t)
	_apply_bone(puppet_sparkle, ANIM.ALG_END_POS_PUPPET_SPARKLE, ANIM.ALG_END_ROT_PUPPET_SPARKLE, ANIM.ALG_END_SCALE_PUPPET_SPARKLE, t)
