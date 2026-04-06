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
    var values: [UUID: String]

    init(value: String = "") {
        self.values = [AIProviderKind.openAI.builtInServiceID: value]
    }

    func loadAPIKey(for serviceID: UUID) throws -> String { values[serviceID] ?? "" }
    func saveAPIKey(_ apiKey: String, for serviceID: UUID) throws { values[serviceID] = apiKey }
}

private final class FailingSaveAIKeyStore: @unchecked Sendable, AIAPIKeyStoring {
    func loadAPIKey(for serviceID: UUID) throws -> String { "" }

    func saveAPIKey(_ apiKey: String, for serviceID: UUID) throws {
        throw NSError(domain: NSOSStatusErrorDomain, code: -25293)
    }
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
    var longFormDraft: AIConversationLongFormReportDraft
    var shouldSuspendNextQuestion = false
    var validateShouldFail = false
    private(set) var validatedConfigurations: [ResolvedAIProviderConfiguration] = []
    private(set) var askedContexts: [AIConversationContext] = []
    private(set) var askedHistories: [[AIConversationMessage]] = []
    private(set) var askedConfigurations: [ResolvedAIProviderConfiguration] = []
    private(set) var summarizedContexts: [AIConversationContext] = []
    private(set) var summarizedHistories: [[AIConversationMessage]] = []
    private(set) var summarizedConfigurations: [ResolvedAIProviderConfiguration] = []
    private(set) var generatedLongFormSessions: [AIConversationSession] = []
    private(set) var generatedLongFormSummaries: [AIConversationSummary] = []
    private(set) var generatedLongFormConfigurations: [ResolvedAIProviderConfiguration] = []
    var compactedMemoryText: String = "• 最近几轮复盘显示会议偏多\n• 用户有意识地保护早晨时间"
    private(set) var compactMemoryCallCount = 0
    private(set) var compactedSummaries: [[AIConversationSummary]] = []
    private(set) var compactedExistingMemories: [String?] = []
    private var suspendedQuestionContinuation: CheckedContinuation<AIConversationMessage, Never>?
    private var suspensionReadyContinuation: CheckedContinuation<Void, Never>?

    init(
        nextQuestion: String = "这个日程主要做了什么？",
        summaryDraft: AIConversationSummaryDraft = AIConversationSummaryDraft(
            headline: "本周安排偏向沟通",
            summary: "你本周大部分时间花在沟通同步上。",
            findings: ["会议密度偏高"],
            suggestions: ["给深度工作预留固定时段"]
        ),
        longFormDraft: AIConversationLongFormReportDraft = AIConversationLongFormReportDraft(
            title: "本周长文复盘",
            content: "这是一篇基于原始对话生成的长文复盘。"
        )
    ) {
        self.nextQuestion = nextQuestion
        self.summaryDraft = summaryDraft
        self.longFormDraft = longFormDraft
    }

    func validateConnection(configuration: ResolvedAIProviderConfiguration) async throws {
        validatedConfigurations.append(configuration)
        if validateShouldFail {
            throw AIAnalysisServiceError.invalidConfiguration
        }
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

    func generateLongFormReport(
        session: AIConversationSession,
        summary: AIConversationSummary,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationLongFormReportDraft {
        generatedLongFormSessions.append(session)
        generatedLongFormSummaries.append(summary)
        generatedLongFormConfigurations.append(configuration)
        return longFormDraft
    }

    func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        compactMemoryCallCount += 1
        compactedSummaries.append(recentSummaries)
        compactedExistingMemories.append(existingMemory)
        return compactedMemoryText
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
            ],
            longFormReports: []
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
@Test func startAIConversationExcludesReviewDisabledCalendarsFromContext() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: CalendarAuthorizationState.authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
            CalendarSource(id: "private", name: "私人", colorHex: "#F5A623", isSelected: true),
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
            CalendarEventRecord(
                id: "2",
                title: "家庭安排",
                calendarID: "private",
                startDate: .init(timeIntervalSince1970: 7_200),
                endDate: .init(timeIntervalSince1970: 9_000),
                isAllDay: false
            ),
        ]
    )
    let conversationService = RecordingAIConversationService(nextQuestion: "今天最值得关注的安排是什么？")
    let archiveStore = InMemoryAIConversationArchiveStore()
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.aiBaseURL = "https://example.com/v1"
    preferences.aiModel = "gpt-5-mini"
    preferences.replaceReviewExcludedCalendars(with: ["private"])
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: archiveStore
    )

    await model.refresh()
    await model.startAIConversation()

    #expect(conversationService.askedContexts.first?.events.map(\.title) == ["需求评审"])
    #expect(conversationService.askedContexts.first?.overviewSnapshot.totalEventCount == 1)
    #expect(conversationService.askedContexts.first?.overviewSnapshot.topCalendarNames == ["工作"])
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
    keyStore.values[AIProviderKind.gemini.builtInServiceID] = "gemini-key"
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.defaultAIProvider = .gemini
    preferences.setAIProviderEnabled(true, for: .gemini)
    preferences.setAIProviderBaseURL("https://generativelanguage.googleapis.com/v1beta", for: .gemini)
    preferences.setAIProviderModel("gemini-2.0-flash", for: .gemini)
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
    #expect(session.provider == .gemini)
    #expect(conversationService.askedConfigurations.first?.provider == .gemini)
    #expect(conversationService.askedConfigurations.first?.model == "gemini-2.0-flash")
}

