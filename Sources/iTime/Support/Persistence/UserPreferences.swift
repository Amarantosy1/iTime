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
        static let aiBaseURL = "aiBaseURL"
        static let aiModel = "aiModel"
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

    public var aiBaseURL: String {
        didSet { defaults.set(aiBaseURL, forKey: Keys.aiBaseURL) }
    }

    public var aiModel: String {
        didSet { defaults.set(aiModel, forKey: Keys.aiModel) }
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
        self.aiBaseURL = defaults.string(forKey: Keys.aiBaseURL) ?? "https://api.openai.com/v1"
        self.aiModel = defaults.string(forKey: Keys.aiModel) ?? ""
    }

    public func replaceSelectedCalendars(with ids: [String]) {
        selectedCalendarIDs = ids
    }
}
