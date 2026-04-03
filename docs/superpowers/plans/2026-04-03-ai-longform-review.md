# AI 长文复盘实现计划

## Phase 1: 数据模型与归档扩展

1. 在 `Sources/iTime/Domain/AIConversation.swift` 中新增：
   - `AIConversationLongFormReport`
   - `AIConversationLongFormReportDraft`
   - `AIConversationLongFormState`
2. 扩展 `AIConversationArchive`，增加 `longFormReports` 数组。
3. 保持旧 archive 解码兼容，缺失 `longFormReports` 时默认空数组。
4. 更新删除 summary 的级联逻辑，确保关联长文报告也一并删除。

## Phase 2: 服务层长文生成能力

1. 在现有 AI conversation service 层增加长文生成接口：
   - `generateLongFormReport(session:summary:configuration:)`
2. 为 OpenAI-compatible / OpenAI / Anthropic / Gemini / DeepSeek 路由复用现有 provider routing，新增 long-form 生成分支。
3. 为长文模式单独设计 prompt：
   - 输入原始消息、统计快照、时间范围、服务信息
   - 输出固定 JSON：`title`、`content`
4. 增加解析和错误映射，避免半结构化脏输出进入 UI。

## Phase 3: AppModel 状态与操作

1. 在 `AppModel` 中新增：
   - `aiLongFormState`
   - `longFormReport(for:)`
   - `generateLongFormReport(for:)`
   - `updateLongFormReport(...)`
2. 生成流程：
   - 通过 `summaryID` 找到 summary
   - 通过 `sessionID` 找到原始 session
   - 用当前绑定服务配置调用长文生成接口
   - 成功后写入 archive 并更新状态
3. 保证长文状态独立于：
   - `aiConversationState`
   - 当前聊天窗口输入发送状态
4. 保持并发安全：若重复点击生成，以最新操作为准。

## Phase 4: 当前完成页 UI

1. 在 `AIConversationWindowView` 的 `.completed` 视图中新增“长文复盘”区块。
2. 无长文时显示：
   - `生成长文复盘`
3. 生成中显示局部 loading，不遮挡短总结。
4. 已生成时显示：
   - 标题
   - 可滚动或可展开正文
   - `重新生成长文`
5. 文案保持中文，避免引入说明性废话。

## Phase 5: 历史总结详情页 UI

1. 在 `AIConversationHistoryView` 的详情区新增长文复盘分区。
2. 无长文时提供生成按钮。
3. 有长文时支持：
   - 查看标题和正文
   - 编辑并保存
   - 重新生成覆盖
4. 保持当前 summary 编辑能力不受影响。

## Phase 6: 测试

1. 领域/归档测试
   - archive 可读写 long-form reports
   - 删除 summary 时级联删除 long-form reports
2. 服务层测试
   - 长文 prompt 构造包含原始消息和 overview snapshot
   - 响应 JSON 可稳定解析
3. AppModel 测试
   - 当前完成页生成长文成功写入 archive
   - 历史总结详情生成旧 summary 的长文成功
   - 更新长文内容可持久化
   - 长文状态不影响短总结状态
4. 表现层测试
   - 相关中文文案和状态 copy 稳定

## Phase 7: 验证与收尾

1. 运行 `swift test`
2. 运行 `xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' test`
3. 检查 diff 范围，只包含：
   - AI conversation domain
   - conversation service
   - AppModel
   - AI conversation window/history UI
   - tests
4. 根据结果决定是否提交、合并。