@MainActor
@Test func startAIConversationFallsBackToEnabledServiceWhenDefaultServiceDisabled() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
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
    let conversationService = RecordingAIConversationService(nextQuestion: "路线评审产出了什么？")
    let keyStore = ConversationInMemoryAIKeyStore()
    keyStore.values[AIProviderKind.gemini.builtInServiceID] = "gemini-key"
    let preferences = UserPreferences(storage: .inMemory)
    preferences.setDefaultAIServiceID(AIProviderKind.openAI.builtInServiceID)
    preferences.setAIProviderEnabled(true, for: .gemini)
    preferences.setAIProviderBaseURL("https://generativelanguage.googleapis.com/v1beta", for: .gemini)
    preferences.setAIProviderModel("gemini-2.0-flash", for: .gemini)
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
        Issue.record("Expected waitingForUser state when a non-default enabled service is configured")
        return
    }
    #expect(session.provider == .gemini)
    #expect(conversationService.askedConfigurations.first?.provider == .gemini)
}

@MainActor
@Test func startAIConversationBindsSelectedServiceAndModel() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
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
    let service = AIServiceEndpoint.customOpenAICompatible(
        displayName: "OpenAI Proxy",
        baseURL: "https://proxy.example.com/v1",
        models: ["gpt-5", "gpt-5-mini"],
        defaultModel: "gpt-5-mini",
        isEnabled: true
    )
    let conversationService = RecordingAIConversationService(nextQuestion: "路线评审的结论是什么？")
    let keyStore = ConversationInMemoryAIKeyStore()
    keyStore.values[service.id] = "proxy-key"
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.saveAIService(service)
    preferences.setDefaultAIServiceID(service.id)
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: keyStore,
        aiConversationArchiveStore: InMemoryAIConversationArchiveStore()
    )

    await model.refresh()
    model.selectConversationService(id: service.id)
    model.selectConversationModel("gpt-5")
    await model.startAIConversation()

    guard case .waitingForUser(let session) = model.aiConversationState else {
        Issue.record("Expected waitingForUser state")
        return
    }
    #expect(session.serviceID == service.id)
    #expect(session.serviceDisplayName == "OpenAI Proxy")
    #expect(session.model == "gpt-5")
    #expect(conversationService.askedConfigurations.first?.baseURL == "https://proxy.example.com/v1")
    #expect(conversationService.askedConfigurations.first?.model == "gpt-5")
}

@MainActor
@Test func startAIConversationWorksAfterEnablingBuiltInOpenAIServiceWithoutManualModelInput() async throws {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
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
    let conversationService = RecordingAIConversationService(nextQuestion: "本次评审主要结论是什么？")
    let preferences = UserPreferences(storage: .inMemory)
    let keyStore = ConversationInMemoryAIKeyStore(value: "openai-key")
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: keyStore,
        aiConversationArchiveStore: InMemoryAIConversationArchiveStore()
    )

    await model.refresh()
    let openAIService = try #require(model.availableAIServices.first(where: { $0.providerKind == .openAI }))
    model.updateAIService(openAIService.updating(isEnabled: true))
    await model.startAIConversation()

    guard case .waitingForUser = model.aiConversationState else {
        Issue.record("Expected waitingForUser state after enabling OpenAI built-in service")
        return
    }
    #expect(conversationService.askedConfigurations.first?.provider == .openAI)
    #expect((conversationService.askedConfigurations.first?.model.isEmpty ?? true) == false)
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
    keyStore.values[AIProviderKind.gemini.builtInServiceID] = "gemini-key"
    keyStore.values[AIProviderKind.openAI.builtInServiceID] = "openai-key"
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.defaultAIProvider = .gemini
    preferences.setAIProviderEnabled(true, for: .gemini)
    preferences.setAIProviderBaseURL("https://generativelanguage.googleapis.com/v1beta", for: .gemini)
    preferences.setAIProviderModel("gemini-2.0-flash", for: .gemini)
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
    #expect(conversationService.askedConfigurations[0].provider == .gemini)
    #expect(conversationService.askedConfigurations[1].provider == .gemini)
}

