import Foundation
import Observation

@MainActor
@Observable
public final class AppModel {
    public private(set) var authorizationState: CalendarAuthorizationState
    public private(set) var availableCalendars: [CalendarSource]
    public private(set) var availableAIServices: [AIServiceEndpoint]
    public private(set) var overview: TimeOverview?
    public private(set) var aiAnalysisState: AIAnalysisState
    public private(set) var aiConversationState: AIConversationState
    public private(set) var aiConversationHistory: [AIConversationSummary]
    public private(set) var latestAIMemorySnapshot: AIMemorySnapshot?
    public private(set) var aiServiceConnectionStates: [UUID: AIServiceConnectionState]
    public private(set) var selectedConversationServiceID: UUID?
    public private(set) var selectedConversationModel: String

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
    private var aiConversationOperationID: UUID

    public init(
        service: CalendarAccessServing,
        preferences: UserPreferences,
        aiService: AIAnalysisServing = OpenAICompatibleAIAnalysisService(),
        aiConversationService: AIConversationServing = AIConversationRoutingService(
            services: [
                .openAI: OpenAIConversationService(),
                .anthropic: AnthropicConversationService(),
                .gemini: GeminiConversationService(),
                .deepSeek: DeepSeekConversationService(),
                .openAICompatible: OpenAIConversationService(),
            ]
        ),
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
        self.availableAIServices = preferences.aiServiceEndpoints
        self.aiAnalysisState = .unavailable(.noData)
        self.aiConversationState = .unavailable(.noData)
        self.aiConversationHistory = archive.summaries.sorted(by: { $0.createdAt > $1.createdAt })
        self.latestAIMemorySnapshot = archive.memorySnapshots.max(by: { $0.createdAt < $1.createdAt })
        self.aiServiceConnectionStates = [:]
        self.selectedConversationServiceID = preferences.defaultAIServiceID ?? preferences.defaultAIService?.id
        self.selectedConversationModel = ""
        self.currentEvents = []
        self.aiConversationArchive = archive
        self.aiConversationOperationID = UUID()
        synchronizeConversationSelection()
    }

    public var liveSelectedRange: TimeRangePreset {
        preferences.selectedRange.isRuntimeSelectable ? preferences.selectedRange : .today
    }

    public var latestAIConversationSummary: AIConversationSummary? {
        aiConversationHistory.first
    }

    public var defaultAIServiceID: UUID? {
        preferences.defaultAIServiceID
    }

