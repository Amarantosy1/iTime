import Foundation
import Testing
@testable import iTime

private struct ConversationStubCalendarAccessService: CalendarAccessServing {
    let state: CalendarAuthorizationState
    let calendars: [CalendarSource]
    let events: [CalendarEventRecord]

    func authorizationState() -> CalendarAuthorizationState { state }
    func requestAccess() async -> CalendarAuthorizationState { state }
    func fetchCalendars() -> [CalendarSource] { calendars }
    func fetchEvents(in interval: DateInterval, selectedCalendarIDs: [String]) -> [CalendarEventRecord] {
        events.filter { selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains($0.calendarID) }
    }
}

private final class ConversationInMemoryAIKeyStore: @unchecked Sendable, AIAPIKeyStoring {
    var values: [AIProviderKind: String]

    init(value: String = "") {
        self.values = [.openAI: value]
    }

    func loadAPIKey(for provider: AIProviderKind) throws -> String { values[provider] ?? "" }
    func saveAPIKey(_ apiKey: String, for provider: AIProviderKind) throws { values[provider] = apiKey }
}

private final class InMemoryAIConversationArchiveStore: @unchecked Sendable, AIConversationArchiveStoring {
    var archive: AIConversationArchive
    private(set) var savedArchives: [AIConversationArchive] = []

    init(archive: AIConversationArchive = .empty) {
        self.archive = archive
    }

    func loadArchive() throws -> AIConversationArchive {
        archive
    }

    func saveArchive(_ archive: AIConversationArchive) throws {
        self.archive = archive
        savedArchives.append(archive)
    }
}

private final class RecordingAIConversationService: @unchecked Sendable, AIConversationServing {
    var nextQuestion: String
    var summaryDraft: AIConversationSummaryDraft
    var shouldSuspendNextQuestion = false
    private(set) var askedContexts: [AIConversationContext] = []
    private(set) var askedHistories: [[AIConversationMessage]] = []
    private(set) var askedConfigurations: [ResolvedAIProviderConfiguration] = []
    private(set) var summarizedContexts: [AIConversationContext] = []
    private(set) var summarizedHistories: [[AIConversationMessage]] = []
    private(set) var summarizedConfigurations: [ResolvedAIProviderConfiguration] = []
    private var suspendedQuestionContinuation: CheckedContinuation<AIConversationMessage, Never>?
    private var suspensionReadyContinuation: CheckedContinuation<Void, Never>?

    init(
        nextQuestion: String = "这个日程主要做了什么？",
        summaryDraft: AIConversationSummaryDraft = AIConversationSummaryDraft(
            headline: "本周安排偏向沟通",
            summary: "你本周大部分时间花在沟通同步上。",
            findings: ["会议密度偏高"],
            suggestions: ["给深度工作预留固定时段"]
        )
    ) {
        self.nextQuestion = nextQuestion
        self.summaryDraft = summaryDraft
    }

    func askQuestion(
        context: AIConversationContext,
        history: [AIConversationMessage],
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationMessage {
        askedContexts.append(context)
        askedHistories.append(history)
        askedConfigurations.append(configuration)
        if shouldSuspendNextQuestion {
            shouldSuspendNextQuestion = false
            return await withCheckedContinuation { continuation in
                suspendedQuestionContinuation = continuation
                suspensionReadyContinuation?.resume()
                suspensionReadyContinuation = nil
            }
        }
        return AIConversationMessage(
            id: UUID(),
            role: .assistant,
            content: nextQuestion,
            createdAt: Date(timeIntervalSince1970: 2_000)
        )
    }

    func summarizeConversation(
        context: AIConversationContext,
        history: [AIConversationMessage],
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationSummaryDraft {
        summarizedContexts.append(context)
        summarizedHistories.append(history)
        summarizedConfigurations.append(configuration)
        return summaryDraft
    }

    func resumeSuspendedQuestion() {
        suspendedQuestionContinuation?.resume(
            returning: AIConversationMessage(
                id: UUID(),
                role: .assistant,
                content: nextQuestion,
                createdAt: Date(timeIntervalSince1970: 2_000)
            )
        )
        suspendedQuestionContinuation = nil
    }

    func waitUntilQuestionSuspends() async {
        if suspendedQuestionContinuation != nil {
            return
        }

        await withCheckedContinuation { continuation in
            suspensionReadyContinuation = continuation
        }
    }
}

@MainActor
@Test func startAIConversationCreatesAssistantQuestionAndPersistsSession() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: CalendarAuthorizationState.authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
        ],
        events: [
            CalendarEventRecord(
                id: "1",
                title: "需求评审",
                calendarID: "work",
                startDate: .init(timeIntervalSince1970: 0),
                endDate: .init(timeIntervalSince1970: 3_600),
                isAllDay: false
            ),
        ]
    )
    let conversationService = RecordingAIConversationService(nextQuestion: "需求评审主要讨论了什么？")
    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [],
            summaries: [],
            memorySnapshots: [
                AIMemorySnapshot(
                    id: UUID(),
                    createdAt: .init(timeIntervalSince1970: 100),
                    sourceSummaryIDs: [],
                    summary: "过去几轮复盘都显示会议偏多。"
                ),
            ]
        )
    )
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.aiBaseURL = "https://example.com/v1"
    preferences.aiModel = "gpt-5-mini"
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: archiveStore
    )

    await model.refresh()
    await model.startAIConversation()

    guard case .waitingForUser(let session) = model.aiConversationState else {
        Issue.record("Expected waitingForUser state")
        return
    }
    #expect(session.messages.count == 1)
    #expect(session.provider == .openAI)
    #expect(session.messages.first?.role == AIConversationMessageRole.assistant)
    #expect(session.messages.first?.content == "需求评审主要讨论了什么？")
    #expect(conversationService.askedContexts.first?.events.map(\.title) == ["需求评审"])
    #expect(conversationService.askedContexts.first?.latestMemorySummary == "过去几轮复盘都显示会议偏多。")
    #expect(conversationService.askedConfigurations.first?.provider == .openAI)
    #expect(archiveStore.archive.sessions.count == 1)
}

