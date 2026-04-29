import SwiftUI

struct RecipeCardView: View {
    let recipe: Recipe
    var imageHeight: CGFloat = 244
    var titleFontSize: CGFloat = 19
    var favoriteAction: (() -> Void)?

    var body: some View {
        ZStack(alignment: .topLeading) {
            RemoteRecipeImage(imageURL: recipe.imageURL, height: imageHeight)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    if let average = recipe.averageRating {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.yellow)
                            Text(String(format: "%.1f", average))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            if recipe.reviewCount > 0 {
                                Text("(\(recipe.reviewCount))")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(RecipeTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Capsule())
                    }

                    Spacer()

                    if let favoriteAction {
                        Button(action: favoriteAction) {
                            Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(recipe.isFavorite ? Color.red : RecipeTheme.accentStrong)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.94))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.title)
                        .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(RecipeTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 8) {
                        Label(recipe.savedDate.formatted(date: .abbreviated, time: .omitted), systemImage: "clock.fill")
                        Text("by \(recipe.createdByName)")
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(RecipeTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                    if !recipe.tagNames.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recipe.tagNames.prefix(3), id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(RecipeTheme.accentSoft)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RecipeTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        }
        .shadow(color: RecipeTheme.mintShadow, radius: 20, y: 12)
    }
}
