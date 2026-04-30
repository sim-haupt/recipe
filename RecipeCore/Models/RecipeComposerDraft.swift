import Foundation

struct RecipeComposerDraft: Codable, Hashable {
    var title: String
    var description: String
    var sourceURL: String
    var ingredientsText: String
    var preparationText: String
    var notesText: String
    var categories: [String]
    var tags: [String]
    var comments: String
    var rating: Int

    var category: String? {
        get { categories.first }
        set { categories = newValue.map { [$0] } ?? [] }
    }

    init(
        title: String,
        description: String,
        sourceURL: String,
        ingredientsText: String = "",
        preparationText: String = "",
        notesText: String = "",
        category: String? = nil,
        categories: [String] = [],
        tags: [String],
        comments: String,
        rating: Int
    ) {
        self.title = title
        self.description = description
        self.sourceURL = sourceURL
        self.ingredientsText = ingredientsText
        self.preparationText = preparationText
        self.notesText = notesText
        self.categories = categories.isEmpty ? (category.map { [$0] } ?? []) : categories
        self.tags = tags
        self.comments = comments
        self.rating = rating
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case description
        case sourceURL
        case ingredientsText
        case preparationText
        case notesText
        case category
        case categories
        case tags
        case comments
        case rating
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        sourceURL = try container.decode(String.self, forKey: .sourceURL)
        ingredientsText = try container.decodeIfPresent(String.self, forKey: .ingredientsText) ?? ""
        preparationText = try container.decodeIfPresent(String.self, forKey: .preparationText) ?? ""
        notesText = try container.decodeIfPresent(String.self, forKey: .notesText) ?? ""
        let decodedCategories = try container.decodeIfPresent([String].self, forKey: .categories)
        let decodedCategory = try container.decodeIfPresent(String.self, forKey: .category)
        categories = decodedCategories ?? (decodedCategory.map { [$0] } ?? [])
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        comments = try container.decodeIfPresent(String.self, forKey: .comments) ?? ""
        rating = try container.decodeIfPresent(Int.self, forKey: .rating) ?? 0
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(sourceURL, forKey: .sourceURL)
        try container.encode(ingredientsText, forKey: .ingredientsText)
        try container.encode(preparationText, forKey: .preparationText)
        try container.encode(notesText, forKey: .notesText)
        try container.encode(categories, forKey: .categories)
        try container.encodeIfPresent(categories.first, forKey: .category)
        try container.encode(tags, forKey: .tags)
        try container.encode(comments, forKey: .comments)
        try container.encode(rating, forKey: .rating)
    }
}
