extends Node
class_name ExploreSceneState

## 探索场景状态管理器
## 负责管理场景的状态、检查点保存和加载

signal state_changed(new_state: String)

enum State {
	ACTIVE,      # 正常探索中
	PAUSED,      # 暂停（打开背包等）
	EXITING,     # 正在退出（撤离或死亡）
	LOADING      # 加载中
}

var current_state: State = State.LOADING
var current_explore_id: String = ""
var is_player_dead: bool = false
var last_exit_was_death: bool = false

# 临时背包状态
var temp_player_inventory = {}
var temp_snow_fox_inventory = {}

# 地图配置缓存
var _map_config: Dictionary = {}

func _ready():
	pass

func set_state(new_state: State):
	"""设置场景状态"""
	if current_state == new_state:
		return
	
	var old_state = current_state
	current_state = new_state
	
	print("探索场景状态变化: %s -> %s" % [_state_to_string(old_state), _state_to_string(new_state)])
	state_changed.emit(_state_to_string(new_state))

func _state_to_string(state: State) -> String:
	match state:
		State.ACTIVE: return "ACTIVE"
		State.PAUSED: return "PAUSED"
		State.EXITING: return "EXITING"
		State.LOADING: return "LOADING"
		_: return "UNKNOWN"

func is_active() -> bool:
	"""检查是否处于活跃状态（可以交互）"""
	return current_state == State.ACTIVE

func is_exiting() -> bool:
	"""检查是否正在退出"""
	return current_state == State.EXITING

func load_map_config():
	"""加载地图配置"""
	if _map_config.is_empty():
		var path := "res://config/map.json"
		if FileAccess.file_exists(path):
			var f = FileAccess.open(path, FileAccess.READ)
			var js = f.get_as_text()
			f.close()
			var j = JSON.new()
			if j.parse(js) == OK:
				_map_config = j.data

func get_explore_display_name(explore_id: String) -> String:
	"""获取探索场景的显示名称"""
	load_map_config()
	if _map_config.has("world") and _map_config.world.has("points"):
		for p in _map_config.world.points:
			if p.get("id", "") == explore_id and p.get("type", "") == "explore":
				return p.get("name", explore_id)
	return explore_id

func get_checkpoint_data(player_pos: Vector2, snow_fox_pos: Vector2) -> Dictionary:
	"""获取检查点数据"""
	return {
		"active": true,
		"scene_id": current_explore_id,
		"player_pos": {"x": player_pos.x, "y": player_pos.y},
		"snow_fox_pos": {"x": snow_fox_pos.x, "y": snow_fox_pos.y}
	}

func restore_checkpoint(player: Node2D, snow_fox: Node2D) -> bool:
	"""从检查点恢复位置"""
	if not has_node("/root/SaveManager"):
		return false
	
	var sm = get_node("/root/SaveManager")
	if not sm.save_data.has("explore_checkpoint"):
		return false
	
	var cp = sm.save_data.explore_checkpoint
	if not cp.get("active", false):
		return false
	
	if player and cp.has("player_pos"):
		var p = cp.player_pos
		if p.has("x") and p.has("y"):
			player.global_position = Vector2(float(p.x), float(p.y))
	
	if snow_fox and cp.has("snow_fox_pos"):
		var s = cp.snow_fox_pos
		if s.has("x") and s.has("y"):
			snow_fox.global_position = Vector2(float(s.x), float(s.y))
	
	return true

func save_checkpoint_immediately():
	"""立即保存检查点"""
	if has_node("/root/SaveManager"):
		var sm = get_node("/root/SaveManager")
		sm.save_game(sm.current_slot)
