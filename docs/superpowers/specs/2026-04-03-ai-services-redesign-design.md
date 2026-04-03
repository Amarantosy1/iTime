# AI 服务层重做设计

日期：2026-04-03  
状态：已评审设计，待写实现计划

## 背景

当前 AI 能力已经从单次评估扩展到了多 provider、独立对话窗口、历史总结和本地归档。但 API 配置层仍然沿用了 `mount` 概念，导致几个问题叠在一起：

- provider 类型、用户配置实例、默认选择和网络连通性概念混杂
- 设置页虽已拆成左右布局，但 AI 区域的内部结构仍偏“编辑挂载对象”，而不是“配置 AI 服务”
- 连接失败时，排查边界不清楚，容易把 provider、服务实例、网络层混为一谈
- 未来继续加自定义 provider 时，复杂度会继续上升

这轮目标不是继续修补现有挂载层，而是删除“挂载”抽象，重建为更接近成熟桌面 AI 客户端的“内置 provider + 自定义服务”结构。

## 目标

1. 删除当前 `AIProviderMount` 为核心的配置模型和相关文案。
2. 重做设置页 AI 配置，改为“AI 服务”信息架构。
3. 保留内置 provider：`OpenAI / Anthropic / Gemini / DeepSeek`。
4. 支持用户新增自定义服务，但自定义服务只支持 `OpenAI-compatible`。
5. AI 对话窗口开始前可选择“服务 + 模型”，会话开始后保持绑定不变。
6. 网络层默认继续跟随系统网络栈，不新增代理设置页。
7. 保留现有 API Key Keychain 存储能力，并做轻量迁移，避免用户现有配置丢失。

## 非目标

- 不新增系统代理、HTTP 代理或 SOCKS 代理设置
- 不做 provider marketplace
- 不做自动拉取远端模型列表
- 不做导入导出服务配置
- 不支持自定义 Anthropic/Gemini/DeepSeek 协议
- 不支持进行中的会话切换服务或模型

## 参考项目与借鉴范围

### 可借鉴交互，不直接抄代码

- Cherry Studio
  - 借鉴点：provider/settings 信息架构、自定义 provider 编辑流程
  - 不直接抄代码原因：AGPL-3.0
  - 参考：
    - https://github.com/CherryHQ/cherry-studio
    - https://docs.cherry-ai.com/en-us/pre-basic/settings/providers

- Chatbox
  - 借鉴点：服务实例与模型管理的产品层组织
  - 不直接抄代码原因：GPL-3.0
  - 参考：
    - https://github.com/chatboxai/chatbox

### 可直接借鉴实现思路

- Jan
  - 借鉴点：provider 与 endpoint 分层、默认服务/模型组织方式
  - 许可证：Apache-2.0
  - 参考：
    - https://github.com/janhq/jan
    - https://www.jan.ai/docs/desktop/settings

## 总体方案

采用“Provider Catalog + Service Endpoint”两层模型：

- `Provider Catalog`
  - 描述系统支持哪些 provider 类型，以及每种 provider 的默认行为
  - 内置 4 个固定 provider：`OpenAI / Anthropic / Gemini / DeepSeek`
  - 额外提供一个可配置的 `OpenAI-compatible` 自定义类型

- `Service Endpoint`
  - 表示用户真实配置的一个 AI 服务实例
  - 例如：
    - OpenAI 官方
    - DeepSeek 官方
    - 公司 OpenAI 代理
    - 自建 OpenAI-compatible 网关

这样“provider 是什么”和“用户连到哪里”解耦，后续 UI、持久化、请求路由都更清晰。

## 数据模型

### 新增或重命名模型

#### `AIProviderCatalogItem`

描述 provider 类型和展示信息。

建议字段：

- `kind: AIProviderKind`
- `title: String`
- `defaultBaseURL: String`
- `supportsCustomEndpoint: Bool`
- `isBuiltIn: Bool`

说明：
- `OpenAI / Anthropic / Gemini / DeepSeek` 都是 built-in catalog item
- 自定义服务创建时，provider type 仅允许选择 `openAICompatible`

#### `AIServiceEndpoint`

替代当前 `AIProviderMount`，表示真实服务实例。

建议字段：

- `id: UUID`
- `displayName: String`
- `providerKind: AIProviderKind`
- `baseURL: String`
- `models: [String]`
- `defaultModel: String`
- `isEnabled: Bool`
- `isBuiltIn: Bool`

不在该模型中存储 API Key，继续只在 Keychain 按 `id` 保存。

### 现有枚举调整

`AIProviderKind` 扩展为：

- `openAI`
- `anthropic`
- `gemini`
- `deepSeek`
- `openAICompatible`

