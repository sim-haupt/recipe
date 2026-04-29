import Foundation

struct Tag: Identifiable, Codable, Hashable {
    let id: String
    var householdID: String
    var name: String
    var normalizedName: String
    var createdAt: Date
    var updatedAt: Date
}
