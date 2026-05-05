import PhotosUI
import SwiftUI
import UIKit
import os

struct AddRecipeView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddRecipeViewModel
    @State private var isShowingPreviewEditor = false
    @FocusState private var isSourceURLFocused: Bool

    init(userProfile: UserProfile, environment: AppEnvironment = .demo) {
        _viewModel = StateObject(wrappedValue: AddRecipeViewModel(environment: environment, userProfile: userProfile))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    sourceEntryCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(RecipeTheme.pageGradient.ignoresSafeArea())
            .navigationTitle("Add Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .tint(RecipeTheme.accentStrong)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Unable to save", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .environment(\.appEnvironment, environment)
        .fullScreenCover(isPresented: $isShowingPreviewEditor) {
            NavigationStack {
                AddRecipePreviewEditorView(
                    viewModel: viewModel,
                    onBack: {
                        viewModel.beginEditingSourceURL()
                        isShowingPreviewEditor = false
                        DispatchQueue.main.async {
                            isSourceURLFocused = true
                        }
                    },
                    onSave: {
                        if await viewModel.save() {
                            dismiss()
                        }
                    }
                )
            }
        }
        .task {
            if !viewModel.hasResolvedSourcePreview {
                isSourceURLFocused = true
            }
        }
    }

    private var sourceEntryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Recipe Link")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(RecipeTheme.textPrimary)

                Spacer()
            }

            TextField("Paste a recipe link", text: $viewModel.draft.sourceURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .textContentType(.URL)
                .submitLabel(.go)
                .focused($isSourceURLFocused)
                .recipeFormInputStyle()
                .onSubmit {
                    Task {
                        await startPreviewGeneration()
                    }
                }

            VStack(alignment: .leading, spacing: 10) {
                Text("Paste a link, then generate a separate editable preview with image, title, ingredients, categories, and tags.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await startPreviewGeneration()
                    }
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isImportingURL || viewModel.isGeneratingPreview {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(viewModel.isGeneratingPreview
                             ? "Importing recipe…"
                             : (viewModel.isImportingURL ? "Fetching recipe…" : "Import Recipe"))
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(RecipeTheme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RecipeTheme.accentStrong)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isImportingURL || viewModel.isGeneratingPreview)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RecipeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(RecipeTheme.strokeSoft, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: RecipeTheme.shadow.opacity(0.55), radius: 10, y: 6)
    }
    @MainActor
    private func startPreviewGeneration() async {
        isSourceURLFocused = false
        await viewModel.generatePreviewFromSourceURL()
        if viewModel.hasResolvedSourcePreview {
            isShowingPreviewEditor = true
        }
    }
}

private struct AddRecipePreviewEditorView: View {
    private static let logger = Logger(subsystem: "WeCookin", category: "AddRecipePreview")

