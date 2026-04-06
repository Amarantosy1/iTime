import Foundation

public struct AIConversationArchive: Equatable, Codable, Sendable {
    public static let empty = AIConversationArchive(
        sessions: [],
        summaries: [],
        memorySnapshots: [],
        longFormReports: [],
        deletedItemIDs: []
    )

    public let sessions: [AIConversationSession]
    public let summaries: [AIConversationSummary]
    public let memorySnapshots: [AIMemorySnapshot]
    public let longFormReports: [AIConversationLongFormReport]
    public let deletedItemIDs: Set<UUID>

    public init(
        sessions: [AIConversationSession],
        summaries: [AIConversationSummary],
        memorySnapshots: [AIMemorySnapshot],
        longFormReports: [AIConversationLongFormReport],
        deletedItemIDs: Set<UUID> = []
    ) {
        self.sessions = sessions
        self.summaries = summaries
        self.memorySnapshots = memorySnapshots
        self.longFormReports = longFormReports
        self.deletedItemIDs = deletedItemIDs
    }

    private enum CodingKeys: String, CodingKey {
        case sessions
        case summaries
        case memorySnapshots
        case longFormReports
        case deletedItemIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessions = try container.decodeIfPresent([AIConversationSession].self, forKey: .sessions) ?? []
        summaries = try container.decodeIfPresent([AIConversationSummary].self, forKey: .summaries) ?? []
        memorySnapshots = try container.decodeIfPresent([AIMemorySnapshot].self, forKey: .memorySnapshots) ?? []
        longFormReports = try container.decodeIfPresent([AIConversationLongFormReport].self, forKey: .longFormReports) ?? []
        deletedItemIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .deletedItemIDs) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessions, forKey: .sessions)
        try container.encode(summaries, forKey: .summaries)
        try container.encode(memorySnapshots, forKey: .memorySnapshots)
        try container.encode(longFormReports, forKey: .longFormReports)
        try container.encode(deletedItemIDs, forKey: .deletedItemIDs)
    }
}

public struct AIConversationSession: Equatable, Codable, Sendable {
    public let id: UUID
    public let serviceID: UUID?
    public let serviceDisplayName: String
    public let provider: AIProviderKind
    public let model: String
    public let range: TimeRangePreset
    public let startDate: Date
    public let endDate: Date
    public let startedAt: Date
    public let completedAt: Date?
    public let status: AIConversationStatus
    public let overviewSnapshot: AIOverviewSnapshot
    public let messages: [AIConversationMessage]

    public init(
        id: UUID,
        serviceID: UUID?,
        serviceDisplayName: String,
        provider: AIProviderKind,
        model: String,
        range: TimeRangePreset,
        startDate: Date,
        endDate: Date,
        startedAt: Date,
        completedAt: Date?,
        status: AIConversationStatus,
        overviewSnapshot: AIOverviewSnapshot,
        messages: [AIConversationMessage]
    ) {
        self.id = id
        self.serviceID = serviceID
        self.serviceDisplayName = serviceDisplayName
        self.provider = provider
        self.model = model
        self.range = range
        self.startDate = startDate
        self.endDate = endDate
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.overviewSnapshot = overviewSnapshot
        self.messages = messages
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case serviceID
        case serviceDisplayName
        case mountID
        case mountDisplayName
        case provider
        case model
        case range
        case startDate
        case endDate
        case startedAt
        case completedAt
        case status
        case overviewSnapshot
        case messages
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        provider = try container.decodeIfPresent(AIProviderKind.self, forKey: .provider) ?? .openAI
        serviceID = try container.decodeIfPresent(UUID.self, forKey: .serviceID)
            ?? container.decodeIfPresent(UUID.self, forKey: .mountID)
        serviceDisplayName = try container.decodeIfPresent(String.self, forKey: .serviceDisplayName)
            ?? container.decodeIfPresent(String.self, forKey: .mountDisplayName)
            ?? provider.title
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        range = try container.decode(TimeRangePreset.self, forKey: .range)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        status = try container.decode(AIConversationStatus.self, forKey: .status)
        overviewSnapshot = try container.decode(AIOverviewSnapshot.self, forKey: .overviewSnapshot)
        messages = try container.decode([AIConversationMessage].self, forKey: .messages)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(serviceID, forKey: .serviceID)
        try container.encode(serviceDisplayName, forKey: .serviceDisplayName)
        try container.encode(provider, forKey: .provider)
        try container.encode(model, forKey: .model)
        try container.encode(range, forKey: .range)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(status, forKey: .status)
        try container.encode(overviewSnapshot, forKey: .overviewSnapshot)
        try container.encode(messages, forKey: .messages)
    }
}

