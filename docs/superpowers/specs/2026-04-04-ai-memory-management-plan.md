# AI Memory Management Plan

## 1. 行业思路调研 (基于 GitHub 开源项目)
在 GitHub 上类似 MemGPT (提供长短期记忆分页)、Zep (长期记忆检索与自动总结) 以及 LangChain 的 Memory 机制中，普遍采用以下策略：
- **分层总结 (Hierarchical Summarization)**: 将小时间粒度的记忆（日）定期压缩为大时间粒度的记忆（周、月），阅读时优先读取较大概括，并补充最近的具体细节。
- **滚动视窗压缩 (Rolling Window Compact)**: 记忆链过长时，将旧记忆进行自动化合并，释放上下文 Token。

## 2. iTime 的读取逻辑优化 (Context-Aware Retrieval)
在 `AppModel.swift` 中重构 `currentAIConversationContext` 对 `memoryText` 的组装，基于当前复盘的时间粒度(`.day`, `.week`, `.month`, `.custom`)，智能匹配 `aiConversationHistory` 中最相关的历史复盘概要：
- **.day (一日)**: 匹配【昨天的日复盘】+【本周的周复盘】+【本月的月复盘】
- **.week (一周)**: 匹配【上周的周复盘】+【本月的月复盘】
- **.month (一月)**: 匹配【上个月的月复盘】
- **.custom (自定义)**: 计算当前时间段长度 $D$，匹配前一段相同长度时间 $[start - D, start]$ 的复盘。

## 3. iTime 的 Compact 更新逻辑
现在的架构中，所有的 Summary 都存放在 `summaries` 中且没有上限。为了防止累积，我们进行**结构化归档 (Compacting)**：
- 在保存长文或每次进行完结构化 summary 之后，生成新的 `AIMemorySnapshot` 并进行“瘦身”。
- **冗余剔除机制**：如果在周复盘中已经涵盖了本周前几天的内容，则可以将这几天的日常短总结脱水或归档，只保留“周总结”层级的节点作为主 memory，防止 Token 指数级增长。
- **限制上下文长度**：AI 读入的 `latestMemorySummary` 时，将历史 summary 按照重要性排布，总长度（以字符衡量）严格截断，保证给后面的日历事件留足空间。

