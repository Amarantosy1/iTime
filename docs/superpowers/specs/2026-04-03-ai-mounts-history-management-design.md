# AI 挂载、历史管理与复盘退出设计

## Summary

这一轮把 AI 复盘从“能用”推进到“可管理、可中断、可扩展”。

目标有三块：

1. 历史总结支持彻底删除，而不是只能查看。
2. 复盘窗口支持“退出本轮但不形成报告”，并明确与“结束复盘生成报告”区分。
3. 参考 Cherry Studio 的 provider/settings 思路，把当前固定四家 provider 的扁平配置重构为可扩展的“AI 挂载层”，并允许在复盘开始前切换挂载和模型。

这轮不会做远端模型自动拉取、导入导出、路由策略或会话中途切模型。重点是把配置抽象、会话绑定和历史管理一次做对。

参考：

- Cherry Studio provider settings
  https://docs.cherry-ai.com/en-us/pre-basic/settings/providers
- Cherry Studio custom providers
  https://docs.cherry-ai.com/docs/en-us/pre-basic/providers/zi-ding-yi-fu-wu-shang

## Goals

- 支持删除历史总结，并清理关联会话和失效 memory。
- 在独立 AI 复盘窗口增加左上角无文字返回键，用于放弃当前未完成复盘。
- 将 AI 配置从“固定 provider 配置”升级为“provider mount 配置”。
- 支持内置 provider 与自定义挂载共存。
- 在复盘窗口开始前切换挂载和模型。
- 确保进行中的会话绑定启动时的挂载与模型，不受后续设置变化影响。

## Non-Goals

- 不做会话中途切换模型或 provider。
- 不做自动拉取远端模型列表。
- 不做导入导出挂载配置。
- 不做多 key 轮询或自动 fallback。
- 不做向量检索或新的 memory 架构调整。
- 不做菜单栏中的 AI 配置入口。

## Current Problems

### 1. 历史总结不可管理

当前历史页只有查看能力，没有删除入口。归档数据一旦生成，只能不断累积，无法清理误生成、无效或不再需要的总结。

### 2. 退出语义不清

当前对话窗口只有：

- 关闭窗口
- 结束复盘

但没有“放弃这轮对话”的正式路径。用户如果只是想退出，不希望形成报告，当前产品语义不明确。

### 3. AI 配置抽象过低

当前设置页围绕 `OpenAI / Anthropic / Gemini / DeepSeek` 四家做固定表单，每家仅有：

- `Base URL`
- `Model`
- `API Key`
- `isEnabled`

这导致几个问题：

- 无法新增自定义 provider 挂载。
- 模型只能是单个字符串，无法管理候选模型。
- 默认项绑定的是 provider kind，不是具体挂载实例。
- 会话层无法明确记录“这轮复盘使用的是哪一个挂载实例和模型”。

### 4. 复盘开始前无法显式切换模型

当前模型只能去设置里改默认值，复盘窗口本身没有开始前选择挂载和模型的入口，导致高频使用路径绕远。

## Proposed Design

## 1. AI 挂载层

将现有 provider 配置升级为 `AIProviderMount`。

### 数据模型

新增：

- `AIProviderMount`
  - `id: UUID`
  - `displayName: String`
  - `providerType: AIProviderKind`
  - `baseURL: String`
  - `apiKeyStorageKey: String`
  - `models: [String]`
  - `defaultModel: String`
  - `isEnabled: Bool`
  - `isBuiltIn: Bool`

- `ResolvedAIProviderMount`
  - `id`
  - `displayName`
  - `providerType`
  - `baseURL`
  - `apiKey`
  - `models`
  - `selectedModel`
  - `isEnabled`

保留 `AIProviderKind`，但它的职责降级为“请求适配器类型”和“默认 URL / 默认展示名来源”，不再等价于最终配置本体。

### 持久化

- `UserPreferences` 不再按 provider kind 分散保存字段，而是持久化挂载列表和 `defaultMountID`。
- `API Key` 继续存在 Keychain，但 key 从“provider kind”升级为“mount id”。
- 启动时自动迁移旧数据：
  - 为四家内置 provider 生成 built-in mounts
  - 读取旧配置填充到对应 built-in mount
  - 迁移旧默认 provider 到 `defaultMountID`

### 挂载规则

- 内置挂载默认存在：
  - OpenAI
  - Anthropic
  - Gemini
  - DeepSeek
- 用户可新增自定义挂载。
- 自定义挂载需要显式选择 `providerType`，这样请求层知道如何路由。

## 2. 设置页重构

设置页从“固定四段表单”改成“挂载列表 + 详情编辑器”。

### 左侧

- 挂载列表
- 显示名称、provider 类型、启用状态
- 支持选择默认挂载
- 支持新增自定义挂载
- 支持删除自定义挂载

### 右侧

当前选中挂载的详情编辑器：

- 显示名称
- provider 类型
- Base URL
- API Key
- 启用开关
- 模型列表编辑
- 默认模型选择
- 测试连接按钮

