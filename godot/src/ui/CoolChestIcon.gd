class_name CoolChestIcon
extends ChestIconBase

const ANIM := preload("res://src/ui/CoolChestAnimData.gd")
const SFX_RATTLE: AudioStream = preload("res://assets/audio/sfx/Cool_Chest_Rattle.wav")

@onready var puppet_global: Node3D = $CoolChestRoot/Puppet_Global
@onready var puppet_base: Node3D = $CoolChestRoot/Puppet_Global/Puppet_Base
@onready var puppet_lid: Node3D = $CoolChestRoot/Puppet_Global/Puppet_Base/Puppet_Lid
@onready var puppet_loose_board: Node3D = $CoolChestRoot/Puppet_Global/Puppet_Base/Puppet_Lid/Puppet_LooseBoard
@onready var puppet_card: Node3D = $CoolChestRoot/Puppet_Global/Puppet_Card
@onready var puppet_moth1_body: Node3D = $CoolChestRoot/Puppet_Global/Puppet_Moth01_Body
@onready var puppet_moth1_wing_l: Node3D = $CoolChestRoot/Puppet_Global/Puppet_Moth01_Body/Puppet_Moth01_WingL
@onready var puppet_moth1_wing_r: Node3D = $CoolChestRoot/Puppet_Global/Puppet_Moth01_Body/Puppet_Moth01_WingR
@onready var puppet_moth2_body: Node3D = $CoolChestRoot/Puppet_Global/Puppet_Moth02_Body
@onready var puppet_moth2_wing_l: Node3D = $CoolChestRoot/Puppet_Global/Puppet_Moth02_Body/Puppet_Moth02_WingL
@onready var puppet_moth2_wing_r: Node3D = $CoolChestRoot/Puppet_Global/Puppet_Moth02_Body/Puppet_Moth02_WingR


func _init() -> void:
	_rattle_stream = SFX_RATTLE
	_rattle_time = 0.2
	_open_burst_time = 2.07
	_card_pop_time = 4.33


func _get_idle_duration() -> float:
	return ANIM.COOL_IDLE_DURATION


func _get_open_duration() -> float:
	return ANIM.COOL_OPEN_DURATION


func _get_close_duration() -> float:
	return ANIM.COOL_END_DURATION


func _apply_idle_frame(t: float) -> void:
	_apply_bone(puppet_global, ANIM.COOL_IDLE_POS_PUPPET_GLOBAL, ANIM.COOL_IDLE_ROT_PUPPET_GLOBAL, ANIM.COOL_IDLE_SCALE_PUPPET_GLOBAL, t)
	_apply_bone(puppet_base, ANIM.COOL_IDLE_POS_PUPPET_BASE, ANIM.COOL_IDLE_ROT_PUPPET_BASE, ANIM.COOL_IDLE_SCALE_PUPPET_BASE, t)
	_apply_bone(puppet_lid, ANIM.COOL_IDLE_POS_PUPPET_LID, ANIM.COOL_IDLE_ROT_PUPPET_LID, ANIM.COOL_IDLE_SCALE_PUPPET_LID, t)
	_apply_bone(puppet_loose_board, ANIM.COOL_IDLE_POS_PUPPET_LOOSEBOARD, ANIM.COOL_IDLE_ROT_PUPPET_LOOSEBOARD, ANIM.COOL_IDLE_SCALE_PUPPET_LOOSEBOARD, t)
	_apply_bone(puppet_card, ANIM.COOL_IDLE_POS_PUPPET_CARD, ANIM.COOL_IDLE_ROT_PUPPET_CARD, ANIM.COOL_IDLE_SCALE_PUPPET_CARD, t)
	_apply_bone(puppet_moth1_body, ANIM.COOL_IDLE_POS_PUPPET_MOTH01_BODY, ANIM.COOL_IDLE_ROT_PUPPET_MOTH01_BODY, ANIM.COOL_IDLE_SCALE_PUPPET_MOTH01_BODY, t)
	_apply_bone(puppet_moth1_wing_l, ANIM.COOL_IDLE_POS_PUPPET_MOTH01_WINGL, ANIM.COOL_IDLE_ROT_PUPPET_MOTH01_WINGL, ANIM.COOL_IDLE_SCALE_PUPPET_MOTH01_WINGL, t)
	_apply_bone(puppet_moth1_wing_r, ANIM.COOL_IDLE_POS_PUPPET_MOTH01_WINGR, ANIM.COOL_IDLE_ROT_PUPPET_MOTH01_WINGR, ANIM.COOL_IDLE_SCALE_PUPPET_MOTH01_WINGR, t)
	_apply_bone(puppet_moth2_body, ANIM.COOL_IDLE_POS_PUPPET_MOTH02_BODY, ANIM.COOL_IDLE_ROT_PUPPET_MOTH02_BODY, ANIM.COOL_IDLE_SCALE_PUPPET_MOTH02_BODY, t)
	_apply_bone(puppet_moth2_wing_l, ANIM.COOL_IDLE_POS_PUPPET_MOTH02_WINGL, ANIM.COOL_IDLE_ROT_PUPPET_MOTH02_WINGL, ANIM.COOL_IDLE_SCALE_PUPPET_MOTH02_WINGL, t)
	_apply_bone(puppet_moth2_wing_r, ANIM.COOL_IDLE_POS_PUPPET_MOTH02_WINGR, ANIM.COOL_IDLE_ROT_PUPPET_MOTH02_WINGR, ANIM.COOL_IDLE_SCALE_PUPPET_MOTH02_WINGR, t)


