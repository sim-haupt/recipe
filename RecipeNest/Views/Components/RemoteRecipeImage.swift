import SwiftUI

struct RemoteRecipeImage: View {
    let imageURL: String?
    var height: CGFloat

    var body: some View {
        Group {
            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [RecipeTheme.accentSoft, RecipeTheme.sage.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}
