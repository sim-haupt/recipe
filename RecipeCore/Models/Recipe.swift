import Foundation

struct Recipe: Identifiable, Codable, Hashable {
    let id: String
    var householdID: String
    var title: String
    var description: String
    var sourceURL: String?
    var imageURL: String?
    var savedDate: Date
    var createdByUserID: String
    var createdByName: String
    var updatedAt: Date
    var tagIDs: [String]
    var tagNames: [String]
    var averageRating: Double?
    var reviewCount: Int
}