@MainActor
@Test func changingServiceSelectionDoesNotAffectOngoingConversation() async throws {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
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
    let primaryService = AIServiceEndpoint.customOpenAICompatible(
        displayName: "OpenAI Proxy A",
        baseURL: "https://proxy-a.example.com/v1",
        models: ["gpt-5-mini"],
        defaultModel: "gpt-5-mini",
        isEnabled: true
    )
    let secondaryService = AIServiceEndpoint.customOpenAICompatible(
        displayName: "OpenAI Proxy B",
        baseURL: "https://proxy-b.example.com/v1",
        models: ["gpt-5"],
        defaultModel: "gpt-5",
        isEnabled: true
    )
    let conversationService = RecordingAIConversationService(nextQuestion: "还有哪些待办？")
    let keyStore = ConversationInMemoryAIKeyStore()
    keyStore.values[primaryService.id] = "proxy-a-key"
    keyStore.values[secondaryService.id] = "proxy-b-key"
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.saveAIService(primaryService)
    preferences.saveAIService(secondaryService)
    preferences.setDefaultAIServiceID(primaryService.id)
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: keyStore,
        aiConversationArchiveStore: InMemoryAIConversationArchiveStore()
    )

    await model.refresh()
    model.selectConversationService(id: primaryService.id)
    await model.startAIConversation()

    let startedSession = try #require(model.currentConversationSession)
    model.selectConversationService(id: secondaryService.id)
    model.selectConversationModel("gpt-5")
    await model.sendAIConversationReply("已经产出结论了。")

    let continuedSession = try #require(model.currentConversationSession)
    #expect(continuedSession.serviceID == startedSession.serviceID)
    #expect(continuedSession.model == startedSession.model)
    #expect(conversationService.askedConfigurations.count == 2)
    #expect(conversationService.askedConfigurations[0].baseURL == "https://proxy-a.example.com/v1")
    #expect(conversationService.askedConfigurations[1].baseURL == "https://proxy-a.example.com/v1")
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
@Test func aiConversationHistoryOrderingIsDeterministicWhenCreatedAtTies() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
        calendars: [],
        events: []
    )
    let idTieLow = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let idTieHigh = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let idOldest = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    func makeSummary(id: UUID, createdAt: Date, headline: String) -> AIConversationSummary {
        AIConversationSummary(
            id: id,
            sessionID: UUID(),
            serviceID: AIProviderKind.openAI.builtInServiceID,
            serviceDisplayName: "OpenAI",
            provider: .openAI,
            model: "gpt-5-mini",
            range: .today,
            startDate: .init(timeIntervalSince1970: 0),
            endDate: .init(timeIntervalSince1970: 86_400),
            createdAt: createdAt,
            headline: headline,
            summary: "",
            findings: [],
            suggestions: [],
            overviewSnapshot: AIOverviewSnapshot(
                rangeTitle: "今天",
                totalDurationText: "0小时",
                totalEventCount: 0,
                topCalendarNames: []
            )
        )
    }

    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [],
            summaries: [
                makeSummary(id: idOldest, createdAt: .init(timeIntervalSince1970: 100), headline: "最旧"),
                makeSummary(id: idTieLow, createdAt: .init(timeIntervalSince1970: 200), headline: "并列-低"),
                makeSummary(id: idTieHigh, createdAt: .init(timeIntervalSince1970: 200), headline: "并列-高"),
            ],
            memorySnapshots: [],
            longFormReports: []
        )
    )

    let model = AppModel(
        service: calendarService,
        preferences: UserPreferences(storage: .inMemory),
        aiConversationService: RecordingAIConversationService(),
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: archiveStore
    )

    await model.refresh()

    #expect(model.aiConversationHistory.map(\.id) == [idTieHigh, idTieLow, idOldest])
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

@MainActor
@Test func deletingConversationSummaryRemovesSummarySessionAndMemory() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
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
    let summaryID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    let sessionID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    let reportID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [
                AIConversationSession(
                    id: sessionID,
                    serviceID: AIProviderKind.openAI.builtInServiceID,
                    serviceDisplayName: "OpenAI",
                    provider: .openAI,
                    model: "gpt-5-mini",
                    range: .today,
                    startDate: .init(timeIntervalSince1970: 0),
                    endDate: .init(timeIntervalSince1970: 86_400),
                    startedAt: .init(timeIntervalSince1970: 0),
                    completedAt: .init(timeIntervalSince1970: 7_200),
                    status: .completed,
                    overviewSnapshot: AIOverviewSnapshot(
                        rangeTitle: "今天",
                        totalDurationText: "1小时",
                        totalEventCount: 1,
                        topCalendarNames: ["工作"]
                    ),
                    messages: []
                ),
            ],
            summaries: [
                AIConversationSummary(
                    id: summaryID,
                    sessionID: sessionID,
                    serviceID: AIProviderKind.openAI.builtInServiceID,
                    serviceDisplayName: "OpenAI",
                    provider: .openAI,
                    model: "gpt-5-mini",
                    range: .today,
                    startDate: .init(timeIntervalSince1970: 0),
                    endDate: .init(timeIntervalSince1970: 86_400),
                    createdAt: .init(timeIntervalSince1970: 7_200),
                    headline: "今天以沟通为主",
                    summary: "今天的日程多为需求同步。",
                    findings: ["沟通密度偏高"],
                    suggestions: ["给执行留整块时间"],
                    overviewSnapshot: AIOverviewSnapshot(
                        rangeTitle: "今天",
                        totalDurationText: "1小时",
                        totalEventCount: 1,
                        topCalendarNames: ["工作"]
                    )
                ),
            ],
            memorySnapshots: [
                AIMemorySnapshot(
                    id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
                    createdAt: .init(timeIntervalSince1970: 8_000),
                    sourceSummaryIDs: [summaryID],
                    summary: "最近几轮复盘都显示沟通偏多。"
                ),
            ],
            longFormReports: [
                AIConversationLongFormReport(
                    id: reportID,
                    sessionID: sessionID,
                    summaryID: summaryID,
                    createdAt: .init(timeIntervalSince1970: 8_100),
                    updatedAt: .init(timeIntervalSince1970: 8_100),
                    title: "今天复盘长文",
                    content: "这是一篇长文复盘。"
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
    model.deleteAIConversationSummary(id: summaryID)

    #expect(model.aiConversationHistory.isEmpty)
    #expect(model.latestAIMemorySnapshot == nil)
    #expect(archiveStore.archive.summaries.isEmpty)
    #expect(archiveStore.archive.sessions.isEmpty)
    #expect(archiveStore.archive.memorySnapshots.isEmpty)
    #expect(archiveStore.archive.longFormReports.isEmpty)
}

@MainActor
@Test func updatingConversationSummaryPersistsEditedContent() async throws {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
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
    let summaryID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    let sessionID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    let originalSummary = AIConversationSummary(
        id: summaryID,
        sessionID: sessionID,
        serviceID: AIProviderKind.openAI.builtInServiceID,
        serviceDisplayName: "OpenAI",
        provider: .openAI,
        model: "gpt-5-mini",
        range: .today,
        startDate: .init(timeIntervalSince1970: 0),
        endDate: .init(timeIntervalSince1970: 86_400),
        createdAt: .init(timeIntervalSince1970: 7_200),
        headline: "今天以沟通为主",
        summary: "今天的日程多为需求同步。",
        findings: ["沟通密度偏高"],
        suggestions: ["给执行留整块时间"],
        overviewSnapshot: AIOverviewSnapshot(
            rangeTitle: "今天",
            totalDurationText: "1小时",
            totalEventCount: 1,
            topCalendarNames: ["工作"]
        )
    )
    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [],
            summaries: [originalSummary],
            memorySnapshots: [],
            longFormReports: []
        )
    )
    let preferences = UserPreferences(storage: .inMemory)
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: RecordingAIConversationService(),
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: archiveStore
    )

    await model.refresh()
    model.updateAIConversationSummary(
        id: summaryID,
        headline: "今天的时间被会议切碎了",
        summary: "今天大部分时间花在需求同步和结论确认上。",
        findings: ["连续会议过多", "执行时间不足"],
        suggestions: ["明天预留 2 小时深度工作"]
    )

    let editedSummary = try #require(model.aiConversationHistory.first)
    #expect(editedSummary.headline == "今天的时间被会议切碎了")
    #expect(editedSummary.summary == "今天大部分时间花在需求同步和结论确认上。")
    #expect(editedSummary.findings == ["连续会议过多", "执行时间不足"])
    #expect(editedSummary.suggestions == ["明天预留 2 小时深度工作"])
    #expect(archiveStore.archive.summaries.first?.headline == "今天的时间被会议切碎了")
}

