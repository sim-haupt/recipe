import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    let id: String
    var displayName: String
    var email: String
    var activeHouseholdID: String?
    var householdIDs: [String]
    var createdAt: Date
    var updatedAt: Date
}