说明：
- 前四个是内置 provider 类型
- `openAICompatible` 只用于自定义服务

## 持久化与迁移

### 持久化

`UserPreferences` 中：

- 删除旧的 `aiProviderMounts`
- 删除旧的 `defaultAIMountID`
- 新增：
  - `aiServiceEndpoints`
  - `defaultAIServiceID`

### 迁移策略

首次加载新版本配置时：

1. 如果新 `aiServiceEndpoints` 已存在，直接使用。
2. 否则读取旧 `AIProviderMount` 数据：
   - built-in mount 迁移为 built-in service endpoint
   - custom mount 迁移为 custom `openAICompatible` service endpoint
3. `defaultAIMountID` 迁移为 `defaultAIServiceID`
4. Keychain 不迁移内容，只继续按已有 UUID 读取

迁移完成后，写回新格式，后续不再依赖旧字段。

## 设置页设计

设置页保持 Apple 经典布局：

- 左侧 sidebar
  - `统计日历`
  - `AI 服务`
- 右侧 detail
  - 按左侧分类展示对应内容

### `AI 服务` 页面结构

右侧内容分三段：

1. `默认服务`
   - 下拉选择默认 `AIServiceEndpoint`

2. `内置服务`
   - 展示 4 个 built-in service endpoint
   - 每个服务都可以编辑：
     - Base URL
     - API Key
     - 模型列表
     - 默认模型
     - 启用状态
     - 测试连接

3. `自定义服务`
   - 列表展示用户新增的自定义服务
   - 新建按钮创建 `OpenAI-compatible` 服务
   - 支持编辑和删除

UI 文案统一使用“服务”，彻底移除“挂载”措辞。

## 对话窗口设计

AI 对话窗口在会话开始前显示：

- `服务` 选择器
- `模型` 选择器

行为规则：

- 只能在会话开始前切换
- 一旦开始：
  - 会话绑定 `serviceID + providerKind + model`
  - 后续问答和总结都沿用该绑定
- 进行中的会话不跟随设置页默认服务变化

## 路由与网络设计

### 路由

当前 provider routing 重构为：

1. 根据 `serviceID` 找到 `AIServiceEndpoint`
2. 根据 `providerKind` 选择 adapter
3. 发请求时使用 endpoint 的 `baseURL + model + API key`

规则：

- `OpenAI` 和 `DeepSeek` 可继续走 OpenAI-compatible adapter
- `Anthropic` 走 Anthropic adapter
- `Gemini` 走 Gemini adapter
- `OpenAI-compatible` 走 OpenAI-compatible adapter

### 网络

不新增网络设置页，不做代理 UI。

网络默认策略：

- 使用系统默认网络栈
- 跟随系统代理
- 不在 app 内部暴露代理配置

## 删除范围

这轮需要明确移除或废弃以下旧概念：

- `AIProviderMount`
- `defaultAIMountID`
- `defaultAIMount`
- `availableAIMounts`
- `createCustomAIMount()`
- `updateAIMount()`
- `deleteAIMount()`
- `setDefaultAIMount()`
- `testAIMountConnection()` 中与 mount 绑定的文案和状态命名

文案层：

- “挂载”全部改成“服务”

## 测试计划

### 模型与持久化

- 旧 mount 数据可迁移为新 service endpoint
- 默认 mount 可迁移为默认 service
- built-in service 默认存在
- 自定义 service 只能创建为 `openAICompatible`

### AppModel

- 开始对话时绑定选中的 `serviceID + model`
- 切换默认服务不影响进行中的会话
- 测试连接只依赖 service 自身 `isEnabled`

### UI

- 设置页 sidebar 包含 `统计日历 / AI 服务`
- `AI 服务` 页不再出现“挂载”文案
- 对话窗口开始前显示服务和模型选择器

### 网络层

- sender 使用默认 session configuration
- 不显式设置 proxy dictionary
- `OpenAI-compatible` 服务走对应 adapter

## 风险与取舍

### 风险

- 这轮会改动设置页、持久化和对话入口，涉及面较广
- 如果迁移边界没做清楚，可能导致现有用户 AI 配置丢失

### 取舍

- 明确不保留“挂载”概念兼容层，避免继续双轨运行
- 明确不做代理设置，减少一个易失控子系统
- 自定义 provider 只支持 `OpenAI-compatible`，换取实现清晰度

## 结论

这轮不是继续补 AI 挂载，而是把 AI 配置层正式升级为“AI 服务”。

推荐按以下顺序实施：

1. 数据模型与持久化迁移
2. `AppModel` 和路由层切到 service endpoint
3. 设置页 `AI 服务` 页面重写
4. 对话窗口开始前选择器重写
5. 文案与测试清理