@MainActor
@Test func generatingLongFormReportPersistsReportFromConversationSession() async throws {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
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
    let conversationService = RecordingAIConversationService(
        longFormDraft: AIConversationLongFormReportDraft(
            title: "本周复盘长文",
            content: "这是一篇基于原始对话生成的长文复盘。"
        )
    )
    let sessionID = UUID(uuidString: "11111111-aaaa-bbbb-cccc-111111111111")!
    let summaryID = UUID(uuidString: "22222222-aaaa-bbbb-cccc-222222222222")!
    let session = AIConversationSession(
        id: sessionID,
        serviceID: AIProviderKind.openAI.builtInServiceID,
        serviceDisplayName: "OpenAI",
        provider: .openAI,
        model: "gpt-5-mini",
        range: .week,
        startDate: .init(timeIntervalSince1970: 0),
        endDate: .init(timeIntervalSince1970: 86_400),
        startedAt: .init(timeIntervalSince1970: 0),
        completedAt: .init(timeIntervalSince1970: 7_200),
        status: .completed,
        overviewSnapshot: AIOverviewSnapshot(
            rangeTitle: "本周",
            totalDurationText: "5小时",
            totalEventCount: 2,
            topCalendarNames: ["工作"]
        ),
        messages: [
            AIConversationMessage(
                id: UUID(),
                role: .assistant,
                content: "这次需求评审主要产出了什么？",
                createdAt: .init(timeIntervalSince1970: 100)
            ),
            AIConversationMessage(
                id: UUID(),
                role: .user,
                content: "主要在对齐需求变更和下周排期。",
                createdAt: .init(timeIntervalSince1970: 200)
            ),
        ]
    )
    let summary = AIConversationSummary(
        id: summaryID,
        sessionID: sessionID,
        serviceID: AIProviderKind.openAI.builtInServiceID,
        serviceDisplayName: "OpenAI",
        provider: .openAI,
        model: "gpt-5-mini",
        range: .week,
        startDate: .init(timeIntervalSince1970: 0),
        endDate: .init(timeIntervalSince1970: 86_400),
        createdAt: .init(timeIntervalSince1970: 7_200),
        headline: "本周工作会议偏多",
        summary: "短总结不是长文主输入。",
        findings: ["会议偏多"],
        suggestions: ["预留整块时间"],
        overviewSnapshot: session.overviewSnapshot
    )
    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [session],
            summaries: [summary],
            memorySnapshots: [],
            longFormReports: []
        )
    )
    let preferences = UserPreferences(storage: .inMemory)
    preferences.setAIProviderEnabled(true, for: .openAI)
    preferences.setAIProviderBaseURL("https://example.com/v1", for: .openAI)
    preferences.setAIProviderModel("gpt-5-mini", for: .openAI)
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: archiveStore
    )

    await model.refresh()
    await model.generateLongFormReport(for: summaryID)

    let report = try #require(model.longFormReport(for: summaryID))
    #expect(report.title == "本周复盘长文")
    #expect(report.content == "这是一篇基于原始对话生成的长文复盘。")
    #expect(conversationService.generatedLongFormSessions.first?.id == sessionID)
    #expect(conversationService.generatedLongFormSummaries.first?.id == summaryID)
    #expect(conversationService.generatedLongFormConfigurations.first?.provider == .openAI)
}

@MainActor
@Test func updatingLongFormReportPersistsEditedContent() async throws {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
        ],
        events: []
    )
    let reportID = UUID(uuidString: "33333333-aaaa-bbbb-cccc-333333333333")!
    let summaryID = UUID(uuidString: "44444444-aaaa-bbbb-cccc-444444444444")!
    let sessionID = UUID(uuidString: "55555555-aaaa-bbbb-cccc-555555555555")!
    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [],
            summaries: [],
            memorySnapshots: [],
            longFormReports: [
                AIConversationLongFormReport(
                    id: reportID,
                    sessionID: sessionID,
                    summaryID: summaryID,
                    createdAt: .init(timeIntervalSince1970: 100),
                    updatedAt: .init(timeIntervalSince1970: 100),
                    title: "旧标题",
                    content: "旧内容"
                ),
            ]
        )
    )
    let model = AppModel(
        service: calendarService,
        preferences: UserPreferences(storage: .inMemory),
        aiConversationService: RecordingAIConversationService(),
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: archiveStore
    )

    await model.refresh()
    model.updateLongFormReport(id: reportID, title: "新标题", content: "新的长文内容")

    let report = try #require(model.longFormReport(for: summaryID))
    #expect(report.title == "新标题")
    #expect(report.content == "新的长文内容")
}

