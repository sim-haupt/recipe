import Foundation

struct RecipeCreationInput {
    var title: String
    var description: String
    var sourceURL: String
    var tagNames: [String]
    var imageData: Data?
    var initialComment: String
    var initialRating: Int
}
