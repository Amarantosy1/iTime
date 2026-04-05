# iTime iOS 版本对齐与本地近场互传设计

## 1. 背景与目标

iTime 当前以 macOS 菜单栏为核心，已具备统计、AI 复盘、历史归档与设置能力。  
本设计目标是在 **不使用 iCloud/CloudKit** 的前提下，完成 iOS 首版并实现 Mac 与 iOS 的近场双向数据互传。

目标约束（已确认）：

- iOS 首版功能范围：统计看板 + 新建/继续复盘 + AI 配置 + 本地历史归档 + 基础设置。
- 同步技术路线：原生 `MultipeerConnectivity`（局域网 + 蓝牙近场）。
- 同步数据范围：复盘数据 + 应用设置。
- API Key：设备间端到端加密传输，接收端落地 Keychain。
- 冲突策略：可合并字段自动合并；冲突字段按最后修改时间覆盖。
- 同步触发：首版手动触发（“设备互传”页点击“立即同步”）。
- iOS 最低版本：`iOS 17+`。

## 2. 范围与非目标

### 2.1 In Scope

- iOS 独立统计查看能力（今天/本周/本月/自定义）。
- iOS 复盘对话流程（启动、追问、总结、历史查看、长文查看）。
- iOS 侧 AI 服务管理与提醒配置。
- Mac <-> iOS 近场双向同步（手动触发）。
- 同步后双端状态一致（复盘档案、偏好设置、AI 服务配置）。

### 2.2 Out of Scope（首版不做）

- iCloud / CloudKit 相关能力。
- 自动后台实时同步。
- 跨平台（Android/Windows）协议兼容。
- 系统日历原始事件同步（依旧各设备本地 EventKit 读取）。

## 3. 方案对比与决策

评估过三条路线：

1. `SharedCore + 原生 MPC`（选中）
2. 强依赖第三方封装（如直接重度绑定 MultipeerKit）
3. 完全自研底层发现/传输

最终决策：**路线 1**。  
原因：在开发效率、可控性、长期可演进性之间平衡最好；可以先完成“手动近场同步”闭环，再平滑扩展自动同步/远程中继。

参考项目：

- `insidegui/MultipeerKit`（高成熟度，iOS/macOS，Codable 消息）
- `dingwilson/MultiPeer`（自动发现/连接体验可借鉴）
- `eugenebokhan/bonjour`（发现层细节参考）
- `localsend/localsend`（协议分层、状态管理与故障处理思路参考）

## 4. 总体架构

### 4.1 模块拆分

新增一个共享 Swift Package：`SharedCore`（名称可在实现时微调）。

- `SharedCore/Domain`
  - 复用并扩展 `AIConversationArchive`、`AIServiceEndpoint`、同步消息模型等。
- `SharedCore/PersistenceContracts`
  - 抽象归档与偏好读写协议，统一 Mac/iOS 读写语义。
- `SharedCore/Sync`
  - `MultipeerTransport`：设备发现、会话管理、消息收发。
  - `SyncCoordinator`：一次同步生命周期编排。
  - `SyncEngine`：差异计算、冲突合并、补丁应用。
  - `CryptoEnvelope`：敏感字段（API Key）加解密封装。

平台层：

- macOS：保留当前 `Sources/iTime` 结构和菜单栏入口。
- iOS：在 `iTime-iOS` 下补齐 App 入口、页面和 ViewModel，但业务逻辑优先复用 `SharedCore`。

### 4.2 分层原则

- UI 不直接处理同步细节，只消费同步状态（idle/running/succeeded/failed）。
- 同步协议、冲突合并、加密处理全部下沉到 `SharedCore`。
- 平台差异仅保留在：权限请求、场景生命周期、窗口/导航模型、通知实现。

## 5. 数据模型与同步边界

### 5.1 同步对象

1. 复盘档案：`AIConversationArchive`
   - `sessions`
   - `summaries`
   - `memorySnapshots`
   - `longFormReports`
2. 应用设置：
   - 统计范围、日历选择、复盘提醒、AI 服务 endpoint 元数据
3. API Key：
   - 不进入普通偏好 JSON，单独走加密消息并写入 Keychain。

### 5.2 非同步对象

- EventKit 原始事件数据（按设备本地日历权限与本地数据源计算）。

### 5.3 版本与时间戳