@MainActor
@Test func discardingInProgressConversationRemovesDraftSessionWithoutSummary() async throws {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
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
    let sessionID = try #require(model.currentConversationSession?.id)

    model.discardCurrentAIConversation()

    #expect(model.aiConversationState == .idle)
    #expect(model.aiConversationHistory.isEmpty)
    #expect(archiveStore.archive.summaries.isEmpty)
    #expect(archiveStore.archive.sessions.contains(where: { $0.id == sessionID }) == false)
}

@MainActor
@Test func activeConversationStateFlagsMatchConversationLifecycle() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
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
    #expect(model.hasActiveAIConversation == false)
    #expect(model.canAdjustConversationRange == true)

    await model.startAIConversation()
    #expect(model.hasActiveAIConversation == true)
    #expect(model.canAdjustConversationRange == false)

    model.discardCurrentAIConversation()
    #expect(model.hasActiveAIConversation == false)
    #expect(model.canAdjustConversationRange == true)
}

@MainActor
@Test func testAIServiceConnectionStoresSuccessStatePerService() async throws {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
        calendars: [],
        events: []
    )
    let conversationService = RecordingAIConversationService()
    let keyStore = ConversationInMemoryAIKeyStore(value: "secret-key")
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.aiBaseURL = "https://api.openai.com/v1"
    preferences.aiModel = "gpt-5-mini"
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: keyStore,
        aiConversationArchiveStore: InMemoryAIConversationArchiveStore()
    )

    await model.refresh()
    let service = try #require(model.availableAIServices.first(where: { $0.providerKind == .openAI }))

    await model.testAIServiceConnection(service.id)

    #expect(model.aiServiceConnectionState(for: service.id) == .succeeded("连接成功"))
    #expect(conversationService.validatedConfigurations.first?.provider == .openAI)
}

@MainActor
@Test func testAIServiceConnectionDoesNotDependOnLegacyAIAnalysisToggle() async throws {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
        calendars: [],
        events: []
    )
    let conversationService = RecordingAIConversationService()
    let service = AIServiceEndpoint.customOpenAICompatible(
        displayName: "Gemini 代理",
        baseURL: "https://generativelanguage.googleapis.com/v1beta",
        models: ["gemini-2.5-flash"],
        defaultModel: "gemini-2.5-flash",
        isEnabled: true
    )
    let keyStore = ConversationInMemoryAIKeyStore()
    keyStore.values[service.id] = "gemini-key"
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = false
    preferences.saveAIService(service)
    preferences.setDefaultAIServiceID(service.id)
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: keyStore,
        aiConversationArchiveStore: InMemoryAIConversationArchiveStore()
    )

    await model.refresh()
    await model.testAIServiceConnection(service.id)

    #expect(model.aiServiceConnectionState(for: service.id) == .succeeded("连接成功"))
    #expect(conversationService.validatedConfigurations.first?.provider == .openAICompatible)
    #expect(conversationService.validatedConfigurations.first?.isEnabled == true)
}

@MainActor
@Test func testAIServiceConnectionWorksWhenServiceIsDisabled() async throws {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
        calendars: [],
        events: []
    )
    let conversationService = RecordingAIConversationService()
    let service = AIServiceEndpoint.customOpenAICompatible(
        displayName: "禁用服务",
        baseURL: "https://api.example.com/v1",
        models: ["gpt-4o-mini"],
        defaultModel: "gpt-4o-mini",
        isEnabled: false
    )
    let keyStore = ConversationInMemoryAIKeyStore()
    keyStore.values[service.id] = "example-key"
    let preferences = UserPreferences(storage: .inMemory)
    preferences.saveAIService(service)
    preferences.setDefaultAIServiceID(service.id)
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: keyStore,
        aiConversationArchiveStore: InMemoryAIConversationArchiveStore()
    )

    await model.refresh()
    await model.testAIServiceConnection(service.id)

    #expect(model.aiServiceConnectionState(for: service.id) == .succeeded("连接成功"))
    #expect(conversationService.validatedConfigurations.first?.provider == .openAICompatible)
    #expect(conversationService.validatedConfigurations.first?.isEnabled == false)
}

@MainActor
@Test func testAIServiceConnectionUsesInMemoryKeyWhenKeychainSaveFails() async throws {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
        calendars: [],
        events: []
    )
    let conversationService = RecordingAIConversationService()
    let service = AIServiceEndpoint.customOpenAICompatible(
        displayName: "Keychain 失败服务",
        baseURL: "https://api.example.com/v1",
        models: ["gpt-4o-mini"],
        defaultModel: "gpt-4o-mini",
        isEnabled: true
    )
    let preferences = UserPreferences(storage: .inMemory)
    preferences.saveAIService(service)
    preferences.setDefaultAIServiceID(service.id)
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: FailingSaveAIKeyStore(),
        aiConversationArchiveStore: InMemoryAIConversationArchiveStore()
    )

    await model.refresh()
    model.updateAIAPIKey("temp-key", for: service.id)
    await model.testAIServiceConnection(service.id)

    #expect(model.aiServiceConnectionState(for: service.id) == .succeeded("连接成功"))
    #expect(conversationService.validatedConfigurations.first?.apiKey == "temp-key")
}

