import SwiftUI
import UIKit
import PhotosUI

struct RecipeDetailView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RecipeDetailViewModel
    @State private var isShowingShareSheet = false
    @State private var isShowingEditSheet = false
    @State private var isShowingCommentSheet = false
    @State private var isShowingRatingSheet = false
    @State private var selectedCommentPhoto: PhotosPickerItem?
    @State private var commentPhotoData: Data?
    @State private var selectedEditPhoto: PhotosPickerItem?
    @State private var editPhotoData: Data?

    init(recipe: Recipe, userProfile: UserProfile, environment: AppEnvironment = .demo) {
        _viewModel = StateObject(wrappedValue: RecipeDetailViewModel(recipe: recipe, environment: environment, userProfile: userProfile))
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = RecipeDetailLayoutMetrics(availableWidth: proxy.size.width)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    recipeOverviewSection(metrics: metrics)
                    commentsCard(metrics: metrics)
                }
                .frame(maxWidth: metrics.contentWidth, alignment: .leading)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            detailScreenBackground
                .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    editPhotoData = nil
                    selectedEditPhoto = nil
                    isShowingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }

                Button {
                    isShowingCommentSheet = true
                } label: {
                    Image(systemName: "text.bubble")
                }

                Button {
                    isShowingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }

                if viewModel.recipe.sourceURL.flatMap(URL.init(string:)) != nil {
                    Button {
                        if let sourceURL = viewModel.recipe.sourceURL, let url = URL(string: sourceURL) {
                            openURL(url)
                        }
                    } label: {
                        Image(systemName: "safari")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ActivityView(items: shareItems)
        }
        .sheet(isPresented: $isShowingEditSheet) {
            editSheet
        }
        .sheet(isPresented: $isShowingCommentSheet) {
            commentSheet
        }
        .sheet(isPresented: $isShowingRatingSheet) {
            ratingSheet
        }
        .task {
            viewModel.start()
        }
        .onChange(of: selectedCommentPhoto) { _, newValue in
            guard let newValue else {
                commentPhotoData = nil
                return
            }

            Task {
                commentPhotoData = try? await newValue.loadTransferable(type: Data.self)
            }
        }
        .onChange(of: selectedEditPhoto) { _, newValue in
            guard let newValue else {
                editPhotoData = nil
                return
            }

            Task {
                editPhotoData = try? await newValue.loadTransferable(type: Data.self)
            }
        }
        .alert("Recipe detail issue", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .environment(\.appEnvironment, environment)
    }

    private var detailScreenBackground: some View {
        ZStack {
            Image("RecipeDetailPattern")
                .resizable()
                .scaledToFill()

            LinearGradient(
                colors: [
                    RecipeTheme.accent.opacity(0.10),
                    RecipeTheme.accentStrong.opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func recipeOverviewSection(metrics: RecipeDetailLayoutMetrics) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                RemoteRecipeImage(
                    imageURL: viewModel.recipe.imageURL,
                    width: metrics.heroWidth,
                    height: metrics.heroHeight,
                    placeholderStyle: .pattern("RecipeDetailPattern")
                )
                    .frame(width: metrics.heroWidth, height: metrics.heroHeight)
                    .overlay {
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.38)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            isShowingRatingSheet = true
                        } label: {
                            RecipeRatingPill(
                                rating: displayedAverageRating,
                                reviewCount: viewModel.recipe.reviewCount
                            )
                        }
                        .buttonStyle(PressableScaleButtonStyle())

                        Spacer(minLength: 12)

                        Button {
                            Task { await viewModel.toggleFavorite() }
                        } label: {
                            Image(systemName: viewModel.recipe.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(viewModel.recipe.isFavorite ? Color(red: 0.95, green: 0.31, blue: 0.46) : RecipeTheme.accentStrong)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.94))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.14), radius: 12, y: 8)
                        }
                        .buttonStyle(PressableScaleButtonStyle())
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 10) {
                        categoryOverlayRow

                        Text(viewModel.recipe.title)
                            .font(.system(size: metrics.heroTitleSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.82)

                        Text("Saved \(viewModel.recipe.savedDate.formatted(date: .long, time: .omitted)) by \(viewModel.recipe.createdByName)")
                            .font(.system(size: metrics.metaTitleSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .minimumScaleFactor(0.8)
                    }
                }
                .padding(metrics.heroPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(width: metrics.heroWidth, height: metrics.heroHeight, alignment: .bottomLeading)

            recipeOverviewBody(metrics: metrics)
        }
        .frame(width: metrics.heroWidth, alignment: .topLeading)
        .background(RecipeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(RecipeTheme.strokeSoft, lineWidth: 1)
        }
        .shadow(color: RecipeTheme.mintShadow, radius: 24, y: 14)
    }

    private func recipeOverviewBody(metrics: RecipeDetailLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !viewModel.recipe.ingredients.isEmpty {
                recipeContentSection(
                    title: "Ingredients",
                    items: viewModel.recipe.ingredients,
                    metrics: metrics,
                    usesNumbers: false
                )
            }

            if !viewModel.recipe.tagNames.isEmpty {
                Text(viewModel.recipe.tagNames.map { "#\($0.replacingOccurrences(of: " ", with: ""))" }.joined(separator: " "))
                    .font(.system(size: metrics.bodyTextSize - 1, weight: .semibold, design: .rounded))
                    .foregroundStyle(RecipeTheme.accentStrong)
            }

            if let sourceURL = viewModel.recipe.sourceURL, !sourceURL.isEmpty {
                Label(sourceURL, systemImage: "link")
                    .font(.system(size: metrics.bodyTextSize - 1, weight: .medium, design: .rounded))
                    .foregroundStyle(RecipeTheme.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RecipeTheme.surface)
    }

    private func recipeContentSection(title: String, items: [String], metrics: RecipeDetailLayoutMetrics, usesNumbers: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: metrics.bodyTextSize + 1, weight: .bold, design: .rounded))
                .foregroundStyle(RecipeTheme.textPrimary)

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if IngredientFormatting.isSectionHeader(item) {
                    Text(item)
                        .font(.system(size: metrics.bodyTextSize, weight: .bold, design: .rounded))
                        .foregroundStyle(RecipeTheme.accentStrong)
                        .padding(.top, index == 0 ? 0 : 6)
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        Text(usesNumbers ? "\(index + 1)." : "•")
                            .font(.system(size: metrics.bodyTextSize, weight: .bold, design: .rounded))
                            .foregroundStyle(RecipeTheme.accentStrong)
                            .frame(width: usesNumbers ? 22 : 10, alignment: .leading)

                        Text(item)
                            .font(.system(size: metrics.bodyTextSize, weight: .medium, design: .rounded))
                            .foregroundStyle(RecipeTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var categoryOverlayRow: some View {
        Group {
            if !viewModel.recipe.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.recipe.categories, id: \.self) { category in
                            CategoryPill(title: category, compact: true)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private func commentsCard(metrics: RecipeDetailLayoutMetrics) -> some View {
        detailCard(title: "Comments", metrics: metrics) {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.comments.isEmpty {
                    Text("No comments yet.")
                        .font(.system(size: metrics.bodyTextSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.comments) { comment in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(comment.authorName)
                                .font(.system(size: metrics.bodyTextSize - 1, weight: .bold, design: .rounded))

                            if !comment.text.isEmpty {
                                Text(comment.text)
                                    .font(.system(size: metrics.bodyTextSize - 1, weight: .medium, design: .rounded))
                            }

                            if let imageURL = comment.imageURL {
                                RemoteRecipeImage(imageURL: imageURL, width: metrics.commentImageWidth, height: 180)
                                    .frame(width: metrics.commentImageWidth, height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }

                            Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RecipeTheme.secondaryCard)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func detailCard<Content: View>(title: String? = nil, metrics: RecipeDetailLayoutMetrics, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.system(size: metrics.sectionTitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(RecipeTheme.textPrimary)
            }
            content()
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RecipeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(RecipeTheme.strokeSoft, lineWidth: 1)
        }
        .shadow(color: RecipeTheme.shadow.opacity(0.75), radius: 10, y: 6)
    }

    private var displayedRating: Int {
        if viewModel.reviewRating > 0 {
            return viewModel.reviewRating
        }
        if let average = viewModel.recipe.averageRating {
            return max(0, min(5, Int(round(average))))
        }
        return 0
    }

    private var displayedAverageRating: Double {
        if let average = viewModel.recipe.averageRating {
            return average
        }
        return displayedRating > 0 ? Double(displayedRating) : 0
    }

    private var shareItems: [Any] {
        var details: [String] = [viewModel.recipe.title]

        if !viewModel.recipe.ingredients.isEmpty {
            details.append("Ingredients:\n" + viewModel.recipe.ingredients.map { "• \($0)" }.joined(separator: "\n"))
        }

        var items: [Any] = [details.joined(separator: "\n\n")]

        if let sourceURL = viewModel.recipe.sourceURL, let url = URL(string: sourceURL) {
            items.append(url)
        }

        return items
    }

    private var editSheet: some View {
        let sheetMetrics = RecipeDetailLayoutMetrics(availableWidth: UIScreen.main.bounds.width)
        let recipeImageURL = viewModel.recipe.imageURL

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PhotosPicker(selection: $selectedEditPhoto, matching: .images) {
                        ZStack {
                            if let editPhotoData, let image = UIImage(data: editPhotoData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                RemoteRecipeImage(imageURL: recipeImageURL, width: sheetMetrics.commentImageWidth, height: 180)
                            }
                        }
                        .frame(width: sheetMetrics.commentImageWidth, height: 180)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            Label("Change Image", systemImage: "photo")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.42))
                                .clipShape(Capsule())
                                .padding(12)
                        }
                    }
                    .buttonStyle(.plain)

                    TextField("Title", text: $viewModel.editTitle)
                        .recipeInputFieldStyle()

                    TextField("Source URL", text: $viewModel.editSourceURL, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .recipeInputFieldStyle(minHeight: 70)

                    Text("Categories")
                        .font(.system(size: 15, weight: .bold, design: .rounded))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                        ForEach(RecipeCategory.allTitles, id: \.self) { category in
                            let isSelected = viewModel.editableCategories.contains(category)
                            CategoryPill(title: category, isSelected: isSelected, style: .outlined) {
                                if isSelected {
                                    viewModel.editableCategories.remove(category)
                                } else {
                                    viewModel.editableCategories.insert(category)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Text("Tags")
                        .font(.system(size: 15, weight: .bold, design: .rounded))

                    EditableTagEditor(
                        tags: $viewModel.editableTags,
                        placeholder: "Add tags",
                        helperText: "Tags appear as hashtags on the recipe page."
                    )

                    Text("Ingredients")
                        .font(.system(size: 15, weight: .bold, design: .rounded))

                    TextField("One ingredient per line", text: $viewModel.editIngredients, axis: .vertical)
                        .recipeInputFieldStyle(minHeight: 150)
                }
                .padding(20)
            }
            .navigationTitle("Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isShowingEditSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveRecipeEdits(imageData: editPhotoData)
                            editPhotoData = nil
                            selectedEditPhoto = nil
                            isShowingEditSheet = false
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var commentSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Add a comment", text: $viewModel.newComment, axis: .vertical)
                        .recipeInputFieldStyle(minHeight: 120)

                    PhotosPicker(selection: $selectedCommentPhoto, matching: .images) {
                        Label(commentPhotoData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if let commentPhotoData, let image = UIImage(data: commentPhotoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(20)
            }
            .navigationTitle("New Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isShowingCommentSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task {
                            await viewModel.submitComment(imageData: commentPhotoData)
                            commentPhotoData = nil
                            selectedCommentPhoto = nil
                            isShowingCommentSheet = false
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var ratingSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Your Rating")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(RecipeTheme.textPrimary)

                StarRatingView(rating: $viewModel.reviewRating)
                    .font(.system(size: 30))

                Spacer()
            }
            .padding(24)
            .navigationTitle("Give Rating")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isShowingRatingSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.submitReview()
                            isShowingRatingSheet = false
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private extension View {
    func recipeInputFieldStyle(minHeight: CGFloat = 58) -> some View {
        self
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.96))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: RecipeTheme.mintShadow.opacity(0.45), radius: 12, y: 6)
    }
}

private struct RecipeDetailLayoutMetrics {
    let availableWidth: CGFloat

    private var safeAvailableWidth: CGFloat {
        availableWidth.isFinite ? max(availableWidth, 1) : 1
    }

    var contentWidth: CGFloat { min(max(safeAvailableWidth - 32, 1), 720) }
    var horizontalPadding: CGFloat { safeAvailableWidth >= 768 ? 32 : 16 }
    var heroWidth: CGFloat { contentWidth }
    var heroHeight: CGFloat { min(max(contentWidth * 0.64, 260), 360) }
    var commentImageWidth: CGFloat { max(contentWidth - (horizontalPadding * 2), 1) }
    var heroPadding: CGFloat { safeAvailableWidth < 360 ? 16 : 18 }
    var heroTitleSize: CGFloat { safeAvailableWidth < 360 ? 24 : 28 }
    var metaTitleSize: CGFloat { safeAvailableWidth < 360 ? 13 : 14 }
    var bodyTextSize: CGFloat { safeAvailableWidth < 360 ? 14 : 15 }
    var sectionTitleSize: CGFloat { safeAvailableWidth < 360 ? 19 : 21 }
    var sectionSpacing: CGFloat { safeAvailableWidth < 360 ? 16 : 18 }
    var cardPadding: CGFloat { safeAvailableWidth < 360 ? 14 : 16 }
}
