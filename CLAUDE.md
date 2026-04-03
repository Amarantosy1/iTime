# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is iTime

A native macOS menu bar app for time reflection/review. It reads system calendars via EventKit, aggregates time data, and provides AI-assisted review conversations. All data stays local. UI is Chinese-language, follows macOS HIG with restrained Liquid Glass styling.

## Build & Test Commands

```bash
swift build                    # SPM build
swift test                     # Run all tests (~85 tests)
swift test --filter iTimeTests.AppModelTests   # Run a single test file

# Xcode equivalents
xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' build
xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' test
```

No linter is configured. Use `swift-format` if needed.

## Architecture

**Swift 6 strict concurrency** throughout. Uses `@Observable` (Observation framework), not Combine. The app is an SPM executable target, not a traditional Xcode app target.

### Layer overview

- **App** — `AppModel` is the single `@MainActor @Observable` state owner. All UI reads from it. It orchestrates calendar access, statistics, AI conversations, and archive persistence.
- **Domain** — Pure value types (`TimeOverview`, `CalendarSource`, `CalendarEventRecord`, `AIConversation`, `AIProvider`, `AIServiceEndpoint`, etc.). No framework imports.
- **Services** — Protocol-driven. Each capability has a protocol (`CalendarAccessServing`, `StatisticsAggregating`, `AIConversationServing`, `AIAnalysisServing`, `ReviewReminderScheduling`) and one or more concrete implementations. AI conversation dispatch goes through `AIConversationRoutingService` which maps provider type to the correct service.
- **Support** — Persistence (`UserPreferences` via UserDefaults, `KeychainAIAPIKeyStore`, `FileAIConversationArchiveStore`), formatting helpers.
- **UI** — SwiftUI views grouped by feature: MenuBar, Overview (statistics dashboard), AIConversation, Settings, Theme (`AppTheme`, `LiquidGlassCard`).

### Key patterns

- **Protocol → Concrete** — Services are injected via protocols. `AppModel.init` accepts protocol-typed dependencies with production defaults, making tests straightforward.
- **Testability** — Tests create `AppModel` with stub/mock implementations of service protocols. The `now` closure and `Calendar` are also injectable for deterministic time-based tests.
- **AI multi-provider routing** — `AIConversationRoutingService` holds a `[AIProviderType: AIConversationServing]` dictionary. Each provider (OpenAI, Anthropic, Gemini, DeepSeek, OpenAI-compatible) has its own service implementation making direct HTTP calls.
- **Archive persistence** — Conversation history, summaries, and memory snapshots are serialized to a local file via `AIConversationArchiveStoring`.

### Scene structure (iTimeApp.swift)

The app declares four scenes: `MenuBarExtra` (primary), `Window("概览")` for the statistics dashboard, `Window` for AI conversation, and `Settings`.

## Platform Requirements

- macOS 14+
- Swift 6.3 / Swift tools version 6.3
- Requires calendar permission (EventKit) and optionally notification permission for daily review reminders
