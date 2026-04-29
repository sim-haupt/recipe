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

                Section("Tags") {
                    HStack {
                        TextField("Add tag", text: $viewModel.tagEntry)
                        Button("Add", action: viewModel.addTag)
                    }

                    FlowTagList(tags: viewModel.draft.tags) { tag in
                        viewModel.removeTag(tag)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RecipeTheme.pageGradient.ignoresSafeArea())
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
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
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