    @ObservedObject var viewModel: AddRecipeViewModel
    let onBack: () -> Void
    let onSave: () async -> Void
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isShowingDebugInspector = false
    @State private var isPresentingImagePicker = false
    @State private var isEditingIngredients = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                previewSourceCard
                generatedPreviewCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                Self.logger.debug("Preview root received tap for source: \(self.viewModel.draft.sourceURL, privacy: .public)")
            }
        )
        .background(RecipeTheme.pageGradient.ignoresSafeArea())
        .navigationTitle("Recipe Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") {
                    onBack()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task {
                        await onSave()
                    }
                }
                .disabled(!viewModel.hasResolvedSourcePreview || viewModel.isSaving)
            }
        }
        .sheet(isPresented: $isShowingDebugInspector) {
            debugInspectorSheet
        }
        .photosPicker(isPresented: $isPresentingImagePicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }

            Task {
                let loadedData = try? await newValue.loadTransferable(type: Data.self)
                viewModel.setCustomSelectedImageData(loadedData)
            }
        }
        .onChange(of: isPresentingImagePicker) { _, isPresented in
            Self.logger.debug("Change Image picker state changed: \(isPresented)")
        }
        .onChange(of: isShowingDebugInspector) { _, isPresented in
            Self.logger.debug("Inspect AI Input sheet state changed: \(isPresented)")
        }
        .task {
            viewModel.logPreviewDiagnostics(context: "AddRecipePreviewEditorView.task")
        }
    }

    private var previewSourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Recipe Link")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(RecipeTheme.textPrimary)

                Spacer()
            }

            HStack(spacing: 12) {
                Label(viewModel.draft.sourceURL, systemImage: "link")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(RecipeTheme.textPrimary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.96))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: RecipeTheme.mintShadow.opacity(0.42), radius: 12, y: 6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RecipeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(RecipeTheme.strokeSoft, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: RecipeTheme.shadow.opacity(0.55), radius: 10, y: 6)
        .modifier(FrameLoggingModifier(name: "previewSourceCard", logger: Self.logger))
        .simultaneousGesture(
            TapGesture().onEnded {
                Self.logger.debug("Preview source card received tap")
            }
        )
    }

    private var generatedPreviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recipe Preview")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(RecipeTheme.textPrimary)

                Spacer()
            }

            previewImage

            inputSection(title: "Title") {
                TextField("Recipe title", text: $viewModel.draft.title)
                    .recipeFormInputStyle()
            }

            inputSection(title: "Ingredients") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(isEditingIngredients ? "Edit ingredients" : "Saved format preview")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            isEditingIngredients.toggle()
                        } label: {
                            Image(systemName: isEditingIngredients ? "checkmark.circle.fill" : "square.and.pencil")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(RecipeTheme.accentStrong)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isEditingIngredients ? "Done editing ingredients" : "Edit ingredients")
                    }

                    if isEditingIngredients {
                        TextField("One ingredient per line", text: $viewModel.draft.ingredientsText, axis: .vertical)
                            .recipeFormInputStyle(minHeight: 150)
                    } else {
                        FormattedIngredientsPreviewCard(
                            items: AddRecipeIngredientFormatting.lines(from: viewModel.draft.ingredientsText),
                            accent: RecipeTheme.accentStrong,
                            textPrimary: RecipeTheme.textPrimary,
                            surface: Color.white.opacity(0.9)
                        )
                    }
                }
            }

            inputSection(title: "Categories") {
                CategorySelectionGrid(selectedCategories: $viewModel.draft.categories)
            }

            inputSection(title: "Tags") {
                EditableTagEditor(
                    tags: $viewModel.draft.tags,
                    placeholder: "Add tags",
                    helperText: viewModel.draft.tags.isEmpty ? "Add any custom hashtags you want to keep with this recipe." : nil
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RecipeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(RecipeTheme.strokeSoft, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: RecipeTheme.shadow.opacity(0.55), radius: 10, y: 6)
        .modifier(FrameLoggingModifier(name: "generatedPreviewCard", logger: Self.logger))
    }

    @ViewBuilder
    private var previewImage: some View {
        ZStack {
            if let imageData = viewModel.selectedImageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .allowsHitTesting(false)
            } else {
                RemoteRecipeImage(imageURL: nil, width: nil, height: 210, placeholderStyle: .pattern("RecipeDetailPattern"))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 210, maxHeight: 210)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Button {
                Self.logger.debug("Change Image tapped for source: \(self.viewModel.draft.sourceURL)")
                self.viewModel.logPreviewDiagnostics(context: "ChangeImage.tap")
                isPresentingImagePicker = true
            } label: {
                changeImageLabel
            }
            .buttonStyle(.plain)
            .modifier(FrameLoggingModifier(name: "changeImageButton", logger: Self.logger))
            .padding(12)
        }
        .modifier(FrameLoggingModifier(name: "previewImage", logger: Self.logger))
        .simultaneousGesture(
            TapGesture().onEnded {
                Self.logger.debug("Preview image container received tap")
            }
        )
    }

    private func inputSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(RecipeTheme.textPrimary)

            content()
        }
    }

    private var inspectAIButton: some View {
        Button {
            Self.logger.debug("Inspect AI Input tapped for source: \(self.viewModel.draft.sourceURL)")
            self.viewModel.logPreviewDiagnostics(context: "InspectAIButton.tap")
            isShowingDebugInspector = true
            Task {
                await viewModel.loadDebugInfo()
            }
        } label: {
            Label(viewModel.isLoadingDebugInfo ? "Inspecting…" : "Inspect AI Input", systemImage: "ladybug")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(RecipeTheme.textOnAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RecipeTheme.accentStrong)
                .clipShape(Capsule())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoadingDebugInfo)
        .modifier(FrameLoggingModifier(name: "inspectAIButton", logger: Self.logger))
    }

    private var changeImageLabel: some View {
        Label("Change Image", systemImage: "photo")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(RecipeTheme.textOnAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RecipeTheme.accentStrong)
            .clipShape(Capsule())
    }

    private var debugInspectorSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if viewModel.isLoadingDebugInfo {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading backend debug payload…")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let debugInfo = viewModel.debugInfo {
                        debugField(title: "Model", value: debugInfo.model, isCode: true)
                        debugField(title: "Source URL", value: debugInfo.sourceURL, isCode: true)
                        debugField(title: "App Title", value: debugInfo.title)
                        debugField(title: "App Description", value: debugInfo.description)
                        debugField(title: "App Raw Text", value: debugInfo.rawText)
                        debugField(title: "Backend Fetched Title", value: debugInfo.fetchedTitle)
                        debugField(title: "Backend Fetched Description", value: debugInfo.fetchedDescription)
                        debugField(title: "Backend Fetched Text", value: debugInfo.fetchedText)
                        debugField(title: "Candidate Text Sent To GPT", value: debugInfo.candidateText)
                        debugField(title: "GPT Generated Title", value: debugInfo.extraction.title)
                        debugField(title: "GPT Extracted Ingredients", value: debugInfo.extraction.ingredients.joined(separator: "\n"))
                        debugField(title: "System Prompt", value: debugInfo.systemPrompt)
                        debugField(title: "User Prompt", value: debugInfo.userPrompt)
                    } else if let debugErrorMessage = viewModel.debugErrorMessage {
                        debugField(title: "Debug Error", value: debugErrorMessage)
                    } else {
                        Text("No debug payload yet.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
            }
            .background(RecipeTheme.pageGradient.ignoresSafeArea())
            .navigationTitle("AI Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        isShowingDebugInspector = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await viewModel.loadDebugInfo()
                        }
                    }
                    .disabled(viewModel.isLoadingDebugInfo)
                }
            }
        }
    }

    private func debugField(title: String, value: String, isCode: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(RecipeTheme.textPrimary)

            Text(value.isEmpty ? "—" : value)
                .font(isCode
                    ? .system(size: 13, weight: .medium, design: .monospaced)
                    : .system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(RecipeTheme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.96))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
    }
}

