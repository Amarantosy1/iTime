# iTime

`iTime` 是一个原生 macOS 菜单栏应用，用来回答一个很直接的问题：`Where is my time?`

当前版本聚焦第一阶段最小闭环：
- 从系统日历读取事件
- 按日历分类聚合时长
- 在菜单栏显示速览
- 在详情窗口用 Apple 风格图表展示时间分布

## 当前构建状态

当前项目路径：
- `/Users/amarantos/Project/iTime`

当前已完成内容：
- 原生 `SwiftUI` 菜单栏应用入口
- `EventKit` 日历权限与事件读取
- `今天 / 本周 / 本月` 时间范围切换
- 按日历分组的聚合统计
- 详情窗口图表展示
- 基于 `Swift Testing` 的核心逻辑测试
- 原生 `iTime.xcodeproj` 工程整理

已验证状态：
- `swift build` 通过
- `swift test` 通过，8 个测试全部通过

## 项目结构

```text
iTime.xcodeproj/                Xcode 工程
Sources/iTime/                  应用源码
  App/                          应用状态
  Domain/                       核心数据模型
  Services/                     EventKit 与聚合逻辑
  Support/                      持久化与格式化
  UI/                           菜单栏、详情页、主题
Tests/iTimeTests/               Swift Testing 测试
Package.swift                   SwiftPM 入口，便于命令行构建
```

## Xcode 打开方式

1. 打开 Xcode。
2. 选择 `File > Open...`
3. 选择项目里的 `iTime.xcodeproj`
4. 在左上角 Scheme 选择 `iTime`
5. 运行目标选择 `My Mac`
6. 按 `Cmd + R` 运行应用

这个工程默认关闭了代码签名要求，本地运行通常不需要额外配置 Team。

## 第一次运行需要的配置

第一次运行时，应用会请求日历权限。

如果你之前拒绝过：
1. 打开 `System Settings`
2. 进入 `Privacy & Security > Calendars`
3. 找到 `iTime`
4. 重新打开权限

## Xcode 常用操作

运行应用：

```bash
Cmd + R
```

运行测试：

```bash
Cmd + U
```

只从命令行构建：

```bash
swift build
```

只从命令行跑测试：

```bash
swift test
```

## 说明

第一版只实现“日历 + 图表”闭环，下面这些能力还没有进入当前工程：
- 睡眠数据读取
- AI 时间管理评估
- 自定义分类规则
- 旧版 macOS 兼容 UI

后续如果继续推进，建议顺序是：
1. 增加日历选择与持久化 UI
2. 增加更多统计维度
3. 接入睡眠数据
4. 再接 AI 分析层
