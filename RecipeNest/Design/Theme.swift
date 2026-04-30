import SwiftUI

enum RecipeTheme {
    static let accentBase = Color(red: 74 / 255, green: 194 / 255, blue: 116 / 255)
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
    static let accent = accentBase
    static let accentStrong = accentBase
    static let accentSoft = Color(red: 0.86, green: 0.96, blue: 0.89)
    static let accentWash = Color(red: 0.92, green: 0.98, blue: 0.94)
    static let mintShadow = Color(red: 0.17, green: 0.45, blue: 0.28).opacity(0.18)
    static let textOnAccent = Color.white
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
    static let heroGlow = Color(red: 0.23, green: 0.54, blue: 0.32).opacity(0.24)

    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.42, green: 0.82, blue: 0.53),
            accentStrong
        ],
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
            Color(red: 0.91, green: 0.98, blue: 0.93),
            Color(red: 0.97, green: 0.99, blue: 0.96)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
