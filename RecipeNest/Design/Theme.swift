import SwiftUI

enum RecipeTheme {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .systemBackground)
    static let secondaryCard = Color(uiColor: .secondarySystemBackground)
    static let accent = Color(red: 0.35, green: 0.78, blue: 0.68)
    static let accentStrong = Color(red: 0.22, green: 0.66, blue: 0.57)
    static let accentSoft = Color(red: 0.87, green: 0.97, blue: 0.94)
    static let accentWash = Color(red: 0.93, green: 0.99, blue: 0.97)
    static let mintShadow = Color(red: 0.24, green: 0.55, blue: 0.49).opacity(0.18)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let shadow = Color.black.opacity(0.08)

    static let heroGradient = LinearGradient(
        colors: [accent, accentStrong],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pageGradient = LinearGradient(
        colors: [accentWash, background],
        startPoint: .top,
        endPoint: .bottom
    )
}
