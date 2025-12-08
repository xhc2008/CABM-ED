extends Control

@onready var progress_bar: ProgressBar = $Panel/VBox/ProgressBar
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var hint_label: Label = $Panel/VBox/HintLabel
@onready var download_button: Button = $Panel/VBox/Buttons/DownloadButton
@onready var import_button: Button = $Panel/VBox/Buttons/ImportButton

var http_request: HTTPRequest
var current_url_index: int = 0
var download_urls: Array = [
	"https://github.com/xhc2008/CABM-ED/releases/download/resources/resouces-v1-20251208-1.zip",
	"https://ghproxy.com/https://github.com/xhc2008/CABM-ED/releases/download/resources/resouces-v1-20251208-1.zip",
	"https://github.com/xhc2008/CABM-ED/releases/download/resources/resouces-v1-20251208-1.zip?mirror=tuna",
	"https://mirrors.ustc.edu.cn/github-release/xhc2008/CABM-ED/releases/download/resources/resouces-v1-20251208-1.zip",
	"https://mirrors.aliyun.com/github-release/xhc2008/CABM-ED/releases/download/resources/resouces-v1-20251208-1.zip",
	"https://mirrors.huaweicloud.com/github-release/xhc2008/CABM-ED/releases/download/resources/resouces-v1-20251208-1.zip"
]
var required_version: String = ""

func _ready():
	if has_node("/root/SaveManager"):
		required_version = get_node("/root/SaveManager").get_required_resource_version()
	_ensure_resources_dir()
	_set_ui_enabled(true)
	_show_hint()
	download_button.pressed.connect(_on_download_pressed)
	import_button.pressed.connect(_on_import_pressed)

func _show_hint():
	hint_label.text = "需要安装资源包才能开始游戏。可选择在线下载或手动导入压缩包。完成后会自动重启进入游戏。"

func _set_ui_enabled(enabled: bool):
	download_button.disabled = not enabled
	import_button.disabled = not enabled

func _on_download_pressed():
	_set_ui_enabled(false)
	progress_bar.value = 0
	status_label.text = "开始下载资源..."
	current_url_index = 0
	_start_next_download()

func _start_next_download():
	if current_url_index >= download_urls.size():
		status_label.text = "所有下载源失败，请尝试手动导入"
		_set_ui_enabled(true)
		return
	
	var url = download_urls[current_url_index]
	status_label.text = "尝试下载: " + url
	if http_request:
		http_request.queue_free()
	
	http_request = HTTPRequest.new()
	add_child(http_request)
	# 只保留完成信号的连接
	http_request.request_completed.connect(_on_request_completed)
	http_request.download_file = "user://resources/_download.zip"
	
	var err = http_request.request(url)
	if err != OK:
		status_label.text = "发送请求失败，切换下一源"
		current_url_index += 1
		_start_next_download()
		return
	
	# 下载开始后，设置一个每0.1秒调用一次的循环来检查进度
	while http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_update_progress()
		await get_tree().create_timer(0.1).timeout

func _update_progress():
	if not http_request or not http_request.is_inside_tree():
		return
	
	# 获取已下载字节数
	var downloaded = http_request.get_downloaded_bytes()
	# 获取响应体总大小（可能为-1，如果服务器未提供）
	var total = http_request.get_body_size()
	
	var pct: float = 0.0
	# 只有当总大小有效且大于0时才计算百分比
	if total > 0:
		pct = float(downloaded) / float(total) * 100.0
		progress_bar.value = clamp(pct, 0.0, 100.0)
	# 如果服务器没有返回总大小，可以显示一个不确定的进度或提示
	# 例如：progress_bar.value = 50  # 或设置为某个中间值表示“进行中”

func _on_request_progress(current: int, total: int):
	# 在 Godot 4 中，download_progress 信号传递的参数就是已下载和总字节数
	var pct: float = 0.0
	if total > 0:
		pct = float(current) / float(total) * 100.0
	progress_bar.value = clamp(pct, 0.0, 100.0)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
	if result != OK or response_code < 200 or response_code >= 300:
		status_label.text = "下载失败 (" + str(response_code) + ")，尝试下一源"
		current_url_index += 1
		_start_next_download()
		return
	status_label.text = "下载完成，开始解压"
	_extract_zip_and_finalize("user://resources/_download.zip")

func _on_import_pressed():
	_set_ui_enabled(false)
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.add_filter("*.zip", "资源包")
	fd.file_selected.connect(_on_import_file_selected)
	get_tree().root.add_child(fd)
	fd.popup_centered(Vector2i(800, 600))

func _on_import_file_selected(path: String):
	status_label.text = "选择文件: " + path + "，开始解压"
	_extract_zip_and_finalize(path)

func _extract_zip_and_finalize(zip_path: String):
	progress_bar.value = 0
	var ok = _extract_resources_zip(zip_path)
	if not ok:
		status_label.text = "解压失败，请重试或更换文件"
		_set_ui_enabled(true)
		return
	_write_version_file(required_version)
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager")._initialize_after_resources_ready()
	status_label.text = "资源安装完成，正在重启..."
	
	# 等待确保所有操作完成
	await get_tree().create_timer(2).timeout
	
	# 执行重启
	restart_application()

func restart_application():
	var executable_path = OS.get_executable_path()
	var arguments = OS.get_cmdline_args()
	# 启动新的程序实例
	var _pid = OS.create_process(executable_path, arguments, true)
	get_tree().quit()
	return

func _ensure_resources_dir():
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("resources"):
		dir.make_dir("resources")

func _extract_resources_zip(import_path: String) -> bool:
	var zip = ZIPReader.new()
	var err = zip.open(import_path)
	if err != OK:
		return false
	var files = zip.get_files()
	var strip_prefix := ""
	# 检测是否有顶层 resources/ 目录
	for fp in files:
		if fp.begins_with("resources/"):
			strip_prefix = "resources/"
			break
	for file_path in files:
		var content = zip.read_file(file_path)
		if content.size() == 0 and not file_path.ends_with("/"):
			continue
		if file_path.ends_with("/"):
			continue
		var rel_path = file_path
		if not strip_prefix.is_empty() and rel_path.begins_with(strip_prefix):
			rel_path = rel_path.substr(strip_prefix.length())
		var base_path = ProjectSettings.globalize_path("user://resources")
		var full_path = base_path + "/" + rel_path
		var dir_path = full_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)
		var f = FileAccess.open(full_path, FileAccess.WRITE)
		if f:
			f.store_buffer(content)
			f.close()
		else:
			zip.close()
			return false
	zip.close()
	return true

func _write_version_file(version: String):
	var path = "user://resources/version.txt"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(version)
		f.close()
