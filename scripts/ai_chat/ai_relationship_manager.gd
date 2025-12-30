extends Node

# Relationship manager: handles relationship model calls and saving

var owner_service: Node = null
var logger: Node = null

func call_relationship_api():
	if not owner_service:
		push_error("RelationshipManager: owner_service not set")
		return

	var summary_config = owner_service.config_loader.config.summary_model
	var model = summary_config.model
	var base_url = summary_config.base_url

	if model.is_empty() or base_url.is_empty():
		push_error("关系模型配置不完整")
		return

	var url = base_url + "/chat/completions"
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + owner_service.config_loader.api_key]

	var prompt_builder = owner_service.get_node("/root/PromptBuilder")
	var current_relationship = prompt_builder.get_relationship_context()
	var memory_context = prompt_builder.get_memory_context()

	# Debug logging to ensure we actually call the relationship model
	print("RelationshipManager: calling relationship model. current_relationship length=%d, memory_context length=%d" % [str(current_relationship.length()).to_int(), str(memory_context.length()).to_int()])
	if logger:
		logger.log_api_request("RELATIONSHIP_PREPARE", {"current_relationship": current_relationship, "memory_context_len": memory_context.length()}, "")

	var save_mgr = owner_service.get_node("/root/SaveManager")
	var character_name = save_mgr.get_character_name()
	var user_name = save_mgr.get_user_name()

	var relationship_params = summary_config.relationship
	var system_prompt = relationship_params.system_prompt.replace("{character_name}", character_name).replace("{user_name}", user_name)

	var user_content = "{character_name}的日记：\n{memory_context}".replace("{character_name}", character_name).replace("{memory_context}", memory_context)

	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_content}
	]

	var body = {
		"model": model,
		"messages": messages,
		"max_tokens": int(relationship_params.max_tokens),
		"temperature": float(relationship_params.temperature),
		"top_p": float(relationship_params.top_p)
	}

	var json_body = JSON.stringify(body)
	if logger:
		logger.log_api_request("RELATIONSHIP_REQUEST", body, json_body)

	if owner_service.http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		owner_service.http_request.cancel_request()
		await owner_service.get_tree().process_frame

	owner_service.http_request.set_meta("request_type", "relationship")
	owner_service.http_request.set_meta("request_body", body)
	owner_service.http_request.set_meta("messages", messages)

	var error = owner_service.http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_error("关系模型请求失败: " + str(error))
	else:
		print("RelationshipManager: relationship request sent (error==OK)")

func handle_relationship_response(response: Dictionary):
	if not response.has("choices") or response.choices.is_empty():
		push_error("关系模型响应格式错误")
		return

	var message = response.choices[0].message
	var relationship_summary = message.content

	var messages = owner_service.http_request.get_meta("messages", [])
	if logger:
		logger.log_api_call("RELATIONSHIP_RESPONSE", messages, relationship_summary)

	# If model returned the same as current relationship, warn — maybe the model was not properly invoked
	var prompt_builder = owner_service.get_node("/root/PromptBuilder")
	var current_relationship = prompt_builder.get_relationship_context()
	if relationship_summary.strip_edges() == current_relationship.strip_edges():
		push_warning("关系模型返回与当前关系相同，可能未更新: %s" % relationship_summary)

	_save_relationship(relationship_summary)
	print("关系模型已更新: ", relationship_summary)

func _save_relationship(relationship_summary: String):
	var save_mgr = owner_service.get_node("/root/SaveManager")
	if not save_mgr.save_data.ai_data.has("relationship_history"):
		save_mgr.save_data.ai_data.relationship_history = []

	var timestamp = owner_service._get_local_datetime_string()
	var cleaned_summary = relationship_summary.strip_edges()

	var relationship_item = {"timestamp": timestamp, "content": cleaned_summary}
	save_mgr.save_data.ai_data.relationship_history.append(relationship_item)

	var max_relationship_history = owner_service.config_loader.config.memory.get("max_relationship_history", 2)
	if save_mgr.save_data.ai_data.relationship_history.size() > max_relationship_history:
		save_mgr.save_data.ai_data.relationship_history = save_mgr.save_data.ai_data.relationship_history.slice(-max_relationship_history)

	save_mgr.save_game(save_mgr.current_slot)

	print("关系信息已保存: ", relationship_summary)
