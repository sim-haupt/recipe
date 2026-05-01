import Foundation

protocol RecipeEnrichmentServicing {
    func enrichRecipeContent(using request: RecipeEnrichmentRequest) async throws -> RecipeAIExtraction?
    func debugRecipeContent(using request: RecipeEnrichmentRequest) async throws -> RecipeEnrichmentDebugInfo?
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

    func debugRecipeContent(using request: RecipeEnrichmentRequest) async throws -> RecipeEnrichmentDebugInfo? {
        guard request.hasEnoughContent else { return nil }
        guard let debugEndpointURL = debugEndpointURL() else {
            return RecipeEnrichmentDebugInfo.localFallback(from: request)
        }

        var urlRequest = URLRequest(url: debugEndpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 25
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(BackendRecipeEnrichmentRequest(from: request))

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw RecipeEnrichmentError.backendUnavailable
        }

        let decoded = try JSONDecoder().decode(BackendRecipeEnrichmentDebugResponse.self, from: data)
        return decoded.asDebugInfo
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
        let extraction = mergedExtraction(primary: decoded.asExtraction, fallback: fallback.enrichRecipeContent(using: request))
        guard extraction.hasMeaningfulContent else {
            throw RecipeEnrichmentError.invalidResponse
        }
        return extraction
    }

    private func mergedExtraction(primary: RecipeAIExtraction, fallback: RecipeAIExtraction) -> RecipeAIExtraction {
        RecipeAIExtraction(
            summary: primary.summary.isEmpty ? fallback.summary : primary.summary,
            ingredients: shouldPreferFallbackIngredients(primary.ingredients, fallback: fallback.ingredients) ? fallback.ingredients : primary.ingredients,
            confidence: primary.confidence ?? fallback.confidence
        )
    }

    private func shouldPreferFallbackIngredients(_ primary: [String], fallback: [String]) -> Bool {
        if primary.isEmpty {
            return !fallback.isEmpty
        }

        if primary.count <= 2 && fallback.count >= 4 {
            return true
        }

        return primary.contains(where: isSuspiciousRecipeBlob)
    }
    private func isSuspiciousRecipeBlob(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        if lowercased.contains("recipe (") || lowercased.contains("rezept (") {
            return true
        }
        if lowercased.contains("likes") || lowercased.contains("comments") {
            return true
        }
        if value.count > 260 {
            return true
        }

        let dashedSegments = value.components(separatedBy: "-").count - 1
        return dashedSegments >= 3
    }

    private static func configuredEndpointURL() -> URL? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "RecipeEnrichmentAPIURL") as? String else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    private func debugEndpointURL() -> URL? {
        guard let endpointURL else { return nil }
        return endpointURL.deletingLastPathComponent().appendingPathComponent("recipe-extract-debug")
    }
}

struct RecipeEnrichmentDebugInfo: Decodable {
    let model: String
    let systemPrompt: String
    let userPrompt: String
    let sourceURL: String
    let title: String
    let description: String
    let rawText: String
    let fetchedTitle: String
    let fetchedDescription: String
    let fetchedText: String
    let candidateText: String
    let extraction: RecipeAIExtraction

    static func localFallback(from request: RecipeEnrichmentRequest) -> RecipeEnrichmentDebugInfo {
        let normalizedRawText = ImportedTextSanitizer.normalizedRecipeExtractionText(from: request.rawText)
        let summary = ImportedTextSanitizer.preferredRecipeDescription(
            baseDescription: request.description,
            rawText: request.rawText,
            aiSummary: nil
        )

        return RecipeEnrichmentDebugInfo(
            model: "local-heuristic-fallback",
            systemPrompt: "Backend debug endpoint is unavailable. This is local app-side input only.",
            userPrompt: "",
            sourceURL: request.sourceURL,
            title: request.title,
            description: request.description,
            rawText: request.rawText,
            fetchedTitle: "",
            fetchedDescription: "",
            fetchedText: "",
            candidateText: normalizedRawText,
            extraction: RecipeAIExtraction(summary: summary, ingredients: [], confidence: nil)
        )
    }
}

private final class HeuristicRecipeEnrichmentService {
    func enrichRecipeContent(using request: RecipeEnrichmentRequest) -> RecipeAIExtraction {
        let summary = ImportedTextSanitizer.preferredRecipeDescription(
            baseDescription: request.description,
            rawText: request.rawText,
            aiSummary: nil
        )
        let normalizedRecipeText = ImportedTextSanitizer.normalizedRecipeExtractionText(from: request.rawText)
        let rawLines = normalizedRecipeText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let ingredients = extractIngredients(from: rawLines)

        return RecipeAIExtraction(
            summary: summary,
            ingredients: ingredients,
            confidence: inferredConfidence(summary: summary, ingredients: ingredients)
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

    private func normalizeListLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: #"^(\d+[\.\)]\s*|[\-\u2022]\s*|step\s+\d+\s*[:\-]?\s*)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func inferredConfidence(summary: String, ingredients: [String]) -> Double? {
        if !ingredients.isEmpty {
            return 0.56
        }
        if !summary.isEmpty && !ingredients.isEmpty {
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
    let confidence: Double?

    var asExtraction: RecipeAIExtraction {
        RecipeAIExtraction(
            summary: summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            ingredients: ingredients ?? [],
            confidence: confidence
        )
    }
}

private struct BackendRecipeEnrichmentDebugResponse: Decodable {
    let extraction: BackendRecipeEnrichmentResponse
    let debug: BackendRecipeEnrichmentDebugPayload

    var asDebugInfo: RecipeEnrichmentDebugInfo {
        RecipeEnrichmentDebugInfo(
            model: debug.model,
            systemPrompt: debug.systemPrompt,
            userPrompt: debug.userPrompt,
            sourceURL: debug.normalizedRequest.sourceURL,
            title: debug.normalizedRequest.title,
            description: debug.normalizedRequest.description,
            rawText: debug.normalizedRequest.rawText,
            fetchedTitle: debug.fetchedContext.fetchedTitle,
            fetchedDescription: debug.fetchedContext.fetchedDescription,
            fetchedText: debug.fetchedContext.fetchedText,
            candidateText: debug.candidateText,
            extraction: extraction.asExtraction
        )
    }
}

private struct BackendRecipeEnrichmentDebugPayload: Decodable {
    let model: String
    let systemPrompt: String
    let userPrompt: String
    let normalizedRequest: BackendRecipeEnrichmentDebugRequest
    let fetchedContext: BackendRecipeEnrichmentDebugFetchedContext
    let candidateText: String
}

private struct BackendRecipeEnrichmentDebugRequest: Decodable {
    let sourceURL: String
    let title: String
    let description: String
    let rawText: String
}

private struct BackendRecipeEnrichmentDebugFetchedContext: Decodable {
    let fetchedTitle: String
    let fetchedDescription: String
    let fetchedText: String
}
