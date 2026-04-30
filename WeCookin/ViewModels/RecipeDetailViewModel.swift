import Foundation

@MainActor
final class RecipeDetailViewModel: ObservableObject {
    @Published var recipe: Recipe
    @Published var comments: [Comment] = []
    @Published var reviews: [Review] = []
    @Published var newComment = ""
    @Published var reviewRating = 0
    @Published var editableCategories = Set<String>()
    @Published var editableTags: [String]
    @Published var editTitle: String
    @Published var editDescription: String
    @Published var editSourceURL: String
    @Published var editIngredients: String
    @Published var editPreparation: String
    @Published var editNotes: String
    @Published var errorMessage: String?

    private let environment: AppEnvironment
    private let userProfile: UserProfile
    private var recipeListener: RealtimeListening?
    private var commentListener: RealtimeListening?
    private var reviewListener: RealtimeListening?

    init(recipe: Recipe, environment: AppEnvironment, userProfile: UserProfile) {
        self.recipe = recipe
        self.environment = environment
        self.userProfile = userProfile
        self.editableCategories = Set(recipe.categories)
        self.editableTags = recipe.tagNames
        self.editTitle = recipe.title
        self.editDescription = recipe.description
        self.editSourceURL = recipe.sourceURL ?? ""
        self.editIngredients = recipe.ingredients.joined(separator: "\n")
        self.editPreparation = recipe.preparationSteps.joined(separator: "\n")
        self.editNotes = recipe.aiNotes.joined(separator: "\n")
    }

    func start() {
        guard let householdID = userProfile.activeHouseholdID else { return }

        recipeListener = environment.recipeService.observeRecipes(householdID: householdID) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let recipes):
                    guard let self, let updatedRecipe = recipes.first(where: { $0.id == self.recipe.id }) else { return }
                    self.recipe = updatedRecipe
                    self.editTitle = updatedRecipe.title
                    self.editDescription = updatedRecipe.description
                    self.editSourceURL = updatedRecipe.sourceURL ?? ""
                    self.editableCategories = Set(updatedRecipe.categories)
                    self.editableTags = updatedRecipe.tagNames
                    self.editIngredients = updatedRecipe.ingredients.joined(separator: "\n")
                    self.editPreparation = updatedRecipe.preparationSteps.joined(separator: "\n")
                    self.editNotes = updatedRecipe.aiNotes.joined(separator: "\n")
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }

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
                    let validRatings = reviews.map(\.rating).filter { $0 > 0 }
                    self?.recipe.averageRating = validRatings.isEmpty ? nil : Double(validRatings.reduce(0, +)) / Double(validRatings.count)
                    self?.recipe.reviewCount = validRatings.count
                    if let mine = reviews.first(where: { $0.authorID == self?.userProfile.id }) {
                        self?.reviewRating = mine.rating
                    } else {
                        self?.reviewRating = 0
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func submitComment(imageData: Data?) async {
        guard let householdID = userProfile.activeHouseholdID else { return }
        do {
            try await environment.recipeService.addComment(recipe: recipe, householdID: householdID, text: newComment, imageData: imageData, author: userProfile)
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
                note: "",
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

    func saveRecipeEdits(imageData: Data?) async {
        guard let householdID = userProfile.activeHouseholdID else { return }

        do {
            try await environment.recipeService.updateRecipe(
                recipe: recipe,
                householdID: householdID,
                title: editTitle,
                description: editDescription,
                sourceURL: editSourceURL,
                categories: editableCategories.sorted(),
                tagNames: editableTags,
                ingredients: multilineEditorLines(from: editIngredients),
                preparationSteps: multilineEditorLines(from: editPreparation),
                notes: multilineEditorLines(from: editNotes),
                imageData: imageData
            )

            recipe.title = editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? recipe.title : editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            recipe.description = editDescription
            recipe.sourceURL = editSourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editSourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
            recipe.categories = editableCategories.sorted()
            recipe.tagNames = editableTags
            recipe.ingredients = multilineEditorLines(from: editIngredients)
            recipe.preparationSteps = multilineEditorLines(from: editPreparation)
            recipe.aiNotes = multilineEditorLines(from: editNotes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func multilineEditorLines(from value: String) -> [String] {
        ImportedTextSanitizer.cleanMultiline(value)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func deleteRecipe() async {
        guard let householdID = userProfile.activeHouseholdID else { return }

        do {
            try await environment.recipeService.deleteRecipe(recipe: recipe, householdID: householdID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    deinit {
        recipeListener?.remove()
        commentListener?.remove()
        reviewListener?.remove()
    }
}
