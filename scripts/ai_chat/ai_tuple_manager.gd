extends Node

# Tuple manager: handles tuple extraction requests and memory_graph file

var owner_service: Node = null
var logger: Node = null

func call_tuple_model(summary_text: String, conversation_text: String, custom_timestamp = null):
    if not owner_service:
        push_error("TupleManager: owner_service not set")
        return

    var summary_config = owner_service.config_loader.config.summary_model
    var model = summary_config.model
    var base_url = summary_config.base_url

    if model.is_empty() or base_url.is_empty():
        print("Tuple 模型配置不完整，跳过图谱保存")
        return

    var url = base_url + "/chat/completions"
    var headers = ["Content-Type: application/json", "Authorization: Bearer " + owner_service.config_loader.api_key]

    var tuple_params = summary_config.get("tuple", {})
    var system_prompt = tuple_params.get("system_prompt", "")

    var save_mgr = owner_service.get_node_or_null("/root/SaveManager")
    var helpers = owner_service.get_node_or_null("/root/EventHelpers")
    var char_name = helpers.get_character_name() if helpers else ""
    var user_name = save_mgr.get_user_name() if save_mgr else ""
    system_prompt = system_prompt.replace("{character_name}", char_name)
    system_prompt = system_prompt.replace("{user_name}", user_name)

    var messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": summary_text}
    ]

    var body = {
        "model": model,
        "messages": messages,
        "max_tokens": int(tuple_params.get("max_tokens", 256)),
        "temperature": float(tuple_params.get("temperature", 0.1)),
        "top_p": float(tuple_params.get("top_p", 0.7))
    }

    var json_body = JSON.stringify(body)
    if logger:
        logger.log_api_request("TUPLE_REQUEST", body, json_body)

    _apply_forgetting_to_graph()

    var tuple_request = HTTPRequest.new()
    add_child(tuple_request)
    tuple_request.request_completed.connect(self._on_tuple_request_completed)

    tuple_request.set_meta("request_type", "tuple")
    tuple_request.set_meta("summary", summary_text)
    tuple_request.set_meta("conversation_text", conversation_text)
    tuple_request.set_meta("messages", messages)
    tuple_request.set_meta("timestamp", custom_timestamp)

    var error = tuple_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
    if error != OK:
        push_error("Tuple 模型请求失败: " + str(error))
        tuple_request.queue_free()

func _on_tuple_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
    var tuple_request = null
    for child in get_children():
        if child is HTTPRequest and child.has_meta("request_type") and child.get_meta("request_type") == "tuple":
            tuple_request = child
            break

    if result != HTTPRequest.RESULT_SUCCESS:
        push_error("Tuple 请求失败: " + str(result))
        if tuple_request:
            tuple_request.queue_free()
        return

    if response_code != 200:
        var error_text = body.get_string_from_utf8()
        print("Tuple 模型API错误 (%d): %s" % [response_code, error_text])
        if tuple_request:
            tuple_request.queue_free()
        return

    var response_text = body.get_string_from_utf8()
    var json = JSON.new()
    if json.parse(response_text) != OK:
        push_error("Tuple 响应解析失败，保存原始文本")
        _save_tuple_to_file(tuple_request.get_meta("timestamp"), tuple_request.get_meta("summary"), response_text)
        if tuple_request:
            tuple_request.queue_free()
        return

    var data = json.data
    var tuples = null

    if data.has("choices") and not data.choices.is_empty():
        var msg = data.choices[0].message
        if msg and msg.has("content"):
            var content = str(msg.content)
            var p = JSON.new()
            if p.parse(content) == OK:
                tuples = p.data
    else:
        tuples = data

    _save_tuple_to_file(tuple_request.get_meta("timestamp"), tuple_request.get_meta("summary"), tuples)

    if logger:
        logger.log_api_call("TUPLE_RESPONSE", tuple_request.get_meta("messages", []), response_text)

    if tuple_request:
        tuple_request.queue_free()