@MainActor
@Test func finishAIConversationCreatesMemorySnapshotAfterSummary() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
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
    conversationService.compactedMemoryText = "• 会议偏多\n• 执行时间不足"
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

    #expect(conversationService.compactMemoryCallCount == 1)
    #expect(conversationService.compactedSummaries.first?.count == 1)
    #expect(model.latestAIMemorySnapshot?.summary == "• 会议偏多\n• 执行时间不足")
    #expect(archiveStore.archive.memorySnapshots.count == 1)
    #expect(archiveStore.archive.memorySnapshots.first?.summary == "• 会议偏多\n• 执行时间不足")
}

@MainActor
@Test func contextMemoryIsTruncatedToTokenBudgetWhenTooLong() async {
    let longMemory = String(repeating: "记忆内容", count: 250) // 1000 chars > 800 budget
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
        ],
        events: [
            CalendarEventRecord(
                id: "1",
                title: "深度工作",
                calendarID: "work",
                startDate: .init(timeIntervalSince1970: 0),
                endDate: .init(timeIntervalSince1970: 3_600),
                isAllDay: false
            ),
        ]
    )
    let conversationService = RecordingAIConversationService()
    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [],
            summaries: [],
            memorySnapshots: [
                AIMemorySnapshot(
                    id: UUID(),
                    createdAt: .init(timeIntervalSince1970: 100),
                    sourceSummaryIDs: [],
                    summary: longMemory
                ),
            ],
            longFormReports: []
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

    let injectedMemory = conversationService.askedContexts.first?.latestMemorySummary
    let memoryLength = injectedMemory?.count ?? 0
    #expect(memoryLength <= 801)
    #expect(injectedMemory?.hasSuffix("…") == true)
}

@MainActor
@Test func todayContextMemoryUsesYesterdayAndPreviousSevenDayCompact() async {
    let calendar = Calendar(identifier: .gregorian)
    let fixedNow = calendar.date(from: DateComponents(year: 2026, month: 4, day: 8, hour: 10))!
    let todayStart = calendar.startOfDay(for: fixedNow)
    let weekStart = calendar.dateInterval(of: .weekOfYear, for: todayStart)!.start
    let monthStart = calendar.dateInterval(of: .month, for: todayStart)!.start

    let previousSevenDailySummaries = (1...7).map { offset in
        makeSummary(
            range: .today,
            startDate: calendar.date(byAdding: .day, value: -offset, to: todayStart)!,
            calendar: calendar,
            headline: "日复盘-\(offset)",
            summary: "第\(offset)天的日复盘"
        )
    }

    let weekSummary = makeSummary(
        range: .week,
        startDate: weekStart,
        calendar: calendar,
        headline: "本周全局",
        summary: "本周总结"
    )
    let monthSummary = makeSummary(
        range: .month,
        startDate: monthStart,
        calendar: calendar,
        headline: "本月全局",
        summary: "本月总结"
    )

    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [],
            summaries: previousSevenDailySummaries + [weekSummary, monthSummary],
            memorySnapshots: [],
            longFormReports: []
        )
    )

    let (model, conversationService) = makeConversationModel(
        calendar: calendar,
        now: fixedNow,
        archiveStore: archiveStore
    )
    model.preferences.selectedRange = .today

    await model.refresh()
    await model.startAIConversation()

    let injectedMemory = conversationService.askedContexts.first?.latestMemorySummary

    #expect(injectedMemory?.contains("【昨天的反思】标题：日复盘-1") == true)
    #expect(injectedMemory?.contains("【近七天日复盘压缩】") == true)
    #expect(injectedMemory?.contains("日复盘-7") == true)
    #expect(injectedMemory?.contains("本周的全局定调") == false)
    #expect(injectedMemory?.contains("本月的全局定调") == false)
}

@MainActor
@Test func weekContextMemoryUsesLastWeekOnly() async {
    let calendar = Calendar(identifier: .gregorian)
    let fixedNow = calendar.date(from: DateComponents(year: 2026, month: 4, day: 8, hour: 10))!
    let weekStart = calendar.dateInterval(of: .weekOfYear, for: fixedNow)!.start
    let monthStart = calendar.dateInterval(of: .month, for: fixedNow)!.start

    let lastWeekSummary = makeSummary(
        range: .week,
        startDate: calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart)!,
        calendar: calendar,
        headline: "上周复盘",
        summary: "上周的内容"
    )
    let thisMonthSummary = makeSummary(
        range: .month,
        startDate: monthStart,
        calendar: calendar,
        headline: "本月复盘",
        summary: "本月的内容"
    )

    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [],
            summaries: [lastWeekSummary, thisMonthSummary],
            memorySnapshots: [],
            longFormReports: []
        )
    )
    let (model, conversationService) = makeConversationModel(
        calendar: calendar,
        now: fixedNow,
        archiveStore: archiveStore
    )
    model.preferences.selectedRange = .week

    await model.refresh()
    await model.startAIConversation()

    let injectedMemory = conversationService.askedContexts.first?.latestMemorySummary

    #expect(injectedMemory?.contains("【上周的反思】标题：上周复盘") == true)
    #expect(injectedMemory?.contains("本月的全局定调") == false)
}

@MainActor
@Test func monthContextMemoryUsesLastMonthSummary() async {
    let calendar = Calendar(identifier: .gregorian)
    let fixedNow = calendar.date(from: DateComponents(year: 2026, month: 4, day: 8, hour: 10))!
    let monthStart = calendar.dateInterval(of: .month, for: fixedNow)!.start
    let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart)!

    let lastMonthSummary = makeSummary(
        range: .month,
        startDate: lastMonthStart,
        calendar: calendar,
        headline: "上月复盘",
        summary: "上月内容"
    )

    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [],
            summaries: [lastMonthSummary],
            memorySnapshots: [],
            longFormReports: []
        )
    )
    let (model, conversationService) = makeConversationModel(
        calendar: calendar,
        now: fixedNow,
        archiveStore: archiveStore
    )
    model.preferences.selectedRange = .month

    await model.refresh()
    await model.startAIConversation()

    let injectedMemory = conversationService.askedContexts.first?.latestMemorySummary
    #expect(injectedMemory?.contains("【上个月的总结】标题：上月复盘") == true)
}

