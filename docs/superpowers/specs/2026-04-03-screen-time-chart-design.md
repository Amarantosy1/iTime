# Screen Time Chart Design

## Summary

将 `iTime` 详情窗口中的“每日趋势”从单色总量柱图升级为类似 Apple 屏幕使用时间的堆叠统计图。

这次设计聚焦一件事：

- 用“按日历堆叠的日时长图”替换当前单维度趋势图

目标不是复刻 Apple 的视觉细节，而是借鉴它的信息组织方式，让独立统计窗口更像成熟的时间分析工具。

## References

本次设计主要参考以下 GitHub 项目与产品方向：

- `ActivityWatch/activitywatch`
  - Repository: `https://github.com/ActivityWatch/activitywatch`
  - 成熟的自动时间追踪项目，仪表盘强调总览、时间分布和分类对比
- `ActivityWatch/aw-webui`
  - Repository: `https://github.com/ActivityWatch/aw-webui`
  - ActivityWatch 的前端统计界面，适合参考图表信息组织
- `ActivityWatch/aw-import-screentime`
  - Repository: `https://github.com/ActivityWatch/aw-import-screentime`
  - 直接处理 Apple Screen Time 数据，说明其统计结构与 Screen Time 场景相近
- `solidtime-io/solidtime`
  - Repository: `https://github.com/solidtime-io/solidtime`
  - 现代报表型时间统计产品，适合参考筛选区、主图和明细区的层级
- `kimai/kimai`
  - Repository: `https://github.com/kimai/kimai`
  - 成熟时间追踪报表产品，适合参考时间范围与数据表的组织方式

## Goals

- 让详情页主图从“总量趋势”升级为“结构化时间分布趋势”
- 在同一张图里同时表达“哪天忙”和“忙在什么日历上”
- 保持现有中文界面、深浅色自动适配和原生 macOS 统计窗口风格
- 复用当前日历颜色作为堆叠分段颜色，降低用户重新学习成本
- 保持 `今天 / 本周 / 本月 / 自定义` 的范围控制逻辑不变

## Non-Goals

- 不做 Apple Screen Time 的像素级视觉复刻
- 不在本次实现中加入点击图表钻取到事件级明细
- 不增加新的分类体系，仍然按系统日历聚合
- 不加入复杂悬浮提示、拖拽缩放或图表过滤器
- 不替换当前已有的指标卡、环图和排行表

## Current Problems

当前趋势区的限制比较明显：

- 只展示每天总时长，无法回答“时间被哪些日历占掉了”
- 单色柱图信息密度偏低，对独立统计窗口来说过于简化
- 图表和下方日历排行是割裂的，用户需要在脑中自己做映射
- 长时间范围下，单一总量柱图的洞察价值会快速下降

## UX Design

### Main Chart

主图仍位于指标卡之后，但从单序列柱图改为按日历堆叠的柱图。

单根柱子的含义：

- 一个时间桶代表一个日期或一个周区间
- 柱内每个颜色分段代表一个日历在该时间桶中的累计时长

这样用户可以同时看到：

- 每天总时长的高低变化
- 某个日历是否在特定日期占主导
- 不同日历的活跃模式是否稳定

### Grouping Rules

分组规则按时间范围自适应：

- `今天`：按小时分组过于依赖事件精度，当前版本仍按天显示单根柱
- `本周`：按天分组
- `本月`：按天分组，但压缩 X 轴标签密度
- `自定义`：
  - 当范围天数小于等于 45 天时按天分组
  - 当范围天数大于 45 天时按周分组

这里不做按月分组，原因是当前使用场景仍以中短周期复盘为主，周分组已足够避免图表拥挤。

### Calendar Colors

堆叠段颜色直接复用系统日历颜色。

如果某个日历颜色过浅：

- 在浅色/深色模式下仍按原色绘制
- 不额外改写品牌色
- 通过图例和摘要辅助理解，而不是强行改色

### Legend

主图下方增加简洁图例区：

- 展示当前范围内有数据的日历
- 使用和柱图一致的颜色点
- 名称过长时截断

图例先做只读，不支持点击筛选。

### Focus Summary

