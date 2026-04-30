import Foundation

@MainActor
final class ShareViewModel: ObservableObject {
    enum Step: Int {
        case details
        case category
    }

    @Published var title = ""
    @Published var description = ""
    @Published var rawText = ""
    @Published var sourceURL = ""
    @Published var selectedCategories = Set<String>()
    @Published var imageData: Data?
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var currentStep: Step = .details
    @Published var errorMessage: String?

    private let extensionItems: [NSExtensionItem]
    private let draftStore: SharedDraftStore
    private let importer: RecipeShareImporter

    init(
        extensionItems: [NSExtensionItem],
        draftStore: SharedDraftStore = SharedDraftStore(),
        importer: RecipeShareImporter = RecipeShareImporter()
    ) {
        self.extensionItems = extensionItems
        self.draftStore = draftStore
        self.importer = importer
    }

    func load() async {
        let payload = await importer.extractPayload(from: extensionItems)
        title = payload.title
        description = payload.description
        rawText = payload.rawText
        sourceURL = payload.sourceURL ?? ""
        imageData = payload.imageData
        isLoading = false
    }

    func goToNextStep() {
        currentStep = .category
    }

    func goBack() {
        currentStep = .details
    }

    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            let draft = RecipeDraft(
                id: UUID().uuidString,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("Untitled Recipe"),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                rawText: rawText.trimmingCharacters(in: .whitespacesAndNewlines),
                sourceURL: sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                imageFileName: nil,
                categories: selectedCategories.sorted(),
                tags: [],
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
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
