import Foundation

struct RecipeCreationInput {
    var title: String
    var description: String
    var sourceURL: String
    var categories: [String]
    var tagNames: [String]
    var imageData: Data?
    var initialComment: String
    var initialRating: Int

    var category: String? {
        categories.first
    }
}
