class_name TripoAPI
extends Node

# Tripo 3D API 集成
signal model_generation_started(task_id: String)
signal model_generation_completed(model_data: Dictionary)
signal model_preview_updated(preview_url: String)
signal model_generation_failed(error_message: String)

var http_request: HTTPRequest
var api_key: String = ""
var client_id: String = ""
var base_url: String = "https://api.tripo3d.ai/v2/openapi"
var pending_tasks: Dictionary = {}
var polling_inflight: Dictionary = {}
var post_success_attempts: Dictionary = {}

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func set_api_key(key: String):
	"""设置API密钥"""
	api_key = key
	print("Tripo API密钥已设置")

func set_client_id(id: String):
	"""设置Client ID（可选）"""
	client_id = id
	print("Tripo Client ID 已设置")

func generate_3d_model_from_text(prompt: String, recipe_id: String = "") -> String:
	"""根据文本生成3D模型"""
	if api_key.is_empty():
		print("错误：未设置Tripo API密钥")
		model_generation_failed.emit("未设置API密钥")
		return ""
	
	var headers = [
		"Authorization: Bearer " + api_key,
		"Content-Type: application/json",
		"Accept: application/json"
	]
	if not client_id.is_empty():
		headers.append("X-Client-Id: " + client_id)
	
	var body = JSON.stringify({
		"type": "text_to_model",
		"prompt": prompt,
		"model_version": "v2.0-20240919",
		"face_limit": 8000,
		"texture": true,
		"pbr": true,
		"texture_alignment": "geometry",
		"geometry_quality": "original"
	})
	
	var task_id = generate_task_id()
	pending_tasks[task_id] = {
		"type": "generation",
		"recipe_id": recipe_id,
		"prompt": prompt,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var error = http_request.request(base_url + "/task", headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("请求发送失败：", error)
		model_generation_failed.emit("请求发送失败")
		return ""
	
	print("3D模型生成请求已发送，任务ID：", task_id)
	model_generation_started.emit(task_id)
	return task_id

func check_task_status(task_id: String):
	"""检查任务状态"""
	if api_key.is_empty():
		print("错误：未设置Tripo API密钥")
		return
	
	# 防抖：同一任务的状态请求进行中则跳过
	if polling_inflight.get(task_id, false):
		return
	
	var headers = [
		"Authorization: Bearer " + api_key,
		"Accept: application/json"
	]
	if not client_id.is_empty():
		headers.append("X-Client-Id: " + client_id)
	
	polling_inflight[task_id] = true
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		var response_text = body.get_string_from_utf8()
		print("API响应：", response_code, " - ", response_text)
		_process_response(response_code, response_text)
		polling_inflight.erase(task_id)
		req.queue_free()
	)
	var error = req.request(base_url + "/task/" + task_id, headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("状态检查请求发送失败：", error)
		polling_inflight.erase(task_id)
		req.queue_free()

func generate_task_id() -> String:
	"""生成任务ID"""
	return "recipe_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	"""处理HTTP请求响应"""
	var response_text = body.get_string_from_utf8()
	print("API响应：", response_code, " - ", response_text)
	_process_response(response_code, response_text)

func _process_response(response_code: int, response_text: String) -> void:
	if response_code >= 200 and response_code < 300:
		var json = JSON.new()
		var parse_result = json.parse(response_text)
		
		if parse_result == OK:
			var response_data = json.data
			var payload: Dictionary = {}
			var business_code: int = -1
			var business_message: String = ""
			# 兼容 {code, data, message} 或 {data: {...}}
			if typeof(response_data) == TYPE_DICTIONARY:
				if response_data.has("code"):
					business_code = int(response_data.get("code", -1))
				if response_data.has("message"):
					business_message = str(response_data.get("message", ""))
				elif response_data.has("msg"):
					business_message = str(response_data.get("msg", ""))
				if response_data.has("data") and typeof(response_data.data) == TYPE_DICTIONARY:
					payload = response_data.data
			# 若未提取到 data，则直接使用顶层字典
			if payload.is_empty() and typeof(response_data) == TYPE_DICTIONARY:
				payload = response_data
			# 如果存在业务 code 且非 0/200，当作业务失败
			if business_code != -1 and business_code != 0 and business_code != 200:
				var msg = business_message if business_message != "" else "API业务失败 code=" + str(business_code)
				model_generation_failed.emit(msg)
				return
			_handle_successful_response(payload)
		else:
			print("响应解析失败")
			model_generation_failed.emit("响应解析失败")
	else:
		print("API请求失败，状态码：", response_code)
		# 尝试从错误体中提取 message
		var err_msg: String = ""
		var err_json = JSON.new()
		if err_json.parse(response_text) == OK and typeof(err_json.data) == TYPE_DICTIONARY:
			if err_json.data.has("message"):
				err_msg = str(err_json.data.get("message", ""))
			elif err_json.data.has("error"):
				err_msg = str(err_json.data.get("error", ""))
		if err_msg.is_empty():
			model_generation_failed.emit("API请求失败：" + str(response_code))
		else:
			model_generation_failed.emit("API请求失败：" + str(response_code) + " - " + err_msg)

func _handle_successful_response(data: Dictionary):
	"""处理成功的API响应"""
	if data.has("status"):
		# 这是状态查询的响应
		var status = data.status
		
		match status:
			"queued", "running":
				print("任务进行中...")
				# 若有中间预览图则通知UI
				if data.has("output") and typeof(data.output) == TYPE_DICTIONARY:
					var out: Dictionary = data.output
					var gen_img = out.get("generated_image", "")
					if typeof(gen_img) == TYPE_STRING and not gen_img.is_empty():
						model_preview_updated.emit(gen_img)
			"success":
				print("状态=success，开始尝试提取模型URL…")
				# 成功：尝试提取模型URL
				var model_url := _extract_model_url_from_payload(data)
				if model_url != "":
					data["model_url"] = model_url
					print("3D模型生成完成！检测到模型URL=", model_url)
					model_generation_completed.emit(data)
				else:
					print("3D模型生成完成，但暂未返回模型URL，尝试短轮询获取…")
					var tid: String = data.get("task_id", "")
					if tid != "":
						var tries: int = int(post_success_attempts.get(tid, 0))
						print("短轮询尝试次数=", tries)
						if tries < 3:
							post_success_attempts[tid] = tries + 1
							var t := Timer.new()
							t.one_shot = true
							t.wait_time = 2.0
							t.timeout.connect(func(): check_task_status(tid))
							add_child(t)
							t.start()
					else:
						print("短轮询达到上限，直接回调完成（无模型URL）")
						model_generation_completed.emit(data)
			"failed":
				print("3D模型生成失败")
				model_generation_failed.emit("生成失败")
	elif data.has("task_id"):
		# 这是生成请求的响应
		var task_id = data.task_id
		print("3D模型生成任务已创建：", task_id)
		
		# 开始定期检查任务状态
		_start_status_polling(task_id)

func _extract_model_url_from_payload(payload: Dictionary) -> String:
	print("extract_model_url: keys=", payload.keys())
	# 直接字段
	var direct = payload.get("model_url", "")
	if typeof(direct) == TYPE_STRING and not direct.is_empty():
		print("extract_model_url: model_url=", direct)
		return direct
	# 常见位置：output 或 result
	for k in ["output", "result"]:
		if payload.has(k) and typeof(payload[k]) == TYPE_DICTIONARY:
			var d: Dictionary = payload[k]
			print("extract_model_url: inspect ", k, " keys=", d.keys())
			# 兼容 pbr_model
			if d.has("pbr_model"):
				var pm = d.get("pbr_model")
				if typeof(pm) == TYPE_STRING and not pm.is_empty():
					return pm
				if typeof(pm) == TYPE_DICTIONARY:
					var u = pm.get("url", "")
					if typeof(u) == TYPE_STRING and not u.is_empty():
						return u
			for key in ["model", "glb_url", "gltf_url", "mesh", "mesh_url", "file_url"]:
				var v = d.get(key, "")
				if typeof(v) == TYPE_STRING and not v.is_empty():
					print("extract_model_url: ", key, "=", v)
					return v
	# 兜底：递归查找包含 .glb/.gltf 的字符串
	var found: String = _deep_find_url_with_ext(payload, [".glb", ".gltf"]) 
	if not found.is_empty():
		print("extract_model_url: deep_found=", found)
	return found

func _deep_find_url_with_ext(data, exts: Array[String]) -> String:
	match typeof(data):
		TYPE_DICTIONARY:
			for k in data.keys():
				var r: String = _deep_find_url_with_ext(data[k], exts)
				if not r.is_empty():
					return r
			return ""
		TYPE_ARRAY:
			for v in data:
				var r2: String = _deep_find_url_with_ext(v, exts)
				if not r2.is_empty():
					return r2
			return ""
		TYPE_STRING:
			var s: String = data
			for e in exts:
				if s.findn(e) != -1:
					return s
			return ""
		_:
			return ""

func _start_status_polling(task_id: String):
	"""开始状态轮询"""
	# 创建定时器进行状态检查
	var timer = Timer.new()
	timer.wait_time = 3.0  # 每3秒检查一次
	timer.timeout.connect(func(): check_task_status(task_id))
	add_child(timer)
	timer.start()
	
	# 设置最大轮询时间（5分钟）
	var max_timer = Timer.new()
	max_timer.wait_time = 300.0
	max_timer.one_shot = true
	max_timer.timeout.connect(func(): 
		timer.queue_free()
		max_timer.queue_free()
		model_generation_failed.emit("生成超时")
	)
	add_child(max_timer)
	max_timer.start()

# 模拟API调用（用于开发测试）
func simulate_model_generation(prompt: String, recipe_id: String = "") -> String:
	"""模拟3D模型生成（用于测试）"""
	var task_id = generate_task_id()
	
	print("模拟生成3D模型：", prompt)
	model_generation_started.emit(task_id)
	
	# 延迟3秒后返回模拟结果
	await get_tree().create_timer(3.0).timeout
	
	var mock_data = {
		"task_id": task_id,
		"status": "success",
		"model_url": "https://example.com/model.glb",
		"preview_url": "https://example.com/preview.jpg",
		"prompt": prompt,
		"recipe_id": recipe_id
	}
	
	model_generation_completed.emit(mock_data)
	return task_id