func _apply_open_frame(t: float) -> void:
	_apply_bone(puppet_global, ANIM.COOL_OPEN_POS_PUPPET_GLOBAL, ANIM.COOL_OPEN_ROT_PUPPET_GLOBAL, ANIM.COOL_OPEN_SCALE_PUPPET_GLOBAL, t)
	_apply_bone(puppet_base, ANIM.COOL_OPEN_POS_PUPPET_BASE, ANIM.COOL_OPEN_ROT_PUPPET_BASE, ANIM.COOL_OPEN_SCALE_PUPPET_BASE, t)
	_apply_bone(puppet_lid, ANIM.COOL_OPEN_POS_PUPPET_LID, ANIM.COOL_OPEN_ROT_PUPPET_LID, ANIM.COOL_OPEN_SCALE_PUPPET_LID, t)
	_apply_bone(puppet_loose_board, ANIM.COOL_OPEN_POS_PUPPET_LOOSEBOARD, ANIM.COOL_OPEN_ROT_PUPPET_LOOSEBOARD, ANIM.COOL_OPEN_SCALE_PUPPET_LOOSEBOARD, t)
	_apply_bone(puppet_card, ANIM.COOL_OPEN_POS_PUPPET_CARD, ANIM.COOL_OPEN_ROT_PUPPET_CARD, ANIM.COOL_OPEN_SCALE_PUPPET_CARD, t)
	_apply_bone(puppet_moth1_body, ANIM.COOL_OPEN_POS_PUPPET_MOTH01_BODY, ANIM.COOL_OPEN_ROT_PUPPET_MOTH01_BODY, ANIM.COOL_OPEN_SCALE_PUPPET_MOTH01_BODY, t)
	_apply_bone(puppet_moth1_wing_l, ANIM.COOL_OPEN_POS_PUPPET_MOTH01_WINGL, ANIM.COOL_OPEN_ROT_PUPPET_MOTH01_WINGL, ANIM.COOL_OPEN_SCALE_PUPPET_MOTH01_WINGL, t)
	_apply_bone(puppet_moth1_wing_r, ANIM.COOL_OPEN_POS_PUPPET_MOTH01_WINGR, ANIM.COOL_OPEN_ROT_PUPPET_MOTH01_WINGR, ANIM.COOL_OPEN_SCALE_PUPPET_MOTH01_WINGR, t)
	_apply_bone(puppet_moth2_body, ANIM.COOL_OPEN_POS_PUPPET_MOTH02_BODY, ANIM.COOL_OPEN_ROT_PUPPET_MOTH02_BODY, ANIM.COOL_OPEN_SCALE_PUPPET_MOTH02_BODY, t)
	_apply_bone(puppet_moth2_wing_l, ANIM.COOL_OPEN_POS_PUPPET_MOTH02_WINGL, ANIM.COOL_OPEN_ROT_PUPPET_MOTH02_WINGL, ANIM.COOL_OPEN_SCALE_PUPPET_MOTH02_WINGL, t)
	_apply_bone(puppet_moth2_wing_r, ANIM.COOL_OPEN_POS_PUPPET_MOTH02_WINGR, ANIM.COOL_OPEN_ROT_PUPPET_MOTH02_WINGR, ANIM.COOL_OPEN_SCALE_PUPPET_MOTH02_WINGR, t)


