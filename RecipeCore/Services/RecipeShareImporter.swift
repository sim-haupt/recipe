import Foundation
import LinkPresentation
import UniformTypeIdentifiers
import UIKit

struct ImportedSharePayload {
    var title: String
    var description: String
    var rawText: String
    var sourceURL: String?
    var imageData: Data?
    var metadata: [String: String]
}

final class RecipeShareImporter {
    func extractPayload(from extensionItems: [NSExtensionItem]) async -> ImportedSharePayload {
        var title = ""
        var description = ""
        var rawText = ""
        var sourceURL: String?
        var imageData: Data?
        var metadata: [String: String] = [:]

        for item in extensionItems {
            if let attributedContent = item.attributedContentText?.string, !attributedContent.isEmpty {
                let cleanedContent = ImportedTextSanitizer.cleanMultiline(attributedContent)
                description = append(description, with: cleanedContent)
                rawText = append(rawText, with: cleanedContent)
            }

            if let attachments = item.attachments {
                for provider in attachments {
                    if sourceURL == nil, let url = await loadURL(from: provider) {
                        sourceURL = url.absoluteString
                    }

                    if title.isEmpty, let text = await loadText(from: provider) {
                        let cleanedText = ImportedTextSanitizer.cleanMultiline(text)
                        if description.isEmpty {
                            description = cleanedText
                        } else {
                            title = inferTitle(from: cleanedText)
                        }
                        rawText = append(rawText, with: cleanedText)
                    }

                    if imageData == nil, let data = await loadImageData(from: provider) {
                        imageData = data
                    }
                }
            }
        }

        if let sharedSourceURL = sourceURL, let normalizedURL = normalizedURL(from: sharedSourceURL) {
            let remoteMetadata = await fetchRemoteMetadata(from: normalizedURL)

            if let canonicalURL = remoteMetadata?.canonicalURL {
                sourceURL = canonicalURL.absoluteString
            }

            if let remoteTitle = remoteMetadata?.bestTitle,
               (title.isEmpty || isLikelyFallbackTitle(title, for: sharedSourceURL)) {
                title = ImportedTextSanitizer.cleanInline(remoteTitle)
            }

            if let remoteDescription = remoteMetadata?.bestDescription, description.isEmpty {
                description = ImportedTextSanitizer.oneSentenceSummary(from: remoteDescription, fallback: "")
            }

            if let remoteRawText = remoteMetadata?.rawText, !remoteRawText.isEmpty {
                rawText = append(rawText, with: ImportedTextSanitizer.cleanMultiline(remoteRawText))
            }

            if imageData == nil {
                imageData = await fetchImageData(
                    provider: remoteMetadata?.linkMetadata?.imageProvider,
                    fallbackImageURL: remoteMetadata?.imageURL
                )
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

        title = ImportedTextSanitizer.cleanInline(title)
        description = ImportedTextSanitizer.preferredRecipeDescription(
            baseDescription: description,
            rawText: rawText,
            aiSummary: nil
        )
        rawText = ImportedTextSanitizer.cleanMultiline(rawText)

        return ImportedSharePayload(
            title: title,
            description: description,
            rawText: rawText,
            sourceURL: sourceURL,
            imageData: imageData,
            metadata: metadata
        )
    }

    private func inferTitle(from text: String) -> String {
        ImportedTextSanitizer.cleanMultiline(text)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)
            .description ?? "Untitled Recipe"
    }

    private func normalizedURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let directURL = URL(string: trimmed), directURL.scheme != nil {
            return directURL
        }

        return URL(string: "https://\(trimmed)")
    }

    private func isLikelyFallbackTitle(_ title: String, for sourceURL: String?) -> Bool {
        guard let sourceURL, let host = URL(string: sourceURL)?.host else {
            return title == "Untitled Recipe"
        }

        let fallbackHostTitle = host.replacingOccurrences(of: "www.", with: "").capitalized
        return title == fallbackHostTitle || title == "Untitled Recipe"
    }

    private func append(_ existing: String, with newValue: String) -> String {
        let cleanedValue = ImportedTextSanitizer.cleanMultiline(newValue)
        guard !cleanedValue.isEmpty else { return existing }
        if existing.isEmpty { return cleanedValue }
        if existing.contains(cleanedValue) { return existing }
        return existing + "\n\n" + cleanedValue
    }

    private func fetchRemoteMetadata(from url: URL) async -> RemoteMetadata? {
        async let linkMetadataTask = fetchLinkMetadata(from: url)
        async let htmlMetadataTask = fetchHTMLMetadata(from: url)

        let linkMetadata = try? await linkMetadataTask
        let htmlMetadata = try? await htmlMetadataTask

        guard linkMetadata != nil || htmlMetadata != nil else {
            return nil
        }

        return RemoteMetadata(
            canonicalURL: htmlMetadata?.canonicalURL ?? linkMetadata?.originalURL ?? linkMetadata?.url ?? url,
            title: firstNonEmpty([
                htmlMetadata?.openGraphTitle,
                htmlMetadata?.twitterTitle,
                htmlMetadata?.pageTitle,
                linkMetadata?.title
            ]),
            description: firstNonEmpty([
                htmlMetadata?.openGraphDescription,
                htmlMetadata?.twitterDescription,
                htmlMetadata?.metaDescription
            ]),
            rawText: htmlMetadata?.bodyText,
            imageURL: htmlMetadata?.imageURL,
            linkMetadata: linkMetadata
        )
    }

    private func fetchLinkMetadata(from url: URL) async throws -> LPLinkMetadata {
        try await withCheckedThrowingContinuation { continuation in
            let provider = LPMetadataProvider()
            provider.startFetchingMetadata(for: url) { metadata, error in
                if let metadata {
                    continuation.resume(returning: metadata)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
        }
    }

    private func fetchHTMLMetadata(from url: URL) async throws -> HTMLMetadata {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return RecipePageContentExtractor.extract(from: html, baseURL: url)
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
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

    private func fetchImageData(provider: NSItemProvider?, fallbackImageURL: URL?) async -> Data? {
        if let provider, let providerImageData = await loadImageData(from: provider) {
            return providerImageData
        }

        if let fallbackImageURL {
            do {
                let (data, _) = try await URLSession.shared.data(from: fallbackImageURL)
                return data
            } catch {
                return nil
            }
        }

        return nil
    }
}

private struct RemoteMetadata {
    let canonicalURL: URL
    let title: String?
    let description: String?
    let rawText: String?
    let imageURL: URL?
    let linkMetadata: LPLinkMetadata?

    var bestTitle: String? { title }
    var bestDescription: String? { description }
}

private typealias HTMLMetadata = RecipePageContent
