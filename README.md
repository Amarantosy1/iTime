# iTime

> 一个原生的 macOS 菜单栏时间复盘应用，把系统日历变成你的个人时间仪表盘。

[![Platform](https://img.shields.io/badge/platform-macOS-111111)](#)
[![Swift](https://img.shields.io/badge/swift-6-orange)](#)
[![UI](https://img.shields.io/badge/UI-SwiftUI-blue)](#)
[![Version](https://img.shields.io/badge/version-1.0.0-brightgreen)](#)
[![Tests](https://img.shields.io/badge/tests-85%20passing-brightgreen)](#)

`iTime` 只回答一个问题：

## 我的时间去哪了？

它会读取你的系统日历，聚合真实安排过的时间，并以菜单栏快照 + 独立统计窗口的方式展示出来。除了统计视图，它还内置 AI 复盘能力，可以围绕具体日程继续追问、生成总结、保存历史，并在本地沉淀长期复盘记录。

## 功能亮点

- 原生 `SwiftUI` 菜单栏应用体验
- 基于 `EventKit` 读取系统日历与事件
- 支持 `今天 / 本周 / 本月 / 自定义` 统计范围
- 自动排除整天日程，避免污染时长统计
- 独立主界面提供更完整的时间仪表盘
- AI 复盘支持多轮追问、历史归档、长文复盘
- 原生设置窗口支持日历选择、AI 服务配置、复盘提醒
- 全中文界面，支持深色模式与本地持久化

## 适合谁

`iTime` 不是排期工具，而是复盘工具。  
它更适合这些场景：

- 每天下班后回顾今天时间花在了哪里
- 每周做一次学习 / 工作节奏复盘
- 检查某类会议是否占用了过多时间
- 对照不同日历分类查看投入比例变化
- 用 AI 辅助完成更深入的时间管理总结

## 核心功能

### 菜单栏快照

- 快速切换时间范围
- 一眼看到当前范围总时长
- 用横向条形图查看各日历占比
- 一键打开完整统计窗口和设置

### 时间统计主界面

- 总时长、事件数、日均时长、最长单日等指标
- 类似屏幕使用时间的堆叠图表
- 当天视图支持 24 小时小时级堆叠
- 分类分布图例与自定义日期范围
- 胶囊式范围切换，整体更接近原生 macOS 风格

### AI 复盘

- AI 可以读取具体日程标题，而不是只看汇总桶
- 默认先提问，再根据你的回答生成总结
- 支持多家内置 AI 服务与自定义 `OpenAI-compatible` 服务
- 支持历史总结查看、编辑、删除
- 支持基于原始会话生成长文复盘
- 所有会话、总结与 memory 默认本地保存

### 每日复盘提醒

- 可在设置里启用每日固定时间提醒
- 使用系统通知权限
- 修改时间后会自动重新调度提醒

## AI 服务

内置服务：

- `OpenAI`
- `Gemini`
- `DeepSeek`

自定义服务：

- `OpenAI-compatible`

每个服务都可以独立保存：

- `Base URL`
- `API Key`
- 模型列表
- 默认模型
- 启用状态

## 项目结构

```text
iTime.xcodeproj/
Sources/iTime/
  App/          应用状态与主流程编排
  Domain/       日历、统计、AI、历史归档模型
  Services/     EventKit、统计聚合、AI 服务适配、提醒调度
  Support/      持久化、格式化、Keychain、本地归档
  UI/           菜单栏、主界面、设置、AI 对话、主题
Tests/iTimeTests/
Package.swift
```

## 快速开始

### 用 Xcode 运行

1. 打开 `iTime.xcodeproj`
2. 选择 `iTime` scheme
3. 目标设备选择 `My Mac`
4. 使用 `Cmd + R` 运行

### 首次启动

`iTime` 需要日历权限才能读取统计数据。

如果你此前拒绝过权限：

1. 打开“系统设置”
2. 进入“隐私与安全性 > 日历”
3. 为 `iTime` 打开权限

如果你启用了复盘提醒，还需要系统通知权限。

### 从 GitHub Release 下载后无法打开

如果 macOS 提示“`iTime.app` 会损害你的电脑”或阻止打开，通常是系统给下载产物打了隔离标记。可以先把应用拖到“应用程序”目录，再执行：

```bash
xattr -dr com.apple.quarantine /Applications/iTime.app
```

如果你还没有把应用移到“应用程序”目录，也可以直接对当前路径执行，例如：

```bash
xattr -dr com.apple.quarantine ~/Downloads/iTime.app
```

执行完成后重新打开 `iTime` 即可。这里是只对 `iTime.app` 单独移除隔离标记，不是全局关闭 Gatekeeper。

## 构建与测试

```bash
swift build
swift test
xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' build
xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' test
```

当前验证状态：

- `swift test`：**85** 个测试通过
- `xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' test`：通过

## 设计方向

`iTime` 故意保持接近原生 macOS 的行为和审美：

- 菜单栏优先
- 独立统计窗口
- 原生 `Settings` 窗口
- 默认跟随系统浅色 / 深色外观
- 以克制的材质与玻璃感样式为主，而不是重型自定义设计系统

目标不是把它做成泛化的效率套件，而是把“基于日历的时间复盘”做得足够轻、足够快、足够像系统应用。

## 当前能力范围

已实现：

- 基于日历的时间统计
- 独立统计仪表盘
- 自定义统计范围
- 多轮 AI 复盘对话
- 历史总结与长文复盘
- 多服务 AI 配置
- 每日复盘提醒

当前不做：

- 任务管理
- 多端同步
- 健康 / 睡眠数据接入
- 后台自动 AI 分析
- 外部分析后端

## 为什么做这个项目

这个项目聚焦在三件事的交叉点：

- 原生 macOS 菜单栏产品设计
- 基于日历的个人时间分析
- 本地优先的 AI 时间复盘体验

如果你在找一个同时结合 `EventKit`、`SwiftUI`、原生设置窗口、图表、AI 服务路由、本地归档与菜单栏交互的 macOS 项目，`iTime` 会是一个比较完整的参考实现。
