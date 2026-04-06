import Foundation
import Testing
@testable import iTime

@Test func archiveStoreLoadsEmptyArchiveWhenNoFileExists() throws {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = FileAIConversationArchiveStore(directoryURL: directoryURL)

    let archive = try store.loadArchive()

    #expect(archive == .empty)
}

@Test func archiveStoreRoundTripsSessionsSummariesAndMemory() throws {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = FileAIConversationArchiveStore(directoryURL: directoryURL)
    let sessionID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let summaryID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let memoryID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let reportID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    let startDate = Date(timeIntervalSince1970: 1_700_000_000)
    let endDate = Date(timeIntervalSince1970: 1_700_086_400)
    let archive = AIConversationArchive(
        sessions: [
            AIConversationSession(
                id: sessionID,
                serviceID: AIProviderKind.openAI.builtInServiceID,
                serviceDisplayName: "OpenAI",
                provider: .openAI,
                model: "gpt-5-mini",
                range: .week,
                startDate: startDate,
                endDate: endDate,
                startedAt: startDate,
                completedAt: endDate,
                status: .completed,
                overviewSnapshot: AIOverviewSnapshot(
                    rangeTitle: "本周",
                    totalDurationText: "12小时",
                    totalEventCount: 8,
                    topCalendarNames: ["工作", "学习"]
                ),
                messages: [
                    AIConversationMessage(
                        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                        role: .assistant,
                        content: "周二下午的项目评审主要做了什么？",
                        createdAt: startDate
                    ),
                    AIConversationMessage(
                        id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                        role: .user,
                        content: "主要在评审需求变更。",
                        createdAt: startDate.addingTimeInterval(300)
                    ),
                ]
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
                range: .week,
                startDate: startDate,
                endDate: endDate,
                createdAt: endDate,
                headline: "本周时间分配偏向工作",
                summary: "你本周主要时间投入在工作会议和需求评审上。",
                findings: ["会议密度偏高"],
                suggestions: ["下周给深度工作留整块时间"],
                overviewSnapshot: AIOverviewSnapshot(
                    rangeTitle: "本周",
                    totalDurationText: "12小时",
                    totalEventCount: 8,
                    topCalendarNames: ["工作", "学习"]
                )
            ),
        ],
        memorySnapshots: [
            AIMemorySnapshot(
                id: memoryID,
                createdAt: endDate.addingTimeInterval(600),
                sourceSummaryIDs: [summaryID],
                summary: "最近几轮复盘都显示会议偏多，深度工作容易被切碎。"
            ),
        ],
        longFormReports: [
            AIConversationLongFormReport(
                id: reportID,
                sessionID: sessionID,
                summaryID: summaryID,
                createdAt: endDate.addingTimeInterval(900),
                updatedAt: endDate.addingTimeInterval(900),
                title: "本周时间复盘流水账",
                content: "这是一篇基于原始对话生成的流水账复盘。"
            ),
        ]
    )

    try store.saveArchive(archive)
    let loadedArchive = try store.loadArchive()

    #expect(loadedArchive == archive)
}

@Test func longFormReportDecodesWithoutFlowchartForBackwardCompatibility() throws {
    let json = """
    {
      "id": "11111111-0000-0000-0000-000000000000",
      "sessionID": "22222222-0000-0000-0000-000000000000",
      "summaryID": "33333333-0000-0000-0000-000000000000",
      "createdAt": 0,
      "updatedAt": 0,
      "title": "旧报告",
      "content": "旧内容"
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let report = try decoder.decode(AIConversationLongFormReport.self, from: Data(json.utf8))
    #expect(report.title == "旧报告")
    #expect(report.flowchart == nil)
}

@Test func longFormReportEncodesAndDecodesFlowchart() throws {
    let flowchart = AIConversationFlowchart(
        nodes: [
            FlowchartNode(id: "n1", timeRange: "09:00-09:30", title: "早会", calendarName: "工作"),
            FlowchartNode(id: "n2", timeRange: "09:30-11:00", title: "写代码", calendarName: nil),
        ],
        edges: [FlowchartEdge(from: "n1", to: "n2")]
    )
    let original = AIConversationLongFormReport(
        id: UUID(),
        sessionID: UUID(),
        summaryID: UUID(),
        createdAt: .init(timeIntervalSince1970: 0),
        updatedAt: .init(timeIntervalSince1970: 0),
        title: "标题",
        content: "内容",
        flowchart: flowchart
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    let data = try encoder.encode(original)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let decoded = try decoder.decode(AIConversationLongFormReport.self, from: data)
    #expect(decoded.flowchart == flowchart)
    #expect(decoded.flowchart?.nodes.count == 2)
    #expect(decoded.flowchart?.edges.count == 1)
}
