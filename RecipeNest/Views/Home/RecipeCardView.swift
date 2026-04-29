import SwiftUI

struct RecipeCardView: View {
    let recipe: Recipe
    var imageHeight: CGFloat = 244
    var titleFontSize: CGFloat = 19
    var favoriteAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                RemoteRecipeImage(imageURL: recipe.imageURL, height: imageHeight)
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.18)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 28,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 28,
                            style: .continuous
                        )
                    )

                HStack(alignment: .top) {
                    if let average = recipe.averageRating {
                        RecipeRatingPill(rating: average, reviewCount: recipe.reviewCount)
                    }

                    Spacer(minLength: 10)

                    if let favoriteAction {
                        Button(action: favoriteAction) {
                            Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(recipe.isFavorite ? Color(red: 0.95, green: 0.31, blue: 0.46) : RecipeTheme.accentStrong)
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.94))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.12), radius: 12, y: 8)
                        }
                        .buttonStyle(PressableScaleButtonStyle())
                    }
                }
                .padding(14)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(recipe.title)
                    .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(RecipeTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)

                HStack(spacing: 10) {
                    Label(recipe.savedDate.formatted(date: .abbreviated, time: .omitted), systemImage: "clock.fill")
                    Text("by \(recipe.createdByName)")
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(RecipeTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

                if !recipe.tagNames.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recipe.tagNames.prefix(3), id: \.self) { tag in
                                RecipeTagPill(title: tag)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RecipeTheme.surface)
        }
        .background(RecipeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(RecipeTheme.strokeSoft, lineWidth: 1)
        }
        .shadow(color: RecipeTheme.mintShadow, radius: 20, y: 12)
    }
}

#Preview {
    RecipeCardView(
        recipe: Recipe(
            id: "preview-recipe",
            householdID: "preview-household",
            title: "Burst Tomato Pasta",
            description: "Fresh tomato pasta with basil and garlic.",
            sourceURL: "https://example.com",
            imageURL: nil,
            savedDate: .now,
            createdByUserID: "preview-user",
            createdByName: "Demo Cook",
            updatedAt: .now,
            tagIDs: ["1", "2"],
            tagNames: ["Weeknight", "Pasta", "Quick"],
            isFavorite: true,
            averageRating: 4.8,
            reviewCount: 14
        ),
        favoriteAction: {}
    )
    .padding()
    .background(RecipeTheme.homeBackdrop)
}