在图表下方增加一段摘要文案，用于解释当前范围里最值得看的信号。

初版不做鼠标悬停联动，直接给出静态摘要，例如：

- 最忙的一天
- 占比最高的日历
- 该范围内平均每天投入多少时间

摘要的作用是补足 macOS Charts 默认信息密度有限的问题，让用户不用依赖 tooltip 也能快速读图。

### Relationship to Existing Sections

现有详情页结构保持不变：

1. 标题与范围选择
2. 指标卡
3. 趋势图
4. 分类分布图
5. 日历排行表

变化只发生在趋势图区及其配套数据。

## Data Model Design

### Time Bucket Layer

当前 `TimeOverview` 只有：

- `dailyDurations`
- `buckets`

这不足以绘制堆叠图，因为堆叠图需要“每个时间桶内部的日历分布”。

因此需要新增一个显式的时间桶模型，例如：

- `OverviewStackedBucket`
  - `id`
  - `label`
  - `interval`
  - `totalDuration`
  - `segments`
- `OverviewStackedSegment`
  - `calendarID`
  - `calendarName`
  - `calendarColor`
  - `duration`

这样图表层不需要临时重算，也不需要从排行表数据反推。

### Overview Model

`TimeOverview` 需要新增：

- `stackedBuckets`
- `stackedBucketResolution`

其中 `stackedBucketResolution` 用于描述当前是按天还是按周聚合，便于视图层决定标题、副文案和 X 轴标签策略。

### Aggregation Rules

聚合层要从“整体按天 + 整体按日历”升级为“按时间桶 + 按日历交叉聚合”。

规则如下：

- 先根据选中范围确定查询区间
- 再根据区间长度确定图表分组粒度
- 将事件切分并累加到对应时间桶
- 每个时间桶内继续按日历累加
- 空时间桶保留，以保证趋势连续

### Ordering

堆叠分段和图例顺序应稳定，不应每天跳动。

推荐规则：

- 先按整个范围内该日历总时长降序
- 再按日历名称升序打破并列

这样颜色与顺序在图中保持一致，用户更容易建立映射。

## Chart Behavior

### Axis Strategy

X 轴：

- 日分组时显示日期
- 周分组时显示“起始日 - 结束日”的简写标签或起始日期

Y 轴：

- 单位使用小时
- 保持与现有图表一致，避免用户重新理解刻度

### Empty Data

如果当前范围没有任何可统计事件：

- 不显示堆叠图
- 保持当前空态卡片文案

如果有事件但只有一个日历：

- 仍然使用堆叠图结构，只是每根柱子只有一个颜色段

### Accessibility and Readability

- 深色模式下必须保证坐标轴和标题可读
- 颜色不是唯一编码，图例和摘要要能补充说明
- 不依赖 hover 才能理解图表

## Application Flow

### State Ownership

仍由 `AppModel` 持有 `overview`。

图表所需的新数据全部在刷新概览时一次性产出，不在视图层临时重算。

### Refresh Behavior

以下操作都会触发重算：

- 切换范围
- 修改自定义起止日期
- 修改选中的日历
- 授权状态变化后重新拉取

## Testing Strategy

需要补三类测试：

- 聚合测试
  - 验证同一天多个日历能正确堆叠
  - 验证长区间会从按天切到按周
  - 验证空白日期/空白周会保留 0 值桶
- 表现层测试
  - 验证堆叠图标题、摘要和图例仅使用中文文案
  - 验证分组粒度切换后标题/标签逻辑稳定
- 回归测试
  - 验证现有指标卡、环图、排行表仍使用相同总量基础数据

## Open Questions

当前设计中仍有一个明确取舍：

- `今天` 是否需要未来升级成按小时堆叠

本次先不做。原因是当前事件模型和详情页目标仍更适合做区间复盘，而不是一天内的精细行为追踪。

## Success Criteria

完成后应满足以下标准：

- 详情页主图变为按日历堆叠的统计图
- 用户能一眼看出每个时间桶的总量与组成
- `本月` 与较长 `自定义` 范围下图表不会拥挤到不可读
- 现有独立窗口布局、中文文案、深浅色适配不回退
