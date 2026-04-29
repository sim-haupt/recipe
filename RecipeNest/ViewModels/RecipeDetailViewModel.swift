import Foundation

@MainActor
final class RecipeDetailViewModel: ObservableObject {
    @Published var recipe: Recipe
    @Published var comments: [Comment] = []
    @Published var reviews: [Review] = []
    @Published var newComment = ""
    @Published var reviewNote = ""
    @Published var reviewRating = 0
    @Published var tagEntry = ""
    @Published var editableTags: [String]
    @Published var errorMessage: String?

    private let environment: AppEnvironment
    private let userProfile: UserProfile
    private var commentListener: RealtimeListening?
    private var reviewListener: RealtimeListening?

    init(recipe: Recipe, environment: AppEnvironment, userProfile: UserProfile) {
        self.recipe = recipe
        self.environment = environment
        self.userProfile = userProfile
        self.editableTags = recipe.tagNames
    }

    func start() {
        guard let householdID = userProfile.activeHouseholdID else { return }

        commentListener = environment.recipeService.observeComments(householdID: householdID, recipeID: recipe.id) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let comments):
                    self?.comments = comments
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }

        reviewListener = environment.recipeService.observeReviews(householdID: householdID, recipeID: recipe.id) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let reviews):
                    self?.reviews = reviews
                    if let mine = reviews.first(where: { $0.authorID == self?.userProfile.id }) {
                        self?.reviewRating = mine.rating
                        self?.reviewNote = mine.note
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func addTag() {
        let cleaned = tagEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !editableTags.contains(cleaned) else { return }
        editableTags.append(cleaned)
        tagEntry = ""
    }

    func removeTag(_ tag: String) {
        editableTags.removeAll { $0 == tag }
    }

    func saveTags() async {
        guard let householdID = userProfile.activeHouseholdID else { return }
        do {
            try await environment.recipeService.updateTags(recipe: recipe, householdID: householdID, tagNames: editableTags)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitComment() async {
        guard let householdID = userProfile.activeHouseholdID else { return }
        do {
            try await environment.recipeService.addComment(recipe: recipe, householdID: householdID, text: newComment, author: userProfile)
            newComment = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitReview() async {
        guard let householdID = userProfile.activeHouseholdID else { return }
        do {
            try await environment.recipeService.upsertReview(
                recipe: recipe,
                householdID: householdID,
                rating: reviewRating,
                note: reviewNote,
                author: userProfile
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleFavorite() async {
        guard let householdID = userProfile.activeHouseholdID else { return }

        do {
            let nextValue = !recipe.isFavorite
            try await environment.recipeService.updateFavorite(recipe: recipe, householdID: householdID, isFavorite: nextValue)
            recipe.isFavorite = nextValue
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
