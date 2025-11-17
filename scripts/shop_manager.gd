extends Node

# ShopManager - 管理商店生成、存档与交易逻辑
# 请将此脚本设置为 Autoload 单例（例如名为 ShopManager）以便全局访问

const SHOP_CONFIG_PATH = "res://config/shop_offers.json"
const DEFAULT_DAILY_OFFERS = 5

var shop_pool: Array = []
var active_offers: Array = [] # 每个offer为具体化的交易项
var rng := RandomNumberGenerator.new()

func _ready():
    rng.randomize()
    _load_shop_config()
    _load_from_save()
    if active_offers.size() == 0:
        generate_offers(DEFAULT_DAILY_OFFERS)
        _save_to_save()
    

func _load_shop_config():
    if not FileAccess.file_exists(SHOP_CONFIG_PATH):
        print("警告: 商店配置不存在: ", SHOP_CONFIG_PATH)
        return

    var f = FileAccess.open(SHOP_CONFIG_PATH, FileAccess.READ)
    if f == null:
        print("无法打开商店配置")
        return

    var content = f.get_as_text()
    f.close()
    var json = JSON.new()
    if json.parse(content) == OK:
        var data = json.data
        if typeof(data) == TYPE_DICTIONARY and data.has("shop_pool"):
            shop_pool = data.shop_pool.duplicate(true)

func generate_offers(count: int):
    active_offers.clear()
    if shop_pool.size() == 0:
        return

    var pool_indices = []
    for i in range(shop_pool.size()):
        pool_indices.append(i)

    # 随机挑选不重复的样本
    for i in range(min(count, pool_indices.size())):
        var pick_idx = rng.randi_range(0, pool_indices.size() - 1)
        var pool_entry = shop_pool[pool_indices[pick_idx]]
        pool_indices.remove_at(pick_idx)

        # 将范围具体化
        var offer = {
            "id": str(Time.get_unix_time_from_system()) + "_" + str(rng.randi()),
            "name": pool_entry.get("name", "offer"),
            "requires": [],
            "gives": [],
            "limit": 1,
            "bought": 0
        }

        # requires
        for req in pool_entry.get("requires", []):
            var cnt = _choose_count(req.get("count", 1))
            offer.requires.append({"item_id": req.item_id, "count": int(cnt)})

        # gives
        for g in pool_entry.get("gives", []):
            var cnt = _choose_count(g.get("count", 1))
            offer.gives.append({"item_id": g.item_id, "count": int(cnt)})

        # limit
        var limit_val = pool_entry.get("limit", 1)
        offer.limit = int(_choose_count(limit_val))

        active_offers.append(offer)

    _save_to_save()

func _choose_count(val):
    # val 可以是单个数值或数组[min,max]
    if val is Array and val.size() >= 2:
        var lo = int(val[0])
        var hi = int(val[1])
        return rng.randi_range(lo, hi)
    elif typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
        return int(val)
    else:
        return 1

func trade_offer(offer_id: String) -> bool:
    # 执行交易：检查背包物品是否足够，扣除并发放奖励
    var offer = null
    for o in active_offers:
        if o.id == offer_id:
            offer = o
            break
    if offer == null:
        print("交易失败：未找到offer", offer_id)
        return false

    # 检查限购
    var save_mgr = get_node_or_null("/root/SaveManager")
    if save_mgr != null:
        var shop_data = save_mgr.save_data.get("shop_system_data", {})
        var counts = shop_data.get("purchase_counts", {})
        var bought = int(counts.get(offer_id, 0))
        if bought >= int(offer.limit):
            print("交易失败：已达限购", offer_id)
            return false

    # 检查需求
    var inv = null
    if has_node("/root/InventoryManager"):
        inv = get_node("/root/InventoryManager").inventory_container
    else:
        push_error("InventoryManager 未找到，无法交易")
        return false

    for req in offer.requires:
        var have = inv.count_item(req.item_id)
        if have < int(req.count):
            print("交易取消，物品不足: ", req.item_id)
            return false

    # 扣除物品
    for req in offer.requires:
        var removed = inv.remove_item_by_id(req.item_id, int(req.count))
        if removed < int(req.count):
            push_warning("扣除失败或部分扣除: " + req.item_id)

    # 添加奖励
    for g in offer.gives:
        var added = get_node("/root/InventoryManager").add_item_to_inventory(g.item_id, int(g.count))
        if not added:
            push_warning("发放奖励失败，背包可能已满: " + g.item_id)

    # 更新计数并保存
    if save_mgr != null:
        if not save_mgr.save_data.has("shop_system_data"):
            save_mgr.save_data.shop_system_data = {"active_offers": [], "purchase_counts": {}}
        var pc = save_mgr.save_data.shop_system_data.purchase_counts
        pc[offer_id] = int(pc.get(offer_id, 0)) + 1
        save_mgr.save_game(save_mgr.current_slot)

    offer.bought = int(offer.bought) + 1
    return true

func _load_from_save():
    var save_mgr = get_node_or_null("/root/SaveManager")
    if save_mgr != null and save_mgr.save_data.has("shop_system_data"):
        var data = save_mgr.save_data.shop_system_data
        if data.has("active_offers"):
            active_offers = data.active_offers.duplicate(true)

func _save_to_save():
    var save_mgr = get_node_or_null("/root/SaveManager")
    if save_mgr == null:
        return
    if not save_mgr.save_data.has("shop_system_data"):
        save_mgr.save_data.shop_system_data = {"active_offers": [], "purchase_counts": {}}
    save_mgr.save_data.shop_system_data.active_offers = active_offers.duplicate(true)

func get_active_offers() -> Array:
    return active_offers
