import Foundation

public struct AIConversationArchive: Equatable, Codable, Sendable {
    public static let empty = AIConversationArchive(
        sessions: [],
        summaries: [],
        memorySnapshots: []
    )

    public let sessions: [AIConversationSession]
    public let summaries: [AIConversationSummary]
    public let memorySnapshots: [AIMemorySnapshot]

    public init(
        sessions: [AIConversationSession],
        summaries: [AIConversationSummary],
        memorySnapshots: [AIMemorySnapshot]
    ) {
        self.sessions = sessions
        self.summaries = summaries
        self.memorySnapshots = memorySnapshots
    }
}

public struct AIConversationSession: Equatable, Codable, Sendable {
    public let id: UUID
    public let mountID: UUID?
    public let mountDisplayName: String
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
        mountID: UUID?,
        mountDisplayName: String,
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
        self.mountID = mountID
        self.mountDisplayName = mountDisplayName
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
        mountID = try container.decodeIfPresent(UUID.self, forKey: .mountID)
        mountDisplayName = try container.decodeIfPresent(String.self, forKey: .mountDisplayName) ?? provider.title
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
        try container.encodeIfPresent(mountID, forKey: .mountID)
        try container.encode(mountDisplayName, forKey: .mountDisplayName)
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
    public let mountID: UUID?
    public let mountDisplayName: String
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
        mountID: UUID?,
        mountDisplayName: String,
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
        self.mountID = mountID
        self.mountDisplayName = mountDisplayName
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
        mountID = try container.decodeIfPresent(UUID.self, forKey: .mountID)
        mountDisplayName = try container.decodeIfPresent(String.self, forKey: .mountDisplayName) ?? provider.title
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
        try container.encodeIfPresent(mountID, forKey: .mountID)
        try container.encode(mountDisplayName, forKey: .mountDisplayName)
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

    private static func isSingleDay(startDate: Date, endDate: Date, calendar: Calendar) -> Bool {
        guard endDate > startDate else { return true }
        let inclusiveEndDate = endDate.addingTimeInterval(-1)
        return calendar.isDate(startDate, inSameDayAs: inclusiveEndDate)
    }

    private static func isWholeMonth(startDate: Date, endDate: Date, calendar: Calendar) -> Bool {
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
