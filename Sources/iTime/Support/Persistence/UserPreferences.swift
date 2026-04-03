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
        static let aiAnalysisEnabled = "aiAnalysisEnabled"
        static let defaultAIProvider = "defaultAIProvider"
        static let aiBaseURL = "aiBaseURL"
        static let aiModel = "aiModel"

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

    public var aiAnalysisEnabled: Bool {
        didSet { defaults.set(aiAnalysisEnabled, forKey: Keys.aiAnalysisEnabled) }
    }

    public var defaultAIProvider: AIProviderKind {
        didSet { defaults.set(defaultAIProvider.rawValue, forKey: Keys.defaultAIProvider) }
    }

    public var aiBaseURL: String {
        didSet {
            defaults.set(aiBaseURL, forKey: Keys.aiBaseURL)
            defaults.set(aiBaseURL, forKey: Keys.providerBaseURL(.openAI))
        }
    }

    public var aiModel: String {
        didSet {
            defaults.set(aiModel, forKey: Keys.aiModel)
            defaults.set(aiModel, forKey: Keys.providerModel(.openAI))
        }
    }

    public init(storage: Storage, suiteNameOverride: String? = nil) {
        switch storage {
        case .standard:
            self.defaults = .standard
        case .inMemory:
            let suiteName = suiteNameOverride ?? "iTime.tests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            Self.inMemoryLock.lock()
            defer { Self.inMemoryLock.unlock() }
            if Self.seededInMemorySuites.insert(suiteName).inserted {
                defaults.removePersistentDomain(forName: suiteName)
            }
            self.defaults = defaults
        }

        self.selectedRange = TimeRangePreset(rawValue: defaults.string(forKey: Keys.selectedRange) ?? "") ?? .today
        self.selectedCalendarIDs = defaults.stringArray(forKey: Keys.selectedCalendarIDs) ?? []
        let now = Date()
        let calendar = Calendar.current
        let todayInterval = calendar.dateInterval(of: .day, for: now) ?? DateInterval(start: now, duration: 86_400)
        self.customStartDate = defaults.object(forKey: Keys.customStartDate) as? Date ?? todayInterval.start
        self.customEndDate = defaults.object(forKey: Keys.customEndDate) as? Date ?? todayInterval.end
        self.aiAnalysisEnabled = defaults.object(forKey: Keys.aiAnalysisEnabled) as? Bool ?? false
        self.defaultAIProvider = AIProviderKind(rawValue: defaults.string(forKey: Keys.defaultAIProvider) ?? "") ?? .openAI
        self.aiBaseURL = defaults.string(forKey: Keys.aiBaseURL) ?? "https://api.openai.com/v1"
        self.aiModel = defaults.string(forKey: Keys.aiModel) ?? ""
    }

    public func replaceSelectedCalendars(with ids: [String]) {
        selectedCalendarIDs = ids
    }

    public func aiProviderConfiguration(for provider: AIProviderKind) -> AIProviderConfiguration {
        AIProviderConfiguration(
            provider: provider,
            baseURL: defaults.string(forKey: Keys.providerBaseURL(provider))
                ?? (provider == .openAI ? aiBaseURL : provider.defaultBaseURL),
            model: defaults.string(forKey: Keys.providerModel(provider))
                ?? (provider == .openAI ? aiModel : ""),
            isEnabled: defaults.object(forKey: Keys.providerEnabled(provider)) as? Bool ?? false
        )
    }

    public func setAIProviderEnabled(_ isEnabled: Bool, for provider: AIProviderKind) {
        defaults.set(isEnabled, forKey: Keys.providerEnabled(provider))
    }

    public func setAIProviderBaseURL(_ baseURL: String, for provider: AIProviderKind) {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(trimmed, forKey: Keys.providerBaseURL(provider))
        if provider == .openAI {
            aiBaseURL = trimmed
        }
    }

    public func setAIProviderModel(_ model: String, for provider: AIProviderKind) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(trimmed, forKey: Keys.providerModel(provider))
        if provider == .openAI {
            aiModel = trimmed
        }
    }
}