@MainActor
@Test func startAIConversationBindsSessionToSelectedProvider() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: CalendarAuthorizationState.authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
        ],
        events: [
            CalendarEventRecord(
                id: "1",
                title: "路线评审",
                calendarID: "work",
                startDate: .init(timeIntervalSince1970: 0),
                endDate: .init(timeIntervalSince1970: 3_600),
                isAllDay: false
            ),
        ]
    )
    let conversationService = RecordingAIConversationService(nextQuestion: "路线评审的结论是什么？")
    let keyStore = ConversationInMemoryAIKeyStore()
    keyStore.values[.anthropic] = "anthropic-key"
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.defaultAIProvider = .anthropic
    preferences.setAIProviderEnabled(true, for: .anthropic)
    preferences.setAIProviderBaseURL("https://api.anthropic.com/v1", for: .anthropic)
    preferences.setAIProviderModel("claude-sonnet-4-5", for: .anthropic)
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: keyStore,
        aiConversationArchiveStore: InMemoryAIConversationArchiveStore()
    )

    await model.refresh()
    await model.startAIConversation()

    guard case .waitingForUser(let session) = model.aiConversationState else {
        Issue.record("Expected waitingForUser state")
        return
    }
    #expect(session.provider == .anthropic)
    #expect(conversationService.askedConfigurations.first?.provider == .anthropic)
    #expect(conversationService.askedConfigurations.first?.model == "claude-sonnet-4-5")
}

@MainActor
@Test func sendAIConversationReplyAppendsUserReplyAndNextQuestion() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: CalendarAuthorizationState.authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
        ],
        events: [
            CalendarEventRecord(
                id: "1",
                title: "需求评审",
                calendarID: "work",
                startDate: .init(timeIntervalSince1970: 0),
                endDate: .init(timeIntervalSince1970: 3_600),
                isAllDay: false
            ),
        ]
    )
    let conversationService = RecordingAIConversationService(nextQuestion: "这次评审之后安排了什么动作？")
    let archiveStore = InMemoryAIConversationArchiveStore()
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.aiBaseURL = "https://example.com/v1"
    preferences.aiModel = "gpt-5-mini"
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: archiveStore
    )

    await model.refresh()
    await model.startAIConversation()
    await model.sendAIConversationReply("主要在对齐需求变更。")

    guard case .waitingForUser(let session) = model.aiConversationState else {
        Issue.record("Expected waitingForUser state")
        return
    }
    #expect(session.messages.count == 3)
    #expect(session.messages[1].role == AIConversationMessageRole.user)
    #expect(session.messages[1].content == "主要在对齐需求变更。")
    #expect(session.messages[2].role == AIConversationMessageRole.assistant)
    #expect(session.messages[2].content == "这次评审之后安排了什么动作？")
    #expect(conversationService.askedHistories.last?.count == 2)
}

