import Foundation

struct SessionFolders {
    let database: URL
    let files: URL

    static func prepare(storageID: UUID, requiresExistingDatabase: Bool = false,
                        applicationSupport: URL? = nil, fileManager: FileManager = .default) throws -> Self {
        let support = try applicationSupport ?? fileManager.url(for: .applicationSupportDirectory,
                                                                in: .userDomainMask,
                                                                appropriateFor: nil, create: true)
        var root = support.appendingPathComponent("WhogramSessions", isDirectory: true)
        let profile = root.appendingPathComponent(storageID.uuidString, isDirectory: true)
        let database = profile.appendingPathComponent("Database", isDirectory: true)
        let files = profile.appendingPathComponent("Files", isDirectory: true)
        if requiresExistingDatabase {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: database.path, isDirectory: &isDirectory), isDirectory.boolValue,
                  try !fileManager.contentsOfDirectory(atPath: database.path).isEmpty else {
                throw SessionCatalogError.missingDatabase
            }
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        #if os(iOS)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        #endif
        for folder in [database, files] {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return Self(database: database, files: files)
    }
}
