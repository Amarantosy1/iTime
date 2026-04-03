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
    @ObservationIgnored private var isSynchronizingAIMountState = false

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
        didSet {
            defaults.set(aiAnalysisEnabled, forKey: Keys.aiAnalysisEnabled)
            synchronizeOpenAIMountFromLegacyValues()
        }
    }

    public var defaultAIProvider: AIProviderKind {
        didSet {
            defaults.set(defaultAIProvider.rawValue, forKey: Keys.defaultAIProvider)
            guard !isSynchronizingAIMountState else { return }
            setDefaultAIMountID(defaultAIProvider.builtInMountID)
        }
    }

    public var aiBaseURL: String {
        didSet {
            defaults.set(aiBaseURL, forKey: Keys.aiBaseURL)
            defaults.set(aiBaseURL, forKey: Keys.providerBaseURL(.openAI))
            synchronizeOpenAIMountFromLegacyValues()
        }
    }

    public var aiModel: String {
        didSet {
            defaults.set(aiModel, forKey: Keys.aiModel)
            defaults.set(aiModel, forKey: Keys.providerModel(.openAI))
            synchronizeOpenAIMountFromLegacyValues()
        }
    }

    public private(set) var aiProviderMounts: [AIProviderMount] {
        didSet {
            persistAIMounts()
        }
    }

    public private(set) var defaultAIMountID: UUID? {
        didSet {
            defaults.set(defaultAIMountID?.uuidString.lowercased(), forKey: Keys.defaultAIMountID)
            synchronizeLegacyProviderFromDefaultMount()
        }
    }

    public var defaultAIMount: AIProviderMount? {
        let mounts = Self.normalizedBuiltInMounts(aiProviderMounts)
        if let defaultAIMountID {
            return mounts.first(where: { $0.id == defaultAIMountID }) ?? mounts.first
        }
        return mounts.first
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

        self.aiAnalysisEnabled = defaults.object(forKey: Keys.aiAnalysisEnabled) as? Bool ?? false
        self.defaultAIProvider = AIProviderKind(rawValue: defaults.string(forKey: Keys.defaultAIProvider) ?? "") ?? .openAI
        self.aiBaseURL = defaults.string(forKey: Keys.aiBaseURL) ?? AIProviderKind.openAI.defaultBaseURL
        self.aiModel = defaults.string(forKey: Keys.aiModel) ?? ""

        let decodedMounts = Self.decodeAIMounts(from: defaults)
        let startingMounts = decodedMounts.isEmpty ? Self.legacyBuiltInMounts(from: defaults) : decodedMounts
        self.aiProviderMounts = Self.normalizedBuiltInMounts(startingMounts)

        if let storedMountIDString = defaults.string(forKey: Keys.defaultAIMountID),
           let storedMountID = UUID(uuidString: storedMountIDString) {
            self.defaultAIMountID = storedMountID
        } else {
            self.defaultAIMountID = self.aiProviderMounts.first(where: { $0.providerType == self.defaultAIProvider })?.id
                ?? self.aiProviderMounts.first?.id
        }

        persistAIMounts()
        synchronizeLegacyProviderFromDefaultMount()
    }

    public func replaceSelectedCalendars(with ids: [String]) {
        selectedCalendarIDs = ids
    }

    public func aiProviderConfiguration(for provider: AIProviderKind) -> AIProviderConfiguration {
        let mount = aiProviderMounts.first(where: { $0.providerType == provider && $0.isBuiltIn })
            ?? aiProviderMounts.first(where: { $0.providerType == provider })
            ?? AIProviderMount.builtIn(providerType: provider)

        return AIProviderConfiguration(
            provider: provider,
            baseURL: mount.baseURL,
            model: mount.defaultModel,
            isEnabled: mount.isEnabled
        )
    }

    public func setAIProviderEnabled(_ isEnabled: Bool, for provider: AIProviderKind) {
        defaults.set(isEnabled, forKey: Keys.providerEnabled(provider))
        updateBuiltInMount(for: provider) { $0.updating(isEnabled: isEnabled) }
        if provider == .openAI {
            aiAnalysisEnabled = isEnabled
        }
    }

    public func setAIProviderBaseURL(_ baseURL: String, for provider: AIProviderKind) {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(trimmed, forKey: Keys.providerBaseURL(provider))
        updateBuiltInMount(for: provider) { $0.updating(baseURL: trimmed) }
        if provider == .openAI {
            aiBaseURL = trimmed
        }
    }

    public func setAIProviderModel(_ model: String, for provider: AIProviderKind) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(trimmed, forKey: Keys.providerModel(provider))
        updateBuiltInMount(for: provider) {
            $0.updating(
                models: trimmed.isEmpty ? [] : [trimmed],
                defaultModel: trimmed
            )
        }
        if provider == .openAI {
            aiModel = trimmed
        }
    }

    public func saveAIMount(_ mount: AIProviderMount) {
        var mounts = aiProviderMounts.filter { $0.id != mount.id }
        mounts.append(mount)
        aiProviderMounts = Self.normalizedBuiltInMounts(mounts)

        if defaultAIMountID == nil {
            defaultAIMountID = mount.id
        }
    }

    public func deleteAIMount(id: UUID) {
        let deletingDefault = defaultAIMountID == id
        aiProviderMounts = Self.normalizedBuiltInMounts(
            aiProviderMounts.filter { mount in
                mount.isBuiltIn || mount.id != id
            }
        )

        if deletingDefault || defaultAIMountID == id {
            defaultAIMountID = aiProviderMounts.first?.id
        }
    }

    public func setDefaultAIMountID(_ id: UUID?) {
        if let id, aiProviderMounts.contains(where: { $0.id == id }) {
            defaultAIMountID = id
        } else {
            defaultAIMountID = aiProviderMounts.first?.id
        }
    }

    private static func decodeAIMounts(from defaults: UserDefaults) -> [AIProviderMount] {
        guard
            let data = defaults.data(forKey: Keys.aiProviderMounts),
            let mounts = try? JSONDecoder().decode([AIProviderMount].self, from: data)
        else {
            return []
        }
        return mounts
    }

    private static func legacyBuiltInMounts(from defaults: UserDefaults) -> [AIProviderMount] {
        AIProviderKind.allCases.map { provider in
            let baseURL = defaults.string(forKey: Keys.providerBaseURL(provider))
                ?? (provider == .openAI
                    ? defaults.string(forKey: Keys.aiBaseURL) ?? provider.defaultBaseURL
                    : provider.defaultBaseURL)
            let model = defaults.string(forKey: Keys.providerModel(provider))
                ?? (provider == .openAI ? defaults.string(forKey: Keys.aiModel) ?? "" : "")
            let isEnabled = defaults.object(forKey: Keys.providerEnabled(provider)) as? Bool
                ?? (provider == .openAI ? (defaults.object(forKey: Keys.aiAnalysisEnabled) as? Bool ?? false) : false)

            return AIProviderMount.builtIn(
                providerType: provider,
                baseURL: baseURL,
                models: model.isEmpty ? [] : [model],
                defaultModel: model,
                isEnabled: isEnabled
            )
        }
    }

    private static func normalizedBuiltInMounts(_ mounts: [AIProviderMount]) -> [AIProviderMount] {
        var merged = Dictionary(uniqueKeysWithValues: mounts.map { ($0.id, $0) })

        for provider in AIProviderKind.allCases {
            let builtInID = provider.builtInMountID
            if merged[builtInID] == nil {
                merged[builtInID] = AIProviderMount.builtIn(providerType: provider)
            }
        }

        let builtIns = AIProviderKind.allCases.compactMap { merged[$0.builtInMountID] }
        let customs = merged.values
            .filter { !$0.isBuiltIn }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
        return builtIns + customs
    }

    private func persistAIMounts() {
        guard let data = try? JSONEncoder().encode(aiProviderMounts) else { return }
        defaults.set(data, forKey: Keys.aiProviderMounts)
    }

    private func synchronizeLegacyProviderFromDefaultMount() {
        guard let mount = defaultAIMount else { return }
        isSynchronizingAIMountState = true
        defaultAIProvider = mount.providerType
        isSynchronizingAIMountState = false
    }

    private func synchronizeOpenAIMountFromLegacyValues() {
        guard !isSynchronizingAIMountState else { return }
        updateBuiltInMount(for: .openAI) {
            $0.updating(
                baseURL: aiBaseURL,
                models: aiModel.isEmpty ? [] : [aiModel],
                defaultModel: aiModel,
                isEnabled: aiAnalysisEnabled
            )
        }
    }

    private func updateBuiltInMount(
        for provider: AIProviderKind,
        transform: (AIProviderMount) -> AIProviderMount
    ) {
        let current = aiProviderMounts.first(where: { $0.id == provider.builtInMountID })
            ?? AIProviderMount.builtIn(providerType: provider)
        saveAIMount(transform(current))
    }
}