public enum AIConversationStatus: String, Equatable, Codable, Sendable {
    case inProgress
    case completed
    case failed
}

public struct AIConversationMessage: Equatable, Codable, Sendable {
    public let id: UUID
    public let role: AIConversationMessageRole
    public let content: String
    public let createdAt: Date

    public init(
        id: UUID,
        role: AIConversationMessageRole,
        content: String,
        createdAt: Date
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

public enum AIConversationMessageRole: String, Equatable, Codable, Sendable {
    case assistant
    case user
}

public struct AIConversationSummary: Equatable, Codable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let serviceID: UUID?
    public let serviceDisplayName: String
    public let provider: AIProviderKind
    public let model: String
    public let range: TimeRangePreset
    public let startDate: Date
    public let endDate: Date
    public let createdAt: Date
    public let headline: String
    public let summary: String
    public let findings: [String]
    public let suggestions: [String]
    public let overviewSnapshot: AIOverviewSnapshot

    public init(
        id: UUID,
        sessionID: UUID,
        serviceID: UUID?,
        serviceDisplayName: String,
        provider: AIProviderKind,
        model: String,
        range: TimeRangePreset,
        startDate: Date,
        endDate: Date,
        createdAt: Date,
        headline: String,
        summary: String,
        findings: [String],
        suggestions: [String],
        overviewSnapshot: AIOverviewSnapshot
    ) {
        self.id = id
        self.sessionID = sessionID
        self.serviceID = serviceID
        self.serviceDisplayName = serviceDisplayName
        self.provider = provider
        self.model = model
        self.range = range
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.headline = headline
        self.summary = summary
        self.findings = findings
        self.suggestions = suggestions
        self.overviewSnapshot = overviewSnapshot
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sessionID
        case serviceID
        case serviceDisplayName
        case mountID
        case mountDisplayName
        case provider
        case model
        case range
        case startDate
        case endDate
        case createdAt
        case headline
        case summary
        case findings
        case suggestions
        case overviewSnapshot
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        provider = try container.decodeIfPresent(AIProviderKind.self, forKey: .provider) ?? .openAI
        serviceID = try container.decodeIfPresent(UUID.self, forKey: .serviceID)
            ?? container.decodeIfPresent(UUID.self, forKey: .mountID)
        serviceDisplayName = try container.decodeIfPresent(String.self, forKey: .serviceDisplayName)
            ?? container.decodeIfPresent(String.self, forKey: .mountDisplayName)
            ?? provider.title
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        range = try container.decode(TimeRangePreset.self, forKey: .range)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        headline = try container.decode(String.self, forKey: .headline)
        summary = try container.decode(String.self, forKey: .summary)
        findings = try container.decode([String].self, forKey: .findings)
        suggestions = try container.decode([String].self, forKey: .suggestions)
        overviewSnapshot = try container.decode(AIOverviewSnapshot.self, forKey: .overviewSnapshot)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encodeIfPresent(serviceID, forKey: .serviceID)
        try container.encode(serviceDisplayName, forKey: .serviceDisplayName)
        try container.encode(provider, forKey: .provider)
        try container.encode(model, forKey: .model)
        try container.encode(range, forKey: .range)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(headline, forKey: .headline)
        try container.encode(summary, forKey: .summary)
        try container.encode(findings, forKey: .findings)
        try container.encode(suggestions, forKey: .suggestions)
        try container.encode(overviewSnapshot, forKey: .overviewSnapshot)
    }

    public var displayPeriodText: String {
        AIConversationPeriodFormatter.displayText(
            range: range,
            startDate: startDate,
            endDate: endDate
        )
    }

    public var dynamicRangeCategory: TimeRangePreset {
        if range != .custom { return range }
        let calendar = Calendar.autoupdatingCurrent

        if AIConversationPeriodFormatter.isSingleDay(startDate: startDate, endDate: endDate, calendar: calendar) {
            return .today
        }

        if AIConversationPeriodFormatter.isWholeWeek(startDate: startDate, endDate: endDate, calendar: calendar) {
            return .week
        }

        let components = calendar.dateComponents([.month, .day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: endDate))
        if (components.month == 1 && components.day == 0) || AIConversationPeriodFormatter.isWholeMonth(startDate: startDate, endDate: endDate, calendar: calendar) {
            return .month
        }

        return .custom
    }

    public func updating(
        headline: String,
        summary: String,
        findings: [String],
        suggestions: [String]
    ) -> AIConversationSummary {
        AIConversationSummary(
            id: id,
            sessionID: sessionID,
            serviceID: serviceID,
            serviceDisplayName: serviceDisplayName,
            provider: provider,
            model: model,
            range: range,
            startDate: startDate,
            endDate: endDate,
            createdAt: createdAt,
            headline: headline,
            summary: summary,
            findings: findings,
            suggestions: suggestions,
            overviewSnapshot: overviewSnapshot
        )
    }
}

public struct AIMemorySnapshot: Equatable, Codable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let sourceSummaryIDs: [UUID]
    public let summary: String

