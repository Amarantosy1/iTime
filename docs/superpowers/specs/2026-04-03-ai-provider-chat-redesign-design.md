# AI Provider And Chat Window Redesign

## Summary

`iTime` 现有 AI 功能已经具备本地会话归档、事件级上下文和基础多轮问答能力，但产品形态仍然不稳定。当前对话 UI 被直接嵌在详情页统计卡片中，输入框和会话状态共享同一块滚动内容与重绘路径，导致焦点不稳定，出现点击输入框后退出的交互问题。与此同时，设置页仍然只支持单一“兼容 OpenAI 接口”的配置，无法满足同时使用 `OpenAI / Anthropic / Gemini / DeepSeek` 的需求。

这次重设计的目标是把 AI 从“统计页里的一张动态卡片”升级成两块清晰的产品面：

1. 设置页中的多 provider 管理
2. 独立 AI 对话窗口

详情页不再承载完整聊天界面，只保留 AI 入口和最近一次总结摘要。这样既能解决聊天焦点和状态抖动问题，也能为后续历史总结、memory compact、provider 扩展留出清晰边界。

## Goals

- 支持 `OpenAI / Anthropic / Gemini / DeepSeek` 四个 provider 的独立配置
- 允许分别保存各自的 `Base URL / Model / API Key`
- 提供一个 `defaultProvider` 作为默认发起 AI 会话的来源
- 将 AI 聊天从详情页内嵌卡片迁移到独立窗口
- 保持现有本地会话归档、历史总结和事件级上下文能力
- 让 AI 对话输入区稳定可用，不再因详情页重绘或卡片切换而退出

## Non-Goals

- 这次不做 provider 级会话切换历史筛选
- 这次不做多窗口并行会话
- 这次不做 provider 连接测试向导
- 这次不做 memory compact 逻辑增强
- 这次不做聊天记录搜索或标签系统
- 这次不做 provider 自动降级或模型回退链

## External References

这次方案主要借鉴的不是具体视觉，而是成熟产品的结构分层：

- Chatbox：多 provider 桌面配置与聊天区解耦
- LibreChat：默认 provider 与 provider 独立配置并存
- Jan：聊天是独立工作区，不依附在别的业务面板里
- OpenCat：原生客户端里 provider 作为明确的连接模式存在

这些产品的共同结论是：

- provider 配置必须单独建模
- 聊天输入区必须固定在专用视图中
- 会话 UI 不应挂在一个会频繁重绘的 dashboard 卡片里

## Design

### 1. Provider Domain Model

新增一组 provider 相关类型，替代当前只有一套 `baseURL / model / apiKey / isEnabled` 的形态。

建议新增：

- `AIProviderKind`
  - `openAI`
  - `anthropic`
  - `gemini`
  - `deepSeek`
- `AIProviderConfiguration`
  - `provider`
  - `baseURL`
  - `model`
  - `isEnabled`
- `AIProviderSelection`
  - `defaultProvider`

敏感信息继续不进入 `UserDefaults`。API Key 按 provider 分开存进 Keychain，例如：

- `openai`
- `anthropic`
- `gemini`
- `deepseek`

`AppModel` 读取当前默认 provider 时，会将：

- 非敏感配置从 `UserPreferences`
- 对应 provider 的 API Key 从 Keychain

组合成运行时配置对象，例如：

- `ResolvedAIProviderConfiguration`

### 2. Settings Redesign

设置页中的 AI 区从单一表单改成“默认 provider + provider 配置列表”。

推荐结构：

1. 总开关
   - `启用 AI 时间评估`
2. 默认 provider 选择器
   - `OpenAI / Anthropic / Gemini / DeepSeek`
3. provider 分组配置
   - 每个 provider 一节
   - 每节包含：
     - 启用开关
     - `Base URL`
     - `Model`
     - `API Key`

行为规则：

- `defaultProvider` 可以选择任一 provider，但如果该 provider 未完成配置，详情页与对话窗口要提示“默认 provider 未配置完成”
- 每个 provider 独立启停
- 默认 provider 不自动覆盖别的 provider 字段
- 这次不做“新增自定义 provider”，只支持固定四个

### 3. Chat Window Redesign

新增独立 AI 对话窗口，替代详情页内嵌聊天卡片。

窗口结构固定为三段：

1. 顶栏
   - 当前统计范围
   - 当前 provider / model
   - 新建复盘按钮
   - 查看历史按钮
2. 中间消息区
   - 可滚动消息列表
   - 显示 `AI / 你`
   - 对话完成后在同一窗口展示总结
3. 底部输入区
   - 固定文本输入框
   - `发送`
   - `结束复盘`

关键原则：

- 输入区不放进主滚动容器
- 消息区和输入区视图边界分开
- 焦点状态由窗口级 `@FocusState` 管理
- 历史列表不和当前聊天区做复杂嵌套切换

详情页中的 AI 区改成更轻的入口卡片：

- 显示最近一次总结标题或摘要
- `打开 AI 复盘` 按钮
- `查看历史总结` 按钮
- 不再内嵌输入框与消息列表

### 4. Window Management

`iTimeApp` 新增一个 AI 对话窗口场景，例如：

- `Window("AI 复盘", id: "ai-conversation")`

触发方式：

- 从详情页按钮打开
- 后续也可从菜单栏入口打开，但这次不做菜单栏入口

