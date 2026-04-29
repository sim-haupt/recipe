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
                    .font(.subheadline.weight(.medium))
                if removable {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? RecipeTheme.accent : RecipeTheme.accentSoft)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
