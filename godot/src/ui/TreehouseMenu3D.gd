extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var logo_group: Node3D = $LogoGroup
@onready var front_group: Node3D = $LogoGroup/FrontGroup
@onready var back_group: Node3D = $LogoGroup/BackGroup
@onready var jake_node: MeshInstance3D = $Jake
@onready var jake_stool: MeshInstance3D = $JakeStool
@onready var finn_node: MeshInstance3D = $Finn
@onready var finn_stool: MeshInstance3D = $FinnStool
@onready var board_glow: MeshInstance3D = $BoardGlow
@onready var board_modes_group: Node3D = $BoardModesGroup
@onready var quests_mode: Node3D = $BoardModesGroup/QuestsMode
@onready var fionna_mode: Node3D = $BoardModesGroup/FionnaCakeMode
@onready var deckwars_mode: Node3D = $BoardModesGroup/DeckWarsMode

# Camera transforms
# Start View: Front view framing Jake (left), Finn (right), and the Table
const START_CAM_POS := Vector3(0.0, 2.45, 6.8)
const START_CAM_TARGET := Vector3(0.0, -0.35, 0.0)

# Hub View: First-person Jake POV, looking across table at Finn
const HUB_CAM_POS := Vector3(-3.20, 1.15, 0.0)
const HUB_CAM_TARGET := Vector3(0.60, -0.05, 0.0)

# Battle Select View: Framing the game board from Jake's side, steep 57deg pitch, Finn completely off-screen
const BATTLE_SELECT_CAM_POS := Vector3(-1.78, 1.89, 0.0)
const BATTLE_SELECT_CAM_TARGET := Vector3(-0.38, -0.29, 0.0)

# 3D Logo positions
# In Start view: High above the table
const START_LOGO_POS := Vector3(0.0, 1.95, 0.2)
const START_LOGO_SCALE := Vector3(0.75, 0.75, 0.75)
const START_LOGO_ROT := Vector3(0.0, 0.0, 0.0)

# In Hub view: Hovering centered over the board crease, spinning continuously
const HUB_LOGO_POS := Vector3(-0.01, 0.09, 0.03)
const HUB_LOGO_SCALE := Vector3(0.185, 0.185, 0.185)
const LOGO_SPIN_SPEED := 67.5 # degrees per second (matches Take 001_7.anim 360deg/5.333s)

var is_hub_view: bool = false
var is_mode_select: bool = false
var anim_time: float = 0.0
var logo_base_pos: Vector3 = START_LOGO_POS
var logo_scale: Vector3 = START_LOGO_SCALE
var logo_rot_y: float = 0.0
var active_tween: Tween = null
var board_glow_mat: StandardMaterial3D = null

func _ready() -> void:
	if board_glow:
		var mat = board_glow.get_surface_override_material(0)
		if not mat and board_glow.material_override:
			mat = board_glow.material_override
		if mat:
			board_glow_mat = mat.duplicate()
			board_glow.material_override = board_glow_mat
	set_start_view()

func set_start_view() -> void:
	is_hub_view = false
	is_mode_select = false
	if board_modes_group:
		board_modes_group.visible = false
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	if camera:
		camera.position = START_CAM_POS
		camera.look_at(START_CAM_TARGET, Vector3.UP)
	
	logo_base_pos = START_LOGO_POS
	logo_scale = START_LOGO_SCALE
	logo_rot_y = 0.0
	
	if logo_group:
		logo_group.position = START_LOGO_POS
		logo_group.rotation_degrees = START_LOGO_ROT
		logo_group.scale = START_LOGO_SCALE
	
	if jake_node:
		jake_node.visible = true
	if jake_stool:
		jake_stool.visible = true

func set_hub_view() -> void:
	is_hub_view = true
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	if camera:
		camera.position = HUB_CAM_POS
		camera.look_at(HUB_CAM_TARGET, Vector3.UP)
	
	logo_base_pos = HUB_LOGO_POS
	logo_scale = HUB_LOGO_SCALE
	
	if logo_group:
		logo_group.position = HUB_LOGO_POS
		logo_group.rotation_degrees = Vector3(0.0, logo_rot_y, 0.0)
		logo_group.scale = HUB_LOGO_SCALE
	
	# Jake is hidden in first-person POV
	if jake_node:
		jake_node.visible = false
	if jake_stool:
		jake_stool.visible = true

func transition_to_hub(duration: float = 0.8) -> void:
	if is_hub_view:
		return
	is_hub_view = true
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	if jake_node:
		jake_node.visible = false
	
	var saved_cam_xf = camera.transform
	camera.position = HUB_CAM_POS
	camera.look_at(HUB_CAM_TARGET, Vector3.UP)
	var target_cam_xf = camera.transform
	camera.transform = saved_cam_xf
	
	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(camera, "transform", target_cam_xf, duration)
	
	active_tween.tween_method(func(p: Vector3):
		logo_base_pos = p
	, START_LOGO_POS, HUB_LOGO_POS, duration)
	
	active_tween.tween_method(func(s: Vector3):
		logo_scale = s
	, START_LOGO_SCALE, HUB_LOGO_SCALE, duration)

