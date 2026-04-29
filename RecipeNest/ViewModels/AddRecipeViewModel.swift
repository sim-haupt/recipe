import Foundation

@MainActor
final class AddRecipeViewModel: ObservableObject {
    @Published var draft = RecipeComposerDraft(title: "", description: "", sourceURL: "", tags: [], comments: "", rating: 0)
    @Published var tagEntry = ""
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var selectedImageData: Data?

    private let environment: AppEnvironment
    private let userProfile: UserProfile

    init(environment: AppEnvironment, userProfile: UserProfile) {
        self.environment = environment
        self.userProfile = userProfile
    }

    func addTag() {
        let cleaned = tagEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !draft.tags.contains(cleaned) else { return }
        draft.tags.append(cleaned)
        tagEntry = ""
    }

    func removeTag(_ tag: String) {
        draft.tags.removeAll { $0 == tag }
    }

    func save() async -> Bool {
        guard let householdID = userProfile.activeHouseholdID else {
            errorMessage = "Choose a household before saving recipes."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let input = RecipeCreationInput(
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
                sourceURL: draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines),
                tagNames: draft.tags,
                imageData: selectedImageData,
                initialComment: draft.comments.trimmingCharacters(in: .whitespacesAndNewlines),
                initialRating: draft.rating
            )
            try await environment.recipeService.createRecipe(input: input, householdID: householdID, author: userProfile)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
