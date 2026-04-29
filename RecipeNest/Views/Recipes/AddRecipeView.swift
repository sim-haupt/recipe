import PhotosUI
import SwiftUI

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
            Form {
                Section("Recipe") {
                    TextField("Title", text: $viewModel.draft.title)
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
                    TextField("Description or clipped content", text: $viewModel.draft.description, axis: .vertical)
                        .lineLimit(4...10)
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

                Section("Image") {
                    PhotosPicker("Choose Photo", selection: $selectedPhoto, matching: .images)
                }

                Section("Your first note") {
                    TextField("Comment", text: $viewModel.draft.comments, axis: .vertical)
                        .lineLimit(3...6)
                    StarRatingView(rating: $viewModel.draft.rating)
                }
            }
            .navigationTitle("Add Recipe")
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
                    .disabled(
                        viewModel.draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                        viewModel.draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .task(id: selectedPhoto) {
                guard let selectedPhoto else { return }
                viewModel.selectedImageData = try? await selectedPhoto.loadTransferable(type: Data.self)
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
}
