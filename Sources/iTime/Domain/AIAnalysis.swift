import Foundation

public struct AIAnalysisConfiguration: Equatable, Sendable {
    public let baseURL: String
    public let model: String
    public let apiKey: String
    public let isEnabled: Bool

    public init(
        baseURL: String,
        model: String,
        apiKey: String,
        isEnabled: Bool
    ) {
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isEnabled = isEnabled
    }

    public var isComplete: Bool {
        isEnabled && !baseURL.isEmpty && !model.isEmpty && !apiKey.isEmpty
    }

    public var chatCompletionsURL: URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        let normalizedPath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = normalizedPath + "/chat/completions"
        return components.url
    }
}

public struct AIAnalysisBucket: Equatable, Sendable {
    public let id: String
    public let name: String
    public let shareText: String
    public let durationText: String
    public let eventCount: Int

    public init(
        id: String,
        name: String,
        shareText: String,
        durationText: String,
        eventCount: Int
    ) {
        self.id = id
        self.name = name
        self.shareText = shareText
        self.durationText = durationText
        self.eventCount = eventCount
    }
}

public struct AIAnalysisRequest: Equatable, Sendable {
    public let rangeTitle: String
    public let totalDurationText: String
    public let totalEventCount: Int
    public let averageDailyDurationText: String
    public let longestDayDurationText: String
    public let topBuckets: [AIAnalysisBucket]
    public let busiestPeriodSummary: String?

    public init(
        rangeTitle: String,
        totalDurationText: String,
        totalEventCount: Int,
        averageDailyDurationText: String,
        longestDayDurationText: String,
        topBuckets: [AIAnalysisBucket],
        busiestPeriodSummary: String?
    ) {
        self.rangeTitle = rangeTitle
        self.totalDurationText = totalDurationText
        self.totalEventCount = totalEventCount
        self.averageDailyDurationText = averageDailyDurationText
        self.longestDayDurationText = longestDayDurationText
        self.topBuckets = topBuckets
        self.busiestPeriodSummary = busiestPeriodSummary
    }
}

public struct AIAnalysisResult: Equatable, Sendable {
    public let summary: String
    public let findings: [String]
    public let suggestions: [String]
    public let generatedAt: Date

    public init(
        summary: String,
        findings: [String],
        suggestions: [String],
        generatedAt: Date
    ) {
        self.summary = summary
        self.findings = findings
        self.suggestions = suggestions
        self.generatedAt = generatedAt
    }
}

public enum AIAnalysisAvailability: Equatable, Sendable {
    case disabled
    case notConfigured
    case noData

    public var message: String {
        switch self {
        case .disabled:
            "请先在设置中启用一个 AI 服务。"
        case .notConfigured:
            "请先在设置中配置 AI 服务。"
        case .noData:
            "当前范围内没有可供分析的统计数据。"
        }
    }
}

public enum AIAnalysisState: Equatable, Sendable {
    case unavailable(AIAnalysisAvailability)
    case idle
    case loading
    case loaded(AIAnalysisResult)
    case failed(String)
}

public extension TimeOverview {
    func makeAIAnalysisRequest(topBucketLimit: Int = 4) -> AIAnalysisRequest {
        let busiestBucketSummary: String?
        if
            let busiestBucket = stackedBuckets.max(by: { $0.totalDuration < $1.totalDuration }),
            busiestBucket.totalDuration > 0
        {
            let dominantCalendar = busiestBucket.segments.max(by: { $0.duration < $1.duration })?.calendarName ?? "未分类"
            busiestBucketSummary = "\(busiestBucket.label)，共 \(busiestBucket.totalDuration.formattedDuration)，其中\(dominantCalendar)占比最高。"
        } else {
            busiestBucketSummary = nil
        }

        return AIAnalysisRequest(
            rangeTitle: range.title,
            totalDurationText: totalDuration.formattedDuration,
            totalEventCount: totalEventCount,
            averageDailyDurationText: averageDailyDuration.formattedDuration,
            longestDayDurationText: longestDayDuration.formattedDuration,
            topBuckets: Array(buckets.prefix(topBucketLimit)).map {
                AIAnalysisBucket(
                    id: $0.id,
                    name: $0.name,
                    shareText: $0.shareText,
                    durationText: $0.totalDuration.formattedDuration,
                    eventCount: $0.eventCount
                )
            },
            busiestPeriodSummary: busiestBucketSummary
        )
    }
}