    public init(
        id: UUID,
        createdAt: Date,
        sourceSummaryIDs: [UUID],
        summary: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceSummaryIDs = sourceSummaryIDs
        self.summary = summary
    }
}

public struct AIConversationLongFormReport: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let sessionID: UUID
    public let summaryID: UUID
    public let createdAt: Date
    public let updatedAt: Date
    public let title: String
    public let content: String

    public init(
        id: UUID,
        sessionID: UUID,
        summaryID: UUID,
        createdAt: Date,
        updatedAt: Date,
        title: String,
        content: String
    ) {
        self.id = id
        self.sessionID = sessionID
        self.summaryID = summaryID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.content = content
    }

    public func updating(title: String, content: String, updatedAt: Date) -> AIConversationLongFormReport {
        AIConversationLongFormReport(
            id: id,
            sessionID: sessionID,
            summaryID: summaryID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            title: title,
            content: content,
        )
    }
}

public struct AIOverviewSnapshot: Equatable, Codable, Sendable {
    public let rangeTitle: String
    public let totalDurationText: String
    public let totalEventCount: Int
    public let topCalendarNames: [String]

    public init(
        rangeTitle: String,
        totalDurationText: String,
        totalEventCount: Int,
        topCalendarNames: [String]
    ) {
        self.rangeTitle = rangeTitle
        self.totalDurationText = totalDurationText
        self.totalEventCount = totalEventCount
        self.topCalendarNames = topCalendarNames
    }
}

public struct AIConversationContext: Equatable, Sendable {
    public let range: TimeRangePreset
    public let rangeTitle: String
    public let startDate: Date
    public let endDate: Date
    public let overviewSnapshot: AIOverviewSnapshot
    public let events: [AIEventContext]
    public let latestMemorySummary: String?

    public init(
        range: TimeRangePreset,
        rangeTitle: String,
        startDate: Date,
        endDate: Date,
        overviewSnapshot: AIOverviewSnapshot,
        events: [AIEventContext],
        latestMemorySummary: String?
    ) {
        self.range = range
        self.rangeTitle = rangeTitle
        self.startDate = startDate
        self.endDate = endDate
        self.overviewSnapshot = overviewSnapshot
        self.events = events
        self.latestMemorySummary = latestMemorySummary
    }
}

public enum AIConversationState: Equatable, Sendable {
    case unavailable(AIAnalysisAvailability)
    case idle
    case asking
    case responding(AIConversationSession)
    case waitingForUser(AIConversationSession)
    case summarizing(AIConversationSession)
    case completed(AIConversationSummary)
    case failed(String)
}

public enum AIConversationLongFormState: Equatable, Sendable {
    case idle
    case generating(summaryID: UUID)
    case loaded(AIConversationLongFormReport)
    case failed(summaryID: UUID, message: String)
}

