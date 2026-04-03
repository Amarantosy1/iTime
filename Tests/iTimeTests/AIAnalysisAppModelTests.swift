import Foundation
import Testing
@testable import iTime

private struct StubAIAnalysisService: AIAnalysisServing {
    let result: AIAnalysisResult

    func analyze(
        request: AIAnalysisRequest,
        configuration: AIAnalysisConfiguration
    ) async throws -> AIAnalysisResult {
        result
    }
}

private struct LocalStubCalendarAccessService: CalendarAccessServing {
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

private final class RecordingAIAnalysisService: @unchecked Sendable, AIAnalysisServing {
    let result: AIAnalysisResult
    private(set) var requests: [AIAnalysisRequest] = []
    private(set) var configurations: [AIAnalysisConfiguration] = []

    init(result: AIAnalysisResult) {
        self.result = result
    }

    func analyze(
        request: AIAnalysisRequest,
        configuration: AIAnalysisConfiguration
    ) async throws -> AIAnalysisResult {
        requests.append(request)
        configurations.append(configuration)
        return result
    }
}

private final class InMemoryAIKeyStore: @unchecked Sendable, AIAPIKeyStoring {
    var value: String

    init(value: String = "") {
        self.value = value
    }

    func loadAPIKey() throws -> String {
        value
    }

    func saveAPIKey(_ apiKey: String) throws {
        value = apiKey
    }
}

@MainActor
@Test func analyzeOverviewLoadsAIResultWhenConfigurationIsComplete() async {
    let calendarService = LocalStubCalendarAccessService(
        state: CalendarAuthorizationState.authorized,
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
    let aiService = RecordingAIAnalysisService(
        result: AIAnalysisResult(
            summary: "本周整体聚焦不错",
            findings: ["工作时长集中"],
            suggestions: ["补一个休息块"],
            generatedAt: .init(timeIntervalSince1970: 1_000)
        )
    )
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.aiBaseURL = "https://example.com/v1"
    preferences.aiModel = "gpt-5-mini"
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiService: aiService,
        aiKeyStore: InMemoryAIKeyStore(value: "secret-key")
    )

    await model.refresh()
    await model.analyzeOverview()

    #expect(aiService.requests.count == 1)
    #expect(aiService.configurations.first?.apiKey == "secret-key")
    #expect(aiService.requests.first?.rangeTitle == "今天")
    #expect(aiService.requests.first?.topBuckets.first?.name == "工作")
    #expect(model.aiAnalysisState == AIAnalysisState.loaded(
        AIAnalysisResult(
            summary: "本周整体聚焦不错",
            findings: ["工作时长集中"],
            suggestions: ["补一个休息块"],
            generatedAt: .init(timeIntervalSince1970: 1_000)
        )
    ))
}

@MainActor
@Test func analyzeOverviewDoesNotCallAIServiceWhenConfigurationIsIncomplete() async {
    let calendarService = LocalStubCalendarAccessService(
        state: CalendarAuthorizationState.authorized,
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
    let aiService = RecordingAIAnalysisService(
        result: AIAnalysisResult(
            summary: "unused",
            findings: [],
            suggestions: [],
            generatedAt: .init(timeIntervalSince1970: 0)
        )
    )
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiService: aiService,
        aiKeyStore: InMemoryAIKeyStore(value: "")
    )

    await model.refresh()
    await model.analyzeOverview()

    #expect(aiService.requests.isEmpty)
    #expect(model.aiAnalysisState == AIAnalysisState.unavailable(.notConfigured))
}

@MainActor
@Test func refreshingOverviewClearsPreviouslyLoadedAIResult() async {
    let calendarService = LocalStubCalendarAccessService(
        state: CalendarAuthorizationState.authorized,
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
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.aiBaseURL = "https://example.com/v1"
    preferences.aiModel = "gpt-5-mini"
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiService: StubAIAnalysisService(
            result: AIAnalysisResult(
                summary: "已分析",
                findings: ["工作时长集中"],
                suggestions: ["安排休息"],
                generatedAt: .init(timeIntervalSince1970: 1_000)
            )
        ),
        aiKeyStore: InMemoryAIKeyStore(value: "secret-key")
    )

    await model.refresh()
    await model.analyzeOverview()
    await model.setRange(TimeRangePreset.week)

    #expect(model.aiAnalysisState == AIAnalysisState.idle)
}
