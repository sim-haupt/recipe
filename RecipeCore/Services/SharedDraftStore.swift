import Foundation

enum SharedDraftStoreError: Error {
    case appGroupUnavailable
    case imageWriteFailed
}

final class SharedDraftStore {
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func pendingDrafts() throws -> [RecipeDraft] {
        guard let fileURL = draftsFileURL(createIfMissing: false) else {
            return []
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([RecipeDraft].self, from: data)
    }

    func saveDraft(_ draft: RecipeDraft, imageData: Data?) throws {
        var drafts = try pendingDrafts()
        var storedDraft = draft

        if let imageData {
            storedDraft.imageFileName = try persistImageData(imageData, draftID: draft.id)
        }

        drafts.removeAll { $0.id == storedDraft.id }
        drafts.insert(storedDraft, at: 0)
        try persistDrafts(drafts)
    }

    func markImported(_ draftID: String) throws {
        var drafts = try pendingDrafts()
        guard let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        drafts[index].importedAt = Date()
        try persistDrafts(drafts)
    }

    func removeImportedDrafts() throws {
        let remaining = try pendingDrafts().filter { $0.importedAt == nil }
        try persistDrafts(remaining)
    }

    func imageData(for draft: RecipeDraft) -> Data? {
        guard let fileName = draft.imageFileName else { return nil }
        guard let imageURL = sharedImagesDirectoryURL()?.appendingPathComponent(fileName) else { return nil }
        return try? Data(contentsOf: imageURL)
    }

    private func persistDrafts(_ drafts: [RecipeDraft]) throws {
        guard let fileURL = draftsFileURL(createIfMissing: true) else {
            throw SharedDraftStoreError.appGroupUnavailable
        }

        let data = try encoder.encode(drafts)
        try data.write(to: fileURL, options: .atomic)
    }

    private func persistImageData(_ data: Data, draftID: String) throws -> String {
        guard let imagesDirectory = sharedImagesDirectoryURL(createIfMissing: true) else {
            throw SharedDraftStoreError.appGroupUnavailable
        }

        let fileName = "\(draftID).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL, options: .atomic)
            return fileName
        } catch {
            throw SharedDraftStoreError.imageWriteFailed
        }
    }

    private func draftsFileURL(createIfMissing: Bool) -> URL? {
        guard let container = baseContainerURL(createIfMissing: createIfMissing) else { return nil }

        if createIfMissing {
            try? fileManager.createDirectory(at: container, withIntermediateDirectories: true, attributes: nil)
        }

        return container.appendingPathComponent(AppConstants.pendingShareDraftsFileName)
    }

    private func sharedImagesDirectoryURL(createIfMissing: Bool = false) -> URL? {
        guard let container = baseContainerURL(createIfMissing: createIfMissing) else { return nil }

        let directory = container.appendingPathComponent(AppConstants.sharedImagesDirectoryName, isDirectory: true)
        if createIfMissing {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }

        return directory
    }

    private func baseContainerURL(createIfMissing: Bool) -> URL? {
        if let appGroupContainer = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier) {
            return appGroupContainer
        }

        guard let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let fallbackDirectory = appSupportDirectory.appendingPathComponent(AppConstants.localDraftsDirectoryName, isDirectory: true)
        if createIfMissing {
            try? fileManager.createDirectory(at: fallbackDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        return fallbackDirectory
    }
}