@MainActor
@Test func sendAIConversationReplyKeepsConversationVisibleWhileAwaitingNextQuestion() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: CalendarAuthorizationState.authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
        ],
        events: [
            CalendarEventRecord(
                id: "1",
                title: "需求评审",
                calendarID: "work",
                startDate: .init(timeIntervalSince1970: 0),
                endDate: .init(timeIntervalSince1970: 3_600),
                isAllDay: false
            ),
        ]
    )
    let conversationService = RecordingAIConversationService(nextQuestion: "这次评审之后安排了什么动作？")
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.aiBaseURL = "https://example.com/v1"
    preferences.aiModel = "gpt-5-mini"
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: InMemoryAIConversationArchiveStore()
    )

    await model.refresh()
    await model.startAIConversation()
    conversationService.shouldSuspendNextQuestion = true

    let replyTask = Task {
        await model.sendAIConversationReply("主要在对齐需求变更。")
    }
    await conversationService.waitUntilQuestionSuspends()

    guard case .responding(let session) = model.aiConversationState else {
        Issue.record("Expected responding state while awaiting next question")
        conversationService.resumeSuspendedQuestion()
        await replyTask.value
        return
    }
    #expect(session.messages.count == 2)
    #expect(session.messages.last?.role == .user)
    #expect(session.messages.last?.content == "主要在对齐需求变更。")

    conversationService.resumeSuspendedQuestion()
    await replyTask.value

    guard case .waitingForUser(let updatedSession) = model.aiConversationState else {
        Issue.record("Expected waitingForUser state after next question resumes")
        return
    }
    #expect(updatedSession.messages.count == 3)
}

@MainActor
@Test func continuingConversationKeepsOriginalProviderAfterDefaultProviderChanges() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: CalendarAuthorizationState.authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
        ],
        events: [
            CalendarEventRecord(
                id: "1",
                title: "需求评审",
                calendarID: "work",
                startDate: .init(timeIntervalSince1970: 0),
                endDate: .init(timeIntervalSince1970: 3_600),
                isAllDay: false
            ),
        ]
    )
    let conversationService = RecordingAIConversationService(nextQuestion: "还有哪些待办？")
    let keyStore = ConversationInMemoryAIKeyStore()
    keyStore.values[.anthropic] = "anthropic-key"
    keyStore.values[.openAI] = "openai-key"
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.defaultAIProvider = .anthropic
    preferences.setAIProviderEnabled(true, for: .anthropic)
    preferences.setAIProviderBaseURL("https://api.anthropic.com/v1", for: .anthropic)
    preferences.setAIProviderModel("claude-sonnet-4-5", for: .anthropic)
    preferences.setAIProviderEnabled(true, for: .openAI)
    preferences.setAIProviderBaseURL("https://api.openai.com/v1", for: .openAI)
    preferences.setAIProviderModel("gpt-5-mini", for: .openAI)
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: keyStore,
        aiConversationArchiveStore: InMemoryAIConversationArchiveStore()
    )

    await model.refresh()
    await model.startAIConversation()
    model.updateDefaultAIProvider(.openAI)
    await model.sendAIConversationReply("已经产出结论了。")

    #expect(conversationService.askedConfigurations.count == 2)
    #expect(conversationService.askedConfigurations[0].provider == .anthropic)
    #expect(conversationService.askedConfigurations[1].provider == .anthropic)
}

@MainActor
@Test func finishAIConversationArchivesSummaryAndLoadsHistory() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: CalendarAuthorizationState.authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
        ],
        events: [
            CalendarEventRecord(
                id: "1",
                title: "需求评审",
                calendarID: "work",
                startDate: .init(timeIntervalSince1970: 0),
                endDate: .init(timeIntervalSince1970: 3_600),
                isAllDay: false
            ),
        ]
    )
    let conversationService = RecordingAIConversationService()
    let archiveStore = InMemoryAIConversationArchiveStore()
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.aiBaseURL = "https://example.com/v1"
    preferences.aiModel = "gpt-5-mini"
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: archiveStore
    )

    await model.refresh()
    await model.startAIConversation()
    await model.sendAIConversationReply("主要在对齐需求变更。")
    await model.finishAIConversation()

    guard case .completed(let summary) = model.aiConversationState else {
        Issue.record("Expected completed state")
        return
    }
    #expect(summary.provider == .openAI)
    #expect(summary.headline == "本周安排偏向沟通")
    #expect(model.aiConversationHistory.count == 1)
    #expect(model.aiConversationHistory.first?.headline == "本周安排偏向沟通")
    #expect(archiveStore.archive.summaries.count == 1)
    #expect(conversationService.summarizedHistories.first?.count == 3)
}

@MainActor
@Test func refreshingOverviewResetsCurrentConversationButKeepsHistory() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: CalendarAuthorizationState.authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
        ],
        events: [
            CalendarEventRecord(
                id: "1",
                title: "需求评审",
                calendarID: "work",
                startDate: .init(timeIntervalSince1970: 0),
                endDate: .init(timeIntervalSince1970: 3_600),
                isAllDay: false
            ),
        ]
    )
    let conversationService = RecordingAIConversationService()
    let archiveStore = InMemoryAIConversationArchiveStore()
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.aiBaseURL = "https://example.com/v1"
    preferences.aiModel = "gpt-5-mini"
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: archiveStore
    )

    await model.refresh()
    await model.startAIConversation()
    await model.sendAIConversationReply("主要在对齐需求变更。")
    await model.finishAIConversation()
    await model.setRange(TimeRangePreset.week)

    #expect(model.aiConversationHistory.count == 1)
    #expect(model.aiConversationState == AIConversationState.idle)
}