private struct FormattedIngredientsPreviewCard: View {
    let items: [String]
    let accent: Color
    let textPrimary: Color
    let surface: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if items.isEmpty {
                Text("Ingredients will appear here once extracted or edited.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if AddRecipeIngredientFormatting.isSectionHeader(item) {
                            Text(item)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(accent)
                                .padding(.top, index == 0 ? 0 : 6)
                        } else {
                            HStack(alignment: .top, spacing: 10) {
                                Text("•")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(accent)
                                    .frame(width: 10, alignment: .leading)

                                Text(item)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

private extension View {
    func recipeFormInputStyle(minHeight: CGFloat = 56) -> some View {
        self
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.96))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: RecipeTheme.mintShadow.opacity(0.42), radius: 12, y: 6)
    }
}

private enum AddRecipeIngredientFormatting {
    static func lines(from value: String) -> [String] {
        ImportedTextSanitizer.cleanMultiline(value)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func isSectionHeader(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") { return false }
        return trimmed.hasSuffix(":")
    }
}

private struct FrameLoggingModifier: ViewModifier {
    let name: String
    let logger: Logger

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .task(id: frameSignature(proxy.frame(in: .global))) {
                        let frame = proxy.frame(in: .global)
                        logger.debug("\(self.name, privacy: .public) frame x=\(frame.origin.x) y=\(frame.origin.y) w=\(frame.size.width) h=\(frame.size.height)")
                    }
            }
        )
    }

    private func frameSignature(_ frame: CGRect) -> String {
        "\(frame.origin.x.rounded())-\(frame.origin.y.rounded())-\(frame.size.width.rounded())-\(frame.size.height.rounded())"
    }
}

private struct CategorySelectionGrid: View {
    @Binding var selectedCategories: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedCategories.isEmpty ? "Choose one or more categories" : selectedCategories.joined(separator: ", "))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            FlowCategoryPillList(
                titles: RecipeCategory.allTitles,
                style: .outlined,
                isSelected: { selectedCategories.contains($0) },
                action: { category in
                    if selectedCategories.contains(category) {
                        selectedCategories.removeAll { $0 == category }
                    } else {
                        selectedCategories.append(category)
                    }
                }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
