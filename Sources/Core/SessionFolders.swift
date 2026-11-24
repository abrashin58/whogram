import Foundation

struct SessionFolders {
    let database: URL
    let files: URL

    static func prepare(storageID: UUID, applicationSupport: URL? = nil, fileManager: FileManager = .default) throws -> Self {
        let support = try applicationSupport ?? fileManager.url(for: .applicationSupportDirectory,
                                                                in: .userDomainMask,
                                                                appropriateFor: nil, create: true)
        var root = support.appendingPathComponent("WhogramSessions", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        #if os(iOS)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        #endif
        let profile = root.appendingPathComponent(storageID.uuidString, isDirectory: true)
        let database = profile.appendingPathComponent("Database", isDirectory: true)
        let files = profile.appendingPathComponent("Files", isDirectory: true)
        for folder in [database, files] {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return Self(database: database, files: files)
    }
}
