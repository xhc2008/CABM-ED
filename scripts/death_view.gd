extends Control

signal death_view_closed

@onready var return_button: Button = $Panel/VBox/ReturnButton

var map_config: Dictionary = {}

func _ready():
    _load_map_config()
    if return_button:
        return_button.pressed.connect(_on_return_pressed)

func _load_map_config():
    var map_path = "res://config/map.json"
    if FileAccess.file_exists(map_path):
        var f = FileAccess.open(map_path, FileAccess.READ)
        var js = f.get_as_text()
        f.close()
        var j = JSON.new()
        if j.parse(js) == OK:
            map_config = j.data

func _on_return_pressed():
    var target_scene := "entryway"
    if has_node("/root/SaveManager"):
        var sm = get_node("/root/SaveManager")
        if sm.has_meta("death_from_explore_id"):
            var explore_id = String(sm.get_meta("death_from_explore_id"))
            var base_id = _find_nearest_base_id_for_explore(explore_id)
            if base_id != "":
                target_scene = "entryway"
        if sm.save_data.has("explore_checkpoint"):
            if sm.save_data.explore_checkpoint.has("active"):
                sm.save_data.explore_checkpoint.active = false
        sm.set_character_scene(target_scene)
        if sm.has_meta("open_death_on_load"):
            sm.remove_meta("open_death_on_load")
        if sm.has_meta("death_from_explore_id"):
            sm.remove_meta("death_from_explore_id")
        sm.save_game(sm.current_slot)
    death_view_closed.emit()
    queue_free()

func _find_nearest_base_id_for_explore(explore_id: String) -> String:
    if not map_config.has("world"):
        return ""
    var explore_pos := Vector2.ZERO
    for p in map_config.world.points:
        if String(p.get("id", "")) == explore_id:
            var center_x = float(map_config.world.get("size", [2000,1200])[0]) / 2.0
            var center_y = float(map_config.world.get("size", [2000,1200])[1]) / 2.0
            var px = float(p.get("x", 0))
            var py = float(p.get("y", 0))
            explore_pos = Vector2(center_x + px, center_y + py)
            break
    if explore_pos == Vector2.ZERO:
        return ""
    var nearest_id := ""
    var nearest_dist := INF
    for p2 in map_config.world.points:
        if String(p2.get("type", "")) == "base":
            var center_x2 = float(map_config.world.get("size", [2000,1200])[0]) / 2.0
            var center_y2 = float(map_config.world.get("size", [2000,1200])[1]) / 2.0
            var bx = float(p2.get("x", 0))
            var by = float(p2.get("y", 0))
            var bpos = Vector2(center_x2 + bx, center_y2 + by)
            var d = explore_pos.distance_to(bpos)
            if d < nearest_dist:
                nearest_dist = d
                nearest_id = String(p2.get("id", ""))
    return nearest_id