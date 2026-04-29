import Foundation

struct RecipeDraft: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var description: String
    var sourceURL: String?
    var imageFileName: String?
    var tags: [String]
    var savedDate: Date
    var importedAt: Date?
    var createdByUser: String?

    static let empty = RecipeDraft(
        id: UUID().uuidString,
        title: "",
        description: "",
        sourceURL: nil,
        imageFileName: nil,
        tags: [],
        savedDate: Date(),
        importedAt: nil,
        createdByUser: nil
    )
}
