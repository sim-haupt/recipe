import Foundation

struct RecipeEnrichmentRequest: Hashable {
    var sourceURL: String
    var title: String
    var description: String
    var rawText: String

    var hasEnoughContent: Bool {
        !sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct RecipeCreationInput {
    var title: String
    var description: String
    var sourceURL: String
    var categories: [String]
    var tagNames: [String]
    var imageData: Data?
    var initialComment: String
    var initialRating: Int
    var aiExtraction: RecipeAIExtraction?

    var category: String? {
        categories.first
    }
}
