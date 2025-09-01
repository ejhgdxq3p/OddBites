# OddBites - Tripo Gacha 抽卡料理游戏

一个创新的抽卡料理游戏，玩家通过抽取食材卡片，组合生成3D料理模型，并进行售卖获得收益。

## 游戏特色

- 🎴 **策略抽卡**：5个主题卡池，每个卡池有不同的属性倾向
- 🍳 **自由组合**：将抽到的食材卡片组合成独特料理
- 🎨 **3D生成**：集成Tripo AI，根据卡片组合生成3D料理模型
- 📈 **潮流系统**：根据当前潮流获得售价加成
- 💰 **经济循环**：售卖料理获得金币，继续抽卡
- 👤 **个性头像**：DiceBear随机生成玩家头像，点击头像可重新生成

## 卡池设计

### 1. 奇趣异域 🌌
- **特点**：奇异度极高，视觉冲击力强
- **适合**：追求创意和稀有视觉效果的玩家
- **代表食材**：外星果实、幽灵蘑菇、荧光蔬菜

### 2. 传统经典 🏠
- **特点**：属性平衡，价格亲民
- **适合**：新手玩家和稳定收益
- **代表食材**：牛肉片、意面、米饭

### 3. 甜点幻想 🧁
- **特点**：甜度爆表，颜值担当
- **适合**：甜品料理和视觉系玩家
- **代表食材**：马卡龙外壳、巧克力酱、果冻球

### 4. 潮流未来 ⚡
- **特点**：科技感十足，属性随机性强
- **适合**：追求前卫和高策略自由度
- **代表食材**：荧光面条、反重力豆、电子香料

### 5. 火焰烈厨 🌶️
- **特点**：辣度爆表，高风险高回报
- **适合**：刺激挑战和高售价追求
- **代表食材**：辣椒碎、火焰肉片、炽热香料

## 技术架构

### 核心系统
- **GameManager**: 游戏核心管理器，处理卡池、抽卡、属性计算
- **CardData**: 卡片数据结构，包含属性和稀有度计算
- **TripoAPI**: 集成Tripo 3D生成API
- **AvatarManager**: DiceBear头像管理器，处理头像生成和缓存
- **MainGame**: 主游戏界面控制器

## 界面布局与交互（最新）

- 第三列（右侧大区）固定为纯 3D 预览：永不显示图片层，始终渲染 GLB 或占位模型
- 第四列新增 `广播 + 出餐` 侧栏：
  - 广播：实时显示当前潮流与最新生成的菜肴信息（辣/甜/奇、成本、售价）
  - 出餐：
    - 从“我的料理”选择菜肴后，以 Tag 形式加入套餐；点击 Tag 右上角“×”可移除
    - 下方显示套餐合计属性与合计成本
    - 支持建议售价与可编辑的实际售价（建议价=合计成本×潮流加成）
- 左列（卡池区）压缩宽度；中列（我的卡片 + 我的料理）进一步收缩，仅竖向滚动
- “我的卡片”“我的料理”均禁用横向滚动，仅允许竖向滚动（新增 `CardScroll`/`MyDishesScroll`）

## 我的料理与命名规则（最新）

- 预览图与模型文件以“组合出的菜名”命名：
  - 预览图：`user://recipes/<菜名>.png`
  - 模型：`user://recipes/<菜名>.glb`
- 缩略只显示图片，不显示标题文本以减少占用；点击缩略：
  - 第三列立即加载对应 GLB（若存在），否则按属性渲染占位 3D
  - 第四列的“出餐”中新增一个可移除的菜肴 Tag，并实时刷新“合计属性/成本/建议售价”


### 属性系统
每张卡片包含三个核心属性：
- **辣度 (Spice)**: 0-5，影响料理的刺激程度
- **甜度 (Sweet)**: 0-5，影响料理的甜美程度  
- **奇异度 (Weird)**: 0-10，影响料理的视觉奇特程度

### 潮流加成
根据当前潮流，不同属性组合可获得售价加成：
- **奇异风暴**: 奇异度≥8，加成50%
- **甜蜜时光**: 甜度≥4，加成30%
- **火辣挑战**: 辣度≥4，加成40%
- **未来科技**: 奇异度≥6且辣度≥2，加成30%
- **经典回归**: 三属性都较低，加成20%