    public var currentConversationSession: AIConversationSession? {
        switch aiConversationState {
        case .responding(let session), .waitingForUser(let session), .summarizing(let session):
            return session
        case .unavailable, .idle, .asking, .completed, .failed:
            return nil
        }
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
        availableAIServices = preferences.aiServiceEndpoints
        synchronizeConversationSelection()

        guard authorizationState == .authorized else {
            availableCalendars = []
            overview = nil
            currentEvents = []
            invalidateAIConversationOperations()
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
        invalidateAIConversationOperations()
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
        let configuration = currentAIConversationConfiguration()
        guard configuration.isEnabled else {
            aiConversationState = .unavailable(.disabled)
            return
        }
        guard configuration.isComplete else {
            aiConversationState = .unavailable(.notConfigured)
            return
        }
        let selectedService = currentSelectedAIService()
        let operationID = UUID()
        aiConversationOperationID = operationID

        aiConversationState = .asking

        do {
            let assistantMessage = try await aiConversationService.askQuestion(
                context: context,
                history: [],
                configuration: configuration
            )
            guard aiConversationOperationID == operationID else { return }
            let session = AIConversationSession(
                id: UUID(),
                serviceID: selectedService?.id,
                serviceDisplayName: selectedService?.displayName ?? configuration.provider.title,
                provider: configuration.provider,
                model: configuration.model,
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
        let configuration = resolvedAIConversationConfiguration(
            serviceID: session.serviceID,
            provider: session.provider,
            model: session.model
        )
        guard configuration.isEnabled, configuration.isComplete else { return }
        let operationID = UUID()
        aiConversationOperationID = operationID

        let userMessage = AIConversationMessage(
            id: UUID(),
            role: .user,
            content: trimmedContent,
            createdAt: now()
        )
        let historyWithReply = session.messages + [userMessage]
        let respondingSession = AIConversationSession(
            id: session.id,
            serviceID: session.serviceID,
            serviceDisplayName: session.serviceDisplayName,
            provider: session.provider,
            model: session.model,
            range: session.range,
            startDate: session.startDate,
            endDate: session.endDate,
            startedAt: session.startedAt,
            completedAt: nil,
            status: .inProgress,
            overviewSnapshot: session.overviewSnapshot,
            messages: historyWithReply
        )
        aiConversationState = .responding(respondingSession)
        try? saveConversationArchive(upserting: respondingSession)

        do {
            let assistantMessage = try await aiConversationService.askQuestion(
                context: context,
                history: historyWithReply,
                configuration: configuration
            )
            guard aiConversationOperationID == operationID else { return }
            let updatedSession = AIConversationSession(
                id: session.id,
                serviceID: session.serviceID,
                serviceDisplayName: session.serviceDisplayName,
                provider: session.provider,
                model: session.model,
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
        let configuration = resolvedAIConversationConfiguration(
            serviceID: session.serviceID,
            provider: session.provider,
            model: session.model
        )
        guard configuration.isEnabled, configuration.isComplete else { return }
        let operationID = UUID()
        aiConversationOperationID = operationID

        aiConversationState = .summarizing(session)

        do {
            let draft = try await aiConversationService.summarizeConversation(
                context: context,
                history: session.messages,
                configuration: configuration
            )
            guard aiConversationOperationID == operationID else { return }
            let completedAt = now()
            let completedSession = AIConversationSession(
                id: session.id,
                serviceID: session.serviceID,
                serviceDisplayName: session.serviceDisplayName,
                provider: session.provider,
                model: session.model,
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
                serviceID: session.serviceID,
                serviceDisplayName: session.serviceDisplayName,
                provider: session.provider,
                model: session.model,
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
        resetAIConversationStateIfSafe()
    }

    public func updateDefaultAIProvider(_ provider: AIProviderKind) {
        preferences.defaultAIProvider = provider
        availableAIServices = preferences.aiServiceEndpoints
        synchronizeConversationSelection()
        resetAIAnalysisState()
        resetAIConversationStateIfSafe()
    }

    public func aiProviderConfiguration(for provider: AIProviderKind) -> AIProviderConfiguration {
        preferences.aiProviderConfiguration(for: provider)
    }

    public func updateAIProviderEnabled(_ isEnabled: Bool, for provider: AIProviderKind) {
        preferences.setAIProviderEnabled(isEnabled, for: provider)
        availableAIServices = preferences.aiServiceEndpoints
        synchronizeConversationSelection()
        resetAIAnalysisState()
        resetAIConversationStateIfSafe()
    }

    public func updateAIProviderBaseURL(_ baseURL: String, for provider: AIProviderKind) {
        preferences.setAIProviderBaseURL(baseURL, for: provider)
        availableAIServices = preferences.aiServiceEndpoints
        synchronizeConversationSelection()
        resetAIAnalysisState()
        resetAIConversationStateIfSafe()
    }

    public func updateAIProviderModel(_ model: String, for provider: AIProviderKind) {
        preferences.setAIProviderModel(model, for: provider)
        availableAIServices = preferences.aiServiceEndpoints
        synchronizeConversationSelection()
        resetAIAnalysisState()
        resetAIConversationStateIfSafe()
    }

    public func updateAIBaseURL(_ baseURL: String) {
        preferences.aiBaseURL = baseURL
        availableAIServices = preferences.aiServiceEndpoints
        synchronizeConversationSelection()
        resetAIAnalysisState()
        resetAIConversationStateIfSafe()
    }

    public func updateAIModel(_ model: String) {
        preferences.aiModel = model
        availableAIServices = preferences.aiServiceEndpoints
        synchronizeConversationSelection()
        resetAIAnalysisState()
        resetAIConversationStateIfSafe()
    }

    public func loadAIAPIKey() -> String {
        loadAIAPIKey(for: .openAI)
    }

    public func loadAIAPIKey(for provider: AIProviderKind) -> String {
        (try? aiKeyStore.loadAPIKey(for: provider)) ?? ""
    }

    public func updateAIAPIKey(_ apiKey: String) {
        updateAIAPIKey(apiKey, for: .openAI)
    }

    public func updateAIAPIKey(_ apiKey: String, for provider: AIProviderKind) {
        try? aiKeyStore.saveAPIKey(apiKey, for: provider)
        resetAIAnalysisState()
        resetAIConversationStateIfSafe()
    }

    public func loadAIAPIKey(for serviceID: UUID) -> String {
        (try? aiKeyStore.loadAPIKey(for: serviceID)) ?? ""
    }

    public func updateAIAPIKey(_ apiKey: String, for serviceID: UUID) {
        try? aiKeyStore.saveAPIKey(apiKey, for: serviceID)
        aiServiceConnectionStates[serviceID] = .idle
        resetAIConversationStateIfSafe()
    }

    public func selectConversationService(id: UUID) {
        guard availableAIServices.contains(where: { $0.id == id }) else { return }
        selectedConversationServiceID = id
        synchronizeConversationSelection(preserveSelectedModel: false)
        resetAIConversationStateIfSafe()
    }

    public func selectConversationModel(_ model: String) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedConversationModel = trimmed
        resetAIConversationStateIfSafe()
    }

    @discardableResult
    public func createCustomAIService() -> UUID {
        let service = AIServiceEndpoint.customOpenAICompatible(
            displayName: "自定义服务",
            baseURL: "",
            models: [],
            defaultModel: "",
            isEnabled: false
        )
        preferences.saveAIService(service)
        availableAIServices = preferences.aiServiceEndpoints
        selectedConversationServiceID = service.id
        synchronizeConversationSelection(preserveSelectedModel: false)
        resetAIConversationStateIfSafe()
        return service.id
    }

    public func updateAIService(_ service: AIServiceEndpoint) {
        preferences.saveAIService(service)
        availableAIServices = preferences.aiServiceEndpoints
        synchronizeConversationSelection()
        aiServiceConnectionStates[service.id] = .idle
        resetAIConversationStateIfSafe()
    }

    public func deleteAIService(id: UUID) {
        preferences.deleteAIService(id: id)
        availableAIServices = preferences.aiServiceEndpoints
        aiServiceConnectionStates[id] = nil
        synchronizeConversationSelection()
        resetAIConversationStateIfSafe()
    }

    public func setDefaultAIService(id: UUID) {
        preferences.setDefaultAIServiceID(id)
        availableAIServices = preferences.aiServiceEndpoints
        synchronizeConversationSelection()
        resetAIConversationStateIfSafe()
    }

    public func aiServiceConnectionState(for serviceID: UUID) -> AIServiceConnectionState {
        aiServiceConnectionStates[serviceID] ?? .idle
    }

    public func testAIServiceConnection(_ serviceID: UUID) async {
        guard let service = availableAIServices.first(where: { $0.id == serviceID }) else { return }
        let configuration = resolvedAIConversationConfiguration(
            serviceID: service.id,
            provider: service.providerKind,
            model: service.defaultModel
        )
        guard configuration.isComplete else {
            aiServiceConnectionStates[serviceID] = .failed("请先补全 Base URL、模型和 API Key。")
            return
        }

        aiServiceConnectionStates[serviceID] = .testing
        do {
            try await aiConversationService.validateConnection(configuration: configuration)
            aiServiceConnectionStates[serviceID] = .succeeded("连接成功")
        } catch let error as AIAnalysisServiceError {
            aiServiceConnectionStates[serviceID] = .failed(error.userMessage)
        } catch {
            aiServiceConnectionStates[serviceID] = .failed("连接失败，请检查配置。")
        }
    }

    public func deleteAIConversationSummary(id: UUID) {
        let removedSummaries = aiConversationArchive.summaries.filter { $0.id == id }
        guard !removedSummaries.isEmpty else { return }

        let removedSummaryIDs = Set(removedSummaries.map(\.id))
        let removedSessionIDs = Set(removedSummaries.map(\.sessionID))
        let updatedArchive = AIConversationArchive(
            sessions: aiConversationArchive.sessions.filter { !removedSessionIDs.contains($0.id) },
            summaries: aiConversationArchive.summaries.filter { !removedSummaryIDs.contains($0.id) },
            memorySnapshots: aiConversationArchive.memorySnapshots.filter { snapshot in
                removedSummaryIDs.isDisjoint(with: snapshot.sourceSummaryIDs)
            }
        )

        try? persistConversationArchive(updatedArchive)
        if case .completed(let summary) = aiConversationState, removedSummaryIDs.contains(summary.id) {
            resetAIConversationState()
        }
    }

    public func updateAIConversationSummary(
        id: UUID,
        headline: String,
        summary: String,
        findings: [String],
        suggestions: [String]
    ) {
        guard let existingSummary = aiConversationArchive.summaries.first(where: { $0.id == id }) else { return }

        let updatedSummary = existingSummary.updating(
            headline: headline.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            findings: findings.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            suggestions: suggestions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        )

        let updatedArchive = AIConversationArchive(
            sessions: aiConversationArchive.sessions,
            summaries: aiConversationArchive.summaries
                .map { $0.id == id ? updatedSummary : $0 }
                .sorted(by: { $0.createdAt > $1.createdAt }),
            memorySnapshots: aiConversationArchive.memorySnapshots
        )

        try? persistConversationArchive(updatedArchive)
        if case .completed(let currentSummary) = aiConversationState, currentSummary.id == id {
            aiConversationState = .completed(updatedSummary)
        }
    }

    public func discardCurrentAIConversation() {
        invalidateAIConversationOperations()
        let removableSessionID: UUID?
        switch aiConversationState {
        case .responding(let session), .waitingForUser(let session), .summarizing(let session):
            removableSessionID = session.id
        case .unavailable, .idle, .asking, .completed, .failed:
            removableSessionID = nil
        }

        if let removableSessionID {
            let updatedArchive = AIConversationArchive(
                sessions: aiConversationArchive.sessions.filter { $0.id != removableSessionID },
                summaries: aiConversationArchive.summaries,
                memorySnapshots: aiConversationArchive.memorySnapshots
            )
            try? persistConversationArchive(updatedArchive)
        }

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

    private func currentAIConversationConfiguration() -> ResolvedAIProviderConfiguration {
        guard let service = currentSelectedAIService() else {
            return ResolvedAIProviderConfiguration(
                provider: preferences.defaultAIProvider,
                baseURL: "",
                model: "",
                apiKey: "",
                isEnabled: false
            )
        }
        return resolvedAIConversationConfiguration(
            serviceID: service.id,
            provider: service.providerKind,
            model: selectedConversationModel
        )
    }

    private func resolvedAIConversationConfiguration(for provider: AIProviderKind) -> ResolvedAIProviderConfiguration {
        let configuration = preferences.aiProviderConfiguration(for: provider)
        return ResolvedAIProviderConfiguration(
            provider: provider,
            baseURL: configuration.baseURL,
            model: configuration.model,
            apiKey: (try? aiKeyStore.loadAPIKey(for: provider)) ?? "",
            isEnabled: configuration.isEnabled
        )
    }

    private func resolvedAIConversationConfiguration(
        serviceID: UUID?,
        provider: AIProviderKind,
        model: String
    ) -> ResolvedAIProviderConfiguration {
        if let serviceID, let service = availableAIServices.first(where: { $0.id == serviceID }) {
            let resolvedModel = resolvedModel(for: service, selectedModel: model)
            return ResolvedAIProviderConfiguration(
                provider: service.providerKind,
                baseURL: service.baseURL,
                model: resolvedModel,
                apiKey: (try? aiKeyStore.loadAPIKey(for: service.id)) ?? "",
                isEnabled: service.isEnabled
            )
        }

        let configuration = preferences.aiProviderConfiguration(for: provider)
        let resolvedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? configuration.model
            : model.trimmingCharacters(in: .whitespacesAndNewlines)
        return ResolvedAIProviderConfiguration(
            provider: provider,
            baseURL: configuration.baseURL,
            model: resolvedModel,
            apiKey: (try? aiKeyStore.loadAPIKey(for: provider)) ?? "",
            isEnabled: configuration.isEnabled
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

        let configuration = currentAIConversationConfiguration()
        if !configuration.isEnabled {
            aiConversationState = .unavailable(.disabled)
        } else if !configuration.isComplete {
            aiConversationState = .unavailable(.notConfigured)
        } else {
            aiConversationState = .idle
        }
    }

    private func resetAIConversationStateIfSafe() {
        switch aiConversationState {
        case .asking, .responding, .waitingForUser, .summarizing:
            return
        case .unavailable, .idle, .completed, .failed:
            resetAIConversationState()
        }
    }

    private func currentAIConversationContext() -> AIConversationContext? {
        guard let overview, !overview.buckets.isEmpty else {
            aiConversationState = .unavailable(.noData)
            return nil
        }

        return overview.makeAIConversationContext(
            events: currentEvents,
            calendarLookup: Dictionary(uniqueKeysWithValues: availableCalendars.map { ($0.id, $0) }),
            latestMemorySummary: latestAIMemorySnapshot?.summary
        )
    }

    private func currentSelectedAIService() -> AIServiceEndpoint? {
        let services = availableAIServices
        if let selectedConversationServiceID, let service = services.first(where: { $0.id == selectedConversationServiceID }) {
            return service
        }
        if let defaultService = preferences.defaultAIService {
            return defaultService
        }
        return services.first
    }

    private func synchronizeConversationSelection(preserveSelectedModel: Bool = true) {
        let services = availableAIServices
        guard !services.isEmpty else {
            selectedConversationServiceID = nil
            selectedConversationModel = ""
            return
        }

        let resolvedService = currentSelectedAIService() ?? services[0]
        selectedConversationServiceID = resolvedService.id
        let resolvedModel = resolvedModel(
            for: resolvedService,
            selectedModel: preserveSelectedModel ? selectedConversationModel : nil
        )
        selectedConversationModel = resolvedModel
    }

    private func resolvedModel(for service: AIServiceEndpoint, selectedModel: String?) -> String {
        let preferredModel = selectedModel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !preferredModel.isEmpty && service.models.contains(preferredModel) {
            return preferredModel
        }
        if !service.defaultModel.isEmpty {
            return service.defaultModel
        }
        return service.models.first ?? ""
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
        try persistConversationArchive(updatedArchive)
    }

    private func persistConversationArchive(_ updatedArchive: AIConversationArchive) throws {
        try aiConversationArchiveStore.saveArchive(updatedArchive)
        aiConversationArchive = updatedArchive
        aiConversationHistory = updatedArchive.summaries
        latestAIMemorySnapshot = updatedArchive.memorySnapshots.max(by: { $0.createdAt < $1.createdAt })
    }

    private func invalidateAIConversationOperations() {
        aiConversationOperationID = UUID()
    }
}
