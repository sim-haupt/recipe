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
    var categories: [String]
    var tagIDs: [String]
    var tagNames: [String]
    var isFavorite: Bool
    var averageRating: Double?
    var reviewCount: Int

    var category: String? {
        get { categories.first }
        set { categories = newValue.map { [$0] } ?? [] }
    }

    init(
        id: String,
        householdID: String,
        title: String,
        description: String,
        sourceURL: String?,
        imageURL: String?,
        savedDate: Date,
        createdByUserID: String,
        createdByName: String,
        updatedAt: Date,
        category: String? = nil,
        categories: [String] = [],
        tagIDs: [String],
        tagNames: [String],
        isFavorite: Bool,
        averageRating: Double?,
        reviewCount: Int
    ) {
        self.id = id
        self.householdID = householdID
        self.title = title
        self.description = description
        self.sourceURL = sourceURL
        self.imageURL = imageURL
        self.savedDate = savedDate
        self.createdByUserID = createdByUserID
        self.createdByName = createdByName
        self.updatedAt = updatedAt
        self.categories = Self.sanitizedCategories(categories.isEmpty ? (category.map { [$0] } ?? []) : categories)
        self.tagIDs = tagIDs
        self.tagNames = tagNames
        self.isFavorite = isFavorite
        self.averageRating = averageRating
        self.reviewCount = reviewCount
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case householdID
        case title
        case description
        case sourceURL
        case imageURL
        case savedDate
        case createdByUserID
        case createdByName
        case updatedAt
        case category
        case categories
        case tagIDs
        case tagNames
        case isFavorite
        case averageRating
        case reviewCount
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        householdID = try container.decode(String.self, forKey: .householdID)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        savedDate = try container.decode(Date.self, forKey: .savedDate)
        createdByUserID = try container.decode(String.self, forKey: .createdByUserID)
        createdByName = try container.decode(String.self, forKey: .createdByName)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        let decodedCategories = try container.decodeIfPresent([String].self, forKey: .categories)
        let decodedCategory = try container.decodeIfPresent(String.self, forKey: .category)
        categories = Self.sanitizedCategories(decodedCategories ?? (decodedCategory.map { [$0] } ?? []))
        tagIDs = try container.decode([String].self, forKey: .tagIDs)
        tagNames = try container.decode([String].self, forKey: .tagNames)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        averageRating = try container.decodeIfPresent(Double.self, forKey: .averageRating)
        reviewCount = try container.decode(Int.self, forKey: .reviewCount)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(householdID, forKey: .householdID)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encode(savedDate, forKey: .savedDate)
        try container.encode(createdByUserID, forKey: .createdByUserID)
        try container.encode(createdByName, forKey: .createdByName)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(categories, forKey: .categories)
        try container.encodeIfPresent(categories.first, forKey: .category)
        try container.encode(tagIDs, forKey: .tagIDs)
        try container.encode(tagNames, forKey: .tagNames)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(averageRating, forKey: .averageRating)
        try container.encode(reviewCount, forKey: .reviewCount)
    }

    private static func sanitizedCategories(_ categories: [String]) -> [String] {
        var seen = Set<String>()
        return categories
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }
}