为可同步实体提供统一同步元数据（可通过 wrapper 扩展，不破坏现有 UI 结构）：

- `recordID`
- `updatedAt`
- `deletedAt`（可选，tombstone）
- `version`（整数，调试与排序辅助）

## 6. 冲突合并策略

### 6.1 基本规则

- 列表型集合：按 `recordID` 去重。
- 同 ID 同字段冲突：取 `updatedAt` 更新者（LWW，Last Write Wins）。
- 无 `updatedAt` 的旧数据：回退到 `createdAt` 或迁移时注入当前时间。

### 6.2 删除一致性

采用 tombstone：

- 删除时不立即硬删同步视图，记录 `deletedAt`。
- 同步合并时若 tombstone 新于对端实体更新时间，删除胜出。
- 达到清理窗口后再本地压实（vacuum/compact）历史 tombstone。

### 6.3 失败回滚

- patch 合并按批次事务化。
- 单批失败仅回滚该批，保留已确认批次，避免全量损坏。

## 7. 同步协议（MPC）

### 7.1 连接与发现

- 固定 `serviceType`（例如 `itime-sync`，实际实现需满足 Apple 长度/字符约束）。
- 设备显示名可配置，首次连接显示配对确认。

### 7.2 消息流

1. `Hello`：交换设备信息、协议版本。
2. `SyncManifest`：交换数据摘要（每类数据版本向量/哈希）。
3. `SyncRequest`：请求缺失分片。
4. `SyncPatch`：传输增量数据。
5. `SyncResult`：返回合并结果、冲突统计、失败项。

### 7.3 同步模式

- 首版仅“手动立即同步”。
- UI 展示最近一次同步时间、同步对象数量、错误摘要。

## 8. 安全设计

### 8.1 传输安全

- 近场链路由 MPC 提供会话层保障。
- 对 `apiKey` 字段再做应用层加密（双保险）。

### 8.2 API Key 加密

- 首次会话建立：生成会话密钥材料（基于 CryptoKit 的密钥交换 + HKDF 派生）。
- `apiKey` 使用 `AES.GCM`（或等价 AEAD）加密后放入 `EncryptedSecretPayload`。
- 接收端解密成功后直接写 Keychain，不落盘明文。

### 8.3 密钥生命周期

- 会话结束销毁临时会话密钥。
- 长期设备信任信息仅存最小必要元数据（设备 ID、上次配对时间、指纹）。

## 9. iOS 端产品形态

建议 iOS 首版信息架构：

- `Tab 1: 统计`
  - 时间范围切换、图表、关键指标。
- `Tab 2: 复盘`
  - 新建复盘、继续会话、历史总结/长文。
- `Tab 3: 设置`
  - AI 服务配置、提醒设置、设备互传入口。
- `设备互传` 子页
  - 附近设备列表、连接状态、立即同步按钮、结果日志。

## 10. 错误处理与可观测性

- 明确区分错误类型：发现失败、连接失败、鉴权失败、解密失败、合并失败。
- 每次同步生成 `SyncSessionLog`（本地可读、可清理）。
- UI 对用户输出中文可操作建议（如“请确认两端在同一局域网并已授予本地网络权限”）。

## 11. 测试与验收

### 11.1 单元测试

- `SyncEngine`：合并、冲突、tombstone 处理。
- `ManifestDiff`：差异计算正确性。
- `CryptoEnvelope`：加解密与篡改检测。
- 序列化兼容：旧档案 -> 新结构迁移回放。

### 11.2 集成测试

- 双实例模拟 A/B 设备的增量同步。
- 离线并发编辑后重连同步。
- 中断恢复与部分失败回滚。

### 11.3 验收标准

- iPhone 与 Mac 可手动发现并完成一次全流程同步。
- 同步后复盘数据和设置字段一致。
- API Key 同步后可直接通过对应 provider 发起 AI 请求。
- 冲突场景符合“自动合并 + LWW”预期。

## 12. 迭代路线（设计级）

- Phase 1：iOS 功能对齐（无跨端同步）
- Phase 2：MPC 手动同步闭环（本设计覆盖）
- Phase 3：半自动同步（连接后提醒）
- Phase 4：自动后台同步与更细粒度冲突可视化

---

本设计文档为实现前规格，不包含具体代码改动。实现阶段将按单独 implementation plan 拆分任务与测试顺序。
