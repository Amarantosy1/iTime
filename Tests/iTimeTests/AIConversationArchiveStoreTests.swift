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
                title: "本周时间复盘长文",
                content: "这是一篇基于原始对话生成的长文复盘。"
            ),
        ]
    )

    try store.saveArchive(archive)
    let loadedArchive = try store.loadArchive()

    #expect(loadedArchive == archive)
}
