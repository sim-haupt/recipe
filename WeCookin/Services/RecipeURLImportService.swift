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
        let rawText = htmlMetadata?.bodyText ?? ""

        let imageData = await fetchImageData(
            provider: linkMetadata?.imageProvider,
            fallbackImageURL: htmlMetadata?.imageURL
        )

        return RecipeURLImportResult(
            canonicalURL: resolvedURL.absoluteString,
            title: title,
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
    let bodyText: String?

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
        bodyText = HTMLMetadata.extractBodyText(from: html)
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

    private static func extractBodyText(from html: String) -> String {
        let withoutScripts = html
            .replacingOccurrences(of: "<script[\\s\\S]*?</script>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<style[\\s\\S]*?</style>", with: " ", options: .regularExpression)

        let withLineBreaks = withoutScripts
            .replacingOccurrences(of: "(?i)</(p|div|section|article|li|h1|h2|h3|h4|h5|h6|br)>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        let decoded = decodeHTMLEntities(withLineBreaks)
        let normalizedLines = decoded
            .components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return normalizedLines
            .prefix(140)
            .joined(separator: "\n")
    }
}

enum RecipeEnrichmentError: LocalizedError {
    case backendUnavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .backendUnavailable:
            return "AI recipe extraction is not configured yet."
        case .invalidResponse:
            return "The AI recipe extraction response could not be read."
        }
    }
}

final class RecipeEnrichmentService: RecipeEnrichmentServicing {
    private let session: URLSession
    private let endpointURL: URL?
    private let fallback = HeuristicRecipeEnrichmentService()

    init(session: URLSession = .shared, endpointURL: URL? = RecipeEnrichmentService.configuredEndpointURL()) {
        self.session = session
        self.endpointURL = endpointURL
    }

    func enrichRecipeContent(using request: RecipeEnrichmentRequest) async throws -> RecipeAIExtraction? {
        guard request.hasEnoughContent else { return nil }

        if let endpointURL {
            do {
                return try await fetchBackendExtraction(request: request, endpointURL: endpointURL)
            } catch {
                let fallbackExtraction = fallback.enrichRecipeContent(using: request)
                if fallbackExtraction.hasMeaningfulContent {
                    return fallbackExtraction
                }
                throw error
            }
        }

        let fallbackExtraction = fallback.enrichRecipeContent(using: request)
        return fallbackExtraction.hasMeaningfulContent ? fallbackExtraction : nil
    }

    private func fetchBackendExtraction(request: RecipeEnrichmentRequest, endpointURL: URL) async throws -> RecipeAIExtraction {
        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 25
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(BackendRecipeEnrichmentRequest(from: request))

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw RecipeEnrichmentError.backendUnavailable
        }

        let decoded = try JSONDecoder().decode(BackendRecipeEnrichmentResponse.self, from: data)
        let extraction = decoded.asExtraction
        guard extraction.hasMeaningfulContent else {
            throw RecipeEnrichmentError.invalidResponse
        }
        return extraction
    }

    private static func configuredEndpointURL() -> URL? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "RecipeEnrichmentAPIURL") as? String else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}

private final class HeuristicRecipeEnrichmentService {
    func enrichRecipeContent(using request: RecipeEnrichmentRequest) -> RecipeAIExtraction {
        let summary = request.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawLines = request.rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let ingredients = extractIngredients(from: rawLines)
        let preparationSteps = extractPreparationSteps(from: rawLines)
        let notes = extractNotes(from: rawLines, excluding: Set(ingredients + preparationSteps))

        return RecipeAIExtraction(
            summary: summary,
            ingredients: ingredients,
            preparationSteps: preparationSteps,
            notes: notes,
            confidence: inferredConfidence(summary: summary, ingredients: ingredients, preparationSteps: preparationSteps)
        )
    }

    private func extractIngredients(from lines: [String]) -> [String] {
        sectionLines(
            from: lines,
            matchingHeaders: ["ingredients", "ingredient list", "what you need"],
            untilHeaders: ["instructions", "directions", "method", "preparation", "steps", "how to make"]
        ) ?? lines
            .filter { looksLikeIngredient($0) }
            .prefix(18)
            .map { normalizeListLine($0) }
    }

