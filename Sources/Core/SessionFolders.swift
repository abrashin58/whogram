import Foundation

struct SessionFolders {
    let database: URL
    let files: URL

    private static func locations(for storageID: UUID, at root: URL) -> Self {
        let profile = root.appendingPathComponent(storageID.uuidString, isDirectory: true)
        return Self(database: profile.appendingPathComponent("Database", isDirectory: true),
                    files: profile.appendingPathComponent("Files", isDirectory: true))
    }

    private static func root(at support: URL?, fileManager: FileManager) throws -> URL {
        guard let base = support ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw SessionCatalogError.storage
        }
        return base.appendingPathComponent("WhogramSessions", isDirectory: true)
    }

    private func hasDatabase(fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        let binlog = database.appendingPathComponent("td.binlog")
        guard fileManager.fileExists(atPath: binlog.path, isDirectory: &isDirectory), !isDirectory.boolValue,
              let size = (try? fileManager.attributesOfItem(atPath: binlog.path)[.size]) as? NSNumber else { return false }
        return size.int64Value > 0
    }

    static func hasDatabase(storageID: UUID, applicationSupport: URL? = nil,
                            fileManager: FileManager = .default) -> Bool {
        guard let root = try? root(at: applicationSupport, fileManager: fileManager) else { return false }
        return locations(for: storageID, at: root).hasDatabase(fileManager: fileManager)
    }

    static func legacyFolders(documents: URL? = nil, fileManager: FileManager = .default) throws -> Self {
        guard let base = documents ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw SessionCatalogError.storage
        }
        let folders = locations(forLegacyRoot: base.appendingPathComponent("Whogram", isDirectory: true))
        guard folders.hasDatabase(fileManager: fileManager) else { throw SessionCatalogError.missingDatabase }
        try fileManager.createDirectory(at: folders.files, withIntermediateDirectories: true)
        return folders
    }

    static func hasLegacyDatabase(documents: URL? = nil, fileManager: FileManager = .default) -> Bool {
        guard let base = documents ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return false }
        return locations(forLegacyRoot: base.appendingPathComponent("Whogram", isDirectory: true)).hasDatabase(fileManager: fileManager)
    }

    private static func locations(forLegacyRoot profile: URL) -> Self {
        Self(database: profile.appendingPathComponent("Database", isDirectory: true),
             files: profile.appendingPathComponent("Files", isDirectory: true))
    }

    static func prepare(storageID: UUID, requiresExistingDatabase: Bool = false,
                        applicationSupport: URL? = nil, fileManager: FileManager = .default) throws -> Self {
        var root = try root(at: applicationSupport, fileManager: fileManager)
        let folders = locations(for: storageID, at: root)
        if requiresExistingDatabase && !folders.hasDatabase(fileManager: fileManager) {
            throw SessionCatalogError.missingDatabase
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        #if os(iOS)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        #endif
        for folder in [folders.database, folders.files] {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folders
    }
}
