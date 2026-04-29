import SwiftUI
import UIKit

struct RecipeDetailView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: RecipeDetailViewModel
    @State private var isShowingShareSheet = false

    init(recipe: Recipe, userProfile: UserProfile, environment: AppEnvironment = .demo) {
        _viewModel = StateObject(wrappedValue: RecipeDetailViewModel(recipe: recipe, environment: environment, userProfile: userProfile))
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = RecipeDetailLayoutMetrics(availableWidth: proxy.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    heroSection(metrics: metrics)
                    overviewCard(metrics: metrics)
                    tagsCard(metrics: metrics)
                    reviewCard(metrics: metrics)
                    commentsCard(metrics: metrics)
                }
                .frame(maxWidth: metrics.contentWidth, alignment: .leading)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
        }
        .background(RecipeTheme.pageGradient.ignoresSafeArea())
        .navigationTitle("Recipe Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.toggleFavorite() }
                } label: {
                    Image(systemName: viewModel.recipe.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(viewModel.recipe.isFavorite ? Color.red : RecipeTheme.accentStrong)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }

            if viewModel.recipe.sourceURL.flatMap(URL.init(string:)) != nil {
                ToolbarItem(placement: .topBarTrailing) {
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
        .task {
            viewModel.start()
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

    private func heroSection(metrics: RecipeDetailLayoutMetrics) -> some View {
        ZStack(alignment: .bottomLeading) {
            RemoteRecipeImage(imageURL: viewModel.recipe.imageURL, height: metrics.heroHeight)
                .overlay {
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.36)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                if let average = viewModel.recipe.averageRating {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.yellow)
                        Text(String(format: "%.1f", average))
                            .font(.system(size: metrics.metaTitleSize, weight: .bold, design: .rounded))
                        Text("(\(viewModel.recipe.reviewCount))")
                            .font(.system(size: metrics.metaCaptionSize, weight: .medium, design: .rounded))
                            .foregroundStyle(RecipeTheme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.92))
                    .clipShape(Capsule())
                }

                Text(viewModel.recipe.title)
                    .font(.system(size: metrics.heroTitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.85)

                Text("Saved \(viewModel.recipe.savedDate.formatted(date: .long, time: .omitted)) by \(viewModel.recipe.createdByName)")
                    .font(.system(size: metrics.metaTitleSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .minimumScaleFactor(0.8)
            }
            .padding(metrics.heroPadding)
        }
        .shadow(color: RecipeTheme.mintShadow, radius: 24, y: 14)
    }

    private func overviewCard(metrics: RecipeDetailLayoutMetrics) -> some View {
        detailCard(metrics: metrics) {
            VStack(alignment: .leading, spacing: 14) {
                Text(viewModel.recipe.description.isEmpty ? "No clipped description yet." : viewModel.recipe.description)
                    .font(.system(size: metrics.bodyTextSize, weight: .medium, design: .rounded))
                    .foregroundStyle(RecipeTheme.textPrimary)
            }
        }
    }

    private func tagsCard(metrics: RecipeDetailLayoutMetrics) -> some View {
        detailCard(title: "Tags", metrics: metrics) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TextField("Add tag", text: $viewModel.tagEntry)
                        .textFieldStyle(.roundedBorder)
                    Button("Add", action: viewModel.addTag)
                        .buttonStyle(.borderedProminent)
                        .tint(RecipeTheme.accentStrong)
                }
                FlowTagList(tags: viewModel.editableTags, onRemove: viewModel.removeTag(_:))
                Button("Save Tags") {
                    Task { await viewModel.saveTags() }
                }
                .buttonStyle(.borderedProminent)
                .tint(RecipeTheme.accentStrong)
            }
        }
    }

    private func reviewCard(metrics: RecipeDetailLayoutMetrics) -> some View {
        detailCard(title: "Your Review", metrics: metrics) {
            VStack(alignment: .leading, spacing: 12) {
                StarRatingView(rating: $viewModel.reviewRating)
                TextField("Add a note with your rating", text: $viewModel.reviewNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Save Review") {
                    Task { await viewModel.submitReview() }
                }
                .buttonStyle(.borderedProminent)
                .tint(RecipeTheme.accentStrong)
            }
        }
    }

    private func commentsCard(metrics: RecipeDetailLayoutMetrics) -> some View {
        detailCard(title: "Comments", metrics: metrics) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Add a comment", text: $viewModel.newComment, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Post Comment") {
                    Task { await viewModel.submitComment() }
                }
                .buttonStyle(.borderedProminent)
                .tint(RecipeTheme.accentStrong)

                ForEach(viewModel.comments) { comment in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(comment.authorName)
                            .font(.system(size: metrics.bodyTextSize - 1, weight: .bold, design: .rounded))
                        Text(comment.text)
                            .font(.system(size: metrics.bodyTextSize - 1, weight: .medium, design: .rounded))
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
        .background(RecipeTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: RecipeTheme.shadow, radius: 12, y: 8)
    }

    private var shareItems: [Any] {
        var items: [Any] = [
            viewModel.recipe.title,
            viewModel.recipe.description
        ]

        if let sourceURL = viewModel.recipe.sourceURL, let url = URL(string: sourceURL) {
            items.append(url)
        }

        return items
    }
}

private struct RecipeDetailLayoutMetrics {
    let availableWidth: CGFloat

    var contentWidth: CGFloat { min(availableWidth - 32, 720) }
    var horizontalPadding: CGFloat { availableWidth >= 768 ? 32 : 16 }
    var heroHeight: CGFloat { min(max(contentWidth * 0.72, 260), 380) }
    var heroPadding: CGFloat { availableWidth < 360 ? 18 : 22 }
    var heroTitleSize: CGFloat { availableWidth < 360 ? 26 : 31 }
    var metaTitleSize: CGFloat { availableWidth < 360 ? 13 : 14 }
    var metaCaptionSize: CGFloat { availableWidth < 360 ? 12 : 13 }
    var bodyTextSize: CGFloat { availableWidth < 360 ? 14 : 15 }
    var sectionTitleSize: CGFloat { availableWidth < 360 ? 20 : 22 }
    var sectionSpacing: CGFloat { availableWidth < 360 ? 18 : 22 }
    var cardPadding: CGFloat { availableWidth < 360 ? 16 : 18 }
}
