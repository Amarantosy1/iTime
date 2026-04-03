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
    var value: String

    init(value: String = "") {
        self.value = value
    }

    func loadAPIKey() throws -> String { value }
    func saveAPIKey(_ apiKey: String) throws { value = apiKey }
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
    private(set) var askedContexts: [AIConversationContext] = []
    private(set) var askedHistories: [[AIConversationMessage]] = []
    private(set) var summarizedContexts: [AIConversationContext] = []
    private(set) var summarizedHistories: [[AIConversationMessage]] = []

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
        configuration: AIAnalysisConfiguration
    ) async throws -> AIConversationMessage {
        askedContexts.append(context)
        askedHistories.append(history)
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
        configuration: AIAnalysisConfiguration
    ) async throws -> AIConversationSummaryDraft {
        summarizedContexts.append(context)
        summarizedHistories.append(history)
        return summaryDraft
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
    #expect(session.messages.first?.role == AIConversationMessageRole.assistant)
    #expect(session.messages.first?.content == "需求评审主要讨论了什么？")
    #expect(conversationService.askedContexts.first?.events.map(\.title) == ["需求评审"])
    #expect(conversationService.askedContexts.first?.latestMemorySummary == "过去几轮复盘都显示会议偏多。")
    #expect(archiveStore.archive.sessions.count == 1)
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