func _save_tuple_to_file(custom_timestamp, summary_text, tuples_data):
    var filepath = "user://memory_graph.json"

    var existing = {}
    if FileAccess.file_exists(filepath):
        var f = FileAccess.open(filepath, FileAccess.READ)
        if f:
            var content = f.get_as_text()
            f.close()
            var j = JSON.new()
            if j.parse(content) == OK:
                existing = j.data

    if not existing.has("graphs"):
        existing.graphs = []

    var ts_string = null
    if custom_timestamp != null:
        if typeof(custom_timestamp) == TYPE_INT or typeof(custom_timestamp) == TYPE_FLOAT:
            var timezone_offset = owner_service._get_timezone_offset()
            var local_dict = Time.get_datetime_dict_from_unix_time(int(custom_timestamp + timezone_offset))
            ts_string = "%04d-%02d-%02dT%02d:%02d:%02d" % [local_dict.year, local_dict.month, local_dict.day, local_dict.hour, local_dict.minute, local_dict.second]
        else:
            ts_string = str(custom_timestamp)
    else:
        ts_string = owner_service._get_local_datetime_string()

    var parsed = tuples_data
    if typeof(tuples_data) == TYPE_STRING and tuples_data.strip_edges() != "":
        var jp = JSON.new()
        if jp.parse(str(tuples_data)) == OK:
            parsed = jp.data

    var getv = func(d, keys, default_val=""):
        for k in keys:
            if d.has(k):
                return d[k]
        return default_val

    var normalize_one = func(obj) -> Dictionary:
        var out = {"S": "", "P": "", "O": "", "I": 1, "T": ts_string}
        if typeof(obj) == TYPE_DICTIONARY:
            out.S = str(getv.call(obj, ["S","s","subject"," subj","subject_name"]))
            out.P = str(getv.call(obj, ["P","p","predicate","relation","rel"]))
            out.O = str(getv.call(obj, ["O","o","object","obj","object_name"]))
            var imp = getv.call(obj, ["I","i","importance","I_score","score"], 1)
            out.I = int(imp) if typeof(imp) in [TYPE_INT, TYPE_FLOAT] else int(str(imp).to_int()) if str(imp) != "" else 1
            return out
        elif typeof(obj) == TYPE_ARRAY:
            if obj.size() >= 3:
                out.S = str(obj[0])
                out.P = str(obj[1])
                out.O = str(obj[2])
                if obj.size() >= 4:
                    var imp2 = obj[3]
                    out.I = int(imp2) if typeof(imp2) in [TYPE_INT, TYPE_FLOAT] else int(str(imp2).to_int()) if str(imp2) != "" else 1
            return out
        else:
            out.S = ""
            out.P = "extracted"
            out.O = str(obj)
            return out

    var appended = 0
    if typeof(parsed) == TYPE_ARRAY:
        for item in parsed:
            var e = normalize_one.call(item)
            existing.graphs.append(e)
            appended += 1
    elif typeof(parsed) == TYPE_DICTIONARY:
        if parsed.has("tuples") and typeof(parsed.tuples) == TYPE_ARRAY:
            for item in parsed.tuples:
                var e = normalize_one.call(item)
                existing.graphs.append(e)
                appended += 1
        elif parsed.has("data") and typeof(parsed.data) == TYPE_ARRAY:
            for item in parsed.data:
                var e = normalize_one.call(item)
                existing.graphs.append(e)
                appended += 1
        else:
            var e = normalize_one.call(parsed)
            existing.graphs.append(e)
            appended += 1
    else:
        var e = normalize_one.call(str(parsed))
        existing.graphs.append(e)
        appended += 1

    var wf = FileAccess.open(filepath, FileAccess.WRITE)
    if wf:
        wf.store_string(JSON.stringify(existing, "\t"))
        wf.close()
        print("已保存图谱到: %s (新增 %d 条，总计 %d 条)" % [filepath, appended, existing.graphs.size()])
    else:
        push_error("无法写入图谱文件: %s" % filepath)

func _apply_forgetting_to_graph():
    var filepath = "user://memory_graph.json"
    if not FileAccess.file_exists(filepath):
        return

    var f = FileAccess.open(filepath, FileAccess.READ)
    if not f:
        return

    var content = f.get_as_text()
    f.close()

    var j = JSON.new()
    if j.parse(content) != OK:
        print("遗忘机制：无法解析图谱文件，跳过遗忘")
        return

    var data = j.data
    if not data.has("graphs") or typeof(data.graphs) != TYPE_ARRAY:
        return

    var new_graphs = []
    var removed_count = 0
    for item in data.graphs:
        var Ival = 1
        if item.has("I"):
            Ival = int(item.I)
        Ival -= 0.1
        if Ival < 0:
            removed_count += 1
            continue
        item.I = Ival
        new_graphs.append(item)

    data.graphs = new_graphs

    var wf = FileAccess.open(filepath, FileAccess.WRITE)
    if wf:
        wf.store_string(JSON.stringify(data, "\t"))
        wf.close()
        print("遗忘机制已执行：移除 %d 条记录，剩余 %d 条" % [removed_count, data.graphs.size()])
    else:
        push_error("遗忘机制：无法写回图谱文件: %s" % filepath)