@MainActor
@Test func customContextMemoryUsesNearestCustomSummaryOnly() async {
    let calendar = Calendar(identifier: .gregorian)
    let fixedNow = calendar.date(from: DateComponents(year: 2026, month: 4, day: 8, hour: 10))!
    let customStart = calendar.startOfDay(for: fixedNow)
    let customEnd = calendar.date(byAdding: .day, value: 2, to: customStart)!

    let nearestCustomSummary = makeSummary(
        range: .custom,
        startDate: calendar.date(byAdding: .day, value: -1, to: customStart)!,
        calendar: calendar,
        headline: "最近自定义",
        summary: "最近一次自定义复盘",
        endDateOverride: calendar.date(byAdding: .day, value: 2, to: customStart)!
    )
    let farCustomSummary = makeSummary(
        range: .custom,
        startDate: calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!,
        calendar: calendar,
        headline: "远端自定义",
        summary: "很久之前的自定义复盘"
    )
    let weekSummary = makeSummary(
        range: .week,
        startDate: calendar.dateInterval(of: .weekOfYear, for: customStart)!.start,
        calendar: calendar,
        headline: "周复盘",
        summary: "周内容"
    )

    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [],
            summaries: [farCustomSummary, nearestCustomSummary, weekSummary],
            memorySnapshots: [],
            longFormReports: []
        )
    )
    let (model, conversationService) = makeConversationModel(
        calendar: calendar,
        now: fixedNow,
        archiveStore: archiveStore
    )
    model.preferences.selectedRange = .custom
    model.preferences.customStartDate = customStart
    model.preferences.customEndDate = customEnd

    await model.refresh()
    await model.startAIConversation()

    let injectedMemory = conversationService.askedContexts.first?.latestMemorySummary
    #expect(injectedMemory?.contains("【上一段自定义复盘】标题：最近自定义") == true)
    #expect(injectedMemory?.contains("远端自定义") == false)
    #expect(injectedMemory?.contains("上周的反思") == false)
}

@MainActor
@Test func customContextMemoryPrefersLatestSummaryWhenDistanceTies() async {
    let calendar = Calendar(identifier: .gregorian)
    let fixedNow = calendar.date(from: DateComponents(year: 2026, month: 4, day: 8, hour: 10))!
    let customStart = calendar.startOfDay(for: fixedNow)
    let customEnd = customStart

    let olderSummary = makeSummary(
        range: .custom,
        startDate: calendar.date(byAdding: .day, value: -1, to: customStart)!,
        calendar: calendar,
        headline: "并列-旧",
        summary: "并列候选旧",
        createdAt: .init(timeIntervalSince1970: 100)
    )
    let newerSummary = makeSummary(
        range: .custom,
        startDate: calendar.date(byAdding: .day, value: 1, to: customStart)!,
        calendar: calendar,
        headline: "并列-新",
        summary: "并列候选新",
        createdAt: .init(timeIntervalSince1970: 200)
    )

    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [],
            summaries: [olderSummary, newerSummary],
            memorySnapshots: [],
            longFormReports: []
        )
    )
    let (model, conversationService) = makeConversationModel(
        calendar: calendar,
        now: fixedNow,
        archiveStore: archiveStore
    )
    model.preferences.selectedRange = .custom
    model.preferences.customStartDate = customStart
    model.preferences.customEndDate = customEnd

    await model.refresh()
    await model.startAIConversation()

    let injectedMemory = conversationService.askedContexts.first?.latestMemorySummary
    #expect(injectedMemory?.contains("【上一段自定义复盘】标题：并列-新") == true)
    #expect(injectedMemory?.contains("并列-旧") == false)
}

@MainActor
@Test func finishCustomConversationCompactsCurrentAndNearestPreviousCustomOnly() async {
    let calendar = Calendar(identifier: .gregorian)
    let fixedNow = calendar.date(from: DateComponents(year: 2026, month: 4, day: 8, hour: 10))!
    let customStart = calendar.startOfDay(for: fixedNow)
    let customEnd = calendar.date(byAdding: .day, value: 2, to: customStart)!

    let nearestCustomSummary = makeSummary(
        range: .custom,
        startDate: calendar.date(byAdding: .day, value: -1, to: customStart)!,
        calendar: calendar,
        headline: "最近自定义",
        summary: "最近一次自定义复盘",
        endDateOverride: calendar.date(byAdding: .day, value: 2, to: customStart)!
    )
    let farCustomSummary = makeSummary(
        range: .custom,
        startDate: calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!,
        calendar: calendar,
        headline: "远端自定义",
        summary: "很久之前的自定义复盘"
    )
    let monthSummary = makeSummary(
        range: .month,
        startDate: calendar.dateInterval(of: .month, for: customStart)!.start,
        calendar: calendar,
        headline: "月复盘",
        summary: "月内容"
    )

    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [],
            summaries: [farCustomSummary, nearestCustomSummary, monthSummary],
            memorySnapshots: [],
            longFormReports: []
        )
    )
    let conversationService = RecordingAIConversationService()
    let preferences = UserPreferences(storage: .inMemory)
    preferences.selectedRange = .custom
    preferences.customStartDate = customStart
    preferences.customEndDate = customEnd
    preferences.aiAnalysisEnabled = true
    preferences.aiBaseURL = "https://example.com/v1"
    preferences.aiModel = "gpt-5-mini"
    let model = AppModel(
        service: ConversationStubCalendarAccessService(
            state: .authorized,
            calendars: [
                CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
            ],
            events: [
                CalendarEventRecord(
                    id: "1",
                    title: "深度工作",
                    calendarID: "work",
                    startDate: customStart,
                    endDate: customStart.addingTimeInterval(3_600),
                    isAllDay: false
                ),
            ]
        ),
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: archiveStore,
        calendar: calendar,
        now: { fixedNow }
    )

    await model.refresh()
    await model.startAIConversation()
    await model.finishAIConversation()

    let compacted = conversationService.compactedSummaries.first ?? []
    #expect(compacted.count == 2)
    #expect(compacted.allSatisfy { $0.range == .custom })
    #expect(compacted.contains(where: { $0.headline == "最近自定义" }))
    #expect(compacted.contains(where: { $0.headline == "远端自定义" }) == false)
    #expect(compacted.contains(where: { $0.headline == "月复盘" }) == false)
}

