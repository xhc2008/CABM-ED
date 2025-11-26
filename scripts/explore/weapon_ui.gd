extends Control
class_name WeaponUI

# 武器UI - 显示武器信息和弹药

@onready var weapon_icon: TextureRect = $VBox/WeaponIcon
@onready var ammo_label: Label = $VBox/AmmoLabel
@onready var reload_progress: ProgressBar = $VBox/ReloadProgress

var weapon_system: WeaponSystem

func setup(weapon_sys: WeaponSystem):
	"""初始化武器UI"""
	weapon_system = weapon_sys
	
	if weapon_system:
		weapon_system.weapon_changed.connect(_on_weapon_changed)
		weapon_system.ammo_changed.connect(_on_ammo_changed)
		_on_weapon_changed(weapon_system.get_current_weapon())

func _process(_delta):
	# 更新换弹进度
	if weapon_system and reload_progress:
		var progress = weapon_system.get_reload_progress()
		reload_progress.value = progress
		if weapon_system.has_method("is_reloading"):
			reload_progress.visible = weapon_system.is_reloading

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
		ammo_label.text = str(int(current_ammo)) + "/" + str(int(max_ammo))
