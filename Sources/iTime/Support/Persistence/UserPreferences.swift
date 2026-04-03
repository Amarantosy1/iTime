import Foundation
import Observation

@Observable
public final class UserPreferences {
    public enum Storage {
        case standard
        case inMemory
    }

    private enum Keys {
        static let selectedRange = "selectedRange"
        static let selectedCalendarIDs = "selectedCalendarIDs"
        static let customStartDate = "customStartDate"
        static let customEndDate = "customEndDate"
        static let reviewReminderEnabled = "reviewReminderEnabled"
        static let reviewReminderTime = "reviewReminderTime"
        static let aiAnalysisEnabled = "aiAnalysisEnabled"
        static let defaultAIProvider = "defaultAIProvider"
        static let aiBaseURL = "aiBaseURL"
        static let aiModel = "aiModel"
        static let aiServiceEndpoints = "aiServiceEndpoints"
        static let defaultAIServiceID = "defaultAIServiceID"
        static let aiProviderMounts = "aiProviderMounts"
        static let defaultAIMountID = "defaultAIMountID"

        static func providerEnabled(_ provider: AIProviderKind) -> String {
            "aiProvider.\(provider.rawValue).enabled"
        }

        static func providerBaseURL(_ provider: AIProviderKind) -> String {
            "aiProvider.\(provider.rawValue).baseURL"
        }

        static func providerModel(_ provider: AIProviderKind) -> String {
            "aiProvider.\(provider.rawValue).model"
        }
    }

    private static let inMemoryLock = NSLock()
    nonisolated(unsafe) private static var seededInMemorySuites: Set<String> = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let suiteName: String?
    @ObservationIgnored private var isSynchronizingAIServiceState = false

    public var selectedRange: TimeRangePreset {
        didSet { defaults.set(selectedRange.rawValue, forKey: Keys.selectedRange) }
    }

    public var selectedCalendarIDs: [String] {
        didSet { defaults.set(selectedCalendarIDs, forKey: Keys.selectedCalendarIDs) }
    }

    public var customStartDate: Date {
        didSet { defaults.set(customStartDate, forKey: Keys.customStartDate) }
    }

    public var customEndDate: Date {
        didSet { defaults.set(customEndDate, forKey: Keys.customEndDate) }
    }

    public var reviewReminderEnabled: Bool {
        didSet { defaults.set(reviewReminderEnabled, forKey: Keys.reviewReminderEnabled) }
    }

    public var reviewReminderTime: Date {
        didSet { defaults.set(reviewReminderTime, forKey: Keys.reviewReminderTime) }
    }

    public var aiAnalysisEnabled: Bool {
        didSet {
            defaults.set(aiAnalysisEnabled, forKey: Keys.aiAnalysisEnabled)
            synchronizeOpenAIServiceFromLegacyValues()
        }
    }

    public var defaultAIProvider: AIProviderKind {
        didSet {
            defaults.set(defaultAIProvider.rawValue, forKey: Keys.defaultAIProvider)
            guard !isSynchronizingAIServiceState else { return }
            if defaultAIProvider != .openAICompatible {
                setDefaultAIServiceID(defaultAIProvider.builtInServiceID)
            }
        }
    }

    public var aiBaseURL: String {
        didSet {
            defaults.set(aiBaseURL, forKey: Keys.aiBaseURL)
            defaults.set(aiBaseURL, forKey: Keys.providerBaseURL(.openAI))
            synchronizeOpenAIServiceFromLegacyValues()
        }
    }

    public var aiModel: String {
        didSet {
            defaults.set(aiModel, forKey: Keys.aiModel)
            defaults.set(aiModel, forKey: Keys.providerModel(.openAI))
            synchronizeOpenAIServiceFromLegacyValues()
        }
    }

    public private(set) var aiServiceEndpoints: [AIServiceEndpoint] {
        didSet {
            persistAIServiceEndpoints()
        }
    }

    public private(set) var defaultAIServiceID: UUID? {
        didSet {
            defaults.set(defaultAIServiceID?.uuidString.lowercased(), forKey: Keys.defaultAIServiceID)
            synchronizeLegacyProviderFromDefaultService()
        }
    }

    public var defaultAIService: AIServiceEndpoint? {
        let endpoints = Self.normalizedBuiltInServices(aiServiceEndpoints)
        if let defaultAIServiceID {
            return endpoints.first(where: { $0.id == defaultAIServiceID }) ?? endpoints.first
        }
        return endpoints.first
    }

    public var debugSuiteName: String? {
        suiteName
    }