@MainActor
@Test func finishTodayConversationCompactsTrailingSevenDailySummariesOnly() async {
    let calendar = Calendar(identifier: .gregorian)
    let fixedNow = calendar.date(from: DateComponents(year: 2026, month: 4, day: 8, hour: 10))!
    let todayStart = calendar.startOfDay(for: fixedNow)
    let weekStart = calendar.dateInterval(of: .weekOfYear, for: todayStart)!.start
    let monthStart = calendar.dateInterval(of: .month, for: todayStart)!.start

    let previousSevenDailySummaries = (1...7).map { offset in
        makeSummary(
            range: .today,
            startDate: calendar.date(byAdding: .day, value: -offset, to: todayStart)!,
            calendar: calendar,
            headline: "历史日复盘-\(offset)",
            summary: "历史第\(offset)天"
        )
    }
    let weekSummary = makeSummary(
        range: .week,
        startDate: weekStart,
        calendar: calendar,
        headline: "周复盘",
        summary: "周内容"
    )
    let monthSummary = makeSummary(
        range: .month,
        startDate: monthStart,
        calendar: calendar,
        headline: "月复盘",
        summary: "月内容"
    )

    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [],
            summaries: previousSevenDailySummaries + [weekSummary, monthSummary],
            memorySnapshots: [],
            longFormReports: []
        )
    )
    let conversationService = RecordingAIConversationService()
    let preferences = UserPreferences(storage: .inMemory)
    preferences.selectedRange = .today
    preferences.aiAnalysisEnabled = true
    preferences.aiBaseURL = "https://example.com/v1"
    preferences.aiModel = "gpt-5-mini"
    let model = AppModel(
        service: ConversationStubCalendarAccessService(
            state: .authorized,
            calendars: [
                CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
            ],
            events: [
                CalendarEventRecord(
                    id: "1",
                    title: "深度工作",
                    calendarID: "work",
                    startDate: todayStart,
                    endDate: todayStart.addingTimeInterval(3_600),
                    isAllDay: false
                ),
            ]
        ),
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: archiveStore,
        calendar: calendar,
        now: { fixedNow }
    )

    await model.refresh()
    await model.startAIConversation()
    await model.finishAIConversation()

    let compacted = conversationService.compactedSummaries.first ?? []
    #expect(compacted.count == 7)
    #expect(compacted.allSatisfy { $0.range == .today })
    #expect(compacted.contains(where: { $0.headline == "历史日复盘-1" }))
    #expect(compacted.contains(where: { $0.headline == "历史日复盘-6" }))
    #expect(compacted.contains(where: { $0.headline == "历史日复盘-7" }) == false)
}

@MainActor
private func makeConversationModel(
    calendar: Calendar,
    now: Date,
    archiveStore: InMemoryAIConversationArchiveStore
) -> (AppModel, RecordingAIConversationService) {
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.aiBaseURL = "https://example.com/v1"
    preferences.aiModel = "gpt-5-mini"

    let conversationService = RecordingAIConversationService()

    let model = AppModel(
        service: ConversationStubCalendarAccessService(
            state: .authorized,
            calendars: [
                CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
            ],
            events: [
                CalendarEventRecord(
                    id: "1",
                    title: "深度工作",
                    calendarID: "work",
                    startDate: calendar.startOfDay(for: now),
                    endDate: calendar.startOfDay(for: now).addingTimeInterval(3_600),
                    isAllDay: false
                ),
            ]
        ),
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: archiveStore,
        calendar: calendar,
        now: { now }
    )

    return (model, conversationService)
}

private func makeSummary(
    range: TimeRangePreset,
    startDate: Date,
    calendar: Calendar,
    headline: String,
    summary: String,
    endDateOverride: Date? = nil,
    createdAt: Date? = nil
) -> AIConversationSummary {
    let endDate: Date = endDateOverride ?? {
        switch range {
        case .today:
            return calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? startDate
        case .month:
            return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .custom:
            return startDate.addingTimeInterval(86_400)
        }
    }()

    return AIConversationSummary(
        id: UUID(),
        sessionID: UUID(),
        serviceID: AIProviderKind.openAI.builtInServiceID,
        serviceDisplayName: "OpenAI",
        provider: .openAI,
        model: "gpt-5-mini",
        range: range,
        startDate: startDate,
        endDate: endDate,
        createdAt: createdAt ?? startDate.addingTimeInterval(600),
        headline: headline,
        summary: summary,
        findings: [],
        suggestions: [],
        overviewSnapshot: AIOverviewSnapshot(
            rangeTitle: range.title,
            totalDurationText: "1小时",
            totalEventCount: 1,
            topCalendarNames: ["工作"]
        )
    )
}
