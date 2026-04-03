import Foundation

public struct FileAIConversationArchiveStore {
    private let directoryURL: URL
    private let fileManager: FileManager
    private let fileName: String

    public init(directoryURL: URL) {
        self.init(
            directoryURL: directoryURL,
            fileManager: .default,
            fileName: "AIConversationArchive.json"
        )
    }

    init(
        directoryURL: URL,
        fileManager: FileManager,
        fileName: String
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        self.fileName = fileName
    }

    public func loadArchive() throws -> AIConversationArchive {
        let fileURL = archiveFileURL
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .empty
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(AIConversationArchive.self, from: data)
    }

    public func saveArchive(_ archive: AIConversationArchive) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(archive)
        try data.write(to: archiveFileURL, options: .atomic)
    }

    private var archiveFileURL: URL {
        directoryURL.appendingPathComponent(fileName, isDirectory: false)
    }
}
