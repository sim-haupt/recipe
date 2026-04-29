import Foundation

struct Review: Identifiable, Codable, Hashable {
    let id: String
    var recipeID: String
    var authorID: String
    var authorName: String
    var rating: Int
    var note: String
    var createdAt: Date
    var updatedAt: Date
}
