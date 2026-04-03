import Foundation
import Observation

@MainActor
@Observable
public final class AppModel {
    public private(set) var authorizationState: CalendarAuthorizationState
    public private(set) var availableCalendars: [CalendarSource]
    public private(set) var overview: TimeOverview?
    public private(set) var aiAnalysisState: AIAnalysisState
    public private(set) var aiConversationState: AIConversationState
    public private(set) var aiConversationHistory: [AIConversationSummary]
    public private(set) var latestAIMemorySnapshot: AIMemorySnapshot?

    public var preferences: UserPreferences

    private let service: CalendarAccessServing
    private let aiService: AIAnalysisServing
    private let aiConversationService: AIConversationServing
    private let aiKeyStore: AIAPIKeyStoring
    private let aiConversationArchiveStore: AIConversationArchiveStoring
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private var currentEvents: [CalendarEventRecord]
    private var aiConversationArchive: AIConversationArchive

    public init(
        service: CalendarAccessServing,
        preferences: UserPreferences,
        aiService: AIAnalysisServing = OpenAICompatibleAIAnalysisService(),
        aiConversationService: AIConversationServing = OpenAICompatibleAIConversationService(),
        aiKeyStore: AIAPIKeyStoring = KeychainAIAPIKeyStore(),
        aiConversationArchiveStore: AIConversationArchiveStoring = FileAIConversationArchiveStore(
            directoryURL: FileAIConversationArchiveStore.defaultDirectoryURL
        ),
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        let archive = (try? aiConversationArchiveStore.loadArchive()) ?? .empty

        self.service = service
        self.aiService = aiService
        self.aiConversationService = aiConversationService
        self.aiKeyStore = aiKeyStore
        self.aiConversationArchiveStore = aiConversationArchiveStore
        self.calendar = calendar
        self.now = now
        self.preferences = preferences
        self.authorizationState = service.authorizationState()
        self.availableCalendars = []
        self.aiAnalysisState = .unavailable(.noData)
        self.aiConversationState = .unavailable(.noData)
        self.aiConversationHistory = archive.summaries.sorted(by: { $0.createdAt > $1.createdAt })
        self.latestAIMemorySnapshot = archive.memorySnapshots.max(by: { $0.createdAt < $1.createdAt })
        self.currentEvents = []
        self.aiConversationArchive = archive
    }

    public var liveSelectedRange: TimeRangePreset {
        preferences.selectedRange.isRuntimeSelectable ? preferences.selectedRange : .today
    }

    private var activeRange: TimeRangePreset {
        preferences.selectedRange
    }

    private var activeInterval: DateInterval {
        resolveInterval(for: activeRange)
    }