    public init(storage: Storage, suiteNameOverride: String? = nil) {
        switch storage {
        case .standard:
            self.defaults = .standard
            self.suiteName = nil
        case .inMemory:
            let suiteName = suiteNameOverride ?? "iTime.tests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            Self.inMemoryLock.lock()
            defer { Self.inMemoryLock.unlock() }
            if Self.seededInMemorySuites.insert(suiteName).inserted {
                defaults.removePersistentDomain(forName: suiteName)
            }
            self.defaults = defaults
            self.suiteName = suiteName
        }

        self.selectedRange = TimeRangePreset(rawValue: defaults.string(forKey: Keys.selectedRange) ?? "") ?? .today
        self.selectedCalendarIDs = defaults.stringArray(forKey: Keys.selectedCalendarIDs) ?? []

        let now = Date()
        let calendar = Calendar.current
        let todayInterval = calendar.dateInterval(of: .day, for: now) ?? DateInterval(start: now, duration: 86_400)
        self.customStartDate = defaults.object(forKey: Keys.customStartDate) as? Date ?? todayInterval.start
        self.customEndDate = defaults.object(forKey: Keys.customEndDate) as? Date ?? todayInterval.end
        self.reviewReminderEnabled = defaults.object(forKey: Keys.reviewReminderEnabled) as? Bool ?? false
        self.reviewReminderTime = defaults.object(forKey: Keys.reviewReminderTime) as? Date
            ?? Self.defaultReviewReminderTime(calendar: calendar, referenceDate: now)

        self.aiAnalysisEnabled = defaults.object(forKey: Keys.aiAnalysisEnabled) as? Bool ?? false
        self.defaultAIProvider = AIProviderKind(rawValue: defaults.string(forKey: Keys.defaultAIProvider) ?? "") ?? .openAI
        self.aiBaseURL = defaults.string(forKey: Keys.aiBaseURL) ?? AIProviderKind.openAI.defaultBaseURL
        self.aiModel = defaults.string(forKey: Keys.aiModel) ?? ""

        let decodedServices = Self.decodeAIServiceEndpoints(from: defaults)
        let startingServices = decodedServices.isEmpty ? Self.legacyBuiltInServices(from: defaults) : decodedServices
        self.aiServiceEndpoints = Self.normalizedBuiltInServices(startingServices)

        let storedServiceIDString = defaults.string(forKey: Keys.defaultAIServiceID)
            ?? defaults.string(forKey: Keys.defaultAIMountID)
        if let storedServiceIDString,
           let storedServiceID = UUID(uuidString: storedServiceIDString) {
            self.defaultAIServiceID = storedServiceID
        } else {
            self.defaultAIServiceID = self.aiServiceEndpoints.first(where: { $0.providerKind == self.defaultAIProvider })?.id
                ?? self.aiServiceEndpoints.first?.id
        }

        persistAIServiceEndpoints()
        synchronizeLegacyProviderFromDefaultService()
    }

    private static func defaultReviewReminderTime(calendar: Calendar, referenceDate: Date) -> Date {
        let startOfDay = calendar.startOfDay(for: referenceDate)
        var components = calendar.dateComponents([.year, .month, .day], from: startOfDay)
        components.hour = 21
        components.minute = 0
        return calendar.date(from: components) ?? startOfDay.addingTimeInterval(21 * 3_600)
    }

    public func replaceSelectedCalendars(with ids: [String]) {
        selectedCalendarIDs = ids
    }

    public func aiProviderConfiguration(for provider: AIProviderKind) -> AIProviderConfiguration {
        let service = aiServiceEndpoints.first(where: { $0.providerKind == provider && $0.isBuiltIn })
            ?? aiServiceEndpoints.first(where: { $0.providerKind == provider })
            ?? AIServiceEndpoint.builtIn(providerKind: provider)

        return AIProviderConfiguration(
            provider: provider,
            baseURL: service.baseURL,
            model: service.defaultModel,
            isEnabled: service.isEnabled
        )
    }

    public func setAIProviderEnabled(_ isEnabled: Bool, for provider: AIProviderKind) {
        defaults.set(isEnabled, forKey: Keys.providerEnabled(provider))
        updateBuiltInService(for: provider) { $0.updating(isEnabled: isEnabled) }
        if provider == .openAI {
            aiAnalysisEnabled = isEnabled
        }
    }

    public func setAIProviderBaseURL(_ baseURL: String, for provider: AIProviderKind) {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(trimmed, forKey: Keys.providerBaseURL(provider))
        updateBuiltInService(for: provider) { $0.updating(baseURL: trimmed) }
        if provider == .openAI {
            aiBaseURL = trimmed
        }
    }

