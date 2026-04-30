import SwiftUI

struct RecipeCardView: View {
    enum LayoutStyle {
        case featured
        case list
    }

    let recipe: Recipe
    var layoutStyle: LayoutStyle = .featured
    var cardWidth: CGFloat? = nil
    var imageWidth: CGFloat? = nil
    var imageHeight: CGFloat = 244
    var titleFontSize: CGFloat = 19
    var favoriteAction: (() -> Void)?

    var body: some View {
        Group {
            switch layoutStyle {
            case .featured:
                featuredCard
            case .list:
                listCard
            }
        }
        .background(RecipeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(RecipeTheme.strokeSoft, lineWidth: 1)
        }
        .shadow(color: RecipeTheme.mintShadow, radius: 18, y: 10)
        .frame(width: cardWidth)
        .frame(maxWidth: cardWidth == nil ? .infinity : nil, alignment: .topLeading)
    }

    private var featuredCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                RemoteRecipeImage(imageURL: recipe.imageURL, width: imageWidth, height: imageHeight)
                    .frame(width: imageWidth)
                    .frame(height: imageHeight)
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.14)],
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

                topAccessories
                    .padding(14)
            }
            .frame(width: imageWidth)
            .frame(maxWidth: imageWidth == nil ? .infinity : nil)
            .frame(height: imageHeight)
            .clipped()

            cardBody(spacing: 10, padding: 16, titleLineLimit: 2)
        }
        .frame(width: cardWidth)
        .frame(maxWidth: cardWidth == nil ? .infinity : nil, alignment: .topLeading)
    }

    private var listCard: some View {
        let resolvedImageWidth = imageWidth ?? 132
        let resolvedImageHeight = imageHeight

        return HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .topLeading) {
                RemoteRecipeImage(imageURL: recipe.imageURL, width: resolvedImageWidth, height: resolvedImageHeight)
                    .frame(width: resolvedImageWidth, height: resolvedImageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                if let average = recipe.averageRating {
                    RecipeRatingPill(rating: average, reviewCount: recipe.reviewCount)
                        .scaleEffect(0.92)
                        .padding(10)
                }
            }
            .frame(width: resolvedImageWidth, height: resolvedImageHeight, alignment: .topLeading)

            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(recipe.title)
                        .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(RecipeTheme.textPrimary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.84)
                        .padding(.trailing, favoriteAction == nil ? 0 : 42)

                    metadataRow

                    categoryPills(limit: 2)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 14)
                .padding(.trailing, 14)
                .frame(maxWidth: .infinity, minHeight: resolvedImageHeight, alignment: .topLeading)

                if let favoriteAction {
                    Button(action: favoriteAction) {
                        Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(recipe.isFavorite ? Color(red: 0.95, green: 0.31, blue: 0.46) : RecipeTheme.accentStrong)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.94))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PressableScaleButtonStyle())
                    .padding(.top, 14)
                    .padding(.trailing, 14)
                }
            }
        }
        .frame(width: cardWidth)
    }

    private var topAccessories: some View {
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
    }

    private func cardBody(spacing: CGFloat, padding: CGFloat, titleLineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(recipe.title)
                .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(RecipeTheme.textPrimary)
                .lineLimit(titleLineLimit)
                .minimumScaleFactor(0.84)

            metadataRow

            categoryPills(limit: 2)
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RecipeTheme.surface)
    }

    @ViewBuilder
    private func categoryPills(limit: Int) -> some View {
        let visibleCategories = Array(recipe.categories.prefix(limit))
        if !visibleCategories.isEmpty {
            HStack(spacing: 8) {
                ForEach(visibleCategories, id: \.self) { category in
                    RecipeTagPill(title: category)
                }
            }
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 10) {
            Label(recipe.savedDate.formatted(date: .abbreviated, time: .omitted), systemImage: "clock.fill")
            Text("by \(recipe.createdByName)")
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(RecipeTheme.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.82)
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
            categories: [RecipeCategory.pastaAndRice.rawValue, RecipeCategory.mainCourse.rawValue],
            tagIDs: ["1", "2"],
            tagNames: ["Weeknight", "Pasta", "Quick"],
            isFavorite: true,
            averageRating: 4.8,
            reviewCount: 14
        ),
        layoutStyle: .list,
        favoriteAction: {}
    )
    .padding()
    .background(RecipeTheme.homeBackdrop)
}
