extends Control
class_name WeaponUI

# 武器UI - 显示武器信息和弹药

@onready var weapon_icon: TextureRect = $VBox/WeaponIcon
@onready var ammo_label: Label = $VBox/AmmoLabel
@onready var reload_progress: ProgressBar = $VBox/ReloadProgress
@onready var mobile_controls: Control = $MobileControls
@onready var left_shoot_button: Button = $MobileControls/LeftShootButton
@onready var right_shoot_button: Button = $MobileControls/RightShootButton
@onready var reload_button: Button = $MobileControls/ReloadButton

var weapon_system: WeaponSystem
var is_mobile: bool = false

func _ready():
	# 检测是否为移动设备
	var os_name = OS.get_name()
	is_mobile = os_name == "Android" or os_name == "iOS"
	
	# 根据平台显示/隐藏移动控制
	if mobile_controls:
		mobile_controls.visible = is_mobile
	
	# 连接按钮信号
	if left_shoot_button:
		left_shoot_button.pressed.connect(_on_shoot_pressed)
		left_shoot_button.button_down.connect(_on_shoot_button_down)
		left_shoot_button.button_up.connect(_on_shoot_button_up)
	
	if right_shoot_button:
		right_shoot_button.pressed.connect(_on_shoot_pressed)
		right_shoot_button.button_down.connect(_on_shoot_button_down)
		right_shoot_button.button_up.connect(_on_shoot_button_up)
	
	if reload_button:
		reload_button.pressed.connect(_on_reload_pressed)

func setup(weapon_sys: WeaponSystem):
	"""初始化武器UI"""
	weapon_system = weapon_sys
	
	if weapon_system:
		weapon_system.weapon_changed.connect(_on_weapon_changed)
		weapon_system.ammo_changed.connect(_on_ammo_changed)
		_on_weapon_changed(weapon_system.get_current_weapon())

var is_shooting: bool = false

func _process(_delta):
	# 更新换弹进度
	if weapon_system and reload_progress:
		var progress = weapon_system.get_reload_progress()
		reload_progress.value = progress
		if weapon_system.has_method("is_reloading"):
			reload_progress.visible = weapon_system.is_reloading
	
	# 持续射击（如果按住按钮）
	if is_shooting and weapon_system:
		var scene = get_tree().current_scene
		if scene and scene.has_method("_handle_shoot"):
			scene._handle_shoot()

func _on_weapon_changed(weapon_data: Dictionary):
	"""武器变化"""
	if weapon_data.is_empty():
		# 没有武器
		weapon_icon.texture = null
		ammo_label.text = ""
		return
	
	var item_id = weapon_data.get("item_id", "")
	if not InventoryManager:
		return
	
	var item_config = InventoryManager.get_item_config(item_id)
	if item_config.is_empty():
		return
	
	# 显示武器图标
	if item_config.has("icon"):
		var icon_path = "res://assets/images/items/" + item_config.icon
		if ResourceLoader.exists(icon_path):
			weapon_icon.texture = load(icon_path)
			weapon_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# 更新弹药显示
	_on_ammo_changed(weapon_data.get("ammo", 0), item_config.get("magazine_size", 30))

func _on_ammo_changed(current_ammo: int, max_ammo: int):
	"""弹药变化"""
	if ammo_label:
		ammo_label.text = str(current_ammo) + "/" + str(max_ammo)

func _on_shoot_pressed():
	"""射击按钮按下"""
	# 由button_down处理

func _on_shoot_button_down():
	"""射击按钮按下（持续）"""
	is_shooting = true

func _on_shoot_button_up():
	"""射击按钮释放"""
	is_shooting = false

func _on_reload_pressed():
	"""换弹按钮按下"""
	if weapon_system:
		weapon_system.start_reload()

