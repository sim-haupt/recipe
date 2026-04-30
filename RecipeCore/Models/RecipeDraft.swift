import Foundation

struct RecipeDraft: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var description: String
    var rawText: String
    var ingredients: [String]
    var preparationSteps: [String]
    var notes: [String]
    var sourceURL: String?
    var imageFileName: String?
    var categories: [String]
    var tags: [String]
    var savedDate: Date
    var importedAt: Date?
    var createdByUser: String?

    var category: String? {
        get { categories.first }
        set { categories = newValue.map { [$0] } ?? [] }
    }

    init(
        id: String,
        title: String,
        description: String,
        rawText: String = "",
        ingredients: [String] = [],
        preparationSteps: [String] = [],
        notes: [String] = [],
        sourceURL: String?,
        imageFileName: String?,
        category: String? = nil,
        categories: [String] = [],
        tags: [String],
        savedDate: Date,
        importedAt: Date?,
        createdByUser: String?
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.rawText = rawText
        self.ingredients = ingredients
        self.preparationSteps = preparationSteps
        self.notes = notes
        self.sourceURL = sourceURL
        self.imageFileName = imageFileName
        self.categories = categories.isEmpty ? (category.map { [$0] } ?? []) : categories
        self.tags = tags
        self.savedDate = savedDate
        self.importedAt = importedAt
        self.createdByUser = createdByUser
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case rawText
        case ingredients
        case preparationSteps
        case notes
        case sourceURL
        case imageFileName
        case category
        case categories
        case tags
        case savedDate
        case importedAt
        case createdByUser
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        rawText = try container.decodeIfPresent(String.self, forKey: .rawText) ?? ""
        ingredients = try container.decodeIfPresent([String].self, forKey: .ingredients) ?? []
        preparationSteps = try container.decodeIfPresent([String].self, forKey: .preparationSteps) ?? []
        notes = try container.decodeIfPresent([String].self, forKey: .notes) ?? []
        sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        let decodedCategories = try container.decodeIfPresent([String].self, forKey: .categories)
        let decodedCategory = try container.decodeIfPresent(String.self, forKey: .category)
        categories = decodedCategories ?? (decodedCategory.map { [$0] } ?? [])
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        savedDate = try container.decode(Date.self, forKey: .savedDate)
        importedAt = try container.decodeIfPresent(Date.self, forKey: .importedAt)
        createdByUser = try container.decodeIfPresent(String.self, forKey: .createdByUser)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(rawText, forKey: .rawText)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(preparationSteps, forKey: .preparationSteps)
        try container.encode(notes, forKey: .notes)
        try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try container.encode(categories, forKey: .categories)
        try container.encodeIfPresent(categories.first, forKey: .category)
        try container.encode(tags, forKey: .tags)
        try container.encode(savedDate, forKey: .savedDate)
        try container.encodeIfPresent(importedAt, forKey: .importedAt)
        try container.encodeIfPresent(createdByUser, forKey: .createdByUser)
    }

    static let empty = RecipeDraft(
        id: UUID().uuidString,
        title: "",
        description: "",
        rawText: "",
        ingredients: [],
        preparationSteps: [],
        notes: [],
        sourceURL: nil,
        imageFileName: nil,
        categories: [],
        tags: [],
        savedDate: Date(),
        importedAt: nil,
        createdByUser: nil
    )
}
