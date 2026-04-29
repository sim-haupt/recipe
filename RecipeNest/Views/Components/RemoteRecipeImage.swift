import SwiftUI

struct RemoteRecipeImage: View {
    let imageURL: String?
    var height: CGFloat

    var body: some View {
        Group {
            if let imageURL, let url = URL(string: imageURL) {
                if url.isFileURL, let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            placeholder
                        }
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
            LinearGradient(colors: [RecipeTheme.accentSoft, RecipeTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}
