import SwiftUI
import UIKit

struct ShareComposerView: View {
    @ObservedObject var viewModel: ShareViewModel
    let onCancel: () -> Void
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Extracting recipe content...")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            stepHeader

                            if let imageData = viewModel.imageData, let image = UIImage(data: imageData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 180)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }

                            if viewModel.currentStep == .details {
                                detailStep
                            } else {
                                tagStep
                            }

                            Text("Some apps only share a link, caption text, or a low-resolution thumbnail. Instagram and other third-party apps may not expose the full recipe metadata.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Save Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.currentStep == .details {
                        Button("Next") {
                            viewModel.goToNextStep()
                        }
                        .disabled(viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button(viewModel.isSaving ? "Saving..." : "Save") {
                            Task {
                                if await viewModel.save() {
                                    onComplete()
                                }
                            }
                        }
                        .disabled(viewModel.isSaving)
                    }
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
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.currentStep == .details ? "Review Import" : "Add Tags")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(viewModel.currentStep == .details
                 ? "Edit anything the source app did not provide cleanly before saving."
                 : "Add a few tags now so this recipe is easy to find on the home screen.")
                .foregroundStyle(.secondary)
        }
    }

    private var detailStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                Text("Title")
                    .font(.headline)
                TextField("Recipe title", text: $viewModel.title)
                    .textFieldStyle(.roundedBorder)
            }

            Group {
                Text("Source URL")
                    .font(.headline)
                TextField("https://example.com", text: $viewModel.sourceURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)
            }

            Group {
                Text("Description or recipe notes")
                    .font(.headline)
                TextField("Paste or edit the shared content", text: $viewModel.description, axis: .vertical)
                    .lineLimit(5...12)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var tagStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Add tag", text: $viewModel.tagEntry)
                    .textFieldStyle(.roundedBorder)
                Button("Add", action: viewModel.addTag)
            }

            ShareFlowTagList(tags: viewModel.tags, onRemove: viewModel.removeTag(_:))

            Button("Back") {
                viewModel.goBack()
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct ShareFlowTagList: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        if tags.isEmpty {
            Text("No tags yet. You can still save now and edit tags inside the app later.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            onRemove(tag)
                        } label: {
                            HStack(spacing: 6) {
                                Text(tag)
                                Image(systemName: "xmark.circle.fill")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.16))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
