import Foundation
import LinkPresentation
import UIKit

struct RecipeURLImportResult {
    let canonicalURL: String
    let title: String
    let description: String
    let rawText: String
    let imageData: Data?
}

protocol RecipeURLImportServicing {
    func fetchRecipeData(from urlString: String) async throws -> RecipeURLImportResult
}

enum RecipeURLImportError: LocalizedError {
    case invalidURL
    case unableToLoad

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "That link does not look valid."
        case .unableToLoad:
            return "Could not load recipe details from that link."
        }
    }
}

final class RecipeURLImportService: RecipeURLImportServicing {
    func fetchRecipeData(from urlString: String) async throws -> RecipeURLImportResult {
        guard let sourceURL = normalizedURL(from: urlString) else {
            throw RecipeURLImportError.invalidURL
        }

        async let htmlMetadataTask = fetchHTMLMetadata(from: sourceURL)
        let shouldLoadLinkMetadata = usesLinkPresentation(for: sourceURL)
        async let linkMetadataTask: LPLinkMetadata? = shouldLoadLinkMetadata ? (try? fetchLinkMetadata(from: sourceURL)) : nil

        let linkMetadata = await linkMetadataTask
       let htmlMetadata = try? await htmlMetadataTask

        let resolvedURL = htmlMetadata?.canonicalURL ?? linkMetadata?.originalURL ?? linkMetadata?.url ?? sourceURL
        let title = firstNonEmpty([
            htmlMetadata?.pageTitle,
            htmlMetadata?.openGraphTitle,
            htmlMetadata?.twitterTitle,
            linkMetadata?.title,
            fallbackTitle(from: resolvedURL)
        ]) ?? "Imported Recipe"
        let descriptionSource = firstNonEmpty([
            htmlMetadata?.openGraphDescription,
            htmlMetadata?.twitterDescription,
            htmlMetadata?.metaDescription
        ]) ?? ""
        let description = ImportedTextSanitizer.oneSentenceSummary(
            from: descriptionSource,
            fallback: htmlMetadata?.bodyText ?? ""
        )
        let rawText = ImportedTextSanitizer.normalizedRecipeExtractionText(from:
            firstNonEmpty([
                htmlMetadata?.bodyText,
                descriptionSource
            ]) ?? ""
        )

        let imageData = await fetchImageData(
            provider: linkMetadata?.imageProvider,
            fallbackImageURL: htmlMetadata?.imageURL
        )

        return RecipeURLImportResult(
            canonicalURL: resolvedURL.absoluteString,
            title: ImportedTextSanitizer.cleanInline(title),
            description: description,
            rawText: rawText,
            imageData: imageData
        )
    }

    private func normalizedURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let directURL = URL(string: trimmed), directURL.scheme != nil {
            return directURL
        }

        return URL(string: "https://\(trimmed)")
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
                    continuation.resume(throwing: RecipeURLImportError.unableToLoad)
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

    private func loadImageData(from provider: NSItemProvider) async -> Data? {
        if provider.canLoadObject(ofClass: UIImage.self) {
            return await withCheckedContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    guard let image = object as? UIImage else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: image.jpegData(compressionQuality: 0.9))
                }
            }
        }

        return nil
    }

    private func fallbackTitle(from url: URL) -> String {
        ImportedTextSanitizer.cleanInline(url.host?
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: ".", with: " ")
            .capitalized ?? "Imported Recipe")
    }

    private func usesLinkPresentation(for url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return true }
        let blockedHosts = [
            "instagram.com",
            "www.instagram.com",
            "m.instagram.com",
            "tiktok.com",
            "www.tiktok.com",
            "m.tiktok.com"
        ]
        return !blockedHosts.contains(host)
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }
}

private typealias HTMLMetadata = RecipePageContent
