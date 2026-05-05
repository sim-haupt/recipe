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
            return "AI recipe extraction is unavailable right now."
        case .invalidResponse:
            return "The AI recipe extraction response could not be read."
        }
    }
}

final class RecipeEnrichmentService: RecipeEnrichmentServicing {
    private let session: URLSession
    private let endpointURL: URL?

    init(session: URLSession = .shared, endpointURL: URL? = RecipeEnrichmentService.configuredEndpointURL()) {
        self.session = session
        self.endpointURL = endpointURL
    }

    func enrichRecipeContent(using request: RecipeEnrichmentRequest) async throws -> RecipeAIExtraction? {
        guard request.hasEnoughContent else { return nil }
        guard let endpointURL else { throw RecipeEnrichmentError.backendUnavailable }
        return try await fetchBackendExtraction(request: request, endpointURL: endpointURL)
    }

    func debugRecipeContent(using request: RecipeEnrichmentRequest) async throws -> RecipeEnrichmentDebugInfo? {
        guard request.hasEnoughContent else { return nil }
        guard let debugEndpointURL = debugEndpointURL() else {
            return RecipeEnrichmentDebugInfo.localInputOnly(from: request)
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

    static func localInputOnly(from request: RecipeEnrichmentRequest) -> RecipeEnrichmentDebugInfo {
        let normalizedRawText = ImportedTextSanitizer.normalizedRecipeExtractionText(from: request.rawText)

        return RecipeEnrichmentDebugInfo(
            model: "debug-input-only",
            systemPrompt: "Backend debug endpoint is unavailable. This inspector is showing only the app-side input that would be sent to the backend.",
            userPrompt: "",
            sourceURL: request.sourceURL,
            title: request.title,
            description: request.description,
            rawText: request.rawText,
            fetchedTitle: "",
            fetchedDescription: "",
            fetchedText: "",
            candidateText: normalizedRawText,
            extraction: .empty
        )
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
    let title: String?
    let summary: String?
    let ingredients: [String]?
    let confidence: Double?

    var asExtraction: RecipeAIExtraction {
        RecipeAIExtraction(
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
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
