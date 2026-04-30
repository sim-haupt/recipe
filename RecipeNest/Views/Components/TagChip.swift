import SwiftUI

struct TagChip: View {
    let title: String
    var isSelected = false
    var removable = false
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                if removable {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? RecipeTheme.accent : RecipeTheme.accentSoft)
            .foregroundStyle(isSelected ? RecipeTheme.textOnAccent : RecipeTheme.textPrimary)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? Color.clear : RecipeTheme.accent.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
