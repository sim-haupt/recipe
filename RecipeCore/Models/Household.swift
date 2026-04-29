import Foundation

struct Household: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var inviteCode: String
    var memberIDs: [String]
    var createdByUserID: String
    var createdAt: Date
    var updatedAt: Date
}
