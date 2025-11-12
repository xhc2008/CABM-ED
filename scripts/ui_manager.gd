extends Node

# UI管理器 - 统一管理所有可交互UI元素的状态
# 自动加载单例

signal ui_state_changed(is_interactive: bool)

# 可交互UI元素列表
var interactive_elements: Array = []

# 当前状态
var is_interactive: bool = true

func _ready():
	print("UI管理器已初始化")

func register_element(element: Node):
	"""注册一个可交互UI元素"""
	if element not in interactive_elements:
		interactive_elements.append(element)
		print("UI元素已注册: ", element.name)
		
		# 应用当前状态
		_apply_state_to_element(element, is_interactive)

func unregister_element(element: Node):
	"""注销一个可交互UI元素"""
	if element in interactive_elements:
		interactive_elements.erase(element)
		print("UI元素已注销: ", element.name)

func cleanup_invalid_elements():
	"""清理所有无效的元素引用"""
	var valid_elements = []
	for element in interactive_elements:
		if element != null and is_instance_valid(element):
			valid_elements.append(element)
		else:
			print("清理无效的UI元素引用")
	
	interactive_elements = valid_elements

func disable_all():
	"""禁用所有可交互UI元素（聊天开始时）"""
	if not is_interactive:
		return
	
	is_interactive = false
	print("禁用所有UI交互")
	
	# 先清理无效元素
	cleanup_invalid_elements()
	
	for element in interactive_elements:
		_apply_state_to_element(element, false)
	
	ui_state_changed.emit(false)

func enable_all():
	"""启用所有可交互UI元素（聊天结束时）"""
	if is_interactive:
		return
	
	is_interactive = true
	print("启用所有UI交互")
	
	# 先清理无效元素
	cleanup_invalid_elements()
	
	for element in interactive_elements:
		_apply_state_to_element(element, true)
	
	ui_state_changed.emit(true)

func _apply_state_to_element(element: Node, enabled: bool):
	"""应用状态到具体元素"""
	if element == null or not is_instance_valid(element):
		return
	
	# 根据元素类型应用不同的禁用方式
	if element is Control:
		# Control节点：使用mouse_filter
		if enabled:
			element.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			element.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 如果元素有自定义的enable/disable方法，调用它们
	if element.has_method("set_interactive"):
		element.set_interactive(enabled)
	elif element.has_method("enable") and element.has_method("disable"):
		if enabled:
			element.enable()
		else:
			element.disable()

func is_ui_interactive() -> bool:
	"""检查UI是否可交互"""
	return is_interactive