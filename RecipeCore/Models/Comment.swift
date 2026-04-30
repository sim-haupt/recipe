import Foundation

struct Comment: Identifiable, Codable, Hashable {
    let id: String
    var recipeID: String
    var authorID: String
    var authorName: String
    var text: String
    var imageURL: String?
    var createdAt: Date
}