func transition_to_start(duration: float = 0.8) -> void:
	if not is_hub_view:
		return
	is_hub_view = false
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	var saved_cam_xf = camera.transform
	camera.position = START_CAM_POS
	camera.look_at(START_CAM_TARGET, Vector3.UP)
	var target_cam_xf = camera.transform
	camera.transform = saved_cam_xf
	
	var target_rot_y = round(logo_rot_y / 360.0) * 360.0
	
	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(camera, "transform", target_cam_xf, duration)
	
	active_tween.tween_method(func(p: Vector3):
		logo_base_pos = p
	, HUB_LOGO_POS, START_LOGO_POS, duration)
	
	active_tween.tween_method(func(r: float):
		logo_rot_y = r
	, logo_rot_y, target_rot_y, duration)
	
	active_tween.tween_method(func(s: Vector3):
		logo_scale = s
	, HUB_LOGO_SCALE, START_LOGO_SCALE, duration)
	
	active_tween.chain().tween_callback(func():
		logo_rot_y = 0.0
		if jake_node:
			jake_node.visible = true
	)

func show_quest_modes() -> void:
	if is_mode_select:
		return
	is_mode_select = true
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	# Smoothly fly camera to Battle Select framing (closer, steep overhead view of board)
	var saved_cam_xf = camera.transform
	camera.position = BATTLE_SELECT_CAM_POS
	camera.look_at(BATTLE_SELECT_CAM_TARGET, Vector3.UP)
	var target_cam_xf = camera.transform
	camera.transform = saved_cam_xf
	
	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(camera, "transform", target_cam_xf, 0.55)
	
	# Shrink/hide spinning logo with cartoon spring
	if logo_group:
		var tw_logo = create_tween()
		tw_logo.tween_property(logo_group, "scale", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw_logo.tween_callback(func(): logo_group.visible = false)
	
	# Pop-up 3D props from the base of the board with staggered bounce
	if board_modes_group:
		board_modes_group.visible = true
		var modes = [deckwars_mode, fionna_mode, quests_mode]
		for i in range(modes.size()):
			var m = modes[i]
			if m:
				m.scale = Vector3.ZERO
				var m_tw = create_tween()
				m_tw.tween_interval(0.12 + i * 0.07)
				m_tw.tween_property(m, "scale", Vector3.ONE, 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_quest_modes() -> void:
	if not is_mode_select:
		return
	is_mode_select = false
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	
	# Smoothly return camera to Hub POV (first-person Jake looking at Finn)
	var saved_cam_xf = camera.transform
	camera.position = HUB_CAM_POS
	camera.look_at(HUB_CAM_TARGET, Vector3.UP)
	var target_cam_xf = camera.transform
	camera.transform = saved_cam_xf
	
	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_property(camera, "transform", target_cam_xf, 0.50)
	
	# Pop-down props into the board
	var tw = create_tween().set_parallel(true)
	var modes = [deckwars_mode, fionna_mode, quests_mode]
	for m in modes:
		if m:
			tw.tween_property(m, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tw.chain().tween_callback(func():
		if board_modes_group:
			board_modes_group.visible = false
		if logo_group:
			logo_group.visible = true
			var l_tw = create_tween()
			l_tw.tween_property(logo_group, "scale", HUB_LOGO_SCALE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)

func _process(delta: float) -> void:
	anim_time += delta
	
	# Board breathing glow effect: smoothly pulses from 0 to peak warm amber glow and back over 3.0s
	# Authentic colors derived from original Card Wars FX_Board (startColor 0.40, 0.37, 0.18):
	# adds subtle +30/255 ambient warmth without washing out the blue/brown tiles.
	if board_glow_mat:
		var cycle_pos: float = fmod(anim_time, 3.0) / 3.0
		var glow_intensity: float = sin(cycle_pos * PI)
		board_glow_mat.albedo_color = Color(0.90 * glow_intensity, 0.80 * glow_intensity, 0.44 * glow_intensity, 1.0)
	
	# Mode select prop animations
	if is_mode_select:
		# Gentle breathing hover for board props
		if fionna_mode:
			fionna_mode.position.y = -0.12 + sin(anim_time * 2.0) * 0.005
		if quests_mode:
			quests_mode.position.y = -0.12 + sin(anim_time * 2.2) * 0.005
		if deckwars_mode:
			deckwars_mode.position.y = -0.12 + sin(anim_time * 1.7) * 0.004
	
	if is_hub_view and not is_mode_select:
		logo_rot_y = fmod(logo_rot_y + LOGO_SPIN_SPEED * delta, 360.0)
	
	if logo_group and not is_mode_select:
		if is_hub_view:
			logo_group.position = logo_base_pos
			logo_group.rotation_degrees = Vector3(0.0, logo_rot_y, 0.0)
		else:
			var bob_y = sin(anim_time * 2.2) * 0.03
			var rock_z = sin(anim_time * 1.6) * 0.015
			logo_group.position = logo_base_pos + Vector3(0.0, bob_y, 0.0)
			logo_group.rotation_degrees = Vector3(0.0, logo_rot_y, rock_z * 57.29)
		logo_group.scale = logo_scale
		
		# Edge-on visibility toggle: only render the side facing the camera
		if camera and front_group and back_group:
			var cam_dir = camera.global_position - logo_group.global_position
			var is_facing_camera = logo_group.global_transform.basis.z.dot(cam_dir) > 0.0
			front_group.visible = is_facing_camera
			back_group.visible = not is_facing_camera
