extends Node

# Android权限管理器

func request_storage_permission() -> bool:
	"""请求存储权限"""
	if OS.get_name() != "Android":
		# 非Android平台，直接返回true
		return true
	
	# 检查是否已有权限
	if check_storage_permission():
		print("已有存储权限")
		return true
	
	# 请求权限（Godot 4.x中OS.request_permissions()不接受参数）
	# 权限需要在export_presets.cfg中配置
	print("请求存储权限...")
	OS.request_permissions()
	
	# 等待权限结果
	await get_tree().create_timer(1.0).timeout
	
	# 再次检查权限
	var has_permission = check_storage_permission()
	if has_permission:
		print("存储权限已授予")
	else:
		print("存储权限未授予")
	
	return has_permission

func check_storage_permission() -> bool:
	"""检查是否有存储权限"""
	if OS.get_name() != "Android":
		return true
	
	var granted_perms = OS.get_granted_permissions()
	print("已授予的权限: ", granted_perms)
	
	# 检查是否有任何存储相关权限
	var has_read = granted_perms.has("android.permission.READ_EXTERNAL_STORAGE")
	var has_write = granted_perms.has("android.permission.WRITE_EXTERNAL_STORAGE")
	var has_manage = granted_perms.has("android.permission.MANAGE_EXTERNAL_STORAGE")
	
	return has_read or has_write or has_manage
