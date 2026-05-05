import Foundation
import UIKit
import os

@MainActor
final class AddRecipeViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "WeCookin", category: "AddRecipeViewModel")

    @Published var draft = RecipeComposerDraft(title: "", description: "", sourceURL: "", categories: [], tags: [], comments: "", rating: 0)
    @Published var isSaving = false
    @Published var isImportingURL = false
    @Published var isGeneratingPreview = false
    @Published var isLoadingDebugInfo = false
    @Published var errorMessage: String?
    @Published var debugErrorMessage: String?
    @Published var debugInfo: RecipeEnrichmentDebugInfo?
    @Published var hasResolvedSourcePreview = false
    @Published var selectedImageData: Data?
    @Published private(set) var isUsingCustomImage = false

    private let environment: AppEnvironment
    private let userProfile: UserProfile
    private var urlImportTask: Task<Void, Never>?
    private var lastImportedURL: String?
    private var shouldIgnoreNextSourceURLChange = false
    private var importedRawText = ""
    private var importedDescription = ""
    private var lastGeneratedExtraction: RecipeAIExtraction?
    init(environment: AppEnvironment, userProfile: UserProfile) {
        self.environment = environment
        self.userProfile = userProfile
    }

    func setCustomSelectedImageData(_ data: Data?) {
        selectedImageData = data
        isUsingCustomImage = data != nil
        logPreviewDiagnostics(context: "setCustomSelectedImageData")
    }

    func beginEditingSourceURL() {
        hasResolvedSourcePreview = false
        debugInfo = nil
        debugErrorMessage = nil
        logPreviewDiagnostics(context: "beginEditingSourceURL")
    }

    func generatePreviewFromSourceURL() async {
        urlImportTask?.cancel()
        await fetchMetadataFromSourceURL(force: true)
    }

    func scheduleURLImport() {
        if shouldIgnoreNextSourceURLChange {
            shouldIgnoreNextSourceURLChange = false
            return
        }

        let trimmedURL = draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            urlImportTask?.cancel()
            importedRawText = ""
            importedDescription = ""
            lastGeneratedExtraction = nil
            debugInfo = nil
            debugErrorMessage = nil
            hasResolvedSourcePreview = false
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
            draft.title = sanitizedImportedTitle(
                imported.title,
                sourceURL: imported.canonicalURL,
                rawText: imported.rawText
            )
            importedRawText = imported.rawText
            importedDescription = imported.description
            if draft.sourceURL != imported.canonicalURL {
                shouldIgnoreNextSourceURLChange = true
                draft.sourceURL = imported.canonicalURL
            }
            debugInfo = nil
            debugErrorMessage = nil
            if !isUsingCustomImage, let imageData = imported.imageData {
                selectedImageData = imageData
            }
            lastImportedURL = imported.canonicalURL
            hasResolvedSourcePreview = true
            logPreviewDiagnostics(context: "fetchMetadataFromSourceURL.afterImport")

            await generatePreviewContent(
                importedDescription: imported.description,
                replaceExistingFields: isNewImport || force
            )
        } catch {
            hasResolvedSourcePreview = false
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
        let request = buildEnrichmentRequest()
        guard request.hasEnoughContent else { return nil }
        do {
            return try await environment.recipeEnrichmentService.enrichRecipeContent(using: request)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func loadDebugInfo() async {
        let request = buildEnrichmentRequest()
        guard request.hasEnoughContent else {
            debugInfo = nil
            debugErrorMessage = "Paste a recipe link first."
            return
        }

        isLoadingDebugInfo = true
        defer { isLoadingDebugInfo = false }

        do {
            debugInfo = try await environment.recipeEnrichmentService.debugRecipeContent(using: request)
            debugErrorMessage = nil
        } catch {
            debugInfo = nil
            debugErrorMessage = error.localizedDescription
        }
        logPreviewDiagnostics(context: "loadDebugInfo.completed")
    }

    private func generatePreviewContent(importedDescription: String, replaceExistingFields: Bool) async {
        isGeneratingPreview = true
        defer { isGeneratingPreview = false }

        let enrichment = await fetchAIExtractionIfPossible()
        lastGeneratedExtraction = enrichment

        if shouldReplaceTitleWithAI(enrichment?.title) {
            draft.title = enrichment?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? draft.title
        }

        draft.description = ImportedTextSanitizer.preferredRecipeDescription(
            baseDescription: importedDescription,
            rawText: importedRawText,
            aiSummary: enrichment?.summary
        )

        let generatedIngredients = (enrichment?.ingredients ?? []).joined(separator: "\n")

        if !generatedIngredients.isEmpty && (replaceExistingFields || draft.ingredientsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            draft.ingredientsText = generatedIngredients
        }
        logPreviewDiagnostics(context: "generatePreviewContent.completed")
    }

    private func mergedExtraction(using generatedExtraction: RecipeAIExtraction?, description: String) -> RecipeAIExtraction? {
        let ingredients = parsedLines(from: draft.ingredientsText)

        let extraction = RecipeAIExtraction(
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: description,
            ingredients: ingredients,
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

    private func buildEnrichmentRequest() -> RecipeEnrichmentRequest {
        let titleForEnrichment = ImportedTextSanitizer.isLikelyNoisySocialTitle(
            draft.title,
            sourceURL: draft.sourceURL,
            rawText: importedRawText
        ) ? "" : draft.title.trimmingCharacters(in: .whitespacesAndNewlines)

        return RecipeEnrichmentRequest(
            sourceURL: draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines),
            title: titleForEnrichment,
            description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? importedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                : draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
            rawText: importedRawText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func sanitizedImportedTitle(_ title: String, sourceURL: String, rawText: String) -> String {
        let cleaned = ImportedTextSanitizer.cleanInline(title)
        if ImportedTextSanitizer.isLikelyNoisySocialTitle(cleaned, sourceURL: sourceURL, rawText: rawText) {
            return ""
        }
        return cleaned
    }

    private func shouldReplaceTitleWithAI(_ generatedTitle: String?) -> Bool {
        guard let generatedTitle = generatedTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !generatedTitle.isEmpty else {
            return false
        }

        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        return ImportedTextSanitizer.isLikelyNoisySocialTitle(
            draft.title,
            sourceURL: draft.sourceURL,
            rawText: importedRawText
        )
    }

    func previewDiagnosticsSnapshot(context: String) -> String {
        let request = buildEnrichmentRequest()
        let imageSizeDescription: String
        if let selectedImageData, let image = UIImage(data: selectedImageData) {
            imageSizeDescription = "\(Int(image.size.width))x\(Int(image.size.height))"
        } else {
            imageSizeDescription = "nil"
        }

        let host = URL(string: draft.sourceURL)?.host ?? "nil"
        let platform = if host.contains("instagram.com") {
            "instagram"
        } else if host.contains("tiktok.com") {
            "tiktok"
        } else {
            "web"
        }

        return """
        [\(context)] \
        sourceURL=\(draft.sourceURL) \
        host=\(host) \
        platform=\(platform) \
        titleLength=\(draft.title.count) \
        descriptionLength=\(draft.description.count) \
        rawTextLength=\(importedRawText.count) \
        ingredientsLength=\(draft.ingredientsText.count) \
        isSaving=\(isSaving) \
        isImportingURL=\(isImportingURL) \
        isGeneratingPreview=\(isGeneratingPreview) \
        isLoadingDebugInfo=\(isLoadingDebugInfo) \
        hasResolvedSourcePreview=\(hasResolvedSourcePreview) \
        hasError=\(errorMessage != nil) \
        debugError=\(debugErrorMessage != nil) \
        selectedImageData=\(selectedImageData != nil) \
        selectedImageSize=\(imageSizeDescription) \
        isUsingCustomImage=\(isUsingCustomImage) \
        aiInputAvailable=\(request.hasEnoughContent) \
        debugInfoLoaded=\(debugInfo != nil)
        """
    }

    func logPreviewDiagnostics(context: String) {
        Self.logger.debug("\(self.previewDiagnosticsSnapshot(context: context), privacy: .public)")
    }
}
