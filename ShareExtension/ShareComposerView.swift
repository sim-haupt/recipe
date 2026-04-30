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
                                categoryStep
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
            Text(viewModel.currentStep == .details ? "Review Import" : "Choose Categories")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(viewModel.currentStep == .details
                 ? "Edit anything the source app did not provide cleanly before saving."
                 : "Pick one or more categories now so this recipe is easy to browse later.")
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

    private var categoryStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(RecipeCategory.allTitles, id: \.self) { category in
                    let isSelected = viewModel.selectedCategories.contains(category)
                    Button {
                        if isSelected {
                            viewModel.selectedCategories.remove(category)
                        } else {
                            viewModel.selectedCategories.insert(category)
                        }
                    } label: {
                        Text(category)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(RecipeCategory.color(for: category))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(categoryBackground(category: category, isSelected: isSelected))
                            .overlay {
                                Capsule()
                                    .stroke(RecipeCategory.strokeColor(for: category, isSelected: isSelected), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Back") {
                viewModel.goBack()
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func categoryBackground(category: String, isSelected: Bool) -> some View {
        Capsule()
            .fill(RecipeCategory.fillColor(for: category, isSelected: isSelected))
    }
}
