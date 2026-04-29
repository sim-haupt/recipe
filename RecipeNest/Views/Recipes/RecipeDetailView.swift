import SwiftUI
import UIKit

struct RecipeDetailView: View {
    @Environment(\.appEnvironment) private var environment
    @StateObject private var viewModel: RecipeDetailViewModel
    @State private var isShowingShareSheet = false

    init(recipe: Recipe, userProfile: UserProfile, environment: AppEnvironment = .demo) {
        _viewModel = StateObject(wrappedValue: RecipeDetailViewModel(recipe: recipe, environment: environment, userProfile: userProfile))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RemoteRecipeImage(imageURL: viewModel.recipe.imageURL, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.recipe.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Saved \(viewModel.recipe.savedDate.formatted(date: .long, time: .omitted)) by \(viewModel.recipe.createdByName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let sourceURL = viewModel.recipe.sourceURL, let url = URL(string: sourceURL) {
                        Link(destination: url) {
                            Label("Open Source", systemImage: "safari")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Text(viewModel.recipe.description.isEmpty ? "No clipped description yet." : viewModel.recipe.description)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Tags")
                        .font(.headline)
                    HStack {
                        TextField("Add tag", text: $viewModel.tagEntry)
                            .textFieldStyle(.roundedBorder)
                        Button("Add", action: viewModel.addTag)
                    }
                    FlowTagList(tags: viewModel.editableTags, onRemove: viewModel.removeTag(_:))
                    Button("Save Tags") {
                        Task { await viewModel.saveTags() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Review")
                        .font(.headline)
                    StarRatingView(rating: $viewModel.reviewRating)
                    TextField("Add a note with your rating", text: $viewModel.reviewNote, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button("Save Review") {
                        Task { await viewModel.submitReview() }
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Comments")
                        .font(.headline)
                    TextField("Add a comment", text: $viewModel.newComment, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button("Post Comment") {
                        Task { await viewModel.submitComment() }
                    }
                    .buttonStyle(.bordered)

                    ForEach(viewModel.comments) { comment in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(comment.authorName)
                                .font(.subheadline.weight(.semibold))
                            Text(comment.text)
                            Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Community Ratings")
                        .font(.headline)
                    ForEach(viewModel.reviews) { review in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(review.authorName)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                StaticStarRatingView(rating: review.rating)
                            }
                            if !review.note.isEmpty {
                                Text(review.note)
                            }
                            Text(review.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
            .padding(20)
        }
        .background(RecipeTheme.background.ignoresSafeArea())
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
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

private struct StaticStarRatingView: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundStyle(index <= rating ? .yellow : .secondary)
            }
        }
    }
}