### 主题门槛与对口属性（基于当前代码）
- **奇异风暴**：门槛=奇异≥8；对口属性=奇异；达标加成×1.5
- **甜蜜时光**：门槛=甜≥4；对口属性=甜；达标加成×1.3
- **火辣挑战**：门槛=辣≥4；对口属性=辣；达标加成×1.4
- **未来科技**：门槛=奇≥6且辣≥2；对口属性=奇+辣；达标加成×1.3
- **经典回归**：门槛=辣≤2且甜≤2且奇≤3；对口属性=低配三项；达标加成×1.2
- 建议售价=合计成本×潮流加成（在生成料理与出餐面板中都会体现建议价）。

### 售卖与定价（当前实现）
- 出餐新增"上线/下架"流程：点击"上线售卖"将当前套餐加入在线列表；每个在线套餐都有"下架"按钮可主动移除。
- 同时在线的套餐上限为3个，超出会提示先下架。
- 随机售卖延迟：后台以"基础延迟×定价倍率×随机扰动"计算售卖等待时间，完成后自动广播并入账。
- 成交金额按实际售价与建议价的关系应用软帽：
  - 价格≥建议价×1.2 → 成交额=售价×0.7（高价惩罚）
  - 价格<建议价 → 成交额=售价×1.1（低价小幅奖励）
  - 其他情况 → 成交额=售价×1.0
- 成交后会：
  - 在"广播"面板追加一条售卖记录（包含属性合计、成本、售价、成交额与当前潮流）。
  - 同步将成交金额实时计入玩家金币余额。

### 广播内容（增强）
- 新菜生成广播：显示辣/甜/奇、卡片数、成本、建议价、以及"当前潮流：基线条件 + 加成倍率 + 剩余时间"。
- 上线广播：显示套餐属性、价格与"潮流：基线 + 倍率 + 剩余时间"。
- 售出广播：显示成交详情，并包含潮流基线/倍率与剩余时间。

## 广播系统技术实现详解

### 系统架构
广播系统由三个核心组件协同工作：
1. **GameManager**：管理潮流信息、售卖逻辑、定时器
2. **MainGame**：处理UI显示、用户交互、广播消息格式化
3. **场景文件**：广播面板的UI布局和容器控制

### 核心机制

#### 1. 潮流信息获取
```gdscript
# GameManager.gd 中的潮流信息函数
func get_detailed_trend_info() -> String:
    var current_trend = current_trends[0] if current_trends.size() > 0 else null
    if not current_trend:
        return "无潮流"
    
    var baseline = get_trend_baseline_desc(current_trend)
    var bonus = get_trend_bonus_desc(current_trend)
    var remaining = get_trend_remaining_time(current_trend)
    
    return "潮流：%s | %s | %s" % [baseline, bonus, remaining]
```

#### 2. 售卖定时器系统
```gdscript
# 后台定时器，每秒检查一次
func _process_selling_timers() -> void:
    var current_time = Time.get_unix_time_from_system()
    for i in range(selling_timers.size() - 1, -1, -1):
        var timer = selling_timers[i]
        var end_time = timer.get("end_time", 0)
        if current_time >= end_time:
            var meal_data = timer.get("meal_data", {})
            _complete_automatic_sale(meal_data)
            selling_timers.remove_at(i)
            remove_meal_from_online(str(meal_data.get("online_id", "")))
            break # 一次只处理一个，避免索引问题
```

#### 3. 随机售卖延迟计算
```gdscript
func _start_selling_timer(meal_data: Dictionary) -> void:
    var base_delay = 5.0  # 基础延迟5秒
    var price_factor = 1.0
    
    # 根据定价策略计算延迟倍率
    var suggest_price = meal_data.get("suggest_price", 0)
    var asked_price = meal_data.get("asked_price", 0)
    if suggest_price > 0:
        price_factor = float(asked_price) / float(suggest_price)
    
    # 随机扰动因子 (0.8 - 1.2)
    var random_factor = randf_range(0.8, 1.2)
    
    # 最终延迟 = 基础延迟 × 定价倍率 × 随机扰动
    var final_delay = base_delay * price_factor * random_factor
    
    var timer_data = {
        "end_time": Time.get_unix_time_from_system() + final_delay,
        "meal_data": meal_data
    }
    selling_timers.append(timer_data)
    print("套餐 %s 开始售卖，延迟 %.1f 秒" % [meal_data.get("combo_name", "未命名"), final_delay])
```

