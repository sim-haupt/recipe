import PhotosUI
import SwiftUI
import UIKit

struct AddRecipeView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddRecipeViewModel
    @State private var selectedPhoto: PhotosPickerItem?

    init(userProfile: UserProfile, environment: AppEnvironment = .demo) {
        _viewModel = StateObject(wrappedValue: AddRecipeViewModel(environment: environment, userProfile: userProfile))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    sourceLinkCard
                    generatedPreviewCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(RecipeTheme.pageGradient.ignoresSafeArea())
            .navigationTitle("Add Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .tint(RecipeTheme.accentStrong)
            .onChange(of: viewModel.draft.sourceURL) { _, _ in
                viewModel.scheduleURLImport()
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }

                Task {
                    let loadedData = try? await newValue.loadTransferable(type: Data.self)
                    viewModel.setCustomSelectedImageData(loadedData)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSaving)
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
    }

    private var sourceLinkCard: some View {
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
                .recipeFormInputStyle()
                .onSubmit {
                    Task {
                        await viewModel.fetchMetadataFromSourceURL(force: true)
                    }
                }

            if viewModel.isImportingURL || viewModel.isGeneratingPreview {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.isGeneratingPreview ? "Generating editable recipe preview…" : "Fetching recipe preview…")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("We’ll pull the image and title from the link, then generate ingredients, preparation, and notes for you to edit before saving.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RecipeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(RecipeTheme.strokeSoft, lineWidth: 1)
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

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
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

            inputSection(title: "Preparation") {
                TextField("One step per line", text: $viewModel.draft.preparationText, axis: .vertical)
                    .recipeFormInputStyle(minHeight: 170)
            }

            inputSection(title: "Notes") {
                TextField("Extra notes, substitutions, or tips", text: $viewModel.draft.notesText, axis: .vertical)
                    .recipeFormInputStyle(minHeight: 120)
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