func _apply_close_frame(t: float) -> void:
	_apply_bone(puppet_global, ANIM.COOL_END_POS_PUPPET_GLOBAL, ANIM.COOL_END_ROT_PUPPET_GLOBAL, ANIM.COOL_END_SCALE_PUPPET_GLOBAL, t)
	_apply_bone(puppet_base, ANIM.COOL_END_POS_PUPPET_BASE, ANIM.COOL_END_ROT_PUPPET_BASE, ANIM.COOL_END_SCALE_PUPPET_BASE, t)
	_apply_bone(puppet_lid, ANIM.COOL_END_POS_PUPPET_LID, ANIM.COOL_END_ROT_PUPPET_LID, ANIM.COOL_END_SCALE_PUPPET_LID, t)
	_apply_bone(puppet_loose_board, ANIM.COOL_END_POS_PUPPET_LOOSEBOARD, ANIM.COOL_END_ROT_PUPPET_LOOSEBOARD, ANIM.COOL_END_SCALE_PUPPET_LOOSEBOARD, t)
	_apply_bone(puppet_card, ANIM.COOL_END_POS_PUPPET_CARD, ANIM.COOL_END_ROT_PUPPET_CARD, ANIM.COOL_END_SCALE_PUPPET_CARD, t)
	_apply_bone(puppet_moth1_body, ANIM.COOL_END_POS_PUPPET_MOTH01_BODY, ANIM.COOL_END_ROT_PUPPET_MOTH01_BODY, ANIM.COOL_END_SCALE_PUPPET_MOTH01_BODY, t)
	_apply_bone(puppet_moth1_wing_l, ANIM.COOL_END_POS_PUPPET_MOTH01_WINGL, ANIM.COOL_END_ROT_PUPPET_MOTH01_WINGL, ANIM.COOL_END_SCALE_PUPPET_MOTH01_WINGL, t)
	_apply_bone(puppet_moth1_wing_r, ANIM.COOL_END_POS_PUPPET_MOTH01_WINGR, ANIM.COOL_END_ROT_PUPPET_MOTH01_WINGR, ANIM.COOL_END_SCALE_PUPPET_MOTH01_WINGR, t)
	_apply_bone(puppet_moth2_body, ANIM.COOL_END_POS_PUPPET_MOTH02_BODY, ANIM.COOL_END_ROT_PUPPET_MOTH02_BODY, ANIM.COOL_END_SCALE_PUPPET_MOTH02_BODY, t)
	_apply_bone(puppet_moth2_wing_l, ANIM.COOL_END_POS_PUPPET_MOTH02_WINGL, ANIM.COOL_END_ROT_PUPPET_MOTH02_WINGL, ANIM.COOL_END_SCALE_PUPPET_MOTH02_WINGL, t)
	_apply_bone(puppet_moth2_wing_r, ANIM.COOL_END_POS_PUPPET_MOTH02_WINGR, ANIM.COOL_END_ROT_PUPPET_MOTH02_WINGR, ANIM.COOL_END_SCALE_PUPPET_MOTH02_WINGR, t)
