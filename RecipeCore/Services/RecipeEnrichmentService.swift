import Foundation

protocol RecipeEnrichmentServicing {
    func enrichRecipeContent(using request: RecipeEnrichmentRequest) async throws -> RecipeAIExtraction?
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
            .map { normalizeListLine($0) }
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
            || lowercased.range(of: #"\b(mix|stir|bake|cook|heat|whisk|combine|serve|add|preheat|simmer|boil|roast|grill|fold|chop|assemble|fry|marinate|vermischen|braten|servieren|zusammenbauen)\b"#, options: .regularExpression) != nil
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
