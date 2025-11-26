extends Node

# 平台管理器 - 统一管理平台检测
# 作为自动加载单例使用

var is_mobile: bool = false
var platform_name: String = ""

func _ready():
	_detect_platform()

func _detect_platform():
	"""检测当前平台"""
	platform_name = OS.get_name()
	is_mobile = platform_name == "Android" or platform_name == "IOS"
	
	print("平台检测: ", platform_name, " | 移动设备: ", is_mobile)

func is_mobile_platform() -> bool:
	"""返回是否为移动平台"""
	return is_mobile

func get_platform_name() -> String:
	"""返回平台名称"""
	return platform_name

func is_android() -> bool:
	"""是否为Android平台"""
	return platform_name == "Android"

func is_ios() -> bool:
	"""是否为iOS平台"""
	return platform_name == "iOS"

func is_windows() -> bool:
	"""是否为Windows平台"""
	return platform_name == "Windows"

func is_macos() -> bool:
	"""是否为macOS平台"""
	return platform_name == "macOS"

func is_linux() -> bool:
	"""是否为Linux平台"""
	return platform_name == "Linux"

func is_web() -> bool:
	"""是否为Web平台"""
	return platform_name == "Web"
