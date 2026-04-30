import Foundation

enum RecipeCategory: String, CaseIterable, Codable, Identifiable {
    case desserts = "Desserts"
    case baking = "Baking"
    case breadAndRolls = "Bread and Rolls"
    case beverages = "Beverages"
    case breakfast = "Breakfast"
    case snacks = "Snacks"
    case appetizers = "Appetizers"
    case soups = "Soups"
    case pastaAndRice = "Pasta & Rice"
    case mainCourse = "Main Course"
    case sideDish = "Side Dish"
    case saucesDipsSpreads = "Sauces, Dips & Spreads"

    var id: String { rawValue }

    static var allTitles: [String] {
        allCases.map(\.rawValue)
    }
}
