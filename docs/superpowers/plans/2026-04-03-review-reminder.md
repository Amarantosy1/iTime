# 复盘提醒实现计划

## Phase 1: 持久化与通知抽象

1. 在 `UserPreferences` 中新增：
   - `reviewReminderEnabled`
   - `reviewReminderTime`
2. 为默认值增加合理初始化逻辑。
3. 新增通知权限与调度抽象，例如：
   - `ReviewReminderAuthorizationStatus`
   - `ReviewReminderScheduling`
4. 提供系统实现和测试 stub。

## Phase 2: AppModel 状态与同步逻辑

1. 在 `AppModel` 中新增：
   - 当前提醒权限状态
   - 请求权限方法
   - 开关更新方法
   - 提醒时间更新方法
2. 添加同步逻辑：
   - 开启时请求权限并注册通知
   - 关闭时移除通知
   - 改时间时重排通知
3. 在 `refresh()` 或初始化阶段加载当前权限状态。

## Phase 3: 设置页 UI

1. `SettingsSection` 新增 `reviewReminder`
2. 左侧 sidebar 增加 `复盘提醒`
3. 右侧新增 `复盘提醒` 页面：
   - 开关
   - 时间选择器
   - 权限状态文案
   - 请求权限按钮
4. 保持现有 `统计日历 / AI 服务` 页面结构不受影响。

## Phase 4: 测试

1. `UserPreferences` 测试：
   - 默认提醒关闭
   - 时间持久化正确
2. `AppModel` 测试：
   - 开启提醒时请求权限并注册通知
   - 关闭提醒时移除通知
   - 改时间时重新注册
3. 表现层测试：
   - sidebar 出现 `复盘提醒`
   - 相关 copy 正确
4. 调度服务测试：
   - identifier、标题、正文、重复 trigger 正确

## Phase 5: 验证与收尾

1. 运行 `swift test`
2. 运行 `xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' test`
3. 检查 diff 只包含：
   - settings
   - app model
   - user preferences
   - reminder service
   - tests
