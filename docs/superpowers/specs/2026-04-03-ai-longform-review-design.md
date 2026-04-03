# AI 长文复盘设计

## 概述

在现有 AI 复盘的“短总结”之上，新增一层“长文复盘模式”。
长文复盘不是基于短总结扩写，而是直接基于原始多轮对话内容、统计快照和时间范围上下文生成一篇正式复盘文章。

第一版目标是让用户在保留当前快读型总结的同时，能额外生成一份适合沉淀、回看和编辑的完整复盘文稿。

## 核心原则

- 短总结继续保留，作为默认复盘结果和历史列表主入口。
- 长文复盘是独立产物，不污染现有 `headline / summary / findings / suggestions` 结构。
- 长文生成输入优先使用原始对话内容，不以短总结为中间层。
- 长文默认做抽象整理，不把用户对话直接转写成流水账。
- 当前完成页和历史总结详情页都可以触发长文生成。

## 数据模型

新增 `AIConversationLongFormReport`：

- `id: UUID`
- `sessionID: UUID`
- `summaryID: UUID`
- `createdAt: Date`
- `updatedAt: Date`
- `title: String`
- `content: String`

关联关系：

- `summaryID` 用于从历史总结页定位长文
- `sessionID` 用于回溯原始消息和统计快照
- 删除 summary 时，关联 long-form report 一并删除

`AIConversationArchive` 扩展为同时保存：

- `sessions`
- `summaries`
- `memorySnapshots`
- `longFormReports`

## 生成输入

长文生成直接基于以下内容：

- `AIConversationSession.messages`
- `AIConversationSession.overviewSnapshot`
- `range / startDate / endDate`
- `serviceDisplayName / provider / model`

输出要求：

- 默认做抽象整理
- 允许少量提及关键日程标题，但不逐条复述聊天
- 不把短总结作为主输入来源，只可作为补充元信息使用

## 生成结果结构

长文输出是正式复盘文章，固定章节：

1. 本次复盘范围
2. 时间投入与关注重点
3. 关键模式与主要问题
4. 深层原因分析
5. 改进行动建议
6. 下一阶段关注点

文章风格要求：

- 中文输出
- 结构清晰，适合回看
- 避免空泛鸡汤和流水账
- 重点强调变化、失衡、优先级和行动建议

## 交互设计

### 当前完成页

在短总结下新增“长文复盘”区块：

- 若当前 summary 没有关联长文：显示 `生成长文复盘`
- 生成中：显示局部 loading 状态
- 已生成：显示长文标题和可展开正文
- 支持 `重新生成长文`

### 历史总结详情页

新增“长文复盘”分区：

- 无长文时：显示 `生成长文复盘`
- 有长文时：显示标题、正文、更新时间
- 支持编辑保存
- 支持重新生成覆盖当前长文

## 应用状态

在 `AppModel` 中新增独立长文状态，不与 `aiConversationState` 混用：

- `idle`
- `generating(summaryID: UUID)`
- `loaded(report: AIConversationLongFormReport)`
- `failed(message: String)`

新增能力：

- `longFormReport(for summaryID: UUID) -> AIConversationLongFormReport?`
- `generateLongFormReport(for summaryID: UUID) async`
- `updateLongFormReport(id:title:content:)`

长文生成失败时，只影响长文区块，不影响短总结和聊天历史。

## 服务层

新增独立的长文生成接口，例如：

- `generateLongFormReport(session: AIConversationSession, summary: AIConversationSummary, configuration: AIConversationConfiguration) async throws -> AIConversationLongFormReportDraft`

输出草稿字段：

- `title`
- `content`

服务层继续走现有 provider 路由，但 prompt 单独为长文模式设计。

## 持久化与删除语义

- 长文本地存档到现有 archive 文件
- 编辑长文后更新 `updatedAt`
- 删除 summary 时级联删除关联 long-form report
- 删除未完成会话不会产生长文

## UI 范围

第一版只覆盖：

- AI 复盘完成页
- AI 历史总结详情页

不在菜单栏展示，不在设置页增加新开关，不做导出功能。

## 测试计划

- 原始会话生成长文测试
  - 验证输入来自 `session.messages` 和 `overviewSnapshot`
  - 验证不是从短总结文本直接派生
- `AppModel` 测试
  - 当前完成页可触发长文生成
  - 历史总结页可触发旧 summary 的长文生成
  - 长文状态独立于 `aiConversationState`
- 持久化测试
  - 长文写入 archive 并可重新读取
  - 编辑后内容持久化
  - 删除 summary 时级联删除长文
- 表现层测试
  - 无长文、生成中、已生成、失败四种状态
  - 相关中文文案稳定

## 非目标

第一版不做：

- 多版本长文历史
- Markdown/PDF 导出
- 长文模板切换
- 自动后台生成长文
- 菜单栏长文入口