#### 4. 广播消息格式化
```gdscript
# MainGame.gd 中的广播消息格式化
func _on_meal_sold(meal_data: Dictionary, final_income: int) -> void:
    if is_instance_valid(broadcast_log):
        var combo_name = meal_data.get("combo_name", "未命名")
        var total_spice = meal_data.get("total_spice", 0)
        var total_sweet = meal_data.get("total_sweet", 0)
        var total_weird = meal_data.get("total_weird", 0)
        var total_cost = meal_data.get("total_cost", 0)
        var suggest_price = meal_data.get("suggest_price", 0)
        var asked_price = meal_data.get("asked_price", 0)
        
        # 获取详细潮流信息
        var detailed_trend = game_manager.get_detailed_trend_info()
        
        # 格式化广播消息
        var line := "[color=yellow]售出:[/color] [b]%s[/b] | 辣:%d 甜:%d 奇:%d | 成本:%d 建议:%d 售价:%d 成交:%d | %s\n" % [
            combo_name, total_spice, total_sweet, total_weird, 
            total_cost, suggest_price, asked_price, final_income, 
            detailed_trend
        ]
        
        # 添加到广播面板并滚动到底部
        broadcast_log.append_text(line)
        broadcast_log.scroll_to_line(broadcast_log.get_line_count())
        _save_broadcast_line(line)
```

### 广播面板UI控制

#### 1. 容器宽度固定
```gdscript
# 强制固定所有容器宽度，防止因内容变长而扩展
func _force_fix_container_widths():
    # 所有容器设置固定最小宽度和水平布局标志
    for container_path in [
        "MainContainer/ContentArea/SidePanel",
        "MainContainer/ContentArea/SidePanel/ServePanel",
        "MainContainer/ContentArea/SidePanel/ServePanel/ServeContent",
        "MainContainer/ContentArea/SidePanel/BroadcastPanel"
    ]:
        if is_instance_valid(get_node_or_null(container_path)):
            var container = get_node(container_path)
            container.custom_minimum_size = Vector2(320, 0)
            container.size_flags_horizontal = 0
```

#### 2. 广播日志持久化
```gdscript
# 保存广播消息到游戏存档
func _save_broadcast_line(line: String) -> void:
    if game_manager:
        if game_manager.ui_broadcast_lines == null:
            game_manager.ui_broadcast_lines = []
        
        # 限制广播日志长度，防止存档过大
        if game_manager.ui_broadcast_lines.size() >= 200:
            game_manager.ui_broadcast_lines.pop_front()
        
        game_manager.ui_broadcast_lines.append(line)
        game_manager.save_game_data()
```

### 信号系统
广播系统通过Godot的信号机制实现组件间通信：

```gdscript
# GameManager 发出售卖完成信号
meal_sold.emit(meal_data, final_income)

# MainGame 连接信号并更新UI
func _ready():
    if game_manager:
        game_manager.meal_sold.connect(_on_meal_sold)
```

### 调试与错误处理
系统包含完善的调试机制：

1. **定时器状态打印**：每次售卖开始和完成都会打印详细信息
2. **广播引用检查**：使用`is_instance_valid()`确保UI组件有效
3. **错误恢复**：如果广播面板引用失效，会尝试重新获取
4. **延迟执行**：使用`call_deferred()`确保UI更新在正确的时机执行

### 性能优化
- **定时器批处理**：一次只处理一个售卖完成，避免索引问题
- **广播日志限制**：最多保留200条广播消息，防止内存泄漏
- **UI更新优化**：使用`call_deferred()`避免在信号回调中直接更新UI

## 快速开始

### 环境要求
- Godot 4.4+
- (可选) Tripo API密钥用于真实3D生成

### 运行步骤
1. 用Godot打开项目文件 `project.godot`
2. 点击运行按钮或按F5启动游戏
3. 选择卡池开始抽卡
4. 组合卡片生成料理
5. 查看生成的3D料理模型

### 配置Tripo API
- 目前项目已在 `Scripts/MainGame.gd` 的 `_ready()` 中直接设置了密钥与 Client ID，运行即可调用真实生成。
- 如需改为环境变量方式：
  - Windows PowerShell 运行前设置（临时会话）:
    ```powershell
    $env:TRIPO_API_SECRET="<你的secret>"
    $env:TRIPO_CLIENT_ID="<你的client_id>"
    ```
  - 然后在 `MainGame.gd` 中改回从环境变量读取的代码。