    public func setAIProviderModel(_ model: String, for provider: AIProviderKind) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(trimmed, forKey: Keys.providerModel(provider))
        updateBuiltInService(for: provider) {
            $0.updating(
                models: trimmed.isEmpty ? [] : [trimmed],
                defaultModel: trimmed
            )
        }
        if provider == .openAI {
            aiModel = trimmed
        }
    }

    public func saveAIService(_ service: AIServiceEndpoint) {
        var endpoints = aiServiceEndpoints.filter { $0.id != service.id }
        endpoints.append(service)
        aiServiceEndpoints = Self.normalizedBuiltInServices(endpoints)

        if defaultAIServiceID == nil {
            defaultAIServiceID = service.id
        }
    }

    public func deleteAIService(id: UUID) {
        let deletingDefault = defaultAIServiceID == id
        aiServiceEndpoints = Self.normalizedBuiltInServices(
            aiServiceEndpoints.filter { service in
                service.isBuiltIn || service.id != id
            }
        )

        if deletingDefault || defaultAIServiceID == id {
            defaultAIServiceID = aiServiceEndpoints.first?.id
        }
    }

    public func setDefaultAIServiceID(_ id: UUID?) {
        if let id, aiServiceEndpoints.contains(where: { $0.id == id }) {
            defaultAIServiceID = id
        } else {
            defaultAIServiceID = aiServiceEndpoints.first?.id
        }
    }

    private static func decodeAIServiceEndpoints(from defaults: UserDefaults) -> [AIServiceEndpoint] {
        guard
            let data = defaults.data(forKey: Keys.aiServiceEndpoints) ?? defaults.data(forKey: Keys.aiProviderMounts),
            let services = try? JSONDecoder().decode([AIServiceEndpoint].self, from: data)
        else {
            return []
        }
        return services
    }

    private static func legacyBuiltInServices(from defaults: UserDefaults) -> [AIServiceEndpoint] {
        AIProviderCatalog.builtInItems.map { item in
            let provider = item.kind
            let baseURL = defaults.string(forKey: Keys.providerBaseURL(provider))
                ?? (provider == .openAI
                    ? defaults.string(forKey: Keys.aiBaseURL) ?? provider.defaultBaseURL
                    : provider.defaultBaseURL)
            let model = defaults.string(forKey: Keys.providerModel(provider))
                ?? (provider == .openAI ? defaults.string(forKey: Keys.aiModel) ?? "" : "")
            let isEnabled = defaults.object(forKey: Keys.providerEnabled(provider)) as? Bool
                ?? (provider == .openAI ? (defaults.object(forKey: Keys.aiAnalysisEnabled) as? Bool ?? false) : false)

            return AIServiceEndpoint.builtIn(
                providerKind: provider,
                baseURL: baseURL,
                models: model.isEmpty ? [] : [model],
                defaultModel: model,
                isEnabled: isEnabled
            )
        }
    }

    private static func normalizedBuiltInServices(_ services: [AIServiceEndpoint]) -> [AIServiceEndpoint] {
        var merged = Dictionary(uniqueKeysWithValues: services.map { ($0.id, $0) })

        for item in AIProviderCatalog.builtInItems {
            let builtInID = item.kind.builtInServiceID
            if merged[builtInID] == nil {
                merged[builtInID] = AIServiceEndpoint.builtIn(providerKind: item.kind)
            }
        }

        let builtIns = AIProviderCatalog.builtInItems.compactMap { merged[$0.kind.builtInServiceID] }
        let customServices = merged.values
            .filter { !$0.isBuiltIn }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
        return builtIns + customServices
    }

    private func persistAIServiceEndpoints() {
        guard let data = try? JSONEncoder().encode(aiServiceEndpoints) else { return }
        defaults.set(data, forKey: Keys.aiServiceEndpoints)
    }

    private func synchronizeLegacyProviderFromDefaultService() {
        guard let service = defaultAIService else { return }
        isSynchronizingAIServiceState = true
        defaultAIProvider = service.providerKind
        isSynchronizingAIServiceState = false
    }

    private func synchronizeOpenAIServiceFromLegacyValues() {
        guard !isSynchronizingAIServiceState else { return }
        updateBuiltInService(for: .openAI) {
            $0.updating(
                baseURL: aiBaseURL,
                models: aiModel.isEmpty ? [] : [aiModel],
                defaultModel: aiModel,
                isEnabled: aiAnalysisEnabled
            )
        }
    }

    private func updateBuiltInService(
        for provider: AIProviderKind,
        transform: (AIServiceEndpoint) -> AIServiceEndpoint
    ) {
        let current = aiServiceEndpoints.first(where: { $0.id == provider.builtInServiceID })
            ?? AIServiceEndpoint.builtIn(providerKind: provider)
        saveAIService(transform(current))
    }
}
