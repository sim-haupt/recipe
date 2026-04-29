import SwiftUI

struct RecipeCardView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RemoteRecipeImage(imageURL: recipe.imageURL, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text(recipe.title)
                .font(.headline)
                .lineLimit(2)

            Text(recipe.savedDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recipe.tagNames, id: \.self) { tag in
                        TagChip(title: tag)
                    }
                }
            }

            if let average = recipe.averageRating {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", average))
                        .font(.subheadline.weight(.semibold))
                    Text("(\(recipe.reviewCount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(RecipeTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: RecipeTheme.shadow, radius: 16, y: 10)
    }
}