### 生成流程（当前实现）
1. 选择卡池并抽卡；或直接点击“生成料理”，若未选择卡片会自动从已有卡中按价格降序挑选最多5张。
2. 系统将所选卡牌合成为单一道菜的 Prompt（卡通3D风格、合盘呈现）。
3. 调用 Tripo 创建任务并轮询状态（已兼容 `{code, data}` 响应格式，使用一次性 HTTPRequest 避免 ERR_BUSY(44)）。
4. 右侧预览：
   - 透明 SubViewport 渲染 3D（已开启 `transparent_bg` + `CLEAR_MODE_ALWAYS`，避免透明背景闪烁）。
   - 模型成功实例化后自动隐藏图片预览，仅显示 3D 视图，减少叠层闪烁。
   - 模型将自适应居中与缩放，相机自动取景到合适距离。
5. 生成成功后，将自动把模型与预览图保存到本地（见下文“存档与回忆”）。

## 游戏玩法

1. **选择卡池**: 根据策略需求选择不同主题的卡池
2. **抽取卡片**: 消耗金币抽取食材卡片
3. **组合料理**: 选择最多5张卡片组合生成料理（若未选择会自动挑选）
4. **查看属性**: 系统自动计算料理的最终属性
5. **生成模型**: 调用AI生成对应的3D料理模型
6. **售卖获利**: 根据属性和潮流加成获得金币

### Prompt 设计（示例）
系统会生成类似如下的提示词，用于合成“单一道菜”的卡通3D模型：
```
A stylized cartoon 3D dish combining: 辣味青椒, 虹彩坚果, 洋葱丁. Create a single cohesive plated dish, do not separate items. Style: cartoon 3D food, stylized, cohesive single dish, served on a ceramic plate, soft studio lighting, no text, plain background, high quality, spicy, red accents, futuristic elements, playful shapes.
```

## 开发计划

- [x] 核心抽卡系统
- [x] 卡片属性计算
- [x] 基础UI界面（玩家信息、潮流倒计时、商店入口占位）
- [x] 模拟3D生成与占位几何体预览
- [x] 真实 Tripo API 集成（任务创建与轮询、预览图显示）
- [x] GLTF/GLB 模型加载到 3D 预览（运行时解析 GLB + 自适应取景）
- [x] DiceBear 头像系统（随机生成、缓存、点击刷新）
- [ ] 套餐组合系统
- [ ] 潮流任务系统
- [ ] 成就和收集系统
- [ ] 音效和动画
- [x] 模型与预览图持久化存档

## 玩家头像系统

