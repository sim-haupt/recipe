import SwiftUI

enum RecipeImagePlaceholderStyle {
    case gradient
    case pattern(String)
}

struct RemoteRecipeImage: View {
    let imageURL: String?
    var width: CGFloat? = nil
    var height: CGFloat
    var placeholderStyle: RecipeImagePlaceholderStyle = .gradient

    var body: some View {
        Group {
            if let imageURL, let url = URL(string: imageURL) {
                if let localURL = DemoDataStore.shared.resolvedImageURL(for: imageURL),
                   let image = UIImage(contentsOfFile: localURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if url.isFileURL, let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            placeholder
                        }
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height, alignment: .center)
        .clipped()
    }

    private var placeholder: some View {
        ZStack {
            switch placeholderStyle {
            case .gradient:
                LinearGradient(colors: [RecipeTheme.accentSoft, RecipeTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .pattern(let assetName):
                Image(assetName)
                    .resizable()
                    .scaledToFill()

                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.black.opacity(0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}
