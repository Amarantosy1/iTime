# GEMINI.md

## Project Overview
**iTime** is a native macOS menu bar application designed for time reflection and analysis. It transforms system calendar data into a personal time dashboard, providing both quick visual summaries and deep AI-assisted reviews of how time was spent.

- **Primary Goal:** Answer "Where did my time go?" by aggregating and analyzing calendar events.
- **Core Technologies:** Swift 6, SwiftUI, EventKit (Calendar access), Swift Charts, and multi-provider AI integration.
- **Key Features:**
    - **Menu Bar Integration:** Quick-access snapshot of today's/this week's time distribution.
    - **Statistics Dashboard:** Detailed charts (stacked bars, pie charts) and metrics (total duration, event count, daily averages).
    - **AI Superpowers:** Multi-turn AI conversations to review specific schedules, generate summaries, and produce long-form reflection reports.
    - **Provider Agility:** Built-in support for OpenAI, Gemini, DeepSeek, and custom OpenAI-compatible endpoints.
    - **Local-First:** All conversations, summaries, and time data are stored locally for privacy and persistence.

## Architecture & Project Structure
The project follows a modular architecture organized by responsibility:

- **`Sources/iTime/App/`**: Application entry point (`iTimeApp.swift`) and the central `AppModel` which orchestrates state across the menu bar and windows.
- **`Sources/iTime/Domain/`**: Pure data models for `TimeOverview`, `CalendarSource`, `AIConversation`, and `AIProvider` configurations.
- **`Sources/iTime/Services/`**: Business logic implementations:
    - `EventKitCalendarAccessService`: Interfaces with macOS system calendars.
    - `CalendarStatisticsAggregator`: Processes raw events into `TimeBucketSummary` data.
    - `AIConversationRoutingService`: Handles dispatching prompts to different AI providers.
    - `ReviewReminderScheduling`: Manages local notifications for daily reflections.
- **`Sources/iTime/UI/`**: SwiftUI components categorized by feature (Menu Bar, Overview, AI Conversation, Settings, and Theme).
- **`Sources/iTime/Support/`**: Infrastructure utilities including `UserPreferences`, `Keychain` for API keys, and `FileAIConversationArchiveStore`.

## Building and Running
The project can be managed via Xcode or the Swift Package Manager.

### Prerequisites
- **macOS:** 14.0 or later.
- **Xcode:** 15.0+ (recommended 16+ for Swift 6 features).

### Key Commands
- **Build:** `swift build` or `xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' build`
- **Run:** Use Xcode to run the `iTime` scheme on "My Mac".
- **Test:** `swift test` or `xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' test`
- **Linting/Formatting:** The project follows standard Swift styling; use `swift-format` if available.

## Development Conventions
- **Native Look & Feel:** Adhere to macOS HIG. Use `LiquidGlassCard` for consistent translucent UI elements. Support both Light and Dark modes.
- **Privacy & Security:** Never log API keys. Use `AIAPIKeyStoring` (Keychain-backed) for sensitive credentials.
- **Test-Driven Development:** New features should include corresponding tests in `Tests/iTimeTests/`. Maintain the existing suite of unit tests for services and models.
- **Async/Await:** Leverage Swift 6 concurrency patterns for all service calls and UI updates.
- **Localization:** While currently focused on Chinese/English, keep strings externalized where possible for future localization efforts.

## Key Files for Reference
- `README.md`: High-level user documentation and setup instructions.
- `plan.md`: The implementation roadmap and task tracking.
- `Package.swift`: Dependency and target configuration.
- `Sources/iTime/Domain/AIProvider.swift`: Definition of supported AI services.
- `Sources/iTime/Services/AIConversationRoutingService.swift`: Logic for switching between AI backends.