public enum AIConversationPeriodFormatter {
    public static func displayText(
        range: TimeRangePreset,
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = Locale(identifier: "zh_CN")
    ) -> String {
        if isSingleDay(startDate: startDate, endDate: endDate, calendar: calendar) {
            return dayFormatter(locale: locale, calendar: calendar).string(from: startDate)
        }

        if range == .month, isWholeMonth(startDate: startDate, endDate: endDate, calendar: calendar) {
            return monthFormatter(locale: locale, calendar: calendar).string(from: startDate)
        }

        let inclusiveEndDate = endDate.addingTimeInterval(-1)
        let startText = dayFormatter(locale: locale, calendar: calendar).string(from: startDate)
        let endText = dayFormatter(locale: locale, calendar: calendar).string(from: inclusiveEndDate)
        return "\(startText) - \(endText)"
    }

    public static func isSingleDay(startDate: Date, endDate: Date, calendar: Calendar) -> Bool {
        guard endDate > startDate else { return true }
        let inclusiveEndDate = endDate.addingTimeInterval(-1)
        return calendar.isDate(startDate, inSameDayAs: inclusiveEndDate)
    }

    public static func isWholeWeek(startDate: Date, endDate: Date, calendar: Calendar) -> Bool {
        guard endDate > startDate else { return false }
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: endDate))
        return components.day == 7
    }

    public static func isWholeMonth(startDate: Date, endDate: Date, calendar: Calendar) -> Bool {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: startDate)
        else {
            return false
        }

        return monthInterval.start == startDate && monthInterval.end == endDate
    }

    private static func dayFormatter(locale: Locale, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateFormat = "M月d日"
        return formatter
    }

    private static func monthFormatter(locale: Locale, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateFormat = "M月"
        return formatter
    }
}

public extension AIConversationSession {
    var displayPeriodText: String {
        AIConversationPeriodFormatter.displayText(
            range: range,
            startDate: startDate,
            endDate: endDate
        )
    }
}

public struct AIEventContext: Equatable, Sendable {
    public let id: String
    public let title: String
    public let calendarID: String
    public let calendarName: String
    public let startDate: Date
    public let endDate: Date
    public let durationText: String

    public init(
        id: String,
        title: String,
        calendarID: String,
        calendarName: String,
        startDate: Date,
        endDate: Date,
        durationText: String
    ) {
        self.id = id
        self.title = title
        self.calendarID = calendarID
        self.calendarName = calendarName
        self.startDate = startDate
        self.endDate = endDate
        self.durationText = durationText
    }
}

public extension TimeOverview {
    func makeAIOverviewSnapshot(topBucketLimit: Int = 4) -> AIOverviewSnapshot {
        AIOverviewSnapshot(
            rangeTitle: range.title,
            totalDurationText: totalDuration.formattedDuration,
            totalEventCount: totalEventCount,
            topCalendarNames: Array(buckets.prefix(topBucketLimit)).map(\.name)
        )
    }

    func makeAIConversationContext(
        events: [CalendarEventRecord],
        calendarLookup: [String: CalendarSource],
        latestMemorySummary: String?
    ) -> AIConversationContext {
        AIConversationContext(
            range: range,
            rangeTitle: range.title,
            startDate: interval.start,
            endDate: interval.end,
            overviewSnapshot: makeAIOverviewSnapshot(),
            events: events
                .filter { !$0.isAllDay }
                .sorted { lhs, rhs in
                    if lhs.startDate == rhs.startDate {
                        return lhs.id < rhs.id
                    }
                    return lhs.startDate < rhs.startDate
                }
                .map { event in
                    AIEventContext(
                        id: event.id,
                        title: event.title,
                        calendarID: event.calendarID,
                        calendarName: calendarLookup[event.calendarID]?.name ?? "未分类日历",
                        startDate: event.startDate,
                        endDate: event.endDate,
                        durationText: Self.aiConversationDurationText(for: event.endDate.timeIntervalSince(event.startDate))
                    )
                },
            latestMemorySummary: latestMemorySummary
        )
    }

    private static func aiConversationDurationText(for duration: TimeInterval) -> String {
        let totalMinutes = max(Int(duration) / 60, 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(minutes)分钟"
        }

        if minutes == 0 {
            return "\(hours)小时"
        }

        return "\(hours)小时\(minutes)分钟"
    }
}

public extension AIConversationSession {
    var effectiveUpdatedAt: Date {
        completedAt ?? messages.last?.createdAt ?? startedAt
    }
}
public extension AIConversationSummary {
    var effectiveUpdatedAt: Date {
        createdAt
    }
}
public extension AIMemorySnapshot {
    var effectiveUpdatedAt: Date {
        createdAt
    }
}
