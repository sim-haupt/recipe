import Foundation

struct RecipeComposerDraft: Codable, Hashable {
    var title: String
    var description: String
    var sourceURL: String
    var tags: [String]
    var comments: String
    var rating: Int
}
