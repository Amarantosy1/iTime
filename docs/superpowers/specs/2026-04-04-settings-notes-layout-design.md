# iTime 设置页备忘录式布局设计

## 目标

将当前设置页改成更接近 Apple 备忘录的布局：
- 左侧导航更窄，作为稳定的 section 切换栏
- 右侧内容区更宽，但保持阅读宽度上限，不随窗口放大而失控拉伸
- 设置窗口支持自由缩放，不再被视图内部固定尺寸锁死

## 当前问题

- `SettingsView` 内部写死了 `960 x 700`，导致设置窗口表现得像固定尺寸窗口
- 右侧详情页使用大块 `ScrollView + GroupBox` 平铺，节奏松散，视觉重心不集中
- AI 服务页面包含最多表单内容，但当前没有统一的内容列宽度和区块层级，窗口一放大就显得过于分散

## 设计决策

### 1. 保留原生 `NavigationSplitView`

继续使用系统分栏能力，而不是手写 `HStack`。

原因：
- 保留 macOS 原生 sidebar 行为
- 用最小代价实现“左窄右宽”
- 只重做视觉层和窗口约束，不引入额外维护成本

### 2. 设置窗口改为“默认尺寸 + 最小尺寸”

移除 `SettingsView` 内部固定尺寸，在 `Settings` scene 上设置默认尺寸和最小尺寸。

行为：
- 初始大小固定在适合阅读的区间
- 用户可以自由拉大拉小
- 详情内容列通过最大宽度保持居中，不跟着无限摊平

### 3. 右侧统一为备忘录式内容列

每个设置页都用同一套页面骨架：
- 页标题
- 一句简短说明
- 1 到多个轻量内容块

内容块不再使用厚重的 `GroupBox` 堆叠，而改为更轻的圆角卡片，强调内容分段和阅读节奏。

### 4. AI 服务页优先做结构收敛

AI 服务页保留原有功能，但重排为三段：
- 默认服务
- 服务列表
- 服务详情

每段共享相同的卡片和内容宽度规则，减少大窗口下的空洞感。

## 影响范围

- `Sources/iTime/UI/Settings/SettingsView.swift`
- `Sources/iTime/iTimeApp.swift`
- `Tests/iTimeTests/PresentationTests.swift`

## 验证策略

- 为设置窗口和布局常量增加展示层测试
- 跑 `swift test --filter PresentationTests`
- 跑完整 `swift test`
- 跑 `xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' build`
