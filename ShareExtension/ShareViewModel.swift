import Foundation

@MainActor
final class ShareViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var rawText = ""
    @Published var ingredientsText = ""
    @Published var preparationText = ""
    @Published var notesText = ""
    @Published var sourceURL = ""
    @Published var tags: [String] = []
    @Published var selectedCategories = Set<String>()
    @Published var imageData: Data?
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let extensionItems: [NSExtensionItem]
    private let draftStore: SharedDraftStore
    private let importer: RecipeShareImporter
    private let recipeEnrichmentService: RecipeEnrichmentService
    private var lastGeneratedExtraction: RecipeAIExtraction?

    init(
        extensionItems: [NSExtensionItem],
        draftStore: SharedDraftStore = SharedDraftStore(),
        importer: RecipeShareImporter = RecipeShareImporter(),
        recipeEnrichmentService: RecipeEnrichmentService = RecipeEnrichmentService()
    ) {
        self.extensionItems = extensionItems
        self.draftStore = draftStore
        self.importer = importer
        self.recipeEnrichmentService = recipeEnrichmentService
    }

    func load() async {
        let payload = await importer.extractPayload(from: extensionItems)
        title = payload.title
        description = payload.description
        rawText = payload.rawText
        sourceURL = payload.sourceURL ?? ""
        imageData = payload.imageData

        let enrichment = try? await recipeEnrichmentService.enrichRecipeContent(using: RecipeEnrichmentRequest(
            sourceURL: sourceURL.trimmingCharacters(in: .whitespacesAndNewlines),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            rawText: rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        ))

        lastGeneratedExtraction = enrichment
        description = ImportedTextSanitizer.preferredRecipeDescription(
            baseDescription: description,
            rawText: rawText,
            aiSummary: enrichment?.summary
        )
        ingredientsText = (enrichment?.ingredients ?? []).joined(separator: "\n")
        preparationText = (enrichment?.preparationSteps ?? []).joined(separator: "\n")
        notesText = (enrichment?.notes ?? []).joined(separator: "\n")
        isLoading = false
    }

    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            let draft = RecipeDraft(
                id: UUID().uuidString,
                title: ImportedTextSanitizer.cleanInline(title).ifEmpty("Untitled Recipe"),
                description: ImportedTextSanitizer.preferredRecipeDescription(
                    baseDescription: description,
                    rawText: rawText,
                    aiSummary: lastGeneratedExtraction?.summary
                ),
                rawText: ImportedTextSanitizer.cleanMultiline(rawText),
                ingredients: parsedLines(from: ingredientsText),
                preparationSteps: parsedLines(from: preparationText),
                notes: parsedLines(from: notesText),
                sourceURL: sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                imageFileName: nil,
                categories: selectedCategories.sorted(),
                tags: tags,
                savedDate: Date(),
                importedAt: nil,
                createdByUser: nil
            )

            try draftStore.saveDraft(draft, imageData: imageData)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func parsedLines(from value: String) -> [String] {
        ImportedTextSanitizer.cleanMultiline(value)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
