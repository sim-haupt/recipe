import Foundation

@MainActor
final class AddRecipeViewModel: ObservableObject {
    @Published var draft = RecipeComposerDraft(title: "", description: "", sourceURL: "", categories: [], tags: [], comments: "", rating: 0)
    @Published var isSaving = false
    @Published var isImportingURL = false
    @Published var isGeneratingPreview = false
    @Published var errorMessage: String?
    @Published var selectedImageData: Data?

    private let environment: AppEnvironment
    private let userProfile: UserProfile
    private var urlImportTask: Task<Void, Never>?
    private var lastImportedURL: String?
    private var importedRawText = ""
    private var lastGeneratedExtraction: RecipeAIExtraction?

    init(environment: AppEnvironment, userProfile: UserProfile) {
        self.environment = environment
        self.userProfile = userProfile
    }

    func applyPastedSourceURL(from pastedValue: String) {
        let trimmedValue = pastedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return }

        let detectedURL = firstURL(in: trimmedValue) ?? trimmedValue
        draft.sourceURL = detectedURL
        lastImportedURL = nil
        scheduleURLImport()
    }

    func scheduleURLImport() {
        let trimmedURL = draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            urlImportTask?.cancel()
            importedRawText = ""
            lastGeneratedExtraction = nil
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
            draft.title = imported.title
            importedRawText = imported.rawText
            draft.sourceURL = imported.canonicalURL
            if let imageData = imported.imageData {
                selectedImageData = imageData
            }
            lastImportedURL = imported.canonicalURL

            await generatePreviewContent(
                importedDescription: imported.description,
                replaceExistingFields: isNewImport || force
            )
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

            let enrichment = await fetchAIExtractionIfPossible()
            let finalDescription = ImportedTextSanitizer.preferredRecipeDescription(
                baseDescription: draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
                rawText: importedRawText.trimmingCharacters(in: .whitespacesAndNewlines),
                aiSummary: enrichment?.summary
            )
            let mergedExtraction = mergedExtraction(using: enrichment, description: finalDescription)

            let input = RecipeCreationInput(
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: finalDescription,
                sourceURL: draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines),
                categories: draft.categories,
                tagNames: draft.tags,
                imageData: selectedImageData,
                initialComment: draft.comments.trimmingCharacters(in: .whitespacesAndNewlines),
                initialRating: draft.rating,
                aiExtraction: mergedExtraction
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

    private func fetchAIExtractionIfPossible() async -> RecipeAIExtraction? {
        let request = RecipeEnrichmentRequest(
            sourceURL: draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines),
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
            rawText: importedRawText.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        guard request.hasEnoughContent else { return nil }
        return try? await environment.recipeEnrichmentService.enrichRecipeContent(using: request)
    }

    private func generatePreviewContent(importedDescription: String, replaceExistingFields: Bool) async {
        isGeneratingPreview = true
        defer { isGeneratingPreview = false }

        let enrichment = await fetchAIExtractionIfPossible()
        lastGeneratedExtraction = enrichment

        draft.description = ImportedTextSanitizer.preferredRecipeDescription(
            baseDescription: importedDescription,
            rawText: importedRawText,
            aiSummary: enrichment?.summary
        )

        let generatedIngredients = (enrichment?.ingredients ?? []).joined(separator: "\n")
        let generatedPreparation = (enrichment?.preparationSteps ?? []).joined(separator: "\n")
        let generatedNotes = (enrichment?.notes ?? []).joined(separator: "\n")

        if replaceExistingFields || draft.ingredientsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.ingredientsText = generatedIngredients
        }
        if replaceExistingFields || draft.preparationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.preparationText = generatedPreparation
        }
        if replaceExistingFields || draft.notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.notesText = generatedNotes
        }
    }

    private func mergedExtraction(using generatedExtraction: RecipeAIExtraction?, description: String) -> RecipeAIExtraction? {
        let ingredients = parsedLines(from: draft.ingredientsText)
        let preparationSteps = parsedLines(from: draft.preparationText)
        let notes = parsedLines(from: draft.notesText)

        let extraction = RecipeAIExtraction(
            summary: description,
            ingredients: ingredients,
            preparationSteps: preparationSteps,
            notes: notes,
            confidence: generatedExtraction?.confidence ?? lastGeneratedExtraction?.confidence
        )

        return extraction.hasMeaningfulContent ? extraction : nil
    }

    private func parsedLines(from value: String) -> [String] {
        ImportedTextSanitizer.cleanMultiline(value)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func firstURL(in text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, options: [], range: range)?.url?.absoluteString
    }
}
