import FirebaseStorage
import Foundation

extension StorageReference {
    func putDataAwaitingResult(_ uploadData: Data) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { continuation in
            putData(uploadData, metadata: nil) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: NSError(domain: "WeCookin", code: -1, userInfo: [NSLocalizedDescriptionKey: "Image upload finished without metadata."]))
                }
            }
        }
    }

    func downloadURLAwaitingResult() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            downloadURL { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: NSError(domain: "WeCookin", code: -2, userInfo: [NSLocalizedDescriptionKey: "Image upload finished without a download URL."]))
                }
            }
        }
    }
}
