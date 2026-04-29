import SwiftUI

enum RecipeTheme {
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.11, blue: 0.12, alpha: 1)
            : UIColor(red: 0.97, green: 0.98, blue: 0.97, alpha: 1)
    })
    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.16, blue: 0.17, alpha: 1)
            : .white
    })
    static let secondaryCard = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.19, blue: 0.20, alpha: 1)
            : UIColor(red: 0.95, green: 0.98, blue: 0.97, alpha: 1)
    })
    static let accent = Color(red: 0.35, green: 0.78, blue: 0.68)
    static let accentStrong = Color(red: 0.22, green: 0.66, blue: 0.57)
    static let accentSoft = Color(red: 0.87, green: 0.97, blue: 0.94)
    static let accentWash = Color(red: 0.93, green: 0.99, blue: 0.97)
    static let mintShadow = Color(red: 0.24, green: 0.55, blue: 0.49).opacity(0.18)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let shadow = Color.black.opacity(0.08)
    static let surface = card
    static let surfaceElevated = Color.white.opacity(0.78)
    static let contentBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.12, blue: 0.13, alpha: 1)
            : UIColor(red: 0.98, green: 0.99, blue: 0.98, alpha: 1)
    })
    static let strokeSoft = Color.white.opacity(0.55)
    static let heroGlow = Color(red: 0.20, green: 0.52, blue: 0.45).opacity(0.24)

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

    static let homeBackdrop = LinearGradient(
        colors: [
            Color(red: 0.90, green: 0.98, blue: 0.95),
            Color(red: 0.97, green: 0.98, blue: 0.97)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
