import Foundation

struct SessionFolders {
    let database: URL
    let files: URL

    static func prepare(documents: URL? = nil, fileManager: FileManager = .default) throws -> Self {
        let documents = try documents ?? fileManager.url(for: .documentDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil, create: true)
        let base = documents.appendingPathComponent("Whogram", isDirectory: true)
        let database = base.appendingPathComponent("Database", isDirectory: true)
        let files = base.appendingPathComponent("Files", isDirectory: true)
        for folder in [database, files] {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return Self(database: database, files: files)
    }
}
