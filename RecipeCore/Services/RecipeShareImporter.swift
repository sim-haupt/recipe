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
                    metadata["types"] = appendMetadataTypes(
                        existing: metadata["types"],
                        newTypes: provider.registeredTypeIdentifiers
                    )

                    if sourceURL == nil, let url = await loadURL(from: provider) {
                        sourceURL = url.absoluteString
                    }

                    if let text = await loadText(from: provider) {
                        let cleanedText = ImportedTextSanitizer.cleanMultiline(text)
                        if description.isEmpty, !looksLikeURLOnly(cleanedText) {
                            description = cleanedText
                        }
                        if title.isEmpty, !looksLikeURLOnly(cleanedText) {
                            title = inferTitle(from: cleanedText)
                        }
                        rawText = append(rawText, with: cleanedText)

                        if sourceURL == nil, let detectedURL = firstURL(in: cleanedText) {
                            sourceURL = detectedURL.absoluteString
                        }
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
                rawText = append(rawText, with: ImportedTextSanitizer.normalizedRecipeExtractionText(from: remoteRawText))
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
        rawText = ImportedTextSanitizer.normalizedRecipeExtractionText(from: rawText)

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

    private func appendMetadataTypes(existing: String?, newTypes: [String]) -> String {
        let merged = Set((existing?.components(separatedBy: ",") ?? []) + newTypes)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
        return merged.joined(separator: ",")
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
                    if let url = item as? URL {
                        continuation.resume(returning: url)
                    } else if let text = item as? String {
                        continuation.resume(returning: URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }

        if let text = await loadText(from: provider) {
            return firstURL(in: text)
        }

        return nil
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        let candidateTypeIdentifiers: [String] = [
            UTType.plainText.identifier,
            UTType.text.identifier,
            UTType.utf8PlainText.identifier,
            UTType.html.identifier,
            "public.text",
            "public.plain-text",
            "public.utf8-plain-text"
        ]

        for typeIdentifier in candidateTypeIdentifiers where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
            if let text = await loadStringItem(from: provider, typeIdentifier: typeIdentifier) {
                let cleaned = typeIdentifier == UTType.html.identifier
                    ? ImportedTextSanitizer.cleanMultiline(htmlToText(text))
                    : ImportedTextSanitizer.cleanMultiline(text)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        if provider.canLoadObject(ofClass: NSAttributedString.self) {
            return await withCheckedContinuation { continuation in
                provider.loadObject(ofClass: NSAttributedString.self) { object, _ in
                    continuation.resume(returning: (object as? NSAttributedString)?.string)
                }
            }
        }

        return nil
    }

    private func loadStringItem(from provider: NSItemProvider, typeIdentifier: String) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                if let text = item as? String {
                    continuation.resume(returning: text)
                    return
                }

                if let attributed = item as? NSAttributedString {
                    continuation.resume(returning: attributed.string)
                    return
                }

                if let url = item as? URL {
                    continuation.resume(returning: url.absoluteString)
                    return
                }

                if let data = item as? Data, let decoded = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: decoded)
                    return
                }

                continuation.resume(returning: nil)
            }
        }
    }

    private func htmlToText(_ html: String) -> String {
        RecipePageContentExtractor
            .extract(from: html, baseURL: URL(string: "https://example.com")!)
            .bodyText ?? ""
    }

    private func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector?.firstMatch(in: text, options: [], range: range)?.url
    }

    private func looksLikeURLOnly(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return true }
        return firstURL(in: cleaned)?.absoluteString == cleaned
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