    private func resolveInterval(for range: TimeRangePreset) -> DateInterval {
        let referenceDate = now()

        switch range {
        case .today:
            return calendar.dateInterval(of: .day, for: referenceDate)
                ?? DateInterval(start: referenceDate, duration: 86_400)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: referenceDate)
                ?? DateInterval(start: referenceDate, duration: 604_800)
        case .month:
            return calendar.dateInterval(of: .month, for: referenceDate)
                ?? DateInterval(start: referenceDate, duration: 2_592_000)
        case .custom:
            let start = calendar.startOfDay(for: preferences.customStartDate)
            let endStart = calendar.startOfDay(for: preferences.customEndDate)
            let end = calendar.date(byAdding: .day, value: 1, to: endStart) ?? endStart.addingTimeInterval(86_400)
            return DateInterval(start: start, end: end)
        }
    }

    public func refresh() async {
        authorizationState = service.authorizationState()

        guard authorizationState == .authorized else {
            availableCalendars = []
            overview = nil
            currentEvents = []
            resetAIAnalysisState()
            resetAIConversationState()
            return
        }

        var fetchedCalendars = service.fetchCalendars()
        let selectedIDs = preferences.selectedCalendarIDs

        if selectedIDs.isEmpty {
            fetchedCalendars = fetchedCalendars.map {
                CalendarSource(id: $0.id, name: $0.name, colorHex: $0.colorHex, isSelected: true)
            }
            preferences.replaceSelectedCalendars(with: fetchedCalendars.map(\.id))
        } else {
            fetchedCalendars = fetchedCalendars.map {
                CalendarSource(
                    id: $0.id,
                    name: $0.name,
                    colorHex: $0.colorHex,
                    isSelected: selectedIDs.contains($0.id)
                )
            }
        }

        availableCalendars = fetchedCalendars

        let range = activeRange
        let selectedCalendarIDs = fetchedCalendars.filter(\.isSelected).map(\.id)
        let events = service.fetchEvents(
            in: activeInterval,
            selectedCalendarIDs: selectedCalendarIDs
        )
        currentEvents = events
        let aggregator = CalendarStatisticsAggregator(
            calendarLookup: Dictionary(uniqueKeysWithValues: fetchedCalendars.map { ($0.id, $0) }),
            calendar: calendar
        )
        overview = aggregator.makeOverview(range: range, interval: activeInterval, events: events)
        resetAIAnalysisState()
        resetAIConversationState()
    }

    public func requestAccessIfNeeded() async {
        if authorizationState == .notDetermined {
            authorizationState = await service.requestAccess()
        }
        await refresh()
    }

    public func setRange(_ range: TimeRangePreset) async {
        preferences.selectedRange = range
        await refresh()
    }

    public func setCustomDateRange(start: Date, end: Date) async {
        let range = StatisticsDateRange(startDate: start, endDate: end)
        preferences.customStartDate = range.startDate
        preferences.customEndDate = range.endDate
        await refresh()
    }

    public func toggleCalendarSelection(id: String) async {
        var updated = Set(preferences.selectedCalendarIDs)
        if updated.contains(id) {
            updated.remove(id)
        } else {
            updated.insert(id)
        }
        preferences.replaceSelectedCalendars(with: Array(updated))
        await refresh()
    }

    public func analyzeOverview() async {
        guard let overview, !overview.buckets.isEmpty else {
            aiAnalysisState = .unavailable(.noData)
            return
        }

        let configuration = currentAIConfiguration()
        if !configuration.isEnabled {
            aiAnalysisState = .unavailable(.disabled)
            return
        }
        if !configuration.isComplete {
            aiAnalysisState = .unavailable(.notConfigured)
            return
        }

        aiAnalysisState = .loading

        do {
            let result = try await aiService.analyze(
                request: overview.makeAIAnalysisRequest(),
                configuration: configuration
            )
            aiAnalysisState = .loaded(result)
        } catch let error as AIAnalysisServiceError {
            aiAnalysisState = .failed(error.userMessage)
        } catch {
            aiAnalysisState = .failed("AI 评估生成失败，请稍后重试。")
        }
    }

    public func startAIConversation() async {
        guard let context = currentAIConversationContext() else {
            return
        }

        aiConversationState = .asking

        do {
            let assistantMessage = try await aiConversationService.askQuestion(
                context: context,
                history: [],
                configuration: currentAIConfiguration()
            )
            let session = AIConversationSession(
                id: UUID(),
                range: context.range,
                startDate: context.startDate,
                endDate: context.endDate,
                startedAt: now(),
                completedAt: nil,
                status: .inProgress,
                overviewSnapshot: context.overviewSnapshot,
                messages: [assistantMessage]
            )
            try saveConversationArchive(upserting: session)
            aiConversationState = .waitingForUser(session)
        } catch let error as AIAnalysisServiceError {
            aiConversationState = .failed(error.userMessage)
        } catch {
            aiConversationState = .failed("AI 对话启动失败，请稍后重试。")
        }
    }

    public func sendAIConversationReply(_ content: String) async {
        guard case .waitingForUser(let session) = aiConversationState else { return }
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty, let context = currentAIConversationContext() else { return }

        let userMessage = AIConversationMessage(
            id: UUID(),
            role: .user,
            content: trimmedContent,
            createdAt: now()
        )
        let historyWithReply = session.messages + [userMessage]
        aiConversationState = .asking

        do {
            let assistantMessage = try await aiConversationService.askQuestion(
                context: context,
                history: historyWithReply,
                configuration: currentAIConfiguration()
            )
            let updatedSession = AIConversationSession(
                id: session.id,
                range: session.range,
                startDate: session.startDate,
                endDate: session.endDate,
                startedAt: session.startedAt,
                completedAt: nil,
                status: .inProgress,
                overviewSnapshot: session.overviewSnapshot,
                messages: historyWithReply + [assistantMessage]
            )
            try saveConversationArchive(upserting: updatedSession)
            aiConversationState = .waitingForUser(updatedSession)
        } catch let error as AIAnalysisServiceError {
            aiConversationState = .failed(error.userMessage)
        } catch {
            aiConversationState = .failed("AI 追问失败，请稍后重试。")
        }
    }

    public func finishAIConversation() async {
        guard case .waitingForUser(let session) = aiConversationState, let context = currentAIConversationContext() else {
            return
        }

        aiConversationState = .summarizing(session)

        do {
            let draft = try await aiConversationService.summarizeConversation(
                context: context,
                history: session.messages,
                configuration: currentAIConfiguration()
            )
            let completedAt = now()
            let completedSession = AIConversationSession(
                id: session.id,
                range: session.range,
                startDate: session.startDate,
                endDate: session.endDate,
                startedAt: session.startedAt,
                completedAt: completedAt,
                status: .completed,
                overviewSnapshot: session.overviewSnapshot,
                messages: session.messages
            )
            let summary = AIConversationSummary(
                id: UUID(),
                sessionID: session.id,
                range: session.range,
                startDate: session.startDate,
                endDate: session.endDate,
                createdAt: completedAt,
                headline: draft.headline,
                summary: draft.summary,
                findings: draft.findings,
                suggestions: draft.suggestions,
                overviewSnapshot: session.overviewSnapshot
            )
            try saveConversationArchive(upserting: completedSession, appending: summary)
            aiConversationState = .completed(summary)
        } catch let error as AIAnalysisServiceError {
            aiConversationState = .failed(error.userMessage)
        } catch {
            aiConversationState = .failed("AI 总结生成失败，请稍后重试。")
        }
    }

    public func updateAIAnalysisEnabled(_ isEnabled: Bool) {
        preferences.aiAnalysisEnabled = isEnabled
        resetAIAnalysisState()
        resetAIConversationState()
    }

    public func updateAIBaseURL(_ baseURL: String) {
        preferences.aiBaseURL = baseURL
        resetAIAnalysisState()
        resetAIConversationState()
    }

    public func updateAIModel(_ model: String) {
        preferences.aiModel = model
        resetAIAnalysisState()
        resetAIConversationState()
    }

    public func loadAIAPIKey() -> String {
        (try? aiKeyStore.loadAPIKey()) ?? ""
    }

    public func updateAIAPIKey(_ apiKey: String) {
        try? aiKeyStore.saveAPIKey(apiKey)
        resetAIAnalysisState()
        resetAIConversationState()
    }

    private func currentAIConfiguration() -> AIAnalysisConfiguration {
        AIAnalysisConfiguration(
            baseURL: preferences.aiBaseURL,
            model: preferences.aiModel,
            apiKey: loadAIAPIKey(),
            isEnabled: preferences.aiAnalysisEnabled
        )
    }

    private func resetAIAnalysisState() {
        guard authorizationState == .authorized, let overview, !overview.buckets.isEmpty else {
            aiAnalysisState = .unavailable(.noData)
            return
        }

        let configuration = currentAIConfiguration()
        if !configuration.isEnabled {
            aiAnalysisState = .unavailable(.disabled)
        } else if !configuration.isComplete {
            aiAnalysisState = .unavailable(.notConfigured)
        } else {
            aiAnalysisState = .idle
        }
    }

    private func resetAIConversationState() {
        guard authorizationState == .authorized, let overview, !overview.buckets.isEmpty else {
            aiConversationState = .unavailable(.noData)
            return
        }

        let configuration = currentAIConfiguration()
        if !configuration.isEnabled {
            aiConversationState = .unavailable(.disabled)
        } else if !configuration.isComplete {
            aiConversationState = .unavailable(.notConfigured)
        } else {
            aiConversationState = .idle
        }
    }

    private func currentAIConversationContext() -> AIConversationContext? {
        guard let overview, !overview.buckets.isEmpty else {
            aiConversationState = .unavailable(.noData)
            return nil
        }

        let configuration = currentAIConfiguration()
        if !configuration.isEnabled {
            aiConversationState = .unavailable(.disabled)
            return nil
        }
        if !configuration.isComplete {
            aiConversationState = .unavailable(.notConfigured)
            return nil
        }

        return overview.makeAIConversationContext(
            events: currentEvents,
            calendarLookup: Dictionary(uniqueKeysWithValues: availableCalendars.map { ($0.id, $0) }),
            latestMemorySummary: latestAIMemorySnapshot?.summary
        )
    }

    private func saveConversationArchive(
        upserting session: AIConversationSession,
        appending summary: AIConversationSummary? = nil
    ) throws {
        var sessions = aiConversationArchive.sessions.filter { $0.id != session.id }
        sessions.append(session)
        sessions.sort { $0.startedAt > $1.startedAt }

        var summaries = aiConversationArchive.summaries
        if let summary {
            summaries.removeAll { $0.id == summary.id }
            summaries.append(summary)
            summaries.sort { $0.createdAt > $1.createdAt }
        }

        let updatedArchive = AIConversationArchive(
            sessions: sessions,
            summaries: summaries,
            memorySnapshots: aiConversationArchive.memorySnapshots
        )
        try aiConversationArchiveStore.saveArchive(updatedArchive)
        aiConversationArchive = updatedArchive
        aiConversationHistory = updatedArchive.summaries
        latestAIMemorySnapshot = updatedArchive.memorySnapshots.max(by: { $0.createdAt < $1.createdAt })
    }
}
