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
                             ? "Generating editable recipe preview…"
                             : (viewModel.isImportingURL ? "Fetching recipe preview…" : "Generate Preview"))
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

            inspectAIButton
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

    private var generatedPreviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recipe Preview")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(RecipeTheme.textPrimary)

                Spacer()

                Button {
                    Self.logger.debug("Change Image tapped for source: \(self.viewModel.draft.sourceURL)")
                    isPresentingImagePicker = true
                } label: {
                    Label("Change Image", systemImage: "photo")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(RecipeTheme.textOnAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(RecipeTheme.accentStrong)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            previewImage

            inputSection(title: "Title") {
                TextField("Recipe title", text: $viewModel.draft.title)
                    .recipeFormInputStyle()
            }

            inputSection(title: "Ingredients") {
                TextField("One ingredient per line", text: $viewModel.draft.ingredientsText, axis: .vertical)
                    .recipeFormInputStyle(minHeight: 150)
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
    }

    @ViewBuilder
    private var previewImage: some View {
        ZStack {
            if let imageData = viewModel.selectedImageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RemoteRecipeImage(imageURL: nil, width: nil, height: 210, placeholderStyle: .pattern("RecipeDetailPattern"))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 210, maxHeight: 210)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Text(viewModel.isUsingCustomImage ? "Custom image selected" : "Image from metadata")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.34))
                .clipShape(Capsule())
                .padding(12)
        }
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

private struct CategorySelectionGrid: View {
    @Binding var selectedCategories: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedCategories.isEmpty ? "Choose one or more categories" : selectedCategories.joined(separator: ", "))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(RecipeCategory.allTitles, id: \.self) { category in
                    let isSelected = selectedCategories.contains(category)
                    CategoryPill(title: category, isSelected: isSelected, style: .outlined) {
                        if isSelected {
                            selectedCategories.removeAll { $0 == category }
                        } else {
                            selectedCategories.append(category)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
