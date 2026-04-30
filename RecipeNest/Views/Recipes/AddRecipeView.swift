import SwiftUI
import UIKit

struct AddRecipeView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddRecipeViewModel

    init(userProfile: UserProfile, environment: AppEnvironment = .demo) {
        _viewModel = StateObject(wrappedValue: AddRecipeViewModel(environment: environment, userProfile: userProfile))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe Link") {
                    TextField("Source URL", text: $viewModel.draft.sourceURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .submitLabel(.go)
                        .recipeFormInputStyle()
                        .onSubmit {
                            Task {
                                await viewModel.fetchMetadataFromSourceURL(force: true)
                            }
                        }
                    if viewModel.isImportingURL {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Fetching title, image, and description…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !viewModel.draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !viewModel.draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.selectedImageData != nil {
                        importedPreview
                    }
                }

                Section("Categories") {
                    CategorySelectionGrid(selectedCategories: $viewModel.draft.categories)
                }
            }
            .scrollContentBackground(.hidden)
            .background(RecipeTheme.pageGradient.ignoresSafeArea())
            .listRowBackground(Color.clear)
            .navigationTitle("Add Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .tint(RecipeTheme.accentStrong)
            .onChange(of: viewModel.draft.sourceURL) { _, _ in
                viewModel.scheduleURLImport()
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
                    .disabled(viewModel.draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    @ViewBuilder
    private var importedPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Imported Preview")
                .font(.system(size: 14, weight: .bold, design: .rounded))

            if let imageData = viewModel.selectedImageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160, alignment: .center)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if !viewModel.draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(viewModel.draft.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }

            if !viewModel.draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(viewModel.draft.description)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .padding(.vertical, 4)
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
                    Button {
                        if isSelected {
                            selectedCategories.removeAll { $0 == category }
                        } else {
                            selectedCategories.append(category)
                        }
                    } label: {
                        Text(category)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(RecipeCategory.color(for: category))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(RecipeCategory.fillColor(for: category, isSelected: isSelected))
                            )
                            .overlay {
                                Capsule()
                                    .stroke(RecipeCategory.strokeColor(for: category, isSelected: isSelected), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
