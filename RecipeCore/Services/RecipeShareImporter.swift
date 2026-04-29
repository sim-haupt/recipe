import Foundation
import UniformTypeIdentifiers
import UIKit

struct ImportedSharePayload {
    var title: String
    var description: String
    var sourceURL: String?
    var imageData: Data?
    var metadata: [String: String]
}

final class RecipeShareImporter {
    func extractPayload(from extensionItems: [NSExtensionItem]) async -> ImportedSharePayload {
        var title = ""
        var description = ""
        var sourceURL: String?
        var imageData: Data?
        var metadata: [String: String] = [:]

        for item in extensionItems {
            if let attributedContent = item.attributedContentText?.string, !attributedContent.isEmpty {
                description = append(description, with: attributedContent)
            }

            if let attachments = item.attachments {
                for provider in attachments {
                    if sourceURL == nil, let url = await loadURL(from: provider) {
                        sourceURL = url.absoluteString
                    }

                    if title.isEmpty, let text = await loadText(from: provider) {
                        if description.isEmpty {
                            description = text
                        } else {
                            title = inferTitle(from: text)
                        }
                    }

                    if imageData == nil, let data = await loadImageData(from: provider) {
                        imageData = data
                    }
                }
            }
        }

        if title.isEmpty {
            if let sourceURL, let host = URL(string: sourceURL)?.host {
                title = host.replacingOccurrences(of: "www.", with: "").capitalized
            } else if !description.isEmpty {
                title = inferTitle(from: description)
            } else {
                title = "Untitled Recipe"
            }
        }

        if let sourceURL {
            metadata["sourceURL"] = sourceURL
        }

        return ImportedSharePayload(
            title: title,
            description: description,
            sourceURL: sourceURL,
            imageData: imageData,
            metadata: metadata
        )
    }

    private func inferTitle(from text: String) -> String {
        text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)
            .description ?? "Untitled Recipe"
    }

    private func append(_ existing: String, with newValue: String) -> String {
        if existing.isEmpty { return newValue }
        return existing + "\n\n" + newValue
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            return await withCheckedContinuation { continuation in
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    continuation.resume(returning: item as? URL)
                }
            }
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            return await withCheckedContinuation { continuation in
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    guard let text = item as? String else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
        }

        return nil
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                continuation.resume(returning: item as? String)
            }
        }
    }

    private func loadImageData(from provider: NSItemProvider) async -> Data? {
        if provider.canLoadObject(ofClass: UIImage.self) {
            return await withCheckedContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    guard let image = object as? UIImage else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: image.jpegData(compressionQuality: 0.85))
                }
            }
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            return await withCheckedContinuation { continuation in
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    continuation.resume(returning: data)
                }
            }
        }

        return nil
    }
}
