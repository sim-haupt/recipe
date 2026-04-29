import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var tags: [Tag] = []
    @Published var searchText = ""
    @Published var selectedTags = Set<String>()
    @Published var errorMessage: String?
    @Published var isShowingAddRecipe = false

    private let environment: AppEnvironment
    private let userProfile: UserProfile
    private var recipeListener: RealtimeListening?
    private var tagListener: RealtimeListening?

    init(environment: AppEnvironment, userProfile: UserProfile) {
        self.environment = environment
        self.userProfile = userProfile
    }

    var filteredRecipes: [Recipe] {
        recipes.filter { recipe in
            let matchesSearch = searchText.isEmpty
                || recipe.title.localizedCaseInsensitiveContains(searchText)
                || recipe.description.localizedCaseInsensitiveContains(searchText)

            let matchesTags = selectedTags.isEmpty
                || !selectedTags.isDisjoint(with: Set(recipe.tagNames))

            return matchesSearch && matchesTags
        }
    }

    func start() {
        guard let householdID = userProfile.activeHouseholdID else { return }

        recipeListener?.remove()
        tagListener?.remove()

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

        tagListener = environment.recipeService.observeTags(householdID: householdID) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let tags):
                    self?.tags = tags
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }

        Task {
            await importPendingDraftsIfNeeded()
        }
    }

    func toggle(tag: Tag) {
        if selectedTags.contains(tag.name) {
            selectedTags.remove(tag.name)
        } else {
            selectedTags.insert(tag.name)
        }
    }

    func importPendingDraftsIfNeeded() async {
        guard let householdID = userProfile.activeHouseholdID else { return }

        do {
            let drafts = try environment.sharedDraftStore.pendingDrafts().filter { $0.importedAt == nil }

            for draft in drafts {
                let input = RecipeCreationInput(
                    title: draft.title,
                    description: draft.description,
                    sourceURL: draft.sourceURL ?? "",
                    tagNames: draft.tags,
                    imageData: environment.sharedDraftStore.imageData(for: draft),
                    initialComment: "",
                    initialRating: 0
                )

                try await environment.recipeService.createRecipe(input: input, householdID: householdID, author: userProfile)
                try environment.sharedDraftStore.markImported(draft.id)
            }

            try environment.sharedDraftStore.removeImportedDrafts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
