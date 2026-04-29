import Foundation

@MainActor
final class AddRecipeViewModel: ObservableObject {
    @Published var draft = RecipeComposerDraft(title: "", description: "", sourceURL: "", tags: [], comments: "", rating: 0)
    @Published var tagEntry = ""
    @Published var isSaving = false
    @Published var isImportingURL = false
    @Published var errorMessage: String?
    @Published var selectedImageData: Data?

    private let environment: AppEnvironment
    private let userProfile: UserProfile
    private var urlImportTask: Task<Void, Never>?
    private var lastImportedURL: String?

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

    func scheduleURLImport() {
        let trimmedURL = draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            urlImportTask?.cancel()
            return
        }

        urlImportTask?.cancel()
        urlImportTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await self?.fetchMetadataFromSourceURL()
        }
    }

    func fetchMetadataFromSourceURL(force: Bool = false) async {
        let trimmedURL = draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }
        guard force || trimmedURL != lastImportedURL else { return }
        guard !isImportingURL else { return }

        isImportingURL = true
        defer { isImportingURL = false }

        do {
            let imported = try await environment.urlImportService.fetchRecipeData(from: trimmedURL)
            if Task.isCancelled { return }

            let isNewImport = imported.canonicalURL != lastImportedURL
            if isNewImport || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.title = imported.title
            }
            if isNewImport || draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.description = imported.description
            }
            draft.sourceURL = imported.canonicalURL
            if let imageData = imported.imageData {
                selectedImageData = imageData
            }
            lastImportedURL = imported.canonicalURL
        } catch {
            if force {
                errorMessage = error.localizedDescription
            }
        }
    }

    func save() async -> Bool {
        guard let householdID = userProfile.activeHouseholdID else {
            errorMessage = "Choose a household before saving recipes."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                urlImportTask?.cancel()
                await fetchMetadataFromSourceURL(force: true)
            }

            let input = RecipeCreationInput(
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
                sourceURL: draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines),
                tagNames: draft.tags,
                imageData: selectedImageData,
                initialComment: draft.comments.trimmingCharacters(in: .whitespacesAndNewlines),
                initialRating: draft.rating
            )
            guard !input.title.isEmpty else {
                errorMessage = "Paste a valid recipe link or enter a title before saving."
                return false
            }
            try await environment.recipeService.createRecipe(input: input, householdID: householdID, author: userProfile)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
