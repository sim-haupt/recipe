import Foundation

struct HomeSearchSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var isShowingAddRecipe = false

    private let environment: AppEnvironment
    private var userProfile: UserProfile
    private var isImportingPendingDrafts = false
    private var recipeListener: RealtimeListening?

    init(environment: AppEnvironment, userProfile: UserProfile) {
        self.environment = environment
        self.userProfile = userProfile
    }

    var searchSuggestions: [HomeSearchSuggestion] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        return recipes
            .filter { recipeMatchesSearch($0, query: query) }
            .sorted { lhs, rhs in
                if lhs.savedDate == rhs.savedDate {
                    return lhs.title < rhs.title
                }
                return lhs.savedDate > rhs.savedDate
            }
            .prefix(5)
            .map { recipe in
                HomeSearchSuggestion(
                    id: recipe.id,
                    title: recipe.title,
                    subtitle: !recipe.categories.isEmpty
                        ? "\(recipe.categories.joined(separator: ", ")) • \(recipe.createdByName)"
                        : "by \(recipe.createdByName)"
                )
            }
    }

    func recipe(for suggestion: HomeSearchSuggestion) -> Recipe? {
        recipes.first { $0.id == suggestion.id }
    }

    var favoriteRecipes: [Recipe] {
        recipes
            .filter(\.isFavorite)
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.savedDate > rhs.savedDate
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    var allRecipesSorted: [Recipe] {
        recipes.sorted { $0.savedDate > $1.savedDate }
    }

    func start() {
        guard let householdID = userProfile.activeHouseholdID else { return }

        recipeListener?.remove()
        recipeListener = environment.recipeService.observeRecipes(householdID: householdID) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let recipes):
                    self?.recipes = recipes
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }

        Task {
            await importPendingDraftsIfNeeded()
        }
    }

    func updateUserProfile(_ userProfile: UserProfile) {
        let oldHouseholdID = self.userProfile.activeHouseholdID
        self.userProfile = userProfile

        if oldHouseholdID != userProfile.activeHouseholdID {
            recipes = []
            start()
        }
    }

    func toggleFavorite(_ recipe: Recipe) async {
        guard let householdID = userProfile.activeHouseholdID else { return }

        do {
            try await environment.recipeService.updateFavorite(recipe: recipe, householdID: householdID, isFavorite: !recipe.isFavorite)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applySearchSuggestion(_ suggestion: HomeSearchSuggestion) {
        searchText = suggestion.title
    }

    func searchResults(for query: String) -> [Recipe] {
        searchResults(in: allRecipesSorted, query: query)
    }

    func searchResults(in sourceRecipes: [Recipe], query: String) -> [Recipe] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sourceRecipes }

        return sourceRecipes.filter { recipeMatchesSearch($0, query: trimmed) }
    }

    func importPendingDraftsIfNeeded() async {
        guard let householdID = userProfile.activeHouseholdID else { return }
        guard !isImportingPendingDrafts else { return }

        isImportingPendingDrafts = true
        defer { isImportingPendingDrafts = false }

        do {
            let drafts = try environment.sharedDraftStore.pendingDrafts().filter { $0.importedAt == nil }

            for draft in drafts {
                let generatedEnrichment = try? await environment.recipeEnrichmentService.enrichRecipeContent(using: RecipeEnrichmentRequest(
                    sourceURL: draft.sourceURL ?? "",
                    title: draft.title,
                    description: draft.description,
                    rawText: draft.rawText
                ))
                let draftEnrichment = RecipeAIExtraction(
                    title: draft.title,
                    summary: ImportedTextSanitizer.preferredRecipeDescription(
                        baseDescription: draft.description,
                        rawText: draft.rawText,
                        aiSummary: generatedEnrichment?.summary
                    ),
                    ingredients: draft.ingredients.isEmpty ? (generatedEnrichment?.ingredients ?? []) : draft.ingredients,
                    confidence: generatedEnrichment?.confidence
                )

                let input = RecipeCreationInput(
                    title: draft.title,
                    description: draftEnrichment.summary,
                    sourceURL: draft.sourceURL ?? "",
                    categories: draft.categories,
                    tagNames: draft.tags,
                    imageData: environment.sharedDraftStore.imageData(for: draft),
                    initialComment: "",
                    initialRating: 0,
                    aiExtraction: draftEnrichment.hasMeaningfulContent ? draftEnrichment : nil
                )

                try await environment.recipeService.createRecipe(input: input, householdID: householdID, author: userProfile)
                try environment.sharedDraftStore.markImported(draft.id)
            }

            try environment.sharedDraftStore.removeImportedDrafts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recipeMatchesSearch(_ recipe: Recipe, query: String) -> Bool {
        recipe.title.localizedCaseInsensitiveContains(query)
            || recipe.description.localizedCaseInsensitiveContains(query)
            || recipe.createdByName.localizedCaseInsensitiveContains(query)
            || recipe.categories.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            || recipe.tagNames.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            || recipe.ingredients.contains(where: { $0.localizedCaseInsensitiveContains(query) })
    }
}