`AppModel` 继续作为共享状态源，但窗口只消费 AI 会话状态，不再依赖详情页卡片驱动会话流程。

### 5. Provider-Aware Service Routing

现有 `OpenAICompatibleAIConversationService` 只是一种“chat completions 风格”请求构造，不适合硬套四个 provider。

这次建议引入路由层：

- `AIConversationRoutingService`
  - 对外实现统一 `AIConversationServing`
  - 根据 `AIProviderKind` 选择具体 provider client

内部按 provider 拆实现：

- `OpenAIConversationService`
- `AnthropicConversationService`
- `GeminiConversationService`
- `DeepSeekConversationService`

这些实现共享一套上层语义：

- `askQuestion`
- `summarizeConversation`

但各自负责不同的 HTTP 端点、header、body 结构和响应解析。

这次只覆盖会话问答和总结，不扩展 memory compact provider 路由。

### 6. AppModel Behavior

`AppModel` 保持当前对话状态机，但启动会话时不再隐式依赖“全局唯一 AI 配置”。

更新后的行为：

- `startAIConversation()`
  - 读取 `defaultProvider`
  - 校验该 provider 是否启用且配置完整
  - 将 provider 信息写入当前会话上下文
- `sendAIConversationReply(_:)`
  - 使用当前会话绑定的 provider
- `finishAIConversation()`
  - 使用当前会话绑定的 provider

会话一旦开始，不因为设置页修改默认 provider 而中途切 provider。

### 7. Conversation History UX

历史总结入口继续保留，但从详情页卡片按钮和独立聊天窗口顶栏都能进入。

这次只做最小可用：

- 历史列表
- 单条摘要显示
- 当前窗口内查看历史列表

不要求本轮实现“历史详情页很复杂”，但至少不能比现在更弱。

### 8. Stability Fix Strategy

本次不是只修一个 `TextField` 焦点 bug，而是通过结构重构根治不稳定来源。

明确替换掉当前不稳定条件：

- 详情页 `ScrollView` 中嵌套聊天输入区
- 聊天状态切换导致整张统计卡片重建
- 历史 sheet、会话输入和详情页滚动共用同一交互上下文

重构后：

- 详情页只保留稳定按钮
- 聊天窗口独立承载焦点与消息状态
- 输入框所在视图不会因详情页统计刷新而销毁

## Files Expected To Change

高概率涉及这些文件或等价新文件：

- `Sources/iTime/App/AppModel.swift`
- `Sources/iTime/iTimeApp.swift`
- `Sources/iTime/Support/Persistence/UserPreferences.swift`
- `Sources/iTime/Support/Persistence/AIAPIKeyStoring.swift`
- `Sources/iTime/Domain/AIConversation.swift`
- `Sources/iTime/UI/Settings/SettingsView.swift`
- `Sources/iTime/UI/Overview/OverviewAIAnalysisSection.swift`

新增文件大概率包括：

- `Sources/iTime/Domain/AIProvider.swift`
- `Sources/iTime/Services/AIConversationRoutingService.swift`
- `Sources/iTime/Services/OpenAIConversationService.swift`
- `Sources/iTime/Services/AnthropicConversationService.swift`
- `Sources/iTime/Services/GeminiConversationService.swift`
- `Sources/iTime/Services/DeepSeekConversationService.swift`
- `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift`
- `Sources/iTime/UI/AIConversation/AIConversationMessagesView.swift`
- `Sources/iTime/UI/AIConversation/AIConversationComposerView.swift`
- `Sources/iTime/UI/AIConversation/AIConversationHistoryView.swift`

## Error Handling

- 默认 provider 未启用：显示明确不可用状态
- 默认 provider 配置不完整：提示去设置页补齐
- provider 请求失败：保留当前会话消息，不清空用户输入
- 切换默认 provider：只影响新会话，不影响已有会话
- 某个 provider 的 API Key 缺失：只阻塞该 provider，不影响别的 provider 配置

## Testing

### Provider Config

- `UserPreferences` 持久化 `defaultProvider`
- 各 provider 的 `baseURL / model / isEnabled` 分别持久化
- Keychain 按 provider 独立读写 API Key

### Routing

- `startAIConversation()` 使用默认 provider
- provider 改变后新会话生效，旧会话保持原 provider
- 各 provider 路由到正确 service

### UI

- 设置页文案和 provider 列表顺序
- 详情页 AI 卡片不再包含输入框
- AI 对话窗口 copy 正确
- 历史按钮在有历史时显示

### Stability Regression

- 点击输入区不会关闭聊天窗口
- 发送消息和结束复盘不会丢失当前会话
- 切换详情页范围不会导致已打开聊天窗口直接退出

## Risks

- 四个 provider 的 HTTP 接口形态不同，不能继续假设同一 JSON schema
- 如果继续把所有 provider 特殊逻辑塞进一个 service 文件，代码会迅速失控
- 如果独立窗口和详情页都直接改写同一大块 AI UI 状态，仍会出现状态竞争

## Recommendation

按两阶段推进：

1. 先完成 provider 配置分层和独立聊天窗口迁移
2. 再在新结构上做更强的历史详情和 memory compact

这样可以先解决当前最影响可用性的两个问题：

- 无法管理多个 AI
- 聊天输入区不稳定
