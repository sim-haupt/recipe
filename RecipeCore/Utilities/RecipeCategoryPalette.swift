import SwiftUI

extension RecipeCategory {
    static func color(for title: String) -> Color {
        switch title {
        case RecipeCategory.desserts.rawValue:
            return Color(red: 0.83, green: 0.50, blue: 0.71)
        case RecipeCategory.baking.rawValue:
            return Color(red: 0.78, green: 0.59, blue: 0.38)
        case RecipeCategory.breadAndRolls.rawValue:
            return Color(red: 0.81, green: 0.68, blue: 0.39)
        case RecipeCategory.beverages.rawValue:
            return Color(red: 0.41, green: 0.75, blue: 0.87)
        case RecipeCategory.breakfast.rawValue:
            return Color(red: 0.91, green: 0.74, blue: 0.34)
        case RecipeCategory.snacks.rawValue:
            return Color(red: 0.88, green: 0.55, blue: 0.48)
        case RecipeCategory.appetizers.rawValue:
            return Color(red: 0.74, green: 0.58, blue: 0.88)
        case RecipeCategory.soups.rawValue:
            return Color(red: 0.85, green: 0.53, blue: 0.34)
        case RecipeCategory.pastaAndRice.rawValue:
            return Color(red: 0.47, green: 0.74, blue: 0.31)
        case RecipeCategory.mainCourse.rawValue:
            return Color(red: 0.88, green: 0.49, blue: 0.42)
        case RecipeCategory.sideDish.rawValue:
            return Color(red: 0.41, green: 0.77, blue: 0.58)
        case RecipeCategory.saucesDipsSpreads.rawValue:
            return Color(red: 0.72, green: 0.63, blue: 0.43)
        default:
            return Color(red: 0.24, green: 0.66, blue: 0.33)
        }
    }

    static func fillColor(for title: String, isSelected: Bool) -> Color {
        isSelected ? color(for: title).opacity(0.22) : Color.white.opacity(0.96)
    }

    static func strokeColor(for title: String, isSelected: Bool) -> Color {
        isSelected ? color(for: title).opacity(0.42) : color(for: title).opacity(0.22)
    }

    static func gradient(for title: String) -> LinearGradient {
        let base = color(for: title)
        return LinearGradient(
            colors: [
                base.opacity(0.82),
                base
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