    private func extractPreparationSteps(from lines: [String]) -> [String] {
        sectionLines(
            from: lines,
            matchingHeaders: ["instructions", "directions", "method", "preparation", "steps", "how to make"],
            untilHeaders: ["notes", "tips", "nutrition"]
        ) ?? lines
            .filter { looksLikePreparationStep($0) }
            .prefix(12)
            .enumerated()
            .map { _, line in normalizeListLine(line) }
    }

    private func extractNotes(from lines: [String], excluding excludedLines: Set<String>) -> [String] {
        let extracted = sectionLines(
            from: lines,
            matchingHeaders: ["notes", "tips"],
            untilHeaders: ["nutrition"]
        ) ?? []

        return extracted
            .map { normalizeListLine($0) }
            .filter { !excludedLines.contains($0) }
            .prefix(6)
            .map { $0 }
    }

    private func sectionLines(from lines: [String], matchingHeaders headers: [String], untilHeaders endHeaders: [String]) -> [String]? {
        guard let startIndex = lines.firstIndex(where: { line in
            let normalized = line.lowercased()
            return headers.contains(where: { normalized.contains($0) })
        }) else {
            return nil
        }

        let remaining = lines.dropFirst(startIndex + 1)
        let endIndex = remaining.firstIndex(where: { line in
            let normalized = line.lowercased()
            return endHeaders.contains(where: { normalized.contains($0) })
        })

        let slice = endIndex.map { remaining[..<$0] } ?? remaining[remaining.startIndex...]
        let cleaned = slice
            .map { normalizeListLine($0) }
            .filter { !$0.isEmpty }

        return cleaned.isEmpty ? nil : Array(cleaned.prefix(20))
    }

    private func looksLikeIngredient(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        if lowercased.count > 90 { return false }
        if lowercased.contains("http") { return false }
        return lowercased.range(of: #"^(\d+|\d+/\d+|[\-\u2022])\s"#, options: .regularExpression) != nil
            || lowercased.range(of: #"\b(cup|cups|tbsp|tsp|teaspoon|teaspoons|tablespoon|tablespoons|g|kg|oz|lb|ml|l|pinch|clove|cloves|slice|slices)\b"#, options: .regularExpression) != nil
    }

    private func looksLikePreparationStep(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        if lowercased.count < 18 { return false }
        if lowercased.contains("ingredients") { return false }
        return lowercased.range(of: #"^(\d+[\.\)]|step\s+\d+)"#, options: .regularExpression) != nil
            || lowercased.range(of: #"\b(mix|stir|bake|cook|heat|whisk|combine|serve|add|preheat|simmer|boil|roast|grill|fold)\b"#, options: .regularExpression) != nil
    }

    private func normalizeListLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: #"^(\d+[\.\)]\s*|[\-\u2022]\s*|step\s+\d+\s*[:\-]?\s*)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func inferredConfidence(summary: String, ingredients: [String], preparationSteps: [String]) -> Double? {
        if !ingredients.isEmpty && !preparationSteps.isEmpty {
            return 0.56
        }
        if !summary.isEmpty && (!ingredients.isEmpty || !preparationSteps.isEmpty) {
            return 0.42
        }
        return nil
    }
}

private struct BackendRecipeEnrichmentRequest: Encodable {
    let sourceURL: String
    let title: String
    let description: String
    let rawText: String

    init(from request: RecipeEnrichmentRequest) {
        sourceURL = request.sourceURL
        title = request.title
        description = request.description
        rawText = request.rawText
    }
}

private struct BackendRecipeEnrichmentResponse: Decodable {
    let summary: String?
    let ingredients: [String]?
    let preparationSteps: [String]?
    let preparation_steps: [String]?
    let notes: [String]?
    let confidence: Double?

    var asExtraction: RecipeAIExtraction {
        RecipeAIExtraction(
            summary: summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            ingredients: ingredients ?? [],
            preparationSteps: preparationSteps ?? preparation_steps ?? [],
            notes: notes ?? [],
            confidence: confidence
        )
    }
}