### DiceBear 集成
- **头像生成**：使用 DiceBear API (https://api.dicebear.com) 生成食物主题头像
- **食物主题**：默认使用食物友好的头像风格，包含🍕🍔🍦等食物表情
- **缓存机制**：头像下载后自动缓存到 `user://avatars/` 目录，避免重复请求
- **种子系统**：基于玩家名称生成稳定种子，确保相同玩家获得一致的头像
- **点击刷新**：点击头像可重新生成新的食物主题头像

### 头像风格
支持多种 DiceBear 风格，包括：

#### 🍕 食物主题风格（推荐）
- `fun-emoji` - 🍕🍔🍦 食物表情风格（默认）
- `icons` - 🍽️ 餐具图标风格
- `pixel-art` - 🎮 像素食物风格
- `croodles` - 🎨 涂鸦食物风格
- `bottts` - 🤖 机器人食物风格

#### 🎭 其他风格
- `adventurer` - 冒险家风格
- `avataaars` - 经典卡通风格
- `big-ears` - 大耳朵风格
- `big-smile` - 大笑脸风格
- `lorelei` - 卡通女性风格
- `micah` - 扁平化风格
- 等多种风格可选

### 使用体验
- **主菜单**：左上角显示玩家头像和基本信息
- **游戏界面**：头像显示在玩家信息面板
- **交互功能**：点击头像立即生成新的食物主题头像
- **食物主题**：始终生成食物相关头像（🍕🍔🍦等）
- **离线支持**：头像缓存支持离线游戏

## 存档与回忆（模型与预览图）

- 生成完成后，系统会将资源保存到用户目录：
  - 模型：`user://recipes/<task_id>.glb`
  - 预览图：`user://recipes/<task_id>.png`
  - 头像缓存：`user://avatars/<style>_<seed>_<size>.png`
- Windows 实际路径一般位于：
  - `C:\Users\<用户名>\AppData\Roaming\Godot\app_userdata\<项目名>\`
- 这些路径也会记录在内存数据结构中，便于后续在"仓库/回忆"中浏览与复用。

## Tripo 模型调取与显示：实战经验

- 提取模型 URL：
  - 先判断任务 `status == success`；从响应的 `data` 或顶层字段里查找。
  - 优先在 `output` 或 `result` 下寻找：
    - `pbr_model`（字符串或 `{ url: ... }` 对象）
    - 兼容 `model/glb_url/gltf_url/mesh/mesh_url/file_url` 等键
  - 若上述均无，则递归遍历字典，搜寻包含 `.glb/.gltf` 的字符串作为兜底。
  - 成功但暂未回传 URL 时，做短轮询兜底（例如每 2 秒重试，最多 3 次）。

- 下载与解析 GLB：
  - 使用一次性 `HTTPRequest` 直接 GET 已签名的 GLB URL，并带上 `Accept: model/gltf-binary, application/octet-stream`。
  - 解析优先用 Godot 4 的 `GLTFDocument.append_from_buffer(...)` + `generate_scene(...)`，避免依赖导入管线。
  - 回退方案：将字节流保存到 `user://temp_tripo_model.glb`（或目标保存路径），再用 `ResourceLoader.load` 加载为 `PackedScene` 实例化。
  - 注意：Tripo 返回的签名 URL 有有效期，应当拿到后立即下载并（可选）本地持久化。

- 实例化与可视化：
  - 将实例放入 `SubViewport` 的 `DishRoot` 下的新容器中，添加缓慢自转动效以增强观感。
  - 计算所有 `MeshInstance3D` 的合并 AABB：
    - 将中心对齐到盘面的轻微高度（例如 y=0.15），并依据最大边长自适应缩放至目标半径，避免过大/过小或漂移出视野。
    - 自动调整 `Camera3D` 距离与朝向，使模型稳定进入视野。
  - 透明背景与防闪烁：
    - `SubViewport.transparent_bg = true`，并将 `render_target_clear_mode` 设为 `CLEAR_MODE_ALWAYS`。
    - 在 3D 世界中放置 `WorldEnvironment`，将 `Environment.background_mode = BG_COLOR` 且背景颜色透明。
    - 当 3D 模型显示时隐藏叠层的图片预览，避免叠加导致的闪烁。

- 本地持久化：
  - GLB 文件与预览图分别保存到：
    - `user://recipes/<task_id>.glb`
    - `user://recipes/<task_id>.png`
  - 目录不存在时在运行时自动创建；路径也会记录在内存数据结构中，便于后续“仓库/回忆”功能读取。

- 常见坑点与对策：
  - URL 字段不固定：注意 `pbr_model` 可能是字符串或对象，且可能位于 `output/result`；必要时递归兜底搜索。
  - 透明视口闪烁：开启透明背景后务必启用 `CLEAR_MODE_ALWAYS`，并避免图片层与 3D 层叠加显示。
  - 模型不可见：大概率是模型尺度/偏移或相机未对准；用合并 AABB 做居中与自适应缩放，并自动相机取景。
  - `HTTPRequest` 忙碌冲突：使用一次性请求器，回调后立即 `queue_free()`。
  - Godot 版本差异：Godot 4 使用 `GLTFDocument.append_from_buffer` 而非旧版的 `parse`；注意 API 变更。

## 常见问题（排错）
- Identifier 未声明：确保 `Scripts/GameManager.gd` 和 `Scripts/TripoAPI.gd` 带有 `class_name`，或在 `MainGame.gd` 顶部使用 `preload()`。
- set_client_id 不存在：项目已做向后兼容，若方法缺失会直接设置字段 `client_id`。
- Invalid assignment translation：Godot 4 使用 `position` 替代 `translation`。
- ERR_BUSY(44)：状态轮询使用一次性 `HTTPRequest`，避免复用同一请求器。
- 3D 预览闪烁：确保 SubViewport 开启 `transparent_bg`，并将 `render_target_clear_mode` 设为 `CLEAR_MODE_ALWAYS`；当 3D 模型显示时隐藏叠加的图片预览层。
- 模型不可见或尺寸异常：已实现运行时 GLB 解析后自适应居中/缩放与相机自动取景；若仍不可见，请查看控制台是否有 GLB 下载失败或解析错误。

## 3D 模型位置处理经验

在开发过程中，我们遇到了 3D 模型在 SubViewport 中定位的挑战，以下是关键经验总结：

### 模型定位的常见陷阱
1. **相机 look_at 陷阱**：如果相机总是 `look_at(模型位置)`，无论模型容器怎么平移，视觉上模型都会被"拉回"屏幕中心
2. **旋转容器位移**：直接旋转包含模型的容器会导致模型在旋转时"飘移"，破坏固定位置效果
3. **视口裁剪问题**：模型移到边缘时容易被 SubViewport 边界裁剪，需要足够大的视口尺寸

### 正确的定位策略
```gdscript
# 1. 创建双层结构：外层容器负责定位，内层pivot负责旋转
var container := Node3D.new()
var pivot := Node3D.new()
container.add_child(pivot)
pivot.add_child(model_root)

# 2. 先做模型的居中缩放（在pivot内）
pivot.position = Vector3(-center.x, -center.y + height_offset, -center.z)
pivot.scale = Vector3.ONE * scale_factor

# 3. 平移整个容器到目标位置（如左上角）
container.position += Vector3(-5.2, 2.0, 0.0)

# 4. 相机固定看向世界原点，不跟随模型
camera.look_at(Vector3(0, 0, 0), Vector3.UP)

# 5. 仅旋转内层pivot，保持容器位置不变
var tween := get_tree().create_tween()
tween.set_loops()
tween.tween_property(pivot, "rotation:y", TAU, 8.0)
```

### 高级旋转效果
- **歪斜旋转轴**：先设置初始 rotation，再进行复合旋转
- **复合动画**：同时控制多个旋转轴，创造"摆动"效果
- **相机距离**：根据模型大小动态调整相机距离，确保完整可见

### 视口配置要点
- 使用足够大的 SubViewport 尺寸（如 1100×700）
- 启用透明背景：`transparent_bg = true`
- 设置清除模式：`render_target_clear_mode = CLEAR_MODE_ALWAYS`
- 合适的 FOV 值（推荐 45-55 度）

这些经验确保了标题页的 3D 封面能够稳定地在左上角进行动态展示，同时避免了位置飘移和视觉center化的问题。

## 标题页 3D 封面优化历程

在开发标题页的 3D 封面展示时，我们经历了一系列优化迭代，最终实现了完美的视觉效果：

### 初始问题与解决方案

#### 1. 模型大小与位置调整
- **问题**：模型太小，位置不够靠左
- **解决**：将 `target_radius` 从 1.25 增加到 3.0，让模型更大更显眼
- **位置优化**：将容器位置从 `Vector3(-5.2, 2.0, 0.0)` 逐步调整到 `Vector3(-14.0, 2.0, 0.0)`，实现"模型从左边探出来"的效果

#### 2. 旋转动画优化
- **问题1**：转轴在动，不是固定的斜轴自转
- **解决1**：改为"视轴自转"结构：外层 `AxisPivot` 对准相机方向，内层 `ModelPivot` 的 +Y 指向相机
- **问题2**：旋转一圈后停止
- **解决2**：使用 `tween_method + set_loops()` 实现持续循环旋转
- **问题3**：碗底朝向玩家
- **解决3**：调整内层旋转角度，确保"菜面"始终朝向玩家

#### 3. UI 交互问题
- **问题**：3D 预览覆盖了按钮，无法点击
- **解决**：在 `PreviewOverlay` 上设置 `mouse_filter = 2`，让 SubViewport 忽略鼠标事件

#### 4. 场景切换错误
- **问题**：切换场景时出现 "Invalid access to property 'rotation'" 错误
- **解决**：保存 tween 引用，在场景切换前调用 `rotation_tween.kill()` 停止动画

### 最终实现效果

```gdscript
# 视轴自转：外层对准相机，内层+Y朝向相机，外层绕视轴持续旋转
var pivot := container.get_node_or_null("ModelPivot")
if pivot and pivot is Node3D:
    var axis := Node3D.new()
    axis.name = "AxisPivot"
    container.add_child(axis)
    pivot.reparent(axis)
    # 对齐外层到相机方向
    var cam: Camera3D = preview_viewport.get_node("WorldRoot/Camera3D")
    if cam:
        axis.look_at(cam.global_transform.origin, Vector3.UP)
    # 让模型 +Y 指向相机方向的反向（-Z）：菜面朝向玩家
    pivot.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
    # 持续绕视轴（Z）旋转，永不停止
    rotation_tween = get_tree().create_tween()
    rotation_tween.set_loops()
    rotation_tween.tween_method(func(angle): axis.rotation.z = angle, 0.0, TAU, 8.0)
```

### 关键经验总结

1. **双层结构设计**：外层负责位置和朝向，内层负责旋转，避免位置飘移
2. **视轴自转**：让转轴始终对准相机，确保菜面始终朝向玩家
3. **持续循环**：使用 `tween_method + set_loops()` 避免旋转停止
4. **UI 层级管理**：设置 `mouse_filter = 2` 避免 3D 预览阻挡按钮交互
5. **资源清理**：在场景切换前停止动画，避免访问已销毁的节点

这些优化让标题页的 3D 封面实现了完美的视觉效果：模型大而醒目，位置靠左只展示一半，像地球一样有固定的斜转轴自转，菜面始终朝向玩家，同时不影响 UI 交互。

## 贡献

欢迎提交Issue和Pull Request来改进游戏！

## 许可证

MIT License

## 存档系统（Save/Load）与页面状态持久化（新增）

- 存档文件：`user://save.json`
  - Windows 路径示例：`C:\Users\<用户名>\AppData\Roaming\Godot\app_userdata\OddBites\save.json`

- 何时自动保存：
  - 抽卡成功后
  - 生成料理成功后（含 `suggested_price` 建议售价）
  - 出餐售卖成功后（写入 `sales_history`）
  - 页面交互（出餐选择/价格输入等）变化时会同步到内存，下一次触发保存时落盘

- 启动自动读取：
  - 在 `GameManager._ready()` 中自动读取 `user://save.json`，并在 `MainGame._ready()` 调用 `_restore_ui_state()` 恢复 UI 状态

- 存档包含内容：
  - 玩家数值：金币、等级、经验、免费次数
  - 卡片：`player_cards`（数组）、卡片稀有度库存 `player_card_inventory`
  - 料理：`player_recipes`（数组，内含 `attributes` 与 `suggested_price`）
  - 潮流与倒计时：`current_trends`、`trend_end_time`（过期则刷新）
  - 页面/UI 状态：
    - `ui_serve_selected_names` 出餐选择列表
    - `ui_serve_price_text` 实际售价输入框文本
    - `ui_serve_price_user_dirty` 价格是否被手动修改
    - `ui_serve_last_suggest` 建议售价缓存
    - `ui_selected_pool` 当前卡池
    - `ui_selected_cards_ids` 已选卡片ID
    - `ui_last_preview_task_id` 上一次预览的任务ID
    - `ui_broadcast_lines` 广播日志（最多保留200条）
  - 售卖历史：`sales_history`（数组），包含：
    - `timestamp`、`names`、合计属性（辣/甜/奇）、`total_cost`、`trend_bonus`、`suggest_price`、`asked_price`、`final_income`

- 清除/重置存档：
  - 直接删除 `user://save.json` 文件即可；下次启动使用默认数据

### 稀有度与成本（新增）
- 重复抽卡自动升级稀有度：`N → R(3) → SR(8) → SSR(20)`
- 成本倍率：`N×1.0, R×1.5, SR×2.5, SSR×4.0`
- 超额重复（SSR满级后）：折算为金币奖励
- 料理成本 = 卡片有效成本之和 + 加工费（每张卡片3金）
- 建议售价（持久化）= 成本 × 潮流加成，字段：`recipe_data.suggested_price`

### 常见报错与对策（汇总）
- Parser Error: Unexpected "?" → 使用 `a if cond else b`（已修复）
- Expected indented block after lambda → 匿名函数体需缩进（已修复）
- Invalid access to property 'pressed' on null → 连接信号前做 `is_instance_valid()` 检查（已修复）
- Invalid access to key 'rotation' on Nil → 将 `tween_method` 改为 `tween_property`，避免闭包持有已释放节点（已修复）
- Trying to assign Array to Array[Dictionary]/Array[String] → 读档时做强类型转换 `_to_dict_array/_to_string_array`（已修复）

### 进阶：多存档建议
- 目前为单文件 `user://save.json`
- 如需多档，可改为：`user://profiles/<code>.json`，在 `GameManager` 中切换 `profile_code` 即可