### 行为约束

- built-in mount 不允许删除，但允许改 URL、模型、API Key 和启用状态。
- custom mount 允许删除。
- 若删除的是默认挂载，自动切到第一个可用挂载；若没有可用挂载，则默认挂载为空。
- 测试连接只做最小连通性验证，不做模型枚举。

## 3. 复盘窗口开始前切换挂载和模型

在 AI 复盘窗口顶部加入开始前选择器。

### 未开始状态

显示：

- 挂载选择
- 模型选择
- 开始新复盘按钮

模型候选来自当前挂载的 `models` 列表。如果列表为空，则允许使用 `defaultModel` 作为唯一候选。

### 已开始状态

一旦会话启动：

- 当前会话绑定 `mountID`
- 当前会话绑定 `providerType`
- 当前会话绑定 `model`

之后窗口顶部选择器切为只读摘要，不允许再切换。

这条规则适用于：

- 首轮提问
- 后续追问
- 最终总结

它们都使用同一个会话绑定，不跟随设置页默认挂载或模型变化。

## 4. 放弃本轮复盘

在 AI 复盘窗口左上角新增无文字返回键，仅用图标。

### 行为

- 当会话未完成时，点击返回键：
  - 弹出确认
  - 用户确认后，丢弃当前进行中的会话
  - 不生成总结
  - 不写入历史总结
  - 关闭窗口

- 当会话已完成或仍处于 idle 时：
  - 直接关闭窗口

### 语义区分

- `结束复盘`：生成报告并归档
- 左上角返回：放弃本轮，不生成报告

这样两种退出路径不会混淆。

## 5. 历史总结彻底删除

历史页新增删除能力。

### 删除范围

删除一条历史总结时，同时删除：

- 对应 `AIConversationSummary`
- 关联 `AIConversationSession`

以及处理 memory：

- 如果某条 `AIMemorySnapshot` 的 `sourceSummaryIDs` 全部失效，则删除该 memory。
- 如果某条 memory 只部分依赖已删 summary，则整条 memory 视为失效并删除，不做局部修补。

原因是当前 memory 是 compact 产物，做局部修补会让语义不可信。更稳的做法是删除失效 memory，等待后续重建。

### UI

- 历史列表页提供删除入口
- 详情页也提供删除入口
- 删除前弹确认
- 删除后自动重新选择下一条可用记录
- 全部删空后回到空态

## 6. AppModel 与服务调整

### AppModel

新增或调整：

- `availableAIMounts`
- `defaultAIMountID`
- `selectedConversationMountID`
- `selectedConversationModel`
- `deleteAISummary(_:)`
- `discardCurrentAIConversation()`
- `testAIMountConnection(_:)`

### 会话模型

`AIConversationSession` 和 `AIConversationSummary` 增加：

- `mountID`
- `mountDisplayName`
- `providerType`
- `model`

为兼容旧历史记录，缺失这些字段时回退：

- `mountDisplayName = providerType.title`
- `model = ""`
- `mountID = nil`

### 路由层

`AIConversationRoutingService` 继续按 `providerType` 分发到：

- OpenAI
- Anthropic
- Gemini
- DeepSeek

但调用入口从“resolved provider config”改为“resolved mount”。

## 7. Error Handling

- 如果默认挂载不存在或未启用，复盘窗口进入 unavailable 状态并提示去设置。
- 如果挂载存在但无可用模型，开始前禁止启动复盘。
- 如果删除历史时底层归档写入失败，保留当前 UI 状态并显示错误。
- 如果退出本轮时归档清理失败，不关闭窗口，提示重试。
- 如果测试连接失败，设置页展示明确失败信息，不改变挂载状态。

## 8. Testing

### 挂载层

- 旧 provider 配置迁移到 built-in mounts
- 自定义 mount 可新增、编辑、删除
- `defaultMountID` 正确持久化
- Keychain 按 mount id 存取 API Key

### 会话绑定

- 开始前可切换挂载和模型
- 开始后绑定不变
- 设置页默认值变化不影响进行中的会话

### 历史删除

- 删除 summary 会删除关联 session
- 删除 summary 会清掉失效 memory
- 删除后列表选中态正确

### 放弃本轮

- 未完成会话退出后不生成报告
- 未完成会话退出后不进入历史
- 已完成状态返回只关闭窗口

### 设置页

- built-in mount 不可删除
- custom mount 可删除
- 模型列表编辑和默认模型选择正确
- 测试连接状态正确反馈

## 9. Implementation Notes

建议按下面顺序实施：

1. 挂载模型与持久化迁移
2. `AppModel` 绑定逻辑与默认 mount 状态
3. 设置页挂载列表 + 编辑器
4. 复盘窗口开始前挂载/模型选择
5. 左上角返回退出与丢弃会话
6. 历史总结删除
7. 测试连接

这样可以先稳定底层抽象，再改 UI，不会把旧 provider 配置和新 mount 结构混用太久。
