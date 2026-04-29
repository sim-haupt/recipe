import Foundation
import LinkPresentation
import UIKit

struct RecipeURLImportResult {
    let canonicalURL: String
    let title: String
    let description: String
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

        async let linkMetadataTask = fetchLinkMetadata(from: sourceURL)
        async let htmlMetadataTask = fetchHTMLMetadata(from: sourceURL)

        let linkMetadata = try? await linkMetadataTask
        let htmlMetadata = try? await htmlMetadataTask

        let resolvedURL = htmlMetadata?.canonicalURL ?? linkMetadata?.originalURL ?? linkMetadata?.url ?? sourceURL
        let title = firstNonEmpty([
            htmlMetadata?.openGraphTitle,
            htmlMetadata?.twitterTitle,
            htmlMetadata?.pageTitle,
            linkMetadata?.title,
            fallbackTitle(from: resolvedURL)
        ]) ?? "Imported Recipe"
        let description = firstNonEmpty([
            htmlMetadata?.openGraphDescription,
            htmlMetadata?.twitterDescription,
            htmlMetadata?.metaDescription
        ]) ?? ""

        let imageData = await fetchImageData(
            provider: linkMetadata?.imageProvider,
            fallbackImageURL: htmlMetadata?.imageURL
        )

        return RecipeURLImportResult(
            canonicalURL: resolvedURL.absoluteString,
            title: title,
            description: description,
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
        return HTMLMetadata(html: html, baseURL: url)
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
        url.host?
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: ".", with: " ")
            .capitalized ?? "Imported Recipe"
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }
}

private struct HTMLMetadata {
    let pageTitle: String?
    let metaDescription: String?
    let openGraphTitle: String?
    let openGraphDescription: String?
    let twitterTitle: String?
    let twitterDescription: String?
    let canonicalURL: URL?
    let imageURL: URL?

    init(html: String, baseURL: URL) {
        pageTitle = HTMLMetadata.capture(in: html, pattern: "<title[^>]*>(.*?)</title>")
        metaDescription = HTMLMetadata.metaContent(in: html, key: "description")
        openGraphTitle = HTMLMetadata.metaContent(in: html, property: "og:title")
        openGraphDescription = HTMLMetadata.metaContent(in: html, property: "og:description")
        twitterTitle = HTMLMetadata.metaContent(in: html, key: "twitter:title")
        twitterDescription = HTMLMetadata.metaContent(in: html, key: "twitter:description")

        let canonicalValue = HTMLMetadata.capture(in: html, pattern: "<link[^>]*rel=[\"']canonical[\"'][^>]*href=[\"'](.*?)[\"'][^>]*>")
        canonicalURL = canonicalValue.flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }

        let imageValue = HTMLMetadata.metaContent(in: html, property: "og:image")
            ?? HTMLMetadata.metaContent(in: html, key: "twitter:image")
        imageURL = imageValue.flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }
    }

    private static func metaContent(in html: String, key: String? = nil, property: String? = nil) -> String? {
        if let property {
            return capture(in: html, pattern: "<meta[^>]*property=[\"']\(NSRegularExpression.escapedPattern(for: property))[\"'][^>]*content=[\"'](.*?)[\"'][^>]*>")
        }

        if let key {
            return capture(in: html, pattern: "<meta[^>]*name=[\"']\(NSRegularExpression.escapedPattern(for: key))[\"'][^>]*content=[\"'](.*?)[\"'][^>]*>")
        }

        return nil
    }

    private static func capture(in html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let captureRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        return decodeHTMLEntities(String(html[captureRange]))
    }

    private static func decodeHTMLEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
